//
//  ViewModelProtocolExtensions.swift
//  ManualBox
//
//  Created by Assistant on 2025/1/27.
//

import Foundation
import Combine
import SwiftUI
import CoreData

// MARK: - ViewModelProtocol Extensions
extension ViewModelProtocol {
    /// 便利方法：发送动作并等待完成
    func sendAndWait(_ action: Action) async {
        await withCheckedContinuation { continuation in
            send(action)
            // 简单的延迟，实际应用中可能需要更复杂的同步机制
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                continuation.resume()
            }
        }
    }
}

// MARK: - StateProtocol Extensions
extension StateProtocol {
    /// 检查是否有错误
    var hasError: Bool {
        return errorMessage != nil && !errorMessage!.isEmpty
    }
    
    /// 检查是否处于空闲状态（既不加载也没有错误）
    var isIdle: Bool {
        return !isLoading && !hasError
    }
}

// MARK: - BaseState Extensions
extension BaseState {
    /// 创建一个带有错误的状态
    static func withError(_ message: String) -> BaseState {
        return BaseState(isLoading: false, errorMessage: message)
    }
    
    /// 创建一个加载中的状态
    static var loading: BaseState {
        return BaseState(isLoading: true, errorMessage: nil)
    }
    
    /// 创建一个成功的状态
    static var success: BaseState {
        return BaseState(isLoading: false, errorMessage: nil)
    }
}

// MARK: - BaseViewModel Extensions
extension BaseViewModel {
    /// 便利方法：执行异步操作并自动处理加载状态
    func withLoading<T>(_ operation: @escaping () async throws -> T) async -> T? {
        setLoading(true)
        setError(nil as String?)
        
        do {
            let result = try await operation()
            setLoading(false)
            return result
        } catch {
            setError(error)
            setLoading(false)
            return nil
        }
    }
    
    /// 便利方法：延迟执行动作
    func sendDelayed(_ action: Action, delay: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            self.send(action)
        }
    }
    
    /// 便利方法：条件性发送动作
    func sendIf(_ condition: Bool, _ action: Action) {
        if condition {
            send(action)
        }
    }
    
    /// 便利方法：批量发送动作
    func sendBatch(_ actions: [Action]) {
        for action in actions {
            send(action)
        }
    }
}

// MARK: - ViewModel State Binding Helpers
extension BaseViewModel {
    /// 创建一个绑定到状态属性的Binding
    func binding<T>(
        get: @escaping (State) -> T,
        set: @escaping (T) -> Action
    ) -> Binding<T> {
        Binding(
            get: { get(self.state) },
            set: { self.send(set($0)) }
        )
    }
    
    /// 创建一个只读的绑定
    func readOnlyBinding<T>(
        get: @escaping (State) -> T
    ) -> Binding<T> {
        Binding(
            get: { get(self.state) },
            set: { _ in /* 只读，不执行任何操作 */ }
        )
    }
}

// MARK: - Error Handling Extensions
extension BaseViewModel {
    /// 处理常见的Core Data错误
    func handleCoreDataError(_ error: Error) {
        if let nsError = error as NSError? {
            switch nsError.code {
            case NSValidationMissingMandatoryPropertyError:
                setError("缺少必填字段")
            case NSValidationStringTooShortError:
                setError("输入内容太短")
            case NSValidationStringTooLongError:
                setError("输入内容太长")
            case NSManagedObjectConstraintMergeError:
                setError("数据冲突，请重试")
            case NSPersistentStoreSaveError:
                setError("保存失败，请检查存储空间")
            default:
                setError("数据操作失败: \(nsError.localizedDescription)")
            }
        } else {
            setError(error.localizedDescription)
        }
    }
    
    /// 处理网络错误
    func handleNetworkError(_ error: Error) {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet:
                setError("网络连接不可用")
            case .timedOut:
                setError("网络请求超时")
            case .cannotFindHost:
                setError("无法连接到服务器")
            default:
                setError("网络错误: \(urlError.localizedDescription)")
            }
        } else {
            setError(error.localizedDescription)
        }
    }
}

// MARK: - Validation Helpers
extension BaseViewModel {
    /// 验证字符串是否非空
    func validateNonEmpty(_ value: String, fieldName: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            setError("\(fieldName)不能为空")
            return false
        }
        return true
    }
    
    /// 验证字符串长度
    func validateLength(_ value: String, fieldName: String, min: Int = 0, max: Int = Int.max) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count < min {
            setError("\(fieldName)至少需要\(min)个字符")
            return false
        }
        if trimmed.count > max {
            setError("\(fieldName)不能超过\(max)个字符")
            return false
        }
        return true
    }
    
    /// 验证邮箱格式
    func validateEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        if !emailPredicate.evaluate(with: email) {
            setError("邮箱格式不正确")
            return false
        }
        return true
    }
}

// MARK: - Debounce Helper
class DebounceHelper {
    private var workItem: DispatchWorkItem?
    private let queue: DispatchQueue
    
    init(queue: DispatchQueue = .main) {
        self.queue = queue
    }
    
    func debounce(delay: TimeInterval, action: @escaping () -> Void) {
        workItem?.cancel()
        workItem = DispatchWorkItem(block: action)
        queue.asyncAfter(deadline: .now() + delay, execute: workItem!)
    }
    
    func cancel() {
        workItem?.cancel()
        workItem = nil
    }
}

// MARK: - Global Debounce Helper Storage
private var globalDebounceHelpers: [String: DebounceHelper] = [:]

// MARK: - ViewModel Debounce Extension
extension BaseViewModel {
    /// 防抖发送动作
    func sendDebounced(_ action: Action, delay: TimeInterval = 0.5, key: String = "default") {
        let helperKey = "\(ObjectIdentifier(self))_\(key)"
        
        if globalDebounceHelpers[helperKey] == nil {
            globalDebounceHelpers[helperKey] = DebounceHelper()
        }
        
        globalDebounceHelpers[helperKey]?.debounce(delay: delay) {
            self.send(action)
        }
    }
    
    /// 取消防抖
    func cancelDebounce(key: String = "default") {
        let helperKey = "\(ObjectIdentifier(self))_\(key)"
        globalDebounceHelpers[helperKey]?.cancel()
    }
}