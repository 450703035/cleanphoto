# Onboarding Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the existing 5-page onboarding with a 4-page Apple-style flow whose visual language matches `HomeView` / `ScanIdleView`.

**Architecture:** Decompose `OnboardingView.swift` into one container + four page views + small set of reusable components (`OnboardingHero`, `GradientIcon`, `OnboardingBottomBar`, `PhotoGridMock`, `PhotoStackMock`). Reuse the existing `AppColors` / `AppTypography` / `ApplePrimaryButtonStyle` tokens. Embed the existing `ScanIdleView` / `ScanningView` unchanged for page 4. Drop the notification-permission page.

**Tech Stack:** SwiftUI, iOS 16+, no third-party deps. Built with Xcode 15+. No XCTest target exists in the repo — verification is build (`xcodebuild`) + visual run in Simulator.

**Spec reference:** [docs/superpowers/specs/2026-05-16-onboarding-redesign-design.md](../specs/2026-05-16-onboarding-redesign-design.md)

---

## File Structure

| File | Purpose | Disposition |
|---|---|---|
| `PhotoCleaner/Views/Onboarding/OnboardingView.swift` | Container: `TabView`, page state, finish handoff | Rewrite |
| `PhotoCleaner/Views/Onboarding/OnboardingComponents.swift` | `OnboardingHero`, `GradientIcon`, `OnboardingBottomBar` | New |
| `PhotoCleaner/Views/Onboarding/OnboardingMocks.swift` | `PhotoGridMock`, `PhotoStackMock`, `PhotoCellState` | New |
| `PhotoCleaner/Views/Onboarding/OnboardingPages.swift` | `FreeSpacePage`, `SmartAnalysisPage`, `PhotoAccessPage`, `StartScanPage` | New |
| `PhotoCleaner/App/L10n.swift` | Onboarding string keys | Modify (add/remove) |
| `PhotoCleaner/Resources/Assets.xcassets/OnboardingPhotos/*` | 9 photo imagesets | New |

Splitting components / mocks / pages into three files keeps each unit under ~200 lines and makes the responsibilities clear: components are layout primitives, mocks are page-1/2 hero illustrations, pages assemble them.

---

## Pre-flight

- [x] **Step P1: Confirm Xcode is reachable**

The repo builds with Xcode 26.4 / iOS 26 SDK. To avoid touching `xcode-select` (sudo required), every `xcodebuild` invocation in this plan is prefixed with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`. Already verified working — `Xcode 26.4 (Build 17E192)`.

- [x] **Step P2: Baseline build green** — already verified `** BUILD SUCCEEDED **` against `iPhone 17` simulator with `CODE_SIGNING_ALLOWED=NO`.

---

## Task 1: Add onboarding photo assets

**Files:**
- Create: `PhotoCleaner/Resources/Assets.xcassets/OnboardingPhotos/Contents.json`
- Create: `PhotoCleaner/Resources/Assets.xcassets/OnboardingPhotos/onboarding_photo_{1..9}.imageset/` (9 imagesets)

The 9 photos drive page 1 (3×3 grid, 4 normal + 2 dimmed + 3 absent cells) and page 2 (3 stacked cards). Sourced from Unsplash with permissive licensing.

- [ ] **Step 1.1: Create folder + folder Contents.json**

Create `PhotoCleaner/Resources/Assets.xcassets/OnboardingPhotos/Contents.json`:
```json
{
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

Note: we deliberately omit `"properties": {"provides-namespace": true}` so the imageset names (`onboarding_photo_1` etc.) can be referenced from SwiftUI without a folder prefix — the page code in Task 5 does exactly that.

- [ ] **Step 1.2: Source 9 square photos**

Download these to `/tmp/onboarding-src/` as `1.jpg` … `9.jpg`, each ≥400×400 cropped square, ≤80 KB after compression:

| # | Suggested subject | Used on page | State on page 1 grid |
|---|---|---|---|
| 1 | Portrait (close-up face) | 1 + 2-front | grid[0]=normal |
| 2 | Landscape (mountain/sunset) | 1 | grid[2]=normal |
| 3 | Pet (dog or cat) | 1 + 2-mid | grid[4]=normal |
| 4 | Food (overhead plate) | 1 | grid[7]=normal |
| 5 | City / architecture | 1 + 2-back | grid[3]=dim |
| 6 | Beach / nature | 1 | grid[8]=dim |
| 7 | Coffee / lifestyle | unused-spare | — |
| 8 | Plant / flower | unused-spare | — |
| 9 | Sky / minimal | unused-spare | — |

Suggested Unsplash search URLs (use any photo, save attribution in a comment in the imageset if required by your license setup):
- https://unsplash.com/s/photos/portrait
- https://unsplash.com/s/photos/landscape
- https://unsplash.com/s/photos/dog
- https://unsplash.com/s/photos/food-flatlay
- https://unsplash.com/s/photos/architecture
- https://unsplash.com/s/photos/beach
- https://unsplash.com/s/photos/coffee
- https://unsplash.com/s/photos/plant
- https://unsplash.com/s/photos/sky

Resize and compress each to ≤400×400, ≤80 KB:
```bash
mkdir -p /tmp/onboarding-src
# put your 9 jpgs there as 1.jpg ... 9.jpg, then:
for i in {1..9}; do
  sips -s format jpeg -Z 400 "/tmp/onboarding-src/$i.jpg" --out "/tmp/onboarding-src/${i}_resized.jpg" >/dev/null
done
```

- [ ] **Step 1.3: Generate the 9 imageset folders**

Run this from the worktree root:
```bash
ASSET_DIR="PhotoCleaner/Resources/Assets.xcassets/OnboardingPhotos"
for i in {1..9}; do
  SET="$ASSET_DIR/onboarding_photo_${i}.imageset"
  mkdir -p "$SET"
  cp "/tmp/onboarding-src/${i}_resized.jpg" "$SET/onboarding_photo_${i}.jpg"
  cat > "$SET/Contents.json" <<JSON
{
  "images" : [
    {
      "filename" : "onboarding_photo_${i}.jpg",
      "idiom" : "universal",
      "scale" : "1x"
    },
    {
      "idiom" : "universal",
      "scale" : "2x"
    },
    {
      "idiom" : "universal",
      "scale" : "3x"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
JSON
done
```

- [ ] **Step 1.4: Verify build picks up the new assets**

Run:
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project PhotoCleaner.xcodeproj -scheme PhotoCleaner -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug CODE_SIGNING_ALLOWED=NO build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 1.5: Commit**

```bash
git add PhotoCleaner/Resources/Assets.xcassets/OnboardingPhotos
git commit -m "feat(onboarding): add 9 photo assets for onboarding mocks"
```

---

## Task 2: Update L10n strings

**Files:**
- Modify: `PhotoCleaner/App/L10n.swift`

Add 4 new keys (badge, score, category tag, scan title/desc), rewrite 2 existing (feature1/2 title+desc), remove 10 obsolete keys (notification page + screenshot/score/tag labels no longer used).

- [ ] **Step 2.1: Add new keys**

Add the following block at the end of the existing onboarding section in `PhotoCleaner/App/L10n.swift` (search for `onboardingNext` to locate it):

```swift
// Onboarding — new feature-page atoms
static var onboardingFeature1Badge: String { isEn ? "−12 GB" : "−12 GB" }
static var onboardingFeature2Score: String { isEn ? "92" : "92" }
static var onboardingFeature2CategoryTag: String { isEn ? "Portrait · Sharp" : "人像 · 清晰" }

// Onboarding — page 4 (scan) titles
static var onboardingScanTitle: String { isEn ? "Scan Your Library" : "开始扫描您的照片库" }
static var onboardingScanDesc: String { isEn ? "Takes about 20 seconds.\nResults appear as we go." : "大约需要 20 秒\n结果会陆续呈现" }
```

- [ ] **Step 2.2: Rewrite feature page titles and descriptions**

In `PhotoCleaner/App/L10n.swift`, replace:

```swift
static var onboardingFeature1Title: String { isEn ? "Free Up Space Instantly" : "一键释放存储空间" }
```
with:
```swift
static var onboardingFeature1Title: String { isEn ? "Free Up\nStorage Space" : "释放\n存储空间" }
```

Replace the body of `onboardingFeature1Desc` (find the existing closure) with:
```swift
static var onboardingFeature1Desc: String { isEn ? "Find duplicate photos and large videos.\nClear gigabytes in one tap." : "找出重复照片和大视频\n一键清理几个 GB" }
```

Replace:
```swift
static var onboardingFeature2Title: String { isEn ? "Smart Photo Analysis" : "智能照片分析" }
```
with:
```swift
static var onboardingFeature2Title: String { isEn ? "Smart Analysis\nof Every Photo" : "智能识别\n每张照片" }
```

Replace the body of `onboardingFeature2Desc` with:
```swift
static var onboardingFeature2Desc: String { isEn ? "Screenshot classification, face protection,\nand quality scoring." : "截图分类、人脸保护\n给每张照片质量评分" }
```

- [ ] **Step 2.3: Remove obsolete keys**

In `PhotoCleaner/App/L10n.swift`, delete these declarations entirely:

```swift
static var onboardingScreenshotLabel
static var onboardingScoreLabel
static var onboardingTagChat
static var onboardingTagOrder
static var onboardingTagCode
static var onboardingTagOther
static var onboardingNotifTitle
static var onboardingNotifDesc
static var onboardingNotifAction
static var onboardingNotifDone
```

(10 keys; their `isEn ? "…" : "…"` bodies go with them.)

- [ ] **Step 2.4: Verify build still passes**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project PhotoCleaner.xcodeproj -scheme PhotoCleaner -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug CODE_SIGNING_ALLOWED=NO build 2>&1 | tail -20
```
Expected: build will likely **fail** because the old `OnboardingView.swift` still references the deleted keys (`onboardingScreenshotLabel`, `onboardingTagChat`, `onboardingNotifTitle`, etc.). This is expected — Task 6 rewrites `OnboardingView.swift` entirely, which will resolve those references.

**To unblock subsequent build verification in Tasks 3–5,** comment out (don't delete) every line in `OnboardingView.swift` that references a removed key — search for `onboardingScreenshotLabel`, `onboardingScoreLabel`, `onboardingTagChat`, `onboardingTagOrder`, `onboardingTagCode`, `onboardingTagOther`, `onboardingNotifTitle`, `onboardingNotifDesc`, `onboardingNotifAction`, `onboardingNotifDone` and prefix each occurrence with `// `. Replace each commented `Text(...)` with `Text("")` so SwiftUI's view builders still type-check. Then re-run the build:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project PhotoCleaner.xcodeproj -scheme PhotoCleaner -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug CODE_SIGNING_ALLOWED=NO build 2>&1 | tail -10
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 2.5: Commit**

```bash
git add PhotoCleaner/App/L10n.swift PhotoCleaner/Views/Onboarding/OnboardingView.swift
git commit -m "feat(onboarding): refresh L10n strings, drop notification keys"
```

---

## Task 3: Create `OnboardingComponents.swift`

**Files:**
- Create: `PhotoCleaner/Views/Onboarding/OnboardingComponents.swift`

Three primitive views: hero container (halo + slot + title + desc + entrance animation), gradient icon block, bottom bar (page indicator + CTA layouts).

- [ ] **Step 3.1: Create the file with full contents**

Create `PhotoCleaner/Views/Onboarding/OnboardingComponents.swift`:

```swift
import SwiftUI

// MARK: - OnboardingHero
/// Shared layout for the top 60% of every onboarding page:
/// blue radial halo → hero slot → title → description, with synchronised
/// entrance animation (hero scale-fade, text slide-fade).
struct OnboardingHero<Hero: View>: View {
    let title: String
    let desc: String
    let haloDiameter: CGFloat
    @ViewBuilder let hero: () -> Hero
    @State private var animateIn = false

    init(
        title: String,
        desc: String,
        haloDiameter: CGFloat = 240,
        @ViewBuilder hero: @escaping () -> Hero
    ) {
        self.title = title
        self.desc = desc
        self.haloDiameter = haloDiameter
        self.hero = hero
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 20)

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                AppColors.purple.opacity(0.32),
                                AppColors.purple.opacity(0.02)
                            ],
                            center: .init(x: 0.5, y: 0.4),
                            startRadius: 0,
                            endRadius: haloDiameter * 0.55
                        )
                    )
                    .frame(width: haloDiameter, height: haloDiameter)
                    .blur(radius: 4)

                hero()
            }
            .scaleEffect(animateIn ? 1.0 : 0.85)
            .opacity(animateIn ? 1.0 : 0.0)

            Spacer().frame(height: 28)

            VStack(spacing: 10) {
                Text(title)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text(desc)
                    .font(.system(size: 15))
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 32)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .offset(y: animateIn ? 0 : 30)
            .opacity(animateIn ? 1.0 : 0.0)

            Spacer()
            // Reserved area for OnboardingBottomBar
            Spacer().frame(height: 120)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.15)) {
                animateIn = true
            }
        }
    }
}

// MARK: - GradientIcon
/// 80×80 rounded blue gradient block with an inset SF Symbol.
/// Used as the hero for permission / informational pages.
struct GradientIcon: View {
    let systemName: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [AppColors.purple, AppColors.lightPurple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 80, height: 80)
                .shadow(color: AppColors.purple.opacity(0.4), radius: 24, y: 10)

            Image(systemName: systemName)
                .font(.system(size: 36, weight: .medium))
                .foregroundColor(.white)
        }
    }
}

// MARK: - OnboardingBottomBar
/// Bottom controls. Page indicator stays left-aligned on every page.
/// When `primaryWide` is true (permission / scan pages), the primary CTA is a
/// full-width pill rendered above the indicator row, with an optional
/// secondary "skip" text link beneath it.
struct OnboardingBottomBar: View {
    let currentPage: Int
    let totalPages: Int
    let primaryTitle: String?
    let primaryIcon: String?      // SF Symbol shown left of the title (wide layout)
    let primaryWide: Bool
    let primaryDisabled: Bool
    let onPrimary: () -> Void
    let secondaryTitle: String?
    let onSecondary: (() -> Void)?

    init(
        currentPage: Int,
        totalPages: Int,
        primaryTitle: String? = nil,
        primaryIcon: String? = nil,
        primaryWide: Bool = false,
        primaryDisabled: Bool = false,
        onPrimary: @escaping () -> Void = {},
        secondaryTitle: String? = nil,
        onSecondary: (() -> Void)? = nil
    ) {
        self.currentPage = currentPage
        self.totalPages = totalPages
        self.primaryTitle = primaryTitle
        self.primaryIcon = primaryIcon
        self.primaryWide = primaryWide
        self.primaryDisabled = primaryDisabled
        self.onPrimary = onPrimary
        self.secondaryTitle = secondaryTitle
        self.onSecondary = onSecondary
    }

    var body: some View {
        VStack(spacing: 12) {
            if primaryWide, let title = primaryTitle {
                Button(action: onPrimary) {
                    HStack(spacing: 6) {
                        if let icon = primaryIcon {
                            Image(systemName: icon)
                        }
                        Text(title)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(ApplePrimaryButtonStyle())
                .disabled(primaryDisabled)
                .padding(.horizontal, 28)

                if let sTitle = secondaryTitle, let onS = onSecondary {
                    Button(action: onS) {
                        Text(sTitle)
                            .font(.system(size: 15))
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
            }

            HStack {
                HStack(spacing: 4) {
                    ForEach(0..<totalPages, id: \.self) { i in
                        Capsule()
                            .fill(i == currentPage ? AppColors.purple : AppColors.textTertiary.opacity(0.4))
                            .frame(width: i == currentPage ? 14 : 4, height: 4)
                            .animation(.easeInOut(duration: 0.25), value: currentPage)
                    }
                }
                Spacer()
                if !primaryWide, let title = primaryTitle {
                    Button(action: onPrimary) {
                        HStack(spacing: 4) {
                            Text(title)
                            Image(systemName: "arrow.right")
                                .font(.system(size: 14, weight: .semibold))
                        }
                    }
                    .buttonStyle(ApplePrimaryButtonStyle())
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 36)
        }
    }
}
```

- [ ] **Step 3.2: Verify build**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project PhotoCleaner.xcodeproj -scheme PhotoCleaner -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug CODE_SIGNING_ALLOWED=NO build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3.3: Commit**

```bash
git add PhotoCleaner/Views/Onboarding/OnboardingComponents.swift
git commit -m "feat(onboarding): add hero/icon/bottom-bar primitives"
```

---

## Task 4: Create `OnboardingMocks.swift`

**Files:**
- Create: `PhotoCleaner/Views/Onboarding/OnboardingMocks.swift`

Two views: `PhotoGridMock` (3×3 grid with per-cell states + badge) for page 1, and `PhotoStackMock` (three stacked photos with score + category tag) for page 2.

- [ ] **Step 4.1: Create the file with full contents**

Create `PhotoCleaner/Views/Onboarding/OnboardingMocks.swift`:

```swift
import SwiftUI

// MARK: - Cell state
enum PhotoCellState {
    case normal   // full-colour photo
    case dim      // grayscale + low opacity (will-be-deleted candidate)
    case gone     // dashed empty slot (already cleared)
}

// MARK: - PhotoGridMock
/// 3×3 thumbnail grid with state-based cell rendering and a top-right pill
/// badge. The grid demonstrates "before / after" clean-up: some cells normal,
/// some dimmed, some empty.
struct PhotoGridMock: View {
    let imageNames: [String]      // exactly 9 names; `gone` cells ignore name
    let states: [PhotoCellState]  // exactly 9 states
    let badgeText: String

    private let cellSize: CGFloat = 48
    private let cellSpacing: CGFloat = 3

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: cellSpacing) {
                ForEach(0..<3, id: \.self) { row in
                    HStack(spacing: cellSpacing) {
                        ForEach(0..<3, id: \.self) { col in
                            let idx = row * 3 + col
                            cell(state: states[idx], imageName: imageNames[idx])
                                .frame(width: cellSize, height: cellSize)
                        }
                    }
                }
            }

            Text(badgeText)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(AppColors.purple))
                .shadow(color: AppColors.purple.opacity(0.5), radius: 14, y: 4)
                .offset(x: 14, y: -10)
        }
    }

    @ViewBuilder
    private func cell(state: PhotoCellState, imageName: String) -> some View {
        switch state {
        case .normal:
            Image(imageName)
                .resizable()
                .scaledToFill()
                .clipShape(RoundedRectangle(cornerRadius: 6))
        case .dim:
            Image(imageName)
                .resizable()
                .scaledToFill()
                .grayscale(1)
                .opacity(0.22)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        case .gone:
            RoundedRectangle(cornerRadius: 6)
                .stroke(AppColors.subtleBorder, style: StrokeStyle(lineWidth: 1, dash: [3]))
        }
    }
}

// MARK: - PhotoStackMock
/// Three photos in a "fan" stack. Front photo carries a score pill (bottom-
/// right) and a category tag (top-left). Used as page 2's hero.
struct PhotoStackMock: View {
    let backImageName: String
    let midImageName: String
    let frontImageName: String
    let scoreText: String
    let categoryTag: String

    private let cardSize = CGSize(width: 130, height: 160)

    var body: some View {
        ZStack {
            Image(backImageName)
                .resizable()
                .scaledToFill()
                .frame(width: cardSize.width, height: cardSize.height)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .opacity(0.6)
                .rotationEffect(.degrees(-8))
                .offset(x: -14, y: 8)
                .shadow(color: .black.opacity(0.4), radius: 8, y: 4)

            Image(midImageName)
                .resizable()
                .scaledToFill()
                .frame(width: cardSize.width, height: cardSize.height)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .opacity(0.85)
                .rotationEffect(.degrees(5))
                .offset(x: 10, y: -4)
                .shadow(color: .black.opacity(0.4), radius: 8, y: 4)

            Image(frontImageName)
                .resizable()
                .scaledToFill()
                .frame(width: cardSize.width, height: cardSize.height)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .shadow(color: .black.opacity(0.4), radius: 8, y: 4)
                .overlay(alignment: .topLeading) {
                    Text(categoryTag)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(AppColors.purple.opacity(0.9)))
                        .padding(8)
                }
                .overlay(alignment: .bottomTrailing) {
                    Text(scoreText)
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundColor(AppColors.green)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.6))
                                .overlay(
                                    Capsule().stroke(AppColors.green.opacity(0.5), lineWidth: 0.5)
                                )
                        )
                        .padding(8)
                }
        }
        .frame(width: cardSize.width + 30, height: cardSize.height + 20)
    }
}
```

- [ ] **Step 4.2: Verify build**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project PhotoCleaner.xcodeproj -scheme PhotoCleaner -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug CODE_SIGNING_ALLOWED=NO build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4.3: Commit**

```bash
git add PhotoCleaner/Views/Onboarding/OnboardingMocks.swift
git commit -m "feat(onboarding): add photo grid + stack mock views"
```

---

## Task 5: Create `OnboardingPages.swift`

**Files:**
- Create: `PhotoCleaner/Views/Onboarding/OnboardingPages.swift`

Four page views, each accepting the bottom-bar callbacks they need. Page 1 / 2 are pure-visual (just an `OnboardingHero` + the bottom bar). Page 3 owns photo-permission state. Page 4 hosts the existing `ScanIdleView` / `ScanningView` switcher.

- [ ] **Step 5.1: Create the file with full contents**

Create `PhotoCleaner/Views/Onboarding/OnboardingPages.swift`:

```swift
import SwiftUI
import Photos

// MARK: - Page 1: Free up space
struct FreeSpacePage: View {
    let currentPage: Int
    let totalPages: Int
    let onNext: () -> Void

    private let imageNames = [
        "onboarding_photo_1", "onboarding_photo_2", "onboarding_photo_3",
        "onboarding_photo_5", "onboarding_photo_4", "onboarding_photo_6",
        "onboarding_photo_8", "onboarding_photo_7", "onboarding_photo_9"
    ]
    private let states: [PhotoCellState] = [
        .normal, .gone,   .normal,
        .dim,    .normal, .gone,
        .gone,   .normal, .dim
    ]

    var body: some View {
        ZStack(alignment: .bottom) {
            OnboardingHero(
                title: L10n.onboardingFeature1Title,
                desc: L10n.onboardingFeature1Desc,
                haloDiameter: 240
            ) {
                PhotoGridMock(
                    imageNames: imageNames,
                    states: states,
                    badgeText: L10n.onboardingFeature1Badge
                )
            }

            OnboardingBottomBar(
                currentPage: currentPage,
                totalPages: totalPages,
                primaryTitle: L10n.onboardingNext,
                primaryWide: false,
                onPrimary: onNext
            )
        }
    }
}

// MARK: - Page 2: Smart analysis
struct SmartAnalysisPage: View {
    let currentPage: Int
    let totalPages: Int
    let onNext: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            OnboardingHero(
                title: L10n.onboardingFeature2Title,
                desc: L10n.onboardingFeature2Desc,
                haloDiameter: 220
            ) {
                PhotoStackMock(
                    backImageName: "onboarding_photo_5",
                    midImageName: "onboarding_photo_3",
                    frontImageName: "onboarding_photo_1",
                    scoreText: L10n.onboardingFeature2Score,
                    categoryTag: L10n.onboardingFeature2CategoryTag
                )
            }

            OnboardingBottomBar(
                currentPage: currentPage,
                totalPages: totalPages,
                primaryTitle: L10n.onboardingNext,
                primaryWide: false,
                onPrimary: onNext
            )
        }
    }
}

// MARK: - Page 3: Photo permission
struct PhotoAccessPage: View {
    let currentPage: Int
    let totalPages: Int
    @Binding var authorized: Bool
    let onAdvance: () -> Void

    @State private var denied = false

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                OnboardingHero(
                    title: L10n.onboardingPhotoTitle,
                    desc: L10n.onboardingPhotoDesc,
                    haloDiameter: 200
                ) {
                    GradientIcon(systemName: "photo.on.rectangle.angled")
                }
                if denied {
                    Text(L10n.onboardingPhotoDeniedHint)
                        .font(.system(size: 13))
                        .foregroundColor(AppColors.amber)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .padding(.bottom, 6)
                }
            }

            OnboardingBottomBar(
                currentPage: currentPage,
                totalPages: totalPages,
                primaryTitle: authorized ? L10n.onboardingPhotoDone : L10n.onboardingPhotoAction,
                primaryIcon: authorized ? "checkmark.circle.fill" : "photo.fill",
                primaryWide: true,
                primaryDisabled: authorized,
                onPrimary: { requestPhotoAccess() },
                secondaryTitle: authorized ? L10n.onboardingNext : L10n.onboardingSkip,
                onSecondary: onAdvance
            )
        }
        .onAppear { checkExistingStatus() }
    }

    private func checkExistingStatus() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if status == .authorized || status == .limited {
            authorized = true
        }
    }

    private func requestPhotoAccess() {
        Task { @MainActor in
            let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            switch status {
            case .authorized, .limited:
                authorized = true
                try? await Task.sleep(nanoseconds: 600_000_000)
                onAdvance()
            case .denied, .restricted:
                denied = true
            default:
                break
            }
        }
    }
}

// MARK: - Page 4: First scan
/// Hosts the existing ScanIdleView/ScanningView. Onboarding-specific framing
/// (page indicator, top spacing) is supplied here so the inner views stay
/// reusable by HomeView.
struct StartScanPage: View {
    @ObservedObject var scanVM: ScanViewModel
    let currentPage: Int
    let totalPages: Int
    let onFinish: () -> Void

    @State private var started = false
    @State private var finishTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            AppColors.darkBG.ignoresSafeArea()

            if started {
                ScanningView(vm: scanVM, progress: scanVM.progressVM, showsCancel: false)
            } else {
                ScanIdleView(onStart: startScan)
            }

            VStack {
                Spacer()
                OnboardingBottomBar(
                    currentPage: currentPage,
                    totalPages: totalPages
                )
            }
        }
        .onDisappear {
            finishTask?.cancel()
            finishTask = nil
        }
    }

    private func startScan() {
        guard !started else { return }
        started = true
        scanVM.startScan()
        finishTask?.cancel()
        finishTask = Task {
            try? await Task.sleep(nanoseconds: 20_000_000_000)
            guard !Task.isCancelled else { return }
            let deadline = Date().addingTimeInterval(2.0)
            while !Task.isCancelled, scanVM.phase == .scanning, Date() < deadline {
                try? await Task.sleep(nanoseconds: 200_000_000)
            }
            guard !Task.isCancelled else { return }
            await MainActor.run { onFinish() }
        }
    }
}
```

- [ ] **Step 5.2: Verify build**

The old `OnboardingView.swift` still defines its own `FeaturePage1`/`FeaturePage2`/`NotificationPage`/`PhotoAccessPage`/`StartScanPage` as `private struct`s — but our new names live in `OnboardingPages.swift` as top-level types. There's no name clash because the old ones are `private`. The build should still succeed at this point.

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project PhotoCleaner.xcodeproj -scheme PhotoCleaner -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug CODE_SIGNING_ALLOWED=NO build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`.

If you see "ambiguous type" errors on `PhotoAccessPage` or `StartScanPage`, that means the old `private` keywords were removed somewhere — verify the old `OnboardingView.swift` still uses `private struct` for those types and fix if not.

- [ ] **Step 5.3: Commit**

```bash
git add PhotoCleaner/Views/Onboarding/OnboardingPages.swift
git commit -m "feat(onboarding): add new 4-page views (free space, smart, photo, scan)"
```

---

## Task 6: Rewrite `OnboardingView.swift` container

**Files:**
- Modify: `PhotoCleaner/Views/Onboarding/OnboardingView.swift` (full rewrite)

Replace the 580-line file with a thin container: just the `TabView`, page-index state, photo-authorisation binding, and finish handoff. Bottom controls move into each page (via `OnboardingBottomBar`) so the container no longer needs an overlay HStack.

- [ ] **Step 6.1: Replace file contents**

Overwrite `PhotoCleaner/Views/Onboarding/OnboardingView.swift` with:

```swift
import SwiftUI

/// Top-level 4-page onboarding flow:
/// 1. Free up storage space
/// 2. Smart photo analysis
/// 3. Photo-library permission
/// 4. First scan
///
/// Each page draws its own `OnboardingBottomBar`, so the container only owns
/// the page-index state and the photo-permission binding shared between
/// page 3 and the rest of the flow.
struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @ObservedObject var scanVM: ScanViewModel

    @State private var currentPage = 0
    @State private var photoAuthorized = false

    private let totalPages = 4

    var body: some View {
        ZStack {
            AppColors.darkBG.ignoresSafeArea()

            TabView(selection: $currentPage) {
                FreeSpacePage(
                    currentPage: currentPage,
                    totalPages: totalPages,
                    onNext: goNext
                )
                .tag(0)

                SmartAnalysisPage(
                    currentPage: currentPage,
                    totalPages: totalPages,
                    onNext: goNext
                )
                .tag(1)

                PhotoAccessPage(
                    currentPage: currentPage,
                    totalPages: totalPages,
                    authorized: $photoAuthorized,
                    onAdvance: goNext
                )
                .tag(2)

                StartScanPage(
                    scanVM: scanVM,
                    currentPage: currentPage,
                    totalPages: totalPages,
                    onFinish: finish
                )
                .tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.35), value: currentPage)
        }
    }

    private func goNext() {
        if currentPage < totalPages - 1 {
            currentPage += 1
        }
    }

    private func finish() {
        hasCompletedOnboarding = true
    }
}
```

- [ ] **Step 6.2: Verify build**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project PhotoCleaner.xcodeproj -scheme PhotoCleaner -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug CODE_SIGNING_ALLOWED=NO build 2>&1 | tail -20
```
Expected: `** BUILD SUCCEEDED **`.

Common failure: the call-site of `OnboardingView` elsewhere (likely `PhotoCleanerApp.swift` or `HomeView.swift`) used a different initializer. The new init signature is `OnboardingView(hasCompletedOnboarding: Binding, scanVM: ScanViewModel)` — identical to the old one, so no call-site change is expected. If the build complains about a missing argument, grep for `OnboardingView(` and align.

- [ ] **Step 6.3: Commit**

```bash
git add PhotoCleaner/Views/Onboarding/OnboardingView.swift
git commit -m "refactor(onboarding): slim container to 4-page TabView"
```

---

## Task 7: Visual QA — page-by-page in the Simulator

**Files:** None modified. This is a verification pass.

Boot the app fresh (delete from simulator first so `hasCompletedOnboarding` is unset), step through all 4 pages, then repeat in light mode.

- [ ] **Step 7.1: Reset simulator state**

```bash
xcrun simctl shutdown all
xcrun simctl boot "iPhone 15"
xcrun simctl uninstall booted com.PhotoCleaner.app 2>/dev/null || true
# Bundle id may differ — check via:
# grep PRODUCT_BUNDLE_IDENTIFIER PhotoCleaner.xcodeproj/project.pbxproj | head -1
```

- [ ] **Step 7.2: Build & install Debug**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project PhotoCleaner.xcodeproj -scheme PhotoCleaner -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug CODE_SIGNING_ALLOWED=NO build 2>&1 | tail -5
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "PhotoCleaner.app" -path "*Debug-iphonesimulator*" 2>/dev/null | head -1)
xcrun simctl install booted "$APP_PATH"
xcrun simctl launch booted "$(plutil -extract CFBundleIdentifier raw "$APP_PATH/Info.plist")"
```

Open Simulator.app to view the running app.

- [ ] **Step 7.3: Verify each page**

For each of the 4 pages, confirm the following with eyes-on the simulator:

**Page 1 — Free up space**
- [ ] Blue radial halo visible centred behind the 3×3 grid
- [ ] 4 photos visible normal, 2 visible grayscale-faded, 3 cells are dashed empty rectangles
- [ ] "−12 GB" pill is blue, white text, sits upper-right of grid with soft glow
- [ ] Title reads on two lines, 28pt semibold
- [ ] Page indicator: first dot is the wide blue capsule, rest are small gray dots
- [ ] Bottom-right "Next →" pill is blue, tapping advances to page 2

**Page 2 — Smart analysis**
- [ ] Three photo cards fan out (back-left dim/tilted, mid-right slight tilt, front centred)
- [ ] Front card shows "92" green pill bottom-right and "Portrait · Sharp" blue tag top-left
- [ ] Animations replay (scale-fade + slide) when swiping to this page
- [ ] Indicator advances to position 2

**Page 3 — Photo permission**
- [ ] Blue gradient rounded-square icon centred with `photo.on.rectangle.angled` symbol
- [ ] Full-width blue "Allow Photo Access" pill below text
- [ ] Gray "Skip" link below pill
- [ ] Tapping the pill triggers iOS's standard permission sheet
- [ ] After granting, pill flips to "Access Granted" with checkmark and is disabled; auto-advances to page 4 within ~0.6s
- [ ] If you deny, an amber hint appears and "Skip" becomes the only forward path

**Page 4 — First scan**
- [ ] Existing `ScanIdleView` rings & camera icon render correctly
- [ ] Page indicator (4th capsule active) sits at very bottom of screen
- [ ] Tapping "Start Scan" transitions to `ScanningView`
- [ ] After scan completes (or ~20s), onboarding dismisses and `HomeView` appears

- [ ] **Step 7.4: Verify light mode**

In the iOS Simulator: **Features → Toggle Appearance** (⌘⇧A).

Repeat Step 7.3 visual checks — confirm that:
- `darkBG` correctly switches to `#f5f5f7` background
- `cardBG` text and grid borders flip to white-on-light
- The blue halo is still visible (it sits on a light surface, opacity 0.32 is still visible)
- Score pill's black backdrop becomes a contrast issue if any — note any deviations

If anything looks off in light mode, capture details and create a follow-up task. Don't block on this if the result is "acceptable, with minor tuning needed."

- [ ] **Step 7.5: Verify on smaller device**

Re-run on iPhone SE (3rd gen):
```bash
xcrun simctl shutdown all
xcodebuild -project PhotoCleaner.xcodeproj -scheme PhotoCleaner -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)' -configuration Debug build 2>&1 | tail -5
# install/launch same as 7.2 but on SE
```

Confirm:
- Title doesn't overflow on any page
- Bottom bar isn't clipped by the home indicator
- The 3×3 grid + badge fit without horizontal scroll

- [ ] **Step 7.6: Capture screenshots for the record**

```bash
xcrun simctl io booted screenshot ~/Desktop/onboarding-p1.png
# (advance to page 2)
xcrun simctl io booted screenshot ~/Desktop/onboarding-p2.png
# … etc for p3, p4
```

Optional but recommended — add these to the PR description.

---

## Task 8: Cleanup pass

**Files:**
- Modify (potentially): `PhotoCleaner/Views/Onboarding/OnboardingView.swift`, `PhotoCleaner/App/L10n.swift`

Final sweep for dead code and orphaned references.

- [ ] **Step 8.1: Grep for orphaned identifiers**

```bash
grep -rn "FeaturePage1\|FeaturePage2\|NotificationPage\|onboardingNotif\|onboardingScreenshotLabel\|onboardingScoreLabel\|onboardingTagChat\|onboardingTagOrder\|onboardingTagCode\|onboardingTagOther" PhotoCleaner/
```
Expected: no output. Any output means leftover references — delete them.

- [ ] **Step 8.2: Re-verify build**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project PhotoCleaner.xcodeproj -scheme PhotoCleaner -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug CODE_SIGNING_ALLOWED=NO build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 8.3: Verify file line counts**

```bash
wc -l PhotoCleaner/Views/Onboarding/*.swift
```
Expected approximate counts:
- `OnboardingView.swift` ≈ 60 lines (down from 580)
- `OnboardingComponents.swift` ≈ 175 lines
- `OnboardingMocks.swift` ≈ 130 lines
- `OnboardingPages.swift` ≈ 195 lines

If `OnboardingView.swift` is still hundreds of lines, the old page structs weren't fully removed — delete them.

- [ ] **Step 8.4: Final commit if anything was cleaned**

```bash
git status
# if there are changes:
git add -A
git commit -m "chore(onboarding): remove residual references to old pages/keys"
```

If `git status` is clean, skip this step.

---

## Acceptance Check

Run through the spec's acceptance criteria (§10) one by one:

- [ ] **AC-1** Flow is ≤ 4 swipes from launch to scan: **count the swipes during Task 7.3 run-through** — should be exactly 3 swipes (page 1→2, 2→3, then permission-or-skip→4) plus a tap on "Start Scan".
- [ ] **AC-2** WCAG AA contrast in both modes — eyeball check during 7.3/7.4 (`textPrimary` on `darkBG` and on `lightBG` both pass by design; verify the score pill's green-on-dark-translucent isn't washed out).
- [ ] **AC-3** Side-by-side with `HomeView` idle state — open the app post-onboarding and compare halo / card / button language. Should feel like the same product surface.
- [ ] **AC-4** Multiple device sizes — done in Tasks 7.3 (iPhone 15) and 7.5 (iPhone SE 3).
- [ ] **AC-5** No notification-page residue — verified in Step 8.1.
- [ ] **AC-6** `OnboardingView.swift` is shorter than before — verified in Step 8.3.

If any AC fails, file it as a follow-up task and decide whether to block the merge.

---

## Done

Plan covers spec sections 1–10 in full:
- §1 motivation, §2 goals → addressed by Tasks 1–6 (rebuild)
- §3 flow → Task 6 (4-page container)
- §4 visual specs → Tasks 3–5 (components + pages)
- §5 structure → matches file layout in this plan
- §6 resources & L10n → Tasks 1–2
- §7 behaviour → Task 5 (PhotoAccessPage / StartScanPage logic)
- §8 non-goals → respected (no new languages, no video, no skip-all button)
- §9 risks → addressed (totalPages constant updated; old L10n consumers removed in Task 8)
- §10 acceptance → Acceptance Check section above
