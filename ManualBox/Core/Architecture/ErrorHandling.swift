//
//  ErrorHandling.swift
//  ManualBox
//
//  Created by Assistant on 2024/12/19.
//  应用错误处理定义
//

import Foundation
import Combine
import os.log

// 导入共享错误类型以避免重复定义
// ErrorContext, RecoveryResult, ErrorHandlingResult 现在从 SharedErrorTypes.swift 导入

// MARK: - 日志系统
private enum Logger {
    static func error(_ message: String) {
        os_log(.error, log: OSLog(subsystem: "com.manualbox.app", category: "ErrorHandling"), "%{public}@", message)
    }
    
    static func warning(_ message: String) {
        os_log(.info, log: OSLog(subsystem: "com.manualbox.app", category: "ErrorHandling"), "%{public}@", message)
    }
}

// MARK: - 应用错误类型
enum AppError: Error, LocalizedError {
    case network(NetworkError)
    case persistence(PersistenceError)
    case system(SystemError)
    case sync(SyncError)
    case validation(ValidationError)
    case business(BusinessError)
    
    // MARK: - 便利属性
    var message: String {
        return errorDescription ?? "未知错误"
    }
    
    var context: String {
        return "AppError"
    }
    
    // MARK: - 网络错误
    enum NetworkError {
        case noConnection
        case timeout
        case requestFailed(String)
        case invalidResponse
        case serverError(Int)
    }
    
    // MARK: - 持久化错误
    enum PersistenceError {
        case saveFailed(String)
        case loadFailed(String)
        case deleteFailed(String)
        case migrationFailed(String)
        case corruptedData
    }
    
    // MARK: - 系统错误
    enum SystemError {
        case memoryWarning
        case diskSpaceLow
        case permissionDenied
        case systemResourceUnavailable
        case unknown(String)
    }
    
    // MARK: - 同步错误
    enum SyncError {
        case conflictDetected
        case syncInProgress
        case cloudKitUnavailable
        case accountNotAvailable
    }
    
    // MARK: - 验证错误
    enum ValidationError {
        case invalidInput(String)
        case missingRequiredField(String)
        case formatError(String)
    }
    
    // MARK: - 业务逻辑错误
    enum BusinessError {
        case operationNotAllowed
        case resourceNotFound
        case duplicateResource
        case quotaExceeded
    }
    
    // MARK: - 错误严重程度
    enum ErrorSeverity: String, CaseIterable {
        case info
        case warning
        case error
        case critical
        
        var displayName: String {
            switch self {
            case .info: return "信息"
            case .warning: return "警告"
            case .error: return "错误"
            case .critical: return "严重"
            }
        }
    }
    
    // MARK: - 错误严重程度属性
    var severity: ErrorSeverity {
        switch self {
        case .network(.noConnection), .network(.timeout):
            return .warning
        case .network(.requestFailed), .network(.invalidResponse):
            return .error
        case .network(.serverError):
            return .critical
        case .persistence(.saveFailed), .persistence(.loadFailed), .persistence(.deleteFailed):
            return .error
        case .persistence(.corruptedData), .persistence(.migrationFailed):
            return .critical
        case .system(.memoryWarning), .system(.diskSpaceLow):
            return .warning
        case .system(.permissionDenied), .system(.systemResourceUnavailable):
            return .error
        case .system(.unknown):
            return .error
        case .sync(.syncInProgress):
            return .info
        case .sync(.conflictDetected), .sync(.cloudKitUnavailable):
            return .warning
        case .sync(.accountNotAvailable):
            return .error
        case .validation:
            return .warning
        case .business(.operationNotAllowed), .business(.resourceNotFound):
            return .error
        case .business(.duplicateResource):
            return .warning
        case .business(.quotaExceeded):
            return .critical
        }
    }
    
    // MARK: - 错误描述
    var errorDescription: String? {
        switch self {
        case .network(let networkError):
            return networkErrorDescription(networkError)
        case .persistence(let persistenceError):
            return persistenceErrorDescription(persistenceError)
        case .system(let systemError):
            return systemErrorDescription(systemError)
        case .sync(let syncError):
            return syncErrorDescription(syncError)
        case .validation(let validationError):
            return validationErrorDescription(validationError)
        case .business(let businessError):
            return businessErrorDescription(businessError)
        }
    }
    
    // MARK: - 私有错误描述方法
    private func networkErrorDescription(_ error: NetworkError) -> String {
        switch error {
        case .noConnection:
            return "网络连接不可用"
        case .timeout:
            return "网络请求超时"
        case .requestFailed(let message):
            return "网络请求失败: \(message)"
        case .invalidResponse:
            return "服务器响应无效"
        case .serverError(let code):
            return "服务器错误 (\(code))"
        }
    }
    
    private func persistenceErrorDescription(_ error: PersistenceError) -> String {
        switch error {
        case .saveFailed(let message):
            return "保存失败: \(message)"
        case .loadFailed(let message):
            return "加载失败: \(message)"
        case .deleteFailed(let message):
            return "删除失败: \(message)"
        case .migrationFailed(let message):
            return "数据迁移失败: \(message)"
        case .corruptedData:
            return "数据已损坏"
        }
    }
    
    private func systemErrorDescription(_ error: SystemError) -> String {
        switch error {
        case .memoryWarning:
            return "内存不足警告"
        case .diskSpaceLow:
            return "磁盘空间不足"
        case .permissionDenied:
            return "权限被拒绝"
        case .systemResourceUnavailable:
            return "系统资源不可用"
        case .unknown(let message):
            return "未知系统错误: \(message)"
        }
    }
    
    private func syncErrorDescription(_ error: SyncError) -> String {
        switch error {
        case .conflictDetected:
            return "检测到同步冲突"
        case .syncInProgress:
            return "同步正在进行中"
        case .cloudKitUnavailable:
            return "CloudKit 服务不可用"
        case .accountNotAvailable:
            return "iCloud 账户不可用"
        }
    }
    
    private func validationErrorDescription(_ error: ValidationError) -> String {
        switch error {
        case .invalidInput(let field):
            return "输入无效: \(field)"
        case .missingRequiredField(let field):
            return "缺少必填字段: \(field)"
        case .formatError(let message):
            return "格式错误: \(message)"
        }
    }
    
    private func businessErrorDescription(_ error: BusinessError) -> String {
        switch error {
        case .operationNotAllowed:
            return "操作不被允许"
        case .resourceNotFound:
            return "资源未找到"
        case .duplicateResource:
            return "资源重复"
        case .quotaExceeded:
            return "配额已超出"
        }
    }
}

// MARK: - 错误上下文
// 注意：ErrorContext 已移动到 SharedErrorTypes.swift 以避免重复定义

// MARK: - 错误处理结果
// 注意：ErrorHandlingResult 已移动到 SharedErrorTypes.swift 以避免重复定义

// MARK: - 统一错误处理器协议
@MainActor
protocol UnifiedErrorHandler {
    func processError(_ error: Error, context: ErrorContext) -> ErrorHandlingResult
    func canHandle(_ error: Error) -> Bool
    func registerErrorHandler(
        for errorType: Error.Type,
        handler: @escaping (Error, ErrorContext) -> ErrorHandlingResult
    )
}

// MARK: - 错误恢复管理器协议
@MainActor
protocol ErrorRecoveryManager {
    func canRecover(from error: Error) -> Bool
    func recover(from error: Error) async -> RecoveryResult
    func registerRecoveryStrategy(for errorType: Error.Type, strategy: @escaping (Error) -> RecoveryResult)
}

// MARK: - 恢复结果
// 注意：RecoveryResult 已移动到 SharedErrorTypes.swift 以避免重复定义

// MARK: - 统一错误处理器实现
@MainActor
class UnifiedErrorHandlerImpl: UnifiedErrorHandler {
    static let shared = UnifiedErrorHandlerImpl()
    
    private var errorHandlers: [String: (Error, ErrorContext) -> ErrorHandlingResult] = [:]
    
    private init() {
        setupDefaultHandlers()
    }
    
    func processError(_ error: Error, context: ErrorContext) -> ErrorHandlingResult {
        let errorTypeName = String(describing: type(of: error))
        
        if let handler = errorHandlers[errorTypeName] {
            return handler(error, context)
        }
        
        // 默认处理逻辑
        return handleDefaultError(error, context: context)
    }
    
    func canHandle(_ error: Error) -> Bool {
        let errorTypeName = String(describing: type(of: error))
        return errorHandlers[errorTypeName] != nil
    }
    
    func registerErrorHandler(
        for errorType: Error.Type,
        handler: @escaping (Error, ErrorContext) -> ErrorHandlingResult
    ) {
        let typeName = String(describing: errorType)
        errorHandlers[typeName] = handler
    }
    
    private func setupDefaultHandlers() {
        // 网络错误处理
        registerErrorHandler(for: AppError.self) { error, _ in
            if let appError = error as? AppError {
                switch appError {
                case .network(.noConnection), .network(.timeout):
                    return .retry(after: 5.0)
                case .network(.serverError):
                    return .escalated
                default:
                    return .handled
                }
            }
            return .handled
        }
    }
    
    private func handleDefaultError(_ error: Error, context: ErrorContext) -> ErrorHandlingResult {
        // 使用日志系统替代print语句
        Logger.error("未处理的错误: \(error.localizedDescription) in \(context.operation)")
        return .handled
    }
}

// MARK: - 错误恢复管理器实现
@MainActor
class ManualBoxErrorRecoveryManager: ErrorRecoveryManager {
    static let shared = ManualBoxErrorRecoveryManager()
    
    private var recoveryStrategies: [String: (Error) async -> RecoveryResult] = [:]
    
    private init() {
        setupDefaultStrategies()
    }
    
    func canRecover(from error: Error) -> Bool {
        let errorTypeName = String(describing: type(of: error))
        return recoveryStrategies[errorTypeName] != nil
    }
    
    func recover(from error: Error) async -> RecoveryResult {
        let errorTypeName = String(describing: type(of: error))
        
        if let strategy = recoveryStrategies[errorTypeName] {
            return await strategy(error)
        }
        
        return .failed(AppError.system(.unknown("无可用的恢复策略")))
    }
    
    func registerRecoveryStrategy(for errorType: Error.Type, strategy: @escaping (Error) -> RecoveryResult) {
        let typeName = String(describing: errorType)
        recoveryStrategies[typeName] = { await strategy($0) }
    }
    
    private func setupDefaultStrategies() {
        // 网络错误恢复策略
        registerRecoveryStrategy(for: AppError.self) { [weak self] error in
            guard self != nil else { return .failed(error) }
            
            if let appError = error as? AppError {
                switch appError {
                case .network(.noConnection):
                    // 等待网络恢复
                    return .retryLater(10.0)
                case .sync(.conflictDetected):
                    // 同步冲突需要用户干预
                    return .userInterventionRequired("检测到同步冲突，请选择解决方案")
                default:
                    return .failed(appError)
                }
            }
            return .failed(error)
        }
    }
}
