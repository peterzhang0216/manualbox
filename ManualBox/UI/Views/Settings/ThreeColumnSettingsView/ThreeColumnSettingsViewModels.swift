//
//  ThreeColumnSettingsViewModels.swift
//  ManualBox
//
//  Created by Assistant on 2024/12/19.
//

import SwiftUI
import Foundation

// MARK: - 设置面板枚举
enum SettingsPanel: String, CaseIterable, Hashable {
    case notification = "notification"
    case appearance = "appearance"
    case appSettings = "appSettings"
    case dataManagement = "dataManagement"
    case about = "about"
    
    var title: String {
        switch self {
        case .notification:
            return "通知"
        case .appearance:
            return "外观"
        case .appSettings:
            return "应用设置"
        case .dataManagement:
            return "数据管理"
        case .about:
            return "关于"
        }
    }
    
    var icon: String {
        switch self {
        case .notification:
            return "bell"
        case .appearance:
            return "paintbrush"
        case .appSettings:
            return "gear"
        case .dataManagement:
            return "externaldrive"
        case .about:
            return "info.circle"
        }
    }
    
    var color: Color {
        switch self {
        case .notification:
            return .orange
        case .appearance:
            return .purple
        case .appSettings:
            return .blue
        case .dataManagement:
            return .green
        case .about:
            return .gray
        }
    }
    
    var description: String {
        switch self {
        case .notification:
            return "管理应用通知和提醒设置"
        case .appearance:
            return "自定义应用外观和主题"
        case .appSettings:
            return "配置应用功能和默认参数"
        case .dataManagement:
            return "管理数据备份、同步和导入导出"
        case .about:
            return "查看应用信息和获取帮助支持"
        }
    }
}

// MARK: - 设置子面板枚举
enum SettingsSubPanel: String, CaseIterable, Hashable {
    // 通知相关
    case notificationPermissions = "notificationPermissions"
    case reminderSettings = "reminderSettings"
    case silentPeriod = "silentPeriod"
    
    // 外观相关
    case themeMode = "themeMode"
    case themeColors = "themeColors"
    case displayOptions = "displayOptions"
    case languageSettings = "languageSettings"
    
    // 应用设置相关
    case defaultParameters = "defaultParameters"
    case ocrSettings = "ocrSettings"
    case advancedOptions = "advancedOptions"
    
    // 数据管理相关
    case syncStatus = "syncStatus"
    case backupRestore = "backupRestore"
    case importExport = "importExport"
    case dataCleanup = "dataCleanup"
    
    // 关于相关
    case appInfo = "appInfo"
    case helpSupport = "helpSupport"
    case legalTerms = "legalTerms"
    
    var title: String {
        switch self {
        case .notificationPermissions:
            return "通知权限"
        case .reminderSettings:
            return "提醒设置"
        case .silentPeriod:
            return "免打扰"
        case .themeMode:
            return "主题模式"
        case .themeColors:
            return "主题色彩"
        case .displayOptions:
            return "显示选项"
        case .languageSettings:
            return "语言设置"
        case .defaultParameters:
            return "默认参数"
        case .ocrSettings:
            return "OCR设置"
        case .advancedOptions:
            return "高级选项"
        case .syncStatus:
            return "同步状态"
        case .backupRestore:
            return "备份恢复"
        case .importExport:
            return "导入导出"
        case .dataCleanup:
            return "数据清理"
        case .appInfo:
            return "应用信息"
        case .helpSupport:
            return "帮助支持"
        case .legalTerms:
            return "法律条款"
        }
    }
    
    var icon: String {
        switch self {
        case .notificationPermissions:
            return "bell.badge"
        case .reminderSettings:
            return "alarm"
        case .silentPeriod:
            return "moon"
        case .themeMode:
            return "circle.lefthalf.filled"
        case .themeColors:
            return "paintpalette"
        case .displayOptions:
            return "display"
        case .languageSettings:
            return "globe"
        case .defaultParameters:
            return "slider.horizontal.3"
        case .ocrSettings:
            return "doc.text.viewfinder"
        case .advancedOptions:
            return "gearshape.2"
        case .syncStatus:
            return "icloud"
        case .backupRestore:
            return "externaldrive.badge.timemachine"
        case .importExport:
            return "square.and.arrow.up.on.square"
        case .dataCleanup:
            return "trash"
        case .appInfo:
            return "app.badge"
        case .helpSupport:
            return "questionmark.circle"
        case .legalTerms:
            return "doc.text"
        }
    }
    
    var color: Color {
        switch self {
        case .notificationPermissions, .reminderSettings, .silentPeriod:
            return .orange
        case .themeMode, .themeColors, .displayOptions, .languageSettings:
            return .purple
        case .defaultParameters, .ocrSettings, .advancedOptions:
            return .blue
        case .syncStatus, .backupRestore, .importExport, .dataCleanup:
            return .green
        case .appInfo, .helpSupport, .legalTerms:
            return .gray
        }
    }
    
    var parentPanel: SettingsPanel {
        switch self {
        case .notificationPermissions, .reminderSettings, .silentPeriod:
            return .notification
        case .themeMode, .themeColors, .displayOptions, .languageSettings:
            return .appearance
        case .defaultParameters, .ocrSettings, .advancedOptions:
            return .appSettings
        case .syncStatus, .backupRestore, .importExport, .dataCleanup:
            return .dataManagement
        case .appInfo, .helpSupport, .legalTerms:
            return .about
        }
    }
}

// MARK: - 三栏设置视图状态
class ThreeColumnSettingsViewState: ObservableObject {
    @Published var selectedPanel: SettingsPanel = .notification
    @Published var selectedSubPanel: SettingsSubPanel? = nil
    
    func updateSelectedPanel(_ panel: SettingsPanel) {
        selectedPanel = panel
        // 当主面板改变时，自动选择第一个子面板
        selectedSubPanel = subPanelsForPanel(panel).first
    }
    
    func updateSelectedSubPanel(_ subPanel: SettingsSubPanel?) {
        selectedSubPanel = subPanel
    }
    
    func subPanelsForPanel(_ panel: SettingsPanel) -> [SettingsSubPanel] {
        SettingsSubPanel.allCases.filter { $0.parentPanel == panel }
    }
    
    var subPanelsForCurrentPanel: [SettingsSubPanel] {
        subPanelsForPanel(selectedPanel)
    }
    
    func initializeSubPanel() {
        if selectedSubPanel == nil {
            selectedSubPanel = subPanelsForCurrentPanel.first
        }
    }
}