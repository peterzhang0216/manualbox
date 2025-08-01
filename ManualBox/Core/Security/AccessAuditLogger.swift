//
//  AccessAuditLogger.swift
//  ManualBox
//
//  Created by Assistant on 2024/12/19.
//  访问审计日志 - 记录和管理用户访问和操作日志
//

import Foundation
import SwiftUI

// MARK: - 审计事件类型
enum AuditEventType: String, CaseIterable, Codable {
    // 权限相关事件
    case permissionCheck = "permission_check"
    case permissionGranted = "permission_granted"
    case permissionDenied = "permission_denied"
    case roleChange = "role_change"
    case permissionChange = "permission_change"
    
    // 数据访问事件
    case dataRead = "data_read"
    case dataWrite = "data_write"
    case dataDelete = "data_delete"
    case dataExport = "data_export"
    case dataImport = "data_import"
    
    // 系统事件
    case systemLogin = "system_login"
    case systemLogout = "system_logout"
    case accessControlEnabled = "access_control_enabled"
    case accessControlDisabled = "access_control_disabled"
    case permissionsReset = "permissions_reset"
    
    // 安全事件
    case authenticationSuccess = "authentication_success"
    case authenticationFailure = "authentication_failure"
    case biometricAuthSuccess = "biometric_auth_success"
    case biometricAuthFailure = "biometric_auth_failure"
    case encryptionEnabled = "encryption_enabled"
    case encryptionDisabled = "encryption_disabled"
    
    // 操作事件
    case operationAuthorized = "operation_authorized"
    case operationBlocked = "operation_blocked"
    case batchOperation = "batch_operation"
    case syncOperation = "sync_operation"
    
    var displayName: String {
        switch self {
        case .permissionCheck: return "权限检查"
        case .permissionGranted: return "权限授予"
        case .permissionDenied: return "权限拒绝"
        case .roleChange: return "角色变更"
        case .permissionChange: return "权限变更"
        case .dataRead: return "数据读取"
        case .dataWrite: return "数据写入"
        case .dataDelete: return "数据删除"
        case .dataExport: return "数据导出"
        case .dataImport: return "数据导入"
        case .systemLogin: return "系统登录"
        case .systemLogout: return "系统登出"
        case .accessControlEnabled: return "访问控制启用"
        case .accessControlDisabled: return "访问控制禁用"
        case .permissionsReset: return "权限重置"
        case .authenticationSuccess: return "认证成功"
        case .authenticationFailure: return "认证失败"
        case .biometricAuthSuccess: return "生物识别成功"
        case .biometricAuthFailure: return "生物识别失败"
        case .encryptionEnabled: return "加密启用"
        case .encryptionDisabled: return "加密禁用"
        case .operationAuthorized: return "操作授权"
        case .operationBlocked: return "操作阻止"
        case .batchOperation: return "批量操作"
        case .syncOperation: return "同步操作"
        }
    }
    
    var severity: AuditSeverity {
        switch self {
        case .permissionDenied, .authenticationFailure, .biometricAuthFailure, .operationBlocked:
            return .high
        case .roleChange, .permissionChange, .dataDelete, .accessControlEnabled, .accessControlDisabled, .permissionsReset:
            return .medium
        case .permissionCheck, .permissionGranted, .dataRead, .dataWrite, .authenticationSuccess, .biometricAuthSuccess, .operationAuthorized:
            return .low
        case .dataExport, .dataImport, .systemLogin, .systemLogout, .encryptionEnabled, .encryptionDisabled, .batchOperation, .syncOperation:
            return .medium
        }
    }
    
    var icon: String {
        switch self {
        case .permissionCheck, .permissionGranted, .permissionDenied: return "key"
        case .roleChange, .permissionChange: return "person.badge.key"
        case .dataRead: return "eye"
        case .dataWrite: return "pencil"
        case .dataDelete: return "trash"
        case .dataExport: return "square.and.arrow.up"
        case .dataImport: return "square.and.arrow.down"
        case .systemLogin, .systemLogout: return "person.circle"
        case .accessControlEnabled, .accessControlDisabled: return "shield"
        case .permissionsReset: return "arrow.clockwise"
        case .authenticationSuccess, .authenticationFailure: return "lock"
        case .biometricAuthSuccess, .biometricAuthFailure: return "faceid"
        case .encryptionEnabled, .encryptionDisabled: return "lock.shield"
        case .operationAuthorized, .operationBlocked: return "checkmark.shield"
        case .batchOperation: return "rectangle.3.group"
        case .syncOperation: return "arrow.triangle.2.circlepath"
        }
    }
}

// MARK: - 审计严重程度
enum AuditSeverity: String, CaseIterable, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
    
    var displayName: String {
        switch self {
        case .low: return "低"
        case .medium: return "中"
        case .high: return "高"
        case .critical: return "严重"
        }
    }
    
    var color: Color {
        switch self {
        case .low: return .green
        case .medium: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }
}

// MARK: - 审计日志条目
struct AuditLogEntry: Identifiable, Codable {
    let id = UUID()
    let timestamp: Date
    let eventType: AuditEventType
    let severity: AuditSeverity
    let userId: String
    let userRole: String
    let resource: String?
    let permission: String?
    let details: String?
    let ipAddress: String?
    let deviceInfo: String?
    let success: Bool
    
    init(
        eventType: AuditEventType,
        userId: String = "current_user",
        userRole: String,
        resource: String? = nil,
        permission: String? = nil,
        details: String? = nil,
        success: Bool = true
    ) {
        self.timestamp = Date()
        self.eventType = eventType
        self.severity = eventType.severity
        self.userId = userId
        self.userRole = userRole
        self.resource = resource
        self.permission = permission
        self.details = details
        self.ipAddress = NetworkInfoProvider.shared.getLocalIPAddress()
        self.deviceInfo = DeviceInfoProvider.shared.getDeviceInfo()
        self.success = success
    }
}

// MARK: - 访问审计日志管理器
@MainActor
class AccessAuditLogger: ObservableObject {
    static let shared = AccessAuditLogger()
    
    // MARK: - Published Properties
    @Published private(set) var auditLogs: [AuditLogEntry] = []
    @Published private(set) var isLoggingEnabled = true
    @Published private(set) var maxLogEntries = 10000
    @Published private(set) var logRetentionDays = 90
    @Published private(set) var lastCleanupDate: Date?
    
    // MARK: - Private Properties
    private let fileManager = FileManager.default
    private let logFileName = "audit_logs.json"
    private var logFileURL: URL {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent(logFileName)
    }
    
    // MARK: - Initialization
    private init() {
        loadSettings()
        loadAuditLogs()
        scheduleLogCleanup()
    }
    
    // MARK: - Public Methods
    
    /// 启用或禁用审计日志
    func setLoggingEnabled(_ enabled: Bool) {
        isLoggingEnabled = enabled
        saveSettings()
        
        if enabled {
            logSystemEvent(.accessControlEnabled, details: "审计日志已启用")
        } else {
            logSystemEvent(.accessControlDisabled, details: "审计日志已禁用")
        }
    }
    
    /// 设置日志保留配置
    func configureLogRetention(maxEntries: Int, retentionDays: Int) {
        maxLogEntries = maxEntries
        logRetentionDays = retentionDays
        saveSettings()
        
        logSystemEvent(.permissionsReset, details: "日志保留配置已更新: 最大条目 \(maxEntries), 保留天数 \(retentionDays)")
        
        // 立即执行清理
        cleanupOldLogs()
    }
    
    /// 记录权限检查
    func logPermissionCheck(_ permission: Permission, granted: Bool) {
        guard isLoggingEnabled else { return }
        
        let entry = AuditLogEntry(
            eventType: .permissionCheck,
            userRole: getCurrentUserRole(),
            permission: permission.rawValue,
            details: "权限检查: \(permission.displayName)",
            success: granted
        )
        
        addLogEntry(entry)
    }
    
    /// 记录权限授予
    func logPermissionGranted(_ permission: Permission, temporary: Bool = false) {
        guard isLoggingEnabled else { return }
        
        let entry = AuditLogEntry(
            eventType: .permissionGranted,
            userRole: getCurrentUserRole(),
            permission: permission.rawValue,
            details: "权限授予: \(permission.displayName)" + (temporary ? " (临时)" : "")
        )
        
        addLogEntry(entry)
    }
    
    /// 记录权限拒绝
    func logPermissionDenied(_ permission: Permission, reason: String? = nil) {
        guard isLoggingEnabled else { return }
        
        let entry = AuditLogEntry(
            eventType: .permissionDenied,
            userRole: getCurrentUserRole(),
            permission: permission.rawValue,
            details: "权限拒绝: \(permission.displayName)" + (reason.map { " - \($0)" } ?? ""),
            success: false
        )
        
        addLogEntry(entry)
    }
    
    /// 记录角色变更
    func logRoleChange(from oldRole: UserRole, to newRole: UserRole) {
        guard isLoggingEnabled else { return }
        
        let entry = AuditLogEntry(
            eventType: .roleChange,
            userRole: newRole.rawValue,
            details: "角色变更: \(oldRole.displayName) -> \(newRole.displayName)"
        )
        
        addLogEntry(entry)
    }
    
    /// 记录权限变更
    func logPermissionChange(role: UserRole, permissions: [Permission]) {
        guard isLoggingEnabled else { return }
        
        let permissionNames = permissions.map { $0.displayName }.joined(separator: ", ")
        let entry = AuditLogEntry(
            eventType: .permissionChange,
            userRole: role.rawValue,
            details: "权限变更: \(role.displayName) - \(permissionNames)"
        )
        
        addLogEntry(entry)
    }
    
    /// 记录数据访问
    func logDataAccess<T>(_ dataType: T.Type, operation: String, resourceId: String? = nil) {
        guard isLoggingEnabled else { return }
        
        let eventType: AuditEventType
        switch operation.lowercased() {
        case "read", "view", "get":
            eventType = .dataRead
        case "write", "update", "create", "save":
            eventType = .dataWrite
        case "delete", "remove":
            eventType = .dataDelete
        case "export":
            eventType = .dataExport
        case "import":
            eventType = .dataImport
        default:
            eventType = .dataRead
        }
        
        let entry = AuditLogEntry(
            eventType: eventType,
            userRole: getCurrentUserRole(),
            resource: String(describing: dataType),
            details: "数据\(operation): \(String(describing: dataType))" + (resourceId.map { " (ID: \($0))" } ?? "")
        )
        
        addLogEntry(entry)
    }
    
    /// 记录操作授权
    func logOperationAuthorized(_ operation: String, permission: Permission) {
        guard isLoggingEnabled else { return }
        
        let entry = AuditLogEntry(
            eventType: .operationAuthorized,
            userRole: getCurrentUserRole(),
            permission: permission.rawValue,
            details: "操作授权: \(operation)"
        )
        
        addLogEntry(entry)
    }
    
    /// 记录操作阻止
    func logOperationBlocked(_ operation: String, reason: String) {
        guard isLoggingEnabled else { return }
        
        let entry = AuditLogEntry(
            eventType: .operationBlocked,
            userRole: getCurrentUserRole(),
            details: "操作阻止: \(operation) - \(reason)",
            success: false
        )
        
        addLogEntry(entry)
    }
    
    /// 记录系统事件
    func logSystemEvent(_ eventType: AuditEventType, details: String? = nil) {
        guard isLoggingEnabled else { return }
        
        let entry = AuditLogEntry(
            eventType: eventType,
            userRole: getCurrentUserRole(),
            details: details
        )
        
        addLogEntry(entry)
    }
    
    /// 记录认证事件
    func logAuthenticationEvent(_ eventType: AuditEventType, method: String, success: Bool) {
        guard isLoggingEnabled else { return }
        
        let entry = AuditLogEntry(
            eventType: eventType,
            userRole: getCurrentUserRole(),
            details: "认证方式: \(method)",
            success: success
        )
        
        addLogEntry(entry)
    }
    
    /// 获取审计日志（带筛选）
    func getAuditLogs(
        eventTypes: Set<AuditEventType>? = nil,
        severities: Set<AuditSeverity>? = nil,
        dateRange: ClosedRange<Date>? = nil,
        limit: Int? = nil
    ) -> [AuditLogEntry] {
        var filteredLogs = auditLogs
        
        // 按事件类型筛选
        if let eventTypes = eventTypes, !eventTypes.isEmpty {
            filteredLogs = filteredLogs.filter { eventTypes.contains($0.eventType) }
        }
        
        // 按严重程度筛选
        if let severities = severities, !severities.isEmpty {
            filteredLogs = filteredLogs.filter { severities.contains($0.severity) }
        }
        
        // 按日期范围筛选
        if let dateRange = dateRange {
            filteredLogs = filteredLogs.filter { dateRange.contains($0.timestamp) }
        }
        
        // 按时间倒序排列
        filteredLogs.sort { $0.timestamp > $1.timestamp }
        
        // 限制数量
        if let limit = limit {
            filteredLogs = Array(filteredLogs.prefix(limit))
        }
        
        return filteredLogs
    }
    
    /// 导出审计日志
    func exportAuditLogs(format: ExportFormat = .json) -> URL? {
        do {
            let tempDirectory = fileManager.temporaryDirectory
            let fileName = "audit_logs_\(dateFormatter.string(from: Date())).\(format.fileExtension)"
            let fileURL = tempDirectory.appendingPathComponent(fileName)
            
            switch format {
            case .json:
                let jsonData = try JSONEncoder().encode(auditLogs)
                try jsonData.write(to: fileURL)
            case .csv:
                let csvContent = generateCSVContent()
                try csvContent.write(to: fileURL, atomically: true, encoding: .utf8)
            }
            
            logSystemEvent(.dataExport, details: "审计日志导出: \(format.rawValue)")
            return fileURL
            
        } catch {
            print("❌ 审计日志导出失败: \(error)")
            return nil
        }
    }
    
    /// 清理旧日志
    func cleanupOldLogs() {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -logRetentionDays, to: Date()) ?? Date()
        let initialCount = auditLogs.count
        
        auditLogs.removeAll { $0.timestamp < cutoffDate }
        
        // 如果超过最大条目数，删除最旧的条目
        if auditLogs.count > maxLogEntries {
            auditLogs = Array(auditLogs.suffix(maxLogEntries))
        }
        
        let removedCount = initialCount - auditLogs.count
        if removedCount > 0 {
            lastCleanupDate = Date()
            saveAuditLogs()
            saveSettings()
            
            logSystemEvent(.permissionsReset, details: "日志清理: 删除 \(removedCount) 条旧记录")
            print("🧹 清理了 \(removedCount) 条旧审计日志")
        }
    }
    
    /// 获取审计统计信息
    func getAuditStatistics() -> AuditStatistics {
        let now = Date()
        let last24Hours = Calendar.current.date(byAdding: .hour, value: -24, to: now) ?? now
        let last7Days = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
        
        let recent24h = auditLogs.filter { $0.timestamp >= last24Hours }
        let recent7d = auditLogs.filter { $0.timestamp >= last7Days }
        
        let eventTypeCounts = Dictionary(grouping: auditLogs) { $0.eventType }
            .mapValues { $0.count }
        
        let severityCounts = Dictionary(grouping: auditLogs) { $0.severity }
            .mapValues { $0.count }
        
        return AuditStatistics(
            totalEntries: auditLogs.count,
            entriesLast24h: recent24h.count,
            entriesLast7d: recent7d.count,
            eventTypeCounts: eventTypeCounts,
            severityCounts: severityCounts,
            oldestEntry: auditLogs.min(by: { $0.timestamp < $1.timestamp })?.timestamp,
            newestEntry: auditLogs.max(by: { $0.timestamp < $1.timestamp })?.timestamp,
            lastCleanup: lastCleanupDate
        )
    }
    
    // MARK: - Private Methods
    
    private func addLogEntry(_ entry: AuditLogEntry) {
        auditLogs.append(entry)
        
        // 异步保存到文件
        Task {
            await saveAuditLogsAsync()
        }
        
        // 检查是否需要清理
        if auditLogs.count > maxLogEntries * 2 {
            cleanupOldLogs()
        }
    }
    
    private func getCurrentUserRole() -> String {
        return AccessControlManager.shared.currentUserRole.rawValue
    }
    
    private func loadAuditLogs() {
        do {
            let data = try Data(contentsOf: logFileURL)
            auditLogs = try JSONDecoder().decode([AuditLogEntry].self, from: data)
            print("📋 加载了 \(auditLogs.count) 条审计日志")
        } catch {
            print("📋 无法加载审计日志: \(error)")
            auditLogs = []
        }
    }
    
    private func saveAuditLogs() {
        do {
            let data = try JSONEncoder().encode(auditLogs)
            try data.write(to: logFileURL)
        } catch {
            print("❌ 保存审计日志失败: \(error)")
        }
    }
    
    private func saveAuditLogsAsync() async {
        do {
            let data = try JSONEncoder().encode(auditLogs)
            try data.write(to: logFileURL)
        } catch {
            print("❌ 异步保存审计日志失败: \(error)")
        }
    }
    
    private func loadSettings() {
        isLoggingEnabled = UserDefaults.standard.bool(forKey: "AuditLoggingEnabled")
        maxLogEntries = UserDefaults.standard.integer(forKey: "MaxAuditLogEntries")
        logRetentionDays = UserDefaults.standard.integer(forKey: "AuditLogRetentionDays")
        
        if let cleanupData = UserDefaults.standard.object(forKey: "LastAuditCleanupDate") as? Date {
            lastCleanupDate = cleanupData
        }
        
        // 设置默认值
        if maxLogEntries == 0 { maxLogEntries = 10000 }
        if logRetentionDays == 0 { logRetentionDays = 90 }
        if !UserDefaults.standard.bool(forKey: "AuditSettingsInitialized") {
            isLoggingEnabled = true
            saveSettings()
            UserDefaults.standard.set(true, forKey: "AuditSettingsInitialized")
        }
    }
    
    private func saveSettings() {
        UserDefaults.standard.set(isLoggingEnabled, forKey: "AuditLoggingEnabled")
        UserDefaults.standard.set(maxLogEntries, forKey: "MaxAuditLogEntries")
        UserDefaults.standard.set(logRetentionDays, forKey: "AuditLogRetentionDays")
        
        if let cleanupDate = lastCleanupDate {
            UserDefaults.standard.set(cleanupDate, forKey: "LastAuditCleanupDate")
        }
    }
    
    private func scheduleLogCleanup() {
        // 每天检查一次是否需要清理日志
        Timer.scheduledTimer(withTimeInterval: 24 * 60 * 60, repeats: true) { _ in
            Task { @MainActor in
                self.cleanupOldLogs()
            }
        }
    }
    
    private func generateCSVContent() -> String {
        var csv = "Timestamp,Event Type,Severity,User Role,Resource,Permission,Details,Success\n"
        
        for entry in auditLogs {
            let row = [
                dateFormatter.string(from: entry.timestamp),
                entry.eventType.displayName,
                entry.severity.displayName,
                entry.userRole,
                entry.resource ?? "",
                entry.permission ?? "",
                entry.details ?? "",
                entry.success ? "Yes" : "No"
            ].map { "\"\($0)\"" }.joined(separator: ",")
            
            csv += row + "\n"
        }
        
        return csv
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter
    }
}

// ExportFormat is defined in Core/Utils/ExportFormat.swift

// MARK: - 审计统计信息
struct AuditStatistics {
    let totalEntries: Int
    let entriesLast24h: Int
    let entriesLast7d: Int
    let eventTypeCounts: [AuditEventType: Int]
    let severityCounts: [AuditSeverity: Int]
    let oldestEntry: Date?
    let newestEntry: Date?
    let lastCleanup: Date?
}

// MARK: - 网络信息提供者
class NetworkInfoProvider {
    static let shared = NetworkInfoProvider()
    
    private init() {}
    
    func getLocalIPAddress() -> String? {
        // 简化实现，返回本地IP地址
        return "127.0.0.1"
    }
}

// MARK: - 设备信息提供者
class DeviceInfoProvider {
    static let shared = DeviceInfoProvider()
    
    private init() {}
    
    func getDeviceInfo() -> String {
        let device = UIDevice.current
        return "\(device.model) - \(device.systemName) \(device.systemVersion)"
    }
}