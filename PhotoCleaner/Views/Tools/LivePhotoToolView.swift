import SwiftUI
import Photos
import PhotosUI

// MARK: - Live Photo → Static
struct LivePhotoToolView: View {
    let onDismiss: () -> Void
    @State private var phAssets: [PHAsset] = []
    @State private var selected: Set<String> = []
    @State private var done = false
    @State private var doneCount = 0
    @State private var isLoading = true
    @State private var isConverting = false
    @State private var statusMessage = ""
    @State private var didInitializeThisAppearance = false
    private let service = PhotoLibraryService.shared

    private var selectedAssets: [PHAsset] { phAssets.filter { selected.contains($0.localIdentifier) } }
    private var allAssetIDs: Set<String> { Set(phAssets.map(\.localIdentifier)) }
    private var isAllSelected: Bool { !allAssetIDs.isEmpty && selected == allAssetIDs }
    private var totalSavedBytes: Int64 {
        selectedAssets.reduce(0) { $0 + livePhotoSavings($1) }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            AppColors.darkBG.ignoresSafeArea()
            if done {
                DoneView(count: doneCount, label: L10n.livePhotoDone(doneCount), onBack: onDismiss)
            } else {
                VStack(spacing: 0) {
                    SubScreenHeader(
                        title: L10n.liveToStatic,
                        subtitle: isLoading ? L10n.loading : L10n.livePhotoSubtitle(phAssets.count, ByteCountFormatter.string(fromByteCount: totalSavedBytes, countStyle: .file)),
                        onBack: onDismiss,
                        trailing: AnyView(
                            Button(isAllSelected ? L10n.deselectAll : L10n.selectAll) {
                                if isAllSelected {
                                    selected.removeAll()
                                } else {
                                    selected = allAssetIDs
                                }
                            }
                                .disabled(isLoading || isConverting || phAssets.isEmpty)
                                .foregroundColor(AppColors.lightPurple)
                                .font(AppTypography.body)
                        )
                    )
                    Text(L10n.livePhotoNote)
                        .font(AppTypography.caption).foregroundColor(AppColors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal).padding(.top, 8)
                    if !statusMessage.isEmpty {
                        Text(statusMessage)
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                            .padding(.top, 4)
                    }

                    if isLoading {
                        ToolLoadingView(message: L10n.loadingLivePhoto)
                    } else if phAssets.isEmpty {
                        ToolEmptyView(icon: "photo.on.rectangle", message: L10n.noLivePhoto)
                    } else {
                        LivePhotoWaterfallGrid(assets: phAssets, selected: $selected)
                    }
                }

                if !selected.isEmpty {
                    BottomDeleteBar(
                        count: selected.count,
                        sizeLabel: ByteCountFormatter.string(fromByteCount: totalSavedBytes, countStyle: .file),
                        fullActionText: L10n.liveToStaticAction(
                            selected.count,
                            ByteCountFormatter.string(fromByteCount: totalSavedBytes, countStyle: .file)
                        ),
                        iconName: "livephoto",
                        color: AppColors.purple
                    ) {
                        Task { @MainActor in
                            if isConverting { return }
                            let targets = selectedAssets
                            guard !targets.isEmpty else { return }
                            let targetIDs = Set(targets.map(\.localIdentifier))
                            isConverting = true
                            statusMessage = ""

                            var requestSuccessCount = 0
                            for asset in targets {
                                do {
                                    try await service.convertLivePhotoToStatic(asset)
                                    requestSuccessCount += 1
                                } catch {
                                    continue
                                }
                            }

                            await loadAssets(resetSelection: false)
                            var remainingLiveIDs = Set(phAssets.map(\.localIdentifier))
                            var actualConvertedCount = targetIDs.subtracting(remainingLiveIDs).count

                            // Photo library updates can be briefly delayed; retry once before finalizing.
                            if actualConvertedCount < requestSuccessCount {
                                try? await Task.sleep(nanoseconds: 350_000_000)
                                await loadAssets(resetSelection: false)
                                remainingLiveIDs = Set(phAssets.map(\.localIdentifier))
                                actualConvertedCount = targetIDs.subtracting(remainingLiveIDs).count
                            }

                            let actualFailedCount = max(0, targets.count - actualConvertedCount)
                            isConverting = false
                            doneCount = actualConvertedCount
                            if actualFailedCount == 0, actualConvertedCount > 0 {
                                done = true
                            } else if actualConvertedCount > 0 {
                                statusMessage = L10n.liveConvertPartial(actualConvertedCount, actualFailedCount)
                            } else {
                                statusMessage = L10n.liveConvertFailed
                            }
                        }
                    }
                }
            }
        }
        .overlay(isConverting ? ProgressView(L10n.convertingLivePhoto).padding(24).background(AppColors.cardBG).cornerRadius(8) : nil)
        .navigationBarHidden(true)
        .onAppear {
            guard !didInitializeThisAppearance else { return }
            didInitializeThisAppearance = true
            done = false
            doneCount = 0
            statusMessage = ""
            selected.removeAll()
            isLoading = true
            Task { await loadAssets(resetSelection: true) }
        }
        .onDisappear {
            didInitializeThisAppearance = false
        }
    }

    @MainActor
    private func loadAssets(resetSelection: Bool) async {
        let opts = PHFetchOptions()
        opts.predicate = NSPredicate(format: "mediaSubtype & %d != 0", PHAssetMediaSubtype.photoLive.rawValue)
        opts.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let result = PHAsset.fetchAssets(with: .image, options: opts)
        var arr: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in arr.append(asset) }
        let newIDs = Set(arr.map(\.localIdentifier))
        let oldSelection = selected
        phAssets = arr
        if resetSelection {
            selected = []
        } else {
            // Keep existing user selection across refreshes; converted items disappear automatically.
            selected = oldSelection.intersection(newIDs)
        }
        isLoading = false
    }
}

// MARK: - Savings helper
private func livePhotoSavings(_ asset: PHAsset) -> Int64 {
    Int64(Double(asset.pixelWidth * asset.pixelHeight * 4) * 0.55)
}

// MARK: - Waterfall grid
private struct LivePhotoWaterfallGrid: View {
    let assets: [PHAsset]
    @Binding var selected: Set<String>

    var body: some View {
        GeometryReader { geo in
            let colWidth = (geo.size.width - 24) / 2   // 8px edge + 8px gap + 8px edge
            let columns = distribute(assets: assets, colWidth: colWidth)
            ScrollView {
                HStack(alignment: .top, spacing: 8) {
                    ForEach(0..<2, id: \.self) { col in
                        LazyVStack(spacing: 8) {
                            ForEach(columns[col], id: \.localIdentifier) { asset in
                                LivePhotoGridCell(
                                    asset: asset,
                                    cellWidth: colWidth,
                                    cellHeight: cellHeight(asset: asset, width: colWidth),
                                    isSelected: selected.contains(asset.localIdentifier),
                                    onToggle: {
                                        if selected.contains(asset.localIdentifier) {
                                            selected.remove(asset.localIdentifier)
                                        } else {
                                            selected.insert(asset.localIdentifier)
                                        }
                                    }
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 100)
            }
        }
    }

    private func cellHeight(asset: PHAsset, width: CGFloat) -> CGFloat {
        guard asset.pixelWidth > 0 else { return width }
        let ratio = CGFloat(asset.pixelHeight) / CGFloat(asset.pixelWidth)
        return min(width * ratio, width * 1.8)
    }

    private func distribute(assets: [PHAsset], colWidth: CGFloat) -> [[PHAsset]] {
        var cols: [[PHAsset]] = [[], []]
        var heights: [CGFloat] = [0, 0]
        for asset in assets {
            let col = heights[0] <= heights[1] ? 0 : 1
            cols[col].append(asset)
            heights[col] += cellHeight(asset: asset, width: colWidth) + 8
        }
        return cols
    }
}

// MARK: - Individual grid cell
private struct LivePhotoGridCell: View {
    let asset: PHAsset
    let cellWidth: CGFloat
    let cellHeight: CGFloat
    let isSelected: Bool
    let onToggle: () -> Void

    @State private var isPlaying = false
    @State private var livePhoto: PHLivePhoto? = nil

    private var savedStr: String {
        ByteCountFormatter.string(fromByteCount: livePhotoSavings(asset), countStyle: .file)
    }
    private var sizeStr: String { estimatedSize(asset) }
    private var dateStr: String {
        guard let d = asset.creationDate else { return "" }
        let f = DateFormatter()
        f.dateFormat = "yy/MM/dd"
        return f.string(from: d)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Static thumbnail / live player
            ZStack {
                PhotoThumbnail(asset: asset, size: cellWidth, height: cellHeight)
                    .frame(width: cellWidth, height: cellHeight)
                    .clipped()
                    .opacity(isPlaying ? 0 : 1)

                // Keep player in hierarchy once loaded so startPlayback fires reliably
                if let lp = livePhoto {
                    LivePhotoPlayerView(livePhoto: lp, isPlaying: $isPlaying)
                        .frame(width: cellWidth, height: cellHeight)
                        .clipped()
                        .opacity(isPlaying ? 1 : 0)
                }
            }

            // Selection tint
            if isSelected {
                Color.black.opacity(0.22)
            }

            // Bottom overlay: info left, circle right
            HStack(alignment: .bottom, spacing: 4) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(sizeStr)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                    if !dateStr.isEmpty {
                        Text(dateStr)
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    Text(L10n.estimatedSave(savedStr))
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(AppColors.amber)
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.55))
                .cornerRadius(6)

                Spacer()

                Button(action: onToggle) {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.9), lineWidth: 1.8)
                        if isSelected {
                            Circle().fill(AppColors.selectionBlue).padding(2)
                            Image(systemName: "checkmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .frame(width: 24, height: 24)
                }
            }
            .padding(6)

            // LIVE badge — top-left, tap to play
            VStack {
                HStack {
                    Button(action: togglePlayback) {
                        Text("LIVE")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(isPlaying ? AppColors.purple : Color.black.opacity(0.55))
                            .cornerRadius(AppShape.iconRadius)
                    }
                    Spacer()
                }
                Spacer()
            }
            .padding(5)
        }
        .frame(width: cellWidth, height: cellHeight)
        .cornerRadius(10)
        .clipped()
    }

    private func togglePlayback() {
        if isPlaying {
            isPlaying = false
            return
        }
        if livePhoto != nil {
            isPlaying = true
            return
        }
        // Request high quality only — simpler than opportunistic which
        // fires twice and made it tricky to know when to start playback
        let opts = PHLivePhotoRequestOptions()
        opts.deliveryMode = .highQualityFormat
        opts.isNetworkAccessAllowed = true
        PHImageManager.default().requestLivePhoto(
            for: asset,
            targetSize: CGSize(width: cellWidth * 2, height: cellHeight * 2),
            contentMode: .aspectFill,
            options: opts
        ) { lp, _ in
            guard let lp else { return }
            DispatchQueue.main.async {
                self.livePhoto = lp
                self.isPlaying = true
            }
        }
    }
}

// MARK: - Live photo player (UIViewRepresentable)
private struct LivePhotoPlayerView: UIViewRepresentable {
    let livePhoto: PHLivePhoto
    @Binding var isPlaying: Bool

    func makeUIView(context: Context) -> PHLivePhotoView {
        let v = PHLivePhotoView()
        v.contentMode = .scaleAspectFill
        v.clipsToBounds = true
        v.delegate = context.coordinator
        return v
    }

    func updateUIView(_ uiView: PHLivePhotoView, context: Context) {
        uiView.livePhoto = livePhoto
        if isPlaying {
            // Defer by one run-loop tick so the view is fully in the window
            // hierarchy before startPlayback is called — fixes "no reaction" bug
            DispatchQueue.main.async {
                uiView.startPlayback(with: .full)
            }
        } else {
            uiView.stopPlayback()
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(isPlaying: $isPlaying) }

    class Coordinator: NSObject, PHLivePhotoViewDelegate {
        @Binding var isPlaying: Bool
        init(isPlaying: Binding<Bool>) { _isPlaying = isPlaying }

        func livePhotoView(_ livePhotoView: PHLivePhotoView,
                           didEndPlaybackWith playbackStyle: PHLivePhotoViewPlaybackStyle) {
            DispatchQueue.main.async { self.isPlaying = false }
        }
    }
}
