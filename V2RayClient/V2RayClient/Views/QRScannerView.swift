import SwiftUI
import AVFoundation
import AudioToolbox

// MARK: - QR Scanner View (SwiftUI wrapper)

struct QRScannerView: View {
    let onScan: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var cameraPermission: AVAuthorizationStatus = .notDetermined
    @State private var torchOn = false
    @State private var showingPermissionAlert = false
    @State private var overlayOpacity = 0.0

    var body: some View {
        ZStack {
            switch cameraPermission {
            case .authorized:
                cameraPreview
            case .denied, .restricted:
                permissionDeniedView
            default:
                Color.black.ignoresSafeArea()
                    .onAppear { requestCameraPermission() }
            }
        }
        .onAppear {
            cameraPermission = AVCaptureDevice.authorizationStatus(for: .video)
            if cameraPermission == .authorized {
                withAnimation(.easeIn(duration: 0.3)) {
                    overlayOpacity = 1.0
                }
            } else if cameraPermission == .notDetermined {
                requestCameraPermission()
            }
        }
        .alert("Camera Access Required", isPresented: $showingPermissionAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) { dismiss() }
        } message: {
            Text("V2Ray Client needs camera access to scan QR codes. Please enable it in Settings.")
        }
    }

    // MARK: - Camera Preview

    private var cameraPreview: some View {
        ZStack {
            // Camera feed
            QRCameraPreview(onScan: { scanned in
                onScan(scanned)
            })
            .ignoresSafeArea()
            .opacity(overlayOpacity)

            // Scanner overlay
            VStack {
                // Top bar
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white)
                            .shadow(radius: 4)
                    }
                    .padding()

                    Spacer()

                    Button {
                        torchOn.toggle()
                        toggleTorch(on: torchOn)
                    } label: {
                        Image(systemName: torchOn ? "bolt.fill" : "bolt.slash.fill")
                            .font(.system(size: 24))
                            .foregroundColor(torchOn ? .yellow : .white)
                            .shadow(radius: 4)
                    }
                    .padding()
                }

                Spacer()

                // Scanning frame
                ZStack {
                    // Dimmed background
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()
                        .reverseMask {
                            RoundedRectangle(cornerRadius: 16)
                                .frame(width: 260, height: 260)
                        }

                    // Corner brackets
                    ScannerFrame()
                        .frame(width: 260, height: 260)
                }
                .frame(height: 300)

                Spacer()

                // Bottom hint
                VStack(spacing: 8) {
                    Text("Align QR code within the frame")
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .shadow(radius: 2)
                    Text("Auto-detection enabled")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.bottom, 60)
            }
        }
    }

    // MARK: - Permission Denied View

    private var permissionDeniedView: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "camera.fill.badge.ellipsis")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("Camera Access Denied")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Please enable camera access in\nSettings to scan QR codes.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)

            Button("Cancel") { dismiss() }
                .foregroundColor(.secondary)

            Spacer()
        }
        .padding()
    }

    // MARK: - Helpers

    private func requestCameraPermission() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                cameraPermission = granted ? .authorized : .denied
                if !granted {
                    showingPermissionAlert = true
                } else {
                    withAnimation(.easeIn(duration: 0.3)) {
                        overlayOpacity = 1.0
                    }
                }
            }
        }
    }

    private func toggleTorch(on: Bool) {
        guard let device = AVCaptureDevice.default(for: .video),
              device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            device.torchMode = on ? .on : .off
            device.unlockForConfiguration()
        } catch {
            // Torch is optional; silently revert the toggle state if unavailable
            DispatchQueue.main.async { self.torchOn = false }
        }
    }
}

// MARK: - Scanner Frame (corner brackets)

struct ScannerFrame: View {
    let lineLength: CGFloat = 24
    let lineWidth: CGFloat = 4
    let color: Color = .white

    var body: some View {
        ZStack {
            // Animated scan line
            ScanLine()

            // Corner brackets
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                Path { path in
                    // Top-left
                    path.move(to: CGPoint(x: 0, y: lineLength))
                    path.addLine(to: CGPoint(x: 0, y: 0))
                    path.addLine(to: CGPoint(x: lineLength, y: 0))

                    // Top-right
                    path.move(to: CGPoint(x: w - lineLength, y: 0))
                    path.addLine(to: CGPoint(x: w, y: 0))
                    path.addLine(to: CGPoint(x: w, y: lineLength))

                    // Bottom-left
                    path.move(to: CGPoint(x: 0, y: h - lineLength))
                    path.addLine(to: CGPoint(x: 0, y: h))
                    path.addLine(to: CGPoint(x: lineLength, y: h))

                    // Bottom-right
                    path.move(to: CGPoint(x: w - lineLength, y: h))
                    path.addLine(to: CGPoint(x: w, y: h))
                    path.addLine(to: CGPoint(x: w, y: h - lineLength))
                }
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            }
        }
    }
}

// MARK: - Animated Scan Line

struct ScanLine: View {
    @State private var offset: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, .green.opacity(0.8), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 2)
                .offset(y: offset)
                .onAppear {
                    withAnimation(
                        .linear(duration: 1.8)
                        .repeatForever(autoreverses: true)
                    ) {
                        offset = geo.size.height - 2
                    }
                }
        }
    }
}

// MARK: - Reverse Mask Extension

extension View {
    @ViewBuilder
    func reverseMask<Mask: View>(alignment: Alignment = .center, @ViewBuilder _ mask: () -> Mask) -> some View {
        self.mask {
            Rectangle()
                .overlay(alignment: alignment) {
                    mask()
                        .blendMode(.destinationOut)
                }
        }
    }
}

// MARK: - AVFoundation Camera Preview (UIViewRepresentable)

struct QRCameraPreview: UIViewRepresentable {
    let onScan: (String) -> Void

    func makeUIView(context: Context) -> QRCameraUIView {
        let view = QRCameraUIView()
        view.onScan = onScan
        return view
    }

    func updateUIView(_ uiView: QRCameraUIView, context: Context) {}
}

// MARK: - Camera UIView

final class QRCameraUIView: UIView, AVCaptureMetadataOutputObjectsDelegate {
    var onScan: ((String) -> Void)?

    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var hasScanned = false

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
        if captureSession == nil {
            setupCamera()
        }
    }

    private func setupCamera() {
        let session = AVCaptureSession()

        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else { return }

        session.addInput(input)

        let metadataOutput = AVCaptureMetadataOutput()
        session.addOutput(metadataOutput)
        metadataOutput.setMetadataObjectsDelegate(self, queue: .main)
        metadataOutput.metadataObjectTypes = [.qr]

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = bounds
        layer.insertSublayer(preview, at: 0)

        previewLayer = preview
        captureSession = session

        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard !hasScanned else { return }
        guard let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              object.type == .qr,
              let stringValue = object.stringValue,
              !stringValue.isEmpty else { return }

        hasScanned = true
        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
        onScan?(stringValue)

        // Stop session after scan
        DispatchQueue.global(qos: .userInitiated).async {
            self.captureSession?.stopRunning()
        }
    }

    override func removeFromSuperview() {
        super.removeFromSuperview()
        DispatchQueue.global(qos: .userInitiated).async {
            self.captureSession?.stopRunning()
        }
    }
}
