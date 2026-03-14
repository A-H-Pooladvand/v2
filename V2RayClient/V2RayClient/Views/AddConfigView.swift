import SwiftUI
import PhotosUI

struct AddConfigView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var storageService: StorageService

    @State private var showingQRScanner = false
    @State private var showingImagePicker = false
    @State private var showingManualJSON = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var importSuccess = false
    @State private var importedConfig: V2RayConfig?
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showingImportSuccess = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    headerView
                }
                .listRowBackground(Color.clear)
                .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))

                Section("Import Methods") {
                    // 1. Import from clipboard (URI)
                    ImportOptionRow(
                        icon: "doc.on.clipboard.fill",
                        iconColor: .blue,
                        title: "Paste from Clipboard",
                        subtitle: "Import vmess://, vless://, trojan://, ss:// URI"
                    ) {
                        importFromClipboard()
                    }

                    // 2. Import JSON from clipboard
                    ImportOptionRow(
                        icon: "doc.text.fill",
                        iconColor: .purple,
                        title: "Paste JSON Config",
                        subtitle: "Import a full v2ray JSON configuration"
                    ) {
                        importJSONFromClipboard()
                    }

                    // 3. Scan QR code from camera
                    ImportOptionRow(
                        icon: "qrcode.viewfinder",
                        iconColor: .orange,
                        title: "Scan QR Code",
                        subtitle: "Use the camera to scan a QR code"
                    ) {
                        showingQRScanner = true
                    }

                    // 4. Import QR from gallery
                    PhotosPicker(
                        selection: $selectedPhotoItem,
                        matching: .images
                    ) {
                        ImportOptionRow(
                            icon: "photo.on.rectangle.angled",
                            iconColor: .green,
                            title: "Import from Gallery",
                            subtitle: "Pick an image from your photo library",
                            showChevron: true
                        )
                    }
                    .onChange(of: selectedPhotoItem) { _, newItem in
                        if let newItem {
                            processGalleryImage(newItem)
                        }
                    }
                }

                Section("Tips") {
                    tipsView
                }
            }
            .navigationTitle("Add Configuration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showingQRScanner) {
                QRScannerView { scannedString in
                    showingQRScanner = false
                    processScannedString(scannedString)
                }
            }
            .alert("Import Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .alert("Config Imported", isPresented: $showingImportSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                if let config = importedConfig {
                    Text("Successfully imported:\n\(config.displayName)")
                }
            }
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.and.arrow.down.fill")
                .font(.system(size: 44))
                .foregroundColor(.blue)
                .padding(.top, 24)

            Text("Choose how to import your\nv2ray configuration")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Tips View

    private var tipsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            TipRow(icon: "1.circle.fill", text: "Copy the config URI from your provider")
            TipRow(icon: "2.circle.fill", text: "Tap \"Paste from Clipboard\" to import")
            TipRow(icon: "3.circle.fill", text: "Or scan a QR code shared by your provider")
            TipRow(icon: "4.circle.fill", text: "Select the imported config and tap Connect")
        }
        .padding(.vertical, 4)
    }

    // MARK: - Import Methods

    private func importFromClipboard() {
        guard let clipboardString = UIPasteboard.general.string else {
            showError("Clipboard is empty. Copy a v2ray URI first.")
            return
        }
        let trimmed = clipboardString.trimmingCharacters(in: .whitespacesAndNewlines)

        // Filter out JSON (handled by importJSONFromClipboard)
        if trimmed.hasPrefix("{") {
            showError("This looks like a JSON config. Use \"Paste JSON Config\" instead.")
            return
        }

        processScannedString(trimmed)
    }

    private func importJSONFromClipboard() {
        guard let clipboardString = UIPasteboard.general.string else {
            showError("Clipboard is empty. Copy a v2ray JSON configuration first.")
            return
        }
        let trimmed = clipboardString.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmed.hasPrefix("{") else {
            showError("Clipboard does not contain a JSON object. Expected { ... }")
            return
        }

        do {
            let config = try ConfigParser.parseRawJSON(trimmed)
            saveConfig(config)
        } catch {
            showError("Failed to parse JSON config: \(error.localizedDescription)")
        }
    }

    private func processGalleryImage(_ item: PhotosPickerItem) {
        item.loadTransferable(type: Data.self) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let data):
                    guard let data = data, let image = UIImage(data: data) else {
                        self.showError("Could not load the selected image.")
                        return
                    }
                    self.decodeQRFromImage(image)
                case .failure(let error):
                    self.showError("Failed to load image: \(error.localizedDescription)")
                }
            }
        }
    }

    private func decodeQRFromImage(_ image: UIImage) {
        guard let ciImage = CIImage(image: image) else {
            showError("Could not process the selected image.")
            return
        }

        let context = CIContext()
        let detector = CIDetector(
            ofType: CIDetectorTypeQRCode,
            context: context,
            options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]
        )

        guard let features = detector?.features(in: ciImage) else {
            showError("No QR code found in the selected image.")
            return
        }

        let qrFeatures = features.compactMap { $0 as? CIQRCodeFeature }
        guard let firstQR = qrFeatures.first, let messageString = firstQR.messageString else {
            showError("No QR code found in the selected image.")
            return
        }

        processScannedString(messageString)
    }

    private func processScannedString(_ string: String) {
        do {
            let config = try ConfigParser.parse(string)
            saveConfig(config)
        } catch {
            showError(error.localizedDescription)
        }
    }

    private func saveConfig(_ config: V2RayConfig) {
        storageService.addConfig(config)
        importedConfig = config
        showingImportSuccess = true
    }

    private func showError(_ message: String) {
        errorMessage = message
        showingError = true
    }
}

// MARK: - Import Option Row

struct ImportOptionRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    var showChevron: Bool = false
    var action: (() -> Void)? = nil

    var body: some View {
        Button {
            action?()
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(iconColor)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Tip Row

struct TipRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .font(.body)
                .frame(width: 20)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    AddConfigView()
        .environmentObject(StorageService.shared)
}
