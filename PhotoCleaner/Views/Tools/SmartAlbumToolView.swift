import SwiftUI
import Photos

// MARK: - Smart Album (using real iOS smart albums)
struct SmartAlbumToolView: View {
    let onDismiss: () -> Void

    struct RealAlbum: Identifiable {
        let id: Int
        let emoji: String
        let name: String
        let color: Color
        let subtype: PHAssetCollectionSubtype
        var count: Int = 0
        var totalSize: Int64 = 0
        var coverAsset: PHAsset? = nil
    }

    @State private var albums: [RealAlbum] = [
        .init(id: 0, emoji: "🤳", name: L10n.albumSelfie,     color: AppColors.purple,      subtype: .smartAlbumSelfPortraits),
        .init(id: 1, emoji: "📱", name: L10n.albumScreenshot,  color: AppColors.red,         subtype: .smartAlbumScreenshots),
        .init(id: 2, emoji: "🎬", name: L10n.albumVideo,       color: AppColors.amber,       subtype: .smartAlbumVideos),
        .init(id: 3, emoji: "🌅", name: L10n.albumPanorama,    color: AppColors.blue,        subtype: .smartAlbumPanoramas),
        .init(id: 4, emoji: "✨", name: L10n.albumLive,        color: AppColors.green,       subtype: .smartAlbumLivePhotos),
        .init(id: 5, emoji: "🐢", name: L10n.albumSlomo,       color: AppColors.lightPurple, subtype: .smartAlbumSlomoVideos),
        .init(id: 6, emoji: "🖼️", name: L10n.albumPortrait,   color: Color(hex: "a855f7"),  subtype: .smartAlbumDepthEffect),
        .init(id: 7, emoji: "⭐", name: L10n.albumFavorites,   color: AppColors.amber,       subtype: .smartAlbumFavorites),
    ]
    @State private var isLoading = true
    let cols = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ZStack {
            AppColors.darkBG.ignoresSafeArea()
            VStack(spacing: 0) {
                SubScreenHeader(title: L10n.smartAlbumTitle, subtitle: L10n.smartAlbumSubtitle, onBack: onDismiss)
                Text(L10n.smartAlbumNote)
                    .font(AppTypography.caption).foregroundColor(AppColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal).padding(.top, 8)

                if isLoading {
                    ToolLoadingView(message: L10n.loadingAlbums)
                } else {
                    ScrollView {
                        LazyVGrid(columns: cols, spacing: 12) {
                            ForEach(albums) { a in
                                SmartAlbumCell(album: a)
                            }
                        }
                        .padding()
                    }
                }
            }
        }
        .task { await loadAlbums() }
    }

    private func loadAlbums() async {
        for i in albums.indices {
            let subtype = albums[i].subtype
            let collections = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: subtype, options: nil)
            guard let col = collections.firstObject else { continue }

            let fetchOpts = PHFetchOptions()
            fetchOpts.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            let assets = PHAsset.fetchAssets(in: col, options: fetchOpts)
            albums[i].count = assets.count
            albums[i].coverAsset = assets.firstObject

            // Estimate total size from first 50 assets
            let sampleCount = min(assets.count, 50)
            if sampleCount > 0 {
                let sampleAssets = assets.objects(at: IndexSet(0..<sampleCount))
                let sampleSize = sampleAssets.reduce(0) { $0 + Int64($1.pixelWidth * $1.pixelHeight * 4) }
                // Extrapolate to full album
                albums[i].totalSize = assets.count > 0
                    ? sampleSize * Int64(assets.count) / Int64(sampleCount)
                    : 0
            }
        }
        isLoading = false
    }
}

struct SmartAlbumCell: View {
    let album: SmartAlbumToolView.RealAlbum

    private var sizeStr: String {
        ByteCountFormatter.string(fromByteCount: album.totalSize, countStyle: .file)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let asset = album.coverAsset {
                PhotoThumbnail(asset: asset, size: 80)
                    .frame(maxWidth: .infinity).frame(height: 80).clipped()
                    .cornerRadius(AppShape.mediaRadius).padding(.bottom, 8)
            } else {
                Text(album.emoji).font(.system(size: 22))
                    .frame(width: 44, height: 44)
                    .background(album.color).cornerRadius(10)
                    .padding(.bottom, 8)
            }
            Text(album.name).font(AppTypography.body.weight(.semibold)).foregroundColor(AppColors.textPrimary)
            Text(L10n.items(album.count)).font(AppTypography.caption).foregroundColor(AppColors.textSecondary).padding(.top, 3)
            if album.totalSize > 0 {
                Text("≈\(sizeStr)").font(AppTypography.caption.weight(.semibold)).foregroundColor(album.color).padding(.top, 2)
            }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.deepCard).cornerRadius(AppShape.cardRadius)
        .overlay(
            RoundedRectangle(cornerRadius: AppShape.cardRadius)
                .stroke(album.color.opacity(0.22), lineWidth: AppShape.borderWidth)
        )
    }
}
