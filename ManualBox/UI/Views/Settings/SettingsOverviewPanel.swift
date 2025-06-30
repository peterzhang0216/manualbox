import SwiftUI

// MARK: - 设置概览面板

struct SettingsOverviewPanel: View {
    @EnvironmentObject private var settingsManager: SettingsManager
    let panel: SettingsPanel
    
    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 24) {
                // 面板标题
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: panel.icon)
                            .font(.title2)
                            .foregroundColor(panel.color)
                        
                        Text(panel.title)
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                    
                    Text(panel.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // 面板概览内容
                overviewContent(for: panel)
                
                Spacer()
            }
            .padding(24)
        }
        .background(Color.adaptiveSecondaryBackground)
    }
    
    @ViewBuilder
    private func overviewContent(for panel: SettingsPanel) -> some View {
        switch panel {
        case .notification:
            notificationOverview
        case .appearance:
            appearanceOverview
        case .appSettings:
            appSettingsOverview
        case .dataManagement:
            dataManagementOverview
        case .about:
            aboutOverview
        }
    }
    
    // MARK: - 各面板概览内容
    
    private var notificationOverview: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsOverviewCard(
                icon: "bell.fill",
                iconColor: .orange,
                title: "通知状态",
                value: settingsManager.notificationSettings.enableNotifications ? "已启用" : "已禁用"
            )

            SettingsOverviewCard(
                icon: "calendar.badge.clock",
                iconColor: .blue,
                title: "保修提醒",
                value: settingsManager.notificationSettings.enableWarrantyReminders ? "已启用" : "已禁用"
            )

            SettingsOverviewCard(
                icon: "clock.fill",
                iconColor: .green,
                title: "提醒时间",
                value: timeFormatter.string(from: settingsManager.notificationSettings.defaultReminderTime)
            )

            if settingsManager.notificationSettings.enableSilentPeriod {
                SettingsOverviewCard(
                    icon: "moon.fill",
                    iconColor: .purple,
                    title: "免打扰",
                    value: "已启用"
                )
            }
        }
    }
    
    private var appearanceOverview: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsOverviewCard(
                icon: "circle.lefthalf.filled",
                iconColor: .blue,
                title: "主题模式",
                value: themeDisplayName
            )
            
            SettingsOverviewCard(
                icon: "paintpalette.fill",
                iconColor: settingsManager.currentAccentColor,
                title: "主题色彩",
                value: accentColorDisplayName
            )

            SettingsOverviewCard(
                icon: "globe",
                iconColor: .green,
                title: "显示语言",
                value: languageDisplayName
            )

            if settingsManager.appearanceSettings.enableReducedMotion {
                SettingsOverviewCard(
                    icon: "speedometer",
                    iconColor: .orange,
                    title: "减少动画",
                    value: "已启用"
                )
            }
        }
    }
    
    private var appSettingsOverview: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsOverviewCard(
                icon: "calendar",
                iconColor: .blue,
                title: "默认保修期",
                value: "\(settingsManager.appSettings.defaultWarrantyPeriod) 个月"
            )

            SettingsOverviewCard(
                icon: "doc.text.viewfinder",
                iconColor: .purple,
                title: "OCR识别",
                value: settingsManager.appSettings.enableOCRByDefault ? "默认启用" : "默认禁用"
            )

            SettingsOverviewCard(
                icon: "clock.arrow.circlepath",
                iconColor: .green,
                title: "自动保存",
                value: "\(settingsManager.appSettings.autoSaveInterval) 秒"
            )

            if settingsManager.appSettings.enableAdvancedFeatures {
                SettingsOverviewCard(
                    icon: "flask.fill",
                    iconColor: .red,
                    title: "实验功能",
                    value: "已启用"
                )
            }
        }
    }
    
    private var dataManagementOverview: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsOverviewCard(
                icon: "icloud.fill",
                iconColor: .blue,
                title: "自动备份",
                value: settingsManager.dataSettings.enableAutoBackup ? "已启用" : "已禁用"
            )

            if settingsManager.dataSettings.enableAutoBackup {
                SettingsOverviewCard(
                    icon: "calendar",
                    iconColor: .green,
                    title: "备份频率",
                    value: backupFrequencyDisplayName
                )

                SettingsOverviewCard(
                    icon: "archivebox.fill",
                    iconColor: .orange,
                    title: "保留备份",
                    value: "\(settingsManager.dataSettings.maxBackupCount) 个"
                )
            }

            if let lastBackupDate = settingsManager.dataSettings.lastBackupDate {
                SettingsOverviewCard(
                    icon: "checkmark.circle.fill",
                    iconColor: .green,
                    title: "上次备份",
                    value: dateFormatter.string(from: lastBackupDate)
                )
            }
        }
    }
    
    private var aboutOverview: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsOverviewCard(
                icon: "app.fill",
                iconColor: .blue,
                title: "应用版本",
                value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
            )

            SettingsOverviewCard(
                icon: "hammer.fill",
                iconColor: .orange,
                title: "构建号",
                value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
            )

            #if os(iOS)
            SettingsOverviewCard(
                icon: "iphone",
                iconColor: .purple,
                title: "系统版本",
                value: "iOS \(UIDevice.current.systemVersion)"
            )
            #elseif os(macOS)
            SettingsOverviewCard(
                icon: "desktopcomputer",
                iconColor: .purple,
                title: "系统版本",
                value: "macOS"
            )
            #endif
        }
    }
    
    // MARK: - 辅助计算属性
    
    private var themeDisplayName: String {
        switch settingsManager.appearanceSettings.themeMode {
        case "light": return "浅色模式"
        case "dark": return "深色模式"
        default: return "跟随系统"
        }
    }
    
    private var accentColorDisplayName: String {
        switch settingsManager.appearanceSettings.accentColor {
        case "blue": return "蓝色"
        case "green": return "绿色"
        case "orange": return "橙色"
        case "purple": return "紫色"
        case "red": return "红色"
        case "pink": return "粉色"
        case "yellow": return "黄色"
        case "indigo": return "靛蓝"
        case "teal": return "青色"
        case "cyan": return "青蓝"
        default: return "系统默认"
        }
    }
    
    private var languageDisplayName: String {
        switch settingsManager.appearanceSettings.language {
        case "zh-Hans": return "简体中文"
        case "en": return "English"
        default: return "跟随系统"
        }
    }
    
    private var backupFrequencyDisplayName: String {
        switch settingsManager.dataSettings.backupFrequency {
        case "daily": return "每天"
        case "weekly": return "每周"
        case "monthly": return "每月"
        default: return "未知"
        }
    }
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }
}

// MARK: - 概览卡片组件

struct SettingsOverviewCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(iconColor)
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(iconColor.opacity(0.1))
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(value)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.adaptiveBackground)
                .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)
        )
    }
}

#Preview {
    SettingsOverviewPanel(panel: .notification)
        .environmentObject(SettingsManager.shared)
}
