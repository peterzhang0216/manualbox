import SwiftUI
import Foundation
import Combine

// MARK: - 设置数据模型

/// 通知设置
struct NotificationSettings: Codable {
    var enableNotifications: Bool = true
    var enableWarrantyReminders: Bool = true
    var reminderDays: Int = 7
    var defaultReminderTime: Date = Calendar.current.date(from: DateComponents(hour: 9, minute: 0)) ?? Date()
    var enableSilentPeriod: Bool = false
    var silentStartTime: Double = 22 * 3600 // 22:00
    var silentEndTime: Double = 8 * 3600 // 08:00
}

/// 外观设置
struct AppearanceSettings: Codable {
    var themeMode: String = "system" // "light", "dark", "system"
    var accentColor: String = "blue"
    var enableReducedMotion: Bool = false
    var enableHighContrast: Bool = false
    var language: String = "auto" // "auto", "zh-Hans", "en"
}

/// 应用设置
struct AppSettings: Codable {
    var defaultWarrantyPeriod: Int = 12 // 月
    var enableOCRByDefault: Bool = true
    var autoSaveInterval: Int = 30 // 秒
    var enableAdvancedFeatures: Bool = false
    var maxImageSize: Int = 10 // MB
}

/// 数据管理设置
struct DataManagementSettings: Codable {
    var enableAutoBackup: Bool = false
    var backupFrequency: String = "weekly" // "daily", "weekly", "monthly"
    var maxBackupCount: Int = 5
    var enableCloudSync: Bool = false
    var lastBackupDate: Date?
}

// MARK: - 统一设置管理器

@MainActor
class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    // MARK: - Published Properties
    @Published var notificationSettings = NotificationSettings()
    @Published var appearanceSettings = AppearanceSettings()
    @Published var appSettings = AppSettings()
    @Published var dataSettings = DataManagementSettings()
    
    // MARK: - Private Properties
    private let userDefaults = UserDefaults.standard
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Keys
    private enum Keys {
        static let notificationSettings = "notification_settings"
        static let appearanceSettings = "appearance_settings"
        static let appSettings = "app_settings"
        static let dataSettings = "data_settings"
    }
    
    // MARK: - Initialization
    private init() {
        loadSettings()
        setupObservers()
    }
    
    // MARK: - Public Methods
    
    /// 加载所有设置
    func loadSettings() {
        notificationSettings = loadSetting(for: Keys.notificationSettings, defaultValue: NotificationSettings())
        appearanceSettings = loadSetting(for: Keys.appearanceSettings, defaultValue: AppearanceSettings())
        appSettings = loadSetting(for: Keys.appSettings, defaultValue: AppSettings())
        dataSettings = loadSetting(for: Keys.dataSettings, defaultValue: DataManagementSettings())
    }
    
    /// 保存所有设置
    func saveSettings() {
        saveSetting(notificationSettings, for: Keys.notificationSettings)
        saveSetting(appearanceSettings, for: Keys.appearanceSettings)
        saveSetting(appSettings, for: Keys.appSettings)
        saveSetting(dataSettings, for: Keys.dataSettings)
    }
    
    /// 重置所有设置
    func resetAllSettings() {
        notificationSettings = NotificationSettings()
        appearanceSettings = AppearanceSettings()
        appSettings = AppSettings()
        dataSettings = DataManagementSettings()
        saveSettings()
    }
    
    /// 导出设置
    func exportSettings() -> Data? {
        struct ExportableSettings: Codable {
            let notification: NotificationSettings
            let appearance: AppearanceSettings
            let app: AppSettings
            let data: DataManagementSettings
        }

        let allSettings = ExportableSettings(
            notification: notificationSettings,
            appearance: appearanceSettings,
            app: appSettings,
            data: dataSettings
        )

        return try? JSONEncoder().encode(allSettings)
    }
    
    /// 导入设置
    func importSettings(from data: Data) throws {
        // TODO: 实现设置导入逻辑
        // 需要验证数据格式和版本兼容性
    }
    
    // MARK: - Private Methods
    
    private func loadSetting<T: Codable>(for key: String, defaultValue: T) -> T {
        guard let data = userDefaults.data(forKey: key),
              let setting = try? JSONDecoder().decode(T.self, from: data) else {
            return defaultValue
        }
        return setting
    }
    
    private func saveSetting<T: Codable>(_ setting: T, for key: String) {
        if let data = try? JSONEncoder().encode(setting) {
            userDefaults.set(data, forKey: key)
        }
    }
    
    private func setupObservers() {
        // 监听设置变化并自动保存
        $notificationSettings
            .dropFirst()
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.saveSetting(self?.notificationSettings, for: Keys.notificationSettings)
            }
            .store(in: &cancellables)
        
        $appearanceSettings
            .dropFirst()
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.saveSetting(self?.appearanceSettings, for: Keys.appearanceSettings)
            }
            .store(in: &cancellables)
        
        $appSettings
            .dropFirst()
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.saveSetting(self?.appSettings, for: Keys.appSettings)
            }
            .store(in: &cancellables)
        
        $dataSettings
            .dropFirst()
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.saveSetting(self?.dataSettings, for: Keys.dataSettings)
            }
            .store(in: &cancellables)
    }
}

// MARK: - 便利扩展

extension SettingsManager {
    /// 获取当前主题模式
    var currentThemeMode: ColorScheme? {
        switch appearanceSettings.themeMode {
        case "light": return .light
        case "dark": return .dark
        default: return nil // 跟随系统
        }
    }
    
    /// 获取当前强调色
    var currentAccentColor: Color {
        switch appearanceSettings.accentColor {
        case "blue": return .blue
        case "green": return .green
        case "orange": return .orange
        case "purple": return .purple
        case "red": return .red
        case "pink": return .pink
        case "yellow": return .yellow
        case "indigo": return .indigo
        case "teal": return .teal
        case "cyan": return .cyan
        default: return .accentColor
        }
    }
    
    /// 检查是否需要显示通知权限请求
    var shouldRequestNotificationPermission: Bool {
        return notificationSettings.enableNotifications
    }
}
