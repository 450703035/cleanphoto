import SwiftUI

struct ContentView: View {
    @ObservedObject var scanVM: ScanViewModel
    @ObservedObject var libraryVM: LibraryViewModel
    @State private var selectedTab = 0
    @AppStorage("appLanguage") private var appLanguage = "zh"

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .environmentObject(scanVM)
                .environmentObject(libraryVM)
                .tabItem {
                    Label(L10n.tabAIClean, systemImage: "sparkles")
                }
                .tag(0)

            TimelineView()
                .environmentObject(scanVM)
                .environmentObject(libraryVM)
                .tabItem {
                    Label(L10n.tabTimeline, systemImage: "calendar")
                }
                .tag(1)

            ToolsView()
                .environmentObject(libraryVM)
                .tabItem {
                    Label(L10n.tabTools, systemImage: "wrench.and.screwdriver")
                }
                .tag(2)

            SettingsView()
                .environmentObject(scanVM)
                .tabItem {
                    Label(L10n.tabSettings, systemImage: "person.circle")
                }
                .tag(3)
        }
        .tint(AppColors.purple)
        .id(appLanguage)
        .task {
            await scanVM.requestAuthorizationOnAppLaunchIfNeeded()
            await scanVM.loadCachedResultsIfAvailable()
            scanVM.startIncrementalSyncOnAppLaunchIfNeeded()
        }
    }
}
