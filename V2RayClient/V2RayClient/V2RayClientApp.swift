import SwiftUI

@main
struct V2RayClientApp: App {
    @StateObject private var storageService = StorageService.shared
    @StateObject private var vpnManager = VPNManager.shared

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(storageService)
                .environmentObject(vpnManager)
        }
    }
}
