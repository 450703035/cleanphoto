import SwiftUI
import Photos

// MARK: - Shared row check circle
func rowCheck(_ on: Bool, _ color: Color = AppColors.selectionBlue) -> some View {
    ZStack {
        Circle()
            .stroke(AppColors.textPrimary.opacity(0.9), lineWidth: 1.8)
        if on {
            Circle()
                .fill(color)
                .padding(3)
            Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
        }
    }
    .frame(width: 24, height: 24)
}

// MARK: - Helper: asset filename via PHAssetResource
func assetFilename(_ asset: PHAsset) -> String {
    PHAssetResource.assetResources(for: asset).first?.originalFilename ?? "照片"
}

// MARK: - Helper: estimated size string
func estimatedSize(_ asset: PHAsset) -> String {
    let bytes = Int64(asset.pixelWidth * asset.pixelHeight * 4)
    return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
}

// MARK: - Empty state view
struct ToolEmptyView: View {
    let icon: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: icon).font(.system(size: 44)).foregroundColor(AppColors.textTertiary)
            Text(message).foregroundColor(AppColors.textSecondary).multilineTextAlignment(.center)
            Spacer()
        }
        .padding(.horizontal, 40)
    }
}

// MARK: - Loading view
struct ToolLoadingView: View {
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            ProgressView().tint(AppColors.purple)
            Text(message).font(.caption).foregroundColor(AppColors.textSecondary)
            Spacer()
        }
    }
}
