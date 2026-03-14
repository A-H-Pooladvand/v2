import SwiftUI

struct ConfigDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var storageService: StorageService
    let config: V2RayConfig

    @State private var showingShareSheet = false
    @State private var showingDeleteAlert = false
    @State private var copiedToClipboard = false
    @State private var showQRCode = false

    var body: some View {
        NavigationStack {
            List {
                // Header section
                Section {
                    HStack {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(protocolColor.opacity(0.15))
                                .frame(width: 56, height: 56)
                            Image(systemName: config.protocol.iconName)
                                .font(.system(size: 24, weight: .medium))
                                .foregroundColor(protocolColor)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(config.displayName)
                                .font(.title3)
                                .fontWeight(.semibold)
                            Text(config.protocol.displayName)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.leading, 8)
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }

                // Server Info
                Section("Server") {
                    DetailRow(label: "Address", value: config.serverAddress)
                    DetailRow(label: "Port", value: String(config.serverPort))
                    if let uuid = config.uuid {
                        DetailRow(label: "UUID / ID", value: uuid, sensitive: true)
                    }
                    if let password = config.password {
                        DetailRow(label: "Password", value: password, sensitive: true)
                    }
                }

                // Protocol-specific
                if hasProtocolDetails {
                    Section("Protocol Details") {
                        if let network = config.network {
                            DetailRow(label: "Network", value: network)
                        }
                        if let security = config.security {
                            DetailRow(label: "Security", value: security)
                        }
                        if let alterId = config.alterId {
                            DetailRow(label: "Alter ID", value: String(alterId))
                        }
                        if config.tlsEnabled == true {
                            DetailRow(label: "TLS", value: "Enabled")
                        }
                        if let sni = config.sni, !sni.isEmpty {
                            DetailRow(label: "SNI", value: sni)
                        }
                        if let path = config.path, !path.isEmpty {
                            DetailRow(label: "Path", value: path)
                        }
                        if let host = config.requestHost, !host.isEmpty {
                            DetailRow(label: "Host", value: host)
                        }
                        if let fingerprint = config.fingerprint, !fingerprint.isEmpty {
                            DetailRow(label: "Fingerprint", value: fingerprint)
                        }
                        if let flow = config.flow, !flow.isEmpty {
                            DetailRow(label: "Flow", value: flow)
                        }
                        if let method = config.method {
                            DetailRow(label: "Method", value: method)
                        }
                    }
                }

                // Raw URI
                Section("Share") {
                    // QR Code button
                    Button {
                        showQRCode = true
                    } label: {
                        Label("Show QR Code", systemImage: "qrcode")
                    }

                    // Copy URI button
                    Button {
                        UIPasteboard.general.string = config.rawURI
                        copiedToClipboard = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            copiedToClipboard = false
                        }
                    } label: {
                        Label(
                            copiedToClipboard ? "Copied!" : "Copy Config URI",
                            systemImage: copiedToClipboard ? "checkmark.circle.fill" : "doc.on.doc"
                        )
                        .foregroundColor(copiedToClipboard ? .green : .primary)
                    }
                }

                // Danger zone
                Section {
                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        Label("Delete Configuration", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("Config Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Delete Config", isPresented: $showingDeleteAlert) {
                Button("Delete", role: .destructive) {
                    storageService.removeConfig(id: config.id)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This action cannot be undone.")
            }
            .sheet(isPresented: $showQRCode) {
                QRCodeDisplayView(uri: config.rawURI, title: config.displayName)
            }
        }
    }

    private var hasProtocolDetails: Bool {
        config.network != nil || config.security != nil || config.alterId != nil
            || config.tlsEnabled != nil || config.sni != nil || config.path != nil
            || config.requestHost != nil || config.method != nil || config.flow != nil
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

// MARK: - Detail Row

struct DetailRow: View {
    let label: String
    let value: String
    var sensitive: Bool = false
    @State private var isRevealed = false

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            if sensitive && !isRevealed {
                Text("••••••••")
                    .foregroundColor(.secondary)
                    .onTapGesture { isRevealed = true }
            } else {
                Text(value)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)
                    .onTapGesture {
                        UIPasteboard.general.string = value
                    }
            }
        }
    }
}

// MARK: - QR Code Display View

struct QRCodeDisplayView: View {
    @Environment(\.dismiss) private var dismiss
    let uri: String
    let title: String

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if let qrImage = generateQRCode(from: uri) {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 260, height: 260)
                        .padding()
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.1), radius: 8)
                } else {
                    Text("Could not generate QR code")
                        .foregroundColor(.secondary)
                }

                Text("Scan this QR code to import the config")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func generateQRCode(from string: String) -> UIImage? {
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        let data = Data(string.utf8)
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let ciImage = filter.outputImage else { return nil }
        let scale: CGFloat = 10
        let transform = CGAffineTransform(scaleX: scale, y: scale)
        let scaledImage = ciImage.transformed(by: transform)
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
