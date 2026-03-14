import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var storageService: StorageService
    @State private var settings: AppSettings = .default
    @State private var showingProxyPassword = false
    @State private var showingResetAlert = false

    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Upstream Proxy Section
                Section {
                    Toggle("Enable Upstream Proxy", isOn: $settings.upstreamProxyEnabled)
                        .tint(.blue)

                    if settings.upstreamProxyEnabled {
                        Picker("Proxy Type", selection: $settings.upstreamProxyType) {
                            ForEach(UpstreamProxyType.allCases, id: \.self) { type in
                                Text(type.displayName).tag(type)
                            }
                        }

                        HStack {
                            Text("Host")
                            Spacer()
                            TextField("e.g. 127.0.0.1", text: $settings.upstreamProxyHost)
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.URL)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                        }

                        HStack {
                            Text("Port")
                            Spacer()
                            TextField("1080", value: $settings.upstreamProxyPort, format: .number)
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.numberPad)
                                .frame(width: 80)
                        }

                        HStack {
                            Text("Username")
                            Spacer()
                            TextField("Optional", text: $settings.upstreamProxyUsername)
                                .multilineTextAlignment(.trailing)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                        }

                        HStack {
                            Text("Password")
                            Spacer()
                            if showingProxyPassword {
                                TextField("Optional", text: $settings.upstreamProxyPassword)
                                    .multilineTextAlignment(.trailing)
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                            } else {
                                SecureField("Optional", text: $settings.upstreamProxyPassword)
                                    .multilineTextAlignment(.trailing)
                            }
                            Button {
                                showingProxyPassword.toggle()
                            } label: {
                                Image(systemName: showingProxyPassword ? "eye.slash" : "eye")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } header: {
                    Label("Upstream Proxy", systemImage: "arrow.triangle.branch")
                } footer: {
                    Text("Route v2ray traffic through an upstream proxy server before reaching the destination.")
                }

                // MARK: - DNS Section
                Section {
                    Toggle("Custom DNS", isOn: $settings.customDNSEnabled)
                        .tint(.blue)

                    if settings.customDNSEnabled {
                        HStack {
                            Text("Primary DNS")
                            Spacer()
                            TextField("8.8.8.8", text: $settings.primaryDNS)
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.numbersAndPunctuation)
                                .autocapitalization(.none)
                        }

                        HStack {
                            Text("Secondary DNS")
                            Spacer()
                            TextField("8.8.4.4", text: $settings.secondaryDNS)
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.numbersAndPunctuation)
                                .autocapitalization(.none)
                        }
                    }
                } header: {
                    Label("DNS", systemImage: "network")
                }

                // MARK: - Routing Section
                Section {
                    Toggle("Bypass LAN", isOn: $settings.bypassLAN)
                        .tint(.blue)
                    Toggle("Bypass China Mainland", isOn: $settings.bypassChinaMainland)
                        .tint(.blue)
                    Toggle("Enable Traffic Sniffing", isOn: $settings.enableSniffing)
                        .tint(.blue)
                } header: {
                    Label("Routing", systemImage: "arrow.triangle.swap")
                } footer: {
                    Text("Bypass LAN skips local addresses. Bypass China Mainland uses direct routing for CN domains.")
                }

                // MARK: - Local Inbound Section
                Section {
                    HStack {
                        Text("SOCKS Port")
                        Spacer()
                        TextField("1080", value: $settings.localSocksPort, format: .number)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numberPad)
                            .frame(width: 80)
                    }

                    HStack {
                        Text("HTTP Port")
                        Spacer()
                        TextField("8080", value: $settings.localHttpPort, format: .number)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numberPad)
                            .frame(width: 80)
                    }

                    Toggle("Allow LAN Connections", isOn: $settings.allowLANConnections)
                        .tint(.blue)
                } header: {
                    Label("Local Inbound", systemImage: "point.bottomleft.forward.to.point.topright.scurvepath.fill")
                } footer: {
                    Text("Local SOCKS5 and HTTP proxy ports exposed by the v2ray client.")
                }

                // MARK: - Connection Section
                Section {
                    Toggle("Auto Connect on Launch", isOn: $settings.autoConnect)
                        .tint(.blue)
                } header: {
                    Label("Connection", systemImage: "bolt.fill")
                }

                // MARK: - About Section
                Section {
                    LabeledContent("Version", value: appVersion)
                    LabeledContent("Build", value: buildNumber)
                    Link(destination: URL(string: "https://github.com/v2ray/v2ray-core")!) {
                        Label("v2ray-core on GitHub", systemImage: "link")
                    }
                } header: {
                    Label("About", systemImage: "info.circle")
                }

                // MARK: - Reset
                Section {
                    Button(role: .destructive) {
                        showingResetAlert = true
                    } label: {
                        Label("Reset All Settings", systemImage: "arrow.counterclockwise")
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        storageService.updateSettings(settings)
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                settings = storageService.settings
            }
            .onChange(of: settings.upstreamProxyEnabled) { _, _ in autoSave() }
            .onChange(of: settings.upstreamProxyType) { _, _ in autoSave() }
            .onChange(of: settings.customDNSEnabled) { _, _ in autoSave() }
            .onChange(of: settings.bypassLAN) { _, _ in autoSave() }
            .onChange(of: settings.bypassChinaMainland) { _, _ in autoSave() }
            .onChange(of: settings.enableSniffing) { _, _ in autoSave() }
            .onChange(of: settings.allowLANConnections) { _, _ in autoSave() }
            .onChange(of: settings.autoConnect) { _, _ in autoSave() }
            .alert("Reset Settings", isPresented: $showingResetAlert) {
                Button("Reset", role: .destructive) {
                    settings = .default
                    storageService.updateSettings(.default)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will reset all settings to their default values.")
            }
        }
    }

    private func autoSave() {
        storageService.updateSettings(settings)
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}

#Preview {
    SettingsView()
        .environmentObject(StorageService.shared)
}
