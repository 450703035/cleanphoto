# 引导页重新设计 · Design Spec

**Date:** 2026-05-16
**Status:** Design approved, pending implementation
**Scope:** 重构 `PhotoCleaner/Views/Onboarding/OnboardingView.swift`，使引导页视觉与 App 主体 (HomeView / ScanIdleView) 的 Apple 第一方语言保持一致。

---

## 1. 动机

当前引导页（5 页）与 App 其余部分视觉脱节：
- 使用紫色渐变 + 红/黄/绿四色 mock 信息图（瀑布流方块、迷你 tag、分数进度条），与 App 单一蓝色 `#0071e3` + 真双模式的克制语言不符
- 信息密度过高，留白不足
- 通知权限页价值不大（PhotoCleaner 没有需要长期推送的场景），徒增流程长度
- 视觉抽象，看不出"清理"实际做什么

## 2. 目标

1. **视觉语言对齐** — 引导页与 HomeView / ScanIdleView 同源（蓝色光晕 + 单一焦点 + 大量留白 + pill 按钮）
2. **流程精简** — 从 5 页降到 4 页，去掉通知权限页
3. **价值具象** — 用真照片缩略图 mock 替代抽象方块，让用户一眼看懂 App 在做什么
4. **保留双模式** — 浅色 / 深色都成立

## 3. 流程

| # | 页面 | 类型 | 主操作 |
|---|---|---|---|
| 1 | 释放空间 | 功能介绍 | 「继续」 |
| 2 | 智能分析 | 功能介绍 | 「继续」 |
| 3 | 相册权限 | 系统权限 | 「允许访问相册」/「稍后再说」 |
| 4 | 首次扫描 | 实际扫描 | 「开始扫描」→ 自动完成进入 App |

**移除：** 通知权限页（原 page 2 of 5）。

## 4. 视觉规范

### 4.1 通用骨架

每页布局自上而下：
```
[ Top safe area ]
[ Spacer ]
[ Hero 视觉  ── 180-220pt 高 ]
[ Spacer 24pt ]
[ 标题（28pt semibold，居中，可两行）]
[ Spacer 10pt ]
[ 副文案（15pt，textSecondary，居中，最多两行）]
[ Spacer ]
[ 主 CTA（功能页右下小 pill；权限/扫描页全宽 pill）]
[ Page indicator（蓝色长条 + 灰色圆点）]
[ Bottom safe area ]
```

### 4.2 设计 tokens（复用 `AppColors` / `AppTypography` / `AppShape`）

- 背景：`AppColors.darkBG`
- 主色：`AppColors.purple` (实为 `#0071e3`)
- 副色 / 信号绿：`AppColors.green`（仅 page 2 评分徽章）
- 文字：`textPrimary` / `textSecondary` / `textTertiary`
- 按钮：`ApplePrimaryButtonStyle`（已有）
- 圆角：照片 cell 6pt、卡片 10pt、pill 980pt
- 标题字号：28pt semibold（沿用现状）
- 副文案：15pt regular（替代当前 17pt body）

### 4.3 Hero 视觉 — 统一光晕

每页 hero 区都有一个共同元素：**蓝色径向渐变光晕**（模糊 4pt），作为 hero 视觉的"地"。

```swift
RadialGradient(
    colors: [AppColors.purple.opacity(0.32), AppColors.purple.opacity(0.02)],
    center: .init(x: 0.5, y: 0.4),
    startRadius: 0,
    endRadius: 110
)
.blur(radius: 4)
```

### 4.4 各页 Hero 详细

#### Page 1 — 释放空间

**视觉:** 3×3 照片网格 mock，部分 cell 是"已清理"状态（虚位 / 灰阶 dimmed），整体右上挂一个 `−12 GB` 蓝色 pill 徽章。

- 网格容器宽 150pt，cell 间距 3pt，cell 圆角 6pt
- 9 个 cell 状态：4 normal、2 dimmed (opacity 0.22 + grayscale)、3 gone（透明 + 虚线描边 `subtleBorder`）
- 徽章：`#0071e3` 填充，白字 700 weight 10pt，shadow `rgba(0,113,227,0.5)` 14pt blur
- 照片缩略图：打包 6-9 张内置静态占位图（`Assets.xcassets/onboardingPhotos/*`），授权前展示

**标题:** "释放\n存储空间"
**副文案:** "找出重复照片和大视频\n一键清理几个 GB"
**CTA:** 右下小 pill「继续」

#### Page 2 — 智能分析

**视觉:** 三张照片堆叠（fan effect），最底两张半透明旋转，最上一张正向，叠加两个徽章。

- 堆叠尺寸：130×160pt，圆角 10pt
- 后两张 transform：旋转 ±8°、平移 8-12pt、opacity 0.6 / 0.85
- 前景照片右下："92" 评分徽章（绿色 `#22c55e`，深色半透明背景 + backdrop blur，0.5pt 绿边）
- 前景照片左上："人像 · 清晰" 蓝色 tag（`#0071e3` 90% opacity，白字 9pt 600）

**标题:** "智能识别\n每张照片"
**副文案:** "截图分类、人脸保护\n给每张照片质量评分"
**CTA:** 右下小 pill「继续」

#### Page 3 — 相册权限

**视觉:** 单一图标 — 蓝色渐变方块（80×80pt，圆角 20pt，`LinearGradient(#0071e3 → #2997ff)`）内嵌系统照片符号 (`photo.on.rectangle.angled`)，下方有 shadow `rgba(0,113,227,0.4)` 30pt blur。

**标题:** "访问您的相册"
**副文案:** "PhotoCleaner 需要访问您的照片才能分析和清理。\n所有处理在本地完成，不会上传。"
**主 CTA:** 全宽 pill「允许访问相册」（授权后变 ✓「已获得授权」disabled，自动跳下一页）
**次 CTA:** 灰色文字"稍后再说"（点击 → 进入 page 4）
**拒绝态:** 出现琥珀色 caption 提示去"设置 > 隐私"开启

#### Page 4 — 首次扫描

**视觉:** 复用现有 `ScanIdleView`（同心圆 + 蓝色弧线 + 中心 camera 图标）。无需重做，直接嵌入。

**标题 + 副文案:** 已存在于 `ScanIdleView`，不重复添加。
**主 CTA:** 全宽 pill「开始扫描」 → 触发 `scanVM.startScan()` → 切到 `ScanningView` → 20 秒后调用 `onFinish()` 完成引导。

### 4.5 分页指示器

四页统一：底部 28pt 内边距处一行 HStack，指示器固定居左。
- Page 1 / 2：同行右侧放小 pill「继续」CTA
- Page 3 / 4：CTA 改为全宽 pill，叠在指示器上方 14pt；指示器同行右侧留空
- 当前页：宽 14pt × 高 4pt 圆角 3pt 长条，`AppColors.purple` 填充
- 其他页：4pt 圆点，`textTertiary` 40% opacity
- 间距 4pt，过渡 `.easeInOut(0.25)`

### 4.6 动画 / 转场

- 页面切换：`TabView .page(indexDisplayMode: .never)`，左右滑动（沿用现有）
- Hero 入场：`scaleEffect 0.85 → 1.0` + `opacity 0 → 1`，`easeOut 0.6s delay 0.15s`（沿用现有）
- 标题/副文案入场：`offset y: 30 → 0` + `opacity 0 → 1`，同 timing（沿用现有）

## 5. 结构 / 实现拆解

`OnboardingView.swift` 重写为 4 个子 View，全部共享一个 `OnboardingHero` 容器，避免重复布局代码。

```
OnboardingView                  // 容器、TabView、底部指示器/按钮
├── OnboardingHero              // 通用骨架：halo + hero slot + title + desc
├── FreeSpacePage               // page 1，提供 hero = PhotoGridMock
├── SmartAnalysisPage           // page 2，提供 hero = PhotoStackMock
├── PhotoAccessPage             // page 3，提供 hero = GradientIcon
└── StartScanPage               // page 4，复用 ScanIdleView/ScanningView
```

**`OnboardingHero<Content: View>`** — 接受 `hero: () -> Content`、`title: String`、`desc: String`，输出统一布局。Halo 由 hero 容器自行包含（让每页能微调光晕大小）。

**`PhotoGridMock`** — 接受 `assets: [Image]`（来自 `Assets.xcassets/onboardingPhotos`），按预设状态数组（normal/dim/gone）渲染 3×3 网格 + 右上徽章。

**`PhotoStackMock`** — 接受 `assets: [Image]` (3 张) + `scoreLabel: String` + `categoryTag: String`，渲染堆叠 + 双徽章。

**`GradientIcon`** — 接受 `systemName: String`，渲染蓝色渐变方块 + 内嵌 SF Symbol。

**Page indicator + Next CTA** — 抽到 `OnboardingBottomBar(currentPage: Int, totalPages: Int, showNext: Bool, onNext: () -> Void)`。

## 6. 资源 / 文案

### 6.1 新增图片资源

`PhotoCleaner/Resources/Assets.xcassets/OnboardingPhotos/`：
- 9 张 200×200 jpg（建议从 Unsplash 选择风格统一的人像 / 风景 / 食物 / 宠物，免授权），用于 page 1 网格和 page 2 堆叠
- 命名 `onboarding_photo_1.jpg` … `onboarding_photo_9.jpg`
- 同时提供 `@2x` `@3x`（或单一 universal）

### 6.2 L10n 字符串调整（`PhotoCleaner/App/L10n.swift`）

新增 / 改写：

| Key | EN | CN |
|---|---|---|
| `onboardingFeature1Title` | "Free Up Space" | "释放存储空间" |
| `onboardingFeature1Desc` | "Find duplicate photos and large videos.\nClear gigabytes in one tap." | "找出重复照片和大视频\n一键清理几个 GB" |
| `onboardingFeature1Badge` | "−12 GB" | "−12 GB" |
| `onboardingFeature2Title` | "Smart Analysis" | "智能识别每张照片" |
| `onboardingFeature2Desc` | "Screenshot classification, face protection,\nand quality scoring for every photo." | "截图分类、人脸保护\n给每张照片质量评分" |
| `onboardingFeature2ScoreLabel` | "92" | "92" |
| `onboardingFeature2CategoryTag` | "Portrait · Sharp" | "人像 · 清晰" |
| `onboardingScanTitle` | "Scan Your Library" | "开始扫描您的照片库" |
| `onboardingScanDesc` | "Takes about 20 seconds.\nResults appear as we go." | "大约需要 20 秒\n结果会陆续呈现" |

**移除:** `onboardingNotifTitle` / `onboardingNotifDesc` / `onboardingNotifAction` / `onboardingNotifDone`（通知权限页废弃，相关代码连带删除）。

**保留并复用:** `onboardingPhotoTitle` / `onboardingPhotoDesc` / `onboardingPhotoAction` / `onboardingPhotoDone` / `onboardingPhotoDeniedHint` / `onboardingNext` / `onboardingSkip` / `onboardingStart`。

`onboardingScreenshotLabel` / `onboardingScoreLabel` / `onboardingTagChat/Order/Code/Other` 不再需要 — 一并移除。

## 7. 行为 / 状态

- 进入引导 (`hasCompletedOnboarding == false`) → page 1
- Page 1/2 右下「继续」→ currentPage++
- Page 3「允许访问相册」→ 调 `PHPhotoLibrary.requestAuthorization(for: .readWrite)`
  - 成功（authorized / limited）→ 0.6s 后自动 `goNext()`
  - 拒绝 → 显示 `onboardingPhotoDeniedHint`，「稍后再说」改为「继续」
- Page 3「稍后再说」→ currentPage++（允许跳过权限进 page 4，但 page 4 扫描会显示无权限提示，沿用现状）
- Page 4「开始扫描」→ `scanVM.startScan()`，UI 切到 `ScanningView`，20s + 短暂等待后调 `onFinish()` 关闭引导

进入引导前已授权（`PHPhotoLibrary.authorizationStatus == .authorized || .limited`）：
- Page 3 加载时 `authorized = true`、CTA 显示「已获得授权」disabled，「稍后再说」改为「继续」（沿用现状）

## 8. 非目标 / Out of scope

- 国际化新增语言（仅维护 EN/CN，与现状一致）
- 引导期间播放内置视频或动效大图
- 添加"跳过整个引导"的顶级按钮 — 仍要求用户完成 4 页
- 重写 `ScanIdleView` / `ScanningView`（仅嵌入，不改造）
- 动效深度定制（仅维持现有 ease-out 入场）

## 9. 兼容性 / 风险

- 旧 L10n key 删除会让 `Localizable.strings`（如果存在）短暂缺失映射 — 仓库目前使用代码内 L10n.swift（基于 `isEn` flag），影响为零
- 9 张内置图增加约 200-400KB bundle 大小，可接受
- `OnboardingView.totalPages` 常量从 5 改为 4，注意页面索引同步
- 已完成引导的老用户不受影响（`hasCompletedOnboarding` 已存在 UserDefaults）
- 新引导期已经请求过相册权限，但用户没在引导期内同意 → 进 App 后由 HomeView 已有逻辑兜底（沿用现状）

## 10. 验收标准

1. 引导从启动到结束 ≤ 4 个轻扫动作（不算扫描期间等待）
2. 浅色 / 深色模式下所有 hero 视觉、徽章、按钮、文字对比度均 ≥ WCAG AA
3. 与首页 (`HomeView` idle 态) 同屏截图对比，色彩 / 字体 / 圆角 / 留白节奏视觉一致
4. iOS 16 / 17 / 18 各设备尺寸下 hero 不被裁剪、文案不溢出（iPhone SE 3 / iPhone 16 Pro Max / iPad）
5. 无通知权限页相关代码残留（包括 L10n keys / state）
6. `OnboardingView.swift` 行数较改造前下降（合并重复代码）
