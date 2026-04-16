import SwiftUI

@main
struct PhotoCleanerApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("themeMode") private var themeModeRaw = AppThemeMode.system.rawValue
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @StateObject private var scanVM = ScanViewModel()
    @StateObject private var libraryVM = LibraryViewModel()

    private var currentThemeMode: AppThemeMode {
        AppThemeMode(rawValue: themeModeRaw) ?? .system
    }

    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                ContentView(scanVM: scanVM, libraryVM: libraryVM)
                    .preferredColorScheme(currentThemeMode.colorScheme)
            } else {
                OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding, scanVM: scanVM)
                    .preferredColorScheme(currentThemeMode.colorScheme)
            }
        }
        .onChange(of: scenePhase) { newPhase in
            guard newPhase == .active else { return }
            scanVM.resumeScanningIfNeededAfterAppBecameActive()
        }
    }
}
