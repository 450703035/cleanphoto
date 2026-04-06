import SwiftUI

// MARK: - Colors
enum AppColors {
    static let purple     = Color(hex: "7c6ff7")
    static let lightPurple = Color(hex: "a78bfa")
    static let darkBG     = Color(hex: "0f0f1a")
    static let cardBG     = Color(hex: "1a1730")
    static let deepCard   = Color(hex: "12122a")
    static let red        = Color(hex: "ef4444")
    static let green      = Color(hex: "22c55e")
    static let amber      = Color(hex: "f59e0b")
    static let blue       = Color(hex: "378add")
    static let selectionBlue = Color(hex: "0A84FF")
    static let textPrimary   = Color.white
    static let textSecondary = Color.white.opacity(0.55)
    static let textTertiary  = Color.white.opacity(0.35)
    static let separator     = Color.white.opacity(0.06)
    static let subtleBorder  = Color.white.opacity(0.08)
}

// MARK: - Score helpers
extension Int {
    var scoreColor: Color {
        switch self {
        case ..<40: return AppColors.red
        case 40..<70: return AppColors.amber
        default: return AppColors.green
        }
    }
    var scoreLabel: String {
        switch self {
        case ..<40: return "推荐删除"
        case 40..<70: return "可选保留"
        default: return "建议保留"
        }
    }
}

// MARK: - Color hex init
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Delete threshold
enum AppConfig {
    static var deleteThreshold: Int {
        get { UserDefaults.standard.object(forKey: "deleteThreshold") as? Int ?? 40 }
        set { UserDefaults.standard.set(newValue, forKey: "deleteThreshold") }
    }
    static var autoSelect: Bool {
        get { UserDefaults.standard.object(forKey: "autoSelect") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "autoSelect") }
    }
    static var timeWeight: Bool {
        get { UserDefaults.standard.object(forKey: "timeWeight") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "timeWeight") }
    }
    static var protectFaces: Bool {
        get { UserDefaults.standard.object(forKey: "protectFaces") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "protectFaces") }
    }
    static var screenshotGridColumns: Int {
        get {
            let v = UserDefaults.standard.object(forKey: "screenshotGridColumns") as? Int ?? 3
            return min(3, max(2, v))
        }
        set { UserDefaults.standard.set(min(3, max(2, newValue)), forKey: "screenshotGridColumns") }
    }
    static var lowQualityGridColumns: Int {
        get {
            let v = UserDefaults.standard.object(forKey: "lowQualityGridColumns") as? Int ?? 3
            return min(3, max(2, v))
        }
        set { UserDefaults.standard.set(min(3, max(2, newValue)), forKey: "lowQualityGridColumns") }
    }
}

// MARK: - Scoring and clustering config
enum ScoringConfig {
    // Base
    static let baseScore = 50
    static let minScore = 5
    static let maxScore = 99

    // Blur thresholds (Laplacian variance)
    static let blurSevereThreshold = 60.0
    static let blurSlightThreshold = 180.0
    static let blurSharpThreshold = 500.0

    // Exposure thresholds (luma 0...255)
    static let underExposureThreshold = 35.0
    static let overExposureThreshold = 215.0
    static let goodExposureLowerBound = 55.0
    static let goodExposureUpperBound = 200.0

    // Score weights
    static let favoriteBonus = 40
    static let multiFaceBonus = 28
    static let singleFaceBonus = 18
    static let petBonus = 10

    static let screenshotPenalty = 22
    static let panoramaBonus = 12
    static let livePhotoBonus = 6

    static let severeBlurPenalty = 30
    static let slightBlurPenalty = 10
    static let verySharpBonus = 12
    static let normalSharpnessBonus = 5

    static let badExposurePenalty = 18
    static let goodExposureBonus = 8

    static let shortVideoPenalty = 12
    static let maxAgePenalty = 12
    static let agePenaltyStartYears = 5
    static let agePenaltyPerYear = 2

    // Other score-related
    static let lowQualityThreshold = 35

    // Duplicate detection
    static let duplicateCandidateTimeBucketSeconds: TimeInterval = 8
    static let duplicateMaxFeatureDistance: Float = 0.06
    static let duplicateMaxHashDistance = 6
    static let duplicateMaxFileSizeDeltaBytes: Int64 = 64 * 1024
    static let hashThumbnailWidth: CGFloat = 9
    static let hashThumbnailHeight: CGFloat = 8

    // Similar detection
    static let similarCaptureGapSeconds: TimeInterval = 3
    static let similarMaxFeatureDistance: Float = 0.12
    static let similarMaxHashDistance = 14

    // Vision feature print input size
    static let featurePrintInputSize: CGFloat = 128
}
