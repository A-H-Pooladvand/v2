import Foundation

// MARK: - Config Parser

enum ConfigParseError: LocalizedError {
    case emptyInput
    case unsupportedProtocol(String)
    case invalidBase64
    case invalidJSON(String)
    case missingRequiredField(String)
    case invalidURL
    case invalidPort

    var errorDescription: String? {
        switch self {
        case .emptyInput:
            return "Input is empty."
        case .unsupportedProtocol(let proto):
            return "Unsupported protocol: \(proto)"
        case .invalidBase64:
            return "Invalid Base64 encoding."
        case .invalidJSON(let detail):
            return "Invalid JSON: \(detail)"
        case .missingRequiredField(let field):
            return "Missing required field: \(field)"
        case .invalidURL:
            return "Invalid URL format."
        case .invalidPort:
            return "Invalid port number."
        }
    }
}

struct ConfigParser {

    // MARK: - Public Entry Point

    /// Attempt to parse any supported v2ray config string.
    /// Supports: vmess://, vless://, trojan://, ss://, socks://, http://, raw JSON.
    static func parse(_ input: String) throws -> V2RayConfig {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ConfigParseError.emptyInput }

        if trimmed.hasPrefix("vmess://") {
            return try parseVMess(trimmed)
        } else if trimmed.hasPrefix("vless://") {
            return try parseVLESS(trimmed)
        } else if trimmed.hasPrefix("trojan://") {
            return try parseTrojan(trimmed)
        } else if trimmed.hasPrefix("ss://") {
            return try parseShadowsocks(trimmed)
        } else if trimmed.hasPrefix("socks://") || trimmed.hasPrefix("socks5://") {
            return try parseSOCKS(trimmed)
        } else if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            return try parseHTTP(trimmed)
        } else if trimmed.hasPrefix("{") {
            return try parseRawJSON(trimmed)
        } else {
            // Try base64-decoding the whole string (some apps encode the full URI)
            if let decoded = base64Decode(trimmed) {
                return try parse(decoded)
            }
            let scheme = trimmed.components(separatedBy: "://").first ?? trimmed
            throw ConfigParseError.unsupportedProtocol(scheme)
        }
    }

    // MARK: - VMess

    static func parseVMess(_ uri: String) throws -> V2RayConfig {
        guard uri.hasPrefix("vmess://") else { throw ConfigParseError.invalidURL }
        let base64Part = String(uri.dropFirst("vmess://".count))

        guard let jsonData = base64DecodeData(base64Part) else {
            throw ConfigParseError.invalidBase64
        }

        let decoder = JSONDecoder()
        let vmess: VMessConfig
        do {
            vmess = try decoder.decode(VMessConfig.self, from: jsonData)
        } catch {
            throw ConfigParseError.invalidJSON(error.localizedDescription)
        }

        guard !vmess.address.isEmpty else { throw ConfigParseError.missingRequiredField("address") }
        guard vmess.port > 0 else { throw ConfigParseError.missingRequiredField("port") }
        guard !vmess.id.isEmpty else { throw ConfigParseError.missingRequiredField("id") }

        var config = V2RayConfig(
            name: vmess.name,
            serverAddress: vmess.address,
            serverPort: vmess.port,
            protocol: .vmess,
            rawURI: uri
        )
        config.uuid = vmess.id
        config.alterId = vmess.alterId
        config.security = vmess.security.isEmpty ? "auto" : vmess.security
        config.network = vmess.network.isEmpty ? "tcp" : vmess.network
        config.headerType = vmess.type.isEmpty ? "none" : vmess.type
        config.requestHost = vmess.host
        config.path = vmess.path
        config.tlsEnabled = vmess.tls.lowercased() == "tls"
        config.sni = vmess.sni
        config.alpn = vmess.alpn
        config.fingerprint = vmess.fingerprint
        return config
    }

    // MARK: - VLESS

    static func parseVLESS(_ uri: String) throws -> V2RayConfig {
        // vless://uuid@host:port?params#name
        guard let url = URL(string: uri) else { throw ConfigParseError.invalidURL }
        guard let host = url.host, !host.isEmpty else {
            throw ConfigParseError.missingRequiredField("host")
        }
        guard let port = url.port, port > 0 else { throw ConfigParseError.invalidPort }
        let uuid = url.user ?? ""
        guard !uuid.isEmpty else { throw ConfigParseError.missingRequiredField("uuid") }

        let name = url.fragment?.removingPercentEncoding ?? ""
        let params = queryParameters(from: url)

        var config = V2RayConfig(
            name: name,
            serverAddress: host,
            serverPort: port,
            protocol: .vless,
            rawURI: uri
        )
        config.uuid = uuid
        config.encryption = params["encryption"] ?? "none"
        config.network = params["type"] ?? "tcp"
        config.headerType = params["headerType"] ?? "none"
        config.requestHost = params["host"]
        config.path = params["path"]
        config.tlsEnabled = params["security"]?.lowercased() == "tls"
            || params["security"]?.lowercased() == "reality"
        config.sni = params["sni"]
        config.alpn = params["alpn"]
        config.fingerprint = params["fp"]
        config.flow = params["flow"]
        return config
    }

    // MARK: - Trojan

    static func parseTrojan(_ uri: String) throws -> V2RayConfig {
        // trojan://password@host:port?params#name
        guard let url = URL(string: uri) else { throw ConfigParseError.invalidURL }
        guard let host = url.host, !host.isEmpty else {
            throw ConfigParseError.missingRequiredField("host")
        }
        guard let port = url.port, port > 0 else { throw ConfigParseError.invalidPort }
        let password = url.user ?? ""
        guard !password.isEmpty else { throw ConfigParseError.missingRequiredField("password") }

        let name = url.fragment?.removingPercentEncoding ?? ""
        let params = queryParameters(from: url)

        var config = V2RayConfig(
            name: name,
            serverAddress: host,
            serverPort: port,
            protocol: .trojan,
            rawURI: uri
        )
        config.password = password
        config.tlsEnabled = true
        config.sni = params["sni"] ?? host
        config.alpn = params["alpn"]
        config.fingerprint = params["fp"]
        config.network = params["type"] ?? "tcp"
        config.path = params["path"]
        config.requestHost = params["host"]
        return config
    }

    // MARK: - Shadowsocks

    static func parseShadowsocks(_ uri: String) throws -> V2RayConfig {
        // Format 1: ss://BASE64(method:password)@host:port#name
        // Format 2: ss://BASE64(method:password@host:port)#name
        guard uri.hasPrefix("ss://") else { throw ConfigParseError.invalidURL }
        var remainder = String(uri.dropFirst("ss://".count))

        var name = ""
        if let hashIndex = remainder.lastIndex(of: "#") {
            name = String(remainder[remainder.index(after: hashIndex)...])
                .removingPercentEncoding ?? ""
            remainder = String(remainder[..<hashIndex])
        }

        // Try Format 1: base64@host:port
        if let atRange = remainder.range(of: "@", options: .backwards) {
            let base64Part = String(remainder[..<atRange.lowerBound])
            let hostPort = String(remainder[atRange.upperBound...])

            if let decoded = base64Decode(base64Part) {
                let parts = decoded.components(separatedBy: ":")
                guard parts.count >= 2 else { throw ConfigParseError.missingRequiredField("method:password") }
                let method = parts[0]
                let password = parts[1...].joined(separator: ":")

                let (host, port) = try parseHostPort(hostPort)
                var config = V2RayConfig(
                    name: name,
                    serverAddress: host,
                    serverPort: port,
                    protocol: .shadowsocks,
                    rawURI: uri
                )
                config.method = method
                config.password = password
                return config
            }
        }

        // Try Format 2: base64(method:password@host:port)
        if let decoded = base64Decode(remainder) {
            if let atRange = decoded.range(of: "@", options: .backwards) {
                let userInfo = String(decoded[..<atRange.lowerBound])
                let hostPort = String(decoded[atRange.upperBound...])
                let parts = userInfo.components(separatedBy: ":")
                guard parts.count >= 2 else { throw ConfigParseError.missingRequiredField("method:password") }
                let method = parts[0]
                let password = parts[1...].joined(separator: ":")
                let (host, port) = try parseHostPort(hostPort)
                var config = V2RayConfig(
                    name: name,
                    serverAddress: host,
                    serverPort: port,
                    protocol: .shadowsocks,
                    rawURI: uri
                )
                config.method = method
                config.password = password
                return config
            }
        }

        throw ConfigParseError.invalidURL
    }

    // MARK: - SOCKS

    static func parseSOCKS(_ uri: String) throws -> V2RayConfig {
        let normalized = uri.hasPrefix("socks5://") ? "socks://" + uri.dropFirst("socks5://".count) : uri
        guard let url = URL(string: normalized) else { throw ConfigParseError.invalidURL }
        guard let host = url.host, !host.isEmpty else {
            throw ConfigParseError.missingRequiredField("host")
        }
        guard let port = url.port, port > 0 else { throw ConfigParseError.invalidPort }

        let name = url.fragment?.removingPercentEncoding ?? ""
        var config = V2RayConfig(
            name: name,
            serverAddress: host,
            serverPort: port,
            protocol: .socks,
            rawURI: uri
        )
        config.uuid = url.user
        config.password = url.password
        return config
    }

    // MARK: - HTTP

    static func parseHTTP(_ uri: String) throws -> V2RayConfig {
        guard let url = URL(string: uri) else { throw ConfigParseError.invalidURL }
        guard let host = url.host, !host.isEmpty else {
            throw ConfigParseError.missingRequiredField("host")
        }
        let port = url.port ?? (uri.hasPrefix("https://") ? 443 : 80)
        let name = url.fragment?.removingPercentEncoding ?? ""
        var config = V2RayConfig(
            name: name,
            serverAddress: host,
            serverPort: port,
            protocol: .http,
            rawURI: uri
        )
        config.uuid = url.user
        config.password = url.password
        config.tlsEnabled = uri.hasPrefix("https://")
        return config
    }

    // MARK: - Raw JSON

    static func parseRawJSON(_ jsonString: String) throws -> V2RayConfig {
        guard let data = jsonString.data(using: .utf8) else {
            throw ConfigParseError.invalidJSON("Cannot encode string as UTF-8")
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ConfigParseError.invalidJSON("Not a valid JSON object")
        }

        // Try to extract server info from v2ray outbound config
        var address = ""
        var port = 0
        var name = "JSON Config"

        if let outbounds = json["outbounds"] as? [[String: Any]],
           let first = outbounds.first {
            if let settings = first["settings"] as? [String: Any] {
                if let vnext = settings["vnext"] as? [[String: Any]], let server = vnext.first {
                    address = server["address"] as? String ?? ""
                    port = server["port"] as? Int ?? 0
                } else if let servers = settings["servers"] as? [[String: Any]], let server = servers.first {
                    address = server["address"] as? String ?? ""
                    port = server["port"] as? Int ?? 0
                }
            }
        }

        var config = V2RayConfig(
            name: name,
            serverAddress: address,
            serverPort: port,
            protocol: .json,
            rawURI: jsonString,
            rawJSON: jsonString
        )
        return config
    }

    // MARK: - Helpers

    private static func base64Decode(_ string: String) -> String? {
        guard let data = base64DecodeData(string) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func base64DecodeData(_ string: String) -> Data? {
        var padded = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = padded.count % 4
        if remainder > 0 {
            padded += String(repeating: "=", count: 4 - remainder)
        }
        return Data(base64Encoded: padded)
    }

    private static func queryParameters(from url: URL) -> [String: String] {
        var params = [String: String]()
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let items = components.queryItems else { return params }
        for item in items {
            params[item.name] = item.value
        }
        return params
    }

    private static func parseHostPort(_ hostPort: String) throws -> (String, Int) {
        if hostPort.hasPrefix("[") {
            // IPv6
            guard let bracketEnd = hostPort.lastIndex(of: "]") else { throw ConfigParseError.invalidURL }
            let host = String(hostPort[hostPort.index(after: hostPort.startIndex)..<bracketEnd])
            let afterBracket = String(hostPort[hostPort.index(after: bracketEnd)...])
            if afterBracket.hasPrefix(":"), let port = Int(afterBracket.dropFirst()) {
                return (host, port)
            }
            throw ConfigParseError.invalidPort
        }
        let parts = hostPort.components(separatedBy: ":")
        guard parts.count >= 2, let port = Int(parts.last ?? "") else {
            throw ConfigParseError.invalidPort
        }
        let host = parts.dropLast().joined(separator: ":")
        return (host, port)
    }

    // MARK: - URI Generation

    /// Generate a shareable URI string from a config
    static func generateURI(from config: V2RayConfig) -> String {
        switch config.protocol {
        case .vmess:
            return generateVMessURI(from: config)
        case .vless:
            return generateVLESSURI(from: config)
        case .trojan:
            return generateTrojanURI(from: config)
        case .shadowsocks:
            return generateSSURI(from: config)
        default:
            return config.rawURI
        }
    }

    private static func generateVMessURI(from config: V2RayConfig) -> String {
        let vmess = VMessConfig(
            version: "2",
            name: config.name,
            address: config.serverAddress,
            port: config.serverPort,
            id: config.uuid ?? "",
            alterId: config.alterId ?? 0,
            security: config.security ?? "auto",
            network: config.network ?? "tcp",
            type: config.headerType ?? "none",
            host: config.requestHost ?? "",
            path: config.path ?? "",
            tls: config.tlsEnabled == true ? "tls" : "",
            sni: config.sni ?? "",
            alpn: config.alpn ?? "",
            fingerprint: config.fingerprint ?? ""
        )
        guard let data = try? JSONEncoder().encode(vmess) else { return config.rawURI }
        let base64 = data.base64EncodedString()
        return "vmess://\(base64)"
    }

    private static func generateVLESSURI(from config: V2RayConfig) -> String {
        var components = URLComponents()
        components.scheme = "vless"
        components.user = config.uuid
        components.host = config.serverAddress
        components.port = config.serverPort
        components.fragment = config.name.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed)

        var queryItems = [URLQueryItem]()
        if let encryption = config.encryption { queryItems.append(.init(name: "encryption", value: encryption)) }
        if let network = config.network { queryItems.append(.init(name: "type", value: network)) }
        if config.tlsEnabled == true { queryItems.append(.init(name: "security", value: "tls")) }
        if let sni = config.sni { queryItems.append(.init(name: "sni", value: sni)) }
        if let path = config.path { queryItems.append(.init(name: "path", value: path)) }
        if let flow = config.flow { queryItems.append(.init(name: "flow", value: flow)) }
        components.queryItems = queryItems
        return components.url?.absoluteString ?? config.rawURI
    }

    private static func generateTrojanURI(from config: V2RayConfig) -> String {
        var components = URLComponents()
        components.scheme = "trojan"
        components.user = config.password
        components.host = config.serverAddress
        components.port = config.serverPort
        components.fragment = config.name.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed)
        var queryItems = [URLQueryItem]()
        if let sni = config.sni { queryItems.append(.init(name: "sni", value: sni)) }
        components.queryItems = queryItems
        return components.url?.absoluteString ?? config.rawURI
    }

    private static func generateSSURI(from config: V2RayConfig) -> String {
        let method = config.method ?? "chacha20-ietf-poly1305"
        let password = config.password ?? ""
        let userInfo = "\(method):\(password)"
        let base64 = Data(userInfo.utf8).base64EncodedString()
        let name = config.name.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed) ?? config.name
        return "ss://\(base64)@\(config.serverAddress):\(config.serverPort)#\(name)"
    }
}
