//
//  EventBus.swift
//  ManualBox
//
//  Created by Assistant on 2025/6/21.
//

import Foundation
import Combine
import SwiftUI

// MARK: - 事件协议
protocol AppEvent {
    var timestamp: Date { get }
    var eventId: UUID { get }
}

// MARK: - 基础事件实现
struct BaseEvent: AppEvent {
    let timestamp: Date = Date()
    let eventId: UUID = UUID()
}

// MARK: - 具体事件类型
struct ProductSelectionEvent: AppEvent {
    let timestamp: Date = Date()
    let eventId: UUID = UUID()
    let product: Product?
    let previousProduct: Product?
}

struct DataChangeEvent: AppEvent {
    let timestamp: Date = Date()
    let eventId: UUID = UUID()
    let entityType: String
    let changeType: DataChangeType
    let entityId: UUID?
    
    enum DataChangeType {
        case created
        case updated
        case deleted
    }
}

struct SyncEvent: AppEvent {
    let timestamp: Date = Date()
    let eventId: UUID = UUID()
    let syncType: SyncType
    let status: SyncStatus
    let progress: Double?
    
    enum SyncType {
        case cloudKit
        case localBackup
        case dataExport
        case dataImport
    }
}

struct ErrorEvent: AppEvent {
    let timestamp: Date = Date()
    let eventId: UUID = UUID()
    let error: Error
    let context: String
    let severity: AppError.ErrorSeverity
}

struct PerformanceEvent: AppEvent {
    let timestamp: Date = Date()
    let eventId: UUID = UUID()
    let metricName: String
    let value: Double
    let unit: String
}

struct NavigationEvent: AppEvent {
    let timestamp: Date = Date()
    let eventId: UUID = UUID()
    let from: String
    let to: String
    let parameters: [String: Any]?
}

// MARK: - 事件订阅者协议
@MainActor
protocol EventSubscriber: AnyObject {
    var subscriberId: UUID { get }
    func handleEvent<T: AppEvent>(_ event: T)
}

// MARK: - 事件总线
@MainActor
class EventBus: ObservableObject {
    
    // 单例 - 使用 lazy 初始化避免并发问题
    static let shared: EventBus = {
        let instance = EventBus()
        return instance
    }()

    // 非隔离的访问方法
    nonisolated static func getInstance() async -> EventBus {
        return await shared
    }

    // 私有属性 - 使用 lazy 初始化避免并发问题
    private lazy var subscribers: [String: [WeakSubscriber]] = [:]
    private lazy var eventHistory: [AppEvent] = []
    private let historyLimit = 1000
    private lazy var cancellables = Set<AnyCancellable>()

    // 发布的事件流
    @Published private(set) var lastEvent: AppEvent?

    // 私有初始化器
    private init() {
        setupEventMonitoring()
    }

    // 专门为环境键使用的非隔离创建方法
    nonisolated static func createNonIsolatedInstance() -> EventBus {
        // 这个方法在非主线程上下文中创建实例
        return EventBus.__createForEnvironment()
    }

    // 专门为环境使用的初始化方法
    private nonisolated init(__forEnvironment: Void) {
        // 延迟初始化，避免主线程隔离问题
        // 属性将在首次访问时在主线程上初始化
    }

    // 工厂方法
    private nonisolated static func __createForEnvironment() -> EventBus {
        return EventBus(__forEnvironment: ())
    }

    // 确保环境实例正确初始化
    func ensureInitialized() {
        if cancellables.isEmpty {
            setupEventMonitoring()
        }
    }
    
    // MARK: - 订阅管理
    
    func subscribe<T: AppEvent>(
        to eventType: T.Type,
        subscriber: EventSubscriber,
        handler: @escaping (T) -> Void
    ) {
        let key = String(describing: eventType)
        
        if subscribers[key] == nil {
            subscribers[key] = []
        }
        
        let weakSubscriber = WeakSubscriber(
            subscriber: subscriber,
            handler: { event in
                if let typedEvent = event as? T {
                    handler(typedEvent)
                }
            }
        )
        
        subscribers[key]?.append(weakSubscriber)
        
        print("📡 [EventBus] 订阅者 \(subscriber.subscriberId) 订阅了事件类型: \(key)")
    }
    
    func unsubscribe(subscriber: EventSubscriber) {
        for (key, _) in subscribers {
            subscribers[key]?.removeAll { weakSub in
                weakSub.subscriber == nil || weakSub.subscriber?.subscriberId == subscriber.subscriberId
            }
        }
        
        print("📡 [EventBus] 订阅者 \(subscriber.subscriberId) 已取消所有订阅")
    }
    
    func unsubscribe<T: AppEvent>(from eventType: T.Type, subscriber: EventSubscriber) {
        let key = String(describing: eventType)
        subscribers[key]?.removeAll { weakSub in
            weakSub.subscriber?.subscriberId == subscriber.subscriberId
        }
        
        print("📡 [EventBus] 订阅者 \(subscriber.subscriberId) 取消订阅事件类型: \(key)")
    }
    
    // MARK: - 事件发布
    
    func publish<T: AppEvent>(_ event: T) {
        let key = String(describing: T.self)
        
        // 记录事件历史
        addToHistory(event)
        
        // 更新最新事件
        lastEvent = event
        
        // 清理无效订阅者
        cleanupSubscribers(for: key)
        
        // 通知订阅者
        subscribers[key]?.forEach { weakSubscriber in
            if let subscriber = weakSubscriber.subscriber {
                weakSubscriber.handler(event)
                subscriber.handleEvent(event)
            }
        }
        
        print("📡 [EventBus] 发布事件: \(key) (订阅者数量: \(subscribers[key]?.count ?? 0))")
    }
    
    // MARK: - 便利发布方法
    
    func publishProductSelection(_ product: Product?, previousProduct: Product? = nil) {
        let event = ProductSelectionEvent(product: product, previousProduct: previousProduct)
        publish(event)
    }
    
    func publishDataChange(entityType: String, changeType: DataChangeEvent.DataChangeType, entityId: UUID? = nil) {
        let event = DataChangeEvent(entityType: entityType, changeType: changeType, entityId: entityId)
        publish(event)
    }
    
    func publishSyncEvent(syncType: SyncEvent.SyncType, status: SyncStatus, progress: Double? = nil) {
        let event = SyncEvent(syncType: syncType, status: status, progress: progress)
        publish(event)
    }
    
    func publishError(_ error: Error, context: String, severity: AppError.ErrorSeverity = .error) {
        let event = ErrorEvent(error: error, context: context, severity: severity)
        publish(event)
    }
    
    func publishPerformanceMetric(name: String, value: Double, unit: String) {
        let event = PerformanceEvent(metricName: name, value: value, unit: unit)
        publish(event)
    }
    
    func publishNavigation(from: String, to: String, parameters: [String: Any]? = nil) {
        let event = NavigationEvent(from: from, to: to, parameters: parameters)
        publish(event)
    }
    
    // MARK: - 事件历史管理
    
    func getEventHistory<T: AppEvent>(ofType type: T.Type, limit: Int = 50) -> [T] {
        return eventHistory
            .compactMap { $0 as? T }
            .suffix(limit)
            .reversed()
    }
    
    func clearEventHistory() {
        eventHistory.removeAll()
        print("📡 [EventBus] 事件历史已清空")
    }
    
    // MARK: - 私有方法
    
    private func addToHistory(_ event: AppEvent) {
        eventHistory.append(event)
        
        // 限制历史记录数量
        if eventHistory.count > historyLimit {
            eventHistory.removeFirst(eventHistory.count - historyLimit)
        }
    }
    
    private func cleanupSubscribers(for key: String) {
        subscribers[key]?.removeAll { $0.subscriber == nil }
    }
    
    private func setupEventMonitoring() {
        // 监听事件发布
        $lastEvent
            .compactMap { $0 }
            .sink { event in
                // 可以在这里添加全局事件监控逻辑
                // 例如：记录到分析系统、调试日志等
            }
            .store(in: &cancellables)
    }
}

// MARK: - 弱引用订阅者包装
private class WeakSubscriber {
    weak var subscriber: EventSubscriber?
    let handler: (AppEvent) -> Void
    
    init(subscriber: EventSubscriber, handler: @escaping (AppEvent) -> Void) {
        self.subscriber = subscriber
        self.handler = handler
    }
}

// MARK: - SwiftUI Environment Key
struct EventBusKey: EnvironmentKey {
    static let defaultValue: EventBus = {
        // 使用非隔离的创建方法来避免主线程隔离问题
        return EventBus.createNonIsolatedInstance()
    }()
}

extension EnvironmentValues {
    var eventBus: EventBus {
        get { self[EventBusKey.self] }
        set { self[EventBusKey.self] = newValue }
    }
}
