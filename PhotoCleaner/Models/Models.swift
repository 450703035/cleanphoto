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
    case blurry  = "blurry"
    case shaky   = "shaky"
    case exposure = "exposure"
    case focusFail = "focusFail"

    var displayName: String {
        switch self {
        case .blurry: return L10n.reasonBlurry
        case .shaky: return L10n.reasonShaky
        case .exposure: return L10n.reasonExposure
        case .focusFail: return L10n.reasonFocusFail
        }
    }
}

// MARK: - Screenshot category (local Vision-based)
enum ScreenshotCategory: String, CaseIterable {
    case receipt = "receipt"
    case handwriting = "handwriting"
    case illustration = "illustration"
    case qrCode = "qrCode"
    case document = "document"
    case other = "other"

    var chipLabel: String {
        switch self {
        case .receipt: return L10n.catReceipt
        case .handwriting: return L10n.catHandwriting
        case .illustration: return L10n.catIllustration
        case .qrCode: return L10n.catQRCode
        case .document: return L10n.catDocument
        case .other: return L10n.catOther
        }
    }
}

// MARK: - Scan state
enum ScanPhase: String {
    case idle     = "idle"
    case scanning = "scanning"
    case done     = "done"

    var displayName: String {
        switch self {
        case .idle: return L10n.phaseIdle
        case .scanning: return L10n.phaseScanning
        case .done: return L10n.phaseDone
        }
    }
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
