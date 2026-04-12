import Photos
import Vision
import CoreImage
import UIKit

/// Central service that reads PHPhotoLibrary and performs AI scoring.
/// All heavy work happens on a background queue; results are published on main.
class PhotoLibraryService: ObservableObject {

    static let shared = PhotoLibraryService()
    private init() {}

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
        return await withCheckedContinuation { cont in
            let opts = PHImageRequestOptions()
            opts.deliveryMode = .opportunistic
            opts.isSynchronous = false
            opts.isNetworkAccessAllowed = true

            // 384×384 is sufficient for blur/exposure/Vision — 64% fewer pixels than 640×640
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: 384, height: 384),
                contentMode: .aspectFit,
                options: opts
            ) { image, info in
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) == true
                if isDegraded { return }
                guard let image = image, let cgImage = image.cgImage else {
                    cont.resume(returning: ScoreResult(
                        score: 50,
                        isBlurry: false,
                        isOverExposed: false,
                        isUnderExposed: false,
                        hasFaces: false,
                        isShaky: false,
                        isFocusFailed: false
                    ))
                    return
                }
                let result = Self.computeScore(cgImage: cgImage, asset: asset)
                cont.resume(returning: result)
            }
        }
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
    //   Screenshot (low-value content)       →  20–45
    private static func computeScore(cgImage: CGImage, asset: PHAsset) -> ScoreResult {
        // ── Run face detection + classification in ONE handler pass ──────
        // Previously called VNClassifyImageRequest twice (detectPet + aestheticBonus).
        // Batching both into a single VNImageRequestHandler lets Vision share the
        // neural engine pipeline and cuts Vision time roughly in half.
        let faceRequest     = VNDetectFaceRectanglesRequest()
        let classifyRequest = VNClassifyImageRequest()
        let handler         = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([faceRequest, classifyRequest])

        let faceCount       = faceRequest.results?.count ?? 0
        let classifications = classifyRequest.results ?? []

        // Pet detection from shared classify results (no second Vision call)
        let petKeywords = ["dog","cat","animal","bird","rabbit","hamster","pet","puppy","kitten"]
        let hasPet = classifications.contains { obs in
            obs.confidence > 0.4 && petKeywords.contains(where: { obs.identifier.lowercased().contains($0) })
        }

        // Aesthetic bonus from shared classify results
        let aesthetic = min(12, classifications.prefix(5).filter { $0.confidence > 0.7 }.count * 5)

        let blur           = laplacianVariance(cgImage: cgImage)
        let (meanL, _)     = exposureStats(cgImage: cgImage)
        let isBlurry       = blur < ScoringConfig.blurSevereThreshold
        let isSlightBlurry = blur >= ScoringConfig.blurSevereThreshold && blur < ScoringConfig.blurSlightThreshold
        let isVerySharp    = blur >= ScoringConfig.blurSharpThreshold
        let isFocusFailed  = blur < (ScoringConfig.blurSevereThreshold * 0.7)
        let isShaky        = blur >= (ScoringConfig.blurSevereThreshold * 0.7) && blur < ScoringConfig.blurSlightThreshold
        let isUnderExposed = meanL < ScoringConfig.underExposureThreshold
        let isOverExposed  = meanL > ScoringConfig.overExposureThreshold
        let isGoodExposure = meanL >= ScoringConfig.goodExposureLowerBound && meanL <= ScoringConfig.goodExposureUpperBound
        let isScreenshot   = asset.mediaSubtypes.contains(.photoScreenshot)
        let isPanorama     = asset.mediaSubtypes.contains(.photoPanorama)
        let isLivePhoto    = asset.mediaSubtypes.contains(.photoLive)
        let isFav          = asset.isFavorite

        var score = ScoringConfig.baseScore

        // ── 1. Emotional / content-subject bonus ──────────────────────────
        if isFav               { score += ScoringConfig.favoriteBonus }
        else if faceCount >= 2 { score += ScoringConfig.multiFaceBonus }
        else if faceCount == 1 { score += ScoringConfig.singleFaceBonus }
        else if hasPet         { score += ScoringConfig.petBonus }

        // ── 2. Content-type adjustment ─────────────────────────────────────
        if isScreenshot      { score -= ScoringConfig.screenshotPenalty }
        else if isPanorama   { score += ScoringConfig.panoramaBonus }
        else if isLivePhoto  { score += ScoringConfig.livePhotoBonus }

        // ── 3. Image quality (biggest swing: ±30) ─────────────────────────
        if isBlurry            { score -= ScoringConfig.severeBlurPenalty }
        else if isSlightBlurry { score -= ScoringConfig.slightBlurPenalty }
        else if isVerySharp    { score += ScoringConfig.verySharpBonus }
        else                   { score += ScoringConfig.normalSharpnessBonus }

        if isUnderExposed || isOverExposed { score -= ScoringConfig.badExposurePenalty }
        else if isGoodExposure             { score += ScoringConfig.goodExposureBonus }

        // ── 4. Aesthetic bonus (0–12) ──────────────────────────────────────
        score += aesthetic

        // ── 5. Redundancy / depreciation penalties ────────────────────────
        if asset.mediaType == .video && asset.duration < 3 { score -= ScoringConfig.shortVideoPenalty }
        // Time weight: only apply age decay when the user has enabled it in Settings
        if AppConfig.timeWeight, let date = asset.creationDate {
            let years = max(0, Calendar.current.dateComponents([.year], from: date, to: Date()).year ?? 0)
            if years > ScoringConfig.agePenaltyStartYears && !isFav && faceCount == 0 {
                score -= min(
                    ScoringConfig.maxAgePenalty,
                    (years - ScoringConfig.agePenaltyStartYears) * ScoringConfig.agePenaltyPerYear
                )
            }
        }

        return ScoreResult(
            score: max(ScoringConfig.minScore, min(ScoringConfig.maxScore, score)),
            isBlurry: isBlurry,
            isOverExposed: isOverExposed,
            isUnderExposed: isUnderExposed,
            hasFaces: faceCount > 0,
            isShaky: isShaky,
            isFocusFailed: isFocusFailed
        )
    }

    // MARK: - Laplacian variance for blur detection (uses shared CIContext)
    private static func laplacianVariance(cgImage: CGImage) -> Double {
        let ciImage = CIImage(cgImage: cgImage)
        guard let filter = CIFilter(name: "CILaplacian") else { return 100 }
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        guard let output = filter.outputImage,
              let bm = ciContext.createCGImage(output, from: output.extent) else { return 100 }
        let w = bm.width, h = bm.height
        guard let data = bm.dataProvider?.data,
              let ptr  = CFDataGetBytePtr(data) else { return 100 }
        let count = w * h
        var sum: Double = 0, sumSq: Double = 0
        for i in 0..<count {
            let v = Double(ptr[i * 4])
            sum += v; sumSq += v * v
        }
        let mean = sum / Double(count)
        return (sumSq / Double(count)) - (mean * mean)
    }

    // MARK: - Exposure stats (uses shared CIContext)
    private static func exposureStats(cgImage: CGImage) -> (mean: Double, stdDev: Double) {
        let ciImage = CIImage(cgImage: cgImage)
        let filter = CIFilter(name: "CIAreaAverage",
                              parameters: [kCIInputImageKey: ciImage,
                                           kCIInputExtentKey: CIVector(cgRect: ciImage.extent)])
        guard let output = filter?.outputImage else { return (128, 30) }
        var pixel = [UInt8](repeating: 0, count: 4)
        ciContext.render(output, toBitmap: &pixel, rowBytes: 4,
                         bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                         format: .RGBA8, colorSpace: nil)
        let lum = 0.299 * Double(pixel[0]) + 0.587 * Double(pixel[1]) + 0.114 * Double(pixel[2])
        return (lum, 30)
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
            // Screenshots must stay in Screenshot Cleanup when metadata marks them as screenshot.
            .filter {
                $0.score < ScoringConfig.lowQualityThreshold &&
                !$0.asset.mediaSubtypes.contains(.photoScreenshot)
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
        await withCheckedContinuation { cont in
            let opts = PHImageRequestOptions()
            opts.deliveryMode = .fastFormat
            opts.resizeMode = .fast
            opts.isSynchronous = false
            opts.isNetworkAccessAllowed = true

            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: ScoringConfig.hashThumbnailWidth, height: ScoringConfig.hashThumbnailHeight),
                contentMode: .aspectFit,
                options: opts
            ) { image, info in
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) == true
                if isDegraded { return }
                guard let cg = image?.cgImage else {
                    cont.resume(returning: nil)
                    return
                }
                cont.resume(returning: Self.dHash(cgImage: cg))
            }
        }
    }

    private func featurePrint(for asset: PHAsset) async -> VNFeaturePrintObservation? {
        await withCheckedContinuation { cont in
            let opts = PHImageRequestOptions()
            opts.deliveryMode = .highQualityFormat
            opts.resizeMode = .exact
            opts.isSynchronous = false
            opts.isNetworkAccessAllowed = true

            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(
                    width: ScoringConfig.featurePrintInputSize,
                    height: ScoringConfig.featurePrintInputSize
                ),
                contentMode: .aspectFit,
                options: opts
            ) { image, info in
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) == true
                if isDegraded { return }
                guard let cg = image?.cgImage else {
                    cont.resume(returning: nil)
                    return
                }

                let req = VNGenerateImageFeaturePrintRequest()
                let handler = VNImageRequestHandler(cgImage: cg, options: [:])
                do {
                    try handler.perform([req])
                    cont.resume(returning: req.results?.first as? VNFeaturePrintObservation)
                } catch {
                    cont.resume(returning: nil)
                }
            }
        }
    }

    private static func dHash(cgImage: CGImage) -> UInt64 {
        let width = 9
        let height = 8
        let bytesPerPixel = 1
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: width * height)

        guard let ctx = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return 0
        }

        ctx.interpolationQuality = .low
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var hash: UInt64 = 0
        var bitIndex: UInt64 = 0
        for y in 0..<height {
            let row = y * width
            for x in 0..<(width - 1) {
                let left = pixels[row + x]
                let right = pixels[row + x + 1]
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
        await withCheckedContinuation { cont in
            let opts = PHImageRequestOptions()
            opts.deliveryMode = .highQualityFormat
            opts.resizeMode = .fast
            opts.isSynchronous = false
            opts.isNetworkAccessAllowed = true

            PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFit,
                options: opts
            ) { image, info in
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) == true
                if isDegraded { return }
                cont.resume(returning: image?.cgImage)
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
