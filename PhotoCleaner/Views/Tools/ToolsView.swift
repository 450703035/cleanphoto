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
        .init(icon: "photo.on.rectangle", name: "Live→静态", desc: "Live Photo 转普通照片", color: AppColors.purple, free: true, route: .livePhoto),
        .init(icon: "arrow.down.doc", name: "视频压缩", desc: "智能压缩，画质损失最小", color: AppColors.red, free: false, route: .videoCompress),
        .init(icon: "eye.slash", name: "模糊检测", desc: "自动找出模糊照片", color: AppColors.green, free: true, route: .blurDetect),
        .init(icon: "photo", name: "HEIC转换", desc: "批量转为 JPG 格式", color: AppColors.blue, free: true, route: .heic),
        .init(icon: "square.grid.2x2", name: "智能相册", desc: "AI 自动分类整理", color: Color(hex: "a855f7"), free: false, route: .smartAlbum),
        .init(icon: "hand.point.left.fill", name: "逐张决策", desc: "左滑删除 · 右滑保留 · 撤销", color: AppColors.amber, free: true, route: .swipeDelete),
    ]

    let cols = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ZStack {
            AppColors.darkBG.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("清理工具").font(.largeTitle).bold().foregroundColor(.white)
                        Text("专业照片整理工具箱").font(.subheadline).foregroundColor(AppColors.textSecondary)
                    }
                    .padding(.horizontal).padding(.top, 16).padding(.bottom, 16)

                    LazyVGrid(columns: cols, spacing: 12) {
                        ForEach(items, id: \.name) { t in
                            ToolCard(
                                icon: t.icon,
                                name: t.name,
                                desc: t.desc,
                                iconBg: t.color.opacity(0.2),
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
                    .background(iconBg).foregroundColor(.white).cornerRadius(12)
                    .padding(.bottom, 9)
                Text(name).font(.subheadline).fontWeight(.bold).foregroundColor(.white).padding(.bottom, 3)
                Text(desc).font(.system(size: 10)).foregroundColor(AppColors.textSecondary).lineLimit(2).padding(.bottom, 7)
                Text(isFree ? "免费" : "Pro")
                    .font(.system(size: 9, weight: .bold))
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(isFree ? AppColors.green.opacity(0.15) : AppColors.purple.opacity(0.2))
                    .foregroundColor(isFree ? AppColors.green : AppColors.lightPurple)
                    .cornerRadius(5)
            }
            .padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.04)).cornerRadius(18)
            .overlay(
                RoundedRectangle(cornerRadius: 18).stroke(
                    isHighlighted ? AppColors.amber.opacity(0.45) : AppColors.subtleBorder,
                    lineWidth: isHighlighted ? 1 : 0.5
                )
            )
        }
    }
}
