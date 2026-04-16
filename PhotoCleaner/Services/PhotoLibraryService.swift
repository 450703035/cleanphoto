import Photos
import Vision
import CoreImage
import UIKit

/// Central service that reads PHPhotoLibrary and performs AI scoring.
/// All heavy work happens on a background queue; results are published on main.
class PhotoLibraryService: ObservableObject {

    static let shared = PhotoLibraryService()
    private init() {}
    private let imageRequestTimeout: TimeInterval = 12

    // MARK: - Permission
    func requestAuthorization() async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        return status == .authorized || status == .limited
    }

    // MARK: - Fetch all assets
    func fetchAllAssets() async -> [PhotoAsset] {
        await Task.detached(priority: .userInitiated) {
            let opts = PHFetchOptions()
            opts.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            opts.includeHiddenAssets = false
            let result = PHAsset.fetchAssets(with: opts)
            var assets: [PhotoAsset] = []
            assets.reserveCapacity(result.count)
            result.enumerateObjects { asset, _, _ in
                // Do not sync-fetch PHAssetResource.fileSize during app launch.
                // That triggers on-demand metadata fetches and can stall UI.
                let pa = PhotoAsset(
                    id: asset.localIdentifier,
                    asset: asset,
                    score: 50,
                    isSelected: false,
                    fileSizeBytes: nil
                )
                assets.append(pa)
            }
            return assets
        }.value
    }

    // MARK: - Fill real file sizes in background (for visible subsets)
    func populateFileSizes(for assets: [PhotoAsset], limit: Int = 300) async -> [PhotoAsset] {
        await Task.detached(priority: .utility) {
            guard !assets.isEmpty else { return assets }
            var result = assets
            let upper = min(limit, result.count)
            if upper <= 0 { return result }

            for i in 0..<upper where result[i].fileSizeBytes == nil {
                if Task.isCancelled { break }
                if let size = self.assetFileSize(result[i].asset), size > 0 {
                    result[i].fileSizeBytes = size
                }
            }
            return result
        }.value
    }

    // MARK: - Score a single asset using IQA + heuristics
    func score(asset: PHAsset) async -> ScoreResult {
        guard let image = await requestImageWithTimeout(
            for: asset,
            targetSize: CGSize(width: 384, height: 384),
            contentMode: .aspectFit,
            timeout: imageRequestTimeout
        ), let cgImage = image.cgImage else {
            return ScoreResult(
                score: 50,
                isBlurry: false,
                isOverExposed: false,
                isUnderExposed: false,
                hasFaces: false,
                isShaky: false,
                isFocusFailed: false
            )
        }
        return Self.computeScore(cgImage: cgImage, asset: asset)
    }

    struct ScoreResult: Sendable {
        let score: Int
        let isBlurry: Bool
        let isOverExposed: Bool
        let isUnderExposed: Bool
        let hasFaces: Bool
        let isShaky: Bool
        let isFocusFailed: Bool
    }

    struct QualitySignals: Sendable {
        let isBlurry: Bool
        let isShaky: Bool
        let isFocusFailed: Bool
        let isOverExposed: Bool
        let isUnderExposed: Bool
    }

    // Shared CIContext — GPU-accelerated, thread-safe for rendering.
    // Avoids the ~2ms allocation cost per photo that adds up at scale.
    private static let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    // MARK: - Additive scoring (produces wide 5–99 distribution)
    //
    // Design principle: start at neutral 50, apply bonuses and penalties independently.
    // Typical ranges:
    //   Blurry / bad exposure photo          →  5–30
    //   Clear ordinary landscape / object    →  55–70
    //   Portrait with good quality           →  70–88
    //   Favourite                            →  88–99
    //   Screenshot / utility (low-value)     →  20–45
    private static func computeScore(cgImage: CGImage, asset: PHAsset) -> ScoreResult {
        // ── Vision requests — all batched in ONE handler pass ────────────
        // VNDetectFaceCaptureQualityRequest: face count + per-face quality (0–1)
        // VNClassifyImageRequest: pet detection labels
        // VNCalculateImageAestheticsScoresRequest (iOS 18+): real aesthetic model
        let faceQualityRequest = VNDetectFaceCaptureQualityRequest()
        let classifyRequest    = VNClassifyImageRequest()
        var visionRequests: [VNRequest] = [faceQualityRequest, classifyRequest]

        var aestheticsReq: VNRequest? = nil
        if #available(iOS 18.0, *) {
            let req = VNCalculateImageAestheticsScoresRequest()
            aestheticsReq = req
            visionRequests.append(req)
        }

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform(visionRequests)

        // ── Face quality ─────────────────────────────────────────────────
        // faceCaptureQuality: 0 = worst (blurry/occluded), 1 = best (sharp, eyes open)
        let faceObservations  = faceQualityRequest.results ?? []
        let faceCount         = faceObservations.count
        let bestFaceQuality   = faceObservations.compactMap { $0.faceCaptureQuality }.max() ?? 0
        let hasFaces          = faceCount > 0

        // ── Pet detection from shared classify results ────────────────────
        let classifications = classifyRequest.results ?? []
        let petKeywords = ["dog","cat","animal","bird","rabbit","hamster","pet","puppy","kitten"]
        let hasPet = classifications.contains { obs in
            obs.confidence > 0.4 && petKeywords.contains(where: { obs.identifier.lowercased().contains($0) })
        }

        // ── Aesthetic score — iOS 18+ native model ────────────────────────
        // VNCalculateImageAestheticsScoresRequest is trained on aesthetic quality,
        // not content classification — overallScore ≈ −1…+1 (higher = better).
        // isUtility flags receipts, documents, QR codes etc. captured by camera.
        var aestheticBonus = 0
        var isUtility = false
        if #available(iOS 18.0, *),
           let req = aestheticsReq as? VNCalculateImageAestheticsScoresRequest,
           let obs = req.results?.first {
            isUtility = obs.isUtility
            // Map −1…+1 → −8…+10
            let clamped = Double(max(-1.0, min(1.0, obs.overallScore)))
            aestheticBonus = Int((clamped + 1.0) / 2.0 * 18.0) - 8
        }

        // ── Blur — texture-aware Laplacian (edge pixels only) ─────────────
        let blur           = textureAwareLaplacianVariance(cgImage: cgImage)
        let isBlurry       = blur < ScoringConfig.blurSevereThreshold
        let isSlightBlurry = blur >= ScoringConfig.blurSevereThreshold && blur < ScoringConfig.blurSlightThreshold
        let isVerySharp    = blur >= ScoringConfig.blurSharpThreshold
        let isFocusFailed  = blur < (ScoringConfig.blurSevereThreshold * 0.7)
        let isShaky        = blur >= (ScoringConfig.blurSevereThreshold * 0.7) && blur < ScoringConfig.blurSlightThreshold

        // ── Exposure — histogram-based (dark/bright pixel ratios) ─────────
        let (isUnderExposed, isOverExposed, isGoodExposure) = exposureFromHistogram(cgImage: cgImage)

        // ── Metadata flags ────────────────────────────────────────────────
        let isScreenshot = asset.mediaSubtypes.contains(.photoScreenshot)
        let isPanorama   = asset.mediaSubtypes.contains(.photoPanorama)
        let isLivePhoto  = asset.mediaSubtypes.contains(.photoLive)
        let isFav        = asset.isFavorite

        var score = ScoringConfig.baseScore

        // ── 1. Face quality bonus / penalty ──────────────────────────────
        // quality > 0.5 → sharp face, worthy bonus
        // quality < 0.3 → blurry / occluded face; penalise (cancels raw blur miss)
        // 0.3–0.5      → uncertain quality, neutral
        if hasFaces {
            if bestFaceQuality > 0.5 {
                score += faceCount >= 2 ? ScoringConfig.multiFaceBonus : ScoringConfig.singleFaceBonus
            } else if bestFaceQuality < 0.3 {
                score += ScoringConfig.blurryFacePenalty   // negative constant
            }
        } else if hasPet {
            score += ScoringConfig.petBonus
        }

        // ── 2. Favourite / content-type adjustment ────────────────────────
        if isFav { score += ScoringConfig.favoriteBonus }
        if isScreenshot || isUtility { score -= ScoringConfig.screenshotPenalty }
        else if isPanorama            { score += ScoringConfig.panoramaBonus }
        else if isLivePhoto           { score += ScoringConfig.livePhotoBonus }

        // ── 3. Image quality ──────────────────────────────────────────────
        if isBlurry            { score -= ScoringConfig.severeBlurPenalty }
        else if isSlightBlurry { score -= ScoringConfig.slightBlurPenalty }
        else if isVerySharp    { score += ScoringConfig.verySharpBonus }
        else                   { score += ScoringConfig.normalSharpnessBonus }

        if isUnderExposed || isOverExposed { score -= ScoringConfig.badExposurePenalty }
        else if isGoodExposure             { score += ScoringConfig.goodExposureBonus }

        // ── 4. Aesthetic score (iOS 18+ model, else 0) ────────────────────
        score += aestheticBonus

        // ── 5. Short video penalty ────────────────────────────────────────
        if asset.mediaType == .video && asset.duration < 3 { score -= ScoringConfig.shortVideoPenalty }

        return ScoreResult(
            score: max(ScoringConfig.minScore, min(ScoringConfig.maxScore, score)),
            isBlurry: isBlurry,
            isOverExposed: isOverExposed,
            isUnderExposed: isUnderExposed,
            hasFaces: hasFaces,
            isShaky: isShaky,
            isFocusFailed: isFocusFailed
        )
    }

    // MARK: - Texture-aware Laplacian variance (blur detection)
    //
    // Only counts pixels that lie on detected edges (Sobel magnitude > threshold).
    // Pure-color backgrounds have near-zero edge density and no longer drag down
    // the sharpness score — a plain-background portrait won't look artificially blurry.
    // If the image has almost no edges (featureless / solid fill), returns a neutral
    // value (300) so it doesn't get incorrectly penalised as blurry.
    private static func textureAwareLaplacianVariance(cgImage: CGImage) -> Double {
        let ciImage = CIImage(cgImage: cgImage)

        // Laplacian response — 2nd-derivative sharpness at each pixel
        guard let lapFilter = CIFilter(name: "CILaplacian") else { return 100 }
        lapFilter.setValue(ciImage, forKey: kCIInputImageKey)
        guard let lapOut = lapFilter.outputImage else { return 100 }

        // Edge magnitude — 1st-derivative: where edges actually exist
        guard let edgeFilter = CIFilter(name: "CIEdges") else {
            return globalLaplacianVariance(lapOut: lapOut, extent: ciImage.extent)
        }
        edgeFilter.setValue(ciImage, forKey: kCIInputImageKey)
        edgeFilter.setValue(2.0 as NSNumber, forKey: kCIInputIntensityKey)
        guard let edgeOut = edgeFilter.outputImage else {
            return globalLaplacianVariance(lapOut: lapOut, extent: ciImage.extent)
        }

        let extent = ciImage.extent
        guard let lapBM  = ciContext.createCGImage(lapOut,  from: extent),
              let edgeBM = ciContext.createCGImage(edgeOut, from: extent) else { return 100 }

        let w = lapBM.width, h = lapBM.height
        guard edgeBM.width == w, edgeBM.height == h else { return 100 }
        guard let lapData  = lapBM.dataProvider?.data,  let lapPtr  = CFDataGetBytePtr(lapData),
              let edgeData = edgeBM.dataProvider?.data, let edgePtr = CFDataGetBytePtr(edgeData)
        else { return 100 }

        let pixelCount   = w * h
        let edgeTreshold: UInt8 = 20          // pixels with Sobel > 20/255 are "edge pixels"
        let minEdgePixels = max(50, pixelCount / 50)  // require ≥ 2% edge coverage

        var sum: Double = 0, sumSq: Double = 0, edgePixels = 0

        for i in 0..<pixelCount {
            // Take the max of R/G/B channels from the edge image as edge magnitude
            let em = Swift.max(edgePtr[i * 4], edgePtr[i * 4 + 1], edgePtr[i * 4 + 2])
            guard em > edgeTreshold else { continue }
            let v = Double(lapPtr[i * 4])
            sum   += v
            sumSq += v * v
            edgePixels += 1
        }

        guard edgePixels >= minEdgePixels else {
            // Featureless image (solid background, etc.) — not blurry, just has no content.
            return 300.0
        }

        let mean = sum / Double(edgePixels)
        return (sumSq / Double(edgePixels)) - (mean * mean)
    }

    // Fallback: global Laplacian variance (used when CIEdges is unavailable)
    private static func globalLaplacianVariance(lapOut: CIImage, extent: CGRect) -> Double {
        guard let bm   = ciContext.createCGImage(lapOut, from: extent),
              let data = bm.dataProvider?.data,
              let ptr  = CFDataGetBytePtr(data) else { return 100 }
        let count = bm.width * bm.height
        var sum: Double = 0, sumSq: Double = 0
        for i in 0..<count {
            let v = Double(ptr[i * 4])
            sum += v; sumSq += v * v
        }
        let mean = sum / Double(count)
        return (sumSq / Double(count)) - (mean * mean)
    }

    // MARK: - Histogram-based exposure detection
    //
    // Measures the fraction of "very dark" (luma < 10) and "very bright" (luma > 245)
    // pixels.  Unlike a simple average, this correctly handles:
    //   • Silhouette photos  — low mean but NOT under-exposed
    //   • Snow / white bg    — high mean but NOT over-exposed
    //   • Half sky / ground  — normal mean but could be both extremes (high contrast, OK)
    private static func exposureFromHistogram(cgImage: CGImage) -> (isUnderExposed: Bool, isOverExposed: Bool, isGoodExposure: Bool) {
        let ciImage = CIImage(cgImage: cgImage)

        // Render to a small known-format bitmap; 64×64 is more than enough for statistics
        let scale = 64.0 / Double(max(cgImage.width, cgImage.height, 1))
        let scaledCI = ciImage.samplingLinear()
            .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let sw = Int(scaledCI.extent.width.rounded()),
            sh = Int(scaledCI.extent.height.rounded())
        guard sw > 0, sh > 0 else { return (false, false, true) }

        var pixels = [UInt8](repeating: 0, count: sw * sh * 4)
        ciContext.render(scaledCI,
                         toBitmap: &pixels,
                         rowBytes: sw * 4,
                         bounds: scaledCI.extent,
                         format: .RGBA8,
                         colorSpace: CGColorSpaceCreateDeviceRGB())

        let total = sw * sh
        var darkCount = 0, brightCount = 0

        for i in 0..<total {
            let r = Double(pixels[i * 4])
            let g = Double(pixels[i * 4 + 1])
            let b = Double(pixels[i * 4 + 2])
            let lum = 0.299 * r + 0.587 * g + 0.114 * b
            if lum < 10  { darkCount   += 1 }
            if lum > 245 { brightCount += 1 }
        }

        let darkRatio   = Double(darkCount)   / Double(total)
        let brightRatio = Double(brightCount) / Double(total)

        // High-contrast scene (silhouette against sky): both extremes present → not an error
        let isBothExtreme = darkRatio   > ScoringConfig.bothExtremesDarkMin
                         && brightRatio > ScoringConfig.bothExtremesBrightMin
        let isUnder = !isBothExtreme && darkRatio   > ScoringConfig.underExposedDarkRatio
        let isOver  = !isBothExtreme && brightRatio > ScoringConfig.overExposedBrightRatio
        let isGood  = !isUnder && !isOver
                   && darkRatio   < ScoringConfig.goodExposureDarkMax
                   && brightRatio < ScoringConfig.goodExposureBrightMax

        return (isUnder, isOver, isGood)
    }

    // MARK: - Detect duplicates using feature print (with hash fallback)
    func findDuplicates(assets: [PhotoAsset]) async -> [PhotoGroup] {
        struct Candidate {
            let asset: PhotoAsset
            let feature: VNFeaturePrintObservation?
            let hash: UInt64?
            let fileSize: Int64
        }

        let images = assets.filter { $0.asset.mediaType == .image }
        guard images.count > 1 else { return [] }

        // Bucket by coarse temporal neighborhood + dimensions to reduce comparisons.
        var buckets: [String: [PhotoAsset]] = [:]
        for photo in images {
            let ts = Int(photo.creationDate.timeIntervalSince1970 / ScoringConfig.duplicateCandidateTimeBucketSeconds)
            let key = "\(photo.asset.pixelWidth)x\(photo.asset.pixelHeight)-\(ts)"
            buckets[key, default: []].append(photo)
        }

        var result: [PhotoGroup] = []
        for bucket in buckets.values where bucket.count > 1 {
            var candidates: [Candidate] = []
            for photo in bucket {
                let feature = await featurePrint(for: photo.asset)
                let hash = await perceptualHash(for: photo.asset)
                if feature == nil && hash == nil { continue }
                let fileSize = assetFileSize(photo.asset) ?? photo.sizeBytes
                candidates.append(Candidate(asset: photo, feature: feature, hash: hash, fileSize: fileSize))
            }
            guard candidates.count > 1 else { continue }

            var used = Set<String>()
            for i in candidates.indices {
                let base = candidates[i]
                guard !used.contains(base.asset.id) else { continue }

                var cluster: [PhotoAsset] = [base.asset]
                used.insert(base.asset.id)

                for j in (i + 1)..<candidates.count {
                    let other = candidates[j]
                    guard !used.contains(other.asset.id) else { continue }

                    let sizeDelta = abs(base.fileSize - other.fileSize)
                    guard sizeDelta <= ScoringConfig.duplicateMaxFileSizeDeltaBytes else { continue }

                    let byFeature: Bool = {
                        guard let a = base.feature, let b = other.feature,
                              let d = featureDistance(a, b) else { return false }
                        return d <= ScoringConfig.duplicateMaxFeatureDistance
                    }()
                    let byHash: Bool = {
                        guard let a = base.hash, let b = other.hash else { return false }
                        return hammingDistance(a, b) <= ScoringConfig.duplicateMaxHashDistance
                    }()

                    if byFeature || byHash {
                        cluster.append(other.asset)
                        used.insert(other.asset.id)
                    }
                }

                if cluster.count > 1 {
                    var sorted = cluster.sorted { $0.score > $1.score }
                    for idx in 1..<sorted.count { sorted[idx].isSelected = true }
                    result.append(PhotoGroup(assets: sorted, groupType: .duplicate))
                }
            }
        }
        return result
    }

    // MARK: - Detect similar using feature print
    func findSimilar(assets: [PhotoAsset]) async -> [PhotoGroup] {
        struct SimilarPhoto {
            let photo: PhotoAsset
            let feature: VNFeaturePrintObservation?
            let hash: UInt64?
        }

        let images = assets.filter { $0.asset.mediaType == .image }
        guard images.count > 1 else { return [] }

        var candidates: [SimilarPhoto] = []
        for photo in images.sorted(by: { $0.creationDate < $1.creationDate }) {
            let feature = await featurePrint(for: photo.asset)
            let hash = await perceptualHash(for: photo.asset)
            candidates.append(SimilarPhoto(photo: photo, feature: feature, hash: hash))
        }
        guard candidates.count > 1 else { return [] }

        var result: [PhotoGroup] = []
        var current: [PhotoAsset] = [candidates[0].photo]
        var last = candidates[0]

        for idx in 1..<candidates.count {
            let item = candidates[idx]
            let dt = item.photo.creationDate.timeIntervalSince(last.photo.creationDate)
            let byFeature: Bool = {
                guard let a = item.feature, let b = last.feature,
                      let d = featureDistance(a, b) else { return false }
                return d <= ScoringConfig.similarMaxFeatureDistance
            }()
            let byHash: Bool = {
                guard let a = item.hash, let b = last.hash else { return false }
                return hammingDistance(a, b) <= ScoringConfig.similarMaxHashDistance
            }()

            let isNeighborFrame = dt <= ScoringConfig.similarCaptureGapSeconds &&
                (byFeature || byHash)

            if isNeighborFrame {
                current.append(item.photo)
            } else {
                if current.count > 1 {
                    var sorted = current.sorted { $0.score > $1.score }
                    for k in 1..<sorted.count { sorted[k].isSelected = true }
                    result.append(PhotoGroup(assets: sorted, groupType: .similar))
                }
                current = [item.photo]
            }
            last = item
        }

        if current.count > 1 {
            var sorted = current.sorted { $0.score > $1.score }
            for k in 1..<sorted.count { sorted[k].isSelected = true }
            result.append(PhotoGroup(assets: sorted, groupType: .similar))
        }

        return result
    }

    // MARK: - Detect low quality
    func findLowQuality(assets: [PhotoAsset], qualityMap: [String: QualitySignals]) -> [PhotoAsset] {
        assets
            // Hard exclusions (same logic as screenshots):
            //   • Screenshots  → belong to Screenshot Cleanup
            //   • Favourites   → user explicitly wants to keep them
            //   • hasAdjustments → user spent time editing; can't be a waste photo
            .filter {
                $0.score < ScoringConfig.lowQualityThreshold &&
                !$0.asset.mediaSubtypes.contains(.photoScreenshot) &&
                !$0.asset.isFavorite &&
                !$0.asset.hasAdjustments
            }
            .map { asset in
                var a = asset
                a.isSelected = true
                if let q = qualityMap[a.id] {
                    // Priority: blur is the most important signal in low-quality routing.
                    if q.isBlurry {
                        a.reason = .blurry
                    } else if q.isShaky {
                        a.reason = .shaky
                    } else if q.isFocusFailed {
                        a.reason = .focusFail
                    } else if q.isOverExposed || q.isUnderExposed {
                        a.reason = .exposure
                    } else {
                        a.reason = .blurry
                    }
                } else {
                    a.reason = .blurry
                }
                return a
            }
    }

    // MARK: - Screenshot semantic classification (local Vision heuristics)
    func classifyScreenshot(_ asset: PHAsset) async -> ScreenshotCategory {
        guard let cg = await requestCGImage(asset: asset, targetSize: CGSize(width: 768, height: 768)) else {
            return .other
        }

        if containsQRCode(cgImage: cg) {
            return .qrCode
        }

        let textLines = recognizeTextLines(cgImage: cg)
        let textBlob = textLines.joined(separator: " ").lowercased()
        if isReceipt(textBlob) {
            return .receipt
        }

        let labels = classifyLabels(cgImage: cg)
        if labels.contains(where: { id in
            let s = id.lowercased()
            return s.contains("handwriting") || s.contains("handwritten") || s.contains("calligraphy")
        }) {
            return .handwriting
        }

        if textLines.count >= 3 && (hasDocumentRectangle(cgImage: cg) || textBlob.count > 30) {
            return .document
        }

        if labels.contains(where: { id in
            let s = id.lowercased()
            return s.contains("illustration") || s.contains("drawing") || s.contains("sketch") || s.contains("cartoon")
        }) {
            return .illustration
        }

        return .other
    }

    // MARK: - Delete assets
    func deleteAssets(_ assets: [PhotoAsset]) async throws {
        let phAssets = assets.map { $0.asset }
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(phAssets as NSArray)
        }
    }

    // MARK: - Convert Live Photo to static
    func convertLivePhotoToStatic(_ asset: PHAsset) async throws {
        // Export the still image component
        let opts = PHLivePhotoRequestOptions()
        opts.deliveryMode = .highQualityFormat
        // In production: use PHAssetChangeRequest to strip Live component
        // Simulated here for demo
        try await Task.sleep(nanoseconds: 500_000_000)
    }

    // MARK: - Compress video
    func compressVideo(_ asset: PHAsset, quality: Float) async throws -> URL {
        let opts = PHVideoRequestOptions()
        opts.deliveryMode = .highQualityFormat
        return try await withCheckedThrowingContinuation { cont in
            PHImageManager.default().requestAVAsset(forVideo: asset, options: opts) { avAsset, _, _ in
                guard let avAsset = avAsset else {
                    cont.resume(throwing: NSError(domain: "PhotoCleaner", code: 1))
                    return
                }
                let preset = quality > 0.7 ? AVAssetExportPreset1920x1080 :
                             quality > 0.4 ? AVAssetExportPreset1280x720 :
                                             AVAssetExportPreset960x540
                guard let export = AVAssetExportSession(asset: avAsset, presetName: preset) else {
                    cont.resume(throwing: NSError(domain: "PhotoCleaner", code: 2))
                    return
                }
                let url = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString + ".mp4")
                export.outputURL = url
                export.outputFileType = .mp4
                export.exportAsynchronously {
                    if export.status == .completed {
                        cont.resume(returning: url)
                    } else {
                        cont.resume(throwing: export.error ?? NSError(domain: "PhotoCleaner", code: 3))
                    }
                }
            }
        }
    }

    // MARK: - Perceptual hash helpers
    private func perceptualHash(for asset: PHAsset) async -> UInt64? {
        guard let image = await requestImageWithTimeout(
            for: asset,
            targetSize: CGSize(width: ScoringConfig.hashThumbnailWidth, height: ScoringConfig.hashThumbnailHeight),
            contentMode: .aspectFit,
            timeout: imageRequestTimeout,
            configure: { opts in
                opts.deliveryMode = .fastFormat
                opts.resizeMode = .fast
            }
        ), let cg = image.cgImage else {
            return nil
        }
        return Self.dHash(cgImage: cg)
    }

    private func featurePrint(for asset: PHAsset) async -> VNFeaturePrintObservation? {
        guard let image = await requestImageWithTimeout(
            for: asset,
            targetSize: CGSize(
                width: ScoringConfig.featurePrintInputSize,
                height: ScoringConfig.featurePrintInputSize
            ),
            contentMode: .aspectFit,
            timeout: imageRequestTimeout,
            configure: { opts in
                opts.deliveryMode = .highQualityFormat
                opts.resizeMode = .exact
            }
        ), let cg = image.cgImage else {
            return nil
        }

        let req = VNGenerateImageFeaturePrintRequest()
        let handler = VNImageRequestHandler(cgImage: cg, options: [:])
        do {
            try handler.perform([req])
            return req.results?.first as? VNFeaturePrintObservation
        } catch {
            return nil
        }
    }

    private static func dHash(cgImage: CGImage) -> UInt64 {
        let width = 9
        let height = 8
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)

        guard let ctx = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return 0
        }

        ctx.interpolationQuality = .low
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        @inline(__always)
        func luma(atX x: Int, y: Int) -> Double {
            let offset = y * bytesPerRow + x * bytesPerPixel
            let r = Double(pixels[offset])
            let g = Double(pixels[offset + 1])
            let b = Double(pixels[offset + 2])
            return 0.299 * r + 0.587 * g + 0.114 * b
        }

        var hash: UInt64 = 0
        var bitIndex: UInt64 = 0
        for y in 0..<height {
            for x in 0..<(width - 1) {
                let left = luma(atX: x, y: y)
                let right = luma(atX: x + 1, y: y)
                if left > right {
                    hash |= (1 << bitIndex)
                }
                bitIndex += 1
            }
        }
        return hash
    }

    private func assetFileSize(_ asset: PHAsset) -> Int64? {
        let resources = PHAssetResource.assetResources(for: asset)
        guard !resources.isEmpty else { return nil }

        // Prefer the primary resource for the media type; fallback to the largest resource.
        let preferredTypes: Set<PHAssetResourceType> = {
            if asset.mediaType == .video {
                return [.video, .fullSizeVideo]
            }
            return [.photo, .fullSizePhoto]
        }()

        var preferredMax: Int64 = 0
        var overallMax: Int64 = 0
        for resource in resources {
            guard let bytes = (resource.value(forKey: "fileSize") as? NSNumber)?.int64Value, bytes > 0 else {
                continue
            }
            overallMax = max(overallMax, bytes)
            if preferredTypes.contains(resource.type) {
                preferredMax = max(preferredMax, bytes)
            }
        }
        if preferredMax > 0 { return preferredMax }
        return overallMax > 0 ? overallMax : nil
    }

    private func hammingDistance(_ a: UInt64, _ b: UInt64) -> Int {
        Int((a ^ b).nonzeroBitCount)
    }

    private func featureDistance(_ a: VNFeaturePrintObservation, _ b: VNFeaturePrintObservation) -> Float? {
        var distance: Float = 0
        do {
            try a.computeDistance(&distance, to: b)
            return distance
        } catch {
            return nil
        }
    }

    private func requestCGImage(asset: PHAsset, targetSize: CGSize) async -> CGImage? {
        let image = await requestImageWithTimeout(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFit,
            timeout: imageRequestTimeout,
            configure: { opts in
                opts.deliveryMode = .highQualityFormat
                opts.resizeMode = .fast
            }
        )
        return image?.cgImage
    }

    private func requestImageWithTimeout(
        for asset: PHAsset,
        targetSize: CGSize,
        contentMode: PHImageContentMode,
        timeout: TimeInterval,
        configure: ((PHImageRequestOptions) -> Void)? = nil
    ) async -> UIImage? {
        await withCheckedContinuation { cont in
            let manager = PHImageManager.default()
            let opts = PHImageRequestOptions()
            opts.deliveryMode = .opportunistic
            opts.resizeMode = .fast
            opts.isSynchronous = false
            opts.isNetworkAccessAllowed = true
            configure?(opts)

            let lock = NSLock()
            var finished = false
            var requestID: PHImageRequestID = PHInvalidImageRequestID
            var timeoutTask: Task<Void, Never>?

            func finish(_ image: UIImage?) {
                lock.lock()
                guard !finished else {
                    lock.unlock()
                    return
                }
                finished = true
                let id = requestID
                let timer = timeoutTask
                lock.unlock()

                timer?.cancel()
                if id != PHInvalidImageRequestID {
                    manager.cancelImageRequest(id)
                }
                cont.resume(returning: image)
            }

            requestID = manager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: contentMode,
                options: opts
            ) { image, info in
                if (info?[PHImageCancelledKey] as? Bool) == true {
                    finish(nil)
                    return
                }
                if info?[PHImageErrorKey] != nil {
                    finish(nil)
                    return
                }
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) == true
                if isDegraded { return }
                finish(image)
            }

            let timeoutNs = UInt64(max(timeout, 1) * 1_000_000_000)
            timeoutTask = Task(priority: .utility) {
                try? await Task.sleep(nanoseconds: timeoutNs)
                finish(nil)
            }
        }
    }

    private func containsQRCode(cgImage: CGImage) -> Bool {
        let ci = CIImage(cgImage: cgImage)
        let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyLow])
        let features = detector?.features(in: ci) ?? []
        return !features.isEmpty
    }

    private func recognizeTextLines(cgImage: CGImage) -> [String] {
        let req = VNRecognizeTextRequest()
        req.recognitionLevel = .fast
        req.usesLanguageCorrection = false
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([req])
        let obs = req.results ?? []
        return obs.compactMap { $0.topCandidates(1).first?.string.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func classifyLabels(cgImage: CGImage) -> [String] {
        let req = VNClassifyImageRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([req])
        return (req.results ?? []).prefix(8).map { $0.identifier }
    }

    private func hasDocumentRectangle(cgImage: CGImage) -> Bool {
        let req = VNDetectRectanglesRequest()
        req.minimumAspectRatio = 0.5
        req.maximumAspectRatio = 1.8
        req.minimumConfidence = 0.45
        req.maximumObservations = 3
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([req])
        return !(req.results ?? []).isEmpty
    }

    private func isReceipt(_ text: String) -> Bool {
        let keys = [
            "receipt", "invoice", "total", "subtotal", "tax", "amount", "paid",
            "收据", "发票", "合计", "小计", "税", "实付", "支付", "金额"
        ]
        return keys.contains { text.contains($0) }
    }
}
