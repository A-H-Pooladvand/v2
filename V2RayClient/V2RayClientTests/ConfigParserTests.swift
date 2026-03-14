import XCTest
@testable import V2RayClient

final class ConfigParserTests: XCTestCase {

    // MARK: - VMess Tests

    func testParseVMessURI() throws {
        // JSON: {"v":"2","ps":"Test Server","add":"example.com","port":"443","id":"12345678-1234-1234-1234-123456789012","aid":"0","scy":"auto","net":"ws","type":"none","host":"example.com","path":"/v2ray","tls":"tls"}
        let json = """
        {"v":"2","ps":"Test Server","add":"example.com","port":"443","id":"12345678-1234-1234-1234-123456789012","aid":"0","scy":"auto","net":"ws","type":"none","host":"example.com","path":"/v2ray","tls":"tls"}
        """
        let base64 = Data(json.utf8).base64EncodedString()
        let uri = "vmess://\(base64)"

        let config = try ConfigParser.parse(uri)

        XCTAssertEqual(config.protocol, .vmess)
        XCTAssertEqual(config.serverAddress, "example.com")
        XCTAssertEqual(config.serverPort, 443)
        XCTAssertEqual(config.name, "Test Server")
        XCTAssertEqual(config.uuid, "12345678-1234-1234-1234-123456789012")
        XCTAssertEqual(config.network, "ws")
        XCTAssertEqual(config.tlsEnabled, true)
        XCTAssertEqual(config.path, "/v2ray")
    }

    func testParseVMessWithIntPort() throws {
        let json = """
        {"v":"2","ps":"Test","add":"example.com","port":443,"id":"12345678-1234-1234-1234-123456789012","aid":0,"net":"tcp","tls":""}
        """
        let base64 = Data(json.utf8).base64EncodedString()
        let uri = "vmess://\(base64)"

        let config = try ConfigParser.parse(uri)
        XCTAssertEqual(config.serverPort, 443)
        XCTAssertEqual(config.alterId, 0)
    }

    func testParseVMessInvalidBase64() {
        let uri = "vmess://not-valid-base64!!!"
        XCTAssertThrowsError(try ConfigParser.parse(uri))
    }

    func testParseVMessMissingAddress() {
        let json = """
        {"v":"2","ps":"Test","add":"","port":"443","id":"12345678-1234-1234-1234-123456789012"}
        """
        let base64 = Data(json.utf8).base64EncodedString()
        let uri = "vmess://\(base64)"
        XCTAssertThrowsError(try ConfigParser.parse(uri)) { error in
            guard let parseError = error as? ConfigParseError,
                  case .missingRequiredField = parseError else {
                XCTFail("Expected missingRequiredField error")
                return
            }
        }
    }

    // MARK: - VLESS Tests

    func testParseVLESSURI() throws {
        let uri = "vless://12345678-1234-1234-1234-123456789012@example.com:443?encryption=none&security=tls&type=ws&host=example.com&path=%2Fv2ray&fp=chrome#My%20Server"

        let config = try ConfigParser.parse(uri)

        XCTAssertEqual(config.protocol, .vless)
        XCTAssertEqual(config.uuid, "12345678-1234-1234-1234-123456789012")
        XCTAssertEqual(config.serverAddress, "example.com")
        XCTAssertEqual(config.serverPort, 443)
        XCTAssertEqual(config.name, "My Server")
        XCTAssertEqual(config.network, "ws")
        XCTAssertEqual(config.tlsEnabled, true)
        XCTAssertEqual(config.path, "/v2ray")
        XCTAssertEqual(config.fingerprint, "chrome")
    }

    func testParseVLESSWithReality() throws {
        let uri = "vless://12345678-1234-1234-1234-123456789012@example.com:443?encryption=none&security=reality&type=tcp&sni=example.com#Reality"

        let config = try ConfigParser.parse(uri)
        XCTAssertEqual(config.protocol, .vless)
        XCTAssertEqual(config.tlsEnabled, true) // reality counts as TLS
        XCTAssertEqual(config.sni, "example.com")
    }

    func testParseVLESSMissingUUID() {
        let uri = "vless://@example.com:443?encryption=none#Test"
        XCTAssertThrowsError(try ConfigParser.parse(uri))
    }

    // MARK: - Trojan Tests

    func testParseTrojanURI() throws {
        let uri = "trojan://mypassword@example.com:443?sni=example.com&type=tcp#My%20Trojan"

        let config = try ConfigParser.parse(uri)

        XCTAssertEqual(config.protocol, .trojan)
        XCTAssertEqual(config.password, "mypassword")
        XCTAssertEqual(config.serverAddress, "example.com")
        XCTAssertEqual(config.serverPort, 443)
        XCTAssertEqual(config.sni, "example.com")
        XCTAssertEqual(config.name, "My Trojan")
        XCTAssertEqual(config.tlsEnabled, true)
    }

    func testParseTrojanMissingPassword() {
        let uri = "trojan://@example.com:443#Test"
        XCTAssertThrowsError(try ConfigParser.parse(uri))
    }

    // MARK: - Shadowsocks Tests

    func testParseShadowsocksURI_SIP002() throws {
        // SIP002 format: ss://BASE64(method:password)@host:port#name
        let userInfo = "chacha20-ietf-poly1305:mypassword"
        let base64 = Data(userInfo.utf8).base64EncodedString()
        let uri = "ss://\(base64)@example.com:8388#My%20SS"

        let config = try ConfigParser.parse(uri)

        XCTAssertEqual(config.protocol, .shadowsocks)
        XCTAssertEqual(config.serverAddress, "example.com")
        XCTAssertEqual(config.serverPort, 8388)
        XCTAssertEqual(config.method, "chacha20-ietf-poly1305")
        XCTAssertEqual(config.password, "mypassword")
        XCTAssertEqual(config.name, "My SS")
    }

    func testParseShadowsocksURILegacy() throws {
        // Legacy: ss://BASE64(method:password@host:port)#name
        let full = "chacha20-ietf-poly1305:mypassword@example.com:8388"
        let base64 = Data(full.utf8).base64EncodedString()
        let uri = "ss://\(base64)#Legacy%20SS"

        let config = try ConfigParser.parse(uri)

        XCTAssertEqual(config.protocol, .shadowsocks)
        XCTAssertEqual(config.serverAddress, "example.com")
        XCTAssertEqual(config.serverPort, 8388)
        XCTAssertEqual(config.method, "chacha20-ietf-poly1305")
        XCTAssertEqual(config.password, "mypassword")
    }

    func testParseShadowsocksPasswordWithColon() throws {
        // Password containing colon should be handled
        let userInfo = "aes-256-gcm:pass:word:with:colons"
        let base64 = Data(userInfo.utf8).base64EncodedString()
        let uri = "ss://\(base64)@example.com:8388#Test"

        let config = try ConfigParser.parse(uri)
        XCTAssertEqual(config.method, "aes-256-gcm")
        XCTAssertEqual(config.password, "pass:word:with:colons")
    }

    // MARK: - SOCKS Tests

    func testParseSOCKSURI() throws {
        let uri = "socks://user:pass@example.com:1080#My%20Socks"

        let config = try ConfigParser.parse(uri)

        XCTAssertEqual(config.protocol, .socks)
        XCTAssertEqual(config.serverAddress, "example.com")
        XCTAssertEqual(config.serverPort, 1080)
        XCTAssertEqual(config.uuid, "user")
        XCTAssertEqual(config.password, "pass")
    }

    func testParseSOCKS5URI() throws {
        let uri = "socks5://user:pass@example.com:1080#SOCKS5"
        let config = try ConfigParser.parse(uri)
        XCTAssertEqual(config.protocol, .socks)
        XCTAssertEqual(config.serverPort, 1080)
    }

    // MARK: - HTTP Tests

    func testParseHTTPURI() throws {
        let uri = "http://user:pass@proxy.example.com:8080#HTTP%20Proxy"

        let config = try ConfigParser.parse(uri)

        XCTAssertEqual(config.protocol, .http)
        XCTAssertEqual(config.serverAddress, "proxy.example.com")
        XCTAssertEqual(config.serverPort, 8080)
        XCTAssertEqual(config.tlsEnabled, false)
    }

    func testParseHTTPSURI() throws {
        let uri = "https://proxy.example.com:443#HTTPS%20Proxy"

        let config = try ConfigParser.parse(uri)
        XCTAssertEqual(config.protocol, .http)
        XCTAssertEqual(config.serverPort, 443)
        XCTAssertEqual(config.tlsEnabled, true)
    }

    // MARK: - JSON Tests

    func testParseRawJSON() throws {
        let json = """
        {
          "inbounds": [{"port": 1080, "protocol": "socks"}],
          "outbounds": [{
            "protocol": "vmess",
            "settings": {
              "vnext": [{"address": "example.com", "port": 443, "users": [{"id": "test-id"}]}]
            }
          }]
        }
        """

        let config = try ConfigParser.parse(json)

        XCTAssertEqual(config.protocol, .json)
        XCTAssertEqual(config.serverAddress, "example.com")
        XCTAssertEqual(config.serverPort, 443)
    }

    func testParseRawJSONWithShadowsocksServer() throws {
        let json = """
        {
          "outbounds": [{
            "protocol": "shadowsocks",
            "settings": {
              "servers": [{"address": "ss.example.com", "port": 8388}]
            }
          }]
        }
        """

        let config = try ConfigParser.parse(json)
        XCTAssertEqual(config.protocol, .json)
        XCTAssertEqual(config.serverAddress, "ss.example.com")
        XCTAssertEqual(config.serverPort, 8388)
    }

    func testParseInvalidJSON() {
        let invalid = "{not valid json"
        XCTAssertThrowsError(try ConfigParser.parseRawJSON(invalid)) { error in
            guard let parseError = error as? ConfigParseError,
                  case .invalidJSON = parseError else {
                XCTFail("Expected invalidJSON error")
                return
            }
        }
    }

    // MARK: - Empty Input

    func testParseEmptyInput() {
        XCTAssertThrowsError(try ConfigParser.parse("")) { error in
            guard let parseError = error as? ConfigParseError,
                  case .emptyInput = parseError else {
                XCTFail("Expected emptyInput error")
                return
            }
        }
    }

    func testParseWhitespaceInput() {
        XCTAssertThrowsError(try ConfigParser.parse("   \n\t  ")) { error in
            guard let parseError = error as? ConfigParseError,
                  case .emptyInput = parseError else {
                XCTFail("Expected emptyInput error")
                return
            }
        }
    }

    // MARK: - Unsupported Protocol

    func testParseUnsupportedProtocol() {
        XCTAssertThrowsError(try ConfigParser.parse("xyz://example.com")) { error in
            guard let parseError = error as? ConfigParseError,
                  case .unsupportedProtocol = parseError else {
                XCTFail("Expected unsupportedProtocol error")
                return
            }
        }
    }

    // MARK: - URI Generation

    func testGenerateVMessURI() throws {
        let json = """
        {"v":"2","ps":"Test","add":"example.com","port":"443","id":"12345678-1234-1234-1234-123456789012","aid":"0","scy":"auto","net":"tcp","type":"none","tls":""}
        """
        let base64 = Data(json.utf8).base64EncodedString()
        let originalURI = "vmess://\(base64)"

        let config = try ConfigParser.parse(originalURI)
        let generatedURI = ConfigParser.generateURI(from: config)

        XCTAssertTrue(generatedURI.hasPrefix("vmess://"))

        // Re-parse generated URI to verify round-trip
        let reparsed = try ConfigParser.parse(generatedURI)
        XCTAssertEqual(reparsed.serverAddress, config.serverAddress)
        XCTAssertEqual(reparsed.serverPort, config.serverPort)
        XCTAssertEqual(reparsed.uuid, config.uuid)
    }

    func testGenerateVLESSURI() throws {
        let original = "vless://12345678-1234-1234-1234-123456789012@example.com:443?encryption=none&type=tcp#Test"
        let config = try ConfigParser.parse(original)
        let generated = ConfigParser.generateURI(from: config)

        XCTAssertTrue(generated.hasPrefix("vless://"))
        let reparsed = try ConfigParser.parse(generated)
        XCTAssertEqual(reparsed.serverAddress, "example.com")
        XCTAssertEqual(reparsed.serverPort, 443)
    }

    func testGenerateSSURI() throws {
        let userInfo = "chacha20-ietf-poly1305:testpass"
        let base64 = Data(userInfo.utf8).base64EncodedString()
        let original = "ss://\(base64)@example.com:8388#Test"
        let config = try ConfigParser.parse(original)
        let generated = ConfigParser.generateURI(from: config)

        XCTAssertTrue(generated.hasPrefix("ss://"))
        let reparsed = try ConfigParser.parse(generated)
        XCTAssertEqual(reparsed.serverAddress, "example.com")
    }

    // MARK: - Auto-detect from URI list

    func testAutoDetectVMessFromBase64WrappedURI() throws {
        let json = """
        {"v":"2","ps":"Wrapped","add":"example.com","port":"443","id":"12345678-1234-1234-1234-123456789012","aid":"0","scy":"auto","net":"tcp","type":"none","tls":""}
        """
        let innerBase64 = Data(json.utf8).base64EncodedString()
        let vmessURI = "vmess://\(innerBase64)"
        // Wrap the whole URI in base64 (some clients do this)
        let outerBase64 = Data(vmessURI.utf8).base64EncodedString()

        let config = try ConfigParser.parse(outerBase64)
        XCTAssertEqual(config.protocol, .vmess)
        XCTAssertEqual(config.serverAddress, "example.com")
    }

    // MARK: - Protocol Display Names

    func testProtocolDisplayNames() {
        XCTAssertEqual(V2RayProtocol.vmess.displayName, "VMess")
        XCTAssertEqual(V2RayProtocol.vless.displayName, "VLESS")
        XCTAssertEqual(V2RayProtocol.trojan.displayName, "Trojan")
        XCTAssertEqual(V2RayProtocol.shadowsocks.displayName, "Shadowsocks")
        XCTAssertEqual(V2RayProtocol.socks.displayName, "SOCKS")
        XCTAssertEqual(V2RayProtocol.http.displayName, "HTTP")
        XCTAssertEqual(V2RayProtocol.json.displayName, "JSON")
    }

    // MARK: - Config Display Name

    func testConfigDisplayNameWithName() throws {
        let uri = "trojan://pass@example.com:443?sni=example.com#My%20Named%20Config"
        let config = try ConfigParser.parse(uri)
        XCTAssertEqual(config.displayName, "My Named Config")
    }

    func testConfigDisplayNameWithoutName() throws {
        let uri = "trojan://pass@example.com:443"
        let config = try ConfigParser.parse(uri)
        // Name is empty, so displayName falls back to "Protocol - host:port"
        XCTAssertTrue(config.displayName.contains("example.com"))
        XCTAssertTrue(config.displayName.contains("443"))
    }

    // MARK: - AppSettings Default Values

    func testAppSettingsDefaults() {
        let settings = AppSettings.default
        XCTAssertFalse(settings.upstreamProxyEnabled)
        XCTAssertEqual(settings.upstreamProxyType, .socks5)
        XCTAssertEqual(settings.upstreamProxyPort, 1080)
        XCTAssertFalse(settings.customDNSEnabled)
        XCTAssertEqual(settings.primaryDNS, "8.8.8.8")
        XCTAssertEqual(settings.secondaryDNS, "8.8.4.4")
        XCTAssertTrue(settings.bypassLAN)
        XCTAssertFalse(settings.bypassChinaMainland)
        XCTAssertTrue(settings.enableSniffing)
        XCTAssertEqual(settings.localSocksPort, 1080)
        XCTAssertEqual(settings.localHttpPort, 8080)
        XCTAssertFalse(settings.allowLANConnections)
        XCTAssertFalse(settings.autoConnect)
    }
}
