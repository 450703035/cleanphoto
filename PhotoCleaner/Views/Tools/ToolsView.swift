import SwiftUI

// MARK: - Tools main grid
struct ToolsView: View {
    @State private var activeTool: ToolRoute? = nil

    enum ToolRoute: String, Identifiable {
        case livePhoto, videoCompress, blurDetect, heic, smartAlbum, swipeDelete
        var id: String { rawValue }
    }

    struct ToolItem {
        let icon: String
        let name: String
        let desc: String
        let color: Color
        let free: Bool
        let route: ToolRoute
    }

    let items: [ToolItem] = [
        .init(icon: "photo.on.rectangle", name: L10n.liveToStatic, desc: L10n.liveToStaticDesc, color: AppColors.purple, free: true, route: .livePhoto),
        .init(icon: "arrow.down.doc", name: L10n.videoCompress, desc: L10n.videoCompressDesc, color: AppColors.red, free: false, route: .videoCompress),
        .init(icon: "eye.slash", name: L10n.blurDetect, desc: L10n.blurDetectDesc, color: AppColors.green, free: true, route: .blurDetect),
        .init(icon: "photo", name: L10n.heicConvert, desc: L10n.heicConvertDesc, color: AppColors.blue, free: true, route: .heic),
        .init(icon: "square.grid.2x2", name: L10n.smartAlbum, desc: L10n.smartAlbumDesc, color: Color(hex: "a855f7"), free: false, route: .smartAlbum),
        .init(icon: "hand.point.left.fill", name: L10n.swipeDecide, desc: L10n.swipeDecideDesc, color: AppColors.amber, free: true, route: .swipeDelete),
    ]

    let cols = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ZStack {
            AppColors.darkBG.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.cleaningTools).font(AppTypography.sectionTitle).foregroundColor(AppColors.textPrimary)
                        Text(L10n.toolboxSubtitle).font(AppTypography.body).foregroundColor(AppColors.textSecondary)
                    }
                    .padding(.horizontal).padding(.top, 16).padding(.bottom, 16)

                    LazyVGrid(columns: cols, spacing: 12) {
                        ForEach(items, id: \.route) { t in
                            ToolCard(
                                icon: t.icon,
                                name: t.name,
                                desc: t.desc,
                                iconBg: t.color,
                                isFree: t.free,
                                isHighlighted: t.route == .swipeDelete
                            ) {
                                activeTool = t.route
                            }
                        }
                    }
                    .padding(.horizontal).padding(.bottom, 20)
                }
            }
        }
        .navigationBarHidden(true)
        .fullScreenCover(item: $activeTool) { route in
            switch route {
            case .livePhoto:
                LivePhotoToolView { activeTool = nil }
            case .videoCompress:
                VideoCompressToolView { activeTool = nil }
            case .blurDetect:
                BlurDetectToolView { activeTool = nil }
            case .heic:
                HeicConvertToolView { activeTool = nil }
            case .smartAlbum:
                SmartAlbumToolView { activeTool = nil }
            case .swipeDelete:
                SwipeDeleteToolView { activeTool = nil }
            }
        }
    }
}

// MARK: - Tool card cell
struct ToolCard: View {
    let icon: String
    let name: String
    let desc: String
    let iconBg: Color
    let isFree: Bool
    var isHighlighted: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .frame(width: 42, height: 42)
                    .background(iconBg).foregroundColor(.white).cornerRadius(10)
                    .padding(.bottom, 9)
                Text(name).font(AppTypography.body.weight(.semibold)).foregroundColor(AppColors.textPrimary).padding(.bottom, 3)
                Text(desc).font(AppTypography.micro).foregroundColor(AppColors.textSecondary).lineLimit(2).padding(.bottom, 7)
                Text(isFree ? L10n.free : "Pro")
                    .font(.system(size: 9, weight: .bold))
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(isFree ? AppColors.green.opacity(0.15) : AppColors.blue.opacity(0.24))
                    .foregroundColor(isFree ? AppColors.green : AppColors.lightPurple)
                    .cornerRadius(AppShape.iconRadius)
            }
            .padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.deepCard).cornerRadius(AppShape.cardRadius)
            .overlay(
                RoundedRectangle(cornerRadius: AppShape.cardRadius).stroke(
                    isHighlighted ? AppColors.lightPurple.opacity(0.65) : AppColors.subtleBorder,
                    lineWidth: isHighlighted ? 1 : AppShape.borderWidth
                )
             )
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: AppShape.cardRadius))
    }
}
