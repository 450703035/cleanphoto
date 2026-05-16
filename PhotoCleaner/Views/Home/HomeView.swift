import SwiftUI
import Photos

struct HomeView: View {
    @EnvironmentObject var vm: ScanViewModel
    @State private var navPath: [HomeRoute] = []

    var body: some View {
        NavigationStack(path: $navPath) {
            ZStack {
                AppColors.darkBG.ignoresSafeArea()
                if vm.isInitialLaunchPreparing {
                    LaunchPreparingView()
                } else {
                    switch vm.phase {
                    case .idle:    ScanIdleView(onStart: vm.startScan)
                    case .scanning: ScanningView(vm: vm, progress: vm.progressVM)
                    case .done:    ResultDashboard(vm: vm, navPath: $navPath)
                    }
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(for: HomeRoute.self) { route in
                routeView(route)
            }
        }
    }

    @ViewBuilder
    private func routeView(_ route: HomeRoute) -> some View {
        switch route {
        case .duplicates:
            DuplicatesView(groups: vm.duplicateGroups + vm.similarGroups, vm: vm)
        case .screenshots:
            ScreenshotCleanView(assets: vm.screenshots, vm: vm)
        case .temporaryRecords:
            TemporaryRecordCleanView(assets: vm.temporaryRecords, vm: vm)
        case .videos:
            VideoCleanView(assets: vm.videos, vm: vm)
        case .lowQuality:
            LowQualityCleanView(assets: vm.lowQuality, vm: vm)
        case .favorites:
            FavoritesCleanView(assets: vm.favorites, vm: vm)
        case .behavior:
            BehaviorCleanView(assets: vm.behaviorAssets, vm: vm)
        case .liveToStatic:
            LivePhotoToolView { navPath.removeLast() }
        }
    }
}

// MARK: - Routes
enum HomeRoute: Hashable {
    case duplicates, screenshots, temporaryRecords, videos, lowQuality, favorites, behavior, liveToStatic
}

// MARK: - Idle scan circle
struct LaunchPreparingView: View {
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(AppColors.purple)
                .scaleEffect(1.1)
            Text(L10n.aiClean)
                .font(AppTypography.body.weight(.semibold))
                .foregroundColor(AppColors.textPrimary)
            Text(L10n.smartAnalyze)
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondary)
        }
    }
}

struct ScanIdleView: View {
    let onStart: () -> Void
    @State private var rotate = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            Text(L10n.aiClean)
                .font(AppTypography.hero)
                .foregroundColor(AppColors.textPrimary)
            Text(L10n.smartAnalyze)
                .font(AppTypography.body)
                .foregroundColor(AppColors.textSecondary)
                .padding(.top, 4)
            Spacer().frame(height: 40)

            // Animated ring
            ZStack {
                Circle().stroke(AppColors.separator, lineWidth: 2).frame(width: 240)
                Circle().stroke(AppColors.purple.opacity(0.15), lineWidth: 1.5).frame(width: 200)
                ZStack {
                    Circle().fill(AppColors.cardBG).frame(width: 164)
                    Circle().stroke(AppColors.purple.opacity(0.3), lineWidth: 1.5).frame(width: 164)
                }

                Circle()
                    .trim(from: 0, to: 0.15)
                    .stroke(AppColors.purple.opacity(0.5), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 200)
                    .rotationEffect(.degrees(rotate ? 360 : 0))
                    .animation(.linear(duration: 3).repeatForever(autoreverses: false), value: rotate)

                VStack(spacing: 6) {
                    Image(systemName: "camera.fill").font(.system(size: 38)).foregroundColor(AppColors.purple)
                    Text(L10n.notScanned).font(.system(size: 17, weight: .semibold)).foregroundColor(AppColors.textPrimary)
                    Text(L10n.tapToStart).font(AppTypography.caption).foregroundColor(AppColors.textSecondary)
                }
            }
            .onAppear { rotate = true }

            Spacer().frame(height: 32)

            Button(action: onStart) {
                Text(L10n.startScan)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ApplePrimaryButtonStyle())
            .padding(.horizontal, 48)

            Spacer().frame(height: 24)

            VStack(spacing: 6) {
                Text(L10n.noManualPick)
                    .font(AppTypography.body.weight(.semibold)).foregroundColor(AppColors.textPrimary)
                Text(L10n.safeDeleteGuide)
                    .font(AppTypography.caption).foregroundColor(AppColors.textSecondary)
            }
            Spacer()
        }
    }
}

// MARK: - Scanning animation
struct ScanningView: View {
    @ObservedObject var vm: ScanViewModel
    @ObservedObject var progress: ScanProgressViewModel
    var showsCancel: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            Text(L10n.aiClean).font(AppTypography.hero).foregroundColor(AppColors.textPrimary)
            Text(progress.phaseLabel).font(AppTypography.caption).foregroundColor(AppColors.lightPurple).padding(.top, 4)
            Spacer().frame(height: 32)

            PhotoSphereView(assets: Array(vm.allAssets.prefix(40).map { $0.asset }))
                .frame(width: 220, height: 220)

            Spacer().frame(height: 20)

            VStack(spacing: 8) {
                Text("\(Int(progress.progress * 100))%")
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                ProgressView(value: progress.progress)
                    .tint(AppColors.purple)
                    .padding(.horizontal, 40)
                Text(L10n.analyzedPhotos(progress.analyzedCount))
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondary)
                Text(L10n.elapsedTime(progress.scanElapsedText))
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer().frame(height: 28)
            VStack(spacing: 6) {
                Text(L10n.noManualPick)
                    .font(AppTypography.body.weight(.semibold)).foregroundColor(AppColors.textPrimary)
                Text(L10n.safeDeleteGuide)
                    .font(AppTypography.caption).foregroundColor(AppColors.textSecondary)
            }

            if showsCancel {
                // Cancel button — vm.reset() calls scanTask?.cancel() then returns to idle
                Button(action: vm.reset) {
                    Text(L10n.cancelScan)
                        .foregroundColor(AppColors.lightPurple)
                }
                .buttonStyle(AppleOutlineButtonStyle())
                .padding(.top, 20)
            }

            Spacer()
        }
    }
}

// MARK: - Background analysis banner (observes progressVM directly so the
// Home dashboard's main body is not re-evaluated every progress tick).
struct BackgroundAnalysisBanner: View {
    @ObservedObject var progress: ScanProgressViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(progress.backgroundLabel.isEmpty ? L10n.bgAnalyzing : progress.backgroundLabel)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColors.purple)
                Spacer()
                Text("\(Int(progress.backgroundProgress * 100))%")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
            }
            ProgressView(value: progress.backgroundProgress)
                .tint(AppColors.purple)
        }
        .padding(14)
        .background(AppColors.cardBG)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppColors.separator, lineWidth: 0.5)
        )
    }
}

// MARK: - Photo sphere
private struct SphereNode: Identifiable {
    let id: Int
    let lat: Double
    let lon: Double
    let baseSize: CGFloat
}

struct PhotoSphereView: View {
    let assets: [PHAsset]
    @State private var thumbnails: [Int: UIImage] = [:]
    // node.id → current thumbnail index, updated randomly every second
    @State private var nodePhotoMap: [Int: Int] = [:]

    private let nodes: [SphereNode]
    private let sphereR: Double = 88
    private let tiltX: Double = 0.40   // ~23° tilt for 3D feel
    private var refreshToken: String {
        let ids = assets.prefix(24).map(\.localIdentifier).joined(separator: "|")
        return "\(assets.count)-\(ids)"
    }

    init(assets: [PHAsset]) {
        self.assets = assets
        let n = 40
        let golden = Double.pi * (3.0 - 5.0.squareRoot())
        nodes = (0..<n).map { i in
            let yUnit = 1.0 - (Double(i) / Double(n - 1)) * 2.0
            let theta = golden * Double(i)
            let lat = asin(max(-1.0, min(1.0, yUnit)))
            let sz = CGFloat(18 + (i * 7 % 12))   // 18–30 pt, deterministic
            return SphereNode(id: i, lat: lat, lon: theta, baseSize: sz)
        }
    }

    var body: some View {
        SwiftUI.TimelineView(AnimationTimelineSchedule(minimumInterval: 1.0 / 30.0)) { timeline in
            let angle = timeline.date.timeIntervalSinceReferenceDate * 0.45
            ZStack {
                ForEach(positionedNodes(rotAngle: angle)) { item in
                    nodeView(item: item)
                        .offset(x: item.screenX, y: item.screenY)
                        .zIndex(item.zIndex)
                }
            }
        }
        .task(id: refreshToken) {
            thumbnails = [:]
            nodePhotoMap = [:]
            await loadAndRefresh()
        }
    }

    // MARK: Private

    private struct PositionedItem: Identifiable {
        let id: Int
        let node: SphereNode
        let screenX: CGFloat
        let screenY: CGFloat
        let zIndex: Double
        let depth: CGFloat   // 0 = back, 1 = front
    }

    private func positionedNodes(rotAngle: Double) -> [PositionedItem] {
        nodes.map { node in
            let (x, y, z) = coords3D(lat: node.lat, lon: node.lon + rotAngle)
            let depth = CGFloat((z / sphereR + 1.0) / 2.0)
            return PositionedItem(
                id: node.id,
                node: node,
                screenX: CGFloat(x),
                screenY: CGFloat(y),
                zIndex: Double(depth),
                depth: depth
            )
        }
    }

    private func coords3D(lat: Double, lon: Double) -> (Double, Double, Double) {
        let x  = sphereR * cos(lat) * cos(lon)
        let y0 = sphereR * sin(lat)
        let z0 = sphereR * cos(lat) * sin(lon)
        // Rotate around X axis for tilt
        let y  = y0 * cos(tiltX) - z0 * sin(tiltX)
        let z  = y0 * sin(tiltX) + z0 * cos(tiltX)
        return (x, y, z)
    }

    @ViewBuilder
    private func nodeView(item: PositionedItem) -> some View {
        let d = item.depth
        let scale = 0.3 + d * 0.7
        let opacity = 0.2 + Double(d) * 0.8
        let img = nodePhotoMap[item.node.id].flatMap { thumbnails[$0] }

        Group {
            if let img {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: item.node.baseSize, height: item.node.baseSize)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                    .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.white.opacity(Double(d) * 0.5), lineWidth: 0.5))
            } else {
                RoundedRectangle(cornerRadius: 3)
                    .fill(AppColors.cardBG)
                    .frame(width: item.node.baseSize, height: item.node.baseSize)
                    .overlay(Image(systemName: "photo.fill").font(.system(size: 7)).foregroundColor(AppColors.purple.opacity(0.7)))
                    .overlay(RoundedRectangle(cornerRadius: 3).stroke(AppColors.purple.opacity(0.3), lineWidth: 0.5))
            }
        }
        .opacity(opacity)
        .scaleEffect(scale)
    }

    // Start rotating node mapping immediately, while thumbnails are loaded concurrently.
    private func loadAndRefresh() async {
        guard !assets.isEmpty else { return }
        let limit = min(assets.count, 120)

        // Seed node mapping so sphere feels "alive" immediately.
        for node in nodes {
            nodePhotoMap[node.id] = Int.random(in: 0..<limit)
        }

        // Concurrent thumbnail preloading (shows images progressively).
        Task {
            await preloadThumbnails(limit: limit)
        }

        // Randomly refresh 6–10 nodes every ~0.45s while scanning.
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 450_000_000)
            guard !Task.isCancelled, !thumbnails.isEmpty else { continue }
            let count = thumbnails.count
            let refreshCount = Int.random(in: 6...10)
            let picked = nodes.shuffled().prefix(refreshCount)
            for node in picked {
                nodePhotoMap[node.id] = Int.random(in: 0..<count)
            }
        }
    }

    private func preloadThumbnails(limit: Int) async {
        let maxConcurrent = 8
        var nextIndex = 0
        await withTaskGroup(of: (Int, UIImage?).self) { group in
            while nextIndex < min(maxConcurrent, limit) {
                let idx = nextIndex
                group.addTask { (idx, await fetchThumbnail(assets[idx])) }
                nextIndex += 1
            }

            for await (idx, image) in group {
                if Task.isCancelled { return }
                if let image {
                    thumbnails[idx] = image
                    if nodePhotoMap[idx % nodes.count] == nil {
                        nodePhotoMap[idx % nodes.count] = idx
                    }
                }

                if nextIndex < limit {
                    let i = nextIndex
                    group.addTask { (i, await fetchThumbnail(assets[i])) }
                    nextIndex += 1
                }
            }
        }
    }

    private func fetchThumbnail(_ asset: PHAsset) async -> UIImage? {
        await withCheckedContinuation { cont in
            var done = false
            let opts = PHImageRequestOptions()
            opts.deliveryMode = .opportunistic
            opts.resizeMode = .fast
            opts.isNetworkAccessAllowed = true
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: 60, height: 60),
                contentMode: .aspectFill,
                options: opts
            ) { img, info in
                guard !done else { return }
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) == true
                let cancelled = (info?[PHImageCancelledKey] as? Bool) == true
                if cancelled {
                    done = true
                    cont.resume(returning: nil)
                    return
                }
                if let img, !isDegraded {
                    done = true
                    cont.resume(returning: img)
                    return
                }
                // Fallback: degraded image is still better than an empty tile.
                if let img, isDegraded {
                    done = true
                    cont.resume(returning: img)
                }
            }
        }
    }
}

// MARK: - Result dashboard
struct ResultDashboard: View {
    @ObservedObject var vm: ScanViewModel
    @Binding var navPath: [HomeRoute]

    struct PrimaryCleanTask: Identifiable {
        let route: HomeRoute
        let title: String
        let count: Int
        let sizeBytes: Int64
        let accent: Color
        var id: HomeRoute { route }
    }

    struct SecondaryCleanTask: Identifiable {
        let route: HomeRoute
        let title: String
        let subtitle: String
        let count: Int
        let sizeBytes: Int64
        let icon: String
        let tint: Color
        var id: HomeRoute { route }
    }

    private var duplicateAndSimilarGroups: [PhotoGroup] {
        vm.duplicateGroups + vm.similarGroups
    }

    private var duplicateAndSimilarCount: Int {
        Set(duplicateAndSimilarGroups.flatMap { $0.assets.map(\.id) }).count
    }

    private var duplicateAndSimilarBytes: Int64 {
        duplicateAndSimilarGroups
            .flatMap { $0.assets.dropFirst() }
            .reduce(0) { $0 + $1.sizeBytes }
    }

    private var liveConvertBytes: Int64 {
        Int64(Double(vm.summary.livePhotoBytes) * 0.55)
    }

    private var releasePercent: Int {
        guard vm.summary.totalBytes > 0 else { return 0 }
        let ratio = Double(vm.summary.freeableBytes) / Double(vm.summary.totalBytes)
        return Int((ratio * 100).rounded())
    }

    private var cleanSubtitle: String {
        let freeable = ByteCountFormatter.string(fromByteCount: vm.summary.freeableBytes, countStyle: .file)
        return L10n.isEn ? "Smart organize · Est. free \(freeable)" : "智能整理 · 预计可释放 \(freeable)"
    }

    private var videoFilesTitle: String {
        L10n.isEn ? "Video Files" : "视频文件"
    }

    private var primaryTasks: [PrimaryCleanTask] {
        [
            .init(route: .duplicates, title: L10n.isEn ? "Duplicates & Similar" : "重复与相似", count: duplicateAndSimilarCount, sizeBytes: duplicateAndSimilarBytes, accent: Color(hex: "f5a452")),
            .init(route: .screenshots, title: L10n.isEn ? "Screenshot Cleanup" : "截图清理", count: vm.screenshots.count, sizeBytes: vm.screenshots.reduce(0) { $0 + $1.sizeBytes }, accent: Color(hex: "63a4ff")),
            .init(route: .temporaryRecords, title: L10n.isEn ? "Temporary Records" : "临时记录", count: vm.temporaryRecords.count, sizeBytes: vm.temporaryRecords.reduce(0) { $0 + $1.sizeBytes }, accent: Color(hex: "7f8cff")),
            .init(route: .lowQuality, title: L10n.isEn ? "Low Quality" : "低质量", count: vm.lowQuality.count, sizeBytes: vm.lowQuality.reduce(0) { $0 + $1.sizeBytes }, accent: Color(hex: "72ce95")),
            .init(route: .liveToStatic, title: L10n.isEn ? "Live to Still" : "Live转静态", count: vm.summary.livePhotoCount, sizeBytes: liveConvertBytes, accent: Color(hex: "ffb168")),
            .init(route: .videos, title: videoFilesTitle, count: vm.videos.count, sizeBytes: vm.videos.reduce(0) { $0 + $1.sizeBytes }, accent: Color(hex: "ff8f8f")),
        ]
    }

    private var secondaryTasks: [SecondaryCleanTask] {
        [
            .init(
                route: .favorites,
                title: L10n.isEn ? "Favorites" : "收藏",
                subtitle: L10n.isEn ? "Default unselected to avoid accidental deletion" : "默认不选中，避免误删重要内容",
                count: vm.favorites.count,
                sizeBytes: vm.favorites.reduce(0) { $0 + $1.sizeBytes },
                icon: "heart.fill",
                tint: Color(lightHex: "fff4ee", darkHex: "2a201d")
            ),
            .init(
                route: .behavior,
                title: L10n.isEn ? "Other" : "其他",
                subtitle: L10n.isEn ? "Cold photos and remaining items" : "冷门照片与其余内容",
                count: vm.behaviorAssets.count,
                sizeBytes: vm.behaviorAssets.reduce(0) { $0 + $1.sizeBytes },
                icon: "snowflake",
                tint: Color(lightHex: "f2f7ff", darkHex: "1f252e")
            ),
        ]
    }

    private func push(_ route: HomeRoute) {
        navPath.append(route)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.tabClean)
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                    Text(cleanSubtitle)
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.textSecondary)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)

                CleanHeroCard(
                    freeableBytes: vm.summary.freeableBytes,
                    releasePercent: releasePercent
                )
                .padding(.horizontal, 16)

                if vm.isBackgroundAnalyzing {
                    BackgroundAnalysisBanner(progress: vm.progressVM)
                        .padding(.horizontal, 16)
                }

                CleanSectionHeader(eyebrow: L10n.isEn ? "Recommended" : "推荐动作", title: L10n.isEn ? "Priority Cleanup" : "优先清理")
                    .padding(.horizontal, 16)

                PriorityCleanCard(
                    items: primaryTasks,
                    onTap: push
                )
                .padding(.horizontal, 16)

                CleanSectionHeader(eyebrow: L10n.isEn ? "More" : "补充分组", title: L10n.isEn ? "Favorites & Other" : "收藏与其他")
                    .padding(.horizontal, 16)

                VStack(spacing: 10) {
                    ForEach(secondaryTasks) { item in
                        SecondaryCleanCard(item: item) {
                            push(item.route)
                        }
                    }
                }
                .padding(.horizontal, 16)

                Text(L10n.isEn ? "All analysis stays on device · You can undo cleanup anytime." : "所有分析均在本机完成 · 你可随时撤销清理")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(AppColors.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
            }
        }
        .background(AppColors.darkBG)
    }
}

private struct CleanSectionHeader: View {
    let eyebrow: String
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(eyebrow)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(AppColors.textTertiary)
                .textCase(.uppercase)
            Text(title)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(AppColors.textPrimary)
        }
    }
}

private struct CleanHeroCard: View {
    let freeableBytes: Int64
    let releasePercent: Int

    private var freeableGB: String {
        let gb = Double(freeableBytes) / 1_000_000_000
        return gb >= 10 ? String(format: "%.0f", gb) : String(format: "%.1f", gb)
    }

    private var releaseCaption: String {
        L10n.isEn ? "Estimated from duplicates, screenshots, temporary records and low quality photos." : "预计从重复图、截图、临时记录和低质量照片中释放空间。"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.isEn ? "Smart Cleanup" : "智能清理建议")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color.white.opacity(0.78))
                .textCase(.uppercase)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(freeableGB)
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.white)
                Text("GB")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.9))
            }

            Text(releaseCaption)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color.white.opacity(0.84))

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.2))
                    Capsule()
                        .fill(Color.white)
                        .frame(width: geo.size.width * CGFloat(max(0, min(100, releasePercent))) / 100.0)
                }
            }
            .frame(height: 8)

            Text(L10n.isEn ? "About \(max(releasePercent, 0))% of total device storage" : "占设备总容量约 \(max(releasePercent, 0))%")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color.white.opacity(0.75))
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [Color(hex: "456cd6"), Color(hex: "3a52bf"), Color(hex: "2d3f97")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(22)
        .overlay(
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: "f4a34f").opacity(0.44), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 120
                    )
                )
                .frame(width: 170, height: 170)
                .offset(x: 90, y: -90),
            alignment: .topTrailing
        )
    }
}

private struct PriorityCleanCard: View {
    let items: [ResultDashboard.PrimaryCleanTask]
    let onTap: (HomeRoute) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L10n.isEn ? "High-yield tasks" : "高收益任务")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
                Text(L10n.isEn ? "Est. 4 mins" : "预计 4 分钟")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppColors.textTertiary)
            }

            VStack(spacing: 9) {
                ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                    Button {
                        onTap(item.route)
                    } label: {
                        HStack(spacing: 10) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(item.accent)
                                .frame(width: 10, height: 10)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(AppColors.textPrimary)
                                Text("\(item.count) \(L10n.isEn ? "items" : "项") · \(ByteCountFormatter.string(fromByteCount: item.sizeBytes, countStyle: .file))")
                                    .font(.system(size: 12))
                                    .foregroundColor(AppColors.textSecondary)
                            }

                            Spacer(minLength: 8)

                            Text(idx == 0 ? (L10n.isEn ? "Clean now" : "立即清理") : (L10n.isEn ? "View" : "查看"))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(idx == 0 ? Color(lightHex: "ffffff", darkHex: "0a0a0b") : AppColors.textSecondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(idx == 0 ? AppColors.textPrimary : Color(lightHex: "000000", darkHex: "ffffff", lightAlpha: 0.08, darkAlpha: 0.14))
                                .clipShape(Capsule())
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(18)
        .background(AppColors.cardBG)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(AppColors.separator, lineWidth: 0.5)
        )
    }
}

private struct SecondaryCleanCard: View {
    let item: ResultDashboard.SecondaryCleanTask
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: item.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 34, height: 34)
                    .foregroundColor(AppColors.textPrimary)
                    .background(Color(lightHex: "000000", darkHex: "ffffff", lightAlpha: 0.06, darkAlpha: 0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                    Text(item.subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(1)
                    Text("\(item.count) \(L10n.isEn ? "items" : "项") · \(ByteCountFormatter.string(fromByteCount: item.sizeBytes, countStyle: .file))")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColors.textTertiary)
            }
            .padding(14)
            .background(item.tint)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AppColors.separator, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Health ring card
struct HealthCard: View {
    let summary: LibrarySummary
    private let ringSize: CGFloat = 68

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().stroke(AppColors.separator, lineWidth: 5).frame(width: ringSize)
                Circle()
                    .trim(from: 0, to: Double(summary.healthScore) / 100)
                    .stroke(
                        LinearGradient(colors: [AppColors.purple, AppColors.lightPurple], startPoint: .top, endPoint: .bottom),
                        style: StrokeStyle(lineWidth: 5, lineCap: .round)
                    )
                    .frame(width: ringSize)
                    .rotationEffect(.degrees(-90))
                Text("\(summary.healthScore)")
                    .font(.system(size: 17, weight: .bold)).foregroundColor(AppColors.textPrimary)
            }

            VStack(spacing: 5) {
                row("📸 \(L10n.totalPhotos)", "\(summary.totalCount)")
                row("💾 \(L10n.storageUsed)", summary.formattedTotal)
                row("🧹 \(L10n.freeable)", summary.formattedFreeable, accent: true)
                row("✅ \(L10n.released)", summary.formattedReleased)
            }
        }
        .padding()
        .background(AppColors.cardBG)
        .cornerRadius(22)
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(AppColors.purple.opacity(0.2), lineWidth: 1))
    }

    private func row(_ label: String, _ value: String, accent: Bool = false) -> some View {
        HStack {
            Text(label).font(.caption).foregroundColor(AppColors.textSecondary)
            Spacer()
            Text(value).font(.caption).fontWeight(.semibold)
                .foregroundColor(accent ? AppColors.lightPurple : AppColors.textPrimary)
        }
    }
}

// MARK: - Space bar
struct SpaceBar: View {
    let summary: LibrarySummary
    private var total: Int64 { max(summary.totalBytes, 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.spaceDistribution).font(.caption).fontWeight(.semibold)
                .foregroundColor(AppColors.textSecondary).textCase(.uppercase)

            GeometryReader { geo in
                HStack(spacing: 1) {
                    seg(summary.videoBytes,      color: AppColors.purple,  width: geo.size.width)
                    seg(summary.screenshotBytes, color: AppColors.red,     width: geo.size.width)
                    seg(summary.utilityBytes,    color: AppColors.blue,    width: geo.size.width)
                    seg(summary.livePhotoBytes,  color: AppColors.amber,   width: geo.size.width)
                    seg(summary.photoBytes,      color: AppColors.green,   width: geo.size.width)
                    Rectangle().fill(AppColors.separator).cornerRadius(2)
                }
                .frame(height: 7)
                .cornerRadius(4)
            }
            .frame(height: 7)

            HStack(spacing: 0) {
                ForEach([
                    (AppColors.purple, L10n.video),
                    (AppColors.red, L10n.screenshot),
                    (AppColors.blue, L10n.temporaryRecords),
                    (AppColors.amber, "Live"),
                    (AppColors.green, L10n.photo)
                ], id: \.1) { color, label in
                    HStack(spacing: 4) {
                        Circle().fill(color).frame(width: 7, height: 7)
                        Text(label).font(.system(size: 10)).foregroundColor(AppColors.textSecondary)
                    }
                    .padding(.trailing, 12)
                }
            }
        }
    }

    private func seg(_ bytes: Int64, color: Color, width: CGFloat) -> some View {
        let fraction = CGFloat(bytes) / CGFloat(total)
        return Rectangle().fill(color).frame(width: width * fraction).cornerRadius(2)
    }
}

// MARK: - Suggestion card
struct SuggestionCard: View {
    let icon: String
    let iconBg: Color
    let title: String
    let desc: String
    let size: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .frame(width: 38, height: 38)
                    .background(iconBg)
                    .foregroundColor(.white)
                    .cornerRadius(11)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.subheadline).fontWeight(.semibold).foregroundColor(AppColors.textPrimary)
                    Text(desc).font(.caption).foregroundColor(AppColors.textSecondary)
                }
                Spacer()
                Text(size).font(.footnote).fontWeight(.bold).foregroundColor(AppColors.lightPurple)
                Image(systemName: "chevron.right").font(.caption).foregroundColor(AppColors.textTertiary)
            }
            .padding(12)
            .background(AppColors.deepCard)
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppColors.subtleBorder, lineWidth: 0.5))
        }
        .padding(.horizontal)
    }
}
