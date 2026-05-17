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
    static var isEn: Bool { AppLanguage.current == .en }

    // MARK: Tabs
    static var tabAIClean: String { isEn ? "AI Clean" : "AI清理" }
    static var tabClean: String { isEn ? "Clean" : "清理" }
    static var tabTimeline: String { isEn ? "Timeline" : "时间线" }
    static var tabTools: String { isEn ? "Tools" : "工具" }
    static var tabSettings: String { isEn ? "Settings" : "设置" }
    static var tabMe: String { isEn ? "Me" : "我的" }
    static var tabInsights: String { isEn ? "Insights" : "洞察" }

    // MARK: Insights
    static var insightsTitle: String { isEn ? "Insights" : "洞察" }
    static func insightsSubtitle(_ monthLabel: String, _ count: Int) -> String {
        isEn ? "\(monthLabel) · \(count) photos this month" : "\(monthLabel) · 本月你拍了 \(count.formatted()) 张"
    }
    static var insightsAnnualReportCTA: String { isEn ? "Annual" : "年报" }
    static var insightsPersonaEyebrow: String { isEn ? "Album Persona" : "相册人格" }
    static var insightsAIGenerated: String { isEn ? "AI Generated" : "AI 生成" }
    static func viewAnnualReport(_ year: Int) -> String {
        isEn ? "View your \(year) report" : "查看你的 \(year) 报告"
    }
    static func viewAnnualReportSub(_ count: Int) -> String {
        isEn ? "\(count.formatted()) photos · 12 months" : "\(count.formatted()) 张照片 · 12 个月"
    }
    static var insightsSectionBehavior: String { isEn ? "Shooting behavior" : "拍摄行为" }
    static var insightsSectionBehaviorTitle: String { isEn ? "Your rhythm" : "你拍照的节奏" }
    static var insightsSectionClean: String { isEn ? "Cleanup advice" : "整理建议" }
    static var insightsSectionCleanTitle: String { isEn ? "Let's lighten up" : "让相册轻一点" }
    static var insightsTrendTitle: String { isEn ? "Shooting trend" : "拍摄趋势" }
    static func insightsTrendSub(_ days: Int, _ count: Int) -> String {
        isEn ? "Last \(days) days · \(count) photos" : "过去 \(days) 天 · \(count) 张"
    }
    static var insightsTrendTab7d: String { isEn ? "7d" : "7天" }
    static var insightsTrendTabHour: String { isEn ? "Hour" : "时段" }
    static var insightsTrendMost: String { isEn ? "Most on weekends" : "周六拍得最多" }
    static func insightsTrendDelta(_ pct: Int) -> String {
        isEn ? "+\(pct)% vs last week" : "较上周 +\(pct)%"
    }
    static func insightsPeakHourInsight(_ hour: Int, _ pct: Int) -> String {
        isEn ? "\(hour):00 is your peak — \(pct)% of daily shots." : "晚 \(hour) 点 是你的高峰时刻，占到全天拍照的 \(pct)%。"
    }
    static var insightsMixTitle: String { isEn ? "What you shot" : "你拍了什么" }
    static var insightsMixSub: String { isEn ? "Content mix this month" : "本月内容分布" }
    static var insightsScreenshotTitle: String { isEn ? "Where screenshots come from" : "截图来自哪里" }
    static var insightsScreenshotBadge: String { isEn ? "Waste alert" : "浪费警报" }
    static func insightsScreenshotSub(_ total: Int, _ pct: Int) -> String {
        isEn ? "\(total) screenshots · \(pct)% never revisited" : "本月 \(total) 张截图 · 其中 \(pct)% 从未回看"
    }
    static var insightsReleaseLabel: String { isEn ? "Freeable space" : "可释放空间" }
    static var insightsReleaseUsed: String { isEn ? "Used / Total" : "已用 / 总" }
    static var insightsLibrarySize: String { isEn ? "Library size" : "相册占用" }
    static func insightsReleaseCTA(_ size: String) -> String {
        isEn ? "Clean now · Free \(size)" : "一键清理 · 释放 \(size)"
    }
    static var insightsAIBadge: String { isEn ? "AI Suggestion" : "AI 建议" }
    static func insightsAISuggestion(_ count: Int, _ size: String) -> String {
        isEn ? "\(count) temporary screenshots haven't been opened for 30+ days. Clean them to free ~\(size)." : "你有 \(count) 张「临时截图」已超过 30 天没打开。清理后可释放约 \(size)。"
    }
    static var insightsAIActionNow: String { isEn ? "Handle now" : "立即处理" }
    static var insightsAIActionLater: String { isEn ? "Later" : "稍后" }
    static var insightsLocalOnly: String { isEn ? "Computed on-device · no photos uploaded" : "仅在本机计算 · 不上传任何照片" }

    // MARK: Insight — personas
    static var personaNightOwl: String { isEn ? "The Night Recorder" : "夜晚的记录者" }
    static var personaNightOwlChip: String { isEn ? "Night Owl" : "夜晚记录者" }
    static var personaNightOwlLine: String {
        isEn ? "You shoot most often late at night — many of your stories happen before sleep."
             : "这一个月，你最常在深夜按下快门 — 很多故事都发生在睡前。"
    }
    static var personaFoodie: String { isEn ? "Table Photographer" : "餐桌上的摄影师" }
    static var personaFoodieChip: String { isEn ? "Foodie" : "食光收集者" }
    static var personaFoodieLine: String {
        isEn ? "Every meal earns a snap — the table is your favorite viewfinder."
             : "每一顿饭，你都记得按下快门 — 餐桌是你最爱的取景框。"
    }
    static var personaParent: String { isEn ? "Chief Baby Photographer" : "把宝宝的每一天都装进相册" }
    static var personaParentChip: String { isEn ? "Baby Observer" : "宝宝观察员" }
    static var personaParentLine: String {
        isEn ? "First roll-over, first word — your lens never misses a moment."
             : "第一次翻身、第一次叫妈妈 — 你的镜头一刻也没有错过。"
    }
    static var personaWanderer: String { isEn ? "Weekend Wanderer" : "把周末走出一张照片地图" }
    static var personaWandererChip: String { isEn ? "Wanderer" : "周末漫游者" }
    static var personaWandererLine: String {
        isEn ? "Weekdays quiet, weekends alive — your lens has measured many places."
             : "工作日安静，周末出发 — 你用镜头丈量了很多地方。"
    }
    static var personaHoarder: String { isEn ? "Every inspiration kept" : "每条灵感都想留下来" }
    static var personaHoarderChip: String { isEn ? "Inspiration Hoarder" : "灵感囤积者" }
    static var personaHoarderLine: String {
        isEn ? "You screenshot everything you like — though you rarely open them again."
             : "看到喜欢的东西就截一张 — 只是后来很少再打开它们。"
    }
    static var personaMinimalist: String { isEn ? "Each shot intentional" : "镜头用得少，但每张都认真" }
    static var personaMinimalistChip: String { isEn ? "Minimalist" : "克制派" }
    static var personaMinimalistLine: String {
        isEn ? "You don't over-shoot — you press only when the moment is worth keeping."
             : "不贪多 — 你只在真正想记住的时刻，才会按下快门。"
    }

    // Persona tag names
    static var tagNightActive: String { isEn ? "Night active" : "夜间活跃" }
    static var tagScreenshotPro: String { isEn ? "Screenshot pro" : "截图高手" }
    static var tagDinnerDiary: String { isEn ? "Dinner diary" : "晚餐记录派" }
    static var tagWeekendTrip: String { isEn ? "Weekend trips" : "周末出游" }
    static var tagPortraitFan: String { isEn ? "Portrait fan" : "人像派" }
    static var tagDailyLog: String { isEn ? "Daily log" : "日常记录" }
    static var tagGrowthBook: String { isEn ? "Growth archive" : "成长档案" }
    static var tagFamilyChat: String { isEn ? "Family chat star" : "家庭群高产" }
    static var tagScenery: String { isEn ? "Scenery" : "风景派" }
    static var tagCityWalk: String { isEn ? "City walker" : "城市漫步" }
    static var tagCheckin: String { isEn ? "Check-in" : "打卡达人" }
    static var tagDriving: String { isEn ? "Driving" : "开车族" }
    static var tagWeChatClip: String { isEn ? "WeChat clippings" : "微信剪报" }
    static var tagRedNote: String { isEn ? "Rednote picks" : "小红书种草" }
    static var tagLongShot: String { isEn ? "Long screenshot" : "Safari 长截图" }
    static var tagAddressArchive: String { isEn ? "Address archive" : "地址存档" }
    static var tagLowProd: String { isEn ? "Low volume" : "低产" }
    static var tagCurated: String { isEn ? "Curated" : "精选派" }
    static var tagRareScreenshot: String { isEn ? "Rare screenshots" : "很少截图" }
    static var tagMorningRitual: String { isEn ? "Morning ritual" : "餐前仪式" }
    static var tagTopDownShooter: String { isEn ? "Top-down shooter" : "俯拍派" }
    static var tagHotpotSeason: String { isEn ? "Hotpot season" : "火锅季" }
    static var tagDessertLover: String { isEn ? "Dessert lover" : "甜品爱好者" }

    // Stat labels
    static var insightsStatPhotos: String { isEn ? "Photos" : "本月照片" }
    static var insightsStatVsLast: String { isEn ? "vs last" : "环比上月" }
    static var insightsStatPeak: String { isEn ? "Peak hour" : "快门高峰" }

    // MARK: Annual report
    static var annualEyebrow: String { isEn ? "Your album year" : "你的 · 相册年度" }
    static var annualCoverTitle: String { isEn ? "Panorama" : "全景" }
    static func annualCoverBody(_ count: Int) -> String {
        isEn ? "You took \(count.formatted()) photos this year. Let's look back." : "这一年，你拍了 \(count.formatted()) 张照片。一起来看看故事。"
    }
    static var annualSwipeRight: String { isEn ? "Swipe right →" : "向右滑动 →" }
    static var annualTotalLeading: String { isEn ? "This year, in total" : "这一年你共拍了" }
    static func annualTotalTrailing(_ sizeGB: Int) -> String {
        isEn ? "photos · \(sizeGB) GB" : "张照片 · 共 \(sizeGB) GB"
    }
    static func annualTopMonth(_ monthLabel: String, _ count: Int) -> String {
        isEn ? "\(monthLabel) was your biggest month · \(count.formatted()) photos" : "\(monthLabel)是你拍照最多的月份 · \(count.formatted()) 张"
    }
    static var annualTimeLeading: String { isEn ? "The hour you love most" : "你最爱按快门的时刻" }
    static var annualTimeBody: String { isEn ? "late nights, lamp light, before sleep" : "深夜、台灯、睡前的那一刻" }
    static var annualContentLeading: String { isEn ? "What you photographed most" : "你最爱拍什么" }
    static var annualPersonLeading: String { isEn ? "The person most in your album" : "相册里出现最多的人是" }
    static var annualPersonLabel: String { isEn ? "Baby" : "宝宝" }
    static func annualPersonBody(_ count: Int, _ pct: Int) -> String {
        isEn ? "\(count.formatted()) photos · \(pct)% of portraits" : "\(count.formatted()) 张照片 · 占人像 \(pct)%"
    }
    static var annualPersonLine: String {
        isEn ? "From first roll-over to first word — your lens never missed a moment." : "从第一次翻身，到第一次叫妈妈 — 你的镜头没有错过任何一刻。"
    }
    static var annualWasteLeading: String { isEn ? "But you also screenshot a lot" : "但其实，你也拍了很多截图" }
    static func annualWasteBody(_ total: Int, _ pct: Int) -> String {
        isEn ? "screenshots · \(pct)% of all photos" : "张截图，占全年照片 \(pct)%"
    }
    static var annualWasteRevisited: String { isEn ? "Actually revisited" : "但你真正回看的" }
    static var annualWasteMostForgotten: String { isEn ? "· most forgotten" : "· 大部分被遗忘" }
    static var annualWasteCta: String { isEn ? "Maybe it's time to lighten up." : "也许，是时候让相册轻一点。" }
    static func annualPersonaEyebrow(_ year: Int) -> String {
        isEn ? "Your \(year) persona" : "你的 \(year) 人格"
    }
    static func annualPersonaLabel(_ year: Int) -> String {
        isEn ? "\(year) · " : "\(year) · "
    }
    static var annualEndingWish: String {
        isEn ? "This year,<br/>you wrote your story in photos." : "这一年，<br/>你用相册写下了自己的故事。"
    }
    static var annualBtnSaveImage: String { isEn ? "Save as image" : "保存为图片" }
    static var annualBtnShare: String { isEn ? "Share" : "分享" }
    static var annualSwitcherHint: String {
        isEn ? "Switch persona to see a different ending" : "切换不同人格，看看会是什么结局"
    }
    static var annualClose: String { isEn ? "Close" : "关闭" }

    // Persona ending lines (line1 / line2)
    static var personaEndNightOwlL1: String {
        isEn ? "Once the day quiets, your lens starts working." : "白日喧闹过去，你的镜头才开始工作。"
    }
    static var personaEndNightOwlL2: String {
        isEn ? "May next year still have stories<br/>worth a late-night shutter." : "愿你的下一年，<br/>夜里依然有故事值得按快门。"
    }
    static var personaEndFoodieL1: String {
        isEn ? "Every meal — you remember to keep one frame." : "每一顿饭，你都记得留下一张。"
    }
    static var personaEndFoodieL2: String {
        isEn ? "May every meal in the year ahead<br/>still be worth remembering." : "愿你的下一年，<br/>每一顿饭，都值得记下来。"
    }
    static var personaEndParentL1: String {
        isEn ? "From first roll-over, to first word — captured." : "从第一次翻身，到第一次叫妈妈。"
    }
    static var personaEndParentL2: String {
        isEn ? "May you keep catching<br/>every small moment." : "愿你的下一年，<br/>依然不错过每一个小小的瞬间。"
    }
    static var personaEndWandererL1: String {
        isEn ? "Weekdays quiet, weekends you set out with your camera." : "工作日安静，周末你带着镜头出发。"
    }
    static var personaEndWandererL2: String {
        isEn ? "May new places still call your shutter<br/>in the year ahead." : "愿你的下一年，<br/>仍有新的地方，值得你按下快门。"
    }
    static var personaEndHoarderL1: String {
        isEn ? "You never miss a screenshot of what moves you." : "看到心动的东西，你从不吝啬按下截图。"
    }
    static var personaEndHoarderL2: String {
        isEn ? "May more of the inspiration you hoard<br/>actually be used." : "愿你的下一年，<br/>囤下的灵感，有更多真的被用上。"
    }
    static var personaEndMinimalistL1: String {
        isEn ? "You press only for moments truly worth it." : "不贪多，你只在真正值得的时刻按下快门。"
    }
    static var personaEndMinimalistL2: String {
        isEn ? "May every shot next year<br/>still be one you wanted to keep." : "愿你的下一年，<br/>每一张，都还是你真正想留下的。"
    }

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
    static var photosUnit: String { isEn ? "photos" : "张照片" }
    static var processing: String { isEn ? "Processing…" : "处理中…" }
    static var loading: String { isEn ? "Loading…" : "加载中…" }
    static var photoPermissionRequired: String { isEn ? "Photo access is required" : "需要相册权限" }
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
    static func dupDescPhotos(_ photoCount: Int, _ groupCount: Int) -> String {
        isEn ? "\(photoCount) photos in \(groupCount) groups" : "\(photoCount)张照片，\(groupCount)组"
    }
    static var screenshotClean: String { isEn ? "Screenshot Cleanup" : "截图清理" }
    static func screenshotDesc(_ n: Int) -> String { isEn ? "\(n) screenshots · Auto analyzed" : "\(n)张截图 · 已自动分析" }
    static var temporaryRecords: String { isEn ? "Temporary Records" : "临时记录" }
    static func temporaryDesc(_ n: Int) -> String { isEn ? "\(n) utility photos · likely one-time use" : "\(n)张工具性照片 · 多为一次性记录" }
    static var largeVideos: String { isEn ? "Large Videos" : "大视频文件" }
    static func videoDesc(_ n: Int) -> String { isEn ? "\(n) videos, sorted by size" : "\(n)个视频，按大小排序" }
    static var lowQualityPhotos: String { isEn ? "Low Quality Photos" : "低质量照片" }
    static func lowQualityDesc(_ n: Int) -> String { isEn ? "Blurry/Shaky/Exposure/Focus failed \(n)" : "模糊/抖动/曝光/对焦失败 \(n)张" }
    static var otherBehavior: String { isEn ? "Other Behavior" : "其他使用行为" }
    static func behaviorDesc(_ frozenCount: Int) -> String {
        isEn ? "\(frozenCount) remaining photos" : "\(frozenCount) 张其余照片"
    }
    static var favoritePhotos: String { isEn ? "Favorites" : "收藏照片" }
    static func favoriteDesc(_ n: Int) -> String { isEn ? "\(n) · Not selected by default" : "\(n)张 · 默认不选择" }
    static func liveDesc(_ n: Int) -> String { isEn ? "\(n) Live Photos · Convert to save ~55%" : "\(n)个 Live Photo · 转为静态可省约 55%" }

    // MARK: Health card
    static var totalPhotos: String { isEn ? "Total Photos" : "照片总数" }
    static var storageUsed: String { isEn ? "Storage Used" : "占用空间" }
    static var freeable: String { isEn ? "Freeable" : "可释放" }
    static var released: String { isEn ? "Freed" : "已释放" }
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
    static var myAchievementsTitle: String { isEn ? "My Cleaning" : "我的清理" }
    static var freedShort: String { isEn ? "Freed" : "已释放" }
    static var cleanupsShort: String { isEn ? "Cleanups" : "清理" }
    static var healthShort: String { isEn ? "Health" : "健康" }
    static var dataManagement: String { isEn ? "Data" : "数据管理" }
    static var recentlyDeleted: String { isEn ? "Recently Deleted" : "最近删除" }
    static var recentlyDeletedDesc: String { isEn ? "Open in Photos app" : "在系统相册中查看" }
    static var rescanLibrary: String { isEn ? "Rescan Library" : "重新扫描照片库" }
    static var rescanLibraryDesc: String { isEn ? "Re-score all photos" : "重新评分所有照片" }
    static var rescanConfirmTitle: String { isEn ? "Rescan Library?" : "确认重新扫描？" }
    static var rescanConfirmMessage: String { isEn ? "All photos will be re-scored. This may take a few minutes." : "将重新评分所有照片，可能需要几分钟。" }
    static var rescanAction: String { isEn ? "Rescan" : "重新扫描" }
    static var aboutSection: String { isEn ? "About" : "关于" }
    static var feedback: String { isEn ? "Feedback" : "意见反馈" }
    static var feedbackDesc: String { isEn ? "Send us an email" : "邮件联系我们" }
    static var rateApp: String { isEn ? "Rate the App" : "给我们评分" }
    static var rateAppDesc: String { isEn ? "Support us in the App Store" : "App Store 中支持一下" }
    static var privacyPolicy: String { isEn ? "Privacy Policy" : "隐私政策" }
    static var privacyPolicyDesc: String { isEn ? "How we handle your data" : "我们如何处理你的数据" }
    static var privacyPolicyBody: String {
        isEn ? "PhotoCleaner runs entirely on your device. All photo analysis, scoring and grouping happen locally — no photos, thumbnails, scores or metadata are uploaded to any server.\n\nThe app reads your Photos library only with your permission, and only writes to it when you explicitly delete or convert files. It does not collect personal information, location, or contact data.\n\nWhen you tap “Feedback”, your email client opens with our address pre-filled; the email is sent through your own account on your terms." :
        "PhotoCleaner 完全在你的设备上运行。所有照片分析、评分与分组都在本地完成，照片、缩略图、评分和元数据都不会上传到任何服务器。\n\n应用仅在你授权后访问相册，仅在你显式删除或转换文件时才会写入。我们不收集个人信息、位置或通讯录。\n\n点击「意见反馈」时，系统邮件会预填我们的地址，邮件通过你自己的账号发送，完全在你的掌控中。"
    }

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
    static func liveToStaticAction(_ count: Int, _ size: String) -> String {
        isEn ? "Live to Still \(count) items · Save \(size)" : "live转静态\(count)项，节省\(size)空间"
    }
    static var convertingLivePhoto: String { isEn ? "Converting Live Photos…" : "正在转换 Live Photo…" }
    static var liveConvertFailed: String { isEn ? "Conversion failed. Please try again." : "转换失败，请重试" }
    static func liveConvertPartial(_ success: Int, _ failed: Int) -> String {
        isEn ? "Converted \(success), failed \(failed). Please retry failed items." : "已转换\(success)项，失败\(failed)项，请重试失败项"
    }
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
    static var cancelMerge: String { isEn ? "Cancel Merge" : "取消合并" }
    static var cancelMergeHint: String { isEn ? "Swipe left on a group card to cancel merge. Photos won't be deleted and will move to \"Other Behavior\"." : "左滑整组卡片可取消合并，不删除，并转入“其他使用行为”" }
    static var best: String { isEn ? "Best" : "最佳" }
    static func screenshotsDone(_ n: Int) -> String { isEn ? "\(n) screenshots" : "\(n)张截图" }
    static var screenshotTitle: String { isEn ? "Screenshot Cleanup" : "截图清理" }
    static func screenshotSubtitle(_ total: Int, _ rec: Int) -> String { isEn ? "\(total) · Recommend delete \(rec)" : "\(total)张 · 推荐删 \(rec)张" }
    static var autoSelectedLow: String { isEn ? "Low quality screenshots auto-selected, adjust manually" : "已自动选中低质量截图，可手动调整" }
    static func temporaryDone(_ n: Int) -> String { isEn ? "\(n) temporary records" : "\(n)张临时记录" }
    static var temporaryTitle: String { isEn ? "Temporary Records" : "临时记录" }
    static func temporarySubtitle(_ total: Int, _ rec: Int) -> String { isEn ? "\(total) · Recommend delete \(rec)" : "\(total)张 · 推荐删 \(rec)张" }
    static var temporaryBanner: String { isEn ? "Utility photos (receipts, docs, whiteboards, QR, notes) are usually one-time captures" : "工具性照片（收据、文档、白板、二维码、备注）通常是一次性记录，可优先清理" }
    static var all: String { isEn ? "All" : "全部" }
    static func classifying(_ pct: Int) -> String { isEn ? "Classifying \(pct)%" : "分类中 \(pct)%" }
    static func videosDone(_ n: Int) -> String { isEn ? "\(n) videos" : "\(n)个视频" }
    static var videoTitle: String { isEn ? "Large Videos" : "大视频文件" }
    static func videoSubtitle(_ n: Int) -> String { isEn ? "\(n) videos, sorted by size" : "\(n)个视频，按大小排序" }
    static var videoBanner: String { isEn ? "Two-column view; tap video to play inline; mark with circle below to batch delete" : "两列浏览；点视频原位小窗播放；点下方圆圈标记后可批量删除" }
    static var unknownDate: String { isEn ? "Unknown date" : "未知日期" }
    static func lowQualityDone(_ n: Int) -> String { isEn ? "\(n) low quality photos" : "\(n)张低质量照片" }
    static var lowQualityTitle: String { isEn ? "Low Quality" : "低质量照片" }
    static func lowQualitySubtitle(_ total: Int, _ rec: Int) -> String { isEn ? "\(total) · Recommend delete \(rec)" : "\(total)张 · 推荐删 \(rec)张" }
    static func favoritesDone(_ n: Int) -> String { isEn ? "\(n) favorite photos" : "\(n)张收藏照片" }
    static var favoritesTitle: String { isEn ? "Favorites" : "收藏照片" }
    static func favoritesSubtitle(_ n: Int) -> String { isEn ? "\(n) · Not selected by default" : "\(n)张 · 默认不勾选" }
    static var favoriteBanner: String { isEn ? "Favorites not selected by default to avoid accidental deletion" : "收藏照片默认不选，避免误删重要内容" }
    static func photosDone(_ n: Int) -> String { isEn ? "\(n) photos" : "\(n)张照片" }
    static var behaviorTitle: String { isEn ? "Cold Photos" : "冷照片" }
    static func behaviorSubtitle(_ frozen: Int, _ cold: Int) -> String {
        isEn ? "\(frozen) frozen · \(cold) cold" : "🥶 \(frozen) 张极冷 · ❄️ \(cold) 张冷"
    }
    static func behaviorInsightBanner(_ frozenCount: Int, _ maxYears: Int) -> String {
        isEn
            ? "These \(frozenCount) photos haven't been touched for \(maxYears)+ years."
            : "这 \(frozenCount) 张照片你已经 \(maxYears) 年没碰过了，是清理的好起点。"
    }
    static var behaviorColdBanner: String { isEn ? "Lightly touched — review before deciding." : "偶尔有过操作，建议浏览后再决定。" }
    static var coldTierFrozen: String { isEn ? "Frozen" : "极冷" }
    static var coldTierCold: String { isEn ? "Cold" : "冷" }
    static var coldTierFrozenDetail: String { isEn ? "Never edited · Untouched for years" : "从没编辑过 · 多年没动过" }
    static var coldTierColdDetail: String { isEn ? "Rarely touched" : "基本没碰过" }
    static var markedDeleteToggle: String { isEn ? "Marked for delete · Tap again to cancel" : "已标记删除 · 再次点击取消" }
    static var markDelete: String { isEn ? "Mark Delete" : "标记删除" }

    // MARK: Timeline
    static var timeline: String { isEn ? "Timeline" : "时间线" }
    static var listMode: String { isEn ? "List" : "列表" }
    static var calendarMode: String { isEn ? "Calendar" : "日历" }
    static var waterfallMode: String { isEn ? "Waterfall" : "瀑布" }
    static var filterAll: String { isEn ? "All" : "全部" }
    static var filterPhotos: String { isEn ? "Photos" : "照片" }
    static var filterLive: String { isEn ? "Live" : "动图" }
    static var filterVideos: String { isEn ? "Videos" : "视频" }
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
    static var deleteNow: String { isEn ? "Delete Now" : "立即删除" }
    static func timelineLongPressDeleteSingleConfirm(_ size: String) -> String {
        if isEn {
            return "Delete this photo (\(size))?\n\(deleteAlertMessage)"
        } else {
            return "确认删除这张照片（\(size)）？\n\(deleteAlertMessage)"
        }
    }
    static var infoSize: String { isEn ? "Size" : "大小" }
    static var infoFormat: String { isEn ? "Format" : "格式" }
    static var infoTime: String { isEn ? "Time" : "时间" }
    static var infoLocation: String { isEn ? "Location" : "地点" }
    static var infoResolution: String { isEn ? "Resolution" : "分辨率" }
    static var infoFrameRate: String { isEn ? "FPS" : "帧率" }

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

    // MARK: Onboarding
    static var onboardingNext: String { isEn ? "Next" : "下一步" }
    static var onboardingSkip: String { isEn ? "Skip" : "跳过" }
    static var onboardingStart: String { isEn ? "Get Started" : "开始使用" }

    static var onboardingFeature1Title: String { isEn ? "Free Up\nStorage Space" : "释放\n存储空间" }
    static var onboardingFeature1Desc: String {
        isEn ? "Find duplicate photos and large videos.\nClear gigabytes in one tap."
             : "找出重复照片和大视频\n一键清理几个 GB"
    }

    static var onboardingFeature2Title: String { isEn ? "Smart Analysis\nof Every Photo" : "智能识别\n每张照片" }
    static var onboardingFeature2Desc: String {
        isEn ? "Screenshot classification, face protection,\nand quality scoring."
             : "截图分类、人脸保护\n给每张照片质量评分"
    }

    // Onboarding — feature-page atoms (new)
    static var onboardingFeature1Badge: String { isEn ? "−12 GB" : "−12 GB" }
    static var onboardingFeature2Score: String { isEn ? "92" : "92" }
    static var onboardingFeature2CategoryTag: String { isEn ? "Portrait · Sharp" : "人像 · 清晰" }

    // Onboarding — page 4 (scan) titles (new)
    static var onboardingScanTitle: String { isEn ? "Scan Your Library" : "开始扫描您的照片库" }
    static var onboardingScanDesc: String { isEn ? "Takes about 20 seconds.\nResults appear as we go." : "大约需要 20 秒\n结果会陆续呈现" }

    static var onboardingPhotoTitle: String { isEn ? "Access Your Photos" : "访问您的相册" }
    static var onboardingPhotoDesc: String {
        isEn ? "PhotoCleaner needs access to your photo library to analyze and clean up. All processing is done on-device — nothing is uploaded."
             : "PhotoCleaner 需要访问您的相册进行分析清理。所有处理均在本地完成，不会上传任何数据。"
    }
    static var onboardingPhotoAction: String { isEn ? "Allow Photo Access" : "允许访问相册" }
    static var onboardingPhotoDone: String { isEn ? "Access Granted" : "已获得授权" }
    static var onboardingPhotoDeniedHint: String {
        isEn ? "Please go to Settings → PhotoCleaner to grant photo access."
             : "请前往 系统设置 → PhotoCleaner 开启相册访问权限。"
    }
}
