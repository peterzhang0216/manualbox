import SwiftUI
import Foundation
import UniformTypeIdentifiers

// MARK: - 设置导入导出服务

@MainActor
class SettingsImportExportService: ObservableObject {
    static let shared = SettingsImportExportService()
    
    @Published var isExporting = false
    @Published var isImporting = false
    @Published var exportProgress: Double = 0.0
    @Published var importProgress: Double = 0.0
    @Published var lastError: String?
    
    private let settingsManager = SettingsManager.shared
    
    private init() {}
    
    // MARK: - 导出功能
    
    /// 导出所有设置
    func exportAllSettings() async -> URL? {
        isExporting = true
        exportProgress = 0.0
        lastError = nil
        
        do {
            // 创建导出数据
            let exportData = SettingsExportData(
                version: "1.0",
                exportDate: Date(),
                appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
                notificationSettings: settingsManager.notificationSettings,
                appearanceSettings: settingsManager.appearanceSettings,
                appSettings: settingsManager.appSettings,
                dataSettings: settingsManager.dataSettings
            )
            
            exportProgress = 0.3
            
            // 编码为JSON
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            
            let jsonData = try encoder.encode(exportData)
            
            exportProgress = 0.6
            
            // 创建临时文件
            let tempDirectory = FileManager.default.temporaryDirectory
            let fileName = "ManualBox_Settings_\(dateFormatter.string(from: Date())).json"
            let fileURL = tempDirectory.appendingPathComponent(fileName)
            
            try jsonData.write(to: fileURL)
            
            exportProgress = 1.0
            isExporting = false
            
            return fileURL
            
        } catch {
            lastError = "导出失败: \(error.localizedDescription)"
            isExporting = false
            exportProgress = 0.0
            return nil
        }
    }
    
    /// 导出特定设置分类
    func exportSettings(categories: Set<SettingsCategory>) async -> URL? {
        isExporting = true
        exportProgress = 0.0
        lastError = nil
        
        do {
            var exportData = SettingsExportData(
                version: "1.0",
                exportDate: Date(),
                appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
            )
            
            // 根据选择的分类添加数据
            if categories.contains(.notification) {
                exportData.notificationSettings = settingsManager.notificationSettings
            }
            if categories.contains(.appearance) {
                exportData.appearanceSettings = settingsManager.appearanceSettings
            }
            if categories.contains(.app) {
                exportData.appSettings = settingsManager.appSettings
            }
            if categories.contains(.data) {
                exportData.dataSettings = settingsManager.dataSettings
            }
            
            exportProgress = 0.5
            
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            
            let jsonData = try encoder.encode(exportData)
            
            let tempDirectory = FileManager.default.temporaryDirectory
            let fileName = "ManualBox_Settings_Partial_\(dateFormatter.string(from: Date())).json"
            let fileURL = tempDirectory.appendingPathComponent(fileName)
            
            try jsonData.write(to: fileURL)
            
            exportProgress = 1.0
            isExporting = false
            
            return fileURL
            
        } catch {
            lastError = "导出失败: \(error.localizedDescription)"
            isExporting = false
            exportProgress = 0.0
            return nil
        }
    }
    
    // MARK: - 导入功能
    
    /// 导入设置
    func importSettings(from url: URL) async -> Bool {
        isImporting = true
        importProgress = 0.0
        lastError = nil
        
        do {
            // 读取文件
            let jsonData = try Data(contentsOf: url)
            importProgress = 0.2
            
            // 解码数据
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let importData = try decoder.decode(SettingsExportData.self, from: jsonData)
            importProgress = 0.4
            
            // 验证版本兼容性
            guard isVersionCompatible(importData.version) else {
                lastError = "不兼容的设置文件版本: \(importData.version)"
                isImporting = false
                importProgress = 0.0
                return false
            }
            
            importProgress = 0.6
            
            // 应用设置
            if let notificationSettings = importData.notificationSettings {
                settingsManager.notificationSettings = notificationSettings
            }
            
            if let appearanceSettings = importData.appearanceSettings {
                settingsManager.appearanceSettings = appearanceSettings
            }
            
            if let appSettings = importData.appSettings {
                settingsManager.appSettings = appSettings
            }
            
            if let dataSettings = importData.dataSettings {
                settingsManager.dataSettings = dataSettings
            }
            
            importProgress = 0.8
            
            // 保存设置
            settingsManager.saveSettings()
            
            importProgress = 1.0
            isImporting = false
            
            return true
            
        } catch {
            lastError = "导入失败: \(error.localizedDescription)"
            isImporting = false
            importProgress = 0.0
            return false
        }
    }
    
    /// 预览导入设置
    func previewImportSettings(from url: URL) async -> SettingsImportPreview? {
        do {
            let jsonData = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let importData = try decoder.decode(SettingsExportData.self, from: jsonData)
            
            return SettingsImportPreview(
                version: importData.version,
                exportDate: importData.exportDate,
                appVersion: importData.appVersion,
                hasNotificationSettings: importData.notificationSettings != nil,
                hasAppearanceSettings: importData.appearanceSettings != nil,
                hasAppSettings: importData.appSettings != nil,
                hasDataSettings: importData.dataSettings != nil,
                isCompatible: isVersionCompatible(importData.version)
            )
            
        } catch {
            lastError = "无法读取设置文件: \(error.localizedDescription)"
            return nil
        }
    }
    
    // MARK: - 私有方法
    
    private func isVersionCompatible(_ version: String) -> Bool {
        // 简单的版本兼容性检查
        let supportedVersions = ["1.0"]
        return supportedVersions.contains(version)
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter
    }
}

// MARK: - 数据模型

struct SettingsExportData: Codable {
    let version: String
    let exportDate: Date
    let appVersion: String
    var notificationSettings: NotificationSettings?
    var appearanceSettings: AppearanceSettings?
    var appSettings: AppSettings?
    var dataSettings: DataManagementSettings?
}

struct SettingsImportPreview {
    let version: String
    let exportDate: Date
    let appVersion: String
    let hasNotificationSettings: Bool
    let hasAppearanceSettings: Bool
    let hasAppSettings: Bool
    let hasDataSettings: Bool
    let isCompatible: Bool
}

enum SettingsCategory: String, CaseIterable {
    case notification = "notification"
    case appearance = "appearance"
    case app = "app"
    case data = "data"
    
    var title: String {
        switch self {
        case .notification: return "通知设置"
        case .appearance: return "外观设置"
        case .app: return "应用设置"
        case .data: return "数据设置"
        }
    }
    
    var icon: String {
        switch self {
        case .notification: return "bell.fill"
        case .appearance: return "paintbrush.fill"
        case .app: return "gear"
        case .data: return "externaldrive.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .notification: return .orange
        case .appearance: return .purple
        case .app: return .blue
        case .data: return .green
        }
    }
}

// MARK: - 文档类型定义

struct SettingsDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    
    var settings: SettingsExportData
    
    init(settings: SettingsExportData) {
        self.settings = settings
    }
    
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        self.settings = try decoder.decode(SettingsExportData.self, from: data)
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        let data = try encoder.encode(settings)
        return FileWrapper(regularFileWithContents: data)
    }
}
