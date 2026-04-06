import SwiftUI
import Photos

// MARK: - Live Photo → Static
struct LivePhotoToolView: View {
    let onDismiss: () -> Void
    @State private var phAssets: [PHAsset] = []
    @State private var selected: Set<String> = []
    @State private var done = false
    @State private var isLoading = true
    private let service = PhotoLibraryService.shared

    private var selectedAssets: [PHAsset] { phAssets.filter { selected.contains($0.localIdentifier) } }
    private var totalSavedBytes: Int64 {
        selectedAssets.reduce(0) { $0 + Int64(Double($1.pixelWidth * $1.pixelHeight * 4) * 0.55) }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            AppColors.darkBG.ignoresSafeArea()
            if done {
                DoneView(count: selected.count, label: "个 Live Photo 已转换", onBack: onDismiss)
            } else {
                VStack(spacing: 0) {
                    SubScreenHeader(
                        title: "Live Photo → 静态",
                        subtitle: isLoading ? "加载中…" : "\(phAssets.count) 个 · 可省约 \(ByteCountFormatter.string(fromByteCount: totalSavedBytes, countStyle: .file))",
                        onBack: onDismiss
                    )
                    Text("转换为静态照片可节省约 55% 空间，动态效果将移除")
                        .font(.caption).foregroundColor(AppColors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal).padding(.top, 8)

                    if isLoading {
                        ToolLoadingView(message: "正在加载 Live Photo…")
                    } else if phAssets.isEmpty {
                        ToolEmptyView(icon: "photo.on.rectangle", message: "相册中没有 Live Photo")
                    } else {
                        List {
                            ForEach(phAssets, id: \.localIdentifier) { asset in
                                LivePhotoRow(asset: asset, isSelected: selected.contains(asset.localIdentifier)) {
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
                        sizeLabel: ByteCountFormatter.string(fromByteCount: totalSavedBytes, countStyle: .file),
                        actionLabel: "转换所选",
                        color: AppColors.purple
                    ) {
                        Task {
                            for asset in selectedAssets { try? await service.convertLivePhotoToStatic(asset) }
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
        opts.predicate = NSPredicate(format: "mediaSubtype & %d != 0", PHAssetMediaSubtype.photoLive.rawValue)
        opts.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let result = PHAsset.fetchAssets(with: .image, options: opts)
        var arr: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in arr.append(asset) }
        phAssets = arr
        selected = Set(arr.map { $0.localIdentifier })
        isLoading = false
    }
}

struct LivePhotoRow: View {
    let asset: PHAsset
    let isSelected: Bool
    let onTap: () -> Void

    private var sizeStr: String { estimatedSize(asset) }
    private var savedStr: String {
        ByteCountFormatter.string(fromByteCount: Int64(Double(asset.pixelWidth * asset.pixelHeight * 4) * 0.55), countStyle: .file)
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                PhotoThumbnail(asset: asset, size: 52).cornerRadius(10)
                Text("LIVE").font(.system(size: 7, weight: .bold)).foregroundColor(.white)
                    .padding(2).background(AppColors.purple).cornerRadius(3).padding(2)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(assetFilename(asset)).foregroundColor(.white).font(.subheadline).fontWeight(.semibold).lineLimit(1)
                Text("约 \(sizeStr) · 节省约 \(savedStr)").font(.caption).foregroundColor(AppColors.textSecondary)
            }
            Spacer()
            rowCheck(isSelected)
        }
        .padding(.vertical, 4).listRowBackground(AppColors.darkBG)
        .onTapGesture(perform: onTap)
    }
}
