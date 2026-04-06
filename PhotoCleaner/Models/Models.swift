import SwiftUI
import Photos

// MARK: - PhotoAsset  (wraps PHAsset + computed score)
struct PhotoAsset: Identifiable, Hashable {
    let id: String
    let asset: PHAsset
    var score: Int
    var isSelected: Bool
    var reason: LowQualityReason?
    var fileSizeBytes: Int64? = nil

    var sizeBytes: Int64 {
        if let real = fileSizeBytes, real > 0 { return real }
        // Fallback only when Photos metadata doesn't expose file size.
        return Int64(asset.pixelWidth * asset.pixelHeight * 4)
    }
    var formattedSize: String { ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file) }
    var creationDate: Date { asset.creationDate ?? Date() }
    var mediaType: PHAssetMediaType { asset.mediaType }
    var duration: TimeInterval { asset.duration }

    static func == (lhs: PhotoAsset, rhs: PhotoAsset) -> Bool { lhs.id == rhs.id && lhs.isSelected == rhs.isSelected }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - Similar / duplicate group
struct PhotoGroup: Identifiable {
    let id = UUID()
    var assets: [PhotoAsset]       // assets[0] = best (highest score)
    var groupType: GroupType
    var totalSize: Int64 { assets.reduce(0) { $0 + $1.sizeBytes } }

    enum GroupType { case duplicate, similar, portrait }
}

// MARK: - Album folder (timeline)
struct AlbumFolder: Identifiable {
    let id = UUID()
    var title: String
    var assets: [PhotoAsset]
    var date: Date
    var averageScore: Int { assets.isEmpty ? 0 : assets.reduce(0) { $0 + $1.score } / assets.count }
    var totalSize: Int64 { assets.reduce(0) { $0 + $1.sizeBytes } }
    var formattedSize: String { ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file) }
    var recommendDelete: Bool { averageScore < AppConfig.deleteThreshold }
}

// MARK: - Low quality reason
enum LowQualityReason: String, CaseIterable {
    case blurry  = "模糊"
    case shaky   = "抖动"
    case exposure = "过曝/过暗"
    case focusFail = "对焦失败"
}

// MARK: - Screenshot category (local Vision-based)
enum ScreenshotCategory: String, CaseIterable {
    case receipt = "收据"
    case handwriting = "手写"
    case illustration = "插图"
    case qrCode = "二维码"
    case document = "文稿"
    case other = "其他"

    var chipLabel: String { rawValue }
}

// MARK: - Scan state
enum ScanPhase: String {
    case idle     = "尚未扫描"
    case scanning = "分析中…"
    case done     = "扫描完成"
}

// MARK: - Library summary
struct LibrarySummary {
    var totalCount: Int = 0
    var totalBytes: Int64 = 0
    var freeableBytes: Int64 = 0
    var healthScore: Int = 0
    var videoBytes: Int64 = 0
    var screenshotBytes: Int64 = 0
    var livePhotoBytes: Int64 = 0
    var photoBytes: Int64 = 0

    var formattedTotal: String { ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file) }
    var formattedFreeable: String { ByteCountFormatter.string(fromByteCount: freeableBytes, countStyle: .file) }
}

// MARK: - Swipe action
enum SwipeDecision { case delete, keep }

struct SwipeHistoryItem {
    let asset: PhotoAsset
    let decision: SwipeDecision
}

// MARK: - Calendar day info
struct DayInfo: Identifiable {
    var id: String { "\(year)-\(month)-\(day)" }
    let year: Int
    let month: Int    // 0-based
    let day: Int
    var assets: [PhotoAsset]
    var count: Int { assets.count }
    var averageScore: Int { assets.isEmpty ? 0 : assets.reduce(0) { $0 + $1.score } / assets.count }
    var totalSize: Int64 { assets.reduce(0) { $0 + $1.sizeBytes } }
    var formattedSize: String { ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file) }
}
