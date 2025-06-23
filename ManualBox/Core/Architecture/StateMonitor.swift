//
//  StateMonitor.swift
//  ManualBox
//
//  Created by Assistant on 2025/6/21.
//

import Foundation
import SwiftUI
import Combine

#if canImport(Darwin)
import Darwin.Mach
#endif

// MARK: - 状态快照
struct StateSnapshot: Identifiable, Codable {
    let id = UUID()
    let timestamp: Date
    let viewModel: String
    let state: String
    let memoryUsage: Double?
    let performanceMetrics: [String: Double]?
    
    enum CodingKeys: String, CodingKey {
        case timestamp, viewModel, state, memoryUsage, performanceMetrics
    }
}

// MARK: - 性能指标
struct PerformanceSnapshot: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let cpuUsage: Double
    let memoryUsage: Double
    let diskUsage: Double
    let networkLatency: Double?
    let activeViewModels: Int
    let pendingTasks: Int

    init(timestamp: Date = Date(), cpuUsage: Double, memoryUsage: Double, diskUsage: Double, networkLatency: Double? = nil, activeViewModels: Int, pendingTasks: Int) {
        self.id = UUID()
        self.timestamp = timestamp
        self.cpuUsage = cpuUsage
        self.memoryUsage = memoryUsage
        self.diskUsage = diskUsage
        self.networkLatency = networkLatency
        self.activeViewModels = activeViewModels
        self.pendingTasks = pendingTasks
    }
}

// MARK: - 状态监控器
@MainActor
class StateMonitor: ObservableObject, EventSubscriber {
    
    // EventSubscriber 协议要求
    let subscriberId = UUID()
    
    // 发布的状态
    @Published var stateHistory: [StateSnapshot] = []
    @Published var performanceHistory: [PerformanceSnapshot] = []
    @Published var isMonitoring: Bool = false
    @Published var currentPerformance: PerformanceSnapshot?
    
    // 配置
    private let maxHistoryCount = 500
    private let performanceUpdateInterval: TimeInterval = 5.0
    
    // 私有属性 - 使用 lazy 初始化避免并发问题
    private lazy var cancellables = Set<AnyCancellable>()
    private var performanceTimer: Timer?
    private lazy var registeredViewModels: [String: WeakViewModelReference] = [:]
    
    // 单例 - 使用 lazy 初始化避免并发问题
    static let shared: StateMonitor = {
        let instance = StateMonitor()
        return instance
    }()

    // 非隔离的访问方法
    nonisolated static func getInstance() async -> StateMonitor {
        return await shared
    }

    // 专门为环境键使用的非隔离创建方法
    nonisolated static func createNonIsolatedInstance() -> StateMonitor {
        // 这个方法在非主线程上下文中创建实例
        return StateMonitor.__createForEnvironment()
    }

    // 私有初始化器
    private init() {
        setupEventSubscriptions()
    }

    // 专门为环境使用的初始化方法
    private nonisolated init(__forEnvironment: Void) {
        // 延迟初始化，避免主线程隔离问题
        // @Published 属性会自动初始化为默认值
        // 其他属性将在首次访问时在主线程上初始化
    }

    // 工厂方法
    private nonisolated static func __createForEnvironment() -> StateMonitor {
        return StateMonitor(__forEnvironment: ())
    }

    // 确保环境实例正确初始化
    func ensureInitialized() {
        if cancellables.isEmpty {
            setupEventSubscriptions()
        }
    }
    
    // MARK: - 监控控制
    
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        isMonitoring = true
        startPerformanceMonitoring()
        
        print("📊 [StateMonitor] 开始状态监控")
    }
    
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        isMonitoring = false
        stopPerformanceMonitoring()
        
        print("📊 [StateMonitor] 停止状态监控")
    }
    
    // MARK: - ViewModel 注册
    
    func registerViewModel<T: ViewModelProtocol>(_ viewModel: T, name: String) {
        let reference = WeakViewModelReference(viewModel: viewModel)
        registeredViewModels[name] = reference
        
        // 监听 ViewModel 状态变化
        viewModel.objectWillChange
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.recordStateChange(viewModel.state, viewModel: name)
                }
            }
            .store(in: &cancellables)
        
        print("📊 [StateMonitor] 注册 ViewModel: \(name)")
    }
    
    func unregisterViewModel(name: String) {
        registeredViewModels.removeValue(forKey: name)
        print("📊 [StateMonitor] 注销 ViewModel: \(name)")
    }
    
    // MARK: - 状态记录
    
    func recordStateChange<T>(_ state: T, viewModel: String) {
        guard isMonitoring else { return }
        
        let snapshot = StateSnapshot(
            timestamp: Date(),
            viewModel: viewModel,
            state: String(describing: state),
            memoryUsage: getCurrentMemoryUsage(),
            performanceMetrics: getCurrentPerformanceMetrics()
        )
        
        stateHistory.append(snapshot)
        
        // 限制历史记录数量
        if stateHistory.count > maxHistoryCount {
            stateHistory.removeFirst(stateHistory.count - maxHistoryCount)
        }
        
        print("📊 [StateMonitor] 记录状态变化: \(viewModel)")
    }
    
    // MARK: - 性能监控
    
    private func startPerformanceMonitoring() {
        performanceTimer = Timer.scheduledTimer(withTimeInterval: performanceUpdateInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.recordPerformanceSnapshot()
            }
        }
    }
    
    private func stopPerformanceMonitoring() {
        performanceTimer?.invalidate()
        performanceTimer = nil
    }
    
    private func recordPerformanceSnapshot() {
        let snapshot = PerformanceSnapshot(
            cpuUsage: getCurrentCPUUsage(),
            memoryUsage: getCurrentMemoryUsage(),
            diskUsage: getCurrentDiskUsage(),
            networkLatency: getCurrentNetworkLatency(),
            activeViewModels: getActiveViewModelsCount(),
            pendingTasks: getPendingTasksCount()
        )
        
        currentPerformance = snapshot
        performanceHistory.append(snapshot)
        
        // 限制性能历史记录数量
        if performanceHistory.count > maxHistoryCount {
            performanceHistory.removeFirst(performanceHistory.count - maxHistoryCount)
        }
        
        // 发布性能事件
        EventBus.shared.publishPerformanceMetric(
            name: "memory_usage",
            value: snapshot.memoryUsage,
            unit: "MB"
        )
        
        EventBus.shared.publishPerformanceMetric(
            name: "cpu_usage",
            value: snapshot.cpuUsage,
            unit: "%"
        )
    }
    
    // MARK: - 性能指标获取
    
    private func getCurrentMemoryUsage() -> Double {
        #if canImport(Darwin)
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }

        if kerr == KERN_SUCCESS {
            return Double(info.resident_size) / 1024.0 / 1024.0 // MB
        } else {
            return 0.0
        }
        #else
        // 非Darwin平台的简化实现
        return 0.0
        #endif
    }
    
    private func getCurrentCPUUsage() -> Double {
        // 简化的 CPU 使用率获取
        // 实际实现需要更复杂的系统调用
        return Double.random(in: 0...100) // 占位符实现
    }
    
    private func getCurrentDiskUsage() -> Double {
        // 获取应用数据目录的磁盘使用情况
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return 0.0
        }
        
        do {
            let resourceValues = try documentsPath.resourceValues(forKeys: [.fileSizeKey, .totalFileSizeKey])
            return Double(resourceValues.fileSize ?? 0) / 1024.0 / 1024.0 // MB
        } catch {
            return 0.0
        }
    }
    
    private func getCurrentNetworkLatency() -> Double? {
        // 网络延迟测量需要实际的网络请求
        // 这里返回 nil 表示暂未实现
        return nil
    }
    
    private func getActiveViewModelsCount() -> Int {
        return registeredViewModels.values.compactMap { $0.viewModel }.count
    }
    
    private func getPendingTasksCount() -> Int {
        // 这需要从各个 ViewModel 收集待处理任务数量
        // 简化实现
        return 0
    }
    
    private func getCurrentPerformanceMetrics() -> [String: Double] {
        return [
            "memory": getCurrentMemoryUsage(),
            "cpu": getCurrentCPUUsage(),
            "disk": getCurrentDiskUsage()
        ]
    }
    
    // MARK: - 数据导出
    
    func exportStateHistory() -> Data? {
        do {
            return try JSONEncoder().encode(stateHistory)
        } catch {
            print("📊 [StateMonitor] 导出状态历史失败: \(error)")
            return nil
        }
    }
    
    func exportPerformanceHistory() -> Data? {
        do {
            return try JSONEncoder().encode(performanceHistory)
        } catch {
            print("📊 [StateMonitor] 导出性能历史失败: \(error)")
            return nil
        }
    }
    
    // MARK: - 数据清理
    
    func clearHistory() {
        stateHistory.removeAll()
        performanceHistory.removeAll()
        print("📊 [StateMonitor] 清空监控历史")
    }
    
    // MARK: - EventSubscriber 实现
    
    func handleEvent<T: AppEvent>(_ event: T) {
        // 处理特定事件类型
        switch event {
        case let errorEvent as ErrorEvent:
            recordErrorEvent(errorEvent)
        case let perfEvent as PerformanceEvent:
            recordPerformanceEvent(perfEvent)
        default:
            break
        }
    }
    
    private func recordErrorEvent(_ event: ErrorEvent) {
        // 记录错误相关的状态变化
        let snapshot = StateSnapshot(
            timestamp: event.timestamp,
            viewModel: "ErrorSystem",
            state: "Error: \(event.error.localizedDescription)",
            memoryUsage: getCurrentMemoryUsage(),
            performanceMetrics: getCurrentPerformanceMetrics()
        )
        
        stateHistory.append(snapshot)
    }
    
    private func recordPerformanceEvent(_ event: PerformanceEvent) {
        // 记录性能指标事件
        print("📊 [StateMonitor] 性能指标: \(event.metricName) = \(event.value) \(event.unit)")
    }
    
    // MARK: - 事件订阅设置
    
    private func setupEventSubscriptions() {
        EventBus.shared.subscribe(to: ErrorEvent.self, subscriber: self) { [weak self] event in
            self?.handleEvent(event)
        }
        
        EventBus.shared.subscribe(to: PerformanceEvent.self, subscriber: self) { [weak self] event in
            self?.handleEvent(event)
        }
    }
}

// MARK: - 弱引用 ViewModel 包装
private class WeakViewModelReference {
    weak var viewModel: (any ViewModelProtocol)?
    
    init(viewModel: any ViewModelProtocol) {
        self.viewModel = viewModel
    }
}

// MARK: - SwiftUI Environment Key
struct StateMonitorKey: EnvironmentKey {
    static let defaultValue: StateMonitor = {
        // 使用非隔离的创建方法来避免主线程隔离问题
        return StateMonitor.createNonIsolatedInstance()
    }()
}

extension EnvironmentValues {
    var stateMonitor: StateMonitor {
        get { self[StateMonitorKey.self] }
        set { self[StateMonitorKey.self] = newValue }
    }
}
