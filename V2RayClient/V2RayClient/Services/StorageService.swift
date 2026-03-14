import Foundation
import Combine

// MARK: - Storage Service

final class StorageService: ObservableObject {
    static let shared = StorageService()

    private let configsKey = "v2ray_configs"
    private let settingsKey = "v2ray_settings"
    private let defaults = UserDefaults.standard

    @Published var configs: [V2RayConfig] = []
    @Published var settings: AppSettings = .default

    private init() {
        loadConfigs()
        loadSettings()
    }

    // MARK: - Configs

    func loadConfigs() {
        guard let data = defaults.data(forKey: configsKey),
              let decoded = try? JSONDecoder().decode([V2RayConfig].self, from: data) else {
            configs = []
            return
        }
        configs = decoded
    }

    func saveConfigs() {
        guard let data = try? JSONEncoder().encode(configs) else { return }
        defaults.set(data, forKey: configsKey)
    }

    func addConfig(_ config: V2RayConfig) {
        configs.append(config)
        saveConfigs()
    }

    func removeConfig(at offsets: IndexSet) {
        configs.remove(atOffsets: offsets)
        saveConfigs()
    }

    func removeConfig(id: UUID) {
        configs.removeAll { $0.id == id }
        saveConfigs()
    }

    func updateConfig(_ config: V2RayConfig) {
        if let index = configs.firstIndex(where: { $0.id == config.id }) {
            configs[index] = config
            saveConfigs()
        }
    }

    func setActiveConfig(_ config: V2RayConfig?) {
        for index in configs.indices {
            configs[index].isActive = configs[index].id == config?.id
        }
        settings.selectedConfigID = config?.id
        saveConfigs()
        saveSettings()
    }

    var activeConfig: V2RayConfig? {
        configs.first { $0.isActive }
    }

    // MARK: - Settings

    func loadSettings() {
        guard let data = defaults.data(forKey: settingsKey),
              let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            settings = .default
            return
        }
        settings = decoded
    }

    func saveSettings() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: settingsKey)
    }

    func updateSettings(_ newSettings: AppSettings) {
        settings = newSettings
        saveSettings()
    }
}
