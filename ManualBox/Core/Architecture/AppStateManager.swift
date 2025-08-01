//
//  AppStateManager.swift
//  ManualBox
//
//  Created by Assistant on 2025/6/21.
//

import Foundation
import SwiftUI
import CoreData
import Combine

// MARK: - 应用全局状态
struct AppGlobalState {
    // 选择状态
    var selectedProduct: Product?
    var detailPanelState: DetailPanelState = .empty
    
    // 同步状态
    var syncStatus: CloudKitSyncStatus = .idle
    var lastSyncDate: Date?
    var syncProgress: Double = 0.0
    
    // 应用状态
    var isInitialized: Bool = false
    var hasNetworkConnection: Bool = true
    var memoryWarningCount: Int = 0
    
    // 错误状态
    var globalError: AppError?
    var errorHistory: [AppError] = []
    
    // 性能指标
    var performanceMetrics: PerformanceMetrics = PerformanceMetrics()
}

// MARK: - 应用错误类型
// AppError is defined in ErrorHandling.swift

// MARK: - 性能指标
struct PerformanceMetrics: Codable {
    var memoryUsage: Double
    var cpuUsage: Double
    var diskUsage: Double
    var networkLatency: Double
    var lastUpdated: Date

    init(memoryUsage: Double = 0.0, cpuUsage: Double = 0.0, diskUsage: Double = 0.0, networkLatency: Double = 0.0, lastUpdated: Date = Date()) {
        self.memoryUsage = memoryUsage
        self.cpuUsage = cpuUsage
        self.diskUsage = diskUsage
        self.networkLatency = networkLatency
        self.lastUpdated = lastUpdated
    }
}

// MARK: - 统一状态管理中心
@MainActor
class AppStateManager: ObservableObject {
    @Published var state = AppGlobalState()
    
    // 私有属性 - 使用 lazy 初始化避免并发问题
    private lazy var cancellables = Set<AnyCancellable>()
    private let errorHistoryLimit = 50
    
    // 单例 - 使用 lazy 初始化避免并发问题
    static let shared: AppStateManager = {
        let instance = AppStateManager()
        return instance
    }()

    // 非隔离的访问方法
    nonisolated static func getInstance() async -> AppStateManager {
        return await shared
    }

    // 私有初始化器
    private init() {
        setupStateMonitoring()
    }

    // 非隔离的初始化方法 - 用于创建新实例
    nonisolated static func createInstance() -> AppStateManager {
        // 创建一个未初始化的实例，稍后在主线程上初始化
        return AppStateManager.createUninitializedInstance()
    }

    // 专门为环境键使用的非隔离创建方法
    nonisolated static func createNonIsolatedInstance() -> AppStateManager {
        // 这个方法在非主线程上下文中创建实例
        return AppStateManager.createUninitializedInstance()
    }

    // 创建未初始化的实例
    private nonisolated static func createUninitializedInstance() -> AppStateManager {
        // 使用特殊的初始化方法避免主线程隔离问题
        let instance = AppStateManager.__createForEnvironment()
        return instance
    }

    // 专门为环境使用的初始化方法
    private nonisolated init(__forEnvironment: Void) {
        // 延迟初始化，避免主线程隔离问题
        // 实际的设置会在首次访问时在主线程上进行
    }

    // 工厂方法
    private nonisolated static func __createForEnvironment() -> AppStateManager {
        return AppStateManager(__forEnvironment: ())
    }

    // 确保环境实例正确初始化
    func ensureInitialized() {
        if !state.isInitialized {
            setupStateMonitoring()
            state.isInitialized = true
        }
    }
    
    // MARK: - 选择状态管理
    
    func updateSelection(_ product: Product?) {
        state.selectedProduct = product
        if let product = product {
            state.detailPanelState = .productDetail(product)
        } else {
            state.detailPanelState = .empty
        }
        
        // 发送状态变更通知
        AppNotification.productUpdated.post(object: product)
    }
    
    func updateDetailPanelState(_ newState: DetailPanelState) {
        state.detailPanelState = newState
        
        // 根据详情面板状态更新选择的产品
        switch newState {
        case .productDetail(let product), .editProduct(let product):
            if state.selectedProduct?.objectID != product.objectID {
                state.selectedProduct = product
            }
        case .empty:
            state.selectedProduct = nil
        default:
            break
        }
    }
    
    // MARK: - 同步状态管理
    
    func updateSyncStatus(_ status: CloudKitSyncStatus, progress: Double = 0.0) {
        state.syncStatus = status
        state.syncProgress = progress

        if case .completed = status {
            state.lastSyncDate = Date()
        }
    }
    
    // MARK: - 应用状态管理
    
    func setInitialized(_ initialized: Bool) {
        state.isInitialized = initialized
    }
    
    func updateNetworkConnection(_ connected: Bool) {
        state.hasNetworkConnection = connected
    }
    
    func recordMemoryWarning() {
        state.memoryWarningCount += 1
    }
    
    // MARK: - 错误管理
    
    func handleError(_ error: Error, context: String, severity: AppError.ErrorSeverity = .error) {
        let appError: AppError
        
        // 根据错误类型创建相应的 AppError
        if let networkError = error as? URLError {
            appError = .network(.requestFailed(networkError.localizedDescription))
        } else if let persistenceError = error as? NSError, persistenceError.domain == NSCocoaErrorDomain {
            appError = .persistence(.saveFailed(persistenceError.localizedDescription))
        } else {
            appError = .system(.unknown(error.localizedDescription))
        }
        
        addError(appError)
    }
    
    func handleError(message: String, context: String, severity: AppError.ErrorSeverity = .error) {
        let appError = AppError.system(.unknown(message))
        addError(appError)
    }
    
    private func addError(_ error: AppError) {
        state.globalError = error
        state.errorHistory.append(error)
        
        // 限制错误历史记录数量
        if state.errorHistory.count > errorHistoryLimit {
            state.errorHistory.removeFirst(state.errorHistory.count - errorHistoryLimit)
        }
        
        // 记录错误日志
        print("🚨 [AppStateManager] \(error.severity.rawValue): \(error.localizedDescription)")
    }
    
    func clearGlobalError() {
        state.globalError = nil
    }
    
    func clearErrorHistory() {
        state.errorHistory.removeAll()
    }
    
    // MARK: - 性能指标管理
    
    func updatePerformanceMetrics(_ metrics: PerformanceMetrics) {
        state.performanceMetrics = metrics
    }
    
    // MARK: - 私有方法
    
    private func setupStateMonitoring() {
        // 监听选择状态变化
        $state
            .map(\.selectedProduct)
            .removeDuplicates { $0?.objectID == $1?.objectID }
            .sink { product in
                print("📱 [AppStateManager] 产品选择变更: \(product?.name ?? "无")")
            }
            .store(in: &cancellables)
        
        // 监听详情面板状态变化
        $state
            .map(\.detailPanelState)
            .removeDuplicates()
            .sink { state in
                print("📱 [AppStateManager] 详情面板状态变更: \(state)")
            }
            .store(in: &cancellables)
        
        // 监听同步状态变化
        $state
            .map(\.syncStatus)
            .removeDuplicates()
            .sink { status in
                print("📱 [AppStateManager] 同步状态变更: \(status)")
            }
            .store(in: &cancellables)
    }
}

// MARK: - SwiftUI Environment Key
struct AppStateManagerKey: EnvironmentKey {
    static let defaultValue: AppStateManager = {
        // 创建一个新的实例而不是使用shared
        // 使用非隔离的创建方法来避免主线程隔离问题
        return AppStateManager.createNonIsolatedInstance()
    }()
}

extension EnvironmentValues {
    var appStateManager: AppStateManager {
        get { self[AppStateManagerKey.self] }
        set { self[AppStateManagerKey.self] = newValue }
    }
}


