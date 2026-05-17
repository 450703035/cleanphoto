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
