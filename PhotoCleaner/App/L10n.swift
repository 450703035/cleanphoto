import Foundation

// MARK: - Language enum
enum AppLanguage: String, CaseIterable, Identifiable {
    case zh = "zh"
    case en = "en"
    var id: String { rawValue }
    var displayName: String { self == .zh ? "中文" : "English" }
    static var current: AppLanguage {
        AppLanguage(rawValue: UserDefaults.standard.string(forKey: "appLanguage") ?? "zh") ?? .zh
    }
}

// MARK: - Localized strings
enum L10n {
    private static var isEn: Bool { AppLanguage.current == .en }

    // MARK: Tabs
    static var tabAIClean: String { isEn ? "AI Clean" : "AI清理" }
    static var tabTimeline: String { isEn ? "Timeline" : "时间线" }
    static var tabTools: String { isEn ? "Tools" : "工具" }
    static var tabSettings: String { isEn ? "Settings" : "设置" }

    // MARK: Common
    static var back: String { isEn ? "Back" : "返回" }
    static var cancel: String { isEn ? "Cancel" : "取消" }
    static var done: String { isEn ? "Done" : "完成" }
    static var free: String { isEn ? "Free" : "免费" }
    static var selectAll: String { isEn ? "Select All" : "全选" }
    static var deselectAll: String { isEn ? "Deselect All" : "取消全选" }
    static var select: String { isEn ? "Select" : "选择" }
    static var clearAll: String { isEn ? "Clear" : "清空" }
    static var deleteSelected: String { isEn ? "Delete Selected" : "删除所选" }
    static var processing: String { isEn ? "Processing…" : "处理中…" }
    static var loading: String { isEn ? "Loading…" : "加载中…" }
    static var photo: String { isEn ? "Photo" : "照片" }
    static var unknown: String { isEn ? "Unknown" : "未知" }

    static func items(_ count: Int) -> String { isEn ? "\(count) items" : "\(count)张" }
    static func groups(_ count: Int) -> String { isEn ? "\(count) groups" : "\(count) 组" }
    static func times(_ count: Int) -> String { isEn ? "\(count) times" : "\(count) 次" }
    static func points(_ n: Int) -> String { isEn ? "\(n) pts" : "\(n) 分" }
    static func deleteCount(_ count: Int, size: String) -> String {
        if size.isEmpty {
            return isEn ? "Delete \(count) items" : "删除所选 \(count) 张"
        }
        return isEn ? "Delete \(count) items · Free \(size)" : "删除所选 \(count) 张 · 释放 \(size)"
    }
    static func actionCount(_ action: String, _ count: Int, size: String) -> String {
        if size.isEmpty {
            return isEn ? "\(action) \(count) items" : "\(action) \(count) 张"
        }
        return isEn ? "\(action) \(count) items · Free \(size)" : "\(action) \(count) 张 · 释放 \(size)"
    }

    // MARK: Theme
    static var themeSystem: String { isEn ? "System" : "跟随系统" }
    static var themeLight: String { isEn ? "Light" : "浅色" }
    static var themeDark: String { isEn ? "Dark" : "深色" }

    // MARK: Score labels
    static var scoreDeleteRecommended: String { isEn ? "Delete Recommended" : "推荐删除" }
    static var scoreOptionalKeep: String { isEn ? "Optional Keep" : "可选保留" }
    static var scoreKeepRecommended: String { isEn ? "Keep Recommended" : "建议保留" }

    // MARK: Low quality reasons
    static var reasonBlurry: String { isEn ? "Blurry" : "模糊" }
    static var reasonShaky: String { isEn ? "Shaky" : "抖动" }
    static var reasonExposure: String { isEn ? "Exposure" : "过曝/过暗" }
    static var reasonFocusFail: String { isEn ? "Focus Failed" : "对焦失败" }

    // MARK: Screenshot categories
    static var catReceipt: String { isEn ? "Receipt" : "收据" }
    static var catHandwriting: String { isEn ? "Handwriting" : "手写" }
    static var catIllustration: String { isEn ? "Illustration" : "插图" }
    static var catQRCode: String { isEn ? "QR Code" : "二维码" }
    static var catDocument: String { isEn ? "Document" : "文稿" }
    static var catOther: String { isEn ? "Other" : "其他" }

    // MARK: Scan phases
    static var phaseIdle: String { isEn ? "Not Scanned" : "尚未扫描" }
    static var phaseScanning: String { isEn ? "Analyzing…" : "分析中…" }
    static var phaseDone: String { isEn ? "Scan Complete" : "扫描完成" }

    // MARK: Scan VM phases
    static var scanPhase1: String { isEn ? "Detecting duplicates" : "检测重复照片" }
    static var scanPhase2: String { isEn ? "Analyzing similar photos" : "分析相似图片" }
    static var scanPhase3: String { isEn ? "Evaluating quality" : "评估照片质量" }
    static var scanPhase4: String { isEn ? "Building score database" : "建立评分数据库" }
    static var scanPhase5: String { isEn ? "Generating cleanup plan" : "生成清理方案" }
    static var scanRequestAuth: String { isEn ? "Requesting access" : "请求相册权限" }
    static var scanPhaseA: String { isEn ? "Phase 1: Stats & types" : "第一阶段：统计空间与类型" }
    static func scanPhaseACountdown(_ s: Int) -> String { isEn ? "Phase 1: Stats & types \(s)s" : "第一阶段：统计空间与类型 \(s)s" }
    static var scanComplete: String { isEn ? "Analysis complete" : "分析完成" }
    static var bgDeepAnalysis: String { isEn ? "Background deep analysis" : "后台深度分析中" }
    static var bgScoring: String { isEn ? "Background: Scoring" : "后台分析：照片评分" }
    static var bgDuplicates: String { isEn ? "Background: Duplicates" : "后台分析：重复照片" }
    static var bgSimilar: String { isEn ? "Background: Similar" : "后台分析：相似照片" }
    static var bgLowQuality: String { isEn ? "Background: Low quality" : "后台分析：低质量照片" }
    static var bgSaving: String { isEn ? "Background: Saving" : "后台分析：保存结果" }
    static var bgComplete: String { isEn ? "Background analysis done" : "后台分析完成" }
    static var bgAnalyzing: String { isEn ? "Background analyzing" : "后台分析中" }

    // MARK: Home - Idle
    static var aiClean: String { isEn ? "AI Clean" : "AI 清理" }
    static var smartAnalyze: String { isEn ? "Smart analysis for your album" : "智能分析你的相册" }
    static var notScanned: String { isEn ? "Not Scanned" : "尚未扫描" }
    static var tapToStart: String { isEn ? "Tap to start" : "点击开始" }
    static var startScan: String { isEn ? "Start Scan" : "开始扫描" }
    static var noManualPick: String { isEn ? "No manual picking, AI recommends" : "无需逐张选择，AI自动推荐" }
    static var safeDeleteGuide: String { isEn ? "We'll guide you to safely delete useless photos" : "我们将引导您安全删除无用照片" }
    static var cancelScan: String { isEn ? "Cancel Scan" : "取消扫描" }
    static func analyzedPhotos(_ n: Int) -> String { isEn ? "Analyzed \(n) photos" : "已分析 \(n) 张照片" }
    static func elapsedTime(_ t: String) -> String { isEn ? "Elapsed \(t)" : "已用时 \(t)" }

    // MARK: Home - Dashboard
    static func bgAnalyzingElapsed(_ t: String) -> String { isEn ? "Background analyzing · Elapsed \(t)" : "后台分析中 · 已用时 \(t)" }
    static func totalScanTime(_ t: String) -> String { isEn ? "Total scan time: \(t)" : "本次扫描总耗时：\(t)" }
    static var smartSuggestions: String { isEn ? "Smart Suggestions · Tap to Enter" : "智能建议 · 点击进入" }
    static var duplicateAndSimilar: String { isEn ? "Duplicates & Similar" : "重复与相似照片" }
    static func dupDesc(_ dup: Int, _ sim: Int) -> String { isEn ? "\(dup) duplicate · \(sim) similar groups" : "\(dup)组重复 · \(sim)组相似" }
    static var screenshotClean: String { isEn ? "Screenshot Cleanup" : "截图清理" }
    static func screenshotDesc(_ n: Int) -> String { isEn ? "\(n) screenshots · Auto analyzed" : "\(n)张截图 · 已自动分析" }
    static var largeVideos: String { isEn ? "Large Videos" : "大视频文件" }
    static func videoDesc(_ n: Int) -> String { isEn ? "\(n) videos, sorted by size" : "\(n)个视频，按大小排序" }
    static var lowQualityPhotos: String { isEn ? "Low Quality Photos" : "低质量照片" }
    static func lowQualityDesc(_ n: Int) -> String { isEn ? "Blurry/Shaky/Exposure/Focus failed \(n)" : "模糊/抖动/曝光/对焦失败 \(n)张" }
    static var otherBehavior: String { isEn ? "Other Behavior" : "其他使用行为" }
    static var behaviorDesc: String { isEn ? "Never viewed / Long time ago / By year" : "从未查看/很久没看/按年限筛选" }
    static var favoritePhotos: String { isEn ? "Favorites" : "收藏照片" }
    static func favoriteDesc(_ n: Int) -> String { isEn ? "\(n) · Not selected by default" : "\(n)张 · 默认不选择" }

    // MARK: Health card
    static var totalPhotos: String { isEn ? "Total Photos" : "照片总数" }
    static var storageUsed: String { isEn ? "Storage Used" : "占用空间" }
    static var freeable: String { isEn ? "Freeable" : "可释放" }
    static var spaceDistribution: String { isEn ? "Space Distribution" : "空间分布" }
    static var video: String { isEn ? "Video" : "视频" }
    static var screenshot: String { isEn ? "Screenshot" : "截图" }

    // MARK: Settings
    static var userAccount: String { isEn ? "Account" : "用户账号" }
    static var freeVersion: String { isEn ? "Free" : "免费版" }
    static var upgradePro: String { isEn ? "Upgrade Pro" : "升级 Pro" }
    static var appearance: String { isEn ? "Appearance" : "外观" }
    static var displayMode: String { isEn ? "Display Mode" : "显示模式" }
    static var followSystem: String { isEn ? "Follow system appearance" : "默认跟随系统外观" }
    static var language: String { isEn ? "Language" : "语言" }
    static var languageSubtitle: String { isEn ? "Switch app language" : "切换应用语言" }
    static var cleanSettings: String { isEn ? "Cleaning" : "清理设置" }
    static var deleteThreshold: String { isEn ? "Delete Threshold" : "删除阈值" }
    static func thresholdDesc(_ n: Int) -> String { isEn ? "Auto-recommend deletion below \(n)" : "低于 \(n) 分自动推荐删除" }
    static var autoSelect: String { isEn ? "Auto Select" : "自动勾选" }
    static var autoSelectDesc: String { isEn ? "Auto-select recommendations after scan" : "扫描后自动选中推荐项" }
    static var timeWeight: String { isEn ? "Time Weight" : "时间权重" }
    static var timeWeightDesc: String { isEn ? "Older photos get lower scores" : "越早的照片评分越低" }
    static var protectFace: String { isEn ? "Protect Face Photos" : "保护人脸照片" }
    static var protectFaceDesc: String { isEn ? "Photos with faces won't auto-delete" : "含人脸照片不自动删除" }
    static func currentThreshold(_ n: Int) -> String { isEn ? "Current threshold: \(n)" : "当前阈值：\(n) 分" }
    static var lenient: String { isEn ? "Lenient (10)" : "宽松 (10)" }
    static var strict: String { isEn ? "Strict (80)" : "严格 (80)" }
    static var notificationPrivacy: String { isEn ? "Notifications & Privacy" : "通知与隐私" }
    static var dailyReminder: String { isEn ? "Daily Reminder" : "每日清理提醒" }
    static var dailyReminderDesc: String { isEn ? "Daily reminder to clean up" : "每天提醒完成清理任务" }
    static var localAI: String { isEn ? "Local AI Analysis" : "本地 AI 分析" }
    static var localAIDesc: String { isEn ? "All analysis done on device" : "所有分析均在设备上完成" }
    static var enabled: String { isEn ? "Enabled" : "已开启" }
    static var statistics: String { isEn ? "Statistics" : "数据统计" }
    static var totalFreed: String { isEn ? "Total Freed Space" : "累计释放空间" }
    static var totalCleanups: String { isEn ? "Total Cleanups" : "累计清理次数" }
    static var healthImprovement: String { isEn ? "Health Improvement" : "相册健康提升" }
    static var improving: String { isEn ? "Improving" : "持续优化中" }
    static var noData: String { isEn ? "No Data" : "暂无数据" }

    // MARK: Tools
    static var cleaningTools: String { isEn ? "Cleaning Tools" : "清理工具" }
    static var toolboxSubtitle: String { isEn ? "Professional photo toolbox" : "专业照片整理工具箱" }
    static var liveToStatic: String { isEn ? "Live→Static" : "Live→静态" }
    static var liveToStaticDesc: String { isEn ? "Convert Live Photo to still" : "Live Photo 转普通照片" }
    static var videoCompress: String { isEn ? "Video Compress" : "视频压缩" }
    static var videoCompressDesc: String { isEn ? "Smart compress, minimal quality loss" : "智能压缩，画质损失最小" }
    static var blurDetect: String { isEn ? "Blur Detection" : "模糊检测" }
    static var blurDetectDesc: String { isEn ? "Auto-detect blurry photos" : "自动找出模糊照片" }
    static var heicConvert: String { isEn ? "HEIC Convert" : "HEIC转换" }
    static var heicConvertDesc: String { isEn ? "Batch convert to JPG" : "批量转为 JPG 格式" }
    static var smartAlbum: String { isEn ? "Smart Albums" : "智能相册" }
    static var smartAlbumDesc: String { isEn ? "AI auto-categorize" : "AI 自动分类整理" }
    static var swipeDecide: String { isEn ? "Swipe Decide" : "逐张决策" }
    static var swipeDecideDesc: String { isEn ? "Swipe left delete · right keep · undo" : "左滑删除 · 右滑保留 · 撤销" }

    // MARK: Smart Album names
    static var albumSelfie: String { isEn ? "Selfies" : "自拍" }
    static var albumScreenshot: String { isEn ? "Screenshots" : "截图" }
    static var albumVideo: String { isEn ? "Videos" : "视频" }
    static var albumPanorama: String { isEn ? "Panoramas" : "全景" }
    static var albumLive: String { isEn ? "Live" : "Live" }
    static var albumSlomo: String { isEn ? "Slo-mo" : "慢动作" }
    static var albumPortrait: String { isEn ? "Portrait" : "人像" }
    static var albumFavorites: String { isEn ? "Favorites" : "收藏" }
    static var smartAlbumTitle: String { isEn ? "Smart Albums" : "智能相册" }
    static var smartAlbumSubtitle: String { isEn ? "Auto-classified by iOS" : "iOS 系统自动分类" }
    static var smartAlbumNote: String { isEn ? "These are maintained by iOS, tap to view" : "以下分类由 iOS 系统自动维护，点击查看" }
    static var loadingAlbums: String { isEn ? "Loading albums…" : "加载相册中…" }

    // MARK: Swipe delete
    static var locating: String { isEn ? "Locating…" : "定位中…" }
    static var noLocation: String { isEn ? "No location" : "无位置信息" }
    static var unknownLocation: String { isEn ? "Unknown location" : "位置未知" }
    static var loadingPhotos: String { isEn ? "Loading photos…" : "加载照片…" }
    static var noPhotosInAlbum: String { isEn ? "No photos in album" : "相册中没有照片" }
    static var allDone: String { isEn ? "All Done!" : "全部完成！" }
    static var deleted: String { isEn ? "Deleted" : "已删除" }
    static var kept: String { isEn ? "Kept" : "已保留" }
    static var swipeDelete: String { isEn ? "← Delete" : "← 删除" }
    static var tapUndo: String { isEn ? "Tap ↩ undo" : "点击 ↩ 撤销" }
    static var swipeKeep: String { isEn ? "Keep →" : "保留 →" }
    static var markedDelete: String { isEn ? "Marked delete · Tap ↩ to undo" : "已标记删除 · 点击 ↩ 可撤销" }
    static var markedKeep: String { isEn ? "Marked keep · Tap ↩ to undo" : "已标记保留 · 点击 ↩ 可撤销" }
    static var allowDeleteTitle: String { isEn ? "Allow Photo Deletion" : "允许删除照片" }
    static var allowDelete: String { isEn ? "Allow Delete" : "允许删除" }
    static var deleteAlertMessage: String { isEn ? "PhotoCleaner will move selected photos to Recently Deleted. You can recover them anytime." : "相册管家将把选中的照片移入废纸篓，您随时可以在「最近删除」相册中恢复。" }
    static var deleteStamp: String { isEn ? "DELETE" : "删除" }
    static var keepStamp: String { isEn ? "KEEP" : "保留" }

    // MARK: Media types
    static var mediaScreenshot: String { isEn ? "Screenshot" : "截图" }
    static var mediaLivePhoto: String { isEn ? "Live Photo" : "实况照片" }
    static var mediaPanorama: String { isEn ? "Panorama" : "全景照片" }
    static var mediaHDR: String { isEn ? "HDR Photo" : "HDR 照片" }
    static var mediaTimelapse: String { isEn ? "Timelapse" : "延时摄影" }
    static var mediaSlomo: String { isEn ? "Slo-mo" : "慢动作视频" }
    static var mediaVideo: String { isEn ? "Video" : "视频" }
    static var mediaPhoto: String { isEn ? "Photo" : "普通照片" }
    // Short versions for tags
    static var tagVideo: String { isEn ? "Video" : "视频" }
    static var tagScreenshot: String { isEn ? "Screenshot" : "截图" }
    static var tagPanorama: String { isEn ? "Panorama" : "全景" }
    static var tagPhoto: String { isEn ? "Photo" : "照片" }

    // MARK: Photo info sheet
    static var dateAndTime: String { isEn ? "Date & Time" : "日期与时间" }
    static var dateLabel: String { isEn ? "Date" : "日期" }
    static var timeLabel: String { isEn ? "Time" : "时间" }
    static var locationSection: String { isEn ? "Location" : "位置" }
    static var locationLabel: String { isEn ? "Location" : "地点" }
    static var fileInfo: String { isEn ? "File Info" : "文件信息" }
    static var fileName: String { isEn ? "Filename" : "文件名" }
    static var resolution: String { isEn ? "Resolution" : "分辨率" }
    static var sizeLabel: String { isEn ? "Size" : "大小" }
    static var format: String { isEn ? "Format" : "格式" }
    static var duration: String { isEn ? "Duration" : "时长" }
    static var attributes: String { isEn ? "Attributes" : "属性" }
    static var aiScore: String { isEn ? "AI Score" : "AI 评分" }
    static var favorited: String { isEn ? "Favorited" : "收藏" }
    static var favoritedYes: String { isEn ? "Yes" : "已收藏" }
    static var typeLabel: String { isEn ? "Type" : "类型" }
    static var photoInfo: String { isEn ? "Photo Info" : "照片信息" }

    // MARK: Done view
    static var cleanComplete: String { isEn ? "Cleanup Complete!" : "清理完成！" }
    static var movedToTrash: String { isEn ? "Moved to Recently Deleted\nYour album is cleaner now" : "已移至废纸篓\n你的相册更整洁了 ✨" }

    // MARK: Video compress
    static var compressQuality: String { isEn ? "Compression Quality" : "压缩质量" }
    static var highCompression: String { isEn ? "High Compression" : "高压缩率" }
    static func qualityPercent(_ n: Int) -> String { isEn ? "\(n)% Quality" : "\(n)% 质量" }
    static var highQuality: String { isEn ? "High Quality" : "高画质" }
    static func estimatedSave(_ s: String) -> String { isEn ? "Est. save \(s)" : "预计节省 \(s)" }
    static var loadingVideos: String { isEn ? "Loading videos…" : "正在加载视频…" }
    static var noVideos: String { isEn ? "No videos in album" : "相册中没有视频文件" }
    static var compressSelected: String { isEn ? "Compress Selected" : "压缩所选" }
    static func videosCompressed(_ n: Int) -> String { isEn ? "\(n) videos compressed" : "\(n)个视频已压缩" }

    // MARK: HEIC convert
    static func heicDoneLabel(_ n: Int) -> String { isEn ? "\(n) HEIC converted to JPG" : "\(n)张 HEIC 已转为 JPG" }
    static var scanning: String { isEn ? "Scanning…" : "扫描中…" }
    static func filesToConvert(_ n: Int) -> String { isEn ? "\(n) files to convert" : "\(n) 个文件待转换" }
    static func converting(_ pct: Int) -> String { isEn ? "Converting… \(pct)%" : "转换中… \(pct)%" }
    static var scanningHEIC: String { isEn ? "Scanning HEIC files…" : "正在扫描 HEIC 文件…" }
    static var noHEIC: String { isEn ? "No HEIC photos in album" : "相册中没有 HEIC 格式照片" }
    static func startConvert(_ n: Int) -> String { isEn ? "Convert \(n) files" : "开始批量转换 \(n) 个文件" }
    static var pending: String { isEn ? "Pending" : "待转" }

    // MARK: Live photo
    static func livePhotoDone(_ n: Int) -> String { isEn ? "\(n) Live Photos converted" : "\(n)个 Live Photo 已转换" }
    static func livePhotoSubtitle(_ n: Int, _ size: String) -> String { isEn ? "\(n) · Save ~\(size)" : "\(n) 个 · 可省约 \(size)" }
    static var livePhotoNote: String { isEn ? "Converting to still saves ~55% space, removes motion" : "转换为静态照片可节省约 55% 空间，动态效果将移除" }
    static var loadingLivePhoto: String { isEn ? "Loading Live Photos…" : "正在加载 Live Photo…" }
    static var noLivePhoto: String { isEn ? "No Live Photos in album" : "相册中没有 Live Photo" }
    static var convertSelected: String { isEn ? "Convert Selected" : "转换所选" }
    static func approxSave(_ size: String, _ saved: String) -> String { isEn ? "~\(size) · Save ~\(saved)" : "约 \(size) · 节省约 \(saved)" }

    // MARK: Blur detect
    static func blurDone(_ n: Int) -> String { isEn ? "\(n) blurry photos" : "\(n)张模糊照片" }
    static func blurScanning(_ done: Int, _ total: Int) -> String { isEn ? "Detecting… \(done)/\(total)" : "检测中… \(done)/\(total)" }
    static func blurFound(_ n: Int) -> String { isEn ? "Found \(n) blurry photos" : "发现 \(n) 张模糊照片" }
    static var analyzingClarity: String { isEn ? "Analyzing photo clarity…" : "正在分析照片清晰度…" }
    static func foundBlurry(_ n: Int) -> String { isEn ? "Found \(n) blurry" : "已发现 \(n) 张模糊照片" }
    static var noBlurry: String { isEn ? "No blurry photos found\nAll your photos are sharp!" : "未发现模糊照片\n你的照片都很清晰！" }
    static var severeBlur: String { isEn ? "Very blurry" : "严重模糊" }
    static var blurry: String { isEn ? "Blurry" : "模糊" }
    static var slightBlur: String { isEn ? "Slightly blurry" : "轻微模糊" }

    // MARK: Clean detail views
    static var duplicateAndSimilarTitle: String { isEn ? "Duplicates & Similar" : "重复与相似" }
    static func dupLabel(_ n: Int) -> String { isEn ? "\(n) duplicate photos" : "\(n)张重复照片" }
    static var duplicate: String { isEn ? "Duplicate" : "重复" }
    static var similar: String { isEn ? "Similar" : "相似" }
    static var merge: String { isEn ? "Merge" : "合并" }
    static var best: String { isEn ? "Best" : "最佳" }
    static func screenshotsDone(_ n: Int) -> String { isEn ? "\(n) screenshots" : "\(n)张截图" }
    static var screenshotTitle: String { isEn ? "Screenshot Cleanup" : "截图清理" }
    static func screenshotSubtitle(_ total: Int, _ rec: Int) -> String { isEn ? "\(total) · Recommend delete \(rec)" : "\(total)张 · 推荐删 \(rec)张" }
    static var autoSelectedLow: String { isEn ? "Low quality screenshots auto-selected, adjust manually" : "已自动选中低质量截图，可手动调整" }
    static var all: String { isEn ? "All" : "全部" }
    static func classifying(_ pct: Int) -> String { isEn ? "Classifying \(pct)%" : "分类中 \(pct)%" }
    static func videosDone(_ n: Int) -> String { isEn ? "\(n) videos" : "\(n)个视频" }
    static var videoTitle: String { isEn ? "Large Videos" : "大视频文件" }
    static func videoSubtitle(_ n: Int) -> String { isEn ? "\(n) videos, sorted by size" : "\(n)个视频，按大小排序" }
    static var videoBanner: String { isEn ? "Two-column view; tap video to play inline; mark with circle below to batch delete" : "两列浏览；点视频原位小窗播放；点下方圆圈标记后可批量删除" }
    static var unknownDate: String { isEn ? "Unknown date" : "未知日期" }
    static func lowQualityDone(_ n: Int) -> String { isEn ? "\(n) low quality photos" : "\(n)张低质量照片" }
    static var lowQualityTitle: String { isEn ? "Low Quality" : "低质量照片" }
    static func lowQualitySubtitle(_ n: Int) -> String { isEn ? "\(n) total · All recommended selected" : "共\(n)张 · 已全选推荐" }
    static func favoritesDone(_ n: Int) -> String { isEn ? "\(n) favorite photos" : "\(n)张收藏照片" }
    static var favoritesTitle: String { isEn ? "Favorites" : "收藏照片" }
    static func favoritesSubtitle(_ n: Int) -> String { isEn ? "\(n) · Not selected by default" : "\(n)张 · 默认不勾选" }
    static var favoriteBanner: String { isEn ? "Favorites not selected by default to avoid accidental deletion" : "收藏照片默认不选，避免误删重要内容" }
    static func photosDone(_ n: Int) -> String { isEn ? "\(n) photos" : "\(n)张照片" }
    static var behaviorTitle: String { isEn ? "Other Behavior" : "其他使用行为" }
    static func behaviorSubtitle(_ n: Int) -> String { isEn ? "\(n) · Favorites excluded" : "\(n)张 · 已排除收藏" }
    static var behaviorNeverViewed: String { isEn ? "Never Viewed" : "从未查看" }
    static var behaviorLongUnused: String { isEn ? "Long Unused" : "很久没看" }
    static var behaviorOlder3: String { isEn ? "Over 3 Years" : "超过3年" }
    static var behaviorOlder5: String { isEn ? "Over 5 Years" : "超过5年" }
    static var behaviorNeverViewedBanner: String { isEn ? "iOS does not provide 'Never Viewed' data, this filter is unavailable" : "iOS 暂不提供\u{201C}从未查看\u{201D}公开数据，本筛选暂不可用" }
    static var behaviorBanner: String { isEn ? "Filter by behavior and time, adjust deletion targets manually" : "按使用行为与时间筛选，可手动调整删除对象" }
    static var markedDeleteToggle: String { isEn ? "Marked for delete · Tap again to cancel" : "已标记删除 · 再次点击取消" }
    static var markDelete: String { isEn ? "Mark Delete" : "标记删除" }

    // MARK: Timeline
    static var timeline: String { isEn ? "Timeline" : "时间线" }
    static var listMode: String { isEn ? "List" : "列表" }
    static var calendarMode: String { isEn ? "Calendar" : "日历" }
    static var waterfallMode: String { isEn ? "Waterfall" : "瀑布" }
    static func yearLabel(_ y: Int) -> String { isEn ? "\(y)" : "\(y)年" }
    static var legendFew: String { isEn ? "Few" : "少" }
    static var legendMedium: String { isEn ? "Med" : "中" }
    static var legendMany: String { isEn ? "Many" : "多" }
    static var legendFull: String { isEn ? "Full" : "满" }
    static func scoringPhotos(_ pct: Int) -> String { isEn ? "Scoring photos \(pct)%" : "照片打分中 \(pct)%" }
    static func deleteSize(_ s: String) -> String { isEn ? "· Del \(s)" : "· 删 \(s)" }
    static var tapEnterLongDelete: String { isEn ? "Tap to enter · Long press to delete" : "点击进入 · 长按删除" }
    static func totalItems(_ n: Int) -> String { isEn ? "\(n) items (photos+videos)" : "共\(n)项（照片+视频）" }
    static var deleting: String { isEn ? "Deleting…" : "删除中…" }
    static var unknownTime: String { isEn ? "Unknown time" : "未知时间" }
    static var unknownPlace: String { isEn ? "Unknown place" : "未知地点" }
    static func yearMonth(_ y: Int, _ m: Int) -> String { isEn ? "\(y)/\(m)" : "\(y)年\(m)月" }
    static var weekdays: [String] { isEn ? ["Su","Mo","Tu","We","Th","Fr","Sa"] : ["日","一","二","三","四","五","六"] }
    static func dayCount(_ n: Int) -> String { isEn ? "\(n)" : "\(n)张" }
    static func folderInfo(_ count: Int, _ title: String) -> String { isEn ? "\(count) · \(title)" : "\(count)张 · \(title)" }
    static func belowThreshold(_ n: Int) -> String { isEn ? "Photos below \(n) are pre-marked, tap to toggle" : "低于 \(n) 分的照片已默认标记，点击可切换" }
    static func dayDetailSubtitle(_ count: Int, _ size: String, _ avg: Int) -> String { isEn ? "\(count) · \(size) · Avg \(avg)" : "\(count)张 · \(size) · 均分\(avg)" }
    static var infoSize: String { isEn ? "Size" : "大小" }
    static var infoFormat: String { isEn ? "Format" : "格式" }
    static var infoTime: String { isEn ? "Time" : "时间" }
    static var infoLocation: String { isEn ? "Location" : "地点" }

    // MARK: Month formatting
    static func monthLabel(_ m: Int) -> String {
        if isEn {
            let names = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]
            return m >= 1 && m <= 12 ? names[m-1] : "\(m)"
        } else {
            return "\(m)月"
        }
    }
    static var monthNames: [String] {
        if isEn {
            return ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]
        } else {
            return ["1月","2月","3月","4月","5月","6月","7月","8月","9月","10月","11月","12月"]
        }
    }
    static func dayFormat(_ year: Int, _ month: Int, _ day: Int) -> String {
        if isEn {
            let names = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]
            let m = month >= 0 && month < 12 ? names[month] : "\(month+1)"
            return "\(m) \(day), \(year)"
        } else {
            let months = ["1月","2月","3月","4月","5月","6月","7月","8月","9月","10月","11月","12月"]
            return "\(year)年\(months[month]) \(day)日"
        }
    }

    // MARK: Locale
    static var dateLocaleIdentifier: String { isEn ? "en_US" : "zh_CN" }
}
