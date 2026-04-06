import SwiftUI

@main
struct PhotoCleanerApp: App {
    @AppStorage("themeMode") private var themeModeRaw = AppThemeMode.system.rawValue

    private var currentThemeMode: AppThemeMode {
        AppThemeMode(rawValue: themeModeRaw) ?? .system
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(currentThemeMode.colorScheme)
        }
    }
}
