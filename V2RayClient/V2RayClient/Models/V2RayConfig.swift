import Foundation
import CryptoKit

// MARK: - Protocol Type Enum

enum V2RayProtocol: String, Codable, CaseIterable {
    case vmess = "vmess"
    case vless = "vless"
    case trojan = "trojan"
    case shadowsocks = "ss"
    case socks = "socks"
    case http = "http"
    case json = "json"

    var displayName: String {
        switch self {
        case .vmess: return "VMess"
        case .vless: return "VLESS"
        case .trojan: return "Trojan"
        case .shadowsocks: return "Shadowsocks"
        case .socks: return "SOCKS"
        case .http: return "HTTP"
        case .json: return "JSON"
        }
    }

    var iconName: String {
        switch self {
        case .vmess: return "v.circle.fill"
        case .vless: return "v.square.fill"
        case .trojan: return "shield.fill"
        case .shadowsocks: return "cloud.fill"
        case .socks: return "network"
        case .http: return "globe"
        case .json: return "doc.text.fill"
        }
    }
}

// MARK: - VMess Config

struct VMessConfig: Codable {
    var version: String
    var name: String
    var address: String
    var port: Int
    var id: String
    var alterId: Int
    var security: String
    var network: String
    var type: String
    var host: String
    var path: String
    var tls: String
    var sni: String
    var alpn: String
    var fingerprint: String

    enum CodingKeys: String, CodingKey {
        case version = "v"
        case name = "ps"
        case address = "add"
        case port
        case id
        case alterId = "aid"
        case security = "scy"
        case network = "net"
        case type
        case host
        case path
        case tls
        case sni
        case alpn
        case fingerprint = "fp"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = (try? container.decode(String.self, forKey: .version)) ?? "2"
        name = (try? container.decode(String.self, forKey: .name)) ?? ""
        address = (try? container.decode(String.self, forKey: .address)) ?? ""
        if let portInt = try? container.decode(Int.self, forKey: .port) {
            port = portInt
        } else if let portStr = try? container.decode(String.self, forKey: .port),
                  let portInt = Int(portStr) {
            port = portInt
        } else {
            port = 0
        }
        id = (try? container.decode(String.self, forKey: .id)) ?? ""
        if let aidInt = try? container.decode(Int.self, forKey: .alterId) {
            alterId = aidInt
        } else if let aidStr = try? container.decode(String.self, forKey: .alterId),
                  let aidInt = Int(aidStr) {
            alterId = aidInt
        } else {
            alterId = 0
        }
        security = (try? container.decode(String.self, forKey: .security)) ?? "auto"
        network = (try? container.decode(String.self, forKey: .network)) ?? "tcp"
        type = (try? container.decode(String.self, forKey: .type)) ?? "none"
        host = (try? container.decode(String.self, forKey: .host)) ?? ""
        path = (try? container.decode(String.self, forKey: .path)) ?? ""
        tls = (try? container.decode(String.self, forKey: .tls)) ?? ""
        sni = (try? container.decode(String.self, forKey: .sni)) ?? ""
        alpn = (try? container.decode(String.self, forKey: .alpn)) ?? ""
        fingerprint = (try? container.decode(String.self, forKey: .fingerprint)) ?? ""
    }

    init(version: String = "2", name: String = "", address: String = "",
         port: Int = 0, id: String = "", alterId: Int = 0,
         security: String = "auto", network: String = "tcp", type: String = "none",
         host: String = "", path: String = "", tls: String = "",
         sni: String = "", alpn: String = "", fingerprint: String = "") {
        self.version = version
        self.name = name
        self.address = address
        self.port = port
        self.id = id
        self.alterId = alterId
        self.security = security
        self.network = network
        self.type = type
        self.host = host
        self.path = path
        self.tls = tls
        self.sni = sni
        self.alpn = alpn
        self.fingerprint = fingerprint
    }
}

// MARK: - V2Ray Config Model

struct V2RayConfig: Identifiable, Codable {
    var id: UUID
    var name: String
    var serverAddress: String
    var serverPort: Int
    var `protocol`: V2RayProtocol
    var rawURI: String
    var rawJSON: String?
    var createdAt: Date
    var isActive: Bool

    // Protocol-specific fields
    var uuid: String?
    var alterId: Int?
    var security: String?
    var network: String?
    var headerType: String?
    var requestHost: String?
    var path: String?
    var tlsEnabled: Bool?
    var sni: String?
    var alpn: String?
    var fingerprint: String?
    var password: String?
    var method: String?
    var encryption: String?
    var flow: String?

    init(
        id: UUID = UUID(),
        name: String,
        serverAddress: String,
        serverPort: Int,
        protocol: V2RayProtocol,
        rawURI: String,
        rawJSON: String? = nil,
        createdAt: Date = Date(),
        isActive: Bool = false
    ) {
        self.id = id
        self.name = name
        self.serverAddress = serverAddress
        self.serverPort = serverPort
        self.protocol = `protocol`
        self.rawURI = rawURI
        self.rawJSON = rawJSON
        self.createdAt = createdAt
        self.isActive = isActive
    }

    var displayName: String {
        name.isEmpty ? "\(`protocol`.displayName) - \(serverAddress):\(serverPort)" : name
    }

    var statusIcon: String {
        isActive ? "checkmark.circle.fill" : "circle"
    }

    var statusColor: String {
        isActive ? "green" : "gray"
    }
}

// MARK: - Sample/Preview Data

extension V2RayConfig {
    static var preview: V2RayConfig {
        var config = V2RayConfig(
            name: "My VMess Server",
            serverAddress: "example.com",
            serverPort: 443,
            protocol: .vmess,
            rawURI: "vmess://eyJ2IjoiMiIsInBzIjoiTXkgU2VydmVyIiwiYWRkIjoiZXhhbXBsZS5jb20iLCJwb3J0IjoiNDQzIn0="
        )
        config.uuid = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
        config.security = "auto"
        config.network = "ws"
        config.tlsEnabled = true
        return config
    }
}
