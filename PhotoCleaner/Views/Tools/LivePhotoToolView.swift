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
                DoneView(count: selected.count, label: L10n.livePhotoDone(selected.count), onBack: onDismiss)
            } else {
                VStack(spacing: 0) {
                    SubScreenHeader(
                        title: L10n.liveToStatic,
                        subtitle: isLoading ? L10n.loading : L10n.livePhotoSubtitle(phAssets.count, ByteCountFormatter.string(fromByteCount: totalSavedBytes, countStyle: .file)),
                        onBack: onDismiss
                    )
                    Text(L10n.livePhotoNote)
                        .font(AppTypography.caption).foregroundColor(AppColors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal).padding(.top, 8)

                    if isLoading {
                        ToolLoadingView(message: L10n.loadingLivePhoto)
                    } else if phAssets.isEmpty {
                        ToolEmptyView(icon: "photo.on.rectangle", message: L10n.noLivePhoto)
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
                        actionLabel: L10n.convertSelected,
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
                PhotoThumbnail(asset: asset, size: 52).cornerRadius(AppShape.mediaRadius)
                Text("LIVE").font(.system(size: 7, weight: .bold)).foregroundColor(.white)
                    .padding(2).background(AppColors.purple).cornerRadius(AppShape.iconRadius).padding(2)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(assetFilename(asset)).foregroundColor(AppColors.textPrimary).font(AppTypography.body.weight(.semibold)).lineLimit(1)
                Text(L10n.approxSave(sizeStr, savedStr)).font(AppTypography.caption).foregroundColor(AppColors.textSecondary)
            }
            Spacer()
            rowCheck(isSelected)
        }
        .padding(.vertical, 4).listRowBackground(AppColors.darkBG)
        .onTapGesture(perform: onTap)
    }
}
