import SwiftUI

struct ContentView: View {
    @StateObject private var scanVM = ScanViewModel()
    @StateObject private var libraryVM = LibraryViewModel()
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .environmentObject(scanVM)
                .environmentObject(libraryVM)
                .tabItem {
                    Label("AI清理", systemImage: "sparkles")
                }
                .tag(0)

            TimelineView()
                .environmentObject(libraryVM)
                .tabItem {
                    Label("时间线", systemImage: "calendar")
                }
                .tag(1)

            ToolsView()
                .environmentObject(libraryVM)
                .tabItem {
                    Label("工具", systemImage: "wrench.and.screwdriver")
                }
                .tag(2)

            SettingsView()
                .environmentObject(scanVM)
                .tabItem {
                    Label("设置", systemImage: "person.circle")
                }
                .tag(3)
        }
        .accentColor(AppColors.purple)
        .task { await scanVM.loadCachedResultsIfAvailable() }
    }
}
