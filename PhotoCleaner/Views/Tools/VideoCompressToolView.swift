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
            if done { DoneView(count: selected.count, label: "个视频已压缩", onBack: onDismiss) }
            else {
                VStack(spacing: 0) {
                    SubScreenHeader(title: "视频压缩", subtitle: "智能压缩，画质损失最小", onBack: onDismiss)

                    VStack(spacing: 8) {
                        Text("压缩质量").font(.caption).foregroundColor(AppColors.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Slider(value: $quality, in: 0.3...0.95).tint(AppColors.purple)
                        HStack {
                            Text("高压缩率").font(.caption).foregroundColor(AppColors.textSecondary)
                            Spacer()
                            Text("\(Int(quality * 100))% 质量").font(.subheadline).fontWeight(.bold).foregroundColor(AppColors.lightPurple)
                            Spacer()
                            Text("高画质").font(.caption).foregroundColor(AppColors.textSecondary)
                        }
                        if savedBytes > 0 {
                            Text("预计节省 \(ByteCountFormatter.string(fromByteCount: savedBytes, countStyle: .file))")
                                .font(.subheadline).foregroundColor(AppColors.green)
                        }
                    }
                    .padding().background(AppColors.cardBG).cornerRadius(14).padding()

                    if isLoading {
                        ToolLoadingView(message: "正在加载视频…")
                    } else if phAssets.isEmpty {
                        ToolEmptyView(icon: "video.slash", message: "相册中没有视频文件")
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
                        actionLabel: "压缩所选",
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
                PhotoThumbnail(asset: asset, size: 52).cornerRadius(10)
                Text(durationStr).font(.system(size: 8, weight: .bold)).foregroundColor(.white)
                    .padding(.horizontal, 3).padding(.vertical, 1)
                    .background(Color.black.opacity(0.7)).cornerRadius(3).padding(3)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(assetFilename(asset)).foregroundColor(.white).font(.subheadline).fontWeight(.semibold).lineLimit(1)
                Text("\(ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)) → \(ByteCountFormatter.string(fromByteCount: Int64(Double(sizeBytes) * quality * 0.8), countStyle: .file))")
                    .font(.caption).foregroundColor(AppColors.textSecondary)
            }
            Spacer()
            rowCheck(isSelected)
        }
        .padding(.vertical, 4).listRowBackground(AppColors.darkBG)
        .onTapGesture(perform: onTap)
    }
}
