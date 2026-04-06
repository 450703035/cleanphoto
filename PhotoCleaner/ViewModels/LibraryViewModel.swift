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

    // MARK: - Size helpers (derived from yearGroups / dayMap)

    func yearSize(_ year: Int) -> Int64 {
        yearGroups[year]?.values.flatMap { $0 }.reduce(0) { $0 + $1.totalSize } ?? 0
    }

    func monthSize(year: Int, month: String) -> Int64 {
        yearGroups[year]?[month]?.reduce(0) { $0 + $1.totalSize } ?? 0
    }

    func yearSelectedSize(_ year: Int) -> Int64 {
        yearGroups[year]?.values.flatMap { $0 }.flatMap { $0.assets }.reduce(0) { total, asset in
            let selected = selectionOverrides[asset.id] ?? asset.isSelected
            return total + (selected ? asset.sizeBytes : 0)
        } ?? 0
    }

    func monthSelectedSize(year: Int, month: String) -> Int64 {
        yearGroups[year]?[month]?.flatMap { $0.assets }.reduce(0) { total, asset in
            let selected = selectionOverrides[asset.id] ?? asset.isSelected
            return total + (selected ? asset.sizeBytes : 0)
        } ?? 0
    }

    var maxDaySize: Int64 {
        dayMap.values.map { $0.totalSize }.max() ?? 1
    }

    private let service = PhotoLibraryService.shared
    private let store   = PhotoStore.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
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
        let ids = allAssets.map { $0.id }
        await DatabaseService.shared.removeScores(for: ids)
        allAssets = []          // clears the guard in load()
        scoringProgress = 0
        await load()
    }

    func load() async {
        guard !isLoading, allAssets.isEmpty else { return }
        isLoading = true

        // Phase 1: Fetch asset metadata and apply any cached scores immediately
        let raw = await service.fetchAllAssets()
        let ids = raw.map { $0.id }
        let cached = await DatabaseService.shared.loadScores(for: ids)

        var assets = raw.map { a -> PhotoAsset in
            var a = a
            if let c = cached[a.id] {
                a.score = c.score
                a.isSelected = Self.shouldAutoSelect(score: c.score, hasFaces: c.hasFaces)
                a.fileSizeBytes = c.fileSizeBytes
            }
            return a
        }

        // Build initial groups off main thread
        let (initialGroups, initialDayMap) = await Task.detached(priority: .userInitiated) {
            (LibraryViewModel.computeYearGroups(assets), LibraryViewModel.computeDayMap(assets))
        }.value

        allAssets = assets
        yearGroups = initialGroups
        dayMap = initialDayMap
        isLoading = false

        // Phase 2: Score only assets not yet in the cache
        let uncached = (0..<raw.count).filter { cached[raw[$0].id] == nil }

        let totalCount = raw.count
        let cachedCount = totalCount - uncached.count
        scoringProgress = uncached.isEmpty ? 1.0 : Double(cachedCount) / Double(max(totalCount, 1))

        if uncached.isEmpty {
            Task.detached(priority: .background) {
                await DatabaseService.shared.pruneStaleScores(keepIds: Set(ids))
            }
            return
        }

        var nextPos = 0
        var newEntries: [DatabaseService.ScoreEntry] = []
        var doneCount = cachedCount
        // Throttle: only publish progress every N photos to avoid flooding main thread
        let progressStride = max(1, totalCount / 30)

        await withTaskGroup(of: (Int, PhotoLibraryService.ScoreResult).self) { group in
            while nextPos < min(10, uncached.count) {
                let i = uncached[nextPos]
                let asset = raw[i].asset
                group.addTask {
                    let r = await PhotoLibraryService.shared.score(asset: asset)
                    return (i, r)
                }
                nextPos += 1
            }

            for await (idx, result) in group {
                if Task.isCancelled { return }
                assets[idx].score = result.score
                assets[idx].isSelected = Self.shouldAutoSelect(score: result.score, hasFaces: result.hasFaces)
                newEntries.append(DatabaseService.ScoreEntry(
                    localId:        raw[idx].id,
                    score:          result.score,
                    isBlurry:       result.isBlurry,
                    isOverExposed:  result.isOverExposed,
                    isUnderExposed: result.isUnderExposed,
                    hasFaces:       result.hasFaces,
                    fileSizeBytes:  assets[idx].fileSizeBytes
                ))
                doneCount += 1
                // Throttle progress updates to reduce main-thread re-renders
                if doneCount % progressStride == 0 || nextPos >= uncached.count {
                    scoringProgress = Double(doneCount) / Double(max(totalCount, 1))
                }

                if nextPos < uncached.count {
                    let i = uncached[nextPos]
                    let asset = raw[i].asset
                    group.addTask {
                        let r = await PhotoLibraryService.shared.score(asset: asset)
                        return (i, r)
                    }
                    nextPos += 1
                }
            }
        }

        // Final rebuild off main thread
        let (finalGroups, finalDayMap) = await Task.detached(priority: .userInitiated) {
            (LibraryViewModel.computeYearGroups(assets), LibraryViewModel.computeDayMap(assets))
        }.value

        store.setAssets(assets)
        allAssets = assets
        yearGroups = finalGroups
        dayMap = finalDayMap

        await DatabaseService.shared.saveScores(newEntries)
        scoringProgress = 1.0
        Task.detached(priority: .background) {
            await DatabaseService.shared.pruneStaleScores(keepIds: Set(ids))
        }
    }

    // MARK: - Group into year -> month -> album folders (runs off main thread)
    nonisolated static func computeYearGroups(_ assets: [PhotoAsset]) -> [Int: [String: [AlbumFolder]]] {
        let cal = Calendar.current
        let monthNames = ["1月","2月","3月","4月","5月","6月","7月","8月","9月","10月","11月","12月"]
        let df = DateFormatter(); df.dateFormat = "M月d日"
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
            let monthLabel = m >= 1 && m <= 12 ? monthNames[m-1] : "\(m)月"
            let title = df.string(from: dayAssets.first!.creationDate)
            let folder = AlbumFolder(
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
    }

    var sortedYears: [Int] { yearGroups.keys.sorted(by: >) }

    func months(for year: Int) -> [String] {
        let order = ["12月","11月","10月","9月","8月","7月","6月","5月","4月","3月","2月","1月"]
        let available: Set<String> = yearGroups[year].map { Set($0.keys) } ?? []
        return order.filter { available.contains($0) }
    }

    func dayInfo(year: Int, month: Int, day: Int) -> DayInfo? {
        dayMap["\(year)-\(month+1)-\(day)"]
    }

    // MARK: - Settings-aware auto-select logic
    // Single source of truth for whether a photo should be auto-marked for deletion.
    // Reads AppConfig (backed by UserDefaults / @AppStorage) so Settings changes take
    // effect on the next load/rescore without any extra wiring.
    static func shouldAutoSelect(score: Int, hasFaces: Bool) -> Bool {
        guard AppConfig.autoSelect else { return false }            // user disabled auto-select
        if AppConfig.protectFaces && hasFaces { return false }      // face-protection shield
        return score < AppConfig.deleteThreshold                    // normal threshold check
    }
}
