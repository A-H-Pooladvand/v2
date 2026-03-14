import SwiftUI

struct ConfigListView: View {
    @EnvironmentObject var storageService: StorageService
    @EnvironmentObject var vpnManager: VPNManager

    @State private var showingAddConfig = false
    @State private var showingDetail: V2RayConfig?
    @State private var showingDeleteAlert = false
    @State private var configToDelete: V2RayConfig?
    @State private var showingError = false
    @State private var errorMessage = ""

    // Timer publisher for refreshing the elapsed-connection-time display
    private let refreshTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                VStack(spacing: 0) {
                    // Connection status card
                    connectionStatusCard

                    // Config list
                    if storageService.configs.isEmpty {
                        emptyState
                    } else {
                        configList
                    }
                }
            }
            .navigationTitle("V2Ray Client")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddConfig = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .imageScale(.large)
                    }
                }
            }
            .sheet(isPresented: $showingAddConfig) {
                AddConfigView()
            }
            .sheet(item: $showingDetail) { config in
                ConfigDetailView(config: config)
            }
            .alert("Delete Config", isPresented: $showingDeleteAlert) {
                Button("Delete", role: .destructive) {
                    if let config = configToDelete {
                        storageService.removeConfig(id: config.id)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete this configuration?")
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
        .onReceive(refreshTimer) { _ in
            // Force status text refresh while connected to keep elapsed time current
            if vpnManager.connectionState.isConnected {
                vpnManager.objectWillChange.send()
            }
        }
    }

    // MARK: - Connection Status Card

    private var connectionStatusCard: some View {
        VStack(spacing: 12) {
            HStack {
                // Status icon
                Image(systemName: vpnManager.connectionState.iconName)
                    .font(.system(size: 40))
                    .foregroundColor(stateColor)
                    .symbolEffect(.pulse, isActive: vpnManager.connectionState.isTransitioning)

                VStack(alignment: .leading, spacing: 4) {
                    Text(vpnManager.connectionState.rawValue)
                        .font(.headline)
                        .foregroundColor(stateColor)
                    Text(vpnManager.statusText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if let config = storageService.activeConfig {
                        Text(config.displayName)
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Connect/Disconnect button
                connectButton
            }
            .padding()
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding()
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    private var stateColor: Color {
        switch vpnManager.connectionState {
        case .connected: return .green
        case .connecting, .reasserting: return .orange
        case .disconnected: return .red
        default: return .gray
        }
    }

    @ViewBuilder
    private var connectButton: some View {
        if vpnManager.connectionState.isTransitioning {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .frame(width: 64, height: 36)
        } else if vpnManager.connectionState.isConnected {
            Button("Disconnect") {
                vpnManager.disconnect()
            }
            .buttonStyle(.bordered)
            .tint(.red)
        } else {
            Button("Connect") {
                connectToSelected()
            }
            .buttonStyle(.borderedProminent)
            .disabled(storageService.activeConfig == nil)
        }
    }

    // MARK: - Config List

    private var configList: some View {
        List {
            ForEach(storageService.configs) { config in
                ConfigRowView(
                    config: config,
                    isSelected: config.isActive,
                    onSelect: {
                        storageService.setActiveConfig(config)
                    },
                    onDetail: {
                        showingDetail = config
                    }
                )
            }
            .onDelete { offsets in
                if let first = offsets.first {
                    configToDelete = storageService.configs[first]
                    showingDeleteAlert = true
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "plus.circle.dashed")
                .font(.system(size: 64))
                .foregroundColor(.blue.opacity(0.5))

            Text("No Configurations")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Tap + to import a v2ray configuration\nfrom clipboard, QR code, or gallery.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .font(.body)

            Button {
                showingAddConfig = true
            } label: {
                Label("Add Configuration", systemImage: "plus")
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
        .padding()
    }

    // MARK: - Actions

    private func connectToSelected() {
        guard let config = storageService.activeConfig else {
            errorMessage = "Please select a configuration first."
            showingError = true
            return
        }
        vpnManager.connect(config: config, settings: storageService.settings)
    }
}

// MARK: - Config Row View

struct ConfigRowView: View {
    let config: V2RayConfig
    let isSelected: Bool
    let onSelect: () -> Void
    let onDetail: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Protocol icon
            ZStack {
                Circle()
                    .fill(protocolColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: config.protocol.iconName)
                    .foregroundColor(protocolColor)
                    .font(.system(size: 18, weight: .medium))
            }

            // Config info
            VStack(alignment: .leading, spacing: 3) {
                Text(config.displayName)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(config.protocol.displayName)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(protocolColor.opacity(0.12))
                        .foregroundColor(protocolColor)
                        .clipShape(Capsule())
                    Text("\(config.serverAddress):\(config.serverPort)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Selected indicator & detail button
            HStack(spacing: 8) {
                Button {
                    onDetail()
                } label: {
                    Image(systemName: "info.circle")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)

                Button {
                    onSelect()
                } label: {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? .green : .gray)
                        .font(.system(size: 22))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
    }

    private var protocolColor: Color {
        switch config.protocol {
        case .vmess: return .blue
        case .vless: return .purple
        case .trojan: return .red
        case .shadowsocks: return .orange
        case .socks: return .teal
        case .http: return .green
        case .json: return .gray
        }
    }
}

#Preview {
    ConfigListView()
        .environmentObject(StorageService.shared)
        .environmentObject(VPNManager.shared)
}
