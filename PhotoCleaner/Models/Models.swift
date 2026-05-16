import SwiftUI
import Photos

// MARK: - PhotoAsset  (wraps PHAsset + computed score)
struct PhotoAsset: Identifiable, Hashable {
    let id: String
    let asset: PHAsset
    var score: Int
    var isSelected: Bool
    var isVideo: Bool = false
    var isLivePhoto: Bool = false
    var isUtility: Bool = false
    var reason: LowQualityReason?
    var coldTier: ColdTier? = nil
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
    let id: String
    var title: String
    var assets: [PhotoAsset]
    var date: Date
    var averageScore: Int { assets.isEmpty ? 0 : assets.reduce(0) { $0 + $1.score } / assets.count }
    var totalSize: Int64 { assets.reduce(0) { $0 + $1.sizeBytes } }
    var formattedSize: String { ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file) }
    var recommendDelete: Bool { averageScore < AppConfig.deleteThreshold }
}

// MARK: - Cold photo tier (behavioral signals)
enum ColdTier: String {
    /// 🥶 Extremely cold: 3+ years old, never edited, barely touched after capture.
    case frozen = "frozen"
    /// ❄️ Cold: 1+ year old, mostly untouched.
    case cold   = "cold"

    var emoji: String { self == .frozen ? "🥶" : "❄️" }
    var label: String { self == .frozen ? L10n.coldTierFrozen : L10n.coldTierCold }
    var detailLabel: String { self == .frozen ? L10n.coldTierFrozenDetail : L10n.coldTierColdDetail }
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

// MARK: - Screenshot category (local screenshot-source classifier)
enum ScreenshotCategory: String, CaseIterable {
    case app1688 = "1688"
    case soul = "Soul"
    case appstore = "appstore"
    case keep = "keep"
    case qq = "qq"
    case safari = "safari"
    case jd = "京东"
    case toutiao = "今日头条"
    case youku = "优酷视频"
    case health = "健康"
    case jianying = "剪映"
    case genshin = "原神"
    case qunar = "去哪儿"
    case ths = "同花顺"
    case peaceElite = "和平精英"
    case bilibili = "哔哩哔哩"
    case dianping = "大众点评"
    case weather = "天气"
    case tmall = "天猫"
    case quark = "夸克"
    case xiaohongshu = "小红书"
    case dewu = "得物"
    case wechat = "微信"
    case weibo = "微博"
    case douyin = "抖音"
    case pinduoduo = "拼多多"
    case trip = "携程"
    case alipay = "支付宝"
    case files = "文件"
    case documentSource = "文档"
    case news = "新闻"
    case calendar = "日历"
    case desktop = "桌面"
    case taobao = "淘宝"
    case didi = "滴滴出行"
    case photos = "照片"
    case iqiyi = "爱奇艺"
    case honorOfKings = "王者荣耀"
    case baiduMap = "百度地图"
    case baiduNetdisk = "百度网盘"
    case zhihu = "知乎"
    case sms = "短信"
    case neteaseMusic = "网易云音乐"
    case meituan = "美团"
    case tencentVideo = "腾讯视频"
    case mangoTV = "芒果TV"
    case antFortune = "蚂蚁财富"
    case eggyParty = "蛋仔派对"
    case xiguaVideo = "西瓜视频"
    case settings = "设置"
    case certificate = "证件"
    case douban = "豆瓣"
    case zhuanzhuan = "转转"
    case xunlei = "迅雷"
    case dingtalk = "钉钉"
    case bank = "银行"
    case xianyu = "闲鱼"
    case feishu = "飞书"
    case fliggy = "飞猪"
    case amap = "高德"

    // Legacy heuristic categories retained for old cache rows and model fallback.
    case receipt = "receipt"
    case handwriting = "handwriting"
    case illustration = "illustration"
    case qrCode = "qrCode"
    case document = "document"
    case other = "other"

    static var allCases: [ScreenshotCategory] {
        sourceCases + [.other]
    }

    static let sourceCases: [ScreenshotCategory] = [
        .app1688, .soul, .appstore, .keep, .qq, .safari, .jd, .toutiao,
        .youku, .health, .jianying, .genshin, .qunar, .ths, .peaceElite,
        .bilibili, .dianping, .weather, .tmall, .quark, .xiaohongshu,
        .dewu, .wechat, .weibo, .douyin, .pinduoduo, .trip, .alipay,
        .files, .documentSource, .news, .calendar, .desktop, .taobao,
        .didi, .photos, .iqiyi, .honorOfKings, .baiduMap, .baiduNetdisk,
        .zhihu, .sms, .neteaseMusic, .meituan, .tencentVideo, .mangoTV,
        .antFortune, .eggyParty, .xiguaVideo, .settings, .certificate,
        .douban, .zhuanzhuan, .xunlei, .dingtalk, .bank, .xianyu,
        .feishu, .fliggy, .amap
    ]

    var chipLabel: String {
        switch self {
        case .receipt: return L10n.catReceipt
        case .handwriting: return L10n.catHandwriting
        case .illustration: return L10n.catIllustration
        case .qrCode: return L10n.catQRCode
        case .document: return L10n.catDocument
        case .other: return L10n.catOther
        default: return rawValue
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
    var releasedBytes: Int64 = 0
    var healthScore: Int = 0
    var videoBytes: Int64 = 0
    var screenshotBytes: Int64 = 0
    var utilityBytes: Int64 = 0
    var livePhotoBytes: Int64 = 0
    var livePhotoCount: Int = 0
    var photoBytes: Int64 = 0

    var formattedTotal: String { ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file) }
    var formattedFreeable: String { ByteCountFormatter.string(fromByteCount: freeableBytes, countStyle: .file) }
    var formattedReleased: String { ByteCountFormatter.string(fromByteCount: releasedBytes, countStyle: .file) }
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
