import SwiftUI
import Photos

// MARK: - Score badge
struct ScoreBadge: View {
    let score: Int
    var fontSize: CGFloat = 10

    var body: some View {
        Text("\(score)")
            .font(.system(size: fontSize, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(score.scoreColor)
            .cornerRadius(3)
    }
}

// MARK: - Photo thumbnail (async)
struct PhotoThumbnail: View {
    let asset: PHAsset
    var size: CGFloat = 80
    var height: CGFloat? = nil          // nil → square (size × size)
    var contentMode: ContentMode = .fill
    @State private var image: UIImage?
    @State private var requestID: PHImageRequestID?

    var body: some View {
        let h = height ?? size
        Group {
            if let img = image {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                Rectangle()
                    .fill(AppColors.deepCard)
            }
        }
        .frame(width: size, height: h)
        .clipped()
        .task(id: asset.localIdentifier) {
            await load()
        }
        .onDisappear {
            if let rid = requestID {
                PHImageManager.default().cancelImageRequest(rid)
                requestID = nil
            }
        }
    }

    private func load() async {
        // Cancel any previous request for this view
        if let rid = requestID {
            PHImageManager.default().cancelImageRequest(rid)
            requestID = nil
        }
        let h = height ?? size
        let targetSize = CGSize(width: size * 2, height: h * 2)
        let opts = PHImageRequestOptions()
        opts.deliveryMode = .opportunistic
        opts.isSynchronous = false
        opts.isNetworkAccessAllowed = false
        let phMode: PHImageContentMode = (contentMode == .fill) ? .aspectFill : .aspectFit
        let rid = PHImageManager.default().requestImage(
            for: asset, targetSize: targetSize,
            contentMode: phMode, options: opts
        ) { img, _ in
            Task { @MainActor in
                if let img { image = img }
            }
        }
        requestID = rid
    }
}

// MARK: - Large photo card (best photo)
struct LargePhotoCard: View {
    let asset: PhotoAsset
    @Binding var isSelected: Bool
    @Binding var selectionMode: Bool
    var isBest: Bool = false
    var onToggle: () -> Void = {}
    var onView: () -> Void = {}

    var body: some View {
        ZStack {
            PhotoThumbnail(asset: asset.asset, size: 300)
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                .clipped()
                .cornerRadius(8)

            VStack {
                HStack {
                    ScoreBadge(score: asset.score, fontSize: 12)
                    if isBest {
                        Text("⭐ \(L10n.best)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color(hex: "7c2d00"))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(AppColors.amber)
                            .cornerRadius(7)
                    }
                    Spacer()
                    cornerMetaText(asset.formattedSize, fontSize: 10)
                }
                Spacer()
                HStack {
                    cornerMetaText(mediaTypeTag(asset.asset), fontSize: 10)
                    Spacer()
                    if selectionMode {
                        SelectionStatusBadge(isSelected: isSelected, size: 24)
                    }
                }
            }
            .padding(10)

            if isSelected {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.25))
            }
        }
        .onTapGesture {
            if selectionMode { onToggle() } else { onView() }
        }
    }
}

// MARK: - Small photo cell
struct SmallPhotoCell: View {
    let asset: PhotoAsset
    @Binding var isSelected: Bool
    @Binding var selectionMode: Bool
    var onToggle: () -> Void = {}
    var onView: () -> Void = {}

    var body: some View {
        ZStack {
            PhotoThumbnail(asset: asset.asset, size: 110)
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fill)
                .clipped()
                .cornerRadius(8)
                .opacity(isSelected ? 0.82 : 1.0)

            VStack {
                HStack {
                    ScoreBadge(score: asset.score)
                    Spacer()
                    cornerMetaText(asset.formattedSize, fontSize: 8)
                }
                Spacer()
                HStack {
                    cornerMetaText(mediaTypeTag(asset.asset), fontSize: 8)
                    Spacer()
                    if selectionMode {
                        SelectionStatusBadge(isSelected: isSelected, size: 20)
                    }
                }
            }
            .padding(4)

            if isSelected {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.22))
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .onTapGesture {
            if selectionMode { onToggle() } else { onView() }
        }
    }
}

// MARK: - Bottom delete bar
struct BottomDeleteBar: View {
    let count: Int
    let sizeLabel: String
    var actionLabel: String = L10n.deleteSelected
    var color: Color = AppColors.red
    let onDelete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Divider().background(AppColors.separator)
            Button(action: onDelete) {
                HStack {
                    Image(systemName: "trash")
                    Text(L10n.actionCount(actionLabel, count, size: sizeLabel))
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity)
                .foregroundColor(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 980)
                        .fill(color)
                )
                .padding(.horizontal)
                .padding(.vertical, 10)
            }
            .background(AppColors.darkBG.opacity(0.97))
        }
    }
}

// MARK: - Sub-screen header
struct SubScreenHeader: View {
    let title: String
    var subtitle: String = ""
    let onBack: () -> Void
    var trailing: AnyView = AnyView(EmptyView())

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text(L10n.back)
                    }
                    .foregroundColor(AppColors.lightPurple)
                }
                Spacer()
                trailing
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 4)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppTypography.body.weight(.semibold))
                    .foregroundColor(AppColors.textPrimary)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.bottom, 8)

            Divider().background(AppColors.separator)
        }
        .background(AppColors.darkBG)
    }
}

// MARK: - Done screen
struct DoneView: View {
    let count: Int
    let label: String
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("🎉").font(.system(size: 64))
            Text(L10n.cleanComplete).font(.title2).bold().foregroundColor(AppColors.textPrimary)
            Text("\(count) \(label)")
                .font(.largeTitle).bold()
                .foregroundColor(AppColors.lightPurple)
            Text(L10n.movedToTrash)
                .multilineTextAlignment(.center)
                .foregroundColor(AppColors.textSecondary)
                .font(.subheadline)
            Button(L10n.back, action: onBack)
                .buttonStyle(ApplePrimaryButtonStyle())
                .tint(AppColors.purple)
                .padding(.top, 8)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.darkBG)
    }
}

// MARK: - Toggle row
struct SettingsToggleRow: View {
    let icon: String
    let iconBg: Color
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .frame(width: 30, height: 30)
                .background(iconBg)
                .foregroundColor(.white)
                .cornerRadius(AppShape.iconRadius)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).foregroundColor(AppColors.textPrimary).font(AppTypography.body)
                Text(subtitle).foregroundColor(AppColors.textTertiary).font(.caption)
            }
            Spacer()
            Toggle("", isOn: $isOn).labelsHidden().tint(AppColors.purple)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }
}

// MARK: - Album folder thumbnail
struct AlbumFolderCell: View {
    let folder: AlbumFolder
    var onTap: () -> Void
    var onLongPress: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            // 2x2 grid preview
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 1), GridItem(.flexible(), spacing: 1)], spacing: 1) {
                ForEach(Array(folder.assets.prefix(4)), id: \.id) { asset in
                    PhotoThumbnail(asset: asset.asset, size: 60)
                        .aspectRatio(1, contentMode: .fill)
                        .clipped()
                        .opacity(folder.recommendDelete ? 0.5 : 1)
                }
                if folder.assets.count < 4 {
                    ForEach(0..<(4 - min(folder.assets.count, 4)), id: \.self) { _ in
                        Rectangle().fill(AppColors.deepCard)
                    }
                }
            }
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(AppColors.subtleBorder, lineWidth: 0.5)
        )

            // Overlay info
            VStack(alignment: .leading, spacing: 1) {
                HStack {
                    Text(L10n.folderInfo(folder.assets.count, folder.title))
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                }
                Text(folder.formattedSize)
                    .font(.system(size: 8))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(5)
            .background(Color.black.opacity(0.7))

            // Score badge
            VStack {
                HStack {
                    Spacer()
                    ScoreBadge(score: folder.averageScore, fontSize: 8)
                        .padding(4)
                }
                Spacer()
            }

            // Recommend indicator
            if folder.recommendDelete {
                Circle()
                    .fill(AppColors.purple)
                    .frame(width: 14, height: 14)
                    .overlay(Image(systemName: "checkmark").font(.system(size: 7, weight: .bold)).foregroundColor(.white))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(4)

                RoundedRectangle(cornerRadius: 10)
                    .stroke(AppColors.red.opacity(0.6), lineWidth: 1.5)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .onTapGesture(perform: onTap)
        .onLongPressGesture(minimumDuration: 0.6, perform: onLongPress)
    }
}

// MARK: - Shared selection/meta UI
struct SelectionStatusBadge: View {
    let isSelected: Bool
    var size: CGFloat = 20

    var body: some View {
        Group {
            if isSelected {
                ZStack {
                    Circle()
                        .fill(AppColors.selectionBlue)
                        .frame(width: size, height: size)
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                        .frame(width: size, height: size)
                    Image(systemName: "checkmark")
                        .font(.system(size: max(8, size * 0.42), weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
    }
}

func cornerMetaText(_ text: String, fontSize: CGFloat) -> some View {
    Text(text)
        .font(.system(size: fontSize, weight: .semibold))
        .foregroundColor(.white.opacity(0.92))
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(Color.black.opacity(0.55))
        .cornerRadius(4)
}

func mediaTypeTag(_ asset: PHAsset) -> String {
    let sub = asset.mediaSubtypes
    if asset.mediaType == .video { return L10n.tagVideo }
    if sub.contains(.photoScreenshot) { return L10n.tagScreenshot }
    if sub.contains(.photoLive) { return "Live" }
    if sub.contains(.photoPanorama) { return L10n.tagPanorama }
    if sub.contains(.photoHDR) { return "HDR" }
    return L10n.tagPhoto
}
