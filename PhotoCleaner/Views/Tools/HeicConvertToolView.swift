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
    @State private var statusMessage: String = ""

    var body: some View {
        ZStack {
            AppColors.darkBG.ignoresSafeArea()
            if done { DoneView(count: phAssets.count, label: L10n.heicDoneLabel(phAssets.count), onBack: onDismiss) }
            else {
                VStack(spacing: 0) {
                    SubScreenHeader(title: "HEIC → JPG",
                                    subtitle: isLoading ? L10n.scanning : (statusMessage.isEmpty ? L10n.filesToConvert(phAssets.count) : statusMessage),
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
                        ToolEmptyView(icon: "checkmark.circle", message: statusMessage.isEmpty ? L10n.noHEIC : statusMessage)
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
        let authStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if authStatus == .notDetermined {
            let updated = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            guard updated == .authorized || updated == .limited else {
                await MainActor.run {
                    phAssets = []
                    statusMessage = L10n.photoPermissionRequired
                    isLoading = false
                }
                return
            }
        } else if authStatus != .authorized && authStatus != .limited {
            await MainActor.run {
                phAssets = []
                statusMessage = L10n.photoPermissionRequired
                isLoading = false
            }
            return
        }

        let arr = await Task.detached(priority: .userInitiated) { () -> [PHAsset] in
            var matches: [PHAsset] = []
            let opts = PHFetchOptions()
            opts.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            let result = PHAsset.fetchAssets(with: .image, options: opts)
            result.enumerateObjects { asset, _, _ in
                autoreleasepool {
                    let resources = PHAssetResource.assetResources(for: asset)
                    if Self.isHEICLikeAsset(resources) {
                        matches.append(asset)
                    }
                }
            }
            return matches
        }.value

        await MainActor.run {
            phAssets = arr
            statusMessage = ""
            isLoading = false
        }
    }

    private static func isHEICLikeAsset(_ resources: [PHAssetResource]) -> Bool {
        for resource in resources {
            let uti = resource.uniformTypeIdentifier.lowercased()
            let name = resource.originalFilename.lowercased()
            if uti == "public.heic" || uti == "public.heif" || uti.contains("heic") || uti.contains("heif") {
                return true
            }
            if name.hasSuffix(".heic") || name.hasSuffix(".heif") {
                return true
            }
        }
        return false
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
