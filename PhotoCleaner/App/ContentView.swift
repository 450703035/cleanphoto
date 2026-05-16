import SwiftUI

struct ContentView: View {
    @ObservedObject var scanVM: ScanViewModel
    @ObservedObject var libraryVM: LibraryViewModel
    @State private var selectedTab = 0
    @AppStorage("appLanguage") private var appLanguage = "zh"

    var body: some View {
        TabView(selection: $selectedTab) {
            InsightsView(onGoClean: { selectedTab = 1 })
                .environmentObject(scanVM)
                .environmentObject(libraryVM)
                .tabItem {
                    Label(L10n.tabInsights, systemImage: "chart.bar.fill")
                }
                .tag(0)

            HomeView()
                .environmentObject(scanVM)
                .environmentObject(libraryVM)
                .tabItem {
                    Label(L10n.tabClean, systemImage: "sparkles")
                }
                .tag(1)

            TimelineView()
                .environmentObject(scanVM)
                .environmentObject(libraryVM)
                .tabItem {
                    Label(L10n.tabTimeline, systemImage: "calendar")
                }
                .tag(2)

            SettingsView()
                .environmentObject(scanVM)
                .tabItem {
                    Label(L10n.tabMe, systemImage: "person.circle")
                }
                .tag(3)
        }
        .tint(AppColors.purple)
        .id(appLanguage)
        .task {
            await scanVM.requestAuthorizationOnAppLaunchIfNeeded()
            await scanVM.loadCachedResultsIfAvailable()
            scanVM.startIncrementalSyncOnAppLaunchIfNeeded()
        }
        .onChange(of: selectedTab) { _ in
            scanVM.markForegroundTransition()
        }
    }
}

private struct InsightsView: View {
    @EnvironmentObject var scanVM: ScanViewModel
    @EnvironmentObject var libraryVM: LibraryViewModel
    var onGoClean: () -> Void
    @State private var focusedMonthStart = InsightsView.monthStart(for: Date())
    @State private var showAnnualReport = false
    @State private var insightsSnapshot = InsightsSnapshot.empty(now: Date())
    @State private var insightsRefreshTask: Task<Void, Never>?

    private var sourceAssets: [PhotoAsset] {
        scanVM.allAssets.isEmpty ? libraryVM.allAssets : scanVM.allAssets
    }

    private var data: InsightsData {
        insightsSnapshot.current
    }

    private var selectedPersona: Persona {
        data.primaryPersona
    }

    private var prevMonthData: InsightsData? {
        canGoPrevMonth ? insightsSnapshot.previous : nil
    }

    private var nextMonthData: InsightsData? {
        canGoNextMonth ? insightsSnapshot.next : nil
    }

    private var monthBounds: (min: Date, max: Date) {
        insightsSnapshot.monthBounds
    }

    private var insightsRefreshKey: String {
        [
            "\(sourceAssets.count)",
            "\(scanVM.screenshots.count)",
            "\(scanVM.temporaryRecords.count)",
            "\(scanVM.videos.count)",
            "\(scanVM.duplicateGroups.count)",
            "\(scanVM.similarGroups.count)",
            "\(scanVM.lowQuality.count)",
            "\(scanVM.summary.totalBytes)",
            "\(scanVM.summary.freeableBytes)",
            "\(scanVM.fileSizeVersion)"
        ].joined(separator: "|")
    }

    private var monthDisplayText: String {
        let comps = Calendar.current.dateComponents([.year, .month], from: focusedMonthStart)
        let y = comps.year ?? Calendar.current.component(.year, from: Date())
        let m = comps.month ?? Calendar.current.component(.month, from: Date())
        if L10n.isEn {
            return "\(L10n.monthLabel(m)) \(y)"
        }
        return "\(y)年\(m)月"
    }

    private var canGoPrevMonth: Bool { focusedMonthStart > monthBounds.min }
    private var canGoNextMonth: Bool { focusedMonthStart < monthBounds.max }

    fileprivate static func monthStart(for date: Date) -> Date {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: date)
        return cal.date(from: DateComponents(year: comps.year, month: comps.month, day: 1)) ?? date
    }

    private func clampMonth(_ date: Date) -> Date {
        if date < monthBounds.min { return monthBounds.min }
        if date > monthBounds.max { return monthBounds.max }
        return date
    }

    private func shiftMonth(by delta: Int, animated: Bool = true) {
        guard delta != 0 else { return }
        guard let moved = Calendar.current.date(byAdding: .month, value: delta, to: focusedMonthStart) else { return }
        let nextMonth = clampMonth(Self.monthStart(for: moved))
        if animated {
            withAnimation(.easeOut(duration: 0.2)) {
                focusedMonthStart = nextMonth
            }
        } else {
            focusedMonthStart = nextMonth
        }
    }

    private func clampFocusedMonthIfNeeded() {
        let clamped = clampMonth(Self.monthStart(for: focusedMonthStart))
        if clamped != focusedMonthStart {
            focusedMonthStart = clamped
        }
    }

    private func refreshInsightsSnapshot() {
        insightsRefreshTask?.cancel()
        let allAssets = sourceAssets
        let screenshots = scanVM.screenshots
        let temporaryRecords = scanVM.temporaryRecords
        let videos = scanVM.videos
        let summary = scanVM.summary
        let duplicateGroups = scanVM.duplicateGroups
        let similarGroups = scanVM.similarGroups
        let lowQuality = scanVM.lowQuality
        let focused = focusedMonthStart
        insightsRefreshTask = Task(priority: .userInitiated) {
            let snapshot = await Task.detached(priority: .userInitiated) {
                InsightsSnapshot.build(
                    allAssets: allAssets,
                    screenshots: screenshots,
                    temporaryRecords: temporaryRecords,
                    videos: videos,
                    summary: summary,
                    duplicateGroups: duplicateGroups,
                    similarGroups: similarGroups,
                    lowQuality: lowQuality,
                    focusedMonthStart: focused
                )
            }.value
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard focusedMonthStart == focused else { return }
                insightsSnapshot = snapshot
                clampFocusedMonthIfNeeded()
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.darkBG.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L10n.insightsTitle)
                                .font(AppTypography.hero)
                                .foregroundColor(AppColors.textPrimary)
                            Text(L10n.insightsSubtitle(data.monthLabel, data.monthCount))
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textSecondary)
                        }
                        .padding(.horizontal)
                        .padding(.top, 16)

                        PersonaHero(
                            persona: selectedPersona,
                            year: data.year,
                            yearTotal: data.yearTotal,
                            previous: prevMonthData.map {
                                .init(persona: $0.primaryPersona, year: $0.year, yearTotal: $0.yearTotal)
                            },
                            next: nextMonthData.map {
                                .init(persona: $0.primaryPersona, year: $0.year, yearTotal: $0.yearTotal)
                            },
                            canSwipePrev: canGoPrevMonth,
                            canSwipeNext: canGoNextMonth,
                            onSwipePrev: { shiftMonth(by: -1, animated: false) },
                            onSwipeNext: { shiftMonth(by: 1, animated: false) }
                        ) {
                            showAnnualReport = true
                        }

                        MonthlyPersonaSwitcher(
                            label: monthDisplayText,
                            canPrev: canGoPrevMonth,
                            canNext: canGoNextMonth,
                            onPrev: { shiftMonth(by: -1) },
                            onNext: { shiftMonth(by: 1) }
                        )
                        .padding(.horizontal, 16)

                        InsightsSectionHeader(
                            eyebrow: L10n.insightsSectionBehavior,
                            title: L10n.insightsSectionBehaviorTitle
                        )
                        TrendCard(
                            weeklyTrends: data.weeklyTrends,
                            initialWeekIndex: data.initialWeekIndex,
                            monthYearKey: "\(data.year)-\(data.monthLabel)"
                        )
                        .padding(.horizontal, 16)
                        ContentMixCard(
                            slices: data.contentMix,
                            topLabel: data.mixTopLabel,
                            topPct: data.mixTopPct
                        )
                        .padding(.horizontal, 16)
                        ScreenshotInsightCard(
                            total: data.screenshotTotal,
                            unusedPct: data.screenshotUnusedPct,
                            sources: data.screenshotSources
                        )
                        .padding(.horizontal, 16)

                        InsightsSectionHeader(
                            eyebrow: L10n.insightsSectionClean,
                            title: L10n.insightsSectionCleanTitle
                        )
                        SpaceReleaseCard(
                            libraryGB: data.spaceUsedGB,
                            releasableGB: data.spaceReleasableGB,
                            categories: data.spaceCategories
                        ) {
                            onGoClean()
                        }
                        .padding(.horizontal, 16)

                        Text(L10n.insightsLocalOnly)
                            .font(AppTypography.micro)
                            .foregroundColor(AppColors.textTertiary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 8)
                            .padding(.bottom, 24)
                    }
                }
            }
            .navigationBarHidden(true)
            .fullScreenCover(isPresented: $showAnnualReport) {
                AnnualReportView(data: data, initialPersona: selectedPersona)
            }
            .onAppear {
                focusedMonthStart = clampMonth(Self.monthStart(for: Date()))
                scanVM.markForegroundTransition(duration: 0.9)
                refreshInsightsSnapshot()
            }
            .onChange(of: focusedMonthStart) { _ in
                refreshInsightsSnapshot()
            }
            .onChange(of: insightsRefreshKey) { _ in
                clampFocusedMonthIfNeeded()
                refreshInsightsSnapshot()
            }
        }
    }
}

private struct InsightsSnapshot {
    let current: InsightsData
    let previous: InsightsData?
    let next: InsightsData?
    let monthBounds: (min: Date, max: Date)

    static func empty(now: Date) -> InsightsSnapshot {
        let month = InsightsView.monthStart(for: now)
        let current = InsightsData.build(
            allAssets: [],
            screenshots: [],
            temporaryRecords: [],
            videos: [],
            summary: LibrarySummary(),
            duplicateGroups: [],
            similarGroups: [],
            lowQuality: [],
            now: month
        )
        return InsightsSnapshot(current: current, previous: nil, next: nil, monthBounds: (month, month))
    }

    static func build(
        allAssets: [PhotoAsset],
        screenshots: [PhotoAsset],
        temporaryRecords: [PhotoAsset],
        videos: [PhotoAsset],
        summary: LibrarySummary,
        duplicateGroups: [PhotoGroup],
        similarGroups: [PhotoGroup],
        lowQuality: [PhotoAsset],
        focusedMonthStart: Date
    ) -> InsightsSnapshot {
        let bounds = monthBounds(for: allAssets)
        let focused = min(max(focusedMonthStart, bounds.min), bounds.max)
        let current = InsightsData.build(
            allAssets: allAssets,
            screenshots: screenshots,
            temporaryRecords: temporaryRecords,
            videos: videos,
            summary: summary,
            duplicateGroups: duplicateGroups,
            similarGroups: similarGroups,
            lowQuality: lowQuality,
            now: focused
        )
        let previousDate = Calendar.current.date(byAdding: .month, value: -1, to: focused)
        let nextDate = Calendar.current.date(byAdding: .month, value: 1, to: focused)
        let previous = previousDate.flatMap { date -> InsightsData? in
            guard date >= bounds.min else { return nil }
            return InsightsData.build(
                allAssets: allAssets,
                screenshots: screenshots,
                temporaryRecords: temporaryRecords,
                videos: videos,
                summary: summary,
                duplicateGroups: duplicateGroups,
                similarGroups: similarGroups,
                lowQuality: lowQuality,
                now: date
            )
        }
        let next = nextDate.flatMap { date -> InsightsData? in
            guard date <= bounds.max else { return nil }
            return InsightsData.build(
                allAssets: allAssets,
                screenshots: screenshots,
                temporaryRecords: temporaryRecords,
                videos: videos,
                summary: summary,
                duplicateGroups: duplicateGroups,
                similarGroups: similarGroups,
                lowQuality: lowQuality,
                now: date
            )
        }
        return InsightsSnapshot(current: current, previous: previous, next: next, monthBounds: bounds)
    }

    private static func monthBounds(for assets: [PhotoAsset]) -> (min: Date, max: Date) {
        guard !assets.isEmpty else {
            let now = InsightsView.monthStart(for: Date())
            return (now, now)
        }
        var earliest = assets[0].creationDate
        var latest = assets[0].creationDate
        for asset in assets.dropFirst() {
            let date = asset.creationDate
            if date < earliest { earliest = date }
            if date > latest { latest = date }
        }
        let minMonth = InsightsView.monthStart(for: earliest)
        let maxMonth = max(InsightsView.monthStart(for: latest), InsightsView.monthStart(for: Date()))
        return (minMonth, maxMonth)
    }
}

private struct MonthlyPersonaSwitcher: View {
    let label: String
    let canPrev: Bool
    let canNext: Bool
    let onPrev: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onPrev) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(canPrev ? AppColors.textPrimary : AppColors.textTertiary)
                    .frame(width: 30, height: 30)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(!canPrev)

            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppColors.textSecondary)
                .frame(maxWidth: .infinity)

            Button(action: onNext) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(canNext ? AppColors.textPrimary : AppColors.textTertiary)
                    .frame(width: 30, height: 30)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(!canNext)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.04))
        .overlay(
            RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 18)
                .onEnded { v in
                    if v.translation.width > 40, canPrev {
                        onPrev()
                    } else if v.translation.width < -40, canNext {
                        onNext()
                    }
                }
        )
    }
}
