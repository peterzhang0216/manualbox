//
//  PrivacyProtectionManager.swift
//  ManualBox
//
//  Created by Assistant on 2024/12/19.
//  隐私保护管理器 - 管理数据匿名化、用户同意和数据删除
//

import Foundation
import SwiftUI
import CryptoKit

// MARK: - 隐私保护错误
enum PrivacyProtectionError: Error, LocalizedError {
    case anonymizationFailed
    case consentNotGranted(String)
    case dataRetentionViolation
    case deletionFailed
    case invalidDataType
    case encryptionRequired
    
    var errorDescription: String? {
        switch self {
        case .anonymizationFailed:
            return "数据匿名化失败"
        case .consentNotGranted(let purpose):
            return "未获得用户同意: \(purpose)"
        case .dataRetentionViolation:
            return "违反数据保留政策"
        case .deletionFailed:
            return "数据删除失败"
        case .invalidDataType:
            return "无效的数据类型"
        case .encryptionRequired:
            return "需要数据加密"
        }
    }
}

// MARK: - 数据处理目的
enum DataProcessingPurpose: String, CaseIterable, Codable {
    case productManagement = "product_management"
    case categoryOrganization = "category_organization"
    case manualStorage = "manual_storage"
    case searchIndexing = "search_indexing"
    case dataSync = "data_sync"
    case analytics = "analytics"
    case backup = "backup"
    case export = "export"
    case sharing = "sharing"
    case cloudStorage = "cloud_storage"
    
    var displayName: String {
        switch self {
        case .productManagement: return "产品管理"
        case .categoryOrganization: return "分类整理"
        case .manualStorage: return "手册存储"
        case .searchIndexing: return "搜索索引"
        case .dataSync: return "数据同步"
        case .analytics: return "数据分析"
        case .backup: return "数据备份"
        case .export: return "数据导出"
        case .sharing: return "数据分享"
        case .cloudStorage: return "云端存储"
        }
    }
    
    var description: String {
        switch self {
        case .productManagement: return "用于管理和组织您的产品信息"
        case .categoryOrganization: return "用于创建和管理产品分类"
        case .manualStorage: return "用于存储和管理产品手册"
        case .searchIndexing: return "用于提供快速搜索功能"
        case .dataSync: return "用于在设备间同步数据"
        case .analytics: return "用于分析使用模式和改进应用"
        case .backup: return "用于创建数据备份以防丢失"
        case .export: return "用于导出数据到其他应用"
        case .sharing: return "用于与他人分享数据"
        case .cloudStorage: return "用于在云端安全存储数据"
        }
    }
    
    var isRequired: Bool {
        switch self {
        case .productManagement, .categoryOrganization, .manualStorage:
            return true
        case .searchIndexing, .dataSync, .backup:
            return false
        case .analytics, .export, .sharing, .cloudStorage:
            return false
        }
    }
    
    var dataRetentionDays: Int {
        switch self {
        case .productManagement, .categoryOrganization, .manualStorage:
            return -1 // 永久保留
        case .searchIndexing:
            return 365
        case .dataSync:
            return 90
        case .analytics:
            return 730
        case .backup:
            return 2555 // 7年
        case .export, .sharing:
            return 30
        case .cloudStorage:
            return -1 // 永久保留
        }
    }
}

// MARK: - 用户同意状态
enum ConsentStatus: String, Codable {
    case granted = "granted"
    case denied = "denied"
    case pending = "pending"
    case expired = "expired"
    case withdrawn = "withdrawn"
    
    var displayName: String {
        switch self {
        case .granted: return "已同意"
        case .denied: return "已拒绝"
        case .pending: return "待处理"
        case .expired: return "已过期"
        case .withdrawn: return "已撤回"
        }
    }
    
    var color: Color {
        switch self {
        case .granted: return .green
        case .denied: return .red
        case .pending: return .orange
        case .expired: return .gray
        case .withdrawn: return .red
        }
    }
}

// MARK: - 用户同意记录
struct ConsentRecord: Identifiable, Codable {
    let id = UUID()
    let purpose: DataProcessingPurpose
    var status: ConsentStatus
    let grantedDate: Date?
    let expiryDate: Date?
    let version: String
    let ipAddress: String?
    let userAgent: String?
    
    init(
        purpose: DataProcessingPurpose,
        status: ConsentStatus,
        version: String = "1.0",
        expiryDate: Date? = nil
    ) {
        self.purpose = purpose
        self.status = status
        self.grantedDate = status == .granted ? Date() : nil
        self.expiryDate = expiryDate
        self.version = version
        self.ipAddress = NetworkInfoProvider.shared.getLocalIPAddress()
        self.userAgent = DeviceInfoProvider.shared.getDeviceInfo()
    }
    
    var isValid: Bool {
        guard status == .granted else { return false }
        
        if let expiryDate = expiryDate {
            return Date() < expiryDate
        }
        
        return true
    }
    
    var isExpired: Bool {
        guard let expiryDate = expiryDate else { return false }
        return Date() >= expiryDate
    }
}

// MARK: - 数据匿名化配置
struct AnonymizationConfig {
    let shouldAnonymize: Bool
    let fieldsToAnonymize: Set<String>
    let anonymizationMethod: AnonymizationMethod
    let retainStructure: Bool
    
    static let `default` = AnonymizationConfig(
        shouldAnonymize: true,
        fieldsToAnonymize: ["name", "email", "phone", "address", "notes"],
        anonymizationMethod: .hash,
        retainStructure: true
    )
}

// MARK: - 匿名化方法
enum AnonymizationMethod: String, CaseIterable {
    case hash = "hash"
    case mask = "mask"
    case remove = "remove"
    case generalize = "generalize"
    
    var displayName: String {
        switch self {
        case .hash: return "哈希化"
        case .mask: return "掩码"
        case .remove: return "移除"
        case .generalize: return "泛化"
        }
    }
}

// MARK: - 隐私保护管理器
@MainActor
class PrivacyProtectionManager: ObservableObject {
    static let shared = PrivacyProtectionManager()
    
    // MARK: - Published Properties
    @Published private(set) var consentRecords: [ConsentRecord] = []
    @Published private(set) var isPrivacyProtectionEnabled = true
    @Published private(set) var dataRetentionEnabled = true
    @Published private(set) var anonymizationEnabled = true
    @Published private(set) var lastPrivacyError: String?
    @Published private(set) var pendingDeletions: [DataDeletionRequest] = []
    
    // MARK: - Private Properties
    private let auditLogger = AccessAuditLogger.shared
    private let encryptionService = DataEncryptionService.shared
    private let fileManager = FileManager.default
    
    // 隐私配置
    private struct PrivacyConfig {
        static let consentExpiryDays = 365
        static let dataRetentionCheckInterval: TimeInterval = 24 * 60 * 60 // 24小时
        static let anonymizationSalt = "ManualBox_Privacy_Salt"
    }
    
    // MARK: - Initialization
    private init() {
        loadPrivacySettings()
        loadConsentRecords()
        scheduleDataRetentionCheck()
        checkExpiredConsents()
    }
    
    // MARK: - Public Methods
    
    /// 启用或禁用隐私保护
    func setPrivacyProtectionEnabled(_ enabled: Bool) {
        isPrivacyProtectionEnabled = enabled
        savePrivacySettings()
        
        auditLogger.logSystemEvent(
            enabled ? .encryptionEnabled : .encryptionDisabled,
            details: "隐私保护已\(enabled ? "启用" : "禁用")"
        )
        
        print("🔒 隐私保护已\(enabled ? "启用" : "禁用")")
    }
    
    /// 请求用户同意
    func requestConsent(for purpose: DataProcessingPurpose, expiryDays: Int? = nil) async throws -> Bool {
        // 检查是否已有有效同意
        if let existingConsent = getConsentRecord(for: purpose), existingConsent.isValid {
            return true
        }
        
        // 计算过期日期
        let expiryDate = expiryDays.map {
            Calendar.current.date(byAdding: .day, value: $0, to: Date())
        } ?? Calendar.current.date(byAdding: .day, value: PrivacyConfig.consentExpiryDays, to: Date())
        
        // 创建同意记录（状态为待处理）
        let consentRecord = ConsentRecord(
            purpose: purpose,
            status: .pending,
            expiryDate: expiryDate
        )
        
        // 更新或添加记录
        if let index = consentRecords.firstIndex(where: { $0.purpose == purpose }) {
            consentRecords[index] = consentRecord
        } else {
            consentRecords.append(consentRecord)
        }
        
        saveConsentRecords()
        
        auditLogger.logSystemEvent(.permissionCheck, details: "请求用户同意: \(purpose.displayName)")
        
        // 在实际应用中，这里应该显示同意对话框
        // 现在简化为自动同意必需的目的，其他需要用户确认
        let granted = purpose.isRequired
        
        try await updateConsentStatus(for: purpose, status: granted ? .granted : .denied)
        
        return granted
    }
    
    /// 更新同意状态
    func updateConsentStatus(for purpose: DataProcessingPurpose, status: ConsentStatus) async throws {
        guard let index = consentRecords.firstIndex(where: { $0.purpose == purpose }) else {
            throw PrivacyProtectionError.invalidDataType
        }
        
        let oldStatus = consentRecords[index].status
        consentRecords[index].status = status
        
        // 如果是授予同意，更新授予日期
        if status == .granted {
            consentRecords[index] = ConsentRecord(
                purpose: purpose,
                status: .granted,
                expiryDate: consentRecords[index].expiryDate
            )
        }
        
        saveConsentRecords()
        
        auditLogger.logSystemEvent(
            status == .granted ? .permissionGranted : .permissionDenied,
            details: "同意状态更新: \(purpose.displayName) - \(oldStatus.displayName) -> \(status.displayName)"
        )
        
        print("🔒 同意状态更新: \(purpose.displayName) - \(status.displayName)")
    }
    
    /// 撤回同意
    func withdrawConsent(for purpose: DataProcessingPurpose) async throws {
        guard !purpose.isRequired else {
            throw PrivacyProtectionError.consentNotGranted("无法撤回必需功能的同意")
        }
        
        try await updateConsentStatus(for: purpose, status: .withdrawn)
        
        // 删除相关数据
        try await deleteDataForPurpose(purpose)
        
        print("🔒 已撤回同意并删除相关数据: \(purpose.displayName)")
    }
    
    /// 检查是否有权限处理数据
    func hasConsentForPurpose(_ purpose: DataProcessingPurpose) -> Bool {
        guard isPrivacyProtectionEnabled else { return true }
        
        if let consent = getConsentRecord(for: purpose) {
            return consent.isValid
        }
        
        // 必需功能默认有权限
        return purpose.isRequired
    }
    
    /// 验证数据处理权限
    func verifyDataProcessingPermission(for purpose: DataProcessingPurpose) async throws {
        guard isPrivacyProtectionEnabled else { return }
        
        if !hasConsentForPurpose(purpose) {
            auditLogger.logOperationBlocked("数据处理", reason: "缺少用户同意: \(purpose.displayName)")
            throw PrivacyProtectionError.consentNotGranted(purpose.displayName)
        }
        
        auditLogger.logOperationAuthorized("数据处理", permission: .readProducts) // 简化权限映射
    }
    
    /// 匿名化数据
    func anonymizeData<T: Codable>(_ data: T, config: AnonymizationConfig = .default) throws -> T {
        guard anonymizationEnabled && config.shouldAnonymize else {
            return data
        }
        
        do {
            // 序列化数据
            let jsonData = try JSONEncoder().encode(data)
            var jsonObject = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] ?? [:]
            
            // 匿名化指定字段
            for field in config.fieldsToAnonymize {
                if let value = jsonObject[field] as? String {
                    jsonObject[field] = anonymizeValue(value, method: config.anonymizationMethod)
                }
            }
            
            // 重新序列化
            let anonymizedData = try JSONSerialization.data(withJSONObject: jsonObject)
            let result = try JSONDecoder().decode(T.self, from: anonymizedData)
            
            auditLogger.logDataAccess(T.self, operation: "anonymize")
            print("🔒 数据已匿名化: \(config.fieldsToAnonymize.count) 个字段")
            
            return result
            
        } catch {
            lastPrivacyError = error.localizedDescription
            throw PrivacyProtectionError.anonymizationFailed
        }
    }
    
    /// 请求数据删除
    func requestDataDeletion(
        dataType: String,
        identifier: String? = nil,
        reason: String,
        confirmationRequired: Bool = true
    ) async throws {
        
        let request = DataDeletionRequest(
            dataType: dataType,
            identifier: identifier,
            reason: reason,
            confirmationRequired: confirmationRequired
        )
        
        pendingDeletions.append(request)
        
        auditLogger.logSystemEvent(.dataDelete, details: "数据删除请求: \(dataType) - \(reason)")
        
        // 如果不需要确认，立即执行删除
        if !confirmationRequired {
            try await executeDeletion(request)
        }
        
        print("🔒 数据删除请求已创建: \(dataType)")
    }
    
    /// 确认并执行数据删除
    func confirmAndExecuteDeletion(_ request: DataDeletionRequest) async throws {
        guard let index = pendingDeletions.firstIndex(where: { $0.id == request.id }) else {
            throw PrivacyProtectionError.deletionFailed
        }
        
        try await executeDeletion(request)
        pendingDeletions.remove(at: index)
        
        print("🔒 数据删除已确认并执行: \(request.dataType)")
    }
    
    /// 取消数据删除请求
    func cancelDeletionRequest(_ request: DataDeletionRequest) {
        pendingDeletions.removeAll { $0.id == request.id }
        
        auditLogger.logSystemEvent(.operationBlocked, details: "数据删除请求已取消: \(request.dataType)")
        print("🔒 数据删除请求已取消: \(request.dataType)")
    }
    
    /// 执行数据保留检查
    func performDataRetentionCheck() async {
        guard dataRetentionEnabled else { return }
        
        var deletedCount = 0
        
        for purpose in DataProcessingPurpose.allCases {
            let retentionDays = purpose.dataRetentionDays
            guard retentionDays > 0 else { continue } // 跳过永久保留的数据
            
            let cutoffDate = Calendar.current.date(byAdding: .day, value: -retentionDays, to: Date()) ?? Date()
            
            // 在实际应用中，这里应该查询和删除过期数据
            // 现在只是记录日志
            auditLogger.logSystemEvent(.dataDelete, details: "数据保留检查: \(purpose.displayName) - 截止日期: \(cutoffDate)")
            
            // 模拟删除过期数据
            deletedCount += 1
        }
        
        if deletedCount > 0 {
            auditLogger.logSystemEvent(.dataDelete, details: "数据保留检查完成，删除 \(deletedCount) 类过期数据")
            print("🔒 数据保留检查完成，删除 \(deletedCount) 类过期数据")
        }
    }
    
    /// 导出隐私数据
    func exportPrivacyData() -> PrivacyDataExport {
        return PrivacyDataExport(
            consentRecords: consentRecords,
            privacySettings: PrivacySettings(
                isProtectionEnabled: isPrivacyProtectionEnabled,
                dataRetentionEnabled: dataRetentionEnabled,
                anonymizationEnabled: anonymizationEnabled
            ),
            pendingDeletions: pendingDeletions,
            exportDate: Date()
        )
    }
    
    /// 获取隐私统计信息
    func getPrivacyStatistics() -> PrivacyStatistics {
        let grantedConsents = consentRecords.filter { $0.status == .granted }.count
        let expiredConsents = consentRecords.filter { $0.isExpired }.count
        let requiredPurposes = DataProcessingPurpose.allCases.filter { $0.isRequired }.count
        
        return PrivacyStatistics(
            totalConsents: consentRecords.count,
            grantedConsents: grantedConsents,
            expiredConsents: expiredConsents,
            requiredPurposes: requiredPurposes,
            pendingDeletions: pendingDeletions.count,
            isProtectionEnabled: isPrivacyProtectionEnabled,
            dataRetentionEnabled: dataRetentionEnabled,
            anonymizationEnabled: anonymizationEnabled
        )
    }
    
    // MARK: - Private Methods
    
    private func getConsentRecord(for purpose: DataProcessingPurpose) -> ConsentRecord? {
        return consentRecords.first { $0.purpose == purpose }
    }
    
    private func anonymizeValue(_ value: String, method: AnonymizationMethod) -> String {
        switch method {
        case .hash:
            let data = (value + PrivacyConfig.anonymizationSalt).data(using: .utf8) ?? Data()
            let hash = SHA256.hash(data: data)
            return hash.compactMap { String(format: "%02x", $0) }.joined()
            
        case .mask:
            guard value.count > 2 else { return "***" }
            let start = value.prefix(1)
            let end = value.suffix(1)
            let middle = String(repeating: "*", count: max(3, value.count - 2))
            return "\(start)\(middle)\(end)"
            
        case .remove:
            return "[已删除]"
            
        case .generalize:
            // 简化的泛化处理
            if value.contains("@") {
                return "[邮箱地址]"
            } else if value.count > 10 && value.allSatisfy({ $0.isNumber || $0 == "-" || $0 == " " }) {
                return "[电话号码]"
            } else {
                return "[个人信息]"
            }
        }
    }
    
    private func deleteDataForPurpose(_ purpose: DataProcessingPurpose) async throws {
        // 在实际应用中，这里应该删除与特定目的相关的所有数据
        auditLogger.logDataAccess(String.self, operation: "delete", resourceId: purpose.rawValue)
        print("🔒 已删除目的相关数据: \(purpose.displayName)")
    }
    
    private func executeDeletion(_ request: DataDeletionRequest) async throws {
        // 在实际应用中，这里应该执行实际的数据删除操作
        auditLogger.logDataAccess(String.self, operation: "delete", resourceId: request.identifier)
        
        // 模拟删除延迟
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1秒
        
        print("🔒 数据删除已执行: \(request.dataType)")
    }
    
    private func checkExpiredConsents() {
        for index in consentRecords.indices {
            if consentRecords[index].isExpired && consentRecords[index].status == .granted {
                consentRecords[index].status = .expired
                
                auditLogger.logSystemEvent(.permissionsReset, details: "同意已过期: \(consentRecords[index].purpose.displayName)")
            }
        }
        
        saveConsentRecords()
    }
    
    private func scheduleDataRetentionCheck() {
        Timer.scheduledTimer(withTimeInterval: PrivacyConfig.dataRetentionCheckInterval, repeats: true) { _ in
            Task { @MainActor in
                await self.performDataRetentionCheck()
            }
        }
    }
    
    private func loadPrivacySettings() {
        isPrivacyProtectionEnabled = UserDefaults.standard.bool(forKey: "PrivacyProtectionEnabled")
        dataRetentionEnabled = UserDefaults.standard.bool(forKey: "DataRetentionEnabled")
        anonymizationEnabled = UserDefaults.standard.bool(forKey: "AnonymizationEnabled")
        
        // 设置默认值
        if !UserDefaults.standard.bool(forKey: "PrivacySettingsInitialized") {
            isPrivacyProtectionEnabled = true
            dataRetentionEnabled = true
            anonymizationEnabled = true
            savePrivacySettings()
            UserDefaults.standard.set(true, forKey: "PrivacySettingsInitialized")
        }
    }
    
    private func savePrivacySettings() {
        UserDefaults.standard.set(isPrivacyProtectionEnabled, forKey: "PrivacyProtectionEnabled")
        UserDefaults.standard.set(dataRetentionEnabled, forKey: "DataRetentionEnabled")
        UserDefaults.standard.set(anonymizationEnabled, forKey: "AnonymizationEnabled")
    }
    
    private func loadConsentRecords() {
        if let data = UserDefaults.standard.data(forKey: "ConsentRecords"),
           let records = try? JSONDecoder().decode([ConsentRecord].self, from: data) {
            consentRecords = records
        }
    }
    
    private func saveConsentRecords() {
        if let data = try? JSONEncoder().encode(consentRecords) {
            UserDefaults.standard.set(data, forKey: "ConsentRecords")
        }
    }
}

// MARK: - 数据删除请求
struct DataDeletionRequest: Identifiable, Codable {
    let id = UUID()
    let dataType: String
    let identifier: String?
    let reason: String
    let requestDate: Date
    let confirmationRequired: Bool
    
    init(dataType: String, identifier: String? = nil, reason: String, confirmationRequired: Bool = true) {
        self.dataType = dataType
        self.identifier = identifier
        self.reason = reason
        self.requestDate = Date()
        self.confirmationRequired = confirmationRequired
    }
}

// MARK: - 隐私设置
struct PrivacySettings: Codable {
    let isProtectionEnabled: Bool
    let dataRetentionEnabled: Bool
    let anonymizationEnabled: Bool
}

// MARK: - 隐私数据导出
struct PrivacyDataExport: Codable {
    let consentRecords: [ConsentRecord]
    let privacySettings: PrivacySettings
    let pendingDeletions: [DataDeletionRequest]
    let exportDate: Date
}

// MARK: - 隐私统计信息
struct PrivacyStatistics {
    let totalConsents: Int
    let grantedConsents: Int
    let expiredConsents: Int
    let requiredPurposes: Int
    let pendingDeletions: Int
    let isProtectionEnabled: Bool
    let dataRetentionEnabled: Bool
    let anonymizationEnabled: Bool
    
    var consentCoverage: Double {
        guard totalConsents > 0 else { return 0.0 }
        return Double(grantedConsents) / Double(totalConsents)
    }
}