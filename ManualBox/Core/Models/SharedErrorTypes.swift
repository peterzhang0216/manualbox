//
//  SharedErrorTypes.swift
//  ManualBox
//
//  Created by Assistant on 2025/7/29.
//

import Foundation

// MARK: - 共享错误类型定义

/// 错误上下文 - 统一定义，避免重复
public struct ErrorContext {
    let operation: String
    let component: String?
    let viewName: String?
    let functionName: String?
    let userAction: String?
    let additionalInfo: [String: Any]?
    
    init(
        operation: String,
        component: String? = nil,
        viewName: String? = nil,
        functionName: String? = nil,
        userAction: String? = nil,
        additionalInfo: [String: Any]? = nil
    ) {
        self.operation = operation
        self.component = component
        self.viewName = viewName
        self.functionName = functionName
        self.userAction = userAction
        self.additionalInfo = additionalInfo
    }
}

/// 恢复结果 - 统一定义，避免重复
public enum RecoveryResult {
    case success
    case failed(Error)
    case userInterventionRequired(String)
    case retryLater(TimeInterval)
}

/// 错误处理结果
public enum ErrorHandlingResult {
    case handled
    case escalated
    case retry(after: TimeInterval)
    case userInterventionRequired
}

/// 恢复策略
public enum RecoveryStrategy {
    case retry(maxAttempts: Int, delay: TimeInterval)
    case fallback(operation: () async -> Void)
    case userIntervention(message: String, actions: [RecoveryAction])
    case gracefulDegradation(limitedFunctionality: [String])
}

/// 恢复操作
public struct RecoveryAction {
    let title: String
    let action: () async -> Void
    
    public init(title: String, action: @escaping () async -> Void) {
        self.title = title
        self.action = action
    }
}
