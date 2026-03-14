import SwiftUI

struct MainView: View {
    @EnvironmentObject var storageService: StorageService
    @EnvironmentObject var vpnManager: VPNManager
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            ConfigListView()
                .tabItem {
                    Label("Configs", systemImage: "list.bullet.rectangle")
                }
                .tag(0)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(1)
        }
        .accentColor(.blue)
    }
}

#Preview {
    MainView()
        .environmentObject(StorageService.shared)
        .environmentObject(VPNManager.shared)
}
