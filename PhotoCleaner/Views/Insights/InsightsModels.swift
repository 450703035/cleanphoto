import SwiftUI
import Photos

// MARK: - Persona identity
enum PersonaID: String, CaseIterable, Identifiable {
    case nightOwl
    case foodie
    case parent
    case wanderer
    case hoarder
    case minimalist

    var id: String { rawValue }
}

struct PersonaStat {
    let value: String
    let label: String
}

struct Persona: Identifiable {
    let id: PersonaID
    let symbol: String
    let eyebrow: String       // chip label (e.g. "夜晚记录者")
    let title: String         // hero title (e.g. "夜晚的记录者")
    let line: String
    let tags: [String]
    let stats: [PersonaStat]
    let gradient: [Color]     // background gradient (top → bottom)
    let glow: Color           // warm accent for halo

    // Ending copy & imagery for Annual Report
    let endingSymbol: String
    let endingStat: PersonaStat
    let endingLine1: String
    let endingLine2Html: String   // may contain <br/>
}

enum PersonaCatalog {
    // Computed so language switching (which rebuilds the view tree via
    // ContentView's .id(appLanguage)) picks up fresh L10n strings instead of
    // a once-frozen array.
    static var all: [Persona] {
        [
        Persona(
            id: .nightOwl,
            symbol: "🌙",
            eyebrow: L10n.personaNightOwlChip,
            title: L10n.personaNightOwl,
            line: L10n.personaNightOwlLine,
            tags: [L10n.tagNightActive, L10n.tagScreenshotPro, L10n.tagDinnerDiary, L10n.tagWeekendTrip],
            stats: [
                PersonaStat(value: "1,248", label: L10n.insightsStatPhotos),
                PersonaStat(value: "+32%",  label: L10n.insightsStatVsLast),
                PersonaStat(value: "22:00", label: L10n.insightsStatPeak),
            ],
            gradient: [Color(hex: "2e2563"), Color(hex: "1a1438"), Color(hex: "120e28")],
            glow: Color(hex: "ff9b4b").opacity(0.55),
            endingSymbol: "🌙",
            endingStat: PersonaStat(value: "61%", label: L10n.isEn ? "after 8pm" : "照片拍摄于 20 点之后"),
            endingLine1: L10n.personaEndNightOwlL1,
            endingLine2Html: L10n.personaEndNightOwlL2
        ),
        Persona(
            id: .foodie,
            symbol: "🍜",
            eyebrow: L10n.personaFoodieChip,
            title: L10n.personaFoodie,
            line: L10n.personaFoodieLine,
            tags: [L10n.tagMorningRitual, L10n.tagTopDownShooter, L10n.tagHotpotSeason, L10n.tagDessertLover],
            stats: [
                PersonaStat(value: "412",   label: L10n.isEn ? "Food shots" : "美食照片"),
                PersonaStat(value: "12:30", label: L10n.isEn ? "Lunch peak" : "午餐高峰"),
                PersonaStat(value: "33%",   label: L10n.isEn ? "Mix share" : "内容占比"),
            ],
            gradient: [Color(hex: "c4752f"), Color(hex: "823920"), Color(hex: "41170d")],
            glow: Color(hex: "ffa548").opacity(0.55),
            endingSymbol: "🍜",
            endingStat: PersonaStat(value: "4,830", label: L10n.isEn ? "food photos" : "张照片与食物相关"),
            endingLine1: L10n.personaEndFoodieL1,
            endingLine2Html: L10n.personaEndFoodieL2
        ),
        Persona(
            id: .parent,
            symbol: "👶",
            eyebrow: L10n.personaParentChip,
            title: L10n.personaParent,
            line: L10n.personaParentLine,
            tags: [L10n.tagPortraitFan, L10n.tagDailyLog, L10n.tagGrowthBook, L10n.tagFamilyChat],
            stats: [
                PersonaStat(value: "736", label: L10n.isEn ? "Baby shots" : "宝宝出镜"),
                PersonaStat(value: "59%", label: L10n.isEn ? "Portrait share" : "人像占比"),
                PersonaStat(value: "28",  label: L10n.isEn ? "Days" : "累计天数"),
            ],
            gradient: [Color(hex: "b05b4a"), Color(hex: "6e2e3c"), Color(hex: "3b1a2a")],
            glow: Color(hex: "ffc4a6").opacity(0.55),
            endingSymbol: "👶",
            endingStat: PersonaStat(value: "2,830", label: L10n.isEn ? "photos starred baby" : "张照片的主角是宝宝"),
            endingLine1: L10n.personaEndParentL1,
            endingLine2Html: L10n.personaEndParentL2
        ),
        Persona(
            id: .wanderer,
            symbol: "🏔️",
            eyebrow: L10n.personaWandererChip,
            title: L10n.personaWanderer,
            line: L10n.personaWandererLine,
            tags: [L10n.tagScenery, L10n.tagCityWalk, L10n.tagCheckin, L10n.tagDriving],
            stats: [
                PersonaStat(value: "14",                  label: L10n.isEn ? "Places" : "到访地点"),
                PersonaStat(value: "68%",                 label: L10n.isEn ? "Weekend share" : "周末占比"),
                PersonaStat(value: L10n.isEn ? "Sat" : "周六", label: L10n.isEn ? "Top day" : "最活跃日"),
            ],
            gradient: [Color(hex: "2c6e6a"), Color(hex: "254a6a"), Color(hex: "122538")],
            glow: Color(hex: "7ad4ca").opacity(0.5),
            endingSymbol: "🏔️",
            endingStat: PersonaStat(value: "138", label: L10n.isEn ? "places visited" : "个到访的地点"),
            endingLine1: L10n.personaEndWandererL1,
            endingLine2Html: L10n.personaEndWandererL2
        ),
        Persona(
            id: .hoarder,
            symbol: "📱",
            eyebrow: L10n.personaHoarderChip,
            title: L10n.personaHoarder,
            line: L10n.personaHoarderLine,
            tags: [L10n.tagWeChatClip, L10n.tagRedNote, L10n.tagLongShot, L10n.tagAddressArchive],
            stats: [
                PersonaStat(value: "336",  label: L10n.isEn ? "Screenshots" : "本月截图"),
                PersonaStat(value: "88%",  label: L10n.isEn ? "Never reopened" : "从未回看"),
                PersonaStat(value: "1.1G", label: L10n.isEn ? "Storage" : "占用空间"),
            ],
            gradient: [Color(hex: "3a4082"), Color(hex: "292a5e"), Color(hex: "1b1835")],
            glow: Color(hex: "8aa3ff").opacity(0.5),
            endingSymbol: "📱",
            endingStat: PersonaStat(value: "5,200", label: L10n.isEn ? "screenshots kept" : "张截图存进了相册"),
            endingLine1: L10n.personaEndHoarderL1,
            endingLine2Html: L10n.personaEndHoarderL2
        ),
        Persona(
            id: .minimalist,
            symbol: "◾️",
            eyebrow: L10n.personaMinimalistChip,
            title: L10n.personaMinimalist,
            line: L10n.personaMinimalistLine,
            tags: [L10n.tagLowProd, L10n.tagCurated, L10n.tagPortraitFan, L10n.tagRareScreenshot],
            stats: [
                PersonaStat(value: "86",   label: L10n.isEn ? "Photos" : "本月照片"),
                PersonaStat(value: "-62%", label: L10n.isEn ? "vs avg" : "低于均值"),
                PersonaStat(value: "0.9G", label: L10n.isEn ? "Storage" : "占用空间"),
            ],
            gradient: [Color(hex: "6e5f52"), Color(hex: "493c34"), Color(hex: "251f1a")],
            glow: Color(hex: "d9cfc0").opacity(0.45),
            endingSymbol: "◾️",
            endingStat: PersonaStat(value: "1,120", label: L10n.isEn ? "photos · curated" : "张照片 · 全年克制"),
            endingLine1: L10n.personaEndMinimalistL1,
            endingLine2Html: L10n.personaEndMinimalistL2
        ),
        ]
    }

    static func find(_ id: PersonaID) -> Persona {
        all.first(where: { $0.id == id }) ?? all[0]
    }
}

// MARK: - Content mix slice

struct ContentMixSlice: Identifiable {
    let id: String
    let label: String
    let value: Double     // percent (0..100)
    let color: Color
}

struct ScreenshotSource: Identifiable {
    var id: String { app }
    let app: String
    let pct: Int
}

struct SpaceCategory: Identifiable {
    var id: String { label }
    let label: String
    let count: Int
    let sizeGB: Double
    let tint: Color
}

struct WeeklyTrendSlice: Identifiable, Equatable {
    let id: Int
    let start: Date
    let end: Date
    let counts: [Int]   // Mon..Sun
    let total: Int
    let deltaPct: Int
    let topWeekday: Int // 0..6, Mon..Sun
    let hourHistogram: [Double] // 24 values, 0..1 normalized
    let peakHour: Int
    let peakHourPct: Int
}

// MARK: - Aggregated data powering the Insights screen

struct InsightsData {
    // Month header
    let monthLabel: String
    let monthCount: Int
    // Hero
    let primaryPersona: Persona
    // Trend card
    let week7Counts: [Int]      // 7 values, Mon..Sun
    let week7Total: Int
    let week7DeltaPct: Int      // +% vs previous week
    let weeklyTrends: [WeeklyTrendSlice]
    let initialWeekIndex: Int
    let hourHistogram: [Double] // 24 values, 0..1 normalized
    let peakHour: Int
    let peakHourPct: Int
    // Content mix
    let contentMix: [ContentMixSlice]
    let mixTopLabel: String
    let mixTopPct: Int
    // Screenshots
    let screenshotTotal: Int
    let screenshotUnusedPct: Int
    let screenshotSources: [ScreenshotSource]
    // Space
    let spaceUsedGB: Double
    let spaceTotalGB: Double
    let spaceReleasableGB: Double
    let spaceCategories: [SpaceCategory]
    // AI suggestion
    let aiSuggestCount: Int
    let aiSuggestSizeLabel: String
    // Annual
    let year: Int
    let yearTotal: Int
    let yearSizeGB: Int
    let monthBars: [Int]        // 12 monthly counts

    // MARK: - Factory

    static func build(
        allAssets: [PhotoAsset],
        screenshots: [PhotoAsset],
        temporaryRecords: [PhotoAsset],
        videos: [PhotoAsset],
        summary: LibrarySummary,
        duplicateGroups: [PhotoGroup] = [],
        similarGroups: [PhotoGroup] = [],
        lowQuality: [PhotoAsset] = [],
        now: Date = Date()
    ) -> InsightsData {
        let cal = Calendar(identifier: .gregorian)

        let components = cal.dateComponents([.year, .month], from: now)
        let year = components.year ?? 2026
        let month = components.month ?? 1

        // 1) This month
        let monthStart = cal.date(from: DateComponents(year: year, month: month, day: 1)) ?? now
        let nextMonthStart = cal.date(byAdding: .month, value: 1, to: monthStart) ?? now
        let thisMonthAssets = allAssets.filter { $0.creationDate >= monthStart && $0.creationDate < nextMonthStart }
        let thisMonthScreenshots = screenshots.filter { $0.creationDate >= monthStart && $0.creationDate < nextMonthStart }
        let thisMonthTemporary = temporaryRecords.filter { $0.creationDate >= monthStart && $0.creationDate < nextMonthStart }
        let thisMonthVideos = videos.filter { $0.creationDate >= monthStart && $0.creationDate < nextMonthStart }
        let monthCount = thisMonthAssets.count

        // Month label
        let monthLabel = L10n.monthLabel(month)

        // 2) 24h hour histogram (from selected month assets)
        let hourBuckets = Array(repeating: 0, count: 24)
        var hours = hourBuckets
        for a in thisMonthAssets {
            let h = cal.component(.hour, from: a.creationDate)
            if h >= 0 && h < 24 { hours[h] += 1 }
        }
        let hourMax = max(1, hours.max() ?? 1)
        let hourHistogram = hours.map { Double($0) / Double(hourMax) }

        // 3) Weekly slices in selected month (Mon..Sun), swipe-able in UI.
        let monthEnd = cal.date(byAdding: .day, value: -1, to: nextMonthStart) ?? now
        let dayCounts = Dictionary(grouping: thisMonthAssets) {
            cal.startOfDay(for: $0.creationDate)
        }.mapValues(\.count)

        func mondayStart(of date: Date) -> Date {
            let day = cal.startOfDay(for: date)
            let weekday = cal.component(.weekday, from: day) // Sun=1 ... Sat=7
            let mondayOffset = (weekday + 5) % 7             // Mon=0 ... Sun=6
            return cal.date(byAdding: .day, value: -mondayOffset, to: day) ?? day
        }

        let firstWeekStart = mondayStart(of: monthStart)
        let lastWeekStart = mondayStart(of: monthEnd)
        var weeklyTrends: [WeeklyTrendSlice] = []
        var cursor = firstWeekStart
        var weekID = 0
        var previousWeekTotal = 0
        while cursor <= lastWeekStart {
            var counts = Array(repeating: 0, count: 7)
            for dayIndex in 0..<7 {
                guard let day = cal.date(byAdding: .day, value: dayIndex, to: cursor) else { continue }
                if day < monthStart || day >= nextMonthStart { continue }
                counts[dayIndex] = dayCounts[cal.startOfDay(for: day)] ?? 0
            }
            let total = counts.reduce(0, +)
            let deltaPct = previousWeekTotal > 0
                ? Int(round(Double(total - previousWeekTotal) / Double(previousWeekTotal) * 100))
                : 0
            let topWeekday = counts.enumerated().max(by: { $0.element < $1.element })?.offset ?? 0
            let weekEndExclusive = cal.date(byAdding: .day, value: 7, to: cursor) ?? cursor
            let weekAssets = thisMonthAssets.filter { $0.creationDate >= cursor && $0.creationDate < weekEndExclusive }
            var weekHourCounts = Array(repeating: 0, count: 24)
            for a in weekAssets {
                let h = cal.component(.hour, from: a.creationDate)
                if h >= 0 && h < 24 { weekHourCounts[h] += 1 }
            }
            let weekHourMax = max(1, weekHourCounts.max() ?? 1)
            let weekHourHistogram = weekHourCounts.map { Double($0) / Double(weekHourMax) }
            let weekPeakHour: Int
            if let maxIdx = weekHourCounts.enumerated().max(by: { $0.element < $1.element })?.offset,
               (weekHourCounts.max() ?? 0) > 0 {
                weekPeakHour = maxIdx
            } else {
                weekPeakHour = 0
            }
            let weekShotTotal = weekHourCounts.reduce(0, +)
            let weekPeakHourPct = weekShotTotal > 0
                ? Int(round(Double(weekHourCounts[weekPeakHour]) / Double(weekShotTotal) * 100))
                : 0
            let rawEnd = cal.date(byAdding: .day, value: 6, to: cursor) ?? cursor
            let startInMonth = max(cursor, monthStart)
            let endInMonth = min(rawEnd, monthEnd)
            weeklyTrends.append(
                WeeklyTrendSlice(
                    id: weekID,
                    start: startInMonth,
                    end: endInMonth,
                    counts: counts,
                    total: total,
                    deltaPct: deltaPct,
                    topWeekday: topWeekday,
                    hourHistogram: weekHourHistogram,
                    peakHour: weekPeakHour,
                    peakHourPct: weekPeakHourPct
                )
            )
            previousWeekTotal = total
            weekID += 1
            cursor = cal.date(byAdding: .day, value: 7, to: cursor) ?? cursor
            if weekID > 8 { break } // one month should not exceed 6 weeks; hard stop for safety
        }
        if weeklyTrends.isEmpty {
            weeklyTrends = [
                WeeklyTrendSlice(
                    id: 0,
                    start: monthStart,
                    end: monthEnd,
                    counts: Array(repeating: 0, count: 7),
                    total: 0,
                    deltaPct: 0,
                    topWeekday: 0,
                    hourHistogram: Array(repeating: 0, count: 24),
                    peakHour: 0,
                    peakHourPct: 0
                )
            ]
        }
        let weekRefDate = min(Date(), monthEnd)
        let initialWeekStart = mondayStart(of: max(weekRefDate, monthStart))
        let initialWeekIndex = weeklyTrends.firstIndex {
            cal.startOfDay(for: $0.start) == cal.startOfDay(for: max(initialWeekStart, monthStart))
        } ?? max(0, weeklyTrends.count - 1)
        let selectedWeek = weeklyTrends[min(max(initialWeekIndex, 0), weeklyTrends.count - 1)]
        let weekUsed = selectedWeek.counts
        let week7Total = selectedWeek.total
        let week7DeltaPct = selectedWeek.deltaPct

        // 4) Content mix
        let screenshotCount = thisMonthScreenshots.count
        let tempCount = thisMonthTemporary.count
        let videoCount = thisMonthVideos.count
        let photoCount = max(0, thisMonthAssets.count - screenshotCount - tempCount - videoCount)
        let totalForMix = thisMonthAssets.count

        func pct(_ v: Int) -> Double {
            guard totalForMix > 0 else { return 0 }
            return Double(v) / Double(totalForMix) * 100
        }

        var mix: [ContentMixSlice] = [
            ContentMixSlice(id: "portrait",  label: L10n.isEn ? "Portrait"   : "人像",
                            value: pct(photoCount), color: Color(hex: "ff9b4b")),
            ContentMixSlice(id: "screenshot", label: L10n.isEn ? "Screenshot" : "截图",
                            value: pct(screenshotCount), color: Color(hex: "63a4ff")),
            ContentMixSlice(id: "video",     label: L10n.isEn ? "Video"      : "视频",
                            value: pct(videoCount), color: Color(hex: "f8a64a")),
            ContentMixSlice(id: "document",  label: L10n.isEn ? "Document"   : "文档",
                            value: pct(tempCount), color: Color(hex: "a484ff")),
            ContentMixSlice(id: "other",     label: L10n.isEn ? "Other"      : "其他",
                            value: max(0, 100 - (pct(photoCount) + pct(screenshotCount) + pct(videoCount) + pct(tempCount))),
                            color: Color(hex: "c0c0c8")),
        ].filter { $0.value > 0.5 }
        if mix.isEmpty {
            mix = [
                ContentMixSlice(
                    id: "other",
                    label: L10n.isEn ? "Other" : "其他",
                    value: 100,
                    color: Color(hex: "c0c0c8")
                )
            ]
        }

        let top = mix.max(by: { $0.value < $1.value }) ?? mix[0]
        let mixTopLabel = top.label
        let mixTopPct   = Int(round(top.value))

        // 5) Screenshots insight
        let screenshotSources = Self.mockScreenshotSources()
        let screenshotUnused = 88  // heuristic

        // 6) Space summary
        let totalGB = Double(summary.totalBytes) / (1024.0 * 1024.0 * 1024.0)
        let bytesToGB: (Int64) -> Double = { Double($0) / (1024.0 * 1024.0 * 1024.0) }
        let duplicateFreeableAssets = (duplicateGroups + similarGroups).flatMap { $0.assets.dropFirst() }
        let duplicateFreeableBytes = duplicateFreeableAssets.reduce(Int64(0)) { $0 + $1.sizeBytes }
        let screenshotFreeableBytes = screenshots.reduce(Int64(0)) { $0 + $1.sizeBytes }
        let temporaryFreeableBytes = temporaryRecords.reduce(Int64(0)) { $0 + $1.sizeBytes }
        let lowQualityBytes = lowQuality.reduce(Int64(0)) { $0 + $1.sizeBytes }
        let videoFreeableBytes = videos.reduce(Int64(0)) { $0 + $1.sizeBytes }
        let liveConvertFreeableBytes = Int64(Double(summary.livePhotoBytes) * 0.55)
        let categories: [SpaceCategory] = [
            SpaceCategory(label: L10n.isEn ? "Duplicates & similar" : "重复与相似",
                          count: duplicateFreeableAssets.count,
                          sizeGB: bytesToGB(duplicateFreeableBytes),
                          tint: Color(hex: "ff9b4b")),
            SpaceCategory(label: L10n.isEn ? "Screenshots" : "截图",
                          count: screenshots.count,
                          sizeGB: bytesToGB(screenshotFreeableBytes),
                          tint: Color(hex: "63a4ff")),
            SpaceCategory(label: L10n.isEn ? "Temporary photos" : "临时照片",
                          count: temporaryRecords.count,
                          sizeGB: bytesToGB(temporaryFreeableBytes),
                          tint: Color(hex: "7f8cff")),
            SpaceCategory(label: L10n.isEn ? "Low quality" : "低质量",
                          count: lowQuality.count,
                          sizeGB: bytesToGB(lowQualityBytes),
                          tint: Color(hex: "5bd08a")),
            SpaceCategory(label: L10n.isEn ? "Videos" : "视频文件",
                          count: videos.count,
                          sizeGB: bytesToGB(videoFreeableBytes),
                          tint: Color(hex: "ff8f8f")),
            SpaceCategory(label: L10n.isEn ? "Live → Still" : "Live转静态",
                          count: summary.livePhotoCount,
                          sizeGB: bytesToGB(liveConvertFreeableBytes),
                          tint: Color(hex: "ffb168")),
        ].filter { $0.count > 0 || $0.sizeGB > 0 }
        let categoriesTotalBytes = duplicateFreeableBytes + screenshotFreeableBytes + temporaryFreeableBytes
            + lowQualityBytes + videoFreeableBytes + liveConvertFreeableBytes
        let freeableGB = bytesToGB(max(summary.freeableBytes, categoriesTotalBytes))

        // 7) Persona pick
        let monthDaysActive = Set(thisMonthAssets.map { cal.startOfDay(for: $0.creationDate) }).count
        let weekendShots = thisMonthAssets.filter {
            let wd = cal.component(.weekday, from: $0.creationDate)
            return wd == 1 || wd == 7
        }.count
        let weekendShare = thisMonthAssets.isEmpty ? 0 : (Double(weekendShots) / Double(thisMonthAssets.count) * 100)
        let persona = Self.pickPersona(
            hourHistogram: hourHistogram,
            photoShare: mix.first(where: { $0.id == "portrait" })?.value ?? 0,
            screenshotShare: mix.first(where: { $0.id == "screenshot" })?.value ?? 0,
            totalPhotos: thisMonthAssets.count,
            activeDays: monthDaysActive,
            weekendShare: weekendShare
        )

        // 8) AI suggestion (temporary screenshots)
        let aiSuggestCount = tempCount
        let aiSize = ByteCountFormatter.string(
            fromByteCount: Int64(Double(aiSuggestCount) * 3_500_000), countStyle: .file
        )

        // 9) Year data for Annual Report
        let yearStart = cal.date(from: DateComponents(year: year, month: 1, day: 1)) ?? now
        let nextYearStart = cal.date(from: DateComponents(year: year + 1, month: 1, day: 1)) ?? now
        let yearAssetsForMonth = allAssets.filter { $0.creationDate >= yearStart && $0.creationDate < nextYearStart }
        var monthBuckets = Array(repeating: 0, count: 12)
        for a in yearAssetsForMonth {
            let m = cal.component(.month, from: a.creationDate)
            if m >= 1 && m <= 12 { monthBuckets[m - 1] += 1 }
        }
        let yearTotal = monthBuckets.reduce(0, +)
        let yearMonthBarsUsed = monthBuckets
        let yearTotalUsed = yearTotal
        let yearSizeGB = Int(round(Double(yearTotalUsed) * 7.0 / 1024.0))  // ~7MB/photo heuristic

        return InsightsData(
            monthLabel: monthLabel,
            monthCount: monthCount,
            primaryPersona: persona,
            week7Counts: weekUsed,
            week7Total: week7Total,
            week7DeltaPct: week7DeltaPct,
            weeklyTrends: weeklyTrends,
            initialWeekIndex: initialWeekIndex,
            hourHistogram: selectedWeek.hourHistogram,
            peakHour: selectedWeek.peakHour,
            peakHourPct: selectedWeek.peakHourPct,
            contentMix: mix,
            mixTopLabel: mixTopLabel,
            mixTopPct: mixTopPct,
            screenshotTotal: screenshotCount,
            screenshotUnusedPct: screenshotUnused,
            screenshotSources: screenshotSources,
            spaceUsedGB: totalGB,
            spaceTotalGB: 128,
            spaceReleasableGB: freeableGB,
            spaceCategories: categories,
            aiSuggestCount: aiSuggestCount,
            aiSuggestSizeLabel: aiSize,
            year: year,
            yearTotal: yearTotalUsed,
            yearSizeGB: yearSizeGB,
            monthBars: yearMonthBarsUsed
        )
    }

    private static func pickPersona(
        hourHistogram: [Double],
        photoShare: Double,
        screenshotShare: Double,
        totalPhotos: Int,
        activeDays: Int,
        weekendShare: Double
    ) -> Persona {
        // Extremely low-volume months default to minimalist.
        if totalPhotos <= 40 {
            return PersonaCatalog.find(.minimalist)
        }

        // Hoarder: screenshot-heavy month.
        if screenshotShare >= 35 || (totalPhotos >= 120 && screenshotShare >= 28) {
            return PersonaCatalog.find(.hoarder)
        }

        // Night-owl: strong bias to evening and late-night (20:00-03:59).
        let nightHours = [20, 21, 22, 23, 0, 1, 2, 3]
        let nightSum = nightHours.reduce(0.0) { partial, hour in
            guard hourHistogram.indices.contains(hour) else { return partial }
            return partial + hourHistogram[hour]
        }
        let totalSum = hourHistogram.reduce(0.0, +)
        if totalSum > 0 && nightSum / totalSum >= 0.42 {
            return PersonaCatalog.find(.nightOwl)
        }

        // Foodie if lunch+dinner hours dominate.
        let mealHours: Set<Int> = [11, 12, 13, 18, 19, 20]
        let mealSum = mealHours.reduce(0.0) { $0 + hourHistogram[$1] }
        if totalSum > 0 && mealSum / totalSum >= 0.5 {
            return PersonaCatalog.find(.foodie)
        }

        // Parent if portrait-like content dominates and activity is spread across the month.
        if photoShare >= 58 && activeDays >= 8 {
            return PersonaCatalog.find(.parent)
        }

        // Wanderer if heavily weekend-oriented with enough active days.
        if weekendShare >= 50 && activeDays >= 6 {
            return PersonaCatalog.find(.wanderer)
        }

        // Sparse but active months still lean minimalist.
        if totalPhotos < 120 {
            return PersonaCatalog.find(.minimalist)
        }

        // Default fallback.
        return PersonaCatalog.find(.wanderer)
    }

    // MARK: - Mocks used when no data is available yet
    private static func mockHourHistogram() -> [Double] {
        // Night-owl shape
        [0.14, 0.10, 0.04, 0.02, 0.02, 0.02, 0.06, 0.12,
         0.22, 0.24, 0.20, 0.28, 0.46, 0.40, 0.22, 0.24,
         0.20, 0.24, 0.50, 0.64, 0.76, 0.88, 1.00, 0.82]
    }

    private static func mockContentMix() -> [ContentMixSlice] {
        [
            ContentMixSlice(id: "portrait",   label: L10n.isEn ? "Portrait"   : "人像",   value: 38, color: Color(hex: "ff9b4b")),
            ContentMixSlice(id: "screenshot", label: L10n.isEn ? "Screenshot" : "截图",   value: 27, color: Color(hex: "63a4ff")),
            ContentMixSlice(id: "food",       label: L10n.isEn ? "Food"       : "美食",   value: 12, color: Color(hex: "e96a4a")),
            ContentMixSlice(id: "scenery",    label: L10n.isEn ? "Scenery"    : "风景",   value: 10, color: Color(hex: "5bd08a")),
            ContentMixSlice(id: "pet",        label: L10n.isEn ? "Pet"        : "宠物",   value: 7,  color: Color(hex: "e8c24a")),
            ContentMixSlice(id: "document",   label: L10n.isEn ? "Document"   : "文档",   value: 4,  color: Color(hex: "a484ff")),
            ContentMixSlice(id: "other",      label: L10n.isEn ? "Other"      : "其他",   value: 2,  color: Color(hex: "c0c0c8")),
        ]
    }

    private static func mockScreenshotSources() -> [ScreenshotSource] {
        [
            ScreenshotSource(app: L10n.isEn ? "WeChat"     : "微信",       pct: 42),
            ScreenshotSource(app: L10n.isEn ? "Rednote"    : "小红书",     pct: 21),
            ScreenshotSource(app: "Safari",                                 pct: 14),
            ScreenshotSource(app: L10n.isEn ? "Meituan"    : "美团",       pct: 9),
            ScreenshotSource(app: L10n.isEn ? "Other"      : "其他",       pct: 14),
        ]
    }
}
