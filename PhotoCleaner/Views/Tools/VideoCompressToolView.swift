import SwiftUI
import Photos

// MARK: - Video Compress
struct VideoCompressToolView: View {
    let onDismiss: () -> Void
    @State private var phAssets: [PHAsset] = []
    @State private var quality: Double = 0.7
    @State private var selected: Set<String> = []
    @State private var done = false
    @State private var isLoading = true
    private let service = PhotoLibraryService.shared

    private var selectedAssets: [PHAsset] { phAssets.filter { selected.contains($0.localIdentifier) } }
    private var savedBytes: Int64 {
        selectedAssets.reduce(0) { sum, a in
            sum + Int64(Double(a.pixelWidth * a.pixelHeight * 4) * (1 - quality) * 0.6)
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            AppColors.darkBG.ignoresSafeArea()
            if done { DoneView(count: selected.count, label: L10n.videosCompressed(selected.count), onBack: onDismiss) }
            else {
                VStack(spacing: 0) {
                    SubScreenHeader(title: L10n.videoCompress, subtitle: L10n.videoCompressDesc, onBack: onDismiss)

                    VStack(spacing: 8) {
                        Text(L10n.compressQuality).font(AppTypography.caption).foregroundColor(AppColors.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Slider(value: $quality, in: 0.3...0.95).tint(AppColors.purple)
                        HStack {
                            Text(L10n.highCompression).font(AppTypography.caption).foregroundColor(AppColors.textSecondary)
                            Spacer()
                            Text(L10n.qualityPercent(Int(quality * 100))).font(AppTypography.body.weight(.semibold)).foregroundColor(AppColors.lightPurple)
                            Spacer()
                            Text(L10n.highQuality).font(AppTypography.caption).foregroundColor(AppColors.textSecondary)
                        }
                        if savedBytes > 0 {
                            Text(L10n.estimatedSave(ByteCountFormatter.string(fromByteCount: savedBytes, countStyle: .file)))
                                .font(AppTypography.body).foregroundColor(AppColors.green)
                        }
                    }
                    .padding().appleCardStyle().padding()

                    if isLoading {
                        ToolLoadingView(message: L10n.loadingVideos)
                    } else if phAssets.isEmpty {
                        ToolEmptyView(icon: "video.slash", message: L10n.noVideos)
                    } else {
                        List {
                            ForEach(phAssets, id: \.localIdentifier) { asset in
                                VideoCompressRow(asset: asset, quality: quality, isSelected: selected.contains(asset.localIdentifier)) {
                                    if selected.contains(asset.localIdentifier) { selected.remove(asset.localIdentifier) }
                                    else { selected.insert(asset.localIdentifier) }
                                }
                            }
                        }
                        .listStyle(.plain).background(AppColors.darkBG)
                    }
                }

                if !selected.isEmpty {
                    BottomDeleteBar(
                        count: selected.count,
                        sizeLabel: ByteCountFormatter.string(fromByteCount: savedBytes, countStyle: .file),
                        actionLabel: L10n.compressSelected,
                        color: AppColors.amber
                    ) {
                        Task {
                            for asset in selectedAssets {
                                do { _ = try await service.compressVideo(asset, quality: Float(quality)) } catch {}
                            }
                            done = true
                        }
                    }
                }
            }
        }
        .task { await loadAssets() }
    }

    private func loadAssets() async {
        let opts = PHFetchOptions()
        opts.sortDescriptors = [NSSortDescriptor(key: "duration", ascending: false)]
        let result = PHAsset.fetchAssets(with: .video, options: opts)
        var arr: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in arr.append(asset) }
        phAssets = arr
        selected = Set(arr.map { $0.localIdentifier })
        isLoading = false
    }
}

struct VideoCompressRow: View {
    let asset: PHAsset
    let quality: Double
    let isSelected: Bool
    let onTap: () -> Void

    private var sizeBytes: Int64 { Int64(asset.pixelWidth * asset.pixelHeight * 4) }
    private var durationStr: String {
        let t = Int(asset.duration)
        return t >= 3600 ? String(format: "%d:%02d:%02d", t/3600, (t%3600)/60, t%60)
                         : String(format: "%d:%02d", t/60, t%60)
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                PhotoThumbnail(asset: asset, size: 52).cornerRadius(AppShape.mediaRadius)
                Text(durationStr).font(.system(size: 8, weight: .bold)).foregroundColor(.white)
                    .padding(.horizontal, 3).padding(.vertical, 1)
                    .background(Color.black.opacity(0.7)).cornerRadius(AppShape.iconRadius).padding(3)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(assetFilename(asset)).foregroundColor(AppColors.textPrimary).font(AppTypography.body.weight(.semibold)).lineLimit(1)
                Text("\(ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)) → \(ByteCountFormatter.string(fromByteCount: Int64(Double(sizeBytes) * quality * 0.8), countStyle: .file))")
                    .font(AppTypography.caption).foregroundColor(AppColors.textSecondary)
            }
            Spacer()
            rowCheck(isSelected)
        }
        .padding(.vertical, 4).listRowBackground(AppColors.darkBG)
        .onTapGesture(perform: onTap)
    }
}
