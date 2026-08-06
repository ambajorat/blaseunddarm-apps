import SwiftUI

struct ContentView: View {
    @Environment(DataStore.self) private var store
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            LogView()
                .tabItem { Label(String(localized: "tab_log"), systemImage: "plus.circle.fill") }
                .tag(0)
            HistoryView()
                .tabItem { Label(String(localized: "tab_history"), systemImage: "list.clipboard") }
                .tag(1)
            StatsView()
                .tabItem { Label(String(localized: "tab_stats"), systemImage: "chart.bar.fill") }
                .tag(2)
            AlertsView()
                .tabItem { Label("Hinweise", systemImage: "bell.badge.fill") }
                .tag(3)
            SettingsView()
                .tabItem { Label(String(localized: "tab_settings"), systemImage: "gearshape.fill") }
                .tag(4)
        }
        .tint(Color.accent)
    }
}

#Preview { ContentView().environment(DataStore()).environment(NotificationManager()).environment(StoreManager()).environment(CloudBackupManager()) }
