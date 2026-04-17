import SwiftUI
import Photos
import Combine

@MainActor
class LibraryViewModel: ObservableObject {
    @Published var allAssets: [PhotoAsset] = []
    @Published var yearGroups: [Int: [String: [AlbumFolder]]] = [:]   // year -> month -> folders
    @Published var dayMap: [String: DayInfo] = [:]                     // "yyyy-M-d" -> DayInfo
    @Published var isLoading = false
    @Published var scoringProgress: Double = 0   // 0.0 – 1.0
    /// User's manual selection overrides: assetId -> isSelected (persists within session)
    var selectionOverrides: [String: Bool] = [:]
    private var yearSizeCache: [Int: Int64] = [:]
    private var monthSizeCache: [String: Int64] = [:] // key: "year|month"
    private var yearSelectedSizeCache: [Int: Int64] = [:]
    private var monthSelectedSizeCache: [String: Int64] = [:] // key: "year|month"

    // MARK: - Size helpers (derived from yearGroups / dayMap)

    func yearSize(_ year: Int) -> Int64 {
        yearSizeCache[year] ?? 0
    }

    func monthSize(year: Int, month: String) -> Int64 {
        monthSizeCache["\(year)|\(month)"] ?? 0
    }

    func yearSelectedSize(_ year: Int) -> Int64 {
        if selectionOverrides.isEmpty {
            return yearSelectedSizeCache[year] ?? 0
        }
        guard let monthMap = yearGroups[year] else { return 0 }
        return monthMap.values
            .flatMap { $0 }
            .flatMap { $0.assets }
            .reduce(0) { total, asset in
                let selected = selectionOverrides[asset.id] ?? asset.isSelected
                return total + (selected ? asset.sizeBytes : 0)
            }
    }

    func monthSelectedSize(year: Int, month: String) -> Int64 {
        if selectionOverrides.isEmpty {
            return monthSelectedSizeCache["\(year)|\(month)"] ?? 0
        }
        guard let folders = yearGroups[year]?[month] else { return 0 }
        return folders
            .flatMap { $0.assets }
            .reduce(0) { total, asset in
                let selected = selectionOverrides[asset.id] ?? asset.isSelected
                return total + (selected ? asset.sizeBytes : 0)
            }
    }

    var maxDaySize: Int64 {
        dayMap.values.map { $0.totalSize }.max() ?? 1
    }

    private let service = PhotoLibraryService.shared
    private let store   = PhotoStore.shared
    private var cancellables = Set<AnyCancellable>()
    private var lastLoadTime: Date?
    private let minAutoReloadInterval: TimeInterval = 30
    private var scoringTask: Task<Void, Never>?
    private var timelineInteractionActive = false
    private var scoringConcurrencyLimit: Int { timelineInteractionActive ? 2 : 4 }

    init() {
        // Fast-path: if scan/home already populated PhotoStore, render timeline immediately.
        if !store.allAssets.isEmpty {
            let snapshot = store.allAssets
            allAssets = snapshot
            Task { @MainActor in
                let (groups, map) = await Task.detached(priority: .userInitiated) {
                    (LibraryViewModel.computeYearGroups(snapshot), LibraryViewModel.computeDayMap(snapshot))
                }.value
                self.yearGroups = groups
                self.dayMap = map
                self.rebuildSizeCaches()
            }
        }

        // Prune timeline data whenever any tab deletes assets through PhotoStore.
        store.$lastDeletedIds
            .dropFirst()
            .filter { !$0.isEmpty }
            .sink { [weak self] (ids: Set<String>) in
                guard let self else { return }
                Task { await self.syncDeletion(ids: ids) }
            }
            .store(in: &cancellables)
    }

    /// Pull-to-refresh: wipe cached scores and re-run scoring from scratch.
    func rescore() async {
        guard !isLoading else { return }
        scoringTask?.cancel()
        let ids = allAssets.map { $0.id }
        await DatabaseService.shared.removeScores(for: ids)
        allAssets = []          // clears the guard in load()
        yearGroups = [:]
        dayMap = [:]
        rebuildSizeCaches()
        scoringProgress = 0
        await load(force: true)
    }

    /// Warm timeline data in background right after app launch/authorization,
    /// so first entry to Timeline feels instant.
    func prewarmForFirstTimelineEntry() async {
        guard allAssets.isEmpty, !isLoading else { return }
        await load()
    }

    func setTimelineInteractionActive(_ active: Bool) {
        timelineInteractionActive = active
    }

    /// Accepts externally-scanned assets (from ScanViewModel) and rebuilds timeline sections.
    /// Used by Timeline tab to show only the scanned subset during long-running scans.
    func applyScannedSubset(_ assets: [PhotoAsset]) async {
        allAssets = assets
        guard !assets.isEmpty else {
            yearGroups = [:]
            dayMap = [:]
            rebuildSizeCaches()
            return
        }
        let (groups, map) = await Task.detached(priority: .userInitiated) {
            (LibraryViewModel.computeYearGroups(assets), LibraryViewModel.computeDayMap(assets))
        }.value
        yearGroups = groups
        dayMap = map
        rebuildSizeCaches()
    }

    func clearTimeline() {
        allAssets = []
        yearGroups = [:]
        dayMap = [:]
        scoringProgress = 0
        rebuildSizeCaches()
    }

    func load(force: Bool = false) async {
        guard !isLoading else { return }
        if !force {
            // Avoid full reload while previous scoring is still running.
            if !allAssets.isEmpty && scoringProgress < 1.0 { return }
            // Avoid repeated reloads when users switch tabs frequently.
            if !allAssets.isEmpty,
               let lastLoadTime,
               Date().timeIntervalSince(lastLoadTime) < minAutoReloadInterval {
                return
            }
        }
        isLoading = true
        scoringTask?.cancel()

        let auth = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard auth == .authorized || auth == .limited else {
            scoringProgress = 1.0
            isLoading = false
            return
        }

        // Phase 1: Fetch asset metadata and apply any cached scores immediately
        let raw = await service.fetchAllAssets()
        if raw.isEmpty {
            allAssets = []
            yearGroups = [:]
            dayMap = [:]
            rebuildSizeCaches()
            scoringProgress = 1.0
            isLoading = false
            return
        }
        let ids = raw.map { $0.id }
        let cached = await DatabaseService.shared.loadScores(for: ids)
        let metadata = await DatabaseService.shared.loadMetadata(for: ids)

        let assets = raw.map { a -> PhotoAsset in
            var a = a
            if let c = cached[a.id] {
                a.score = c.score
                a.isSelected = Self.shouldAutoSelect(score: c.score, hasFaces: c.hasFaces)
                a.isUtility = c.isUtility
                a.fileSizeBytes = c.fileSizeBytes ?? metadata[a.id]?.fileSizeBytes
            } else if let m = metadata[a.id] {
                a.fileSizeBytes = m.fileSizeBytes
            }
            return a
        }

        // Publish assets immediately so the UI can render placeholders while grouping.
        allAssets = assets

        // Build initial groups off main thread
        let (initialGroups, initialDayMap) = await Task.detached(priority: .userInitiated) {
            (LibraryViewModel.computeYearGroups(assets), LibraryViewModel.computeDayMap(assets))
        }.value

        yearGroups = initialGroups
        dayMap = initialDayMap
        rebuildSizeCaches()
        isLoading = false
        lastLoadTime = Date()

        // Phase 2: Score only assets not yet in the cache
        let uncached = (0..<raw.count).filter { cached[raw[$0].id] == nil }

        let totalCount = raw.count
        let cachedCount = totalCount - uncached.count
        scoringProgress = uncached.isEmpty ? 1.0 : Double(cachedCount) / Double(max(totalCount, 1))

        if uncached.isEmpty {
            Task.detached(priority: .background) {
                await DatabaseService.shared.pruneStaleScores(keepIds: Set(ids))
                await DatabaseService.shared.pruneStaleMetadata(keepIds: Set(ids))
            }
            return
        }

        let rawSnapshot = raw
        let uncachedSnapshot = uncached
        let assetsSnapshot = assets
        let idsSnapshot = ids
        let maxConcurrent = self.scoringConcurrencyLimit
        scoringTask = Task(priority: .utility) { [weak self] in
            guard let self else { return }
            let scored = await Task.detached(priority: .utility) {
                await LibraryViewModel.scoreUncachedAssets(
                    raw: rawSnapshot,
                    uncachedIndices: uncachedSnapshot,
                    seedAssets: assetsSnapshot,
                    maxConcurrent: maxConcurrent
                )
            }.value
            guard !Task.isCancelled else { return }

            let (finalGroups, finalDayMap) = await Task.detached(priority: .userInitiated) {
                (LibraryViewModel.computeYearGroups(scored.assets), LibraryViewModel.computeDayMap(scored.assets))
            }.value
            guard !Task.isCancelled else { return }

            await DatabaseService.shared.saveScores(scored.entries)
            guard !Task.isCancelled else { return }
            await DatabaseService.shared.pruneStaleScores(keepIds: Set(idsSnapshot))
            await DatabaseService.shared.pruneStaleMetadata(keepIds: Set(idsSnapshot))
            guard !Task.isCancelled else { return }

            self.store.setAssets(scored.assets)
            self.allAssets = scored.assets
            self.yearGroups = finalGroups
            self.dayMap = finalDayMap
            self.rebuildSizeCaches()
            self.scoringProgress = 1.0
        }
    }

    // MARK: - Group into year -> month -> album folders (runs off main thread)
    nonisolated static func computeYearGroups(_ assets: [PhotoAsset]) -> [Int: [String: [AlbumFolder]]] {
        let cal = Calendar.current
        let df = DateFormatter()
        df.locale = Locale(identifier: L10n.dateLocaleIdentifier)
        df.setLocalizedDateFormatFromTemplate("Md")
        let sorted = assets.sorted { $0.creationDate > $1.creationDate }

        var byDay: [String: [PhotoAsset]] = [:]
        for asset in sorted {
            let comps = cal.dateComponents([.year, .month, .day], from: asset.creationDate)
            let key = "\(comps.year!)-\(comps.month!)-\(comps.day!)"
            byDay[key, default: []].append(asset)
        }

        var yearMonthFolders: [Int: [String: [AlbumFolder]]] = [:]
        for (key, dayAssets) in byDay {
            let parts = key.split(separator: "-").compactMap { Int($0) }
            guard parts.count == 3 else { continue }
            let (y, m, _) = (parts[0], parts[1], parts[2])
            let monthLabel = L10n.monthLabel(m)
            let title = df.string(from: dayAssets.first!.creationDate)
            let folder = AlbumFolder(
                id: key,
                title: title,
                assets: dayAssets.sorted { $0.score > $1.score },
                date: dayAssets.first!.creationDate
            )
            yearMonthFolders[y, default: [:]][monthLabel, default: []].append(folder)
        }

        for y in yearMonthFolders.keys {
            for m in yearMonthFolders[y]!.keys {
                yearMonthFolders[y]![m]!.sort { $0.date > $1.date }
            }
        }
        return yearMonthFolders
    }

    // MARK: - Build day map for calendar (runs off main thread)
    nonisolated static func computeDayMap(_ assets: [PhotoAsset]) -> [String: DayInfo] {
        let cal = Calendar.current
        var map: [String: DayInfo] = [:]
        for asset in assets {
            let comps = cal.dateComponents([.year, .month, .day], from: asset.creationDate)
            guard let y = comps.year, let m = comps.month, let d = comps.day else { continue }
            let key = "\(y)-\(m)-\(d)"
            if map[key] == nil {
                map[key] = DayInfo(year: y, month: m - 1, day: d, assets: [])
            }
            map[key]!.assets.append(asset)
        }
        return map
    }

    private struct ScoringBatchResult {
        var assets: [PhotoAsset]
        var entries: [DatabaseService.ScoreEntry]
    }

    nonisolated private static func scoreUncachedAssets(
        raw: [PhotoAsset],
        uncachedIndices: [Int],
        seedAssets: [PhotoAsset],
        maxConcurrent: Int
    ) async -> ScoringBatchResult {
        guard !uncachedIndices.isEmpty else {
            return ScoringBatchResult(assets: seedAssets, entries: [])
        }

        var assets = seedAssets
        var entries: [DatabaseService.ScoreEntry] = []
        var nextPos = 0
        var inFlight = 0
        let workerLimit = max(1, maxConcurrent)

        await withTaskGroup(of: (Int, PhotoLibraryService.ScoreResult).self) { group in
            func enqueue() {
                while inFlight < workerLimit && nextPos < uncachedIndices.count {
                    let i = uncachedIndices[nextPos]
                    let asset = raw[i].asset
                    group.addTask {
                        let r = await PhotoLibraryService.shared.score(asset: asset)
                        return (i, r)
                    }
                    inFlight += 1
                    nextPos += 1
                }
            }

            enqueue()
            while let (idx, result) = await group.next() {
                inFlight = max(0, inFlight - 1)
                if Task.isCancelled { return }
                assets[idx].score = result.score
                assets[idx].isSelected = LibraryViewModel.shouldAutoSelect(
                    score: result.score,
                    hasFaces: result.hasFaces
                )
                assets[idx].isUtility = result.isUtility
                entries.append(DatabaseService.ScoreEntry(
                    localId:        raw[idx].id,
                    score:          result.score,
                    isBlurry:       result.isBlurry,
                    isOverExposed:  result.isOverExposed,
                    isUnderExposed: result.isUnderExposed,
                    hasFaces:       result.hasFaces,
                    isUtility:      result.isUtility,
                    fileSizeBytes:  assets[idx].fileSizeBytes
                ))
                enqueue()
            }
        }
        return ScoringBatchResult(assets: assets, entries: entries)
    }

    /// Called by the PhotoStore subscription when any tab deletes assets.
    /// Uses `store.allAssets` as the source of truth (already pruned) and rebuilds the timeline views.
    private func syncDeletion(ids: Set<String>) async {
        guard !allAssets.isEmpty else { return }
        allAssets = store.allAssets
        for id in ids { selectionOverrides.removeValue(forKey: id) }
        let snapshot = allAssets
        let (newGroups, newDayMap) = await Task.detached(priority: .userInitiated) {
            (LibraryViewModel.computeYearGroups(snapshot), LibraryViewModel.computeDayMap(snapshot))
        }.value
        yearGroups = newGroups
        dayMap = newDayMap
        rebuildSizeCaches()
    }

    @Published private(set) var sortedYears: [Int] = []
    @Published private(set) var monthsPerYear: [Int: [String]] = [:]
    private static let zhMonthNames = ["1月","2月","3月","4月","5月","6月","7月","8月","9月","10月","11月","12月"]
    private static let enMonthNames = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]

    func months(for year: Int) -> [String] {
        monthsPerYear[year] ?? []
    }

    private func rebuildYearMonthIndex() {
        let newYears = yearGroups.keys.sorted(by: >)
        var newMonths: [Int: [String]] = [:]
        for year in newYears {
            let available: Set<String> = yearGroups[year].map { Set($0.keys) } ?? []
            newMonths[year] = available.sorted { lhs, rhs in
                let l = monthSortIndex(lhs)
                let r = monthSortIndex(rhs)
                if l != r { return l > r }
                return lhs > rhs
            }
        }
        if newYears != sortedYears { sortedYears = newYears }
        if newMonths != monthsPerYear { monthsPerYear = newMonths }
    }

    private func monthSortIndex(_ label: String) -> Int {
        if let idx = L10n.monthNames.firstIndex(of: label) { return idx + 1 }
        if let idx = Self.zhMonthNames.firstIndex(of: label) { return idx + 1 }
        if let idx = Self.enMonthNames.firstIndex(of: label) { return idx + 1 }
        return 0
    }

    func dayInfo(year: Int, month: Int, day: Int) -> DayInfo? {
        dayMap["\(year)-\(month+1)-\(day)"]
    }

    // MARK: - Settings-aware auto-select logic
    // Single source of truth for whether a photo should be auto-marked for deletion.
    // Reads AppConfig (backed by UserDefaults / @AppStorage) so Settings changes take
    // effect on the next load/rescore without any extra wiring.
    nonisolated static func shouldAutoSelect(score: Int, hasFaces: Bool) -> Bool {
        guard AppConfig.autoSelect else { return false }            // user disabled auto-select
        if AppConfig.protectFaces && hasFaces { return false }      // face-protection shield
        return score < AppConfig.deleteThreshold                    // normal threshold check
    }

    private func rebuildSizeCaches() {
        rebuildYearMonthIndex()
        var ys: [Int: Int64] = [:]
        var ms: [String: Int64] = [:]
        var ysSelected: [Int: Int64] = [:]
        var msSelected: [String: Int64] = [:]
        for (year, monthMap) in yearGroups {
            var yTotal: Int64 = 0
            var ySelectedTotal: Int64 = 0
            for (month, folders) in monthMap {
                var total: Int64 = 0
                var selectedTotal: Int64 = 0
                for folder in folders {
                    total += folder.totalSize
                    selectedTotal += folder.assets.reduce(0) { subtotal, asset in
                        subtotal + (asset.isSelected ? asset.sizeBytes : 0)
                    }
                }
                ms["\(year)|\(month)"] = total
                msSelected["\(year)|\(month)"] = selectedTotal
                yTotal += total
                ySelectedTotal += selectedTotal
            }
            ys[year] = yTotal
            ysSelected[year] = ySelectedTotal
        }
        yearSizeCache = ys
        monthSizeCache = ms
        yearSelectedSizeCache = ysSelected
        monthSelectedSizeCache = msSelected
    }
}
