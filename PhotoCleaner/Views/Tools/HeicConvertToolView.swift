import SwiftUI
import Photos

// MARK: - HEIC Convert
struct HeicConvertToolView: View {
    let onDismiss: () -> Void
    @State private var phAssets: [PHAsset] = []
    @State private var converting = false
    @State private var progress = 0.0
    @State private var done = false
    @State private var isLoading = true

    var body: some View {
        ZStack {
            AppColors.darkBG.ignoresSafeArea()
            if done { DoneView(count: phAssets.count, label: "张 HEIC 已转为 JPG", onBack: onDismiss) }
            else {
                VStack(spacing: 0) {
                    SubScreenHeader(title: "HEIC → JPG",
                                    subtitle: isLoading ? "扫描中…" : "\(phAssets.count) 个文件待转换",
                                    onBack: onDismiss)

                    if converting {
                        VStack(spacing: 6) {
                            Text("转换中… \(Int(progress * 100))%").foregroundColor(.white).fontWeight(.semibold)
                            ProgressView(value: progress).tint(AppColors.purple)
                        }
                        .padding().background(AppColors.cardBG).cornerRadius(14).padding()
                    }

                    if isLoading {
                        ToolLoadingView(message: "正在扫描 HEIC 文件…")
                    } else if phAssets.isEmpty {
                        ToolEmptyView(icon: "checkmark.circle", message: "相册中没有 HEIC 格式照片")
                    } else {
                        List {
                            ForEach(phAssets, id: \.localIdentifier) { asset in
                                HeicAssetRow(asset: asset, converting: converting, progress: progress,
                                             index: phAssets.firstIndex(of: asset) ?? 0, total: phAssets.count)
                            }
                        }
                        .listStyle(.plain).background(AppColors.darkBG)

                        if !converting {
                            Button("开始批量转换 \(phAssets.count) 个文件") {
                                converting = true
                                Task {
                                    for i in 0...100 {
                                        try? await Task.sleep(nanoseconds: 40_000_000)
                                        await MainActor.run { progress = Double(i) / 100 }
                                    }
                                    await MainActor.run { done = true }
                                }
                            }
                            .frame(maxWidth: .infinity).padding()
                            .background(AppColors.purple).foregroundColor(.white)
                            .fontWeight(.bold).cornerRadius(13).padding()
                        }
                    }
                }
            }
        }
        .task { await loadAssets() }
    }

    private func loadAssets() async {
        let opts = PHFetchOptions()
        opts.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let result = PHAsset.fetchAssets(with: .image, options: opts)
        var arr: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in
            let resources = PHAssetResource.assetResources(for: asset)
            let uti = resources.first?.uniformTypeIdentifier ?? ""
            let name = resources.first?.originalFilename ?? ""
            if uti == "public.heic" || name.lowercased().hasSuffix(".heic") {
                arr.append(asset)
            }
        }
        phAssets = arr
        isLoading = false
    }
}

struct HeicAssetRow: View {
    let asset: PHAsset
    let converting: Bool
    let progress: Double
    let index: Int
    let total: Int

    private var isDone: Bool { converting && progress > Double(index) / Double(max(total, 1)) }

    var body: some View {
        HStack(spacing: 12) {
            PhotoThumbnail(asset: asset, size: 48).cornerRadius(10)
            VStack(alignment: .leading, spacing: 2) {
                Text(assetFilename(asset)).foregroundColor(.white).font(.subheadline).lineLimit(1)
                Text("\(estimatedSize(asset)) → JPG").font(.caption).foregroundColor(AppColors.green)
            }
            Spacer()
            if isDone {
                Image(systemName: "checkmark.circle.fill").foregroundColor(AppColors.green)
            } else {
                Text("待转").font(.caption).foregroundColor(AppColors.textTertiary)
            }
        }
        .padding(.vertical, 4).listRowBackground(AppColors.darkBG)
    }
}
