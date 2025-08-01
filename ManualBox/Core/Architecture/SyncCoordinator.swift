//
//  SyncCoordinator.swift
//  ManualBox
//
//  Created by Assistant on 2024/12/19.
//  重构的同步协调器 - 统一管理CloudKit同步流程
//

import Foundation
import CloudKit
import CoreData
import Combine
import Network

// MARK: - 同步协调器协议
protocol SyncCoordinator {
    func startSync() async -> SyncResult
    func pauseSync()
    func resumeSync()
    func resolveConflicts(_ conflicts: [SyncConflict]) async -> ConflictResolutionResult
    
    var syncStatus: CloudKitSyncStatus { get }
    var syncProgress: Double { get }
    var syncDetails: SyncDetails? { get }
}

// MARK: - 同步结果
struct SyncResult {
    let success: Bool
    let error: Error?
    let syncedRecords: Int
    let conflictCount: Int
    let duration: TimeInterval
    let syncType: SyncType
}

// MARK: - 冲突解决结果
struct ConflictResolutionResult {
    let resolvedCount: Int
    let failedCount: Int
    let errors: [Error]
}

// MARK: - 同步类型
enum SyncType {
    case full
    case incremental
    case conflictResolution
    case manual
}

// MARK: - 增强的同步协调器实现
@MainActor
class EnhancedSyncCoordinator: SyncCoordinator, ObservableObject {
    
    // MARK: - Published Properties
    @Published private(set) var syncStatus: CloudKitSyncStatus = .idle
    @Published private(set) var syncProgress: Double = 0.0
    @Published private(set) var syncDetails: SyncDetails?
    @Published private(set) var currentPhase: SyncPhase = .idle
    @Published private(set) var estimatedTimeRemaining: TimeInterval?
    @Published private(set) var throughputMetrics: ThroughputMetrics?
    
    // MARK: - Dependencies
    private let cloudKitService: CloudKitSyncService
    private let performanceMonitor: PerformanceMonitoringService
    private let errorHandler: ErrorHandlingService
    private let networkMonitor = NWPathMonitor()
    
    // MARK: - State Management
    private var syncTask: Task<Void, Never>?
    private var isPaused = false
    private var pauseSignal = PassthroughSubject<Void, Never>()
    private var resumeSignal = PassthroughSubject<Void, Never>()
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Performance Tracking
    private var syncStartTime: Date?
    private var phaseStartTime: Date?
    private var recordsProcessed = 0
    private var totalRecordsToProcess = 0
    
    // MARK: - Initialization
    init(
        cloudKitService: CloudKitSyncService = CloudKitSyncService.shared,
        performanceMonitor: PerformanceMonitoringService = ManualBoxPerformanceMonitoringService.shared,
        errorHandler: ErrorHandlingService = ManualBoxErrorHandlingService.shared
    ) {
        self.cloudKitService = cloudKitService
        self.performanceMonitor = performanceMonitor
        self.errorHandler = errorHandler
        
        setupNetworkMonitoring()
        setupSyncStatusObservation()
    }
    
    // MARK: - SyncCoordinator Implementation
    
    nonisolated func startSync() async -> SyncResult {
        return await MainActor.run {
            guard syncStatus != .syncing else {
                return SyncResult(
                    success: false,
                    error: SyncCoordinatorError.syncInProgress,
                    syncedRecords: 0,
                    conflictCount: 0,
                    duration: 0,
                    syncType: .manual
                )
            }
            
            // 取消之前的同步任务
            syncTask?.cancel()
            
            // 开始新的同步任务
            syncTask = Task {
                await performSync()
            }
            
            return SyncResult(
                success: true,
                error: nil,
                syncedRecords: 0,
                conflictCount: 0,
                duration: 0,
                syncType: .manual
            )
        }
    }
    
    nonisolated func pauseSync() {
        guard syncStatus == .syncing else { return }
        
        isPaused = true
        pauseSignal.send()
        
        print("⏸️ 同步已暂停")
    }
    
    nonisolated func resumeSync() {
        guard isPaused else { return }
        
        isPaused = false
        resumeSignal.send()
        
        print("▶️ 同步已恢复")
    }
    
    nonisolated func resolveConflicts(_ conflicts: [SyncConflict]) async -> ConflictResolutionResult {
        return await MainActor.run {
            Task {
                await performConflictResolution(conflicts)
            }
            
            return ConflictResolutionResult(
                resolvedCount: 0,
                failedCount: 0,
                errors: []
            )
        }
    }
    
    // MARK: - Private Sync Implementation
    
    private func performSync() async {
        let operationToken = performanceMonitor.startOperation("full_sync")
        syncStartTime = Date()
        
        do {
            // 初始化同步状态
            await initializeSyncState()
            
            // 阶段1: 下载远程变更
            await updatePhase(.downloading)
            try await performDownloadPhase()
            
            // 检查暂停状态
            try await checkPauseState()
            
            // 阶段2: 处理本地变更
            await updatePhase(.processing)
            try await performProcessingPhase()
            
            // 检查暂停状态
            try await checkPauseState()
            
            // 阶段3: 上传本地变更
            await updatePhase(.uploading)
            try await performUploadPhase()
            
            // 阶段4: 解决冲突
            if await hasConflicts() {
                await updatePhase(.resolving)
                try await performConflictResolutionPhase()
            }
            
            // 完成同步
            await completeSyncSuccessfully()
            
        } catch {
            await handleSyncError(error)
        }
        
        performanceMonitor.endOperation(operationToken)
    }
    
    private func initializeSyncState() async {
        syncStatus = .syncing
        syncProgress = 0.0
        currentPhase = .downloading
        recordsProcessed = 0
        
        syncDetails = SyncDetails(
            startTime: Date(),
            endTime: nil,
            totalRecords: 0,
            processedRecords: 0,
            failedRecords: 0,
            conflictedRecords: 0,
            syncType: .full,
            phase: .downloading
        )
        
        print("🚀 开始同步流程")
    }
    
    private func updatePhase(_ phase: SyncPhase) async {
        currentPhase = phase
        phaseStartTime = Date()
        
        if var details = syncDetails {
            details = SyncDetails(
                startTime: details.startTime,
                endTime: details.endTime,
                totalRecords: details.totalRecords,
                processedRecords: details.processedRecords,
                failedRecords: details.failedRecords,
                conflictedRecords: details.conflictedRecords,
                syncType: details.syncType,
                phase: phase
            )
            syncDetails = details
        }
        
        print("📍 同步阶段: \(phase.description)")
    }
    
    private func performDownloadPhase() async throws {
        let downloadToken = performanceMonitor.startOperation("sync_download")
        
        try await cloudKitService.syncFromCloud()
        
        // 更新进度
        syncProgress = 0.33
        updateThroughputMetrics()
        
        performanceMonitor.endOperation(downloadToken)
        print("✅ 下载阶段完成")
    }
    
    private func performProcessingPhase() async throws {
        let processingToken = performanceMonitor.startOperation("sync_processing")
        
        // 模拟处理延迟以显示进度
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
        
        // 更新进度
        syncProgress = 0.66
        updateThroughputMetrics()
        
        performanceMonitor.endOperation(processingToken)
        print("✅ 处理阶段完成")
    }
    
    private func performUploadPhase() async throws {
        let uploadToken = performanceMonitor.startOperation("sync_upload")
        
        try await cloudKitService.syncToCloud()
        
        // 更新进度
        syncProgress = 0.90
        updateThroughputMetrics()
        
        performanceMonitor.endOperation(uploadToken)
        print("✅ 上传阶段完成")
    }
    
    private func performConflictResolutionPhase() async throws {
        let conflictToken = performanceMonitor.startOperation("sync_conflict_resolution")
        
        try await cloudKitService.resolveConflicts()
        
        performanceMonitor.endOperation(conflictToken)
        print("✅ 冲突解决阶段完成")
    }
    
    private func performConflictResolution(_ conflicts: [SyncConflict]) async -> ConflictResolutionResult {
        var resolvedCount = 0
        var failedCount = 0
        var errors: [Error] = []
        
        for conflict in conflicts {
            do {
                try await cloudKitService.resolveConflict(conflict, strategy: .lastModifiedWins)
                resolvedCount += 1
            } catch {
                failedCount += 1
                errors.append(error)
            }
        }
        
        return ConflictResolutionResult(
            resolvedCount: resolvedCount,
            failedCount: failedCount,
            errors: errors
        )
    }
    
    private func completeSyncSuccessfully() async {
        syncStatus = .completed
        syncProgress = 1.0
        currentPhase = .completed
        
        let duration = Date().timeIntervalSince(syncStartTime ?? Date())
        
        if var details = syncDetails {
            details = SyncDetails(
                startTime: details.startTime,
                endTime: Date(),
                totalRecords: details.totalRecords,
                processedRecords: recordsProcessed,
                failedRecords: details.failedRecords,
                conflictedRecords: details.conflictedRecords,
                syncType: details.syncType,
                phase: .completed
            )
            syncDetails = details
        }
        
        print("🎉 同步成功完成，耗时: \(String(format: "%.2f", duration))秒")
    }
    
    private func handleSyncError(_ error: Error) async {
        syncStatus = .failed(error)
        currentPhase = .idle
        
        await errorHandler.handle(error, context: ErrorContext(
            operation: "sync_coordination",
            component: "SyncCoordinator",
            additionalInfo: [
                "phase": currentPhase.description,
                "progress": syncProgress
            ]
        ))
        
        print("❌ 同步失败: \(error.localizedDescription)")
    }
    
    // MARK: - Helper Methods
    
    private func checkPauseState() async throws {
        if isPaused {
            print("⏸️ 同步暂停中...")
            
            // 等待恢复信号
            await withCheckedContinuation { continuation in
                resumeSignal
                    .first()
                    .sink { _ in
                        continuation.resume()
                    }
                    .store(in: &cancellables)
            }
            
            print("▶️ 同步已恢复")
        }
    }
    
    private func hasConflicts() async -> Bool {
        return cloudKitService.pendingConflictsPublic.count > 0
    }
    
    private func updateThroughputMetrics() {
        guard let startTime = syncStartTime else { return }
        
        let elapsed = Date().timeIntervalSince(startTime)
        let recordsPerSecond = elapsed > 0 ? Double(recordsProcessed) / elapsed : 0
        
        throughputMetrics = ThroughputMetrics(
            recordsPerSecond: recordsPerSecond,
            bytesPerSecond: 0, // 需要实际实现
            averageLatency: elapsed / max(1, Double(recordsProcessed))
        )
        
        // 估算剩余时间
        if recordsPerSecond > 0 && totalRecordsToProcess > recordsProcessed {
            let remainingRecords = totalRecordsToProcess - recordsProcessed
            estimatedTimeRemaining = Double(remainingRecords) / recordsPerSecond
        }
    }
    
    // MARK: - Network Monitoring
    
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                if path.status != .satisfied && self?.syncStatus == .syncing {
                    self?.pauseSync()
                    print("📶 网络断开，同步已暂停")
                } else if path.status == .satisfied && self?.isPaused == true {
                    self?.resumeSync()
                    print("📶 网络恢复，同步已恢复")
                }
            }
        }
        
        let queue = DispatchQueue(label: "SyncCoordinator.NetworkMonitor")
        networkMonitor.start(queue: queue)
    }
    
    private func setupSyncStatusObservation() {
        // 观察CloudKit服务的状态变化
        cloudKitService.$syncStatus
            .sink { [weak self] status in
                // 同步状态变化处理
                self?.handleCloudKitStatusChange(status)
            }
            .store(in: &cancellables)
    }
    
    private func handleCloudKitStatusChange(_ status: CloudKitSyncStatus) {
        // 根据CloudKit服务状态更新协调器状态
        switch status {
        case .idle:
            if syncStatus == .syncing {
                // CloudKit服务完成，但协调器可能还在处理其他阶段
                break
            }
        case .syncing:
            break
        case .paused:
            // 处理暂停状态
            break
        case .completed:
            break
        case .failed(let error):
            Task {
                await handleSyncError(error)
            }
        }
    }
    
    deinit {
        networkMonitor.cancel()
        syncTask?.cancel()
    }
}

// MARK: - 吞吐量指标
struct ThroughputMetrics {
    let recordsPerSecond: Double
    let bytesPerSecond: Double
    let averageLatency: TimeInterval
}

// MARK: - 同步协调器错误
enum SyncCoordinatorError: LocalizedError {
    case syncInProgress
    case syncPaused
    case networkUnavailable
    case invalidState
    
    var errorDescription: String? {
        switch self {
        case .syncInProgress:
            return "同步正在进行中"
        case .syncPaused:
            return "同步已暂停"
        case .networkUnavailable:
            return "网络不可用"
        case .invalidState:
            return "无效的同步状态"
        }
    }
}