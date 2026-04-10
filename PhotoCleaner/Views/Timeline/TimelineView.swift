import SwiftUI
import Photos
import CoreLocation
import AVKit

// MARK: - Root

struct TimelineView: View {
    @EnvironmentObject var vm: LibraryViewModel
    @State private var viewMode: TimelineMode = .list
    @State private var selectedFolder: AlbumFolder? = nil
    @State private var selectedDay: DayInfo? = nil
    @State private var calendarYear: Int = Calendar.current.component(.year, from: Date())

    enum TimelineMode { case list, calendar, waterfall }

    private var shouldShowScoringBar: Bool {
        vm.isLoading || (vm.scoringProgress < 1.0)
    }

    private var displayProgress: Double {
        if vm.isLoading && vm.scoringProgress >= 1.0 { return 0.99 }
        return min(max(vm.scoringProgress, 0), 1.0)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.darkBG.ignoresSafeArea()
                VStack(spacing: 0) {
                    // ── Main header ──────────────────────────────────────
                    HStack {
                        Text("时间线")
                            .font(AppTypography.sectionTitle).foregroundColor(AppColors.textPrimary)
                        Spacer()
                        Picker("", selection: $viewMode) {
                            Text("列表").tag(TimelineMode.list)
                            Text("日历").tag(TimelineMode.calendar)
                            Text("瀑布").tag(TimelineMode.waterfall)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 190)
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)
                    .padding(.bottom, 8)

                    // ── Calendar sub-header: year + legend ───────────────
                    if viewMode == .calendar {
                        HStack(alignment: .center, spacing: 0) {
                            Text("\(calendarYear)年")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(AppColors.lightPurple)
                            Text(vm.yearSize(calendarYear).formattedFileSize)
                                .font(.system(size: 12))
                                .foregroundColor(AppColors.textSecondary)
                                .padding(.leading, 6)
                            Spacer()
                            // Compact inline legend
                            HStack(spacing: 8) {
                                ForEach([
                                    (Color(hex: "D3F9D8"), "少"),
                                    (Color(hex: "69DB7C"), "中"),
                                    (Color(hex: "FFD43B"), "多"),
                                    (Color(hex: "FF6B6B"), "满")
                                ], id: \.1) { color, label in
                                    HStack(spacing: 2) {
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(color).frame(width: 10, height: 10)
                                        Text(label)
                                            .font(.system(size: 9))
                                            .foregroundColor(AppColors.textSecondary)
                                    }
                                }
                                Divider().frame(height: 10).background(AppColors.textTertiary)
                                ForEach([
                                    (AppColors.red, "<40"),
                                    (AppColors.amber, "40-70"),
                                    (AppColors.green, ">70")
                                ], id: \.1) { color, label in
                                    HStack(spacing: 2) {
                                        Circle().fill(color).frame(width: 6, height: 6)
                                        Text(label)
                                            .font(.system(size: 9))
                                            .foregroundColor(AppColors.textSecondary)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 6)
                        .transition(.opacity)
                    }

                    // ── Scoring progress bar ─────────────────────────────
                    if shouldShowScoringBar {
                        VStack(spacing: 3) {
                            ProgressView(value: displayProgress)
                                .tint(AppColors.lightPurple)
                                .padding(.horizontal)
                            Text(vm.isLoading && vm.scoringProgress >= 1.0
                                 ? "数据刷新中…"
                                 : "照片打分中 \(Int(displayProgress * 100))%")
                                .font(.system(size: 10))
                                .foregroundColor(AppColors.textSecondary)
                        }
                        .padding(.bottom, 6)
                    }

                    if vm.isLoading && vm.allAssets.isEmpty {
                        Spacer()
                        TimelineLoadingPlaceholder(mode: viewMode)
                        Spacer()
                    } else if viewMode == .list {
                        TimelineListView(vm: vm, onFolderTap: { selectedFolder = $0 })
                    } else if viewMode == .calendar {
                        CalendarContainerView(vm: vm, onDayTap: { selectedDay = $0 },
                                             visibleYear: $calendarYear)
                    } else {
                        TimelineWaterfallView(vm: vm)
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(item: $selectedFolder) { folder in
                AlbumFolderDetailView(folder: folder, selectionOverrides: vm.selectionOverrides)
            }
            .sheet(item: $selectedDay) { day in
                DayPhotoDetailView(dayInfo: day, selectionOverrides: vm.selectionOverrides)
            }
            .task { await vm.load() }
        }
    }
}

private struct TimelineLoadingPlaceholder: View {
    let mode: TimelineView.TimelineMode

    var body: some View {
        VStack(spacing: 12) {
            ProgressView("正在加载时间线…")
                .foregroundColor(AppColors.textSecondary)
            if mode != .calendar {
                VStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(AppColors.cardBG.opacity(0.7))
                        .frame(height: 18)
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 10).fill(AppColors.cardBG.opacity(0.7))
                        RoundedRectangle(cornerRadius: 10).fill(AppColors.cardBG.opacity(0.7))
                        RoundedRectangle(cornerRadius: 10).fill(AppColors.cardBG.opacity(0.7))
                    }
                    .frame(height: 110)
                }
                .padding(.horizontal, 16)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - List view

struct TimelineListView: View {
    @ObservedObject var vm: LibraryViewModel
    let onFolderTap: (AlbumFolder) -> Void
    @State private var stickyYear: Int? = nil
    private let cols = [
        GridItem(.flexible(), spacing: 4),
        GridItem(.flexible(), spacing: 4),
        GridItem(.flexible(), spacing: 4)
    ]

    private var visibleYear: Int? {
        stickyYear ?? vm.sortedYears.first
    }

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                LazyVStack(spacing: 0) {
                    // Reserve space for sticky year header so content won't be covered.
                    Color.clear.frame(height: 42)

                    ForEach(vm.sortedYears, id: \.self) { year in
                        Color.clear
                            .frame(height: 0)
                            .background(
                                GeometryReader { geo in
                                    Color.clear.preference(
                                        key: TimelineYearHeaderOffsetKey.self,
                                        value: [year: geo.frame(in: .named("timelineListScroll")).minY]
                                    )
                                }
                            )
                            .onAppear {
                                if stickyYear == nil { stickyYear = year }
                            }

                        if year != visibleYear {
                            HStack(spacing: 6) {
                                Text("\(year)")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(AppColors.textPrimary)
                                Text(vm.yearSize(year).formattedFileSize)
                                    .font(.system(size: 11))
                                    .foregroundColor(AppColors.textSecondary)
                                let selYear = vm.yearSelectedSize(year)
                                if selYear > 0 {
                                    Text("· 删 \(selYear.formattedFileSize)")
                                        .font(.system(size: 11))
                                        .foregroundColor(AppColors.red)
                                }
                                Spacer()
                                Text("点击进入 · 长按删除")
                                    .font(.caption)
                                    .foregroundColor(AppColors.textTertiary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(AppColors.darkBG.opacity(0.95))
                        }

                        ForEach(vm.months(for: year), id: \.self) { month in
                            VStack(alignment: .leading, spacing: 6) {
                                // Month label + size
                                HStack(spacing: 6) {
                                    Text(month)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(AppColors.textSecondary)
                                    Text(vm.monthSize(year: year, month: month).formattedFileSize)
                                        .font(.system(size: 10))
                                        .foregroundColor(AppColors.textTertiary)
                                    let sel = vm.monthSelectedSize(year: year, month: month)
                                    if sel > 0 {
                                        Text("· 删 \(sel.formattedFileSize)")
                                            .font(.system(size: 10))
                                            .foregroundColor(AppColors.red)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.top, 10)

                                LazyVGrid(columns: cols, spacing: 4) {
                                    ForEach(vm.yearGroups[year]?[month] ?? []) { folder in
                                        AlbumFolderCell(
                                            folder: folder,
                                            onTap: { onFolderTap(folder) },
                                            onLongPress: {}
                                        )
                                    }
                                }
                                .padding(.horizontal, 14)
                            }
                        }
                    }
                }
                .padding(.bottom, 20)
            }
            .coordinateSpace(name: "timelineListScroll")
            .onPreferenceChange(TimelineYearHeaderOffsetKey.self) { offsets in
                guard !offsets.isEmpty else { return }
                let threshold: CGFloat = 42
                let sorted = offsets.sorted { $0.value < $1.value }
                if let reached = sorted.last(where: { $0.value <= threshold }) {
                    stickyYear = reached.key
                } else if let first = sorted.first {
                    stickyYear = first.key
                }
            }

            if let year = visibleYear {
                HStack(spacing: 6) {
                    Text("\(year)")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                    Text(vm.yearSize(year).formattedFileSize)
                        .font(.system(size: 11))
                        .foregroundColor(AppColors.textSecondary)
                    let selYear = vm.yearSelectedSize(year)
                    if selYear > 0 {
                        Text("· 删 \(selYear.formattedFileSize)")
                            .font(.system(size: 11))
                            .foregroundColor(AppColors.red)
                    }
                    Spacer()
                    Text("点击进入 · 长按删除")
                        .font(.caption)
                        .foregroundColor(AppColors.textTertiary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(AppColors.darkBG.opacity(0.98))
            }
        }
        // Pull-to-refresh → wipe cached scores and rescore everything
        .refreshable { await vm.rescore() }
    }
}

// MARK: - Waterfall view

struct TimelineWaterfallView: View {
    @ObservedObject var vm: LibraryViewModel
    @State private var assets: [PhotoAsset] = []
    @State private var viewerRequest: PhotoViewerRequest? = nil
    @State private var deleting = false
    @State private var playingVideoAssetID: String? = nil

    private var selected: [PhotoAsset] { assets.filter { $0.isSelected } }
    private var isAllSelected: Bool { !assets.isEmpty && assets.allSatisfy { $0.isSelected } }

    var body: some View {
        ZStack(alignment: .bottom) {
            GeometryReader { geo in
                let colWidth = max(120, (geo.size.width - 34) / 2)
                let indexMap = Dictionary(uniqueKeysWithValues: assets.enumerated().map { ($0.element.id, $0.offset) })
                let sections = monthSections(from: assets)

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0, pinnedViews: .sectionHeaders) {
                        HStack(spacing: 12) {
                            Text("共\(assets.count)项（照片+视频）")
                                .font(.system(size: 12))
                                .foregroundColor(AppColors.textSecondary)
                            Spacer()
                            Button(isAllSelected ? "取消全选" : "全选") {
                                let next = !isAllSelected
                                for i in assets.indices {
                                    assets[i].isSelected = next
                                    vm.selectionOverrides[assets[i].id] = next
                                }
                            }
                            .font(.subheadline)
                            .foregroundColor(AppColors.lightPurple)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)

                        ForEach(sections) { section in
                            Section {
                                let sectionIndices = section.assets.compactMap { indexMap[$0.id] }
                                let columns = waterfallColumns(indices: sectionIndices, itemWidth: colWidth)

                                HStack(alignment: .top, spacing: 10) {
                                    LazyVStack(spacing: 10) {
                                        ForEach(columns.left, id: \.self) { idx in
                                            TimelineWaterfallCell(
                                                asset: $assets[idx],
                                                itemWidth: colWidth,
                                                isVideoPlaying: playingVideoAssetID == assets[idx].id,
                                                onPhotoTap: { toggle(index: idx) },
                                                onVideoPlayToggle: {
                                                    if playingVideoAssetID == assets[idx].id {
                                                        playingVideoAssetID = nil
                                                    } else {
                                                        playingVideoAssetID = assets[idx].id
                                                    }
                                                },
                                                onVideoSelectToggle: { toggle(index: idx) },
                                                onDoubleTap: { viewerRequest = PhotoViewerRequest(startIndex: idx) }
                                            )
                                            .id(assets[idx].id)
                                        }
                                    }
                                    LazyVStack(spacing: 10) {
                                        ForEach(columns.right, id: \.self) { idx in
                                            TimelineWaterfallCell(
                                                asset: $assets[idx],
                                                itemWidth: colWidth,
                                                isVideoPlaying: playingVideoAssetID == assets[idx].id,
                                                onPhotoTap: { toggle(index: idx) },
                                                onVideoPlayToggle: {
                                                    if playingVideoAssetID == assets[idx].id {
                                                        playingVideoAssetID = nil
                                                    } else {
                                                        playingVideoAssetID = assets[idx].id
                                                    }
                                                },
                                                onVideoSelectToggle: { toggle(index: idx) },
                                                onDoubleTap: { viewerRequest = PhotoViewerRequest(startIndex: idx) }
                                            )
                                            .id(assets[idx].id)
                                        }
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                            } header: {
                                HStack(spacing: 6) {
                                    Text(section.title)
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(AppColors.textPrimary)
                                    Text(section.totalBytes.formattedFileSize)
                                        .font(.system(size: 11))
                                        .foregroundColor(AppColors.textSecondary)
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(AppColors.darkBG.opacity(0.97))
                            }
                        }
                    }
                    .padding(.bottom, selected.isEmpty ? 20 : 90)
                }
            }

            if !selected.isEmpty {
                BottomDeleteBar(
                    count: selected.count,
                    sizeLabel: selected.reduce(Int64(0)) { $0 + $1.sizeBytes }.formattedFileSize
                ) {
                    Task {
                        deleting = true
                        try? await PhotoStore.shared.deleteAssets(selected)
                        deleting = false
                    }
                }
            }
        }
        .overlay(deleting ? ProgressView("删除中…").padding(24).background(AppColors.cardBG).cornerRadius(14) : nil)
        .onAppear { syncFromViewModel() }
        .onReceive(vm.$allAssets) { _ in syncFromViewModel() }
        .onDisappear { playingVideoAssetID = nil }
        .sheet(item: $viewerRequest) { request in
            FullScreenPhotoViewer(assets: $assets, startIndex: request.startIndex)
        }
    }

    private func syncFromViewModel() {
        assets = vm.allAssets.map { asset in
            var a = asset
            // Waterfall mode defaults to unselected unless user explicitly toggled.
            a.isSelected = vm.selectionOverrides[asset.id] ?? false
            return a
        }
    }

    private func toggle(index: Int) {
        guard assets.indices.contains(index) else { return }
        assets[index].isSelected.toggle()
        vm.selectionOverrides[assets[index].id] = assets[index].isSelected
    }

    private func waterfallColumns(indices: [Int], itemWidth: CGFloat) -> (left: [Int], right: [Int]) {
        var left: [Int] = []
        var right: [Int] = []
        var leftHeight: CGFloat = 0
        var rightHeight: CGFloat = 0

        for idx in indices {
            let cardHeight = estimatedCardHeight(for: assets[idx], itemWidth: itemWidth)
            if leftHeight <= rightHeight {
                left.append(idx)
                leftHeight += cardHeight
            } else {
                right.append(idx)
                rightHeight += cardHeight
            }
        }
        return (left, right)
    }

    private func estimatedCardHeight(for asset: PhotoAsset, itemWidth: CGFloat) -> CGFloat {
        let w = CGFloat(max(1, asset.asset.pixelWidth))
        let h = CGFloat(max(1, asset.asset.pixelHeight))
        return itemWidth * (h / w) + 52
    }

    private func monthSections(from assets: [PhotoAsset]) -> [WaterfallMonthSection] {
        let cal = Calendar.current
        let grouped = Dictionary(grouping: assets) { asset in
            let c = cal.dateComponents([.year, .month], from: asset.creationDate)
            return "\(c.year ?? 0)-\(c.month ?? 0)"
        }

        return grouped.compactMap { key, groupAssets in
            guard let first = groupAssets.first else { return nil }
            let c = cal.dateComponents([.year, .month], from: first.creationDate)
            let year = c.year ?? 0
            let month = c.month ?? 0
            let sortedAssets = groupAssets.sorted { $0.creationDate > $1.creationDate }
            return WaterfallMonthSection(
                id: key,
                year: year,
                month: month,
                assets: sortedAssets
            )
        }
        .sorted { lhs, rhs in
            if lhs.year != rhs.year { return lhs.year > rhs.year }
            return lhs.month > rhs.month
        }
    }
}

private struct TimelineWaterfallCell: View {
    @Binding var asset: PhotoAsset
    let itemWidth: CGFloat
    let isVideoPlaying: Bool
    let onPhotoTap: () -> Void
    let onVideoPlayToggle: () -> Void
    let onVideoSelectToggle: () -> Void
    let onDoubleTap: () -> Void
    @State private var player: AVPlayer?
    @State private var loadingPlayer = false

    private var mediaHeight: CGFloat {
        let w = CGFloat(max(1, asset.asset.pixelWidth))
        let h = CGFloat(max(1, asset.asset.pixelHeight))
        return itemWidth * (h / w)
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                if asset.asset.mediaType == .video {
                    videoContent
                } else {
                    PhotoThumbnail(asset: asset.asset, size: itemWidth, height: mediaHeight, contentMode: .fill)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(asset.isSelected ? Color.black.opacity(0.2) : Color.clear)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                if asset.asset.mediaType == .video {
                    Text(videoDuration(asset.duration))
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(4)
                        .padding(6)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                }
            }
            .frame(width: itemWidth, height: mediaHeight)
            .contentShape(Rectangle())
            .onTapGesture(count: 2) { onDoubleTap() }
            .onTapGesture {
                if asset.asset.mediaType == .video {
                    onVideoPlayToggle()
                } else {
                    onPhotoTap()
                }
            }

            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(asset.formattedSize) · \(captureTime(asset.asset))")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(1)
                    Text(locationText(asset.asset))
                        .font(.system(size: 9))
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(1)
                }
                Spacer()
                Button(action: {
                    if asset.asset.mediaType == .video {
                        onVideoSelectToggle()
                    } else {
                        onPhotoTap()
                    }
                }) {
                    videoSelectCircle(isSelected: asset.isSelected)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(width: itemWidth)
        .onChange(of: isVideoPlaying) { playing in
            guard asset.asset.mediaType == .video else { return }
            if playing {
                Task { await ensurePlayerReadyAndPlay() }
            } else {
                player?.pause()
            }
        }
        .onDisappear {
            player?.pause()
            if !isVideoPlaying { player = nil }
        }
    }

    private func videoDuration(_ secs: TimeInterval) -> String {
        let m = Int(secs / 60), s = Int(secs) % 60
        return String(format: "%d:%02d", m, s)
    }

    private func captureTime(_ asset: PHAsset) -> String {
        guard let date = asset.creationDate else { return "未知时间" }
        let df = DateFormatter()
        df.dateFormat = "MM-dd HH:mm"
        return df.string(from: date)
    }

    private func locationText(_ asset: PHAsset) -> String {
        guard let loc = asset.location else { return "未知地点" }
        let lat = String(format: "%.2f", loc.coordinate.latitude)
        let lon = String(format: "%.2f", loc.coordinate.longitude)
        return "\(lat), \(lon)"
    }

    @ViewBuilder
    private var videoContent: some View {
        ZStack {
            if isVideoPlaying, let player {
                VideoPlayer(player: player)
                    .onAppear { player.play() }
            } else {
                PhotoThumbnail(asset: asset.asset, size: itemWidth, height: mediaHeight, contentMode: .fill)
                    .overlay(
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 36))
                            .foregroundColor(.white.opacity(0.92))
                    )
            }
            if loadingPlayer && isVideoPlaying {
                ProgressView().tint(.white)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .fill(asset.isSelected ? Color.black.opacity(0.2) : Color.clear)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private func videoSelectCircle(isSelected: Bool) -> some View {
        if isSelected {
            ZStack {
                Circle().fill(AppColors.selectionBlue).frame(width: 22, height: 22)
                Circle().stroke(Color.white, lineWidth: 2).frame(width: 22, height: 22)
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
            }
        } else {
            Circle()
                .stroke(AppColors.textSecondary, lineWidth: 2)
                .frame(width: 22, height: 22)
                .background(Circle().fill(Color.black.opacity(0.2)))
        }
    }

    private func ensurePlayerReadyAndPlay() async {
        if let player {
            player.play()
            return
        }
        loadingPlayer = true
        if let avAsset = await requestVideoAsset(for: asset.asset) {
            let item = AVPlayerItem(asset: avAsset)
            let newPlayer = AVPlayer(playerItem: item)
            await MainActor.run {
                self.player = newPlayer
                self.loadingPlayer = false
                newPlayer.play()
            }
        } else {
            await MainActor.run { self.loadingPlayer = false }
        }
    }

    private func requestVideoAsset(for asset: PHAsset) async -> AVAsset? {
        await withCheckedContinuation { cont in
            let opts = PHVideoRequestOptions()
            opts.deliveryMode = .automatic
            opts.isNetworkAccessAllowed = true
            PHImageManager.default().requestAVAsset(forVideo: asset, options: opts) { avAsset, _, _ in
                cont.resume(returning: avAsset)
            }
        }
    }
}

private struct WaterfallMonthSection: Identifiable {
    let id: String
    let year: Int
    let month: Int
    let assets: [PhotoAsset]

    var title: String { "\(year)年\(month)月" }
    var totalBytes: Int64 { assets.reduce(0) { $0 + $1.sizeBytes } }
}

private struct TimelineYearHeaderOffsetKey: PreferenceKey {
    static var defaultValue: [Int: CGFloat] = [:]

    static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

// MARK: - Calendar container (vertical scroll, Apple Calendar style)

struct CalendarContainerView: View {
    @ObservedObject var vm: LibraryViewModel
    let onDayTap: (DayInfo) -> Void
    @Binding var visibleYear: Int

    // 3 years back → 2 years ahead (60 months total).
    private static let months: [Date] = {
        let cal = Calendar.current
        let now = cal.date(from: cal.dateComponents([.year, .month], from: Date()))!
        return (-36...24).compactMap { cal.date(byAdding: .month, value: $0, to: now) }
    }()

    private static let currentMonth: Date = {
        let cal = Calendar.current
        return cal.date(from: cal.dateComponents([.year, .month], from: Date()))!
    }()
    private static let previousMonth: Date = {
        let cal = Calendar.current
        let nowMonth = cal.date(from: cal.dateComponents([.year, .month], from: Date()))!
        return cal.date(byAdding: .month, value: -1, to: nowMonth) ?? nowMonth
    }()
    @State private var didInitialScroll = false

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                let maxDaySize = vm.maxDaySize
                // Sticky weekday header
                LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                    Section {
                        // Lazy month blocks: avoids building all month grids at once
                        // when switching from list/waterfall to calendar.
                        LazyVStack(spacing: 0) {
                            ForEach(Self.months, id: \.self) { month in
                                CalendarMonthBlock(month: month, vm: vm, onDayTap: onDayTap,
                                                   visibleYear: $visibleYear,
                                                   maxDaySize: maxDaySize)
                                    .id(month)
                            }
                        }
                    } header: {
                        HStack(spacing: 0) {
                            ForEach(["日","一","二","三","四","五","六"], id: \.self) { d in
                                Text(d)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(AppColors.textTertiary)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(AppColors.darkBG)
                    }
                }
            }
            .onAppear {
                guard !didInitialScroll else { return }
                didInitialScroll = true
                // Slight delay ensures the VStack is fully laid out before scrolling
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    proxy.scrollTo(Self.previousMonth, anchor: .top)
                }
            }
        }
    }
}

// MARK: - Single month block (no nav arrows)

struct CalendarMonthBlock: View {
    let month: Date
    @ObservedObject var vm: LibraryViewModel
    let onDayTap: (DayInfo) -> Void
    @Binding var visibleYear: Int
    let maxDaySize: Int64

    private let calendar = Calendar.current
    private let cols = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)

    private var year:   Int { calendar.component(.year,  from: month) }
    private var monthN: Int { calendar.component(.month, from: month) }

    private var monthLabel: String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "zh_CN")
        df.dateFormat = "M月"
        return df.string(from: month)
    }

    private var firstWeekday: Int {
        let comps = DateComponents(year: year, month: monthN, day: 1)
        return calendar.component(.weekday, from: calendar.date(from: comps)!) - 1
    }
    private var daysInMonth: Int {
        calendar.range(of: .day, in: .month, for: month)!.count
    }
    private var isCurrentMonth: Bool {
        let c = calendar.dateComponents([.year, .month], from: Date())
        return c.year == year && c.month == monthN
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Month header
            Text(monthLabel)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(isCurrentMonth ? AppColors.purple : .white)
                .padding(.leading, 14)
                .padding(.top, 14)
                .padding(.bottom, 4)

            // Day cells grid
            LazyVGrid(columns: cols, spacing: 2) {
                ForEach(0..<(firstWeekday + daysInMonth), id: \.self) { idx in
                    if idx < firstWeekday {
                        Color.clear.frame(minHeight: 50)
                    } else {
                        let day = idx - firstWeekday + 1
                        DayCellView(
                            day: day,
                            year: year,
                            month: monthN - 1,
                            info: vm.dayInfo(year: year, month: monthN - 1, day: day),
                            isToday: isToday(day: day),
                            maxDaySize: maxDaySize,
                            onTap: onDayTap
                        )
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 8)
        }
        // Update the header year whenever this month block scrolls into view
        .onAppear { visibleYear = year }
    }

    private func isToday(day: Int) -> Bool {
        let c = calendar.dateComponents([.year, .month, .day], from: Date())
        return c.year == year && c.month == monthN && c.day == day
    }
}

// MARK: - Day cell with heatmap background

struct DayCellView: View {
    let day: Int
    let year: Int
    let month: Int   // 0-based
    let info: DayInfo?
    let isToday: Bool
    let maxDaySize: Int64
    let onTap: (DayInfo) -> Void

    private var heatIntensity: Double {
        guard let info = info, maxDaySize > 0 else { return 0 }
        return min(Double(info.totalSize) / Double(maxDaySize), 1.0)
    }

    // 5-level discrete heatmap colors
    private var heatColor: Color {
        guard info != nil else { return Color(hex: "F1F3F5") }
        switch heatIntensity {
        case 0..<0.2:   return Color(hex: "D3F9D8")
        case 0.2..<0.5: return Color(hex: "69DB7C")
        case 0.5..<0.75: return Color(hex: "FFD43B")
        default:         return Color(hex: "FF6B6B")
        }
    }

    // Light backgrounds need dark text
    private var textColor: Color { Color(hex: "1a1a2e").opacity(0.75) }
    private var subTextColor: Color { Color(hex: "1a1a2e").opacity(0.45) }

    private var dotColor: Color? {
        guard let s = info?.averageScore else { return nil }
        return s.scoreColor
    }

    var body: some View {
        VStack(spacing: 2) {
            Text("\(day)")
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 20, height: 20)
                .background(isToday ? AppColors.purple : Color.clear)
                .foregroundColor(isToday ? .white : textColor)
                .clipShape(Circle())

            if let info = info {
                Text("\(info.count)张")
                    .font(.system(size: 7)).foregroundColor(subTextColor).lineLimit(1)
                Text(info.formattedSize)
                    .font(.system(size: 7)).foregroundColor(subTextColor).lineLimit(1)
                if let c = dotColor { Circle().fill(c).frame(width: 5, height: 5) }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 52)
        .background(heatColor)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(hex: "1a1a2e").opacity(0.08), lineWidth: 0.5)
        )
        .onTapGesture {
            if let info = info { onTap(info) }
        }
    }
}

// MARK: - Album folder detail

struct AlbumFolderDetailView: View {
    let folder: AlbumFolder
    @EnvironmentObject var vm: LibraryViewModel
    @State private var assets: [PhotoAsset]
    @State private var done = false
    @State private var selectionMode = false
    @State private var viewerRequest: PhotoViewerRequest? = nil
    @State private var cellFrames: [Int: CGRect] = [:]
    @State private var dragSelectValue: Bool? = nil
    @State private var dragStartIndex: Int? = nil
    @State private var dragCurrentIndex: Int? = nil
    @State private var dragOriginalSelections: [Int: Bool] = [:]
    @Environment(\.dismiss) var dismiss
    private let service = PhotoLibraryService.shared

    init(folder: AlbumFolder, selectionOverrides: [String: Bool]) {
        self.folder = folder
        _assets = State(initialValue: folder.assets.map { asset in
            var a = asset
            a.isSelected = selectionOverrides[asset.id] ?? (asset.score < AppConfig.deleteThreshold)
            return a
        })
    }

    private var selected: [PhotoAsset] { assets.filter { $0.isSelected } }
    private let cols = [
        GridItem(.flexible(), spacing: 4),
        GridItem(.flexible(), spacing: 4),
        GridItem(.flexible(), spacing: 4)
    ]

    var body: some View {
        ZStack(alignment: .bottom) {
            if done {
                DoneView(count: selected.count, label: "张照片") { dismiss() }
            } else {
                VStack(spacing: 0) {
                    SubScreenHeader(
                        title: folder.title,
                        subtitle: "\(assets.count)张 · \(folder.formattedSize)",
                        onBack: { dismiss() },
                        trailing: AnyView(detailHeaderTrailing)
                    )

                    if selectionMode {
                        Text("低于 \(AppConfig.deleteThreshold) 分的照片已默认标记，点击可切换")
                            .font(.caption).foregroundColor(AppColors.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal).padding(.top, 8)
                    }

                    ScrollView {
                        VStack(spacing: 8) {
                            if !assets.isEmpty {
                                LargePhotoCard(
                                    asset: assets[0], isSelected: $assets[0].isSelected,
                                    selectionMode: $selectionMode,
                                    isBest: true,
                                    onToggle: { syncToggle(index: 0) },
                                    onView: { viewerRequest = PhotoViewerRequest(startIndex: 0) }
                                )
                                .padding(.horizontal)
                            }
                            if assets.count > 1 {
                                LazyVGrid(columns: cols, spacing: 4) {
                                    ForEach(1..<assets.count, id: \.self) { i in
                                        SmallPhotoCell(
                                            asset: assets[i],
                                            isSelected: $assets[i].isSelected,
                                            selectionMode: $selectionMode,
                                            onToggle: { syncToggle(index: i) },
                                            onView: { viewerRequest = PhotoViewerRequest(startIndex: i) }
                                        )
                                        .background(GeometryReader { geo in
                                            Color.clear.preference(key: GridCellFrame.self,
                                                value: [i: geo.frame(in: .named("albumGrid"))])
                                        })
                                    }
                                }
                                .coordinateSpace(name: "albumGrid")
                                .onPreferenceChange(GridCellFrame.self) { cellFrames = $0 }
                                .applyIf(selectionMode) {
                                    $0.simultaneousGesture(
                                        DragGesture(minimumDistance: 4, coordinateSpace: .named("albumGrid"))
                                            .onChanged { value in
                                                if dragSelectValue == nil {
                                                    guard let start = cellFrames.first(where: { $0.value.contains(value.startLocation) })?.key else { return }
                                                    dragStartIndex = start
                                                    dragSelectValue = !assets[start].isSelected
                                                    dragOriginalSelections = Dictionary(uniqueKeysWithValues: assets.indices.map { ($0, assets[$0].isSelected) })
                                                }
                                                guard let startIdx = dragStartIndex, let selectValue = dragSelectValue,
                                                      let currentIdx = cellFrames.first(where: { $0.value.contains(value.location) })?.key,
                                                      currentIdx != dragCurrentIndex else { return }
                                                dragCurrentIndex = currentIdx
                                                let lo = min(startIdx, currentIdx), hi = max(startIdx, currentIdx)
                                                for i in assets.indices {
                                                    let target = (i >= lo && i <= hi) ? selectValue : (dragOriginalSelections[i] ?? assets[i].isSelected)
                                                    if assets[i].isSelected != target {
                                                        assets[i].isSelected = target
                                                        vm.selectionOverrides[assets[i].id] = target
                                                    }
                                                }
                                            }
                                            .onEnded { _ in
                                                dragSelectValue = nil; dragStartIndex = nil
                                                dragCurrentIndex = nil; dragOriginalSelections = [:]
                                            }
                                    )
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding(.top, 8).padding(.bottom, 80)
                    }
                }
                .background(AppColors.darkBG)

                if !selected.isEmpty && selectionMode {
                    BottomDeleteBar(count: selected.count, sizeLabel: "") {
                        Task {
                            try? await PhotoStore.shared.deleteAssets(selected)
                            done = true
                        }
                    }
                }
            }
        }
        .sheet(item: $viewerRequest) { request in
            FullScreenPhotoViewer(assets: $assets, startIndex: request.startIndex)
        }
    }

    private var detailHeaderTrailing: some View {
        HStack(spacing: 12) {
            if selectionMode {
                Button("全选") {
                    for i in assets.indices { assets[i].isSelected = true; vm.selectionOverrides[assets[i].id] = true }
                }
                .foregroundColor(AppColors.purple).font(.subheadline)
                Button("清空") {
                    for i in assets.indices { assets[i].isSelected = false; vm.selectionOverrides[assets[i].id] = false }
                }
                .foregroundColor(AppColors.textSecondary).font(.subheadline)
            }
            Button(selectionMode ? "完成" : "选择") { selectionMode.toggle() }
                .foregroundColor(selectionMode ? AppColors.green : AppColors.purple)
                .font(.subheadline.weight(.semibold))
        }
    }

    private func syncToggle(index: Int) {
        guard assets.indices.contains(index) else { return }
        assets[index].isSelected.toggle()
        vm.selectionOverrides[assets[index].id] = assets[index].isSelected
    }
}

// MARK: - Day photo detail

struct DayPhotoDetailView: View {
    let dayInfo: DayInfo
    @EnvironmentObject var vm: LibraryViewModel
    @State private var assets: [PhotoAsset]
    @State private var done = false
    @State private var selectionMode = false
    @State private var viewerRequest: PhotoViewerRequest? = nil
    @State private var cellFrames: [Int: CGRect] = [:]
    @State private var dragSelectValue: Bool? = nil
    @State private var dragStartIndex: Int? = nil
    @State private var dragCurrentIndex: Int? = nil
    @State private var dragOriginalSelections: [Int: Bool] = [:]
    @Environment(\.dismiss) var dismiss
    private let service = PhotoLibraryService.shared
    private let cols = [
        GridItem(.flexible(), spacing: 4),
        GridItem(.flexible(), spacing: 4),
        GridItem(.flexible(), spacing: 4)
    ]

    init(dayInfo: DayInfo, selectionOverrides: [String: Bool]) {
        self.dayInfo = dayInfo
        _assets = State(initialValue: dayInfo.assets.map { asset in
            var a = asset
            a.isSelected = selectionOverrides[asset.id] ?? (asset.score < AppConfig.deleteThreshold)
            return a
        })
    }

    private var selected: [PhotoAsset] { assets.filter { $0.isSelected } }
    private var dateTitle: String {
        let months = ["1月","2月","3月","4月","5月","6月","7月","8月","9月","10月","11月","12月"]
        return "\(dayInfo.year)年\(months[dayInfo.month]) \(dayInfo.day)日"
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            if done {
                DoneView(count: selected.count, label: "张照片") { dismiss() }
            } else {
                VStack(spacing: 0) {
                    SubScreenHeader(
                        title: dateTitle,
                        subtitle: "\(dayInfo.count)张 · \(dayInfo.formattedSize) · 均分\(dayInfo.averageScore)",
                        onBack: { dismiss() },
                        trailing: AnyView(detailHeaderTrailing)
                    )

                    if selectionMode {
                        Text("低于 \(AppConfig.deleteThreshold) 分的照片已默认标记，点击可切换")
                            .font(.caption).foregroundColor(AppColors.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal).padding(.top, 8)
                    }

                    ScrollView {
                        VStack(spacing: 8) {
                            if !assets.isEmpty {
                                LargePhotoCard(
                                    asset: assets[0], isSelected: $assets[0].isSelected,
                                    selectionMode: $selectionMode,
                                    isBest: true,
                                    onToggle: { syncToggle(index: 0) },
                                    onView: { viewerRequest = PhotoViewerRequest(startIndex: 0) }
                                )
                                .padding(.horizontal)
                            }
                            if assets.count > 1 {
                                LazyVGrid(columns: cols, spacing: 4) {
                                    ForEach(1..<assets.count, id: \.self) { i in
                                        SmallPhotoCell(
                                            asset: assets[i],
                                            isSelected: $assets[i].isSelected,
                                            selectionMode: $selectionMode,
                                            onToggle: { syncToggle(index: i) },
                                            onView: { viewerRequest = PhotoViewerRequest(startIndex: i) }
                                        )
                                        .background(GeometryReader { geo in
                                            Color.clear.preference(key: GridCellFrame.self,
                                                value: [i: geo.frame(in: .named("dayGrid"))])
                                        })
                                    }
                                }
                                .coordinateSpace(name: "dayGrid")
                                .onPreferenceChange(GridCellFrame.self) { cellFrames = $0 }
                                .applyIf(selectionMode) {
                                    $0.simultaneousGesture(
                                        DragGesture(minimumDistance: 4, coordinateSpace: .named("dayGrid"))
                                            .onChanged { value in
                                                if dragSelectValue == nil {
                                                    guard let start = cellFrames.first(where: { $0.value.contains(value.startLocation) })?.key else { return }
                                                    dragStartIndex = start
                                                    dragSelectValue = !assets[start].isSelected
                                                    dragOriginalSelections = Dictionary(uniqueKeysWithValues: assets.indices.map { ($0, assets[$0].isSelected) })
                                                }
                                                guard let startIdx = dragStartIndex, let selectValue = dragSelectValue,
                                                      let currentIdx = cellFrames.first(where: { $0.value.contains(value.location) })?.key,
                                                      currentIdx != dragCurrentIndex else { return }
                                                dragCurrentIndex = currentIdx
                                                let lo = min(startIdx, currentIdx), hi = max(startIdx, currentIdx)
                                                for i in assets.indices {
                                                    let target = (i >= lo && i <= hi) ? selectValue : (dragOriginalSelections[i] ?? assets[i].isSelected)
                                                    if assets[i].isSelected != target {
                                                        assets[i].isSelected = target
                                                        vm.selectionOverrides[assets[i].id] = target
                                                    }
                                                }
                                            }
                                            .onEnded { _ in
                                                dragSelectValue = nil; dragStartIndex = nil
                                                dragCurrentIndex = nil; dragOriginalSelections = [:]
                                            }
                                    )
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding(.top, 8).padding(.bottom, 80)
                    }
                }
                .background(AppColors.darkBG)

                if !selected.isEmpty && selectionMode {
                    BottomDeleteBar(count: selected.count, sizeLabel: "") {
                        Task {
                            try? await PhotoStore.shared.deleteAssets(selected)
                            done = true
                        }
                    }
                }
            }
        }
        .sheet(item: $viewerRequest) { request in
            FullScreenPhotoViewer(assets: $assets, startIndex: request.startIndex)
        }
    }

    private var detailHeaderTrailing: some View {
        HStack(spacing: 12) {
            if selectionMode {
                Button("全选") {
                    for i in assets.indices { assets[i].isSelected = true; vm.selectionOverrides[assets[i].id] = true }
                }
                .foregroundColor(AppColors.purple).font(.subheadline)
                Button("清空") {
                    for i in assets.indices { assets[i].isSelected = false; vm.selectionOverrides[assets[i].id] = false }
                }
                .foregroundColor(AppColors.textSecondary).font(.subheadline)
            }
            Button(selectionMode ? "完成" : "选择") { selectionMode.toggle() }
                .foregroundColor(selectionMode ? AppColors.green : AppColors.purple)
                .font(.subheadline.weight(.semibold))
        }
    }

    private func syncToggle(index: Int) {
        guard assets.indices.contains(index) else { return }
        assets[index].isSelected.toggle()
        vm.selectionOverrides[assets[index].id] = assets[index].isSelected
    }
}

// MARK: - Full-screen photo viewer

struct FullScreenPhotoViewer: View {
    @Binding var assets: [PhotoAsset]
    let startIndex: Int
    @State private var currentIndex: Int
    @State private var selectionMode = false
    @Environment(\.dismiss) var dismiss

    init(assets: Binding<[PhotoAsset]>, startIndex: Int) {
        _assets = assets
        self.startIndex = startIndex
        _currentIndex = State(initialValue: startIndex)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $currentIndex) {
                ForEach(assets.indices, id: \.self) { i in
                    FullResAssetView(asset: assets[i].asset)
                        .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        // Keep media content away from top controls, like Apple's Photos layout.
        .safeAreaInset(edge: .top) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 34, height: 34)
                        .background(Color.black.opacity(0.55))
                        .clipShape(Circle())
                }

                Spacer()

                Text("\(currentIndex + 1) / \(assets.count)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .shadow(radius: 2)

                Spacer()

                Button(selectionMode ? "完成" : "选择") {
                    selectionMode.toggle()
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(selectionMode ? AppColors.green : AppColors.purple)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.55))
                .cornerRadius(8)
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)
            .padding(.bottom, 8)
            .background(Color.black.opacity(0.22))
        }
        // Bottom panel is also inset so 16:9 photos/videos won't overlap with info/actions.
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                if currentIndex < assets.count {
                    FullScreenAssetInfoBar(asset: assets[currentIndex].asset)
                }
                if selectionMode {
                    let isSelected = currentIndex < assets.count && assets[currentIndex].isSelected
                    Button {
                        toggleSelection(at: currentIndex)
                    } label: {
                        HStack(spacing: 8) {
                            SelectionStatusBadge(isSelected: isSelected, size: 22)
                            Text(isSelected ? "已标记删除 · 再次点击取消" : "标记删除")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(24)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 6)
            .padding(.bottom, 8)
            .background(Color.black.opacity(0.2))
        }
    }

    private func toggleSelection(at index: Int) {
        guard index < assets.count else { return }
        var tmp = assets
        tmp[index].isSelected.toggle()
        assets = tmp
    }
}

// MARK: - Full-resolution single asset view

struct FullResAssetView: View {
    let asset: PHAsset
    @State private var image: UIImage?
    @State private var player: AVPlayer?

    var body: some View {
        GeometryReader { geo in
            Group {
                if asset.mediaType == .video {
                    if let player = player {
                        VideoPlayer(player: player)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .onAppear { player.play() }
                    } else {
                        Color.black
                            .overlay(ProgressView().tint(.white.opacity(0.6)))
                            .frame(width: geo.size.width, height: geo.size.height)
                    }
                } else {
                    if let img = image {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                            .frame(width: geo.size.width, height: geo.size.height)
                    } else {
                        Color.black
                            .overlay(ProgressView().tint(.white.opacity(0.6)))
                            .frame(width: geo.size.width, height: geo.size.height)
                    }
                }
            }
        }
        .onAppear {
            if asset.mediaType == .video { loadVideo() } else { loadImage() }
        }
        .onDisappear {
            image = nil
            player?.pause()
            player = nil
        }
    }

    private func loadImage() {
        let opts = PHImageRequestOptions()
        opts.deliveryMode = .opportunistic   // shows fast thumbnail first, upgrades to full-res
        opts.isSynchronous = false
        opts.isNetworkAccessAllowed = true

        let scale  = UIScreen.main.scale
        let target = CGSize(width: UIScreen.main.bounds.width * scale,
                            height: UIScreen.main.bounds.height * scale)

        PHImageManager.default().requestImage(
            for: asset, targetSize: target, contentMode: .aspectFit, options: opts
        ) { img, _ in
            guard let img = img else { return }
            DispatchQueue.main.async { image = img }
        }
    }

    private func loadVideo() {
        let opts = PHVideoRequestOptions()
        opts.deliveryMode = .automatic
        opts.isNetworkAccessAllowed = true
        PHImageManager.default().requestAVAsset(forVideo: asset, options: opts) { avAsset, _, _ in
            guard let avAsset else { return }
            let item = AVPlayerItem(asset: avAsset)
            DispatchQueue.main.async {
                player = AVPlayer(playerItem: item)
            }
        }
    }
}

private struct FullScreenAssetInfoBar: View {
    let asset: PHAsset
    @State private var locationText: String = "定位中…"

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                infoText("大小 \(assetFileSizeText(asset))")
                infoText("格式 \(assetFormat(asset))")
            }
            HStack(spacing: 10) {
                infoText("时间 \(captureTimeText(asset))")
                infoText("地点 \(locationText)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.65))
        .cornerRadius(12)
        .task(id: asset.localIdentifier) { await resolveLocation() }
    }

    private func infoText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.white.opacity(0.9))
            .lineLimit(1)
    }

    private func resolveLocation() async {
        guard let loc = asset.location else {
            locationText = "无位置信息"
            return
        }
        let geocoder = CLGeocoder()
        if let marks = try? await geocoder.reverseGeocodeLocation(loc), let p = marks.first {
            let parts = [p.locality ?? p.administrativeArea, p.country].compactMap { $0 }
            locationText = parts.isEmpty ? "位置未知" : parts.joined(separator: ", ")
        } else {
            locationText = "位置未知"
        }
    }
}

private func assetFileSizeText(_ asset: PHAsset) -> String {
    for resource in PHAssetResource.assetResources(for: asset) {
        if let bytes = (resource.value(forKey: "fileSize") as? NSNumber)?.int64Value, bytes > 0 {
            return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
        }
    }
    let estimate: Int64 = asset.mediaType == .video
        ? Int64(asset.duration) * 4_000_000 / 8
        : Int64(asset.pixelWidth * asset.pixelHeight * 3) / 10
    return ByteCountFormatter.string(fromByteCount: max(estimate, 0), countStyle: .file)
}

private func assetFormat(_ asset: PHAsset) -> String {
    let uti = PHAssetResource.assetResources(for: asset).first?.uniformTypeIdentifier ?? ""
    let map: [String: String] = [
        "public.heic": "HEIC",
        "public.heif": "HEIF",
        "public.jpeg": "JPEG",
        "public.png": "PNG",
        "public.tiff": "TIFF",
        "com.apple.quicktime-movie": "MOV",
        "public.mpeg-4": "MP4",
        "public.mpeg-4-video": "MP4",
    ]
    if let v = map[uti] { return v }
    return uti.components(separatedBy: ".").last?.uppercased() ?? "未知"
}

private func captureTimeText(_ asset: PHAsset) -> String {
    guard let date = asset.creationDate else { return "未知时间" }
    let df = DateFormatter()
    df.locale = Locale(identifier: "zh_CN")
    df.dateFormat = "yyyy-MM-dd HH:mm:ss"
    return df.string(from: date)
}

// MARK: - Conditional modifier helper

private extension View {
    /// Applies `modifier` only when `condition` is true. When false, no gesture is attached
    /// so parent ScrollView can receive drags normally.
    @ViewBuilder
    func applyIf(_ condition: Bool, modifier: (Self) -> some View) -> some View {
        if condition {
            modifier(self)
        } else {
            self
        }
    }
}

// MARK: - Drag-to-select preference key

private struct GridCellFrame: PreferenceKey {
    static var defaultValue: [Int: CGRect] = [:]
    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

private struct PhotoViewerRequest: Identifiable {
    let id = UUID()
    let startIndex: Int
}

// MARK: - Int64 size formatting helper

private extension Int64 {
    var formattedFileSize: String {
        ByteCountFormatter.string(fromByteCount: self, countStyle: .file)
    }
}
