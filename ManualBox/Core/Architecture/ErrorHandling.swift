//
//  ErrorHandling.swift
//  ManualBox
//
//  Created by Assistant on 2025/6/21.
//

import Foundation
import SwiftUI
import CoreData
import CloudKit

// MARK: - 错误处理协议
@MainActor
protocol ErrorHandling {
    func handleError(_ error: Error, context: String)
    func showUserFriendlyError(_ message: String)
}

// MARK: - 错误映射器
struct ErrorMessageMapper {
    
    static func map(_ error: Error, context: String) -> String {
        switch error {
        // Core Data 错误
        case let nsError as NSError where nsError.domain == NSCocoaErrorDomain:
            return mapCoreDataError(nsError, context: context)
            
        // CloudKit 错误
        case let ckError as CKError:
            return mapCloudKitError(ckError, context: context)
            
        // 网络错误
        case let urlError as URLError:
            return mapNetworkError(urlError, context: context)
            
        // 文件系统错误
        case let posixError as POSIXError:
            return mapFileSystemError(posixError, context: context)
            
        // 自定义错误
        case let appError as LocalizedError:
            return appError.localizedDescription
            
        default:
            return mapGenericError(error, context: context)
        }
    }
    
    private static func mapCoreDataError(_ error: NSError, context: String) -> String {
        switch error.code {
        case NSValidationMissingMandatoryPropertyError:
            return "缺少必填信息，请检查输入内容"
        case NSValidationRelationshipLacksMinimumCountError:
            return "关联数据不完整，请检查相关设置"
        case NSValidationStringTooLongError:
            return "输入内容过长，请缩短后重试"
        case NSManagedObjectContextLockingError:
            return "数据正在处理中，请稍后重试"
        case NSPersistentStoreIncompatibleVersionHashError:
            return "数据格式需要更新，请重启应用"
        case NSMigrationMissingSourceModelError:
            return "数据迁移失败，可能需要重新安装应用"
        default:
            return "数据操作失败：\(error.localizedDescription)"
        }
    }
    
    private static func mapCloudKitError(_ error: CKError, context: String) -> String {
        switch error.code {
        case .networkUnavailable, .networkFailure:
            return "网络连接不可用，请检查网络设置"
        case .notAuthenticated:
            return "请登录 iCloud 账户以同步数据"
        case .quotaExceeded:
            return "iCloud 存储空间不足，请清理后重试"
        case .zoneBusy:
            return "iCloud 同步繁忙，请稍后重试"
        case .serviceUnavailable:
            return "iCloud 服务暂时不可用，请稍后重试"
        case .requestRateLimited:
            return "同步请求过于频繁，请稍后重试"
        case .limitExceeded:
            return "数据大小超出限制，请减少内容后重试"
        case .unknownItem:
            return "数据已被删除或不存在"
        case .invalidArguments:
            return "数据格式错误，请检查输入内容"
        case .permissionFailure:
            return "没有权限访问 iCloud 数据"
        default:
            return "iCloud 同步失败：\(error.localizedDescription)"
        }
    }
    
    private static func mapNetworkError(_ error: URLError, context: String) -> String {
        switch error.code {
        case .notConnectedToInternet:
            return "网络连接不可用，请检查网络设置"
        case .timedOut:
            return "网络请求超时，请重试"
        case .cannotFindHost:
            return "无法连接到服务器，请检查网络"
        case .cannotConnectToHost:
            return "服务器连接失败，请稍后重试"
        case .networkConnectionLost:
            return "网络连接中断，请重新连接"
        case .dnsLookupFailed:
            return "域名解析失败，请检查网络设置"
        case .httpTooManyRedirects:
            return "服务器响应异常，请稍后重试"
        case .resourceUnavailable:
            return "请求的资源不可用"
        case .notConnectedToInternet:
            return "设备未连接到互联网"
        default:
            return "网络请求失败：\(error.localizedDescription)"
        }
    }
    
    private static func mapFileSystemError(_ error: POSIXError, context: String) -> String {
        switch error.code {
        case .ENOENT:
            return "文件不存在或已被删除"
        case .EACCES:
            return "没有权限访问文件"
        case .ENOSPC:
            return "存储空间不足，请清理后重试"
        case .EROFS:
            return "文件系统为只读状态"
        case .EEXIST:
            return "文件已存在"
        case .EISDIR:
            return "目标是文件夹而非文件"
        case .ENOTDIR:
            return "路径中包含非文件夹项"
        default:
            return "文件操作失败：\(error.localizedDescription)"
        }
    }
    
    private static func mapGenericError(_ error: Error, context: String) -> String {
        let description = error.localizedDescription
        
        // 根据上下文提供更具体的错误信息
        switch context.lowercased() {
        case let ctx where ctx.contains("ocr"):
            return "文字识别失败：\(description)"
        case let ctx where ctx.contains("export"):
            return "数据导出失败：\(description)"
        case let ctx where ctx.contains("import"):
            return "数据导入失败：\(description)"
        case let ctx where ctx.contains("image"):
            return "图片处理失败：\(description)"
        case let ctx where ctx.contains("save"):
            return "保存失败：\(description)"
        case let ctx where ctx.contains("delete"):
            return "删除失败：\(description)"
        case let ctx where ctx.contains("sync"):
            return "同步失败：\(description)"
        default:
            return "操作失败：\(description)"
        }
    }
}

// MARK: - 错误日志记录器
class ErrorLogger {
    static let shared = ErrorLogger()
    
    private let logQueue = DispatchQueue(label: "com.manualbox.errorlogger", qos: .utility)
    private let maxLogEntries = 1000
    private var logEntries: [ErrorLogEntry] = []
    
    private init() {}
    
    struct ErrorLogEntry {
        let timestamp: Date
        let context: String
        let error: String
        let severity: AppError.ErrorSeverity
        let stackTrace: String?
    }
    
    func log(_ error: Error, context: String, severity: AppError.ErrorSeverity = .error) {
        logQueue.async {
            let entry = ErrorLogEntry(
                timestamp: Date(),
                context: context,
                error: String(describing: error),
                severity: severity,
                stackTrace: Thread.callStackSymbols.joined(separator: "\n")
            )
            
            self.logEntries.append(entry)
            
            // 限制日志条目数量
            if self.logEntries.count > self.maxLogEntries {
                self.logEntries.removeFirst(self.logEntries.count - self.maxLogEntries)
            }
            
            // 打印到控制台
            print("🚨 [ErrorLogger] [\(severity.rawValue)] \(context): \(error)")
            
            // 在调试模式下打印堆栈跟踪
            #if DEBUG
            if severity == .critical {
                print("Stack trace:\n\(entry.stackTrace ?? "N/A")")
            }
            #endif
        }
    }
    
    func getRecentLogs(limit: Int = 50) -> [ErrorLogEntry] {
        return logQueue.sync {
            return Array(logEntries.suffix(limit))
        }
    }
    
    func clearLogs() {
        logQueue.async {
            self.logEntries.removeAll()
        }
    }
    
    func exportLogs() -> String {
        return logQueue.sync {
            return logEntries.map { entry in
                "[\(entry.timestamp)] [\(entry.severity.rawValue)] \(entry.context): \(entry.error)"
            }.joined(separator: "\n")
        }
    }
}

// MARK: - BaseViewModel 错误处理扩展
extension BaseViewModel: ErrorHandling {
    func handleError(_ error: Error, context: String) {
        let userMessage = ErrorMessageMapper.map(error, context: context)
        setError(userMessage)
        
        // 记录错误日志
        ErrorLogger.shared.log(error, context: context)
        
        // 发布错误事件
        EventBus.shared.publishError(error, context: context)
        
        // 更新全局状态
        AppStateManager.shared.handleError(error, context: context)
    }
    
    func showUserFriendlyError(_ message: String) {
        setError(message)
        
        // 发布用户友好错误事件
        let customError = NSError(domain: "UserFriendlyError", code: 0, userInfo: [NSLocalizedDescriptionKey: message])
        EventBus.shared.publishError(customError, context: "用户界面")
    }
}

// MARK: - 错误恢复策略
enum ErrorRecoveryStrategy {
    case retry
    case fallback
    case userIntervention
    case ignore
    case restart
}

struct ErrorRecoveryAction {
    let strategy: ErrorRecoveryStrategy
    let description: String
    let action: () async -> Void
}

class ErrorRecoveryManager {
    static let shared = ErrorRecoveryManager()
    
    private init() {}
    
    func getRecoveryActions(for error: Error, context: String) -> [ErrorRecoveryAction] {
        var actions: [ErrorRecoveryAction] = []
        
        switch error {
        case let ckError as CKError:
            actions.append(contentsOf: getCloudKitRecoveryActions(ckError))
        case let urlError as URLError:
            actions.append(contentsOf: getNetworkRecoveryActions(urlError))
        default:
            actions.append(getGenericRecoveryAction())
        }
        
        return actions
    }
    
    private func getCloudKitRecoveryActions(_ error: CKError) -> [ErrorRecoveryAction] {
        switch error.code {
        case .networkUnavailable, .networkFailure:
            return [
                ErrorRecoveryAction(
                    strategy: .retry,
                    description: "重试同步",
                    action: { /* 重试同步逻辑 */ }
                )
            ]
        case .quotaExceeded:
            return [
                ErrorRecoveryAction(
                    strategy: .userIntervention,
                    description: "清理 iCloud 存储空间",
                    action: { /* 打开设置页面 */ }
                )
            ]
        default:
            return []
        }
    }
    
    private func getNetworkRecoveryActions(_ error: URLError) -> [ErrorRecoveryAction] {
        return [
            ErrorRecoveryAction(
                strategy: .retry,
                description: "重试网络请求",
                action: { /* 重试网络请求 */ }
            )
        ]
    }
    
    private func getGenericRecoveryAction() -> ErrorRecoveryAction {
        return ErrorRecoveryAction(
            strategy: .retry,
            description: "重试操作",
            action: { /* 通用重试逻辑 */ }
        )
    }
}
