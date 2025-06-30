//
//  ThreeColumnSettingsViewContent.swift
//  ManualBox
//
//  Created by Assistant on 2024/12/19.
//

import SwiftUI
import Foundation

// MARK: - 子面板内容视图扩展
extension ThreeColumnSettingsView {
    
    // MARK: - 子面板内容
    @ViewBuilder
    func subPanelContent(for subPanel: SettingsSubPanel) -> some View {
        switch subPanel {
        // 通知相关
        case .notificationPermissions:
            NotificationPermissionsContent()
                .environmentObject(SettingsManager.shared)
        case .reminderSettings:
            ReminderSettingsContent()
                .environmentObject(SettingsManager.shared)
        case .silentPeriod:
            SilentPeriodContent()
                .environmentObject(SettingsManager.shared)

        // 外观相关
        case .themeMode:
            ThemeModeContent()
                .environmentObject(SettingsManager.shared)
        case .themeColors:
            ThemeColorsContent()
                .environmentObject(SettingsManager.shared)
        case .displayOptions:
            DisplayOptionsContent()
                .environmentObject(SettingsManager.shared)
        case .languageSettings:
            LanguageSettingsContent()
                .environmentObject(SettingsManager.shared)

        // 应用设置相关
        case .defaultParameters:
            DefaultParametersContent()
                .environmentObject(SettingsManager.shared)
        case .ocrSettings:
            OCRSettingsContent()
                .environmentObject(SettingsManager.shared)
        case .advancedOptions:
            AdvancedOptionsContent()
                .environmentObject(SettingsManager.shared)

        // 数据管理相关
        case .syncStatus:
            SyncDashboardView()
        case .backupRestore:
            BackupRestoreContent()
                .environmentObject(SettingsManager.shared)
        case .importExport:
            ImportExportContent()
                .environmentObject(SettingsManager.shared)
        case .dataCleanup:
            DataCleanupContent()
                .environmentObject(SettingsManager.shared)

        // 关于相关
        case .appInfo:
            AppInfoContent()
                .environmentObject(SettingsManager.shared)
        case .helpSupport:
            HelpSupportContent()
                .environmentObject(SettingsManager.shared)
        case .legalTerms:
            LegalTermsContent()
                .environmentObject(SettingsManager.shared)
        }
    }
}

// MARK: - 占位符内容视图（用于尚未实现的内容）
struct NotificationPermissionsContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("通知权限设置")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("在这里配置应用的通知权限和相关设置。")
                .foregroundColor(.secondary)
            
            // 这里可以添加具体的通知权限设置内容
        }
        .padding()
    }
}

struct ReminderSettingsContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("提醒设置")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("配置保修到期提醒和其他重要提醒。")
                .foregroundColor(.secondary)
            
            // 这里可以添加具体的提醒设置内容
        }
        .padding()
    }
}

struct SilentPeriodContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("免打扰设置")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("设置免打扰时段，在此期间不会收到通知。")
                .foregroundColor(.secondary)
            
            // 这里可以添加具体的免打扰设置内容
        }
        .padding()
    }
}

struct ThemeModeContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("主题模式")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("选择应用的主题模式：浅色、深色或跟随系统。")
                .foregroundColor(.secondary)
            
            // 这里可以添加具体的主题模式设置内容
        }
        .padding()
    }
}

struct ThemeColorsContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("主题色彩")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("自定义应用的主题色彩和强调色。")
                .foregroundColor(.secondary)
            
            // 这里可以添加具体的主题色彩设置内容
        }
        .padding()
    }
}

struct DisplayOptionsContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("显示选项")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("配置界面显示选项和布局设置。")
                .foregroundColor(.secondary)
            
            // 这里可以添加具体的显示选项设置内容
        }
        .padding()
    }
}

struct LanguageSettingsContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("语言设置")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("选择应用的显示语言。")
                .foregroundColor(.secondary)
            
            // 这里可以添加具体的语言设置内容
        }
        .padding()
    }
}

struct DefaultParametersContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("默认参数")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("设置新产品的默认参数，如保修期等。")
                .foregroundColor(.secondary)
            
            // 这里可以添加具体的默认参数设置内容
        }
        .padding()
    }
}

struct OCRSettingsContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("OCR设置")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("配置光学字符识别功能的相关设置。")
                .foregroundColor(.secondary)
            
            // 这里可以添加具体的OCR设置内容
        }
        .padding()
    }
}

struct AdvancedOptionsContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("高级选项")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("配置高级功能和开发者选项。")
                .foregroundColor(.secondary)
            
            // 这里可以添加具体的高级选项设置内容
        }
        .padding()
    }
}

struct BackupRestoreContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("备份恢复")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("管理数据备份和恢复操作。")
                .foregroundColor(.secondary)
            
            // 这里可以添加具体的备份恢复内容
        }
        .padding()
    }
}

struct ImportExportContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("导入导出")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("导入或导出产品数据。")
                .foregroundColor(.secondary)
            
            // 这里可以添加具体的导入导出内容
        }
        .padding()
    }
}

struct DataCleanupContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("数据清理")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("清理无用数据和缓存文件。")
                .foregroundColor(.secondary)
            
            // 这里可以添加具体的数据清理内容
        }
        .padding()
    }
}

struct AppInfoContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("应用信息")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("查看应用版本、构建信息等。")
                .foregroundColor(.secondary)
            
            // 这里可以添加具体的应用信息内容
        }
        .padding()
    }
}

struct HelpSupportContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("帮助支持")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("获取使用帮助和技术支持。")
                .foregroundColor(.secondary)
            
            // 这里可以添加具体的帮助支持内容
        }
        .padding()
    }
}

struct LegalTermsContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("法律条款")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("查看隐私政策、使用条款等法律文档。")
                .foregroundColor(.secondary)
            
            // 这里可以添加具体的法律条款内容
        }
        .padding()
    }
}