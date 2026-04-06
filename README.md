# PhotoCleaner — iOS App

AI驱动的相册管理助手，帮助用户智能清理无用照片、释放存储空间。

## 项目结构

```
PhotoCleaner/
├── App/
│   ├── PhotoCleanerApp.swift      # @main 入口
│   ├── ContentView.swift          # Tab bar 根视图
│   └── AppConstants.swift         # 颜色、配置常量
├── Models/
│   └── Models.swift               # 所有数据模型
├── Services/
│   └── PhotoLibraryService.swift  # PHAsset 访问 + AI 评分
├── ViewModels/
│   ├── ScanViewModel.swift        # 首页扫描逻辑
│   └── LibraryViewModel.swift     # 时间线分组逻辑
└── Views/
    ├── Shared/
    │   └── SharedComponents.swift  # 通用 UI 组件
    ├── Home/
    │   ├── HomeView.swift          # 首页（扫描三态 + 结果）
    │   └── CleanDetailViews.swift  # 重复/截图/视频/低质量详情页
    ├── Timeline/
    │   └── TimelineView.swift      # 时间线 + 日历视图
    ├── Tools/
    │   └── ToolsView.swift         # 工具箱 + 逐张滑动删除
    └── Settings/
        └── SettingsView.swift      # 设置页
```

## 如何在 Xcode 中打开

1. 打开 Xcode 14+
2. 新建项目：File → New → Project → App
   - Product Name: `PhotoCleaner`
   - Bundle Identifier: `com.yourname.photocleaner`
   - Interface: SwiftUI
   - Language: Swift
   - Minimum Deployments: iOS 16.0
3. 将本项目所有 `.swift` 文件拖入对应 Group 中
4. 将 `Info.plist` 内容合并到项目的 Info.plist
5. 选择真机运行（模拟器的 Photos 权限受限）

## 核心功能说明

### AI 评分系统 (PhotoLibraryService)
- **模糊检测**：Laplacian 算子方差，方差 < 50 判定为模糊
- **曝光分析**：CIAreaAverage 计算平均亮度，< 30 欠曝，> 220 过曝
- **时间权重**：照片越旧，评分越低（每年扣 4 分）
- **IQA 加成**：VNClassifyImageRequest 审美评分
- **评分范围**：5–99，低于 40 分自动推荐删除

### 首页扫描流程
1. 请求 PHPhotoLibrary 权限
2. 批量拉取所有 PHAsset
3. 逐张评分（后台并发）
4. 检测重复（hash / 时间窗口）
5. 检测相似（60 秒内拍摄的同场景）
6. 生成清理方案

### 时间线
- 列表视图：年 → 月 → 相册文件夹（按天分组）
- 日历视图：月份网格，有照片的日期显示数量/大小/评分色点
- 点击任意格子进入当日照片选择页

### 逐张滑动删除（Tools → 逐张决策）
- 左滑 → 删除（红色水印）
- 右滑 → 保留（绿色水印）
- 点击 ↩ → 撤销上一步
- 支持无限次撤销

## 权限说明

```
NSPhotoLibraryUsageDescription
NSPhotoLibraryAddUsageDescription
```

两个 key 均已写入 Info.plist，首次启动会弹出系统授权弹窗。

## 依赖

- SwiftUI（iOS 16+）
- Photos Framework
- Vision Framework（IQA 评分）
- CoreImage（模糊/曝光检测）
- AVFoundation（视频压缩）

**无需任何第三方库**，纯苹果原生 SDK。

## 商业化扩展

| 功能 | 免费 | Pro |
|------|------|-----|
| 扫描分析 | ✅ | ✅ |
| 重复检测 | ✅ | ✅ |
| 手动删除 | ✅ | ✅ |
| 自动勾选 | ❌ | ✅ |
| 视频压缩 | ❌ | ✅ |
| 照片压缩 | ❌ | ✅ |
| 智能相册 | ❌ | ✅ |
| 批量删除 | ❌ | ✅ |
