import Foundation

struct AppSettings: Codable {
    // MARK: - Upstream Proxy Settings
    var upstreamProxyEnabled: Bool
    var upstreamProxyType: UpstreamProxyType
    var upstreamProxyHost: String
    var upstreamProxyPort: Int
    var upstreamProxyUsername: String
    var upstreamProxyPassword: String

    // MARK: - DNS Settings
    var customDNSEnabled: Bool
    var primaryDNS: String
    var secondaryDNS: String

    // MARK: - Routing Settings
    var bypassLAN: Bool
    var bypassChinaMainland: Bool
    var enableSniffing: Bool

    // MARK: - Local Inbound Settings
    var localSocksPort: Int
    var localHttpPort: Int
    var allowLANConnections: Bool

    // MARK: - General
    var autoConnect: Bool
    var selectedConfigID: UUID?

    // MARK: - Default Values

    static var `default`: AppSettings {
        AppSettings(
            upstreamProxyEnabled: false,
            upstreamProxyType: .socks5,
            upstreamProxyHost: "",
            upstreamProxyPort: 1080,
            upstreamProxyUsername: "",
            upstreamProxyPassword: "",
            customDNSEnabled: false,
            primaryDNS: "8.8.8.8",
            secondaryDNS: "8.8.4.4",
            bypassLAN: true,
            bypassChinaMainland: false,
            enableSniffing: true,
            localSocksPort: 1080,
            localHttpPort: 8080,
            allowLANConnections: false,
            autoConnect: false,
            selectedConfigID: nil
        )
    }
}

// MARK: - Upstream Proxy Type

enum UpstreamProxyType: String, Codable, CaseIterable {
    case http = "HTTP"
    case https = "HTTPS"
    case socks5 = "SOCKS5"
    case socks4 = "SOCKS4"

    var displayName: String { rawValue }
}
