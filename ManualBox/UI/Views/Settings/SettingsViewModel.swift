//
//  SettingsViewModel.swift
//  ManualBox
//
//  Created by Assistant on 2025/1/27.
//

import Foundation
import SwiftUI
import CoreData

// MARK: - Settings Panel
enum SettingsPanel: Hashable {
    case notification
    case theme
    case data
    case about
    
    var title: String {
        switch self {
        case .notification: return "通知设置"
        case .theme: return "主题设置"
        case .data: return "数据管理"
        case .about: return "关于"
        }
    }
    
    var icon: String {
        switch self {
        case .notification: return "bell"
        case .theme: return "paintbrush"
        case .data: return "externaldrive"
        case .about: return "info.circle"
        }
    }
}

// MARK: - Settings State
struct SettingsState: StateProtocol {
    var isLoading: Bool = false
    var errorMessage: String? = nil
    
    // UI状态
    var selectedPanel: SettingsPanel = .notification
    var showResetAlert = false
    var showPrivacySheet = false
    var showAgreementSheet = false
    
    // 设置值
    var defaultWarrantyPeriod = 12
    var enableOCRByDefault = true
    var enableNotifications = true
    var notificationTime = Date()
    
    // 操作状态
    var isResetting = false
    var resetError: String?
    var isExporting = false
    var exportError: String?
}

// MARK: - Settings Actions
enum SettingsAction: ActionProtocol {
    case selectPanel(SettingsPanel)
    case toggleResetAlert
    case togglePrivacySheet
    case toggleAgreementSheet
    case updateDefaultWarrantyPeriod(Int)
    case updateEnableOCRByDefault(Bool)
    case updateEnableNotifications(Bool)
    case updateNotificationTime(Date)
    case resetAllData
    case exportData
    case importData
    case setResetting(Bool)
    case setExporting(Bool)
    case setResetError(String?)
    case setExportError(String?)
}

@MainActor
class SettingsViewModel: BaseViewModel<SettingsState, SettingsAction> {
    private let viewContext: NSManagedObjectContext
    
    // 便利属性
    var selectedPanel: SettingsPanel { state.selectedPanel }
    var showResetAlert: Bool { state.showResetAlert }
    var showPrivacySheet: Bool { state.showPrivacySheet }
    var showAgreementSheet: Bool { state.showAgreementSheet }
    var defaultWarrantyPeriod: Int { state.defaultWarrantyPeriod }
    var enableOCRByDefault: Bool { state.enableOCRByDefault }
    var enableNotifications: Bool { state.enableNotifications }
    var notificationTime: Date { state.notificationTime }
    var isResetting: Bool { state.isResetting }
    var resetError: String? { state.resetError }
    var isExporting: Bool { state.isExporting }
    var exportError: String? { state.exportError }
    
    init(viewContext: NSManagedObjectContext) {
        self.viewContext = viewContext
        super.init(initialState: SettingsState())
        loadSettings()
    }
    
    // MARK: - Action Handler
    override func handle(_ action: SettingsAction) async {
        switch action {
        case .selectPanel(let panel):
            updateState { $0.selectedPanel = panel }
            
        case .toggleResetAlert:
            updateState { $0.showResetAlert.toggle() }
            
        case .togglePrivacySheet:
            updateState { $0.showPrivacySheet.toggle() }
            
        case .toggleAgreementSheet:
            updateState { $0.showAgreementSheet.toggle() }
            
        case .updateDefaultWarrantyPeriod(let period):
            updateState { $0.defaultWarrantyPeriod = period }
            saveDefaultWarrantyPeriod(period)
            
        case .updateEnableOCRByDefault(let enabled):
            updateState { $0.enableOCRByDefault = enabled }
            saveEnableOCRByDefault(enabled)
            
        case .updateEnableNotifications(let enabled):
            updateState { $0.enableNotifications = enabled }
            await updateNotificationSettings(enabled)
            
        case .updateNotificationTime(let time):
            updateState { $0.notificationTime = time }
            saveNotificationTime(time)
            
        case .resetAllData:
            await resetAllData()
            
        case .exportData:
            await exportData()
            
        case .importData:
            await importData()
            
        case .setResetting(let resetting):
            updateState { $0.isResetting = resetting }
            
        case .setExporting(let exporting):
            updateState { $0.isExporting = exporting }
            
        case .setResetError(let error):
            updateState { $0.resetError = error }
            
        case .setExportError(let error):
            updateState { $0.exportError = error }
        }
    }
    
    // MARK: - Private Methods
    private func loadSettings() {
        // 从UserDefaults加载设置
        let defaults = UserDefaults.standard
        updateState {
            $0.defaultWarrantyPeriod = defaults.integer(forKey: "defaultWarrantyPeriod")
            if $0.defaultWarrantyPeriod == 0 { $0.defaultWarrantyPeriod = 12 }
            
            $0.enableOCRByDefault = defaults.bool(forKey: "enableOCRByDefault")
            $0.enableNotifications = defaults.bool(forKey: "enableNotifications")
            
            if let timeData = defaults.data(forKey: "notificationTime"),
               let time = try? JSONDecoder().decode(Date.self, from: timeData) {
                $0.notificationTime = time
            }
        }
    }
    
    private func saveDefaultWarrantyPeriod(_ period: Int) {
        UserDefaults.standard.set(period, forKey: "defaultWarrantyPeriod")
    }
    
    private func saveEnableOCRByDefault(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "enableOCRByDefault")
    }
    
    private func saveNotificationTime(_ time: Date) {
        if let timeData = try? JSONEncoder().encode(time) {
            UserDefaults.standard.set(timeData, forKey: "notificationTime")
        }
    }
    
    private func updateNotificationSettings(_ enabled: Bool) async {
        UserDefaults.standard.set(enabled, forKey: "enableNotifications")
        
        if enabled {
            // 请求通知权限
            await requestNotificationPermission()
        } else {
            // 取消所有通知
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        }
    }
    
    private func requestNotificationPermission() async {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            if !granted {
                updateState { 
                    $0.enableNotifications = false
                    $0.errorMessage = "通知权限被拒绝，请在系统设置中开启"
                }
            }
        } catch {
            updateState { 
                $0.enableNotifications = false
                $0.errorMessage = "请求通知权限失败: \(error.localizedDescription)"
            }
        }
    }
    
    private func resetAllData() async {
        updateState { $0.isResetting = true }
        
        do {
            // 删除所有Core Data实体
            let entities = ["Product", "Category", "Tag", "Order", "RepairRecord", "Manual"]
            
            for entityName in entities {
                let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
                let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
                try viewContext.execute(deleteRequest)
            }
            
            try viewContext.save()
            
            // 重置UserDefaults
            let defaults = UserDefaults.standard
            defaults.removeObject(forKey: "defaultWarrantyPeriod")
            defaults.removeObject(forKey: "enableOCRByDefault")
            defaults.removeObject(forKey: "enableNotifications")
            defaults.removeObject(forKey: "notificationTime")
            
            // 重新加载默认设置
            loadSettings()
            
            updateState { 
                $0.isResetting = false
                $0.resetError = nil
                $0.showResetAlert = false
            }
        } catch {
            updateState {
                $0.resetError = "重置数据失败: \(error.localizedDescription)"
                $0.isResetting = false
            }
        }
    }
    
    private func exportData() async {
        updateState { $0.isExporting = true }
        
        // TODO: 实现数据导出功能
        // 这里应该实现将Core Data数据导出为JSON或其他格式的功能
        
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 模拟导出过程
        
        updateState {
            $0.isExporting = false
            $0.exportError = nil
        }
    }
    
    private func importData() async {
        // TODO: 实现数据导入功能
        // 这里应该实现从文件导入数据到Core Data的功能
    }
    
    // MARK: - Public Methods
    func getAppVersion() -> String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "未知"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "未知"
        return "\(version) (\(build))"
    }
    
    func getDataStatistics() async -> DataStatistics {
        do {
            let productCount = try await getEntityCount("Product")
            let categoryCount = try await getEntityCount("Category")
            let tagCount = try await getEntityCount("Tag")
            let orderCount = try await getEntityCount("Order")
            let repairRecordCount = try await getEntityCount("RepairRecord")
            let manualCount = try await getEntityCount("Manual")
            
            return DataStatistics(
                productCount: productCount,
                categoryCount: categoryCount,
                tagCount: tagCount,
                orderCount: orderCount,
                repairRecordCount: repairRecordCount,
                manualCount: manualCount
            )
        } catch {
            return DataStatistics()
        }
    }
    
    private func getEntityCount(_ entityName: String) async throws -> Int {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
        return try viewContext.count(for: fetchRequest)
    }
}



struct DataStatistics {
    let productCount: Int
    let categoryCount: Int
    let tagCount: Int
    let orderCount: Int
    let repairRecordCount: Int
    let manualCount: Int
    
    init(productCount: Int = 0, categoryCount: Int = 0, tagCount: Int = 0, 
         orderCount: Int = 0, repairRecordCount: Int = 0, manualCount: Int = 0) {
        self.productCount = productCount
        self.categoryCount = categoryCount
        self.tagCount = tagCount
        self.orderCount = orderCount
        self.repairRecordCount = repairRecordCount
        self.manualCount = manualCount
    }
}

// MARK: - Import for UNUserNotificationCenter
import UserNotifications