import SwiftUI
import Photos
import UniformTypeIdentifiers
import AVKit

// MARK: - Duplicates
struct DuplicatesView: View {
    @ObservedObject var vm: ScanViewModel
    @State private var groups: [PhotoGroup]
    @State private var done = false
    @State private var deleting = false
    @State private var mergingGroupIDs: Set<UUID> = []
    @State private var viewerRequest: DuplicateViewerRequest? = nil
    @Environment(\.dismiss) var dismiss

    var deletableCount: Int { groups.reduce(0) { $0 + $1.assets.dropFirst().count } }
    var deletableSize: Int64 { groups.flatMap { $0.assets.dropFirst() }.reduce(0) { $0 + $1.sizeBytes } }

    init(groups: [PhotoGroup], vm: ScanViewModel) {
        self.vm = vm
        _groups = State(initialValue: groups)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            if done {
                DoneView(count: deletableCount, label: "张重复照片") { dismiss() }
            } else {
                VStack(spacing: 0) {
                    SubScreenHeader(title: "重复与相似",
                                    subtitle: "\(groups.count) 组",
                                    onBack: { dismiss() })

                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(groups) { group in
                                DuplicateGroupCard(
                                    group: group,
                                    isMerging: mergingGroupIDs.contains(group.id),
                                    onMerge: { merge(group) },
                                    onPhotoTap: { photoIndex in
                                        viewerRequest = DuplicateViewerRequest(groupID: group.id, startIndex: photoIndex)
                                    },
                                    onPromoteBest: { assetID in
                                        promoteAsset(assetID, in: group.id)
                                    }
                                )
                            }
                        }
                        .padding()
                        .padding(.bottom, 80)
                    }
                }
                .background(AppColors.darkBG)

                if deletableCount > 0 {
                    BottomDeleteBar(
                        count: deletableCount,
                        sizeLabel: ByteCountFormatter.string(fromByteCount: deletableSize, countStyle: .file)
                    ) {
                        Task {
                            deleting = true
                            try? await vm.deleteGroups(groups)
                            deleting = false
                            done = true
                        }
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .overlay((deleting || !mergingGroupIDs.isEmpty) ? ProgressView("处理中…").padding(24).background(AppColors.cardBG).cornerRadius(8) : nil)
        .sheet(item: $viewerRequest) { request in
            if let binding = bindingForGroupAssets(groupID: request.groupID) {
                FullScreenPhotoViewer(assets: binding, startIndex: request.startIndex)
            }
        }
    }

    private func merge(_ group: PhotoGroup) {
        guard !mergingGroupIDs.contains(group.id), group.assets.count > 1 else { return }
        mergingGroupIDs.insert(group.id)
        Task {
            try? await vm.deleteGroups([group])
            await MainActor.run {
                groups.removeAll { $0.id == group.id }
                mergingGroupIDs.remove(group.id)
                if groups.isEmpty { done = true }
            }
        }
    }

    private func promoteAsset(_ assetID: String, in groupID: UUID) {
        guard let gIdx = groups.firstIndex(where: { $0.id == groupID }) else { return }
        guard let aIdx = groups[gIdx].assets.firstIndex(where: { $0.id == assetID }) else { return }
        guard aIdx > 0 else { return }
        let picked = groups[gIdx].assets.remove(at: aIdx)
        groups[gIdx].assets.insert(picked, at: 0)
    }

    private func bindingForGroupAssets(groupID: UUID) -> Binding<[PhotoAsset]>? {
        guard let gIdx = groups.firstIndex(where: { $0.id == groupID }) else { return nil }
        return Binding<[PhotoAsset]>(
            get: { groups[gIdx].assets },
            set: { groups[gIdx].assets = $0 }
        )
    }
}

struct DuplicateGroupCard: View {
    let group: PhotoGroup
    let isMerging: Bool
    let onMerge: () -> Void
    let onPhotoTap: (Int) -> Void
    let onPromoteBest: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(group.groupType == .duplicate ? "🔁 重复" : "✨ 相似")
                    .font(.caption).fontWeight(.semibold)
                    .foregroundColor(AppColors.textSecondary)
                    .textCase(.uppercase)
                Spacer()
                Button(action: onMerge) {
                    if isMerging {
                        ProgressView().tint(AppColors.purple)
                    } else {
                        Text("合并")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(AppColors.lightPurple)
                    }
                }
                .disabled(isMerging)
                .frame(width: 52, height: 26)
                .background(AppColors.purple.opacity(0.15))
                .cornerRadius(8)
            }

            // Best large, others small
            HStack(alignment: .top, spacing: 4) {
                // Best photo – 2x height
                ZStack(alignment: .topLeading) {
                    PhotoThumbnail(asset: group.assets[0].asset, size: 160)
                        .frame(width: 160, height: 160)
                        .clipped()
                        .cornerRadius(10)
                        .onTapGesture { onPhotoTap(0) }
                        .onDrop(of: [UTType.text], delegate: BestDropDelegate { droppedID in
                            onPromoteBest(droppedID)
                        })
                    Text("⭐ 最佳")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Color(hex: "7c2d00"))
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(AppColors.amber).cornerRadius(5).padding(5)
                    VStack(alignment: .trailing, spacing: 2) {
                        ScoreBadge(score: group.assets[0].score, fontSize: 9)
                        Text(group.assets[0].formattedSize)
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundColor(.white.opacity(0.85))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.55))
                            .cornerRadius(4)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(4)
                }

                // Others in 2-col grid
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 4), GridItem(.flexible(), spacing: 4)], spacing: 4) {
                    ForEach(Array(group.assets.dropFirst().enumerated()), id: \.element.id) { offset, asset in
                        ZStack(alignment: .topTrailing) {
                            PhotoThumbnail(asset: asset.asset, size: 76)
                                .frame(maxWidth: .infinity).aspectRatio(1, contentMode: .fill).clipped()
                                .cornerRadius(8).opacity(0.55)
                                .onTapGesture { onPhotoTap(offset + 1) }
                                .onDrag {
                                    NSItemProvider(object: asset.id as NSString)
                                }
                            Circle().fill(AppColors.purple).frame(width: 14, height: 14)
                                .overlay(Image(systemName: "checkmark").font(.system(size: 7)).foregroundColor(.white))
                                .padding(3)
                            VStack(alignment: .trailing, spacing: 2) {
                                ScoreBadge(score: asset.score, fontSize: 8)
                                Text(asset.formattedSize)
                                    .font(.system(size: 7, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.85))
                                    .padding(.horizontal, 3)
                                    .padding(.vertical, 1)
                                    .background(Color.black.opacity(0.55))
                                    .cornerRadius(3)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                            .padding(3)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(12)
        .appleCardStyle()
    }
}

private struct DuplicateViewerRequest: Identifiable {
    let id = UUID()
    let groupID: UUID
    let startIndex: Int
}

private struct BestDropDelegate: DropDelegate {
    let onDropID: (String) -> Void

    func performDrop(info: DropInfo) -> Bool {
        guard let provider = info.itemProviders(for: [UTType.text]).first else { return false }
        provider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { item, _ in
            if let data = item as? Data, let id = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async { onDropID(id) }
            } else if let text = item as? String {
                DispatchQueue.main.async { onDropID(text) }
            } else if let ns = item as? NSString {
                DispatchQueue.main.async { onDropID(ns as String) }
            }
        }
        return true
    }
}

// MARK: - Screenshots
struct ScreenshotCleanView: View {
    @State var assets: [PhotoAsset]
    @ObservedObject var vm: ScanViewModel
    @State private var filterCategory: ScreenshotCategory? = nil
    @State private var categoryMap: [String: ScreenshotCategory] = [:]
    @State private var classifying = false
    @State private var classifyProgress: Double = 0
    @State private var viewerRequest: ScreenshotViewerRequest? = nil
    @State private var gridColumnCount: Int = AppConfig.screenshotGridColumns
    @State private var done = false
    @State private var deleting = false
    @Environment(\.dismiss) var dismiss

    private var cols: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 3), count: gridColumnCount)
    }
    private var selected: [PhotoAsset] { assets.filter { $0.isSelected } }
    private var filteredIndices: [Int] {
        assets.indices.filter { idx in
            guard let c = filterCategory else { return true }
            return categoryMap[assets[idx].id] == c
        }
    }
    private var isAllSelected: Bool {
        !assets.isEmpty && assets.allSatisfy { $0.isSelected }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            if done {
                DoneView(count: selected.count, label: "张截图") { dismiss() }
            } else {
                VStack(spacing: 0) {
                    SubScreenHeader(
                        title: "截图清理",
                        subtitle: "\(assets.count)张 · 推荐删 \(assets.filter{$0.score < 45}.count)张",
                        onBack: { dismiss() },
                        trailing: AnyView(
                            Button(isAllSelected ? "取消全选" : "全选") {
                                let next = !isAllSelected
                                for i in assets.indices { assets[i].isSelected = next }
                            }
                            .foregroundColor(AppColors.lightPurple).font(AppTypography.body)
                        )
                    )

                    InfoBanner(text: "已自动选中低质量截图，可手动调整", color: AppColors.red)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            FilterChip(label: "全部", isActive: filterCategory == nil) { filterCategory = nil }
                            ForEach(ScreenshotCategory.allCases, id: \.self) { c in
                                FilterChip(label: c.chipLabel, isActive: filterCategory == c) { filterCategory = c }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                    }

                    if classifying {
                        HStack(spacing: 8) {
                            ProgressView(value: classifyProgress).tint(AppColors.purple)
                            Text("分类中 \(Int(classifyProgress * 100))%")
                                .font(.caption)
                                .foregroundColor(AppColors.textSecondary)
                        }
                        .padding(.horizontal)
                        .padding(.top, 4)
                    }

                    ScrollView {
                        LazyVGrid(columns: cols, spacing: 3) {
                            ForEach(filteredIndices, id: \.self) { idx in
                                ScreenshotGridCell(
                                    asset: $assets[idx],
                                    category: categoryMap[assets[idx].id],
                                    onSingleTap: { assets[idx].isSelected.toggle() },
                                    onDoubleTap: { viewerRequest = ScreenshotViewerRequest(startIndex: idx) }
                                )
                                .id(assets[idx].id)
                            }
                        }
                        .padding(3)
                        .padding(.bottom, 80)
                    }
                    .simultaneousGesture(gridPinchGesture)
                    .animation(.easeInOut(duration: 0.18), value: gridColumnCount)
                }
                .background(AppColors.darkBG)

                if !selected.isEmpty {
                    BottomDeleteBar(
                        count: selected.count,
                        sizeLabel: ByteCountFormatter.string(fromByteCount: selected.reduce(0){$0+$1.sizeBytes}, countStyle: .file)
                    ) {
                        Task {
                            deleting = true
                            try? await vm.deleteSelected(from: assets)
                            deleting = false
                            done = true
                        }
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .task { await classifyScreenshots() }
        .sheet(item: $viewerRequest) { request in
            FullScreenPhotoViewer(assets: $assets, startIndex: request.startIndex)
        }
    }

    private var gridPinchGesture: some Gesture {
        MagnificationGesture(minimumScaleDelta: 0.08)
            .onEnded { value in
                // Apple-like direction:
                // spread fingers (>1) => larger thumbnails => fewer columns
                // pinch inward (<1)   => smaller thumbnails => more columns
                if value > 1.06 {
                    setGridColumns(2)
                } else if value < 0.94 {
                    setGridColumns(3)
                }
            }
    }

    private func setGridColumns(_ newValue: Int) {
        let clamped = min(3, max(2, newValue))
        guard clamped != gridColumnCount else { return }
        gridColumnCount = clamped
        AppConfig.screenshotGridColumns = clamped
    }

    private func classifyScreenshots() async {
        guard categoryMap.isEmpty, !assets.isEmpty else { return }
        assets.sort { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score < rhs.score }
            return lhs.creationDate > rhs.creationDate
        }
        classifying = true
        classifyProgress = 0
        let total = max(assets.count, 1)

        for (idx, item) in assets.enumerated() {
            let c = await PhotoLibraryService.shared.classifyScreenshot(item.asset)
            categoryMap[item.id] = c
            classifyProgress = Double(idx + 1) / Double(total)
        }
        classifying = false
    }
}

// MARK: - Videos
struct VideoCleanView: View {
    @State var assets: [PhotoAsset]
    @ObservedObject var vm: ScanViewModel
    @State private var done = false
    @State private var deleting = false
    @State private var playingAssetID: String? = nil
    @Environment(\.dismiss) var dismiss

    private var selected: [PhotoAsset] { assets.filter { $0.isSelected } }
    private var isAllSelected: Bool { !assets.isEmpty && assets.allSatisfy { $0.isSelected } }

    var body: some View {
        ZStack(alignment: .bottom) {
            if done {
                DoneView(count: selected.count, label: "个视频") { dismiss() }
            } else {
                VStack(spacing: 0) {
                    SubScreenHeader(
                        title: "大视频文件",
                        subtitle: "\(assets.count)个视频，按大小排序",
                        onBack: { dismiss() },
                        trailing: AnyView(
                            Button(isAllSelected ? "取消全选" : "全选") {
                                let next = !isAllSelected
                                for i in assets.indices { assets[i].isSelected = next }
                            }
                            .foregroundColor(AppColors.lightPurple)
                            .font(AppTypography.body)
                        )
                    )
                    InfoBanner(text: "两列浏览；点视频原位小窗播放；点下方圆圈标记后可批量删除", color: AppColors.amber)

                    GeometryReader { geo in
                        let colWidth = max(120, (geo.size.width - 34) / 2)
                        let columns = waterfallColumns(itemWidth: colWidth)

                        ScrollView {
                            HStack(alignment: .top, spacing: 10) {
                                LazyVStack(spacing: 12) {
                                    ForEach(columns.left, id: \.self) { idx in
                                        VideoGridCell(
                                            asset: $assets[idx],
                                            itemWidth: colWidth,
                                            isPlaying: playingAssetID == assets[idx].id,
                                            onPlayToggle: {
                                                if playingAssetID == assets[idx].id {
                                                    playingAssetID = nil
                                                } else {
                                                    playingAssetID = assets[idx].id
                                                }
                                            },
                                            onToggleSelect: { assets[idx].isSelected.toggle() }
                                        )
                                        .id(assets[idx].id)
                                        .frame(width: colWidth)
                                    }
                                }
                                LazyVStack(spacing: 12) {
                                    ForEach(columns.right, id: \.self) { idx in
                                        VideoGridCell(
                                            asset: $assets[idx],
                                            itemWidth: colWidth,
                                            isPlaying: playingAssetID == assets[idx].id,
                                            onPlayToggle: {
                                                if playingAssetID == assets[idx].id {
                                                    playingAssetID = nil
                                                } else {
                                                    playingAssetID = assets[idx].id
                                                }
                                            },
                                            onToggleSelect: { assets[idx].isSelected.toggle() }
                                        )
                                        .id(assets[idx].id)
                                        .frame(width: colWidth)
                                    }
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.top, 10)
                            .padding(.bottom, selected.isEmpty ? 20 : 90)
                        }
                    }
                }
                .background(AppColors.darkBG)

                if !selected.isEmpty {
                    BottomDeleteBar(
                        count: selected.count,
                        sizeLabel: ByteCountFormatter.string(fromByteCount: selected.reduce(0){$0+$1.sizeBytes}, countStyle: .file)
                    ) {
                        Task {
                            deleting = true
                            try? await vm.deleteSelected(from: assets)
                            deleting = false
                            done = true
                        }
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            assets.sort { $0.sizeBytes > $1.sizeBytes }
        }
        .onDisappear { playingAssetID = nil }
    }

    private func waterfallColumns(itemWidth: CGFloat) -> (left: [Int], right: [Int]) {
        var left: [Int] = []
        var right: [Int] = []
        var leftHeight: CGFloat = 0
        var rightHeight: CGFloat = 0

        for idx in assets.indices {
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
        let mediaHeight = itemWidth * (h / w)
        return mediaHeight + 54 // bottom meta row + spacing
    }
}

struct VideoGridCell: View {
    @Binding var asset: PhotoAsset
    let itemWidth: CGFloat
    let isPlaying: Bool
    let onPlayToggle: () -> Void
    let onToggleSelect: () -> Void
    @State private var player: AVPlayer?
    @State private var loadingPlayer = false
    private var videoAspectRatio: CGFloat {
        let w = CGFloat(max(1, asset.asset.pixelWidth))
        let h = CGFloat(max(1, asset.asset.pixelHeight))
        return w / h
    }
    private var videoDisplayHeight: CGFloat {
        itemWidth / max(videoAspectRatio, 0.1)
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if isPlaying, let player {
                        VideoPlayer(player: player)
                            .onAppear { player.play() }
                    } else {
                        PhotoThumbnail(
                            asset: asset.asset,
                            size: itemWidth,
                            height: videoDisplayHeight,
                            contentMode: .fill
                        )
                            .overlay(
                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 38))
                                    .foregroundColor(.white.opacity(0.92))
                            )
                    }
                }
                .frame(width: itemWidth, height: videoDisplayHeight)
                .background(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppColors.subtleBorder, lineWidth: 1)
                )
                .onTapGesture { onPlayToggle() }

                if loadingPlayer && isPlaying {
                    ProgressView().tint(.white).padding(6)
                }

                Text(formattedDuration(asset.duration))
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(4)
                    .padding(6)
            }

            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(asset.asset.creationDate?.formatted(date: .abbreviated, time: .omitted) ?? "未知日期")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(1)
                    Text(asset.formattedSize)
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
                Spacer()
                Button(action: onToggleSelect) {
                    videoSelectCircle(isSelected: asset.isSelected)
                }
                .buttonStyle(.plain)
            }
        }
        .onChange(of: isPlaying) { newValue in
            if newValue {
                Task { await ensurePlayerReadyAndPlay() }
            } else {
                player?.pause()
            }
        }
        .onDisappear {
            player?.pause()
            if !isPlaying { player = nil }
        }
    }

    @ViewBuilder
    private func videoSelectCircle(isSelected: Bool) -> some View {
        if isSelected {
            ZStack {
                Circle()
                    .fill(AppColors.selectionBlue)
                    .frame(width: 28, height: 28)
                Circle()
                    .stroke(Color.white, lineWidth: 2)
                    .frame(width: 28, height: 28)
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
            }
        } else {
            Circle()
                .stroke(AppColors.textSecondary, lineWidth: 2)
                .frame(width: 28, height: 28)
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

    private func formattedDuration(_ secs: TimeInterval) -> String {
        let m = Int(secs / 60), s = Int(secs) % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Low Quality
struct LowQualityCleanView: View {
    @State var assets: [PhotoAsset]
    @ObservedObject var vm: ScanViewModel
    @State private var filterReason: LowQualityReason? = nil
    @State private var viewerRequest: LowQualityViewerRequest? = nil
    @State private var gridColumnCount: Int = AppConfig.lowQualityGridColumns
    @State private var done = false
    @State private var deleting = false
    @Environment(\.dismiss) var dismiss

    private var cols: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 3), count: gridColumnCount)
    }
    private var filteredIndices: [Int] {
        assets.indices.filter { idx in
            guard let r = filterReason else { return true }
            return assets[idx].reason == r
        }
    }
    private var selected: [PhotoAsset] { assets.filter { $0.isSelected } }
    private var isAllSelected: Bool {
        !assets.isEmpty && assets.allSatisfy { $0.isSelected }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            if done {
                DoneView(count: selected.count, label: "张低质量照片") { dismiss() }
            } else {
                VStack(spacing: 0) {
                    SubScreenHeader(
                        title: "低质量照片",
                        subtitle: "共\(assets.count)张 · 已全选推荐",
                        onBack: { dismiss() },
                        trailing: AnyView(
                            Button(isAllSelected ? "取消全选" : "全选") {
                                let next = !isAllSelected
                                for i in assets.indices { assets[i].isSelected = next }
                            }
                            .foregroundColor(AppColors.lightPurple)
                            .font(AppTypography.body)
                        )
                    )

                    // Filter chips
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            FilterChip(label: "全部", isActive: filterReason == nil) { filterReason = nil }
                            ForEach(LowQualityReason.allCases, id: \.self) { r in
                                FilterChip(label: r.rawValue, isActive: filterReason == r) { filterReason = r }
                            }
                        }
                        .padding(.horizontal).padding(.vertical, 8)
                    }

                    ScrollView {
                        LazyVGrid(columns: cols, spacing: 3) {
                            ForEach(filteredIndices, id: \.self) { idx in
                                LowQualityGridCell(
                                    asset: $assets[idx],
                                    onSingleTap: { assets[idx].isSelected.toggle() },
                                    onDoubleTap: { viewerRequest = LowQualityViewerRequest(startIndex: idx) }
                                )
                                    .id(assets[idx].id)
                            }
                        }
                        .padding(3).padding(.bottom, 80)
                    }
                    .simultaneousGesture(gridPinchGesture)
                    .animation(.easeInOut(duration: 0.18), value: gridColumnCount)
                }
                .background(AppColors.darkBG)

                if !selected.isEmpty {
                    BottomDeleteBar(count: selected.count, sizeLabel: "") {
                        Task {
                            deleting = true
                            try? await vm.deleteSelected(from: assets)
                            deleting = false
                            done = true
                        }
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(item: $viewerRequest) { request in
            FullScreenPhotoViewer(assets: $assets, startIndex: request.startIndex)
        }
    }

    private var gridPinchGesture: some Gesture {
        MagnificationGesture(minimumScaleDelta: 0.08)
            .onEnded { value in
                if value > 1.06 {
                    setGridColumns(2)
                } else if value < 0.94 {
                    setGridColumns(3)
                }
            }
    }

    private func setGridColumns(_ newValue: Int) {
        let clamped = min(3, max(2, newValue))
        guard clamped != gridColumnCount else { return }
        gridColumnCount = clamped
        AppConfig.lowQualityGridColumns = clamped
    }
}

private struct LowQualityGridCell: View {
    @Binding var asset: PhotoAsset
    let onSingleTap: () -> Void
    let onDoubleTap: () -> Void

    var body: some View {
        ZStack {
            PhotoThumbnail(asset: asset.asset, size: 120)
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fill)
                .clipped()
                .cornerRadius(10)

            VStack {
                HStack {
                    ScoreBadge(score: asset.score)
                    Spacer()
                    cornerMetaText(asset.formattedSize, fontSize: 8)
                }
                Spacer()
                HStack {
                    cornerMetaText(asset.reason?.rawValue ?? mediaTypeTag(asset.asset), fontSize: 8)
                    Spacer()
                    SelectionStatusBadge(isSelected: asset.isSelected, size: 20)
                }
            }
            .padding(4)

            if asset.isSelected {
                RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.22))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { onDoubleTap() }
        .onTapGesture { onSingleTap() }
    }
}

private struct LowQualityViewerRequest: Identifiable {
    let id = UUID()
    let startIndex: Int
}

// MARK: - Favorites
struct FavoritesCleanView: View {
    @State var assets: [PhotoAsset]
    @ObservedObject var vm: ScanViewModel
    @State private var viewerRequest: FavoritesViewerRequest? = nil
    @State private var done = false
    @State private var deleting = false
    @Environment(\.dismiss) var dismiss

    private var selected: [PhotoAsset] { assets.filter { $0.isSelected } }
    private var isAllSelected: Bool {
        !assets.isEmpty && assets.allSatisfy { $0.isSelected }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            if done {
                DoneView(count: selected.count, label: "张收藏照片") { dismiss() }
            } else {
                VStack(spacing: 0) {
                    SubScreenHeader(
                        title: "收藏照片",
                        subtitle: "\(assets.count)张 · 默认不勾选",
                        onBack: { dismiss() },
                        trailing: AnyView(
                            Button(isAllSelected ? "取消全选" : "全选") {
                                let next = !isAllSelected
                                for i in assets.indices { assets[i].isSelected = next }
                            }
                            .foregroundColor(AppColors.lightPurple)
                            .font(AppTypography.body)
                        )
                    )
                    InfoBanner(text: "收藏照片默认不选，避免误删重要内容", color: AppColors.red)

                    ScrollView {
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 3), GridItem(.flexible(), spacing: 3), GridItem(.flexible(), spacing: 3)], spacing: 3) {
                            ForEach(assets.indices, id: \.self) { idx in
                                LowQualityGridCell(
                                    asset: $assets[idx],
                                    onSingleTap: { assets[idx].isSelected.toggle() },
                                    onDoubleTap: { viewerRequest = FavoritesViewerRequest(startIndex: idx) }
                                )
                                .id(assets[idx].id)
                            }
                        }
                        .padding(3)
                        .padding(.bottom, 80)
                    }
                }
                .background(AppColors.darkBG)

                if !selected.isEmpty {
                    BottomDeleteBar(
                        count: selected.count,
                        sizeLabel: ByteCountFormatter.string(fromByteCount: selected.reduce(0){$0+$1.sizeBytes}, countStyle: .file)
                    ) {
                        Task {
                            deleting = true
                            try? await vm.deleteSelected(from: assets)
                            deleting = false
                            done = true
                        }
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .overlay(deleting ? ProgressView("处理中…").padding(24).background(AppColors.cardBG).cornerRadius(8) : nil)
        .sheet(item: $viewerRequest) { request in
            FullScreenPhotoViewer(assets: $assets, startIndex: request.startIndex)
        }
    }
}

private struct FavoritesViewerRequest: Identifiable {
    let id = UUID()
    let startIndex: Int
}

// MARK: - Behavior-based cleanup
private enum BehaviorFilter: String, CaseIterable {
    case neverViewed = "从未查看"
    case longUnused = "很久没看"
    case olderThan3Years = "超过3年"
    case olderThan5Years = "超过5年"
}

struct BehaviorCleanView: View {
    @State var assets: [PhotoAsset]
    @ObservedObject var vm: ScanViewModel
    @State private var filter: BehaviorFilter = .longUnused
    @State private var viewerRequest: BehaviorViewerRequest? = nil
    @State private var done = false
    @State private var deleting = false
    @Environment(\.dismiss) var dismiss

    private var selected: [PhotoAsset] { assets.filter { $0.isSelected } }
    private var filteredIndices: [Int] {
        assets.indices.filter { idx in
            let years = yearsSinceCreation(assets[idx])
            switch filter {
            case .neverViewed:
                // iOS public API does not expose per-asset view history.
                return false
            case .longUnused:
                return years >= 1
            case .olderThan3Years:
                return years >= 3
            case .olderThan5Years:
                return years >= 5
            }
        }
    }
    private var isAllSelected: Bool {
        !assets.isEmpty && assets.allSatisfy { $0.isSelected }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            if done {
                DoneView(count: selected.count, label: "张照片") { dismiss() }
            } else {
                VStack(spacing: 0) {
                    SubScreenHeader(
                        title: "其他使用行为",
                        subtitle: "\(assets.count)张 · 已排除收藏",
                        onBack: { dismiss() },
                        trailing: AnyView(
                            Button(isAllSelected ? "取消全选" : "全选") {
                                let next = !isAllSelected
                                for i in assets.indices { assets[i].isSelected = next }
                            }
                            .foregroundColor(AppColors.lightPurple)
                            .font(AppTypography.body)
                        )
                    )
                    InfoBanner(text: filter == .neverViewed ? "iOS 暂不提供“从未查看”公开数据，本筛选暂不可用" : "按使用行为与时间筛选，可手动调整删除对象", color: AppColors.amber)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(BehaviorFilter.allCases, id: \.self) { f in
                                FilterChip(label: f.rawValue, isActive: filter == f) { filter = f }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }

                    ScrollView {
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 3), GridItem(.flexible(), spacing: 3), GridItem(.flexible(), spacing: 3)], spacing: 3) {
                            ForEach(filteredIndices, id: \.self) { idx in
                                LowQualityGridCell(
                                    asset: $assets[idx],
                                    onSingleTap: { assets[idx].isSelected.toggle() },
                                    onDoubleTap: { viewerRequest = BehaviorViewerRequest(startIndex: idx) }
                                )
                                .id(assets[idx].id)
                            }
                        }
                        .padding(3)
                        .padding(.bottom, 80)
                    }
                }
                .background(AppColors.darkBG)

                if !selected.isEmpty {
                    BottomDeleteBar(
                        count: selected.count,
                        sizeLabel: ByteCountFormatter.string(fromByteCount: selected.reduce(0){$0+$1.sizeBytes}, countStyle: .file)
                    ) {
                        Task {
                            deleting = true
                            try? await vm.deleteSelected(from: assets)
                            deleting = false
                            done = true
                        }
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .overlay(deleting ? ProgressView("处理中…").padding(24).background(AppColors.cardBG).cornerRadius(8) : nil)
        .sheet(item: $viewerRequest) { request in
            FullScreenPhotoViewer(assets: $assets, startIndex: request.startIndex)
        }
    }

    private func yearsSinceCreation(_ asset: PhotoAsset) -> Int {
        Calendar.current.dateComponents([.year], from: asset.creationDate, to: Date()).year ?? 0
    }
}

private struct BehaviorViewerRequest: Identifiable {
    let id = UUID()
    let startIndex: Int
}

// MARK: - Helpers
struct InfoBanner: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundColor(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.infoBannerBG)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(color.opacity(0.35), lineWidth: 0.8)
            )
            .cornerRadius(8)
            .padding(.horizontal).padding(.top, 6)
    }
}

struct FilterChip: View {
    let label: String
    let isActive: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(AppTypography.micro.weight(.semibold))
                .padding(.horizontal, 14).padding(.vertical, 6)
                .background(isActive ? AppColors.purple : AppColors.chipBG)
                .foregroundColor(isActive ? .white : AppColors.textSecondary)
                .cornerRadius(20)
        }
    }
}

private struct ScreenshotGridCell: View {
    @Binding var asset: PhotoAsset
    let category: ScreenshotCategory?
    let onSingleTap: () -> Void
    let onDoubleTap: () -> Void

    var body: some View {
        ZStack {
            PhotoThumbnail(asset: asset.asset, size: 120)
                .frame(maxWidth: .infinity)
                .aspectRatio(9/16, contentMode: .fill)
                .clipped()
                .cornerRadius(10)

            VStack {
                HStack {
                    ScoreBadge(score: asset.score)
                    Spacer()
                    cornerMetaText(asset.formattedSize, fontSize: 8)
                }
                Spacer()
                HStack {
                    cornerMetaText(category?.rawValue ?? mediaTypeTag(asset.asset), fontSize: 8)
                    Spacer()
                    SelectionStatusBadge(isSelected: asset.isSelected, size: 20)
                }
            }
            .padding(4)

            if asset.isSelected {
                RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.22))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { onDoubleTap() }
        .onTapGesture { onSingleTap() }
    }
}

private struct ScreenshotViewerRequest: Identifiable {
    let id = UUID()
    let startIndex: Int
}
