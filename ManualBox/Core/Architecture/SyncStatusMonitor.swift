//
//  SyncStatusMonitor.swift
//  ManualBox
//
//  Created by Assistant on 2024/12/19.
//  同步状态监控器 - 提供详细的同步进度显示
//

import Foundation
import Combine
import SwiftUI

// MARK: - 同步状态监控器
@MainActor
class SyncStatusMonitor: ObservableObject {
    
    // MARK: - Published Properties
    @Published private(set) var isMonitoring = false
    @Published private(set) var currentStatus: CloudKitSyncStatus = .idle
    @Published private(set) var progress: Double = 0.0
    @Published private(set) var currentPhase: SyncPhase = .idle
    @Published private(set) var estimatedTimeRemaining: TimeInterval?
    @Published private(set) var throughputMetrics: ThroughputMetrics?
    @Published private(set) var detailedProgress: DetailedSyncProgress?
    @Published private(set) var syncHistory: [SyncHistoryEntry] = []
    @Published private(set) var networkStatus: NetworkStatus = .unknown
    
    // MARK: - Dependencies
    private let syncCoordinator: EnhancedSyncCoordinator
    private let performanceMonitor: PerformanceMonitoringService
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Monitoring State
    private var monitoringTimer: Timer?
    private var lastUpdateTime: Date?
    
    // MARK: - Initialization
    init(
        syncCoordinator: EnhancedSyncCoordinator,
        performanceMonitor: PerformanceMonitoringService = .shared
    ) {
        self.syncCoordinator = syncCoordinator
        self.performanceMonitor = performanceMonitor
        
        setupMonitoring()
    }
    
    // MARK: - Public Methods
    
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        isMonitoring = true
        startPeriodicUpdates()
        
        print("📊 开始同步状态监控")
    }
    
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        isMonitoring = false
        stopPeriodicUpdates()
        
        print("📊 停止同步状态监控")
    }
    
    func getDetailedStatus() -> DetailedSyncStatus {
        return DetailedSyncStatus(
            status: currentStatus,
            progress: progress,
            phase: currentPhase,
            estimatedTimeRemaining: estimatedTimeRemaining,
            throughputMetrics: throughputMetrics,
            networkStatus: networkStatus,
            lastUpdateTime: lastUpdateTime ?? Date()
        )
    }
    
    func exportSyncHistory() -> Data? {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            return try encoder.encode(syncHistory)
        } catch {
            print("❌ 导出同步历史失败: \(error)")
            return nil
        }
    }
    
    // MARK: - Private Methods
    
    private func setupMonitoring() {
        // 监控同步协调器状态变化
        syncCoordinator.$syncStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.handleStatusChange(status)
            }
            .store(in: &cancellables)
        
        syncCoordinator.$syncProgress
            .receive(on: DispatchQueue.main)
            .sink { [weak self] progress in
                self?.handleProgressChange(progress)
            }
            .store(in: &cancellables)
        
        syncCoordinator.$currentPhase
            .receive(on: DispatchQueue.main)
            .sink { [weak self] phase in
                self?.handlePhaseChange(phase)
            }
            .store(in: &cancellables)
        
        syncCoordinator.$estimatedTimeRemaining
            .receive(on: DispatchQueue.main)
            .sink { [weak self] timeRemaining in
                self?.estimatedTimeRemaining = timeRemaining
            }
            .store(in: &cancellables)
        
        syncCoordinator.$throughputMetrics
            .receive(on: DispatchQueue.main)
            .sink { [weak self] metrics in
                self?.throughputMetrics = metrics
            }
            .store(in: &cancellables)
    }
    
    private func handleStatusChange(_ status: CloudKitSyncStatus) {
        let previousStatus = currentStatus
        currentStatus = status
        lastUpdateTime = Date()
        
        // 记录状态变化历史
        let historyEntry = SyncHistoryEntry(
            timestamp: Date(),
            event: .statusChanged(from: previousStatus, to: status),
            details: createEventDetails()
        )
        syncHistory.append(historyEntry)
        
        // 限制历史记录数量
        if syncHistory.count > 100 {
            syncHistory.removeFirst(syncHistory.count - 100)
        }
        
        print("📊 同步状态变化: \(previousStatus) -> \(status)")
    }
    
    private func handleProgressChange(_ newProgress: Double) {
        let previousProgress = progress
        progress = newProgress
        lastUpdateTime = Date()
        
        // 更新详细进度信息
        updateDetailedProgress()
        
        // 记录重要的进度里程碑
        if shouldRecordProgressMilestone(previous: previousProgress, current: newProgress) {
            let historyEntry = SyncHistoryEntry(
                timestamp: Date(),
                event: .progressMilestone(progress: newProgress),
                details: createEventDetails()
            )
            syncHistory.append(historyEntry)
        }
    }
    
    private func handlePhaseChange(_ phase: SyncPhase) {
        let previousPhase = currentPhase
        currentPhase = phase
        lastUpdateTime = Date()
        
        // 记录阶段变化
        let historyEntry = SyncHistoryEntry(
            timestamp: Date(),
            event: .phaseChanged(from: previousPhase, to: phase),
            details: createEventDetails()
        )
        syncHistory.append(historyEntry)
        
        print("📊 同步阶段变化: \(previousPhase.description) -> \(phase.description)")
    }
    
    private func updateDetailedProgress() {
        detailedProgress = DetailedSyncProgress(
            overallProgress: progress,
            phaseProgress: calculatePhaseProgress(),
            recordsProcessed: 0, // 需要从同步协调器获取
            totalRecords: 0, // 需要从同步协调器获取
            currentOperation: getCurrentOperationDescription(),
            bytesTransferred: 0, // 需要实际实现
            totalBytes: 0 // 需要实际实现
        )
    }
    
    private func calculatePhaseProgress() -> Double {
        // 根据当前阶段计算阶段内进度
        switch currentPhase {
        case .idle:
            return 0.0
        case .downloading:
            return progress * 3.0 // 下载阶段占总进度的1/3
        case .processing:
            return (progress - 0.33) * 3.0 // 处理阶段
        case .uploading:
            return (progress - 0.66) * 3.0 // 上传阶段
        case .resolving:
            return (progress - 0.90) * 10.0 // 冲突解决阶段
        case .completed:
            return 1.0
        }
    }
    
    private func getCurrentOperationDescription() -> String {
        switch currentPhase {
        case .idle:
            return "等待中"
        case .downloading:
            return "正在下载远程变更"
        case .processing:
            return "正在处理本地数据"
        case .uploading:
            return "正在上传本地变更"
        case .resolving:
            return "正在解决数据冲突"
        case .completed:
            return "同步完成"
        }
    }
    
    private func shouldRecordProgressMilestone(previous: Double, current: Double) -> Bool {
        let milestones: [Double] = [0.25, 0.5, 0.75, 1.0]
        
        for milestone in milestones {
            if previous < milestone && current >= milestone {
                return true
            }
        }
        
        return false
    }
    
    private func createEventDetails() -> [String: Any] {
        return [
            "progress": progress,
            "phase": currentPhase.description,
            "networkStatus": networkStatus.description,
            "throughput": throughputMetrics?.recordsPerSecond ?? 0
        ]
    }
    
    private func startPeriodicUpdates() {
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.performPeriodicUpdate()
            }
        }
    }
    
    private func stopPeriodicUpdates() {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
    }
    
    private func performPeriodicUpdate() {
        // 更新网络状态
        updateNetworkStatus()
        
        // 更新性能指标
        updatePerformanceMetrics()
        
        // 检查同步健康状态
        checkSyncHealth()
    }
    
    private func updateNetworkStatus() {
        // 这里应该检查实际的网络状态
        // 简化实现，假设网络正常
        networkStatus = .connected
    }
    
    private func updatePerformanceMetrics() {
        // 从性能监控器获取最新指标
        // 这里可以添加更多性能指标的收集
    }
    
    private func checkSyncHealth() {
        // 检查同步是否健康
        // 例如：检查是否长时间无进度、网络问题等
        
        if let lastUpdate = lastUpdateTime,
           Date().timeIntervalSince(lastUpdate) > 30.0,
           currentStatus == .syncing {
            
            // 同步可能卡住了
            let historyEntry = SyncHistoryEntry(
                timestamp: Date(),
                event: .warning("同步可能卡住，超过30秒无进度更新"),
                details: createEventDetails()
            )
            syncHistory.append(historyEntry)
        }
    }
    
    deinit {
        stopMonitoring()
    }
}

// MARK: - 详细同步状态
struct DetailedSyncStatus {
    let status: CloudKitSyncStatus
    let progress: Double
    let phase: SyncPhase
    let estimatedTimeRemaining: TimeInterval?
    let throughputMetrics: ThroughputMetrics?
    let networkStatus: NetworkStatus
    let lastUpdateTime: Date
}

// MARK: - 详细同步进度
struct DetailedSyncProgress {
    let overallProgress: Double
    let phaseProgress: Double
    let recordsProcessed: Int
    let totalRecords: Int
    let currentOperation: String
    let bytesTransferred: Int64
    let totalBytes: Int64
}

// MARK: - 网络状态
enum NetworkStatus {
    case unknown
    case disconnected
    case connected
    case limited
    
    var description: String {
        switch self {
        case .unknown:
            return "未知"
        case .disconnected:
            return "已断开"
        case .connected:
            return "已连接"
        case .limited:
            return "受限连接"
        }
    }
}

// MARK: - 同步历史条目
struct SyncHistoryEntry: Codable {
    let id = UUID()
    let timestamp: Date
    let event: MonitoringSyncEvent
    let details: [String: String] // 简化为String以支持Codable
    
    init(timestamp: Date, event: MonitoringSyncEvent, details: [String: Any]) {
        self.timestamp = timestamp
        self.event = event
        // 转换details为String字典
        self.details = details.mapValues { "\($0)" }
    }
}

// MARK: - 监控专用同步事件
enum MonitoringSyncEvent: Codable {
    case statusChanged(from: CloudKitSyncStatus, to: CloudKitSyncStatus)
    case phaseChanged(from: SyncPhase, to: SyncPhase)
    case progressMilestone(progress: Double)
    case warning(String)
    case error(String)
    
    private enum CodingKeys: String, CodingKey {
        case type, fromStatus, toStatus, fromPhase, toPhase, progress, message
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "statusChanged":
            let from = try container.decode(String.self, forKey: .fromStatus)
            let to = try container.decode(String.self, forKey: .toStatus)
            self = .statusChanged(from: .idle, to: .idle) // 简化实现
        case "phaseChanged":
            let from = try container.decode(String.self, forKey: .fromPhase)
            let to = try container.decode(String.self, forKey: .toPhase)
            self = .phaseChanged(from: .idle, to: .idle) // 简化实现
        case "progressMilestone":
            let progress = try container.decode(Double.self, forKey: .progress)
            self = .progressMilestone(progress: progress)
        case "warning":
            let message = try container.decode(String.self, forKey: .message)
            self = .warning(message)
        case "error":
            let message = try container.decode(String.self, forKey: .message)
            self = .error(message)
        default:
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unknown event type")
            )
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .statusChanged(let from, let to):
            try container.encode("statusChanged", forKey: .type)
            try container.encode("\(from)", forKey: .fromStatus)
            try container.encode("\(to)", forKey: .toStatus)
        case .phaseChanged(let from, let to):
            try container.encode("phaseChanged", forKey: .type)
            try container.encode(from.description, forKey: .fromPhase)
            try container.encode(to.description, forKey: .toPhase)
        case .progressMilestone(let progress):
            try container.encode("progressMilestone", forKey: .type)
            try container.encode(progress, forKey: .progress)
        case .warning(let message):
            try container.encode("warning", forKey: .type)
            try container.encode(message, forKey: .message)
        case .error(let message):
            try container.encode("error", forKey: .type)
            try container.encode(message, forKey: .message)
        }
    }
}