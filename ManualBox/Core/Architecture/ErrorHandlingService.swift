//
//  ErrorHandlingService.swift
//  ManualBox
//
//  Created by AI Assistant on 2025/7/22.
//

import Foundation
import SwiftUI
import CloudKit
#if canImport(AppKit)
import AppKit
#endif
import Combine

// MARK: - 错误处理服务协议
@MainActor
protocol ErrorHandlingService {
    func handleError<T>(_ operation: () async throws -> T) async -> Result<T, AppError>
    func handleErrorWithRecovery<T>(_ operation: () async throws -> T, recovery: () async -> T?) async -> T?
    func handleErrorWithUI<T>(_ operation: () async throws -> T, showAlert: Bool) async -> Result<T, AppError>
    func registerGlobalErrorHandler(_ handler: @escaping (Error, String) -> Void)
    func showErrorAlert(_ error: AppError, in window: NSWindow?)
}

// MARK: - 错误处理服务实现
@MainActor
class ManualBoxErrorHandlingService: ErrorHandlingService, ObservableObject {
    static let shared = ManualBoxErrorHandlingService()
    
    @Published var currentError: AppError?
    @Published var isShowingError = false
    
    private let unifiedHandler: UnifiedErrorHandler
    private let recoveryManager: ErrorRecoveryManager
    private let appStateManager: AppStateManager
    private let eventBus: EventBus
    
    private var globalErrorHandlers: [(Error, String) -> Void] = []
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        self.unifiedHandler = UnifiedErrorHandlerImpl.shared
        self.recoveryManager = ManualBoxErrorRecoveryManager.shared
        self.appStateManager = AppStateManager.shared
        self.eventBus = EventBus.shared
        
        setupErrorMonitoring()
    }
    
    // MARK: - 核心错误处理方法
    
    func handleError<T>(_ operation: () async throws -> T) async -> Result<T, AppError> {
        do {
            let result = try await operation()
            return .success(result)
        } catch {
            let context = ErrorContext(operation: "async_operation")
            let handlingResult = unifiedHandler.processError(error, context: context)
            
            if let appError = error as? AppError {
                return .failure(appError)
            } else {
                return .failure(mapToAppError(error))
            }
        }
    }
    
    func handleErrorWithRecovery<T>(_ operation: () async throws -> T, recovery: () async -> T?) async -> T? {
        do {
            return try await operation()
        } catch {
            let context = ErrorContext(operation: "async_operation_with_recovery")
            let handlingResult = unifiedHandler.processError(error, context: context)
            
            // 尝试自动恢复
            if recoveryManager.canRecover(from: error) {
                let recoveryResult = await recoveryManager.recover(from: error)
                
                switch recoveryResult {
                case .success:
                    // 恢复成功，重试操作
                    do {
                        return try await operation()
                    } catch {
                        // 重试失败，执行手动恢复
                        return await recovery()
                    }
                case .retryLater:
                    // 稍后重试
                    try? await Task.sleep(nanoseconds: 1_000_000_000) // 1秒
                    do {
                        return try await operation()
                    } catch {
                        return await recovery()
                    }
                default:
                    // 其他情况执行手动恢复
                    return await recovery()
                }
            } else {
                return await recovery()
            }
        }
    }
    
    func handleErrorWithUI<T>(_ operation: () async throws -> T, showAlert: Bool = true) async -> Result<T, AppError> {
        let result = await handleError(operation)
        
        if case .failure(let error) = result, showAlert {
            await showError(error)
        }
        
        return result
    }
    
    func registerGlobalErrorHandler(_ handler: @escaping (Error, String) -> Void) {
        globalErrorHandlers.append(handler)
    }
    
    func showErrorAlert(_ error: AppError, in window: NSWindow?) {
        let alert = createErrorAlert(for: error)
        
        if let window = window {
            alert.beginSheetModal(for: window)
        } else {
            // 在主窗口中显示
            if let mainWindow = NSApplication.shared.mainWindow {
                alert.beginSheetModal(for: mainWindow)
            } else {
                alert.runModal()
            }
        }
    }
    
    // 便利方法：使用默认窗口
    func showErrorAlert(_ error: AppError) {
        showErrorAlert(error, in: nil)
    }
    
    // MARK: - 内部错误处理方法
    
    private func showError(_ error: AppError) async {
        currentError = error
        isShowingError = true
        
        // 通知全局错误处理器
        for handler in globalErrorHandlers {
            handler(error, "UI_Error")
        }
        
        // 更新应用状态
        appStateManager.handleError(error, context: "ErrorHandlingService")
    }
    
    private func mapToAppError(_ error: Error) -> AppError {
        switch error {
        case let appError as AppError:
            return appError
        case let ckError as CKError:
            return .sync(mapCloudKitError(ckError))
        case let urlError as URLError:
            return .network(mapURLError(urlError))
        case let nsError as NSError where nsError.domain == NSCocoaErrorDomain:
            return .persistence(mapCoreDataError(nsError))
        default:
            return .system(.systemResourceUnavailable)
        }
    }
    
    private func mapCloudKitError(_ error: CKError) -> SyncError {
        switch error.code {
        case .networkUnavailable, .networkFailure:
            return .networkUnavailable
        case .quotaExceeded:
            return .quotaExceeded
        case .notAuthenticated:
            return .authenticationFailed
        default:
            return .conflictResolutionFailed
        }
    }
    
    private func mapURLError(_ error: URLError) -> AppError.NetworkError {
        switch error.code {
        case .notConnectedToInternet:
            return .noConnection
        case .timedOut:
            return .timeout
        case .networkConnectionLost:
            return .noConnection
        default:
            return .invalidResponse
        }
    }
    
    private func mapCoreDataError(_ error: NSError) -> AppError.PersistenceError {
        switch error.code {
        case NSValidationMissingMandatoryPropertyError,
             NSValidationRelationshipLacksMinimumCountError:
            return .saveFailed("Validation error")
        case NSManagedObjectContextLockingError:
            return .saveFailed("Context locked")
        case NSPersistentStoreIncompatibleVersionHashError:
            return .migrationFailed("Version hash incompatible")
        default:
            return .loadFailed("Core Data error")
        }
    }
    
    private func createErrorAlert(for error: AppError) -> NSAlert {
        let title = getErrorTitle(for: error)
        let message = error.errorDescription ?? "发生未知错误"
        
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        
        // 添加确定按钮
        alert.addButton(withTitle: "确定")
        
        // 如果有恢复操作，添加恢复按钮
        if recoveryManager.canRecover(from: error) {
            alert.addButton(withTitle: "重试")
        }
        
        return alert
    }
    
    private func getErrorTitle(for error: AppError) -> String {
        switch error.severity {
        case .info:
            return "提示"
        case .warning:
            return "警告"
        case .error:
            return "错误"
        case .critical:
            return "严重错误"
        }
    }
    
    private func setupErrorMonitoring() {
        // 监听错误事件
        eventBus.subscribe(to: ErrorEvent.self, subscriber: ErrorEventSubscriber()) { [weak self] event in
            Task { @MainActor in
                guard let self = self else { return }
                let appError = self.mapToAppError(event.error)
                await self.showError(appError)
            }
        }
    }
}

// MARK: - 错误事件订阅者
private class ErrorEventSubscriber: EventSubscriber {
    let subscriberId = UUID()
    
    func handleEvent<T: AppEvent>(_ event: T) {
        // 事件处理在订阅时的闭包中完成
    }
}

// MARK: - SwiftUI 错误处理视图修饰符
struct ErrorHandlingModifier: ViewModifier {
    @StateObject private var errorService = ManualBoxErrorHandlingService.shared
    
    func body(content: Content) -> some View {
        content
            .alert("错误", isPresented: $errorService.isShowingError) {
                Button("确定") {
                    errorService.isShowingError = false
                    errorService.currentError = nil
                }
                
                if let error = errorService.currentError,
                   ManualBoxErrorRecoveryManager.shared.canRecover(from: error) {
                    Button("重试") {
                        Task {
                            let _ = await ManualBoxErrorRecoveryManager.shared.recover(from: error)
                            await MainActor.run {
                                errorService.isShowingError = false
                                errorService.currentError = nil
                            }
                        }
                    }
                }
            } message: {
                if let error = errorService.currentError {
                    Text(error.errorDescription ?? "发生未知错误")
                }
            }
    }
}

extension View {
    func withErrorHandling() -> some View {
        modifier(ErrorHandlingModifier())
    }
}

// MARK: - 便利扩展
extension ManualBoxErrorHandlingService {
    
    // 便利方法：处理网络请求
    func handleNetworkRequest<T>(_ request: () async throws -> T) async -> Result<T, AppError> {
        return await handleError {
            try await request()
        }
    }
    
    // 便利方法：处理数据库操作
    func handleDatabaseOperation<T>(_ operation: () async throws -> T) async -> Result<T, AppError> {
        return await handleErrorWithRecovery({
            try await operation()
        }, recovery: {
            // 数据库操作失败时的恢复逻辑
            print("数据库操作失败，尝试恢复...")
            return nil
        })
    }
    
    // 便利方法：处理文件操作
    func handleFileOperation<T>(_ operation: () async throws -> T) async -> Result<T, AppError> {
        return await handleError {
            try await operation()
        }
    }
    
    // 便利方法：处理同步操作
    func handleSyncOperation<T>(_ operation: () async throws -> T) async -> Result<T, AppError> {
        return await handleErrorWithRecovery({
            try await operation()
        }, recovery: {
            // 同步操作失败时的恢复逻辑
            print("同步操作失败，尝试离线模式...")
            return nil
        })
    }
}

// MARK: - 环境键
struct ErrorHandlingServiceKey: EnvironmentKey {
    static let defaultValue: ManualBoxErrorHandlingService = ManualBoxErrorHandlingService.shared
}

extension EnvironmentValues {
    var errorHandlingService: ManualBoxErrorHandlingService {
        get { self[ErrorHandlingServiceKey.self] }
        set { self[ErrorHandlingServiceKey.self] = newValue }
    }
}