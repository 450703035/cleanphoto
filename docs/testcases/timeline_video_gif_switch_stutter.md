# Timeline 瀑布页 视频暂停后切换动图/视频卡顿 - 测试用例

## 问题描述
- 场景：时间线瀑布页
- 现象：视频播放后暂停，再切换动图和视频时出现卡顿
- 关联日志关键字：
  - `Error Domain=com.apple.accounts Code=7`
  - `kFigSandboxError_ExtensionDenied`
  - `kFigProcessStateMonitorError_AllocFailed`
  - `kCMBaseObjectError_Invalidated`

## 测试环境
- App: `PhotoCleaner` (Debug, iOS Simulator)
- 设备: iPhone 17 Pro (iOS 26.4)
- 测试数据:
  - 1 个 MP4 视频（8 秒）
  - 1 个 GIF 动图（4 秒）

## 通过标准
- 交互流畅，切换过程中无明显掉帧/卡顿（主观可感知阈值：无 > 0.5s 卡死）
- 视频可正常播放/暂停/继续
- 切换后无异常黑屏、花屏、卡住不响应
- 日志中无持续性错误风暴（同一错误在短时间内连续刷屏）

## 用例清单

### TC-01 基本复现路径（视频 -> 暂停 -> 动图 -> 视频）
- 前置条件：
  - 已进入「时间线」->「瀑布」模式
  - 当前列表内同时有视频和 GIF/动图资源
- 步骤：
  1. 点击一个视频卡片开始播放
  2. 再次点击同一视频暂停
  3. 立即点击相邻 GIF/动图卡片
  4. 再立即点击另一个视频卡片
- 预期：
  - 切换过程顺滑
  - 新视频能在 1 秒内开始播放
  - 无明显 UI 卡顿和播放状态错乱

### TC-02 快速切换压力（A 视频 <-> B 视频）
- 前置条件：同屏至少两个视频卡片
- 步骤：
  1. 播放视频 A
  2. 1 秒内切到视频 B
  3. 重复 10 次
- 预期：
  - 只有当前选中视频播放
  - 不出现多个视频音画并发
  - 不出现明显卡顿、音画不同步

### TC-03 播放中滚动后切换
- 前置条件：瀑布流有足够内容可滚动
- 步骤：
  1. 播放一个视频
  2. 立刻上下滚动列表 2~3 屏
  3. 停止滚动后点击动图，再点击视频
- 预期：
  - 滚动不造成播放器异常残留
  - 切换后仍可正常播放
  - 无白屏/黑屏卡片

### TC-04 iCloud/网络资源回源场景
- 前置条件：至少一个视频资源需网络回源
- 步骤：
  1. 点击该视频开始加载并播放
  2. 暂停后切换到动图，再切换回视频
- 预期：
  - 加载中有可感知反馈（loading）
  - 回源后可恢复播放
  - 无异常报错风暴

### TC-05 长时稳定性（3 分钟）
- 前置条件：已进入可复现页面
- 步骤：
  1. 按 TC-01/TC-02 操作循环 3 分钟
  2. 观察 UI 流畅度与日志
- 预期：
  - 无明显性能劣化
  - 无崩溃、无卡死

## 本次执行记录（2026-04-17）

### 已完成
- `xcodebuild` 编译通过（Debug, iOS Simulator）
- 模拟器启动成功并安装/拉起 App
- 已注入测试媒体（MP4 + GIF）到模拟器相册
- 已设置跳过 Onboarding 的本地开关：`hasCompletedOnboarding = true`
- 已在构建产物上启用 `PHPhotoLibraryPreventAutomaticLimitedAccessAlert=true`，避免 Limited Library 自动弹窗阻塞

### 当前阻塞
- 当前会话无法执行“点击级”自动化交互（切换到时间线 tab、点击视频/GIF 卡片）：
  - `osascript` 键盘事件被系统拒绝（无按键发送权限）
  - 当前 MCP 交互工具依赖 `simctl/idb`，该会话中不可用（`xcode-select` 非 Xcode 开发者目录）

### 结论
- 当前已完成“可运行、可装包、可准备测试数据”的基础验证
- 受系统弹窗交互阻塞，尚未完成 TC-01~TC-05 的完整端到端点击验证

## 代码级高风险点（用于后续排查）
- 文件：`PhotoCleaner/Views/Timeline/TimelineView.swift`
- 现象：
  - `ensurePlayerReadyAndPlay()` 在异步请求 `AVAsset` 返回后，未再次校验当前 `isVideoPlaying` 状态就直接 `newPlayer.play()`
  - 在快速切换视频/动图时，存在旧请求回调“晚到”并触发播放的竞态风险，可能导致卡顿或状态错乱
