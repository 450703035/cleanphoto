import SwiftUI
import Photos

struct HomeView: View {
    @EnvironmentObject var vm: ScanViewModel
    @State private var navPath: [HomeRoute] = []

    var body: some View {
        NavigationStack(path: $navPath) {
            ZStack {
                AppColors.darkBG.ignoresSafeArea()
                switch vm.phase {
                case .idle:    ScanIdleView(onStart: vm.startScan)
                case .scanning: ScanningView(vm: vm)
                case .done:    ResultDashboard(vm: vm, navPath: $navPath)
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
        case .videos:
            VideoCleanView(assets: vm.videos, vm: vm)
        case .lowQuality:
            LowQualityCleanView(assets: vm.lowQuality, vm: vm)
        case .favorites:
            FavoritesCleanView(assets: vm.favorites, vm: vm)
        case .behavior:
            BehaviorCleanView(assets: vm.behaviorAssets, vm: vm)
        }
    }
}

// MARK: - Routes
enum HomeRoute: Hashable {
    case duplicates, screenshots, videos, lowQuality, favorites, behavior
}

// MARK: - Idle scan circle
struct ScanIdleView: View {
    let onStart: () -> Void
    @State private var rotate = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            Text("AI 清理").font(.largeTitle).bold().foregroundColor(.white)
            Text("智能分析你的相册").font(.subheadline).foregroundColor(AppColors.textSecondary).padding(.top, 4)
            Spacer().frame(height: 40)

            // Animated ring
            ZStack {
                Circle().stroke(Color.white.opacity(0.05), lineWidth: 2).frame(width: 240)
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
                    Text("尚未扫描").font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                    Text("点击开始").font(.caption).foregroundColor(AppColors.textSecondary)
                }
            }
            .onAppear { rotate = true }

            Spacer().frame(height: 32)

            Button(action: onStart) {
                Text("开始扫描")
                    .font(.system(size: 16, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppColors.purple)
                    .foregroundColor(.white)
                    .cornerRadius(16)
            }
            .padding(.horizontal, 48)

            Spacer().frame(height: 24)

            VStack(spacing: 6) {
                Text("无需逐张选择，AI自动推荐")
                    .font(.subheadline).bold().foregroundColor(.white.opacity(0.85))
                Text("我们将引导您安全删除无用照片")
                    .font(.caption).foregroundColor(AppColors.textSecondary)
            }
            Spacer()
        }
    }
}

// MARK: - Scanning animation
struct ScanningView: View {
    @ObservedObject var vm: ScanViewModel

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            Text("AI 清理").font(.largeTitle).bold().foregroundColor(.white)
            Text(vm.phaseLabel).font(.subheadline).foregroundColor(AppColors.purple).padding(.top, 4)
            Spacer().frame(height: 32)

            PhotoSphereView(assets: Array(vm.allAssets.prefix(40).map { $0.asset }))
                .frame(width: 220, height: 220)

            Spacer().frame(height: 20)

            VStack(spacing: 8) {
                Text("\(Int(vm.progress * 100))%")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                ProgressView(value: vm.progress)
                    .tint(AppColors.purple)
                    .padding(.horizontal, 40)
                Text("已分析 \(vm.analyzedCount) 张照片")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
                Text("已用时 \(vm.scanElapsedText)")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer().frame(height: 28)
            VStack(spacing: 6) {
                Text("无需逐张选择，AI自动推荐")
                    .font(.subheadline).bold().foregroundColor(.white.opacity(0.85))
                Text("我们将引导您安全删除无用照片")
                    .font(.caption).foregroundColor(AppColors.textSecondary)
            }

            // Cancel button — vm.reset() calls scanTask?.cancel() then returns to idle
            Button(action: vm.reset) {
                Text("取消扫描")
                    .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 28)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
            }
            .padding(.top, 20)

            Spacer()
        }
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

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("AI 清理").font(.largeTitle).bold().foregroundColor(.white)
                        Text(vm.isBackgroundAnalyzing
                             ? "后台分析中 · 已用时 \(vm.scanElapsedText)"
                             : "本次扫描总耗时：\(vm.lastScanDurationText)")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    Spacer()
                    Button(action: vm.reset) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.title3).foregroundColor(AppColors.purple)
                    }
                }
                .padding(.horizontal).padding(.top)

                // Health card
                HealthCard(summary: vm.summary).padding(.horizontal).padding(.top, 10)

                // Space bar
                SpaceBar(summary: vm.summary).padding(.horizontal).padding(.top, 12)

                if vm.isBackgroundAnalyzing {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(vm.backgroundLabel.isEmpty ? "后台分析中" : vm.backgroundLabel)
                                .font(.caption)
                                .foregroundColor(AppColors.purple)
                            Spacer()
                            Text("\(Int(vm.backgroundProgress * 100))%")
                                .font(.caption)
                                .foregroundColor(AppColors.textSecondary)
                        }
                        ProgressView(value: vm.backgroundProgress)
                            .tint(AppColors.purple)
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                }

                // Suggestions
                VStack(alignment: .leading, spacing: 8) {
                    Text("智能建议 · 点击进入")
                        .font(.caption).fontWeight(.semibold)
                        .foregroundColor(AppColors.textSecondary)
                        .textCase(.uppercase)
                        .padding(.horizontal)
                        .padding(.top, 12)

                    SuggestionCard(icon: "arrow.triangle.2.circlepath", iconBg: AppColors.purple.opacity(0.2),
                                   title: "重复与相似照片",
                                   desc: "\(vm.duplicateGroups.count)组重复 · \(vm.similarGroups.count)组相似",
                                   size: ByteCountFormatter.string(fromByteCount: vm.duplicateGroups.flatMap{$0.assets.dropFirst()}.reduce(0){$0+$1.sizeBytes}, countStyle: .file)) {
                        navPath.append(.duplicates)
                    }
                    SuggestionCard(icon: "camera.viewfinder", iconBg: AppColors.red.opacity(0.2),
                                   title: "截图清理",
                                   desc: "\(vm.screenshots.count)张截图 · 已自动分析",
                                   size: ByteCountFormatter.string(fromByteCount: vm.screenshots.reduce(0){$0+$1.sizeBytes}, countStyle: .file)) {
                        navPath.append(.screenshots)
                    }
                    SuggestionCard(icon: "video.fill", iconBg: AppColors.amber.opacity(0.2),
                                   title: "大视频文件",
                                   desc: "\(vm.videos.count)个视频，按大小排序",
                                   size: ByteCountFormatter.string(fromByteCount: vm.videos.reduce(0){$0+$1.sizeBytes}, countStyle: .file)) {
                        navPath.append(.videos)
                    }
                    SuggestionCard(icon: "star.slash.fill", iconBg: AppColors.green.opacity(0.2),
                                   title: "低质量照片",
                                   desc: "模糊/抖动/曝光/对焦失败 \(vm.lowQuality.count)张",
                                   size: ByteCountFormatter.string(fromByteCount: vm.lowQuality.reduce(0){$0+$1.sizeBytes}, countStyle: .file)) {
                        navPath.append(.lowQuality)
                    }
                    SuggestionCard(icon: "clock.arrow.trianglehead.counterclockwise.rotate.90", iconBg: AppColors.amber.opacity(0.2),
                                   title: "其他使用行为",
                                   desc: "从未查看/很久没看/按年限筛选",
                                   size: ByteCountFormatter.string(fromByteCount: vm.behaviorAssets.reduce(0){$0+$1.sizeBytes}, countStyle: .file)) {
                        navPath.append(.behavior)
                    }
                    SuggestionCard(icon: "heart.fill", iconBg: AppColors.red.opacity(0.2),
                                   title: "收藏照片",
                                   desc: "\(vm.favorites.count)张 · 默认不选择",
                                   size: ByteCountFormatter.string(fromByteCount: vm.favorites.reduce(0){$0+$1.sizeBytes}, countStyle: .file)) {
                        navPath.append(.favorites)
                    }
                }
                .padding(.bottom, 20)
            }
        }
        .background(AppColors.darkBG)
    }
}

// MARK: - Health ring card
struct HealthCard: View {
    let summary: LibrarySummary
    private let ringSize: CGFloat = 68

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().stroke(Color.white.opacity(0.1), lineWidth: 5).frame(width: ringSize)
                Circle()
                    .trim(from: 0, to: Double(summary.healthScore) / 100)
                    .stroke(
                        LinearGradient(colors: [AppColors.purple, AppColors.lightPurple], startPoint: .top, endPoint: .bottom),
                        style: StrokeStyle(lineWidth: 5, lineCap: .round)
                    )
                    .frame(width: ringSize)
                    .rotationEffect(.degrees(-90))
                Text("\(summary.healthScore)")
                    .font(.system(size: 17, weight: .bold)).foregroundColor(.white)
            }

            VStack(spacing: 5) {
                row("📸 照片总数", "\(summary.totalCount) 张")
                row("💾 占用空间", summary.formattedTotal)
                row("🧹 可释放", summary.formattedFreeable, accent: true)
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
                .foregroundColor(accent ? AppColors.lightPurple : .white)
        }
    }
}

// MARK: - Space bar
struct SpaceBar: View {
    let summary: LibrarySummary
    private var total: Int64 { max(summary.totalBytes, 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("空间分布").font(.caption).fontWeight(.semibold)
                .foregroundColor(AppColors.textSecondary).textCase(.uppercase)

            GeometryReader { geo in
                HStack(spacing: 1) {
                    seg(summary.videoBytes,      color: AppColors.purple,  width: geo.size.width)
                    seg(summary.screenshotBytes, color: AppColors.red,     width: geo.size.width)
                    seg(summary.livePhotoBytes,  color: AppColors.amber,   width: geo.size.width)
                    seg(summary.photoBytes,      color: AppColors.green,   width: geo.size.width)
                    Rectangle().fill(Color.white.opacity(0.08)).cornerRadius(2)
                }
                .frame(height: 7)
                .cornerRadius(4)
            }
            .frame(height: 7)

            HStack(spacing: 0) {
                ForEach([
                    (AppColors.purple, "视频"),
                    (AppColors.red, "截图"),
                    (AppColors.amber, "Live"),
                    (AppColors.green, "照片")
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
                    Text(title).font(.subheadline).fontWeight(.semibold).foregroundColor(.white)
                    Text(desc).font(.caption).foregroundColor(AppColors.textSecondary)
                }
                Spacer()
                Text(size).font(.footnote).fontWeight(.bold).foregroundColor(AppColors.lightPurple)
                Image(systemName: "chevron.right").font(.caption).foregroundColor(AppColors.textTertiary)
            }
            .padding(12)
            .background(Color.white.opacity(0.04))
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppColors.subtleBorder, lineWidth: 0.5))
        }
        .padding(.horizontal)
    }
}
