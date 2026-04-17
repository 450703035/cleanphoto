import SwiftUI
import UIKit

enum AppThemeMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return L10n.themeSystem
        case .light: return L10n.themeLight
        case .dark: return L10n.themeDark
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

// MARK: - Colors
enum AppColors {
    static let purple     = Color(hex: "0071e3")
    static let lightPurple = Color(hex: "2997ff")
    static let darkBG     = Color(lightHex: "f5f5f7", darkHex: "000000")
    static let cardBG     = Color(lightHex: "ffffff", darkHex: "1d1d1f")
    static let deepCard   = Color(lightHex: "ffffff", darkHex: "272729")
    static let red        = Color(hex: "ef4444")
    static let green      = Color(hex: "22c55e")
    static let amber      = Color(hex: "f59e0b")
    static let blue       = Color(hex: "0066cc")
    static let selectionBlue = Color(hex: "0A84FF")
    static let textPrimary   = Color(lightHex: "1d1d1f", darkHex: "ffffff")
    static let textSecondary = Color(lightHex: "3c3c43", darkHex: "ffffff", lightAlpha: 0.78, darkAlpha: 0.74)
    static let textTertiary  = Color(lightHex: "3c3c43", darkHex: "ffffff", lightAlpha: 0.52, darkAlpha: 0.52)
    static let separator     = Color(lightHex: "000000", darkHex: "ffffff", lightAlpha: 0.10, darkAlpha: 0.12)
    static let subtleBorder  = Color(lightHex: "000000", darkHex: "ffffff", lightAlpha: 0.14, darkAlpha: 0.18)

    static let lightSectionBG = Color(hex: "f5f5f7")
    static let lightTextPrimary = Color(hex: "1d1d1f")
    static let lightTextSecondary = Color.black.opacity(0.8)
    static let chipBG = Color(lightHex: "ffffff", darkHex: "ffffff", lightAlpha: 0.92, darkAlpha: 0.10)
    static let infoBannerBG = Color(lightHex: "ffffff", darkHex: "000000", lightAlpha: 0.92, darkAlpha: 0.18)
}

enum AppTypography {
    static let hero = Font.system(size: 40, weight: .semibold, design: .default)
    static let sectionTitle = Font.system(size: 28, weight: .semibold, design: .default)
    static let body = Font.system(size: 17, weight: .regular, design: .default)
    static let caption = Font.system(size: 14, weight: .regular, design: .default)
    static let micro = Font.system(size: 12, weight: .regular, design: .default)
}

enum AppShape {
    static let cardRadius: CGFloat = 8
    static let mediaRadius: CGFloat = 8
    static let iconRadius: CGFloat = 7
    static let pillRadius: CGFloat = 980
    static let borderWidth: CGFloat = 0.5
}

struct ApplePrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTypography.body.weight(.medium))
            .padding(.horizontal, 18)
            .padding(.vertical, 9)
            .foregroundColor(.white)
            .background(
                RoundedRectangle(cornerRadius: AppShape.pillRadius)
                    .fill(configuration.isPressed ? AppColors.lightPurple : AppColors.purple)
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1.0)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

struct AppleOutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTypography.body.weight(.regular))
            .padding(.horizontal, 18)
            .padding(.vertical, 9)
            .foregroundColor(AppColors.lightPurple)
            .background(
                RoundedRectangle(cornerRadius: AppShape.pillRadius)
                    .stroke(AppColors.lightPurple, lineWidth: 1)
                    .background(
                        RoundedRectangle(cornerRadius: AppShape.pillRadius)
                            .fill(Color.white.opacity(configuration.isPressed ? 0.12 : 0.02))
                    )
            )
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

struct AppleCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(AppColors.deepCard)
            .cornerRadius(AppShape.cardRadius)
            .overlay(
                RoundedRectangle(cornerRadius: AppShape.cardRadius)
                    .stroke(AppColors.subtleBorder, lineWidth: AppShape.borderWidth)
            )
    }
}

extension View {
    func appleCardStyle() -> some View {
        modifier(AppleCardModifier())
    }
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
        case ..<40: return L10n.scoreDeleteRecommended
        case 40..<70: return L10n.scoreOptionalKeep
        default: return L10n.scoreKeepRecommended
        }
    }
}

// MARK: - Color hex init
extension Color {
    init(lightHex: String, darkHex: String, lightAlpha: CGFloat = 1.0, darkAlpha: CGFloat = 1.0) {
        self.init(
            UIColor { trait in
                if trait.userInterfaceStyle == .dark {
                    return UIColor(hex: darkHex, alpha: darkAlpha)
                }
                return UIColor(hex: lightHex, alpha: lightAlpha)
            }
        )
    }

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

extension UIColor {
    convenience init(hex: String, alpha: CGFloat = 1.0) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: CGFloat
        switch hex.count {
        case 3:
            r = CGFloat((int >> 8) * 17) / 255
            g = CGFloat((int >> 4 & 0xF) * 17) / 255
            b = CGFloat((int & 0xF) * 17) / 255
        case 6, 8:
            r = CGFloat((int >> 16) & 0xFF) / 255
            g = CGFloat((int >> 8) & 0xFF) / 255
            b = CGFloat(int & 0xFF) / 255
        default:
            r = 0
            g = 0
            b = 0
        }
        self.init(red: r, green: g, blue: b, alpha: alpha)
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
    static var temporaryGridColumns: Int {
        get {
            let v = UserDefaults.standard.object(forKey: "temporaryGridColumns") as? Int ?? 3
            return min(3, max(2, v))
        }
        set { UserDefaults.standard.set(min(3, max(2, newValue)), forKey: "temporaryGridColumns") }
    }
}

// MARK: - Scoring and clustering config
enum ScoringConfig {
    // Base
    static let baseScore = 50
    static let minScore = 5
    static let maxScore = 99

    // Blur thresholds (texture-aware Laplacian variance, edge pixels only)
    static let blurSevereThreshold = 60.0
    static let blurSlightThreshold = 180.0
    static let blurSharpThreshold = 500.0

    // Exposure thresholds (histogram dark/bright pixel ratios, 0–1)
    // "Very dark" = luma < 10;  "very bright" = luma > 245
    static let underExposedDarkRatio: Double   = 0.50  // >50% very-dark  → under-exposed
    static let overExposedBrightRatio: Double  = 0.30  // >30% very-bright → over-exposed
    static let bothExtremesDarkMin: Double     = 0.30  // high-contrast scene: don't penalise
    static let bothExtremesBrightMin: Double   = 0.20
    static let goodExposureDarkMax: Double     = 0.15
    static let goodExposureBrightMax: Double   = 0.10

    // Score weights — faces
    static let multiFaceBonus    = 28    // ≥2 high-quality faces
    static let singleFaceBonus   = 18    // 1 high-quality face
    static let blurryFacePenalty = -15   // face detected but quality < 0.3

    // Score weights — other content
    static let favoriteBonus = 40
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
