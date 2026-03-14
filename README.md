# V2Ray Client for iOS

A native iOS application for connecting to v2ray proxy configurations, built with SwiftUI. Import configs from clipboard, QR codes, or your photo gallery — and manage your proxy settings with ease.

---

## Table of Contents

- [Features](#features)
- [Screenshots](#screenshots)
- [Requirements](#requirements)
- [Installation](#installation)
  - [Option A: Build from Source with Xcode](#option-a-build-from-source-with-xcode)
  - [Option B: TestFlight / Ad Hoc Distribution](#option-b-testflight--ad-hoc-distribution)
  - [Option C: Sideloading with AltStore](#option-c-sideloading-with-altstore)
- [Project Structure](#project-structure)
- [Configuration Import Methods](#configuration-import-methods)
  - [1. Paste URI from Clipboard](#1-paste-uri-from-clipboard)
  - [2. Paste JSON Config from Clipboard](#2-paste-json-config-from-clipboard)
  - [3. Scan QR Code with Camera](#3-scan-qr-code-with-camera)
  - [4. Import QR Code from Gallery](#4-import-qr-code-from-gallery)
- [Supported Protocols](#supported-protocols)
- [Settings](#settings)
  - [Upstream Proxy](#upstream-proxy)
  - [DNS Configuration](#dns-configuration)
  - [Routing Rules](#routing-rules)
  - [Local Inbound Ports](#local-inbound-ports)
- [VPN Integration](#vpn-integration)
  - [Integrating v2ray-core / Xray-core](#integrating-v2ray-core--xray-core)
- [Testing](#testing)
- [Permissions](#permissions)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)

---

## Features

| Feature | Description |
|---------|-------------|
| 📋 **Clipboard Import (URI)** | Import `vmess://`, `vless://`, `trojan://`, `ss://` configs directly from clipboard |
| 📄 **Clipboard Import (JSON)** | Paste a full v2ray JSON configuration from clipboard |
| 📷 **QR Code Scanner** | Use the camera to scan a QR code containing a proxy config |
| 🖼️ **Gallery QR Import** | Pick an image from your photo library and automatically decode the QR code |
| ⚙️ **Upstream Proxy** | Route v2ray traffic through an upstream HTTP/SOCKS5 proxy |
| 🔒 **Secure Storage** | Configs stored locally using `UserDefaults` with Codable encoding |
| 📱 **SwiftUI Native UI** | Modern, responsive UI built with SwiftUI for iOS 16+ |
| 🌐 **Network Extension** | VPN tunneling via `NetworkExtension` framework |

---

## Screenshots

> Run the app in the iOS Simulator or on a physical device to see it in action.

```
┌─────────────────────┐    ┌─────────────────────┐    ┌─────────────────────┐
│  V2Ray Client       │    │  Add Configuration  │    │  Settings           │
│ ─────────────────── │    │ ─────────────────── │    │ ─────────────────── │
│  ●  Disconnected    │    │  📋 Paste from      │    │  Upstream Proxy     │
│     [Connect]       │    │     Clipboard        │    │  [Toggle]           │
│                     │    │  📄 Paste JSON       │    │  Type: SOCKS5       │
│  [+] No configs     │    │  📷 Scan QR Code    │    │  Host: 127.0.0.1   │
│  Tap + to import    │    │  🖼️ From Gallery    │    │  Port: 1080         │
│                     │    │                     │    │                     │
│  ──────────────────│    │                     │    │  DNS Settings       │
│  Configs | Settings │    │  Cancel             │    │  Routing | About    │
└─────────────────────┘    └─────────────────────┘    └─────────────────────┘
```

---

## Requirements

| Requirement | Version |
|-------------|---------|
| **iOS** | 16.0+ |
| **Xcode** | 15.0+ |
| **Swift** | 5.9+ |
| **macOS (for building)** | 13.0 (Ventura)+ |
| **Apple Developer Account** | Required for device deployment & VPN entitlements |

---

## Installation

### Option A: Build from Source with Xcode

This is the recommended method for developers.

#### Step 1: Clone the Repository

```bash
git clone https://github.com/A-H-Pooladvand/v2.git
cd v2/V2RayClient
```

#### Step 2: Open the Project in Xcode

```bash
open V2RayClient.xcodeproj
```

Or double-click `V2RayClient.xcodeproj` in Finder.

#### Step 3: Configure Signing

1. In Xcode, select the **V2RayClient** project in the navigator.
2. Select the **V2RayClient** target.
3. Under **Signing & Capabilities**, choose your **Team** (requires Apple Developer account).
4. Change `PRODUCT_BUNDLE_IDENTIFIER` to a unique identifier, e.g. `com.yourname.v2rayclient`.

> **Note:** The VPN / NetworkExtension capability requires a **paid Apple Developer account** ($99/year). Without it, you can still build and run the app but the VPN connect/disconnect functionality will not work. All other features (config import, parsing, storage) work without an Apple Developer account.

#### Step 4: Build and Run

- **Simulator:** Select an iOS 16+ simulator and press `⌘R`.
- **Physical Device:** Connect your iPhone/iPad via USB, select it as the run destination, and press `⌘R`.

---

### Option B: TestFlight / Ad Hoc Distribution

To distribute the app for testing:

1. **Archive the app:** In Xcode, choose **Product → Archive**.
2. In the **Organizer**, select the archive and click **Distribute App**.
3. Choose **TestFlight & App Store** or **Ad Hoc** distribution.
4. Follow the prompts to upload or export the `.ipa` file.

For TestFlight, testers install the **TestFlight** app from the App Store and accept your invitation link.

---

### Option C: Sideloading with AltStore

If you don't have a paid developer account, you can sideload with [AltStore](https://altstore.io):

1. Install **AltStore** on your Mac/PC and your iPhone.
2. In Xcode, export the app: **Product → Archive → Distribute App → Development → Export**.
3. Open **AltStore** on your iPhone and sideload the exported `.ipa`.

> **Limitation:** Sideloaded apps expire after 7 days (free account) or 1 year (paid account). The VPN entitlement may not work without a proper developer account.

---

## Project Structure

```
V2RayClient/
├── V2RayClient.xcodeproj/          # Xcode project file
│   └── project.pbxproj
├── V2RayClient/
│   ├── V2RayClientApp.swift        # @main App entry point
│   ├── Models/
│   │   ├── V2RayConfig.swift       # Data model for proxy configs (VMess, VLESS, Trojan, SS...)
│   │   └── AppSettings.swift       # App settings model (proxy, DNS, routing)
│   ├── Views/
│   │   ├── MainView.swift          # Tab bar container (Configs + Settings)
│   │   ├── ConfigListView.swift    # Main list of configs + connect/disconnect
│   │   ├── ConfigDetailView.swift  # Detailed view of a single config + QR share
│   │   ├── AddConfigView.swift     # Import methods menu (4 options)
│   │   ├── QRScannerView.swift     # AVFoundation camera-based QR scanner
│   │   └── SettingsView.swift      # App settings (proxy, DNS, routing, ports)
│   ├── Services/
│   │   ├── ConfigParser.swift      # Parses v2ray URIs and JSON configs
│   │   ├── VPNManager.swift        # NetworkExtension VPN management
│   │   └── StorageService.swift    # UserDefaults-based persistence
│   ├── Assets.xcassets/            # App icons and accent color
│   ├── Info.plist                  # App metadata and permission descriptions
│   └── V2RayClient.entitlements    # VPN/NetworkExtension entitlements
└── README.md                       # This file
```

---

## Configuration Import Methods

### 1. Paste URI from Clipboard

**How to use:**
1. Copy a proxy URI to your clipboard (e.g., `vmess://...`, `vless://...`, `trojan://...`, `ss://...`).
2. Open the app and tap the **+** button.
3. Tap **"Paste from Clipboard"**.
4. The URI is automatically parsed and saved.

**Supported URI formats:**
- `vmess://BASE64_ENCODED_JSON`
- `vless://UUID@host:port?params#name`
- `trojan://password@host:port?params#name`
- `ss://BASE64(method:password)@host:port#name`
- `socks://user:pass@host:port#name`
- `http://user:pass@host:port#name`

**Example VMess URI:**
```
vmess://eyJ2IjoiMiIsInBzIjoiTXkgU2VydmVyIiwiYWRkIjoiZXhhbXBsZS5jb20iLCJwb3J0IjoiNDQzIiwiaWQiOiIxMjM0NTY3OC0xMjM0LTEyMzQtMTIzNC0xMjM0NTY3ODkwMTIiLCJhaWQiOiIwIiwic2N5IjoiYXV0byIsIm5ldCI6IndzIiwidHlwZSI6Im5vbmUiLCJob3N0IjoiZXhhbXBsZS5jb20iLCJwYXRoIjoiL3YycmF5IiwidGxzIjoidGxzIn0=
```

**Example VLESS URI:**
```
vless://12345678-1234-1234-1234-123456789012@example.com:443?encryption=none&security=tls&type=ws&host=example.com&path=%2Fv2ray#My%20Server
```

**Example Trojan URI:**
```
trojan://mypassword@example.com:443?sni=example.com#My%20Trojan
```

**Example Shadowsocks URI:**
```
ss://Y2hhY2hhMjAtaWV0Zi1wb2x5MTMwNTpteXBhc3N3b3Jk@example.com:8388#My%20SS
```

---

### 2. Paste JSON Config from Clipboard

**How to use:**
1. Copy a complete v2ray JSON configuration to your clipboard.
2. Open the app and tap the **+** button.
3. Tap **"Paste JSON Config"**.
4. The JSON is validated and saved.

**Example v2ray JSON:**
```json
{
  "inbounds": [{
    "port": 1080,
    "protocol": "socks",
    "settings": { "auth": "noauth" }
  }],
  "outbounds": [{
    "protocol": "vmess",
    "settings": {
      "vnext": [{
        "address": "example.com",
        "port": 443,
        "users": [{
          "id": "12345678-1234-1234-1234-123456789012",
          "alterId": 0,
          "security": "auto"
        }]
      }]
    },
    "streamSettings": {
      "network": "ws",
      "wsSettings": { "path": "/v2ray" },
      "security": "tls"
    }
  }]
}
```

---

### 3. Scan QR Code with Camera

**How to use:**
1. Tap the **+** button in the app.
2. Tap **"Scan QR Code"**.
3. Grant camera permission if prompted.
4. Point your camera at the QR code — it is detected automatically.
5. The config is parsed and saved immediately upon detection.

**Features:**
- Auto-detection without needing to tap a capture button.
- Flashlight toggle for dark environments.
- Visual scanning frame with animated scan line.
- Haptic feedback on successful scan.

---

### 4. Import QR Code from Gallery

**How to use:**
1. Tap the **+** button in the app.
2. Tap **"Import from Gallery"**.
3. Grant photo library permission if prompted.
4. Select an image containing a QR code.
5. The app uses `CIDetector` to decode the QR code from the image.
6. The config is parsed and saved.

**Supported image formats:** JPG, PNG, HEIC, and any format supported by iOS Photos.

**Tips:**
- The image should have good contrast and the QR code should be clearly visible.
- Cropped or zoomed images also work as long as the QR code is complete.

---

## Supported Protocols

| Protocol | URI Scheme | Notes |
|----------|-----------|-------|
| **VMess** | `vmess://` | Base64-encoded JSON. Supports WebSocket, TCP, H2, gRPC transports |
| **VLESS** | `vless://` | URL-encoded params. Supports Reality, TLS |
| **Trojan** | `trojan://` | TLS required |
| **Shadowsocks** | `ss://` | Supports SIP002 and legacy formats |
| **SOCKS5** | `socks://` | Optional auth |
| **HTTP Proxy** | `http://` | Also `https://` |
| **Raw JSON** | `{...}` | Full v2ray/Xray JSON configuration |

---

## Settings

### Upstream Proxy

Configure an upstream proxy server that v2ray traffic will be routed through before reaching the destination.

| Setting | Description | Default |
|---------|-------------|---------|
| Enable Upstream Proxy | Toggle upstream proxy on/off | Off |
| Proxy Type | HTTP, HTTPS, SOCKS5, or SOCKS4 | SOCKS5 |
| Host | Proxy server hostname or IP | — |
| Port | Proxy server port | 1080 |
| Username | Optional authentication | — |
| Password | Optional authentication | — |

**Use case:** This is useful when:
- You're behind a corporate firewall that requires an HTTP proxy.
- You want to chain proxies (e.g., v2ray → upstream SOCKS5).
- Testing locally with a proxy debugger like Charles or mitmproxy.

**Example: Using a local SOCKS5 proxy as upstream:**
```
Type: SOCKS5
Host: 127.0.0.1
Port: 1086
```

---

### DNS Configuration

| Setting | Description | Default |
|---------|-------------|---------|
| Custom DNS | Enable custom DNS servers | Off |
| Primary DNS | First DNS server | 8.8.8.8 |
| Secondary DNS | Fallback DNS server | 8.8.4.4 |

**Recommended DNS servers:**
- `8.8.8.8` / `8.8.4.4` — Google DNS
- `1.1.1.1` / `1.0.0.1` — Cloudflare DNS
- `9.9.9.9` / `149.112.112.112` — Quad9 DNS

---

### Routing Rules

| Setting | Description | Default |
|---------|-------------|---------|
| Bypass LAN | Direct connection for local network addresses | On |
| Bypass China Mainland | Direct routing for Chinese domains/IPs | Off |
| Enable Sniffing | Detect traffic protocol for better routing | On |

---

### Local Inbound Ports

| Setting | Description | Default |
|---------|-------------|---------|
| SOCKS Port | Local SOCKS5 proxy port | 1080 |
| HTTP Port | Local HTTP proxy port | 8080 |
| Allow LAN Connections | Allow other devices on LAN to use the proxy | Off |

---

## VPN Integration

The app uses iOS `NetworkExtension` framework for VPN management. The current implementation uses `NEVPNManager` for the VPN lifecycle, which is suitable for integrating with a tunnel provider.

### How Connection Works

1. User selects a config and taps **Connect**.
2. `VPNManager.connect()` loads preferences from `NEVPNManager`.
3. The VPN tunnel is started via `NEVPNManager.shared().connection.startVPNTunnel()`.
4. Connection status is observed via `NEVPNStatusDidChange` notifications.

### Integrating v2ray-core / Xray-core

For full v2ray tunneling, you need to integrate a v2ray-core library. Here's how:

#### Step 1: Add a Network Extension Target

1. In Xcode, go to **File → New → Target**.
2. Select **Network Extension** → **Packet Tunnel Provider**.
3. Name it `V2RayTunnel`.
4. Enable the **Network Extension** capability on the new target.

#### Step 2: Add Xray-core Framework

Use the pre-built iOS framework from [Xray-core](https://github.com/XTLS/Xray-core) or [v2ray-core](https://github.com/v2ray/v2ray-core):

```bash
# Using gomobile to build v2ray-core for iOS
git clone https://github.com/v2fly/v2ray-core.git
cd v2ray-core
gomobile bind -target=ios -o V2RayCore.xcframework ./...
```

Add the resulting `V2RayCore.xcframework` to the `V2RayTunnel` target.

#### Step 3: Implement PacketTunnelProvider

```swift
// V2RayTunnel/PacketTunnelProvider.swift
import NetworkExtension

class PacketTunnelProvider: NEPacketTunnelProvider {
    override func startTunnel(options: [String: NSObject]? = nil) async throws {
        // Load config from shared UserDefaults (App Group)
        let defaults = UserDefaults(suiteName: "group.com.v2rayclient.app")
        guard let configJSON = defaults?.string(forKey: "active_config_json") else {
            throw NSError(domain: "V2RayTunnel", code: -1)
        }
        
        // Start v2ray-core with the config
        // V2RayCoreStart(configJSON) // from the framework
        
        // Configure tunnel network settings
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")
        settings.ipv4Settings = NEIPv4Settings(addresses: ["10.0.0.1"], subnetMasks: ["255.255.255.0"])
        settings.ipv4Settings?.includedRoutes = [NEIPv4Route.default()]
        settings.dnsSettings = NEDNSSettings(servers: ["8.8.8.8"])
        
        try await setTunnelNetworkSettings(settings)
    }
    
    override func stopTunnel(with reason: NEProviderStopReason) async {
        // V2RayCoreStop()
    }
}
```

#### Step 4: Update VPNManager to Use NETunnelProviderManager

```swift
// In VPNManager.swift, replace NEVPNManager with NETunnelProviderManager:
let manager = NETunnelProviderManager()
let proto = NETunnelProviderProtocol()
proto.providerBundleIdentifier = "com.v2rayclient.app.tunnel"
proto.serverAddress = config.serverAddress
manager.protocolConfiguration = proto
```

---

## Testing

### Running Tests

The project includes Swift unit tests for the config parser:

```bash
# Run tests in Xcode
# Press ⌘U or go to Product → Test

# Or using xcodebuild from command line:
xcodebuild test \
  -project V2RayClient.xcodeproj \
  -scheme V2RayClient \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=17.0'
```

### Manual Testing Checklist

#### Config Import
- [ ] Copy a VMess URI and use "Paste from Clipboard" — config should appear in list
- [ ] Copy a VLESS URI and import — verify all fields are correctly parsed
- [ ] Copy a Trojan URI and import
- [ ] Copy a Shadowsocks URI and import
- [ ] Copy a v2ray JSON object and use "Paste JSON Config"
- [ ] Scan a QR code with camera — grant permission, scan, verify config saved
- [ ] Save a v2ray config QR code as an image and use "Import from Gallery"

#### Config Management
- [ ] Select a config by tapping its row — checkmark appears
- [ ] View config details by tapping the info button
- [ ] Generate and display QR code for a config
- [ ] Copy config URI from detail view
- [ ] Delete a config with swipe-to-delete

#### Settings
- [ ] Enable upstream proxy, fill in host/port, save settings
- [ ] Toggle custom DNS, enter DNS servers
- [ ] Toggle bypass LAN, bypass China Mainland
- [ ] Change local SOCKS/HTTP port numbers
- [ ] Reset settings to defaults

#### Connection (requires VPN entitlement)
- [ ] Select a config and tap Connect — status changes to Connecting
- [ ] Verify status changes to Connected (requires v2ray-core integration)
- [ ] Tap Disconnect — status returns to Disconnected

### Test Config URIs

Use these for testing:

```
# VMess (test only, not a real server)
vmess://eyJ2IjoiMiIsInBzIjoiVGVzdCBTZXJ2ZXIiLCJhZGQiOiIxMjcuMC4wLjEiLCJwb3J0IjoiMTA4MCIsImlkIjoiMTIzNDU2NzgtMTIzNC0xMjM0LTEyMzQtMTIzNDU2Nzg5MDEyIiwiYWlkIjoiMCIsInNjeSI6ImF1dG8iLCJuZXQiOiJ0Y3AiLCJ0eXBlIjoibm9uZSIsInRscyI6IiJ9

# VLESS
vless://12345678-1234-1234-1234-123456789012@127.0.0.1:1080?encryption=none&type=tcp#Test%20VLESS

# Trojan
trojan://testpassword@127.0.0.1:1080?sni=test.example.com#Test%20Trojan

# Shadowsocks
ss://Y2hhY2hhMjAtaWV0Zi1wb2x5MTMwNTp0ZXN0cGFzc3dvcmQ=@127.0.0.1:8388#Test%20SS
```

---

## Permissions

The app requests the following permissions:

| Permission | Purpose | Required |
|------------|---------|----------|
| **Camera** (`NSCameraUsageDescription`) | Scan QR codes using the camera | Optional |
| **Photo Library** (`NSPhotoLibraryUsageDescription`) | Import QR code images from gallery | Optional |
| **VPN** (`com.apple.developer.networking.networkextension`) | Establish VPN tunnel for proxy connection | Optional |

All permissions are requested only when the relevant feature is used. The app functions without any of these permissions (config storage and parsing work without them).

---

## Troubleshooting

### "Clipboard is empty" when trying to paste
- Ensure you have copied the config URI to your clipboard before tapping import.
- Some apps use rich text — copy from a plain text source if possible.

### Camera permission denied
- Go to **Settings → Privacy & Security → Camera → V2Ray Client** and enable access.

### Photo Library permission denied
- Go to **Settings → Privacy & Security → Photos → V2Ray Client** and set to "All Photos" or "Selected Photos".

### QR code not detected from gallery
- Ensure the image has good resolution and contrast.
- Try cropping the image to just the QR code.
- Make sure the QR code is not damaged or partially obscured.

### VPN won't connect / "Not Configured" state
- A paid Apple Developer account is required for VPN entitlements.
- Ensure the `com.apple.developer.networking.networkextension` entitlement is enabled.
- Check that your bundle ID matches what's provisioned in your Developer portal.
- For full tunneling, you must integrate v2ray-core (see [VPN Integration](#vpn-integration)).

### Build fails with "No such module 'NetworkExtension'"
- Ensure **NetworkExtension.framework** is added to the target's linked frameworks.
- In Xcode: Target → Build Phases → Link Binary With Libraries → + → NetworkExtension.framework.

### App crashes on launch in Simulator
- The Simulator does not support VPN tunneling. The app will show "Not Configured" for connection state, which is expected.
- All other features (config import, parsing, storage, settings) work in the Simulator.

---

## Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Make your changes following the existing code style
4. Add tests for new functionality
5. Commit: `git commit -m 'Add my feature'`
6. Push: `git push origin feature/my-feature`
7. Open a Pull Request

### Code Style
- Use SwiftUI best practices
- Follow Swift naming conventions
- Add `// MARK: -` comments for code organization
- Keep views focused and composable

---

## License

This project is licensed under the MIT License.

---

## Acknowledgments

- [v2ray-core](https://github.com/v2ray/v2ray-core) — The underlying proxy protocol
- [Xray-core](https://github.com/XTLS/Xray-core) — Enhanced v2ray implementation
- [Apple NetworkExtension](https://developer.apple.com/documentation/networkextension) — iOS VPN framework

---

*Made with ❤️ for the open-source community*