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
