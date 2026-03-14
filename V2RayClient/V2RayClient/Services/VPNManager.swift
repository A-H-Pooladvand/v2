import Foundation
import NetworkExtension
import Combine

// MARK: - VPN Connection State

enum VPNConnectionState: String {
    case disconnected = "Disconnected"
    case connecting = "Connecting"
    case connected = "Connected"
    case disconnecting = "Disconnecting"
    case invalid = "Not Configured"
    case reasserting = "Reconnecting"

    var isConnected: Bool { self == .connected }
    var isTransitioning: Bool { self == .connecting || self == .disconnecting }

    var iconName: String {
        switch self {
        case .connected: return "checkmark.shield.fill"
        case .connecting, .reasserting: return "arrow.clockwise.circle.fill"
        case .disconnecting: return "xmark.circle.fill"
        case .disconnected, .invalid: return "shield.slash.fill"
        }
    }

    var color: String {
        switch self {
        case .connected: return "green"
        case .connecting, .reasserting: return "orange"
        case .disconnected: return "red"
        default: return "gray"
        }
    }
}

// MARK: - VPN Manager

final class VPNManager: ObservableObject {
    static let shared = VPNManager()

    @Published var connectionState: VPNConnectionState = .disconnected
    @Published var connectedSince: Date?
    @Published var lastError: String?

    private var vpnManager: NEVPNManager?
    private var cancellables = Set<AnyCancellable>()
    private var statusObserver: NSObjectProtocol?
    private var currentConfig: V2RayConfig?

    private init() {
        setupVPNManager()
        observeVPNStatus()
    }

    deinit {
        if let observer = statusObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Setup

    private func setupVPNManager() {
        NEVPNManager.shared().loadFromPreferences { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.lastError = error.localizedDescription
                    self?.connectionState = .invalid
                } else {
                    self?.vpnManager = NEVPNManager.shared()
                    self?.updateState()
                }
            }
        }
    }

    private func observeVPNStatus() {
        statusObserver = NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateState()
        }
    }

    private func updateState() {
        guard let status = vpnManager?.connection.status else {
            connectionState = .disconnected
            return
        }
        switch status {
        case .connected:
            connectionState = .connected
            connectedSince = vpnManager?.connection.connectedDate
        case .connecting:
            connectionState = .connecting
            connectedSince = nil
        case .disconnected:
            connectionState = .disconnected
            connectedSince = nil
        case .disconnecting:
            connectionState = .disconnecting
        case .invalid:
            connectionState = .invalid
        case .reasserting:
            connectionState = .reasserting
        @unknown default:
            connectionState = .disconnected
        }
    }

    // MARK: - Connect

    func connect(config: V2RayConfig, settings: AppSettings) {
        currentConfig = config
        connectionState = .connecting
        lastError = nil

        NEVPNManager.shared().loadFromPreferences { [weak self] error in
            guard let self = self else { return }

            if let error = error {
                DispatchQueue.main.async {
                    self.lastError = "Load preferences failed: \(error.localizedDescription)"
                    self.connectionState = .disconnected
                }
                return
            }

            let manager = NEVPNManager.shared()

            // NOTE: NEVPNProtocolIKEv2 is used here as a structural stub to demonstrate
            // the VPN lifecycle (connect/disconnect/status). For real v2ray tunneling,
            // replace this with NETunnelProviderManager + NETunnelProviderProtocol,
            // and implement a PacketTunnelProvider Network Extension target that
            // embeds the v2ray-core or Xray-core library. See README for details.
            let proto = NEVPNProtocolIKEv2()

            // Configure the VPN protocol based on config type
            // NOTE: For a full v2ray implementation, use NETunnelProviderManager
            // and a Network Extension target that embeds the v2ray-core library.
            // The code below demonstrates the structure; actual tunneling requires
            // integrating the v2ray-core (e.g., via Xray-core iOS framework).

            proto.serverAddress = config.serverAddress
            proto.remoteIdentifier = config.sni ?? config.serverAddress
            proto.localIdentifier = "V2RayClient"
            proto.useExtendedAuthentication = false
            proto.disconnectOnSleep = false

            // Upstream proxy configuration
            if settings.upstreamProxyEnabled && !settings.upstreamProxyHost.isEmpty {
                proto.proxySettings = buildProxySettings(settings: settings)
            }

            manager.protocolConfiguration = proto
            manager.isEnabled = true
            manager.localizedDescription = "V2Ray - \(config.displayName)"

            manager.saveToPreferences { [weak self] error in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    if let error = error {
                        self.lastError = "Save preferences failed: \(error.localizedDescription)"
                        self.connectionState = .disconnected
                        return
                    }

                    do {
                        try manager.connection.startVPNTunnel()
                    } catch let tunnelError as NEVPNError {
                        self.lastError = tunnelError.localizedDescription
                        self.connectionState = .disconnected
                    } catch {
                        self.lastError = error.localizedDescription
                        self.connectionState = .disconnected
                    }
                }
            }
        }
    }

    func disconnect() {
        vpnManager?.connection.stopVPNTunnel()
        connectedSince = nil
    }

    // MARK: - Proxy Settings

    private func buildProxySettings(settings: AppSettings) -> NEProxySettings {
        let proxySettings = NEProxySettings()
        proxySettings.excludeSimpleHostnames = true

        let server = NEProxyServer(
            address: settings.upstreamProxyHost,
            port: settings.upstreamProxyPort
        )

        switch settings.upstreamProxyType {
        case .http, .https:
            proxySettings.httpEnabled = true
            proxySettings.httpServer = server
            proxySettings.httpsEnabled = true
            proxySettings.httpsServer = server
        case .socks5, .socks4:
            proxySettings.httpEnabled = true
            proxySettings.httpServer = server
        }

        return proxySettings
    }

    // MARK: - Status Helpers

    var statusText: String {
        switch connectionState {
        case .connected:
            if let date = connectedSince {
                let duration = formatDuration(from: date)
                return "Connected · \(duration)"
            }
            return "Connected"
        case .connecting: return "Connecting..."
        case .disconnecting: return "Disconnecting..."
        case .disconnected: return "Disconnected"
        case .invalid: return "Not Configured"
        case .reasserting: return "Reconnecting..."
        }
    }

    private func formatDuration(from date: Date) -> String {
        let seconds = Int(-date.timeIntervalSinceNow)
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 { return String(format: "%02d:%02d:%02d", h, m, s) }
        return String(format: "%02d:%02d", m, s)
    }
}
