import SwiftUI
import Photos
import CoreImage

// MARK: - Blur Detect
struct BlurDetectToolView: View {
    let onDismiss: () -> Void
    @State private var allPhAssets: [PHAsset] = []
    @State private var blurScores: [String: Int] = [:]
    @State private var selected: Set<String> = []
    @State private var done = false
    @State private var isScanning = true
    @State private var scanProgress: Double = 0

    private var blurryAssets: [(asset: PHAsset, score: Int)] {
        allPhAssets
            .compactMap { a -> (PHAsset, Int)? in
                guard let s = blurScores[a.localIdentifier], s < 40 else { return nil }
                return (a, s)
            }
            .sorted { $0.1 < $1.1 }
    }

    let cols = [GridItem(.flexible(), spacing: 3), GridItem(.flexible(), spacing: 3), GridItem(.flexible(), spacing: 3)]

    var body: some View {
        ZStack(alignment: .bottom) {
            AppColors.darkBG.ignoresSafeArea()
            if done { DoneView(count: selected.count, label: L10n.blurDone(selected.count), onBack: onDismiss) }
            else {
                VStack(spacing: 0) {
                    SubScreenHeader(
                        title: L10n.blurDetect,
                        subtitle: isScanning ? L10n.blurScanning(blurScores.count, allPhAssets.count) : L10n.blurFound(blurryAssets.count),
                        onBack: onDismiss
                    )

                    if isScanning {
                        VStack(spacing: 12) {
                            Spacer()
                            ProgressView(value: scanProgress).tint(AppColors.green).padding(.horizontal, 40)
                            Text(L10n.analyzingClarity).font(AppTypography.caption).foregroundColor(AppColors.textSecondary)
                            if !blurryAssets.isEmpty {
                                Text(L10n.foundBlurry(blurryAssets.count)).font(AppTypography.caption).foregroundColor(AppColors.green)
                            }
                            Spacer()
                        }
                    } else if blurryAssets.isEmpty {
                        ToolEmptyView(icon: "checkmark.circle", message: L10n.noBlurry)
                    } else {
                        ScrollView {
                            LazyVGrid(columns: cols, spacing: 3) {
                                ForEach(blurryAssets, id: \.asset.localIdentifier) { item in
                                    BlurPhotoCell(
                                        asset: item.asset, score: item.score,
                                        isSelected: selected.contains(item.asset.localIdentifier)
                                    ) {
                                        if selected.contains(item.asset.localIdentifier) { selected.remove(item.asset.localIdentifier) }
                                        else { selected.insert(item.asset.localIdentifier) }
                                    }
                                }
                            }
                            .padding(3).padding(.bottom, 80)
                        }
                    }
                }

                if !selected.isEmpty {
                    BottomDeleteBar(count: selected.count, sizeLabel: "") {
                        Task {
                            let toDelete = blurryAssets
                                .filter { selected.contains($0.asset.localIdentifier) }
                                .map { PhotoAsset(id: $0.asset.localIdentifier, asset: $0.asset, score: $0.score, isSelected: true) }
                            do {
                                try await PhotoStore.shared.deleteAssets(toDelete)
                                done = true
                            } catch {
                            }
                        }
                    }
                }
            }
        }
        .task { await loadAndScore() }
    }

    private func loadAndScore() async {
        // Fetch recent 300 photos for blur analysis
        let opts = PHFetchOptions()
        opts.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        opts.fetchLimit = 300
        let result = PHAsset.fetchAssets(with: .image, options: opts)
        var arr: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in arr.append(asset) }
        allPhAssets = arr

        let total = max(arr.count, 1)
        var nextIdx = 0
        let maxConcurrent = 6

        await withTaskGroup(of: (String, Int).self) { group in
            while nextIdx < min(maxConcurrent, total) {
                let asset = arr[nextIdx]
                group.addTask { await (asset.localIdentifier, blurScore(for: asset)) }
                nextIdx += 1
            }

            for await (id, score) in group {
                if Task.isCancelled { return }
                blurScores[id] = score
                if score < 40 { selected.insert(id) }
                scanProgress = Double(blurScores.count) / Double(total)

                if nextIdx < total {
                    let asset = arr[nextIdx]
                    group.addTask { await (asset.localIdentifier, blurScore(for: asset)) }
                    nextIdx += 1
                }
            }
        }

        isScanning = false
    }

    private func blurScore(for asset: PHAsset) async -> Int {
        await withCheckedContinuation { cont in
            let opts = PHImageRequestOptions()
            opts.deliveryMode = .fastFormat
            opts.isSynchronous = false
            opts.resizeMode = .fast
            PHImageManager.default().requestImage(
                for: asset, targetSize: CGSize(width: 256, height: 256),
                contentMode: .aspectFit, options: opts
            ) { image, _ in
                guard let img = image, let cg = img.cgImage else { cont.resume(returning: 50); return }
                let variance = Self.laplacianVariance(cg)
                // Map variance to 0-99; low variance = blurry
                let score = max(0, min(99, Int(variance / 2.0)))
                cont.resume(returning: score)
            }
        }
    }

    private static func laplacianVariance(_ cgImage: CGImage) -> Double {
        let ci = CIImage(cgImage: cgImage)
        guard let filter = CIFilter(name: "CILaplacian") else { return 100 }
        filter.setValue(ci, forKey: kCIInputImageKey)
        guard let out = filter.outputImage else { return 100 }
        let ctx = CIContext()
        guard let bm = ctx.createCGImage(out, from: out.extent),
              let data = bm.dataProvider?.data,
              let ptr = CFDataGetBytePtr(data) else { return 100 }
        let count = bm.width * bm.height
        guard count > 0 else { return 100 }
        var sum: Double = 0, sumSq: Double = 0
        for i in 0..<count {
            let v = Double(ptr[i * 4])
            sum += v; sumSq += v * v
        }
        let mean = sum / Double(count)
        return (sumSq / Double(count)) - (mean * mean)
    }
}

struct BlurPhotoCell: View {
    let asset: PHAsset
    let score: Int
    let isSelected: Bool
    let onTap: () -> Void

    private var blurLabel: String {
        if score < 10 { return L10n.severeBlur }
        if score < 25 { return L10n.blurry }
        return L10n.slightBlur
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            PhotoThumbnail(asset: asset, size: 110)
                .frame(maxWidth: .infinity).aspectRatio(1, contentMode: .fill)
                .clipped().cornerRadius(AppShape.mediaRadius)
            ScoreBadge(score: score).padding(3)
            Text(blurLabel).font(.system(size: 8, weight: .bold)).foregroundColor(AppColors.red)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom).padding(.bottom, 4)
            if isSelected {
                RoundedRectangle(cornerRadius: AppShape.mediaRadius).stroke(AppColors.selectionBlue, lineWidth: 2)
                Image(systemName: "checkmark").font(.system(size: 8)).foregroundColor(.white)
                    .frame(width: 16, height: 16).background(AppColors.selectionBlue).clipShape(Circle())
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).padding(4)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .onTapGesture(perform: onTap)
    }
}
