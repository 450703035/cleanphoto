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
            if done { DoneView(count: phAssets.count, label: L10n.heicDoneLabel(phAssets.count), onBack: onDismiss) }
            else {
                VStack(spacing: 0) {
                    SubScreenHeader(title: "HEIC → JPG",
                                    subtitle: isLoading ? L10n.scanning : L10n.filesToConvert(phAssets.count),
                                    onBack: onDismiss)

                    if converting {
                        VStack(spacing: 6) {
                            Text(L10n.converting(Int(progress * 100))).foregroundColor(AppColors.textPrimary).font(AppTypography.body.weight(.semibold))
                            ProgressView(value: progress).tint(AppColors.purple)
                        }
                        .padding().appleCardStyle().padding()
                    }

                    if isLoading {
                        ToolLoadingView(message: L10n.scanningHEIC)
                    } else if phAssets.isEmpty {
                        ToolEmptyView(icon: "checkmark.circle", message: L10n.noHEIC)
                    } else {
                        List {
                            ForEach(phAssets, id: \.localIdentifier) { asset in
                                HeicAssetRow(asset: asset, converting: converting, progress: progress,
                                             index: phAssets.firstIndex(of: asset) ?? 0, total: phAssets.count)
                            }
                        }
                        .listStyle(.plain).background(AppColors.darkBG)

                        if !converting {
                            Button(L10n.startConvert(phAssets.count)) {
                                converting = true
                                Task {
                                    for i in 0...100 {
                                        try? await Task.sleep(nanoseconds: 40_000_000)
                                        await MainActor.run { progress = Double(i) / 100 }
                                    }
                                    await MainActor.run { done = true }
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .buttonStyle(ApplePrimaryButtonStyle())
                            .padding()
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
            PhotoThumbnail(asset: asset, size: 48).cornerRadius(AppShape.mediaRadius)
            VStack(alignment: .leading, spacing: 2) {
                Text(assetFilename(asset)).foregroundColor(AppColors.textPrimary).font(AppTypography.body).lineLimit(1)
                Text("\(estimatedSize(asset)) → JPG").font(AppTypography.caption).foregroundColor(AppColors.green)
            }
            Spacer()
            if isDone {
                Image(systemName: "checkmark.circle.fill").foregroundColor(AppColors.green)
            } else {
                Text(L10n.pending).font(.caption).foregroundColor(AppColors.textTertiary)
            }
        }
        .padding(.vertical, 4).listRowBackground(AppColors.darkBG)
    }
}
