import SwiftUI

@main
struct PhotoCleanerApp: App {
    @AppStorage("themeMode") private var themeModeRaw = AppThemeMode.system.rawValue
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    private var currentThemeMode: AppThemeMode {
        AppThemeMode(rawValue: themeModeRaw) ?? .system
    }

    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                ContentView()
                    .preferredColorScheme(currentThemeMode.colorScheme)
            } else {
                OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
                    .preferredColorScheme(currentThemeMode.colorScheme)
            }
        }
    }
}
