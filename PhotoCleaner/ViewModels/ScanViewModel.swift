import SwiftUI
import Photos
import Combine

@MainActor
class ScanViewModel: ObservableObject {
    @Published var phase: ScanPhase = .idle
    @Published var progress: Double = 0
    @Published var phaseLabel: String = L10n.scanPhase1
    @Published var analyzedCount: Int = 0
    @Published var summary: LibrarySummary = LibrarySummary()
    @Published var authorized: Bool = false
    @Published var scanElapsedSeconds: Int = 0
    @Published var lastScanDurationSeconds: Int = 0
    @Published var isBackgroundAnalyzing: Bool = false
    @Published var backgroundProgress: Double = 0
    @Published var backgroundLabel: String = ""
    @Published private(set) var isUserInteractingInDetail: Bool = false
    @Published private(set) var timelineVisibleAssets: [PhotoAsset] = []
    @Published private(set) var timelineCanShowAssets: Bool = false

    @Published var duplicateGroups: [PhotoGroup] = []
    @Published var similarGroups:   [PhotoGroup] = []
    @Published var screenshots:     [PhotoAsset] = []
    @Published var videos:          [PhotoAsset] = []
    @Published var lowQuality:      [PhotoAsset] = []
    @Published var favorites:       [PhotoAsset] = []
    @Published var behaviorAssets:  [PhotoAsset] = []
    @Published var allAssets:       [PhotoAsset] = []

    private let service = PhotoLibraryService.shared
    private let store   = PhotoStore.shared
    private var scanTask: Task<Void, Never>?
    private var backgroundAnalysisTask: Task<Void, Never>?
    private var scanClockTask: Task<Void, Never>?
    private var metadataWarmupTask: Task<Void, Never>?
    private var launchIncrementalSyncTask: Task<Void, Never>?
    private let timelineRevealSeconds = 20
    private var cancellables = Set<AnyCancellable>()

    var scanElapsedText: String {
        Self.formatDuration(scanElapsedSeconds)
    }

    var lastScanDurationText: String {
        Self.formatDuration(lastScanDurationSeconds)
    }

    init() {
        // Keep derived arrays in sync when LibraryViewModel (or any other caller)
        // deletes assets through the shared PhotoStore.
        store.$lastDeletedIds
            .dropFirst()
            .filter { !$0.isEmpty }
            .sink { [weak self] (ids: Set<String>) in
                guard let self, self.phase == .done else { return }
                self.allAssets = self.store.allAssets
                self.pruneArrays(removingIds: ids)
            }
            .store(in: &cancellables)
    }

    // MARK: - Authorization

    /// Request photo-library permission as early as app launch (Home tab),
    /// so users won't see the system prompt when entering Timeline later.
    func requestAuthorizationOnAppLaunchIfNeeded() async {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch status {
        case .authorized, .limited:
            authorized = true
            if phase == .idle, !isBackgroundAnalyzing {
                startMetadataWarmupIfNeeded()
            }
        case .notDetermined:
            authorized = await service.requestAuthorization()
            if authorized, phase == .idle, !isBackgroundAnalyzing {
                startMetadataWarmupIfNeeded()
            }
        default:
            authorized = false
        }
    }

    /// Background incremental sync on app launch:
    /// - only score/process photos never scanned before
    /// - only check existence for previously scanned photos
    func startIncrementalSyncOnAppLaunchIfNeeded() {
        guard launchIncrementalSyncTask == nil else { return }
        guard phase == .idle, !isBackgroundAnalyzing else { return }
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else { return }
        launchIncrementalSyncTask = Task(priority: .utility) { [weak self] in
            guard let self else { return }
            defer {
                Task { @MainActor [weak self] in
                    self?.launchIncrementalSyncTask = nil
                }
            }
            await self.performIncrementalLaunchSync()
        }
    }

    // MARK: - Restore last scan from DB on app launch

    /// Loads the last scan results from the local database without re-scanning.
    /// Call this when the view appears so results are available immediately.
    func loadCachedResultsIfAvailable() async {
        guard phase == .idle else { return }

        // Requires photo library authorization
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else { return }
        authorized = true

        guard await DatabaseService.shared.loadLatestScanRecord() != nil else { return }

        // Fetch current assets and apply cached scores
        let raw = await service.fetchAllAssets()
        guard !raw.isEmpty else { return }

        let ids = raw.map { $0.id }
        let cached = await DatabaseService.shared.loadScores(for: ids)
        guard !cached.isEmpty else { return }

        let metadata = await DatabaseService.shared.loadMetadata(for: ids)
        let scored = raw.map { a -> PhotoAsset in
            var a = a
            if let c = cached[a.id] {
                a.score = c.score
                a.isSelected = LibraryViewModel.shouldAutoSelect(score: c.score, hasFaces: c.hasFaces)
                a.fileSizeBytes = c.fileSizeBytes ?? metadata[a.id]?.fileSizeBytes
            } else if let m = metadata[a.id] {
                a.fileSizeBytes = m.fileSizeBytes
            }
            return a
        }
        store.setAssets(scored)
        allAssets = scored
        timelineVisibleAssets = scored
        timelineCanShowAssets = true

        // Reconstruct groups from DB, filtering out any assets that no longer exist
        let assetMap = Dictionary(uniqueKeysWithValues: scored.map { ($0.id, $0) })
        let rows = await DatabaseService.shared.loadGroupRows()
        let (dups, sims) = rebuildGroups(from: rows, assetMap: assetMap)
        let nonFavorite = scored.filter { !$0.asset.isFavorite }
        duplicateGroups = dups.map { filteredGroupExcludingFavorites($0) }.filter { $0.assets.count >= 2 }
        similarGroups   = sims.map { filteredGroupExcludingFavorites($0) }.filter { $0.assets.count >= 2 }

        screenshots = nonFavorite.filter { $0.asset.mediaSubtypes.contains(.photoScreenshot) }
            .map { var a = $0; a.isSelected = a.score < 45; return a }
        videos = nonFavorite.filter { $0.asset.mediaType == .video }
            .sorted { $0.sizeBytes > $1.sizeBytes }
            .map { var a = $0; a.isSelected = false; return a }
        let qualityMap: [String: PhotoLibraryService.QualitySignals] = cached.mapValues {
            PhotoLibraryService.QualitySignals(
                isBlurry: $0.isBlurry,
                isShaky: $0.isBlurry && !$0.isOverExposed && !$0.isUnderExposed,
                isFocusFailed: $0.isBlurry,
                isOverExposed: $0.isOverExposed,
                isUnderExposed: $0.isUnderExposed
            )
        }
        lowQuality = service.findLowQuality(assets: nonFavorite, qualityMap: qualityMap)
        behaviorAssets = buildBehaviorAssets(
            from: nonFavorite,
            excludingIDs: occupiedAssetIDsForOtherCategories(
                duplicateGroups: duplicateGroups,
                similarGroups: similarGroups,
                screenshots: screenshots,
                videos: videos,
                lowQuality: lowQuality
            )
        )
        favorites = scored
            .filter { $0.asset.isFavorite }
            .map { var a = $0; a.isSelected = false; return a }

        buildSummary(assets: scored)
        isBackgroundAnalyzing = false
        backgroundProgress = 0
        backgroundLabel = ""
        phase = .done
        startBackgroundFileSizeHydration()
    }

    func startScan() {
        guard phase != .scanning else { return }
        scanTask = Task { await runScan() }
    }

    func reset() {
        scanTask?.cancel()
        backgroundAnalysisTask?.cancel()
        scanClockTask?.cancel()
        phase = .idle; progress = 0; analyzedCount = 0
        summary = LibrarySummary()
        scanElapsedSeconds = 0
        isBackgroundAnalyzing = false
        backgroundProgress = 0
        backgroundLabel = ""
        duplicateGroups = []; similarGroups = []
        screenshots = []; videos = []; lowQuality = []; favorites = []; behaviorAssets = []; allAssets = []
        timelineVisibleAssets = []
        timelineCanShowAssets = false
    }

    func setDetailInteraction(_ active: Bool) {
        guard isUserInteractingInDetail != active else { return }
        isUserInteractingInDetail = active
    }

    // MARK: - Scan

    private func runScan() async {
        metadataWarmupTask?.cancel()
        metadataWarmupTask = nil
        launchIncrementalSyncTask?.cancel()
        launchIncrementalSyncTask = nil
        backgroundAnalysisTask?.cancel()
        isBackgroundAnalyzing = false
        backgroundProgress = 0
        backgroundLabel = ""
        timelineVisibleAssets = []
        timelineCanShowAssets = false

        let scanStart = Date()
        scanElapsedSeconds = 0
        scanClockTask?.cancel()
        scanClockTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                let elapsed = Int(Date().timeIntervalSince(scanStart))
                await MainActor.run { self.scanElapsedSeconds = elapsed }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }

        phaseLabel = L10n.scanRequestAuth
        authorized = await service.requestAuthorization()
        guard authorized else {
            scanClockTask?.cancel()
            phase = .idle
            return
        }
        phase = .scanning

        // Phase A: first-pass scan (target ~1 minute before showing dashboard)
        phaseLabel = L10n.scanPhaseA
        progress = 0.02
        let raw = await service.fetchAllAssets()
        guard !raw.isEmpty else {
            scanClockTask?.cancel()
            lastScanDurationSeconds = Int(Date().timeIntervalSince(scanStart))
            phase = .done
            return
        }
        allAssets = raw
        progress = 0.08

        let ids = raw.map { $0.id }
        let cached = await DatabaseService.shared.loadScores(for: ids)
        let metadata = await DatabaseService.shared.loadMetadata(for: ids)
        let activeScannedIds = await DatabaseService.shared.loadActiveScannedIds(for: ids)
        progress = 0.14
        let cachedScannedIds = Set(cached.keys)
        if !cachedScannedIds.isEmpty {
            // Backfill scan-state table for users upgrading from older schema.
            await DatabaseService.shared.markAssetsScanned(Array(cachedScannedIds))
        }
        let alreadyScannedIds = activeScannedIds.union(cachedScannedIds)
        let newAssetIDs = Set(ids).subtracting(alreadyScannedIds)

        // Apply cached scores immediately; uncached assets keep neutral score for quick display.
        var scored = raw.map { a -> PhotoAsset in
            var a = a
            if let c = cached[a.id] {
                a.score = c.score
                a.isSelected = LibraryViewModel.shouldAutoSelect(score: c.score, hasFaces: c.hasFaces)
                a.fileSizeBytes = c.fileSizeBytes ?? metadata[a.id]?.fileSizeBytes
            } else if let m = metadata[a.id] {
                a.fileSizeBytes = m.fileSizeBytes
            }
            return a
        }
        var scannedIDs = Set(cached.keys)
        analyzedCount = scannedIDs.count

        let rows = await DatabaseService.shared.loadGroupRows()
        let cachedQualityMap: [String: PhotoLibraryService.QualitySignals] = cached.mapValues {
            PhotoLibraryService.QualitySignals(
                isBlurry: $0.isBlurry,
                isShaky: $0.isBlurry && !$0.isOverExposed && !$0.isUnderExposed,
                isFocusFailed: $0.isBlurry,
                isOverExposed: $0.isOverExposed,
                isUnderExposed: $0.isUnderExposed
            )
        }

        let warmed = await warmupMetadataBeforeReveal(
            scoredAssets: scored,
            scannedIDs: scannedIDs,
            scanStart: scanStart
        )
        scored = warmed.scoredAssets
        scannedIDs = warmed.scannedIDs
        let warmedAssetMap = Dictionary(uniqueKeysWithValues: scored.map { ($0.id, $0) })
        let (warmedDup, warmedSim) = rebuildGroups(from: rows, assetMap: warmedAssetMap)

        publishPartialResults(
            scoredAssets: scored,
            scannedIDs: scannedIDs,
            qualityMap: cachedQualityMap,
            duplicateSeed: warmedDup,
            similarSeed: warmedSim,
            elapsedSeconds: Int(Date().timeIntervalSince(scanStart))
        )

        // Phase B: deep pass in background (duplicates/similar/quality/size calibration)
        isBackgroundAnalyzing = true
        backgroundProgress = 0
        backgroundLabel = L10n.bgDeepAnalysis
        backgroundAnalysisTask?.cancel()
        backgroundAnalysisTask = Task(priority: .utility) { [weak self] in
            guard let self else { return }
            await self.performBackgroundDeepScan(
                raw: raw,
                initialScored: scored,
                cached: cached,
                initialScannedIDs: scannedIDs,
                duplicateSeed: warmedDup,
                similarSeed: warmedSim,
                ids: ids,
                newAssetIDs: newAssetIDs,
                scanStart: scanStart
            )
        }

        // For repeat scans (no new assets), don't keep users on a forced waiting screen.
        // Only keep a short settling window when we truly have new/uncached work.
        let minimumFirstPassSeconds = timelineRevealSeconds
        if minimumFirstPassSeconds > 0 {
            while !Task.isCancelled {
                let elapsed = Int(Date().timeIntervalSince(scanStart))
                if elapsed >= minimumFirstPassSeconds { break }
                let t = Double(elapsed) / Double(max(1, minimumFirstPassSeconds))
                progress = min(0.98, 0.55 + t * 0.43)
                phaseLabel = L10n.scanPhaseACountdown(minimumFirstPassSeconds - elapsed)
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
        guard !Task.isCancelled else {
            scanClockTask?.cancel()
            return
        }
        progress = max(progress, 0.6)
        phase = .done
        if !isBackgroundAnalyzing {
            finalizeScanDuration(scanStart: scanStart)
        }
    }

    private func performBackgroundDeepScan(
        raw: [PhotoAsset],
        initialScored: [PhotoAsset],
        cached: [String: DatabaseService.CachedScore],
        initialScannedIDs: Set<String>,
        duplicateSeed: [PhotoGroup],
        similarSeed: [PhotoGroup],
        ids: [String],
        newAssetIDs: Set<String>,
        scanStart: Date
    ) async {
        var scored = initialScored
        let total = max(raw.count, 1)
        let uncached = (0..<raw.count).filter { cached[raw[$0].id] == nil }
        let baseAnalyzedCount = initialScannedIDs.count
        analyzedCount = baseAnalyzedCount
        var scannedIDs = initialScannedIDs

        var newEntries: [DatabaseService.ScoreEntry] = []
        var qualityMap: [String: PhotoLibraryService.QualitySignals] = [:]
        for (id, c) in cached {
            qualityMap[id] = PhotoLibraryService.QualitySignals(
                isBlurry: c.isBlurry,
                isShaky: c.isBlurry && !c.isOverExposed && !c.isUnderExposed,
                isFocusFailed: c.isBlurry,
                isOverExposed: c.isOverExposed,
                isUnderExposed: c.isUnderExposed
            )
        }

        backgroundLabel = L10n.bgScoring
        backgroundProgress = 0.10

        var nextPos = 0
        var inFlight = 0
        var localVisibleCount = baseAnalyzedCount
        var localScoredCount = max(0, min(total, cached.count))
        var lastPublishedAt = Date.distantPast
        let publishInterval: TimeInterval = 3.0
        var pendingSizeHydrationIndices: [Int] = []

        await withTaskGroup(of: (Int, PhotoLibraryService.ScoreResult).self) { group in
            func enqueueTasksIfNeeded() async {
                // Keep UI responsive while users browse Timeline/Detail during deep scan.
                let limit = await MainActor.run { self.isUserInteractingInDetail ? 2 : 4 }
                while inFlight < limit && nextPos < uncached.count {
                    let i = uncached[nextPos]
                    let asset = raw[i].asset
                    group.addTask {
                        let r = await PhotoLibraryService.shared.score(asset: asset)
                        return (i, r)
                    }
                    inFlight += 1
                    nextPos += 1
                }
            }
            await enqueueTasksIfNeeded()

            while let (idx, result) = await group.next() {
                inFlight = max(0, inFlight - 1)
                if Task.isCancelled { return }
                scored[idx].score = result.score
                scored[idx].isSelected = LibraryViewModel.shouldAutoSelect(
                    score: result.score,
                    hasFaces: result.hasFaces
                )
                if scannedIDs.insert(raw[idx].id).inserted {
                    localVisibleCount += 1
                }
                localScoredCount = min(total, localScoredCount + 1)
                if scored[idx].fileSizeBytes == nil {
                    pendingSizeHydrationIndices.append(idx)
                }

                newEntries.append(DatabaseService.ScoreEntry(
                    localId:        raw[idx].id,
                    score:          result.score,
                    isBlurry:       result.isBlurry,
                    isOverExposed:  result.isOverExposed,
                    isUnderExposed: result.isUnderExposed,
                    hasFaces:       result.hasFaces,
                    fileSizeBytes:  scored[idx].fileSizeBytes
                ))
                qualityMap[raw[idx].id] = PhotoLibraryService.QualitySignals(
                    isBlurry: result.isBlurry,
                    isShaky: result.isShaky,
                    isFocusFailed: result.isFocusFailed,
                    isOverExposed: result.isOverExposed,
                    isUnderExposed: result.isUnderExposed
                )

                let now = Date()
                let reachedInterval = now.timeIntervalSince(lastPublishedAt) >= publishInterval
                let finished = localScoredCount >= total
                if reachedInterval || finished {
                    if !pendingSizeHydrationIndices.isEmpty {
                        let uniquePending = Array(Set(pendingSizeHydrationIndices)).sorted()
                        let pendingBatch = uniquePending.map { scored[$0] }
                        let hydratedBatch = await service.populateFileSizes(for: pendingBatch, limit: pendingBatch.count)
                        for (offset, index) in uniquePending.enumerated() {
                            scored[index] = hydratedBatch[offset]
                        }
                        let sizeEntries: [DatabaseService.FileSizeEntry] = hydratedBatch.compactMap { item in
                            guard let size = item.fileSizeBytes, size > 0 else { return nil }
                            return DatabaseService.FileSizeEntry(localId: item.id, fileSizeBytes: size)
                        }
                        if !sizeEntries.isEmpty {
                            await DatabaseService.shared.saveFileSizes(sizeEntries)
                        }
                        await DatabaseService.shared.upsertAssetMetadata(metadataEntries(from: hydratedBatch))
                        pendingSizeHydrationIndices.removeAll()
                    }

                    analyzedCount = (phase == .done) ? localScoredCount : localVisibleCount
                    backgroundProgress = 0.10 + (Double(localScoredCount) / Double(total)) * 0.45
                    progress = min(0.88, backgroundProgress)
                    publishPartialResults(
                        scoredAssets: scored,
                        scannedIDs: scannedIDs,
                        qualityMap: qualityMap,
                        duplicateSeed: duplicateSeed,
                        similarSeed: similarSeed,
                        elapsedSeconds: Int(Date().timeIntervalSince(scanStart))
                    )
                    lastPublishedAt = now
                }

                await enqueueTasksIfNeeded()
            }
        }

        guard !Task.isCancelled else {
            isBackgroundAnalyzing = false
            scanClockTask?.cancel()
            return
        }

        analyzedCount = localScoredCount
        if !pendingSizeHydrationIndices.isEmpty {
            let uniquePending = Array(Set(pendingSizeHydrationIndices)).sorted()
            let pendingBatch = uniquePending.map { scored[$0] }
            let hydratedBatch = await service.populateFileSizes(for: pendingBatch, limit: pendingBatch.count)
            for (offset, index) in uniquePending.enumerated() {
                scored[index] = hydratedBatch[offset]
            }
            let sizeEntries: [DatabaseService.FileSizeEntry] = hydratedBatch.compactMap { item in
                guard let size = item.fileSizeBytes, size > 0 else { return nil }
                return DatabaseService.FileSizeEntry(localId: item.id, fileSizeBytes: size)
            }
            if !sizeEntries.isEmpty {
                await DatabaseService.shared.saveFileSizes(sizeEntries)
            }
            await DatabaseService.shared.upsertAssetMetadata(metadataEntries(from: hydratedBatch))
        }
        publishPartialResults(
            scoredAssets: scored,
            scannedIDs: scannedIDs,
            qualityMap: qualityMap,
            duplicateSeed: duplicateSeed,
            similarSeed: similarSeed,
            elapsedSeconds: Int(Date().timeIntervalSince(scanStart))
        )
        await DatabaseService.shared.saveScores(newEntries)
        if !newAssetIDs.isEmpty {
            await DatabaseService.shared.markAssetsScanned(Array(newAssetIDs))
        }

        let nonFavorite = scored.filter { !$0.asset.isFavorite }
        let newNonFavorite = nonFavorite.filter { newAssetIDs.contains($0.id) }

        backgroundLabel = L10n.bgDuplicates
        backgroundProgress = 0.62
        progress = max(progress, 0.90)
        let newDuplicateGroups = await service.findDuplicates(assets: newNonFavorite)

        backgroundLabel = L10n.bgSimilar
        backgroundProgress = 0.74
        progress = max(progress, 0.93)
        let newSimilarGroups = await service.findSimilar(assets: newNonFavorite)

        let mergedDuplicateGroups = mergeGroups(duplicateGroups + newDuplicateGroups)
        let mergedSimilarGroups = mergeGroups(similarGroups + newSimilarGroups)
        duplicateGroups = mergedDuplicateGroups
        similarGroups = mergedSimilarGroups

        backgroundLabel = L10n.bgLowQuality
        backgroundProgress = 0.84
        progress = max(progress, 0.95)
        lowQuality = service.findLowQuality(assets: nonFavorite, qualityMap: qualityMap)

        // Rebuild behavior bucket using 6-category mutual exclusion.
        behaviorAssets = buildBehaviorAssets(
            from: nonFavorite,
            excludingIDs: occupiedAssetIDsForOtherCategories(
                duplicateGroups: duplicateGroups,
                similarGroups: similarGroups,
                screenshots: screenshots,
                videos: videos,
                lowQuality: lowQuality
            )
        )

        // Calibrate behavior bucket real file sizes before final summary.
        let hydratedBehavior = await service.populateFileSizes(for: behaviorAssets, limit: behaviorAssets.count)
        behaviorAssets = hydratedBehavior
        scored = mergeFileSizes(into: scored, from: hydratedBehavior)
        let behaviorSizeEntries = hydratedBehavior.compactMap { item -> DatabaseService.FileSizeEntry? in
            guard let size = item.fileSizeBytes, size > 0 else { return nil }
            return DatabaseService.FileSizeEntry(localId: item.id, fileSizeBytes: size)
        }
        await DatabaseService.shared.saveFileSizes(behaviorSizeEntries)

        allAssets = scored
        store.setAssets(scored)
        buildSummary(assets: scored)

        backgroundLabel = L10n.bgSaving
        backgroundProgress = 0.95
        progress = max(progress, 0.97)
        await DatabaseService.shared.saveGroups(duplicateGroups + similarGroups)
        await DatabaseService.shared.saveScanRecord(
            summary: summary,
            duplicateCount: duplicateGroups.count,
            similarCount: similarGroups.count,
            lowQualityCount: lowQuality.count
        )

        Task.detached(priority: .background) {
            await DatabaseService.shared.pruneStaleScores(keepIds: Set(ids))
            await DatabaseService.shared.pruneStaleMetadata(keepIds: Set(ids))
        }

        backgroundProgress = 1.0
        backgroundLabel = L10n.bgComplete
        progress = 1.0
        timelineVisibleAssets = scored
        timelineCanShowAssets = true
        finalizeScanDuration(scanStart: scanStart)
        phase = .done
        isBackgroundAnalyzing = false
        phaseLabel = L10n.scanComplete
        startBackgroundFileSizeHydration()
    }

    // MARK: - Helpers

    private func rebuildGroups(
        from rows: [DatabaseService.GroupRow],
        assetMap: [String: PhotoAsset]
    ) -> (duplicates: [PhotoGroup], similar: [PhotoGroup]) {
        var byGroup: [String: [DatabaseService.GroupRow]] = [:]
        for row in rows { byGroup[row.groupId, default: []].append(row) }

        var duplicates: [PhotoGroup] = []
        var similar:    [PhotoGroup] = []

        for (_, members) in byGroup {
            let sorted = members.sorted { $0.rank < $1.rank }
            let assets = sorted.compactMap { assetMap[$0.localId] }
            guard assets.count >= 2 else { continue }
            let gtype: PhotoGroup.GroupType = sorted.first?.groupType == "duplicate" ? .duplicate : .similar
            let group = PhotoGroup(assets: assets, groupType: gtype)
            if gtype == .duplicate { duplicates.append(group) } else { similar.append(group) }
        }
        return (duplicates, similar)
    }

    private func buildSummary(assets: [PhotoAsset]) {
        var s = LibrarySummary()
        s.totalCount = assets.count
        for a in assets {
            s.totalBytes += a.sizeBytes
            if a.asset.mediaType == .video { s.videoBytes += a.sizeBytes }
            else if a.asset.mediaSubtypes.contains(.photoScreenshot) { s.screenshotBytes += a.sizeBytes }
            else if a.asset.mediaSubtypes.contains(.photoLive) { s.livePhotoBytes += a.sizeBytes }
            else { s.photoBytes += a.sizeBytes }
            if a.isSelected { s.freeableBytes += a.sizeBytes }
        }
        let bad = assets.filter { $0.score < 40 }.count
        s.healthScore = max(0, 100 - Int(Double(bad) / Double(max(assets.count, 1)) * 100))
        summary = s
    }

    private func mergeGroups(_ groups: [PhotoGroup]) -> [PhotoGroup] {
        var seen = Set<String>()
        var merged: [PhotoGroup] = []
        for group in groups {
            let ids = group.assets.map(\.id).sorted()
            guard ids.count >= 2 else { continue }
            let typeKey = group.groupType == .duplicate ? "duplicate" : "similar"
            let key = "\(typeKey):\(ids.joined(separator: "|"))"
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            merged.append(group)
        }
        return merged
    }

    func deleteSelected(from assets: [PhotoAsset]) async throws {
        try await store.deleteAssets(assets.filter { $0.isSelected })
    }

    func deleteGroups(_ groups: [PhotoGroup]) async throws {
        let toDelete = groups.flatMap { Array($0.assets.dropFirst()) }
        try await store.deleteAssets(toDelete)
    }

    // MARK: - Pruning (called by store subscription on external deletions)

    private func pruneArrays(removingIds ids: Set<String>) {
        func filteredGroup(_ g: PhotoGroup) -> PhotoGroup? {
            let kept = g.assets.filter { !ids.contains($0.id) }
            return kept.count >= 2 ? PhotoGroup(assets: kept, groupType: g.groupType) : nil
        }
        duplicateGroups = duplicateGroups.compactMap(filteredGroup)
        similarGroups   = similarGroups.compactMap(filteredGroup)
        screenshots = screenshots.filter { !ids.contains($0.id) }
        videos      = videos.filter      { !ids.contains($0.id) }
        lowQuality  = lowQuality.filter  { !ids.contains($0.id) }
        favorites   = favorites.filter   { !ids.contains($0.id) }
        behaviorAssets = behaviorAssets.filter { !ids.contains($0.id) }
        buildSummary(assets: allAssets)
    }

    private func filteredGroupExcludingFavorites(_ group: PhotoGroup) -> PhotoGroup {
        var g = group
        g.assets = g.assets.filter { !$0.asset.isFavorite }
        return g
    }

    private func startBackgroundFileSizeHydration() {
        Task(priority: .utility) { [weak self] in
            guard let self else { return }
            await self.performBackgroundFileSizeHydration()
        }
    }

    private func performBackgroundFileSizeHydration() async {
        let videosSnapshot = videos
        let behaviorSnapshot = behaviorAssets
        let screenshotsSnapshot = screenshots
        let lowQualitySnapshot = lowQuality
        let favoritesSnapshot = favorites
        let allAssetsSnapshot = allAssets

        let newVideos = await service.populateFileSizes(for: videosSnapshot, limit: 600)
        let newBehavior = await service.populateFileSizes(for: behaviorSnapshot, limit: behaviorSnapshot.count)
        let newScreenshots = await service.populateFileSizes(for: screenshotsSnapshot, limit: 400)
        let newLowQuality = await service.populateFileSizes(for: lowQualitySnapshot, limit: 400)
        let newFavorites = await service.populateFileSizes(for: favoritesSnapshot, limit: 600)
        let newAllAssets = await service.populateFileSizes(for: allAssetsSnapshot, limit: allAssetsSnapshot.count)

        videos = mergeFileSizes(into: videos, from: newVideos)
        behaviorAssets = mergeFileSizes(into: behaviorAssets, from: newBehavior)
        screenshots = mergeFileSizes(into: screenshots, from: newScreenshots)
        lowQuality = mergeFileSizes(into: lowQuality, from: newLowQuality)
        favorites = mergeFileSizes(into: favorites, from: newFavorites)
        allAssets = mergeFileSizes(into: allAssets, from: newAllAssets)
        buildSummary(assets: allAssets)

        // Persist hydrated file sizes so next app launch reads real values immediately.
        let merged = newVideos + newBehavior + newScreenshots + newLowQuality + newFavorites + newAllAssets
        var seen = Set<String>()
        let fileSizeEntries: [DatabaseService.FileSizeEntry] = merged.compactMap { item in
            guard let size = item.fileSizeBytes, size > 0, !seen.contains(item.id) else { return nil }
            seen.insert(item.id)
            return DatabaseService.FileSizeEntry(localId: item.id, fileSizeBytes: size)
        }
        await DatabaseService.shared.saveFileSizes(fileSizeEntries)
        await DatabaseService.shared.upsertAssetMetadata(metadataEntries(from: allAssets))
    }

    private func mergeFileSizes(into current: [PhotoAsset], from hydrated: [PhotoAsset]) -> [PhotoAsset] {
        var map: [String: Int64] = [:]
        for item in hydrated {
            if let size = item.fileSizeBytes {
                map[item.id] = size
            }
        }
        return current.map { item in
            guard let size = map[item.id] else { return item }
            var updated = item
            updated.fileSizeBytes = size
            return updated
        }
    }

    private func buildBehaviorAssets(from nonFavoriteAssets: [PhotoAsset], excludingIDs: Set<String>) -> [PhotoAsset] {
        nonFavoriteAssets
            .filter { !excludingIDs.contains($0.id) }
            .map { asset in
                var a = asset
                // "其他使用行为" 默认不自动勾选，避免误删。
                a.isSelected = false
                return a
            }
            .sorted { $0.creationDate < $1.creationDate }
    }

    private func occupiedAssetIDsForOtherCategories(
        duplicateGroups: [PhotoGroup],
        similarGroups: [PhotoGroup],
        screenshots: [PhotoAsset],
        videos: [PhotoAsset],
        lowQuality: [PhotoAsset]
    ) -> Set<String> {
        var ids = Set<String>()
        for group in duplicateGroups { for asset in group.assets { ids.insert(asset.id) } }
        for group in similarGroups { for asset in group.assets { ids.insert(asset.id) } }
        for asset in screenshots { ids.insert(asset.id) }
        for asset in videos { ids.insert(asset.id) }
        for asset in lowQuality { ids.insert(asset.id) }
        return ids
    }

    private static func formatDuration(_ seconds: Int) -> String {
        let s = max(0, seconds)
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, sec)
        }
        return String(format: "%02d:%02d", m, sec)
    }

    private func finalizeScanDuration(scanStart: Date) {
        scanClockTask?.cancel()
        scanElapsedSeconds = Int(Date().timeIntervalSince(scanStart))
        lastScanDurationSeconds = scanElapsedSeconds
    }

    private func warmupMetadataBeforeReveal(
        scoredAssets: [PhotoAsset],
        scannedIDs: Set<String>,
        scanStart: Date
    ) async -> (scoredAssets: [PhotoAsset], scannedIDs: Set<String>) {
        var updated = scoredAssets
        var scanned = scannedIDs
        let total = max(updated.count, 1)
        let deadline = scanStart.addingTimeInterval(TimeInterval(timelineRevealSeconds))

        analyzedCount = scanned.count
        progress = max(progress, min(0.55, Double(scanned.count) / Double(total) * 0.55))

        let pendingIndices = updated.indices.filter { !scanned.contains(updated[$0].id) }
        var cursor = 0
        let batchSize = 200

        while cursor < pendingIndices.count, Date() < deadline, !Task.isCancelled {
            let end = min(cursor + batchSize, pendingIndices.count)
            let slice = Array(pendingIndices[cursor..<end])
            let batch = slice.map { updated[$0] }
            let hydratedBatch = await service.populateFileSizes(for: batch, limit: batch.count)

            for (offset, index) in slice.enumerated() {
                updated[index] = hydratedBatch[offset]
                scanned.insert(updated[index].id)
            }

            let sizeEntries: [DatabaseService.FileSizeEntry] = hydratedBatch.compactMap { item in
                guard let size = item.fileSizeBytes, size > 0 else { return nil }
                return DatabaseService.FileSizeEntry(localId: item.id, fileSizeBytes: size)
            }
            if !sizeEntries.isEmpty {
                await DatabaseService.shared.saveFileSizes(sizeEntries)
            }
            await DatabaseService.shared.upsertAssetMetadata(metadataEntries(from: hydratedBatch))

            analyzedCount = scanned.count
            progress = max(progress, min(0.55, Double(scanned.count) / Double(total) * 0.55))
            cursor = end
        }

        return (updated, scanned)
    }

    private func publishPartialResults(
        scoredAssets: [PhotoAsset],
        scannedIDs: Set<String>,
        qualityMap: [String: PhotoLibraryService.QualitySignals],
        duplicateSeed: [PhotoGroup],
        similarSeed: [PhotoGroup],
        elapsedSeconds: Int
    ) {
        let subset = scoredAssets.filter { scannedIDs.contains($0.id) }
        allAssets = subset
        store.setAssets(subset)

        duplicateGroups = duplicateSeed.compactMap { group in
            let kept = group.assets.filter { scannedIDs.contains($0.id) && !$0.asset.isFavorite }
            guard kept.count >= 2 else { return nil }
            return PhotoGroup(assets: kept, groupType: group.groupType)
        }
        similarGroups = similarSeed.compactMap { group in
            let kept = group.assets.filter { scannedIDs.contains($0.id) && !$0.asset.isFavorite }
            guard kept.count >= 2 else { return nil }
            return PhotoGroup(assets: kept, groupType: group.groupType)
        }

        let nonFavorite = subset.filter { !$0.asset.isFavorite }
        screenshots = nonFavorite.filter { $0.asset.mediaSubtypes.contains(.photoScreenshot) }
            .map { var a = $0; a.isSelected = a.score < 45; return a }
        videos = nonFavorite.filter { $0.asset.mediaType == .video }
            .sorted { $0.sizeBytes > $1.sizeBytes }
            .map { var a = $0; a.isSelected = false; return a }
        favorites = subset.filter { $0.asset.isFavorite }
            .map { var a = $0; a.isSelected = false; return a }
        lowQuality = service.findLowQuality(assets: nonFavorite, qualityMap: qualityMap)
        behaviorAssets = buildBehaviorAssets(
            from: nonFavorite,
            excludingIDs: occupiedAssetIDsForOtherCategories(
                duplicateGroups: duplicateGroups,
                similarGroups: similarGroups,
                screenshots: screenshots,
                videos: videos,
                lowQuality: lowQuality
            )
        )
        buildSummary(assets: subset)
        publishTimelineAssetsDuringScan(
            scoredAssets: subset,
            scannedIDs: Set(subset.map(\.id)),
            elapsedSeconds: elapsedSeconds
        )
    }

    private func publishTimelineAssetsDuringScan(
        scoredAssets: [PhotoAsset],
        scannedIDs: Set<String>,
        elapsedSeconds: Int
    ) {
        if elapsedSeconds < timelineRevealSeconds {
            timelineCanShowAssets = false
            timelineVisibleAssets = []
            return
        }
        timelineCanShowAssets = true
        timelineVisibleAssets = scoredAssets.filter { scannedIDs.contains($0.id) }
    }

    private func startMetadataWarmupIfNeeded() {
        guard metadataWarmupTask == nil else { return }
        guard phase == .idle, !isBackgroundAnalyzing else { return }
        metadataWarmupTask = Task(priority: .utility) { [weak self] in
            guard let self else { return }
            defer {
                Task { @MainActor [weak self] in
                    self?.metadataWarmupTask = nil
                }
            }
            let assets = await self.service.fetchAllAssets()
            guard !Task.isCancelled, !assets.isEmpty else { return }
            let hydrated = await self.service.populateFileSizes(for: assets, limit: assets.count)
            guard !Task.isCancelled else { return }
            await DatabaseService.shared.upsertAssetMetadata(self.metadataEntries(from: hydrated))
            let keepIds = Set(hydrated.map(\.id))
            Task.detached(priority: .background) {
                await DatabaseService.shared.pruneStaleMetadata(keepIds: keepIds)
            }
        }
    }

    private func performIncrementalLaunchSync() async {
        guard phase == .idle, !isBackgroundAnalyzing else { return }

        let raw = await service.fetchAllAssets()
        let currentIDs = Set(raw.map(\.id))

        let activeScannedIDs = await DatabaseService.shared.loadAllActiveScannedIds()
        let deletedIDs = activeScannedIDs.subtracting(currentIDs)
        if !deletedIDs.isEmpty {
            await DatabaseService.shared.markAssetsDeleted(Array(deletedIDs))
        }

        if currentIDs.isEmpty {
            await DatabaseService.shared.pruneStaleScores(keepIds: [])
            await DatabaseService.shared.pruneStaleMetadata(keepIds: [])
            return
        }

        Task.detached(priority: .background) {
            await DatabaseService.shared.pruneStaleScores(keepIds: currentIDs)
            await DatabaseService.shared.pruneStaleMetadata(keepIds: currentIDs)
        }

        let scannedExistingIDs = await DatabaseService.shared.loadActiveScannedIds(for: Array(currentIDs))
        let newIDs = currentIDs.subtracting(scannedExistingIDs)
        guard !newIDs.isEmpty else { return }

        var newAssets = raw.filter { newIDs.contains($0.id) }
        var resultsByID: [String: PhotoLibraryService.ScoreResult] = [:]

        for i in newAssets.indices {
            if Task.isCancelled { return }
            let result = await service.score(asset: newAssets[i].asset)
            newAssets[i].score = result.score
            newAssets[i].isSelected = LibraryViewModel.shouldAutoSelect(
                score: result.score,
                hasFaces: result.hasFaces
            )
            resultsByID[newAssets[i].id] = result
        }

        newAssets = await service.populateFileSizes(for: newAssets, limit: newAssets.count)

        let scoreEntries: [DatabaseService.ScoreEntry] = newAssets.compactMap { asset in
            guard let result = resultsByID[asset.id] else { return nil }
            return DatabaseService.ScoreEntry(
                localId: asset.id,
                score: result.score,
                isBlurry: result.isBlurry,
                isOverExposed: result.isOverExposed,
                isUnderExposed: result.isUnderExposed,
                hasFaces: result.hasFaces,
                fileSizeBytes: asset.fileSizeBytes
            )
        }
        await DatabaseService.shared.saveScores(scoreEntries)

        let sizeEntries: [DatabaseService.FileSizeEntry] = newAssets.compactMap { asset in
            guard let size = asset.fileSizeBytes, size > 0 else { return nil }
            return DatabaseService.FileSizeEntry(localId: asset.id, fileSizeBytes: size)
        }
        await DatabaseService.shared.saveFileSizes(sizeEntries)
        await DatabaseService.shared.upsertAssetMetadata(metadataEntries(from: newAssets))
        await DatabaseService.shared.markAssetsScanned(Array(newIDs))
    }

    private func metadataEntries(from assets: [PhotoAsset]) -> [DatabaseService.AssetMetadataEntry] {
        assets.map { asset in
            DatabaseService.AssetMetadataEntry(
                localId: asset.id,
                fileSizeBytes: asset.fileSizeBytes,
                pixelWidth: Int32(asset.asset.pixelWidth),
                pixelHeight: Int32(asset.asset.pixelHeight),
                creationTimestamp: asset.asset.creationDate.map { Int64($0.timeIntervalSince1970) }
            )
        }
    }
}
