import SwiftUI
import UserNotifications
import Photos

// MARK: - Onboarding Container
struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @ObservedObject var scanVM: ScanViewModel
    @State private var currentPage = 0
    @State private var notificationGranted = false
    @State private var photoAuthorized = false

    private let totalPages = 5

    var body: some View {
        ZStack {
            AppColors.darkBG.ignoresSafeArea()

            TabView(selection: $currentPage) {
                FeaturePage1()
                    .tag(0)

                FeaturePage2()
                    .tag(1)

                NotificationPage(granted: $notificationGranted, onNext: goNext)
                    .tag(2)

                PhotoAccessPage(authorized: $photoAuthorized, onNext: goNext)
                    .tag(3)

                StartScanPage(scanVM: scanVM, onFinish: finish)
                    .tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.35), value: currentPage)

            // Bottom controls
            VStack {
                Spacer()
                HStack {
                    // Page indicator
                    HStack(spacing: 6) {
                        ForEach(0..<totalPages, id: \.self) { i in
                            Capsule()
                                .fill(i == currentPage ? AppColors.purple : AppColors.textTertiary.opacity(0.4))
                                .frame(width: i == currentPage ? 20 : 6, height: 6)
                                .animation(.easeInOut(duration: 0.25), value: currentPage)
                        }
                    }

                    Spacer()

                    // Next button (only on feature pages)
                    if currentPage < 2 {
                        Button {
                            goNext()
                        } label: {
                            HStack(spacing: 4) {
                                Text(L10n.onboardingNext)
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

    private func goNext() {
        if currentPage < totalPages - 1 {
            currentPage += 1
        }
    }

    private func finish() {
        hasCompletedOnboarding = true
    }
}

// MARK: - Feature Page 1: Video Cleanup in Waterfall
private struct FeaturePage1: View {
    @State private var animateIn = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Icon cluster
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AppColors.purple.opacity(0.18), AppColors.lightPurple.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 200, height: 200)

                // Mock waterfall grid
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        mockVideoCell(height: 60, size: "1.2GB", color: AppColors.red)
                        mockVideoCell(height: 80, size: "860MB", color: AppColors.amber)
                    }
                    HStack(spacing: 4) {
                        mockVideoCell(height: 75, size: "2.1GB", color: AppColors.red)
                        mockVideoCell(height: 55, size: "430MB", color: AppColors.green)
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(AppColors.cardBG)
                        .shadow(color: .black.opacity(0.12), radius: 20, y: 8)
                )
                .scaleEffect(animateIn ? 1.0 : 0.85)
                .opacity(animateIn ? 1.0 : 0.0)
            }

            Spacer().frame(height: 48)

            VStack(spacing: 14) {
                Text(L10n.onboardingFeature1Title)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.center)

                Text(L10n.onboardingFeature1Desc)
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 40)
            }
            .offset(y: animateIn ? 0 : 30)
            .opacity(animateIn ? 1.0 : 0.0)

            Spacer()
            Spacer().frame(height: 80) // space for bottom controls
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.15)) {
                animateIn = true
            }
        }
    }

    private func mockVideoCell(height: CGFloat, size: String, color: Color) -> some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(color.opacity(0.12))
            .frame(width: 70, height: height)
            .overlay(
                VStack(spacing: 2) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(color.opacity(0.6))
                    Text(size)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(color)
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(color.opacity(0.25), lineWidth: 0.5)
            )
    }
}

// MARK: - Feature Page 2: Screenshot Classification & Photo Scoring
private struct FeaturePage2: View {
    @State private var animateIn = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Two feature cards side by side
            HStack(spacing: 12) {
                // Screenshot classification card
                VStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(AppColors.lightPurple.opacity(0.10))
                            .frame(height: 80)
                        VStack(spacing: 4) {
                            Image(systemName: "rectangle.on.rectangle.angled")
                                .font(.system(size: 26))
                                .foregroundColor(AppColors.lightPurple)
                            Text(L10n.onboardingScreenshotLabel)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }

                    // Mini tags
                    HStack(spacing: 4) {
                        miniTag(L10n.onboardingTagChat, "message.fill", .blue)
                        miniTag(L10n.onboardingTagOrder, "bag.fill", .orange)
                    }
                    HStack(spacing: 4) {
                        miniTag(L10n.onboardingTagCode, "chevron.left.forwardslash.chevron.right", .green)
                        miniTag(L10n.onboardingTagOther, "ellipsis", .gray)
                    }
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(AppColors.cardBG)
                        .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
                )

                // Photo scoring card
                VStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(AppColors.green.opacity(0.10))
                            .frame(height: 80)
                        VStack(spacing: 4) {
                            Image(systemName: "star.circle.fill")
                                .font(.system(size: 26))
                                .foregroundColor(AppColors.green)
                            Text(L10n.onboardingScoreLabel)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }

                    // Score examples
                    VStack(spacing: 5) {
                        scoreRow(92, AppColors.green)
                        scoreRow(55, AppColors.amber)
                        scoreRow(23, AppColors.red)
                    }
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(AppColors.cardBG)
                        .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
                )
            }
            .padding(.horizontal, 36)
            .scaleEffect(animateIn ? 1.0 : 0.85)
            .opacity(animateIn ? 1.0 : 0.0)

            Spacer().frame(height: 48)

            VStack(spacing: 14) {
                Text(L10n.onboardingFeature2Title)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.center)

                Text(L10n.onboardingFeature2Desc)
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 40)
            }
            .offset(y: animateIn ? 0 : 30)
            .opacity(animateIn ? 1.0 : 0.0)

            Spacer()
            Spacer().frame(height: 80)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.15)) {
                animateIn = true
            }
        }
    }

    private func miniTag(_ text: String, _ icon: String, _ color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 8))
            Text(text)
                .font(.system(size: 9, weight: .medium))
        }
        .foregroundColor(color)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            Capsule().fill(color.opacity(0.10))
        )
    }

    private func scoreRow(_ score: Int, _ color: Color) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 3)
                .fill(color.opacity(0.15))
                .frame(width: 24, height: 18)
                .overlay(
                    Image(systemName: "photo")
                        .font(.system(size: 8))
                        .foregroundColor(color.opacity(0.5))
                )
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(color.opacity(0.12))
                        .frame(height: 4)
                    Capsule()
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(score) / 100, height: 4)
                }
                .frame(maxHeight: .infinity, alignment: .center)
            }
            .frame(height: 18)
            Text("\(score)")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(color)
                .frame(width: 22, alignment: .trailing)
        }
    }
}

// MARK: - Notification Permission Page
private struct NotificationPage: View {
    @Binding var granted: Bool
    var onNext: () -> Void
    @State private var animateIn = false
    @State private var asked = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.orange.opacity(0.15), Color.yellow.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 160, height: 160)

                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(
                        LinearGradient(colors: [.orange, .red], startPoint: .top, endPoint: .bottom)
                    )
            }
            .scaleEffect(animateIn ? 1.0 : 0.8)
            .opacity(animateIn ? 1.0 : 0.0)

            Spacer().frame(height: 48)

            VStack(spacing: 14) {
                Text(L10n.onboardingNotifTitle)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.center)

                Text(L10n.onboardingNotifDesc)
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 40)
            }
            .offset(y: animateIn ? 0 : 30)
            .opacity(animateIn ? 1.0 : 0.0)

            Spacer().frame(height: 36)

            VStack(spacing: 12) {
                Button {
                    requestNotification()
                } label: {
                    HStack {
                        Image(systemName: granted ? "checkmark.circle.fill" : "bell.fill")
                        Text(granted ? L10n.onboardingNotifDone : L10n.onboardingNotifAction)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(ApplePrimaryButtonStyle())
                .disabled(granted)
                .padding(.horizontal, 40)

                Button {
                    onNext()
                } label: {
                    Text(granted ? L10n.onboardingNext : L10n.onboardingSkip)
                        .font(AppTypography.body)
                        .foregroundColor(AppColors.textTertiary)
                }
            }

            Spacer()
            Spacer().frame(height: 80)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.15)) {
                animateIn = true
            }
        }
    }

    private func requestNotification() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { success, _ in
            DispatchQueue.main.async {
                granted = success
                if success {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        onNext()
                    }
                } else {
                    asked = true
                }
            }
        }
    }
}

// MARK: - Photo Library Access Page
private struct PhotoAccessPage: View {
    @Binding var authorized: Bool
    var onNext: () -> Void
    @State private var animateIn = false
    @State private var denied = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AppColors.purple.opacity(0.15), AppColors.lightPurple.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 160, height: 160)

                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 56))
                    .foregroundStyle(
                        LinearGradient(colors: [AppColors.purple, AppColors.lightPurple], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
            }
            .scaleEffect(animateIn ? 1.0 : 0.8)
            .opacity(animateIn ? 1.0 : 0.0)

            Spacer().frame(height: 48)

            VStack(spacing: 14) {
                Text(L10n.onboardingPhotoTitle)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.center)

                Text(L10n.onboardingPhotoDesc)
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 40)
            }
            .offset(y: animateIn ? 0 : 30)
            .opacity(animateIn ? 1.0 : 0.0)

            Spacer().frame(height: 36)

            VStack(spacing: 12) {
                Button {
                    requestPhotoAccess()
                } label: {
                    HStack {
                        Image(systemName: authorized ? "checkmark.circle.fill" : "photo.fill")
                        Text(authorized ? L10n.onboardingPhotoDone : L10n.onboardingPhotoAction)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(ApplePrimaryButtonStyle())
                .disabled(authorized)
                .padding(.horizontal, 40)

                if denied {
                    Text(L10n.onboardingPhotoDeniedHint)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.amber)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }

                Button {
                    onNext()
                } label: {
                    Text(authorized ? L10n.onboardingNext : L10n.onboardingSkip)
                        .font(AppTypography.body)
                        .foregroundColor(authorized ? AppColors.purple : AppColors.textTertiary)
                }
            }

            Spacer()
            Spacer().frame(height: 80)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.15)) {
                animateIn = true
            }
            checkExistingStatus()
        }
    }

    private func checkExistingStatus() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if status == .authorized || status == .limited {
            authorized = true
        }
    }

    private func requestPhotoAccess() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized, .limited:
                    authorized = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        onNext()
                    }
                case .denied, .restricted:
                    denied = true
                default:
                    break
                }
            }
        }
    }
}

// MARK: - Start Scan Page (Onboarding Page 5)
private struct StartScanPage: View {
    @ObservedObject var scanVM: ScanViewModel
    var onFinish: () -> Void
    @State private var started = false
    @State private var finishTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            AppColors.darkBG.ignoresSafeArea()
            if started {
                ScanningView(vm: scanVM, showsCancel: false)
            } else {
                ScanIdleView(onStart: startScan)
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
            // Keep onboarding visible for the first-pass 20s scan window.
            try? await Task.sleep(nanoseconds: 20_000_000_000)
            guard !Task.isCancelled else { return }
            // Give scan state a brief chance to flip to first-pass result mode.
            let deadline = Date().addingTimeInterval(2.0)
            while !Task.isCancelled, scanVM.phase == .scanning, Date() < deadline {
                try? await Task.sleep(nanoseconds: 200_000_000)
            }
            guard !Task.isCancelled else { return }
            await MainActor.run {
                onFinish()
            }
        }
    }
}
