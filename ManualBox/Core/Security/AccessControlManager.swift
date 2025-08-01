//
//  AccessControlManager.swift
//  ManualBox
//
//  Created by Assistant on 2024/12/19.
//  访问控制管理器 - 管理用户权限和数据访问控制
//

import Foundation
import SwiftUI
import LocalAuthentication

// MARK: - 权限类型定义
enum Permission: String, CaseIterable, Codable {
    // 数据访问权限
    case readProducts = "read_products"
    case writeProducts = "write_products"
    case deleteProducts = "delete_products"
    
    case readCategories = "read_categories"
    case writeCategories = "write_categories"
    case deleteCategories = "delete_categories"
    
    case readManuals = "read_manuals"
    case writeManuals = "write_manuals"
    case deleteManuals = "delete_manuals"
    
    // 系统功能权限
    case exportData = "export_data"
    case importData = "import_data"
    case backupData = "backup_data"
    case restoreData = "restore_data"
    
    case syncData = "sync_data"
    case manageSettings = "manage_settings"
    case viewStatistics = "view_statistics"
    
    // 高级功能权限
    case useOCR = "use_ocr"
    case batchOperations = "batch_operations"
    case advancedSearch = "advanced_search"
    case dataEncryption = "data_encryption"
    
    // 管理权限
    case manageUsers = "manage_users"
    case managePermissions = "manage_permissions"
    case viewAuditLogs = "view_audit_logs"
    case systemMaintenance = "system_maintenance"
    
    var displayName: String {
        switch self {
        case .readProducts: return "查看产品"
        case .writeProducts: return "编辑产品"
        case .deleteProducts: return "删除产品"
        case .readCategories: return "查看分类"
        case .writeCategories: return "编辑分类"
        case .deleteCategories: return "删除分类"
        case .readManuals: return "查看手册"
        case .writeManuals: return "编辑手册"
        case .deleteManuals: return "删除手册"
        case .exportData: return "导出数据"
        case .importData: return "导入数据"
        case .backupData: return "备份数据"
        case .restoreData: return "恢复数据"
        case .syncData: return "同步数据"
        case .manageSettings: return "管理设置"
        case .viewStatistics: return "查看统计"
        case .useOCR: return "使用OCR"
        case .batchOperations: return "批量操作"
        case .advancedSearch: return "高级搜索"
        case .dataEncryption: return "数据加密"
        case .manageUsers: return "管理用户"
        case .managePermissions: return "管理权限"
        case .viewAuditLogs: return "查看审计日志"
        case .systemMaintenance: return "系统维护"
        }
    }
    
    var category: PermissionCategory {
        switch self {
        case .readProducts, .writeProducts, .deleteProducts,
             .readCategories, .writeCategories, .deleteCategories,
             .readManuals, .writeManuals, .deleteManuals:
            return .dataAccess
        case .exportData, .importData, .backupData, .restoreData,
             .syncData, .manageSettings, .viewStatistics:
            return .systemFunction
        case .useOCR, .batchOperations, .advancedSearch, .dataEncryption:
            return .advancedFeature
        case .manageUsers, .managePermissions, .viewAuditLogs, .systemMaintenance:
            return .administration
        }
    }
    
    var requiresBiometric: Bool {
        switch self {
        case .deleteProducts, .deleteCategories, .deleteManuals,
             .restoreData, .dataEncryption, .manageUsers,
             .managePermissions, .systemMaintenance:
            return true
        default:
            return false
        }
    }
    
    var icon: String {
        switch self {
        case .readProducts, .readCategories, .readManuals: return "eye"
        case .writeProducts, .writeCategories, .writeManuals: return "pencil"
        case .deleteProducts, .deleteCategories, .deleteManuals: return "trash"
        case .exportData: return "square.and.arrow.up"
        case .importData: return "square.and.arrow.down"
        case .backupData: return "externaldrive"
        case .restoreData: return "arrow.clockwise"
        case .syncData: return "arrow.triangle.2.circlepath"
        case .manageSettings: return "gear"
        case .viewStatistics: return "chart.bar"
        case .useOCR: return "doc.text.viewfinder"
        case .batchOperations: return "rectangle.3.group"
        case .advancedSearch: return "magnifyingglass.circle"
        case .dataEncryption: return "lock.shield"
        case .manageUsers: return "person.2"
        case .managePermissions: return "key"
        case .viewAuditLogs: return "list.clipboard"
        case .systemMaintenance: return "wrench.and.screwdriver"
        }
    }
}

// MARK: - 权限分类
enum PermissionCategory: String, CaseIterable {
    case dataAccess = "data_access"
    case systemFunction = "system_function"
    case advancedFeature = "advanced_feature"
    case administration = "administration"
    
    var displayName: String {
        switch self {
        case .dataAccess: return "数据访问"
        case .systemFunction: return "系统功能"
        case .advancedFeature: return "高级功能"
        case .administration: return "系统管理"
        }
    }
    
    var color: Color {
        switch self {
        case .dataAccess: return .blue
        case .systemFunction: return .green
        case .advancedFeature: return .orange
        case .administration: return .red
        }
    }
}

// MARK: - 用户角色定义
enum UserRole: String, CaseIterable, Codable {
    case viewer = "viewer"
    case editor = "editor"
    case admin = "admin"
    case owner = "owner"
    
    var displayName: String {
        switch self {
        case .viewer: return "查看者"
        case .editor: return "编辑者"
        case .admin: return "管理员"
        case .owner: return "所有者"
        }
    }
    
    var defaultPermissions: Set<Permission> {
        switch self {
        case .viewer:
            return [
                .readProducts, .readCategories, .readManuals,
                .viewStatistics, .advancedSearch
            ]
        case .editor:
            return [
                .readProducts, .writeProducts,
                .readCategories, .writeCategories,
                .readManuals, .writeManuals,
                .exportData, .importData, .syncData,
                .viewStatistics, .useOCR, .batchOperations, .advancedSearch
            ]
        case .admin:
            return Set(Permission.allCases.filter { $0.category != .administration })
        case .owner:
            return Set(Permission.allCases)
        }
    }
    
    var priority: Int {
        switch self {
        case .viewer: return 1
        case .editor: return 2
        case .admin: return 3
        case .owner: return 4
        }
    }
}

// MARK: - 访问控制错误
enum AccessControlError: Error, LocalizedError {
    case permissionDenied(Permission)
    case authenticationRequired
    case biometricAuthenticationFailed
    case roleNotFound
    case invalidPermissionConfiguration
    case auditLogWriteFailed
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied(let permission):
            return "权限不足: 需要 \(permission.displayName) 权限"
        case .authenticationRequired:
            return "需要身份验证"
        case .biometricAuthenticationFailed:
            return "生物识别验证失败"
        case .roleNotFound:
            return "未找到用户角色"
        case .invalidPermissionConfiguration:
            return "权限配置无效"
        case .auditLogWriteFailed:
            return "审计日志写入失败"
        }
    }
}

// MARK: - 访问控制管理器
@MainActor
class AccessControlManager: ObservableObject {
    static let shared = AccessControlManager()
    
    // MARK: - Published Properties
    @Published private(set) var currentUserRole: UserRole = .owner
    @Published private(set) var currentPermissions: Set<Permission> = []
    @Published private(set) var isAccessControlEnabled = false
    @Published private(set) var lastAccessError: String?
    @Published private(set) var pendingPermissionRequests: [PermissionRequest] = []
    
    // MARK: - Private Properties
    private let biometricManager = BiometricAuthenticationManager.shared
    private let auditLogger = AccessAuditLogger.shared
    private var customPermissions: [UserRole: Set<Permission>] = [:]
    
    // MARK: - Initialization
    private init() {
        loadAccessControlSettings()
        setupDefaultPermissions()
    }
    
    // MARK: - Public Methods
    
    /// 启用访问控制
    func enableAccessControl(withRole role: UserRole = .owner) {
        currentUserRole = role
        currentPermissions = getPermissions(for: role)
        isAccessControlEnabled = true
        saveAccessControlSettings()
        
        auditLogger.logSystemEvent(.accessControlEnabled, details: "角色: \(role.displayName)")
        print("🔐 访问控制已启用，当前角色: \(role.displayName)")
    }
    
    /// 禁用访问控制
    func disableAccessControl() {
        isAccessControlEnabled = false
        currentUserRole = .owner
        currentPermissions = Set(Permission.allCases)
        saveAccessControlSettings()
        
        auditLogger.logSystemEvent(.accessControlDisabled, details: nil)
        print("🔐 访问控制已禁用")
    }
    
    /// 检查权限
    func hasPermission(_ permission: Permission) -> Bool {
        guard isAccessControlEnabled else { return true }
        
        let hasPermission = currentPermissions.contains(permission)
        
        // 记录权限检查
        auditLogger.logPermissionCheck(permission, granted: hasPermission)
        
        return hasPermission
    }
    
    /// 请求权限（带身份验证）
    func requestPermission(_ permission: Permission, reason: String? = nil) async throws {
        guard isAccessControlEnabled else { return }
        
        // 检查是否已有权限
        if hasPermission(permission) {
            return
        }
        
        // 记录权限请求
        let request = PermissionRequest(
            permission: permission,
            reason: reason ?? "执行操作需要此权限",
            timestamp: Date()
        )
        pendingPermissionRequests.append(request)
        
        // 如果需要生物识别验证
        if permission.requiresBiometric {
            let isAuthenticated = await biometricManager.authenticateUser(
                reason: reason ?? "访问 \(permission.displayName) 需要验证身份"
            )
            
            guard isAuthenticated else {
                auditLogger.logPermissionDenied(permission, reason: "生物识别验证失败")
                throw AccessControlError.biometricAuthenticationFailed
            }
        }
        
        // 临时授予权限（在实际应用中，这里应该有更复杂的权限提升逻辑）
        auditLogger.logPermissionGranted(permission, temporary: true)
        print("🔐 临时授予权限: \(permission.displayName)")
        
        // 移除请求
        pendingPermissionRequests.removeAll { $0.permission == permission }
    }
    
    /// 验证操作权限
    func verifyPermission(_ permission: Permission, for operation: String) async throws {
        guard isAccessControlEnabled else { return }
        
        if !hasPermission(permission) {
            lastAccessError = "执行 \(operation) 需要 \(permission.displayName) 权限"
            auditLogger.logPermissionDenied(permission, reason: "操作: \(operation)")
            throw AccessControlError.permissionDenied(permission)
        }
        
        // 如果需要生物识别验证
        if permission.requiresBiometric {
            let isAuthenticated = await biometricManager.authenticateUser(
                reason: "执行 \(operation) 需要验证身份"
            )
            
            guard isAuthenticated else {
                auditLogger.logPermissionDenied(permission, reason: "生物识别验证失败，操作: \(operation)")
                throw AccessControlError.biometricAuthenticationFailed
            }
        }
        
        auditLogger.logOperationAuthorized(operation, permission: permission)
    }
    
    /// 更改用户角色
    func changeUserRole(to role: UserRole) async throws {
        // 验证管理权限
        try await verifyPermission(.manageUsers, for: "更改用户角色")
        
        let oldRole = currentUserRole
        currentUserRole = role
        currentPermissions = getPermissions(for: role)
        saveAccessControlSettings()
        
        auditLogger.logRoleChange(from: oldRole, to: role)
        print("🔐 用户角色已更改: \(oldRole.displayName) -> \(role.displayName)")
    }
    
    /// 自定义角色权限
    func customizeRolePermissions(_ role: UserRole, permissions: Set<Permission>) async throws {
        // 验证管理权限
        try await verifyPermission(.managePermissions, for: "自定义角色权限")
        
        customPermissions[role] = permissions
        
        // 如果是当前角色，立即应用
        if currentUserRole == role {
            currentPermissions = permissions
        }
        
        saveCustomPermissions()
        auditLogger.logPermissionChange(role: role, permissions: Array(permissions))
        print("🔐 角色权限已自定义: \(role.displayName)")
    }
    
    /// 获取角色权限
    func getPermissions(for role: UserRole) -> Set<Permission> {
        return customPermissions[role] ?? role.defaultPermissions
    }
    
    /// 获取所有可用权限（按分类）
    func getPermissionsByCategory() -> [PermissionCategory: [Permission]] {
        return Dictionary(grouping: Permission.allCases) { $0.category }
    }
    
    /// 重置权限配置
    func resetPermissions() async throws {
        // 验证管理权限
        try await verifyPermission(.managePermissions, for: "重置权限配置")
        
        customPermissions.removeAll()
        currentPermissions = currentUserRole.defaultPermissions
        saveCustomPermissions()
        
        auditLogger.logSystemEvent(.permissionsReset, details: nil)
        print("🔐 权限配置已重置")
    }
    
    /// 获取访问控制统计
    func getAccessControlStatistics() -> AccessControlStatistics {
        return AccessControlStatistics(
            isEnabled: isAccessControlEnabled,
            currentRole: currentUserRole,
            totalPermissions: Permission.allCases.count,
            grantedPermissions: currentPermissions.count,
            customRoles: customPermissions.count,
            pendingRequests: pendingPermissionRequests.count
        )
    }
    
    // MARK: - Private Methods
    
    private func setupDefaultPermissions() {
        currentPermissions = getPermissions(for: currentUserRole)
    }
    
    private func loadAccessControlSettings() {
        isAccessControlEnabled = UserDefaults.standard.bool(forKey: "AccessControlEnabled")
        
        if let roleString = UserDefaults.standard.string(forKey: "CurrentUserRole"),
           let role = UserRole(rawValue: roleString) {
            currentUserRole = role
        }
        
        loadCustomPermissions()
    }
    
    private func saveAccessControlSettings() {
        UserDefaults.standard.set(isAccessControlEnabled, forKey: "AccessControlEnabled")
        UserDefaults.standard.set(currentUserRole.rawValue, forKey: "CurrentUserRole")
    }
    
    private func loadCustomPermissions() {
        if let data = UserDefaults.standard.data(forKey: "CustomPermissions"),
           let permissions = try? JSONDecoder().decode([UserRole: Set<Permission>].self, from: data) {
            customPermissions = permissions
        }
    }
    
    private func saveCustomPermissions() {
        if let data = try? JSONEncoder().encode(customPermissions) {
            UserDefaults.standard.set(data, forKey: "CustomPermissions")
        }
    }
}

// MARK: - 权限请求模型
struct PermissionRequest: Identifiable {
    let id = UUID()
    let permission: Permission
    let reason: String
    let timestamp: Date
}

// MARK: - 访问控制统计
struct AccessControlStatistics {
    let isEnabled: Bool
    let currentRole: UserRole
    let totalPermissions: Int
    let grantedPermissions: Int
    let customRoles: Int
    let pendingRequests: Int
    
    var permissionCoverage: Double {
        guard totalPermissions > 0 else { return 0.0 }
        return Double(grantedPermissions) / Double(totalPermissions)
    }
}

// MARK: - 便利扩展
extension AccessControlManager {
    /// 检查数据访问权限
    func canAccessData<T>(_ dataType: T.Type) -> Bool {
        switch String(describing: dataType) {
        case "Product":
            return hasPermission(.readProducts)
        case "Category":
            return hasPermission(.readCategories)
        case "Manual":
            return hasPermission(.readManuals)
        default:
            return true
        }
    }
    
    /// 检查数据修改权限
    func canModifyData<T>(_ dataType: T.Type) -> Bool {
        switch String(describing: dataType) {
        case "Product":
            return hasPermission(.writeProducts)
        case "Category":
            return hasPermission(.writeCategories)
        case "Manual":
            return hasPermission(.writeManuals)
        default:
            return true
        }
    }
    
    /// 检查数据删除权限
    func canDeleteData<T>(_ dataType: T.Type) -> Bool {
        switch String(describing: dataType) {
        case "Product":
            return hasPermission(.deleteProducts)
        case "Category":
            return hasPermission(.deleteCategories)
        case "Manual":
            return hasPermission(.deleteManuals)
        default:
            return true
        }
    }
}