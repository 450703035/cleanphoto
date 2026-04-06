import SwiftUI
import Photos
import CoreLocation
import AVKit
import UIKit

// MARK: - Location label (async reverse geocode)
private struct LocationLabel: View {
    let asset: PHAsset
    @State private var text: String = ""

    var body: some View {
        Text(text.isEmpty ? "定位中…" : text)
            .task(id: asset.localIdentifier) { await geocode() }
    }

    private func geocode() async {
        guard let loc = asset.location else { text = "无位置信息"; return }
        let geocoder = CLGeocoder()
        if let marks = try? await geocoder.reverseGeocodeLocation(loc), let p = marks.first {
            let parts = [p.locality ?? p.administrativeArea, p.country].compactMap { $0 }
            text = parts.isEmpty ? "位置未知" : parts.joined(separator: ", ")
        } else {
            text = "位置未知"
        }
    }
}

// MARK: - Swipe Delete Tool
struct SwipeDeleteToolView: View {
    let onDismiss: () -> Void

    @State private var allAssets: [PhotoAsset] = []
    @State private var queue: [PhotoAsset] = []
    @State private var history: [(photo: PhotoAsset, action: SwipeDecision)] = []
    @State private var deletedCount = 0
    @State private var keptCount = 0
    @State private var drag: CGSize = .zero
    @State private var isDragging = false
    @State private var thresholdCrossed = false
    @State private var lastAction: SwipeDecision? = nil
    @State private var isLoading = true
    @State private var hasPromptedForDelete = false
    @State private var showDeleteAlert = false
    @State private var pendingDeletePhoto: PhotoAsset? = nil
    @State private var inlinePlayer: AVPlayer? = nil
    @State private var activeVideoId: String? = nil
    @State private var infoSheetPhoto: PhotoAsset? = nil

    @Environment(\.dismiss) private var envDismiss

    private let service = PhotoLibraryService.shared
    let THRESHOLD: CGFloat = 90
    var current: PhotoAsset? { queue.first }
    var nextCard: PhotoAsset? { queue.count > 1 ? queue[1] : nil }
    var total: Int { allAssets.count }
    var currentIndex: Int { total - queue.count + (queue.isEmpty ? 0 : 1) }

    var body: some View {
        ZStack {
            AppColors.darkBG.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Button {
                        envDismiss()
                        onDismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("返回")
                        }
                        .foregroundColor(AppColors.purple)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    if !queue.isEmpty {
                        Text("\(currentIndex) / \(total)")
                            .font(.title3).bold().foregroundColor(.white)
                    }
                    Spacer()
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "trash")
                            .font(.system(size: 20))
                            .foregroundColor(deletedCount > 0 ? AppColors.red : AppColors.textTertiary)
                            .frame(width: 36, height: 36)
                        if deletedCount > 0 {
                            Text("\(deletedCount)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 5).padding(.vertical, 2)
                                .background(AppColors.red)
                                .clipShape(Capsule())
                                .offset(x: 10, y: -6)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 4)

                if isLoading {
                    Spacer()
                    ToolLoadingView(message: "加载照片…")
                    Spacer()
                } else if queue.isEmpty && total == 0 {
                    Spacer()
                    ToolEmptyView(icon: "photo", message: "相册中没有照片")
                    Spacer()
                } else if queue.isEmpty {
                    allDoneView
                } else {
                    ZStack {
                        if let nxt = nextCard {
                            let dragProgress = min(abs(drag.width) / THRESHOLD, 1)
                            realCardView(nxt, isBack: true)
                                .id("back-\(nxt.id)")
                                .scaleEffect(0.93 + 0.07 * dragProgress)
                                .offset(y: 18 - 18 * dragProgress)
                                .animation(.spring(response: 0.4), value: queue.count)
                                .animation(.interactiveSpring(), value: drag.width)
                        }
                        if let cur = current {
                            realCardView(cur, isBack: false)
                                .id(cur.id)
                                .offset(drag)
                                .rotationEffect(.degrees(Double(drag.width) * 0.05))
                                .gesture(dragGesture)
                                .animation(isDragging ? nil : .spring(response: 0.35), value: drag)
                        }
                    }
                    .padding(.horizontal, 16)
                    .frame(maxHeight: .infinity)

                    bottomButtons
                }
            }
        }
        .task { await loadAssets() }
        .sheet(item: $infoSheetPhoto) { photo in
            PhotoInfoSheet(photo: photo)
        }
        .alert("允许删除照片", isPresented: $showDeleteAlert, presenting: pendingDeletePhoto) { photo in
            Button("允许删除", role: .destructive) {
                hasPromptedForDelete = true
                commitDelete(photo)
            }
            Button("取消", role: .cancel) {
                pendingDeletePhoto = nil
                withAnimation(.spring()) { drag = .zero }
            }
        } message: { _ in
            Text("相册管家将把选中的照片移入废纸篓，您随时可以在「最近删除」相册中恢复。")
        }
    }

    var allDoneView: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("✅").font(.system(size: 64))
            Text("全部完成！").font(.title2).bold().foregroundColor(.white)
            HStack(spacing: 32) {
                VStack(spacing: 4) {
                    Text("\(deletedCount)").font(.largeTitle).bold().foregroundColor(AppColors.red)
                    Text("已删除").font(.caption).foregroundColor(AppColors.textSecondary)
                }
                VStack(spacing: 4) {
                    Text("\(keptCount)").font(.largeTitle).bold().foregroundColor(AppColors.green)
                    Text("已保留").font(.caption).foregroundColor(AppColors.textSecondary)
                }
            }
            Button("返回", action: onDismiss)
                .buttonStyle(.borderedProminent).tint(AppColors.purple).padding(.top, 8)
            Spacer()
        }
    }

    var dragGesture: some Gesture {
        DragGesture()
            .onChanged { v in
                isDragging = true
                drag = v.translation
                let crossed = abs(v.translation.width) > THRESHOLD
                if crossed != thresholdCrossed {
                    thresholdCrossed = crossed
                    if crossed { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
                }
            }
            .onEnded { v in
                isDragging = false
                thresholdCrossed = false
                let dx = v.translation.width
                if dx < -THRESHOLD {
                    doAction(.delete)
                } else if dx > THRESHOLD {
                    doAction(.keep)
                } else {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { drag = .zero }
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                }
            }
    }

    var bottomButtons: some View {
        VStack(spacing: 6) {
            HStack(alignment: .center, spacing: 32) {
                circleBtn(icon: "xmark", size: 64, color: AppColors.red) { doAction(.delete) }
                Button(action: undoLast) {
                    Image(systemName: "arrow.uturn.backward").font(.system(size: 18))
                        .foregroundColor(history.isEmpty ? AppColors.textTertiary : .white.opacity(0.7))
                        .frame(width: 44, height: 44)
                        .background(Color.white.opacity(history.isEmpty ? 0.03 : 0.08))
                        .clipShape(Circle())
                }
                .disabled(history.isEmpty)
                circleBtn(icon: "heart.fill", size: 64, color: AppColors.green) { doAction(.keep) }
            }
            HStack {
                Text("← 删除").font(.caption).fontWeight(.semibold).foregroundColor(AppColors.red)
                Spacer()
                Text("点击 ↩ 撤销").font(.caption).foregroundColor(AppColors.textTertiary)
                Spacer()
                Text("保留 →").font(.caption).fontWeight(.semibold).foregroundColor(AppColors.green)
            }
            .padding(.horizontal, 30)
            if let last = lastAction {
                Text(last == .delete ? "已标记删除 · 点击 ↩ 可撤销" : "已标记保留 · 点击 ↩ 可撤销")
                    .font(.caption).foregroundColor(last == .delete ? AppColors.red : AppColors.green)
            }
        }
        .padding(.horizontal).padding(.bottom, 16)
    }

    func circleBtn(icon: String, size: CGFloat, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: size == 64 ? 26 : 18, weight: .bold))
                .foregroundColor(color).frame(width: size, height: size)
                .background(color.opacity(0.15)).clipShape(Circle())
                .overlay(Circle().stroke(color, lineWidth: 2))
        }
    }

    @ViewBuilder
    func realCardView(_ photo: PhotoAsset, isBack: Bool) -> some View {
        let photoW = UIScreen.main.bounds.width - 32
        let pixW = max(1, CGFloat(photo.asset.pixelWidth))
        let pixH = max(1, CGFloat(photo.asset.pixelHeight))
        let ratio = pixH / pixW
        let photoH = min(max(photoW * ratio, photoW * 0.5), photoW * 1.4)
        let isVideo = photo.asset.mediaType == .video

        VStack(spacing: 0) {
            ZStack {
                Color.black

                if isVideo && activeVideoId == photo.id, let player = inlinePlayer {
                    VideoPlayer(player: player)
                } else {
                    PhotoThumbnail(asset: photo.asset, size: photoW, height: photoH, contentMode: .fit)

                    if isVideo {
                        Color.black.opacity(0.25)
                        Image(systemName: "play.fill")
                            .font(.system(size: 52))
                            .foregroundColor(.white.opacity(0.9))
                            .shadow(color: .black.opacity(0.5), radius: 8)
                    }
                }

                if !isBack && activeVideoId != photo.id {
                    if drag.width < -20 {
                        Color.red.opacity(min(0.35, Double(-drag.width) / 300))
                        swipeStamp("删除", color: AppColors.red, rotation: -15)
                    }
                    if drag.width > 20 {
                        Color.green.opacity(min(0.35, Double(drag.width) / 300))
                        swipeStamp("保留", color: AppColors.green, rotation: 15)
                    }
                }

                if !isBack && activeVideoId != photo.id {
                    VStack {
                        HStack {
                            if photo.asset.isFavorite {
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 13))
                                    .foregroundColor(.white)
                                    .padding(6)
                                    .background(Color.pink.opacity(0.85))
                                    .clipShape(Circle())
                            }
                            Spacer()
                            ScoreBadge(score: photo.score, fontSize: 12)
                        }
                        Spacer()
                        if isVideo {
                            HStack {
                                Spacer()
                                Text(durationString(photo.asset.duration))
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 7).padding(.vertical, 3)
                                    .background(Color.black.opacity(0.6))
                                    .cornerRadius(6)
                            }
                        }
                    }
                    .padding(12)
                }
            }
            .frame(width: photoW, height: photoH)
            .clipped()
            .onTapGesture {
                guard isVideo && !isBack else { return }
                if activeVideoId == photo.id {
                    if let p = inlinePlayer { p.rate > 0 ? p.pause() : p.play() }
                } else {
                    activeVideoId = photo.id
                    inlinePlayer = nil
                    Task { await loadInlinePlayer(asset: photo.asset) }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(formattedDate(photo.creationDate))
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)

                HStack(spacing: 5) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 11))
                        .foregroundColor(AppColors.textSecondary)
                    if photo.asset.location != nil {
                        LocationLabel(asset: photo.asset)
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.textSecondary)
                            .lineLimit(1)
                    } else {
                        Text("无位置信息")
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.textTertiary)
                    }
                }

                HStack(alignment: .center) {
                    HStack(spacing: 5) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11))
                            .foregroundColor(AppColors.textSecondary)
                        Text(mediaCategory(photo.asset))
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.textSecondary)
                    }
                    Text("·")
                        .foregroundColor(AppColors.textTertiary)
                        .font(.system(size: 12))
                    Text(estimatedSizeStr(photo.asset))
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textSecondary)
                    Spacer()
                    Button {
                        infoSheetPhoto = photo
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.system(size: 20))
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(AppColors.cardBG)
        }
        .frame(width: photoW)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.white.opacity(0.08), lineWidth: 0.5))
    }

    private func durationString(_ seconds: TimeInterval) -> String {
        let s = Int(seconds)
        return s >= 3600
            ? String(format: "%d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
            : String(format: "%d:%02d", s / 60, s % 60)
    }

    private func estimatedSizeStr(_ asset: PHAsset) -> String {
        let resources = PHAssetResource.assetResources(for: asset)
        for r in resources {
            if let bytes = (r.value(forKey: "fileSize") as? NSNumber)?.int64Value, bytes > 0 {
                return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
            }
        }
        let estimate: Int64
        if asset.mediaType == .video {
            estimate = Int64(asset.duration) * 4_000_000 / 8
        } else {
            estimate = Int64(asset.pixelWidth * asset.pixelHeight * 3) / 10
        }
        return ByteCountFormatter.string(fromByteCount: max(estimate, 0), countStyle: .file)
    }

    func swipeStamp(_ text: String, color: Color, rotation: Double) -> some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Text(text).font(.largeTitle).bold().foregroundColor(color)
                    .padding(10)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(color, lineWidth: 4))
                    .rotationEffect(.degrees(rotation))
                Spacer()
            }
            Spacer()
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy.MM.dd"
        return df.string(from: date)
    }

    private func mediaCategory(_ asset: PHAsset) -> String {
        let sub = asset.mediaSubtypes
        if sub.contains(.photoScreenshot) { return "截图" }
        if sub.contains(.photoLive) { return "实况照片" }
        if sub.contains(.photoPanorama) { return "全景照片" }
        if sub.contains(.photoHDR) { return "HDR 照片" }
        if asset.mediaType == .video {
            if sub.contains(.videoTimelapse) { return "延时摄影" }
            if sub.contains(.videoHighFrameRate) { return "慢动作视频" }
            return "视频"
        }
        return "普通照片"
    }

    private func loadAssets() async {
        let raw = await PhotoLibraryService.shared.fetchAllAssets()
        let limited = Array(raw.prefix(100))
        allAssets = limited
        queue = limited
        isLoading = false
    }

    func doAction(_ action: SwipeDecision) {
        guard let photo = queue.first else { return }

        if action == .delete && !hasPromptedForDelete {
            pendingDeletePhoto = photo
            showDeleteAlert = true
            return
        }

        if action == .delete {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } else {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }

        inlinePlayer?.pause()
        inlinePlayer = nil
        activeVideoId = nil

        withAnimation(.easeIn(duration: 0.25)) {
            drag = CGSize(width: action == .delete ? -500 : 500, height: 0)
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(280))
            history.append((photo, action))
            queue.removeFirst()
            if action == .delete {
                deletedCount += 1
                Task { try? await PhotoStore.shared.deleteAssets([photo]) }
            } else {
                keptCount += 1
            }
            drag = .zero
            lastAction = action
        }
    }

    private func commitDelete(_ photo: PhotoAsset) {
        pendingDeletePhoto = nil
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        inlinePlayer?.pause()
        inlinePlayer = nil
        activeVideoId = nil
        withAnimation(.easeIn(duration: 0.25)) {
            drag = CGSize(width: -500, height: 0)
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(280))
            history.append((photo, .delete))
            queue.removeFirst()
            deletedCount += 1
            Task { try? await service.deleteAssets([photo]) }
            drag = .zero
            lastAction = .delete
        }
    }

    func undoLast() {
        guard let last = history.last else { return }
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        inlinePlayer?.pause()
        inlinePlayer = nil
        activeVideoId = nil
        history.removeLast()
        queue.insert(last.photo, at: 0)
        last.action == .delete ? (deletedCount -= 1) : (keptCount -= 1)
        lastAction = nil
    }

    private func loadInlinePlayer(asset: PHAsset) async {
        let opts = PHVideoRequestOptions()
        opts.deliveryMode = .automatic
        opts.isNetworkAccessAllowed = true
        let avAsset: AVAsset? = await withCheckedContinuation { cont in
            PHImageManager.default().requestAVAsset(forVideo: asset, options: opts) { a, _, _ in
                cont.resume(returning: a)
            }
        }
        guard let avAsset else { return }
        let item = AVPlayerItem(asset: avAsset)
        inlinePlayer = AVPlayer(playerItem: item)
        inlinePlayer?.play()
    }
}

// MARK: - Photo / Video Info Sheet
struct PhotoInfoSheet: View {
    let photo: PhotoAsset
    @Environment(\.dismiss) private var dismiss
    @State private var locationText: String = "加载中…"
    @State private var fileType: String = ""
    @State private var fileSize: String = ""

    private var asset: PHAsset { photo.asset }

    var body: some View {
        NavigationView {
            List {
                Section {
                    HStack {
                        Spacer()
                        PhotoThumbnail(asset: asset, size: 200)
                            .frame(width: 200, height: 200)
                            .clipped()
                            .cornerRadius(12)
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                    .padding(.vertical, 8)
                }

                Section("日期与时间") {
                    infoRow(icon: "calendar", label: "日期", value: formatted(photo.creationDate, style: .long))
                    infoRow(icon: "clock", label: "时间", value: formatted(photo.creationDate, timeStyle: .medium))
                }

                Section("位置") {
                    infoRow(icon: "mappin.and.ellipse", label: "地点", value: locationText)
                }

                Section("文件信息") {
                    infoRow(icon: "doc", label: "文件名", value: filename())
                    infoRow(icon: "aspectratio", label: "分辨率", value: "\(asset.pixelWidth) × \(asset.pixelHeight)")
                    if !fileSize.isEmpty {
                        infoRow(icon: "internaldrive", label: "大小", value: fileSize)
                    }
                    if !fileType.isEmpty {
                        infoRow(icon: "photo", label: "格式", value: fileType)
                    }
                    if asset.mediaType == .video {
                        infoRow(icon: "video", label: "时长", value: durationStr(asset.duration))
                    }
                }

                Section("属性") {
                    infoRow(icon: "star.fill", label: "AI 评分", value: "\(photo.score)  \(photo.score.scoreLabel)")
                    if asset.isFavorite {
                        infoRow(icon: "heart.fill", label: "收藏", value: "已收藏")
                    }
                    infoRow(icon: "sparkles", label: "类型", value: mediaCategory(asset))
                }
            }
            .navigationTitle("照片信息")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .task { await loadInfo() }
    }

    @ViewBuilder
    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundColor(AppColors.purple)
            Text(label)
                .foregroundColor(.primary)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
        }
    }

    private func loadInfo() async {
        if let loc = asset.location {
            let geocoder = CLGeocoder()
            if let marks = try? await geocoder.reverseGeocodeLocation(loc), let p = marks.first {
                let parts = [p.locality ?? p.administrativeArea, p.country].compactMap { $0 }
                locationText = parts.isEmpty ? "位置未知" : parts.joined(separator: ", ")
            } else {
                locationText = "位置未知"
            }
        } else {
            locationText = "无位置信息"
        }

        let resources = PHAssetResource.assetResources(for: asset)
        if let r = resources.first {
            fileType = utiFriendlyName(r.uniformTypeIdentifier)
            if let bytes = (r.value(forKey: "fileSize") as? NSNumber)?.int64Value, bytes > 0 {
                fileSize = ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
            }
        }

        if fileSize.isEmpty {
            let est: Int64 = asset.mediaType == .video
                ? Int64(asset.duration) * 4_000_000 / 8
                : Int64(asset.pixelWidth * asset.pixelHeight * 3) / 10
            fileSize = ByteCountFormatter.string(fromByteCount: max(est, 0), countStyle: .file)
        }
    }

    private func filename() -> String {
        PHAssetResource.assetResources(for: asset).first?.originalFilename ?? "未知"
    }

    private func formatted(_ date: Date, style: DateFormatter.Style = .none, timeStyle: DateFormatter.Style = .none) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "zh_CN")
        df.dateStyle = style
        df.timeStyle = timeStyle
        return df.string(from: date)
    }

    private func durationStr(_ s: TimeInterval) -> String {
        let t = Int(s)
        return t >= 3600
            ? String(format: "%d:%02d:%02d", t / 3600, (t % 3600) / 60, t % 60)
            : String(format: "%d:%02d", t / 60, t % 60)
    }

    private func utiFriendlyName(_ uti: String) -> String {
        let map: [String: String] = [
            "public.heic": "HEIC", "public.heif": "HEIF",
            "public.jpeg": "JPEG", "public.png": "PNG",
            "public.tiff": "TIFF", "com.apple.quicktime-movie": "MOV",
            "public.mpeg-4": "MP4", "public.mpeg-4-video": "MP4",
        ]
        return map[uti] ?? uti.components(separatedBy: ".").last?.uppercased() ?? "未知"
    }

    private func mediaCategory(_ asset: PHAsset) -> String {
        let sub = asset.mediaSubtypes
        if sub.contains(.photoScreenshot) { return "截图" }
        if sub.contains(.photoLive) { return "实况照片" }
        if sub.contains(.photoPanorama) { return "全景照片" }
        if sub.contains(.photoHDR) { return "HDR 照片" }
        if asset.mediaType == .video {
            if sub.contains(.videoTimelapse) { return "延时摄影" }
            if sub.contains(.videoHighFrameRate) { return "慢动作视频" }
            return "视频"
        }
        return "普通照片"
    }
}
