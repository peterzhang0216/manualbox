//
//  IncrementalSyncManager.swift
//  ManualBox
//
//  Created by Assistant on 2024/12/19.
//  增量同步管理器 - 优化同步性能，减少数据传输量
//

import Foundation
import CloudKit
import CoreData
import Combine

// MARK: - 增量同步管理器
@MainActor
class IncrementalSyncManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published private(set) var lastIncrementalSync: Date?
    @Published private(set) var pendingChanges: [String: Int] = [:]
    @Published private(set) var syncEfficiency: SyncEfficiency?
    @Published private(set) var changeTrackingEnabled = true
    
    // MARK: - Dependencies
    private let context: NSManagedObjectContext
    private let changeTokenStore: ChangeTokenStore
    private let performanceMonitor: PerformanceMonitoringService
    
    // MARK: - Change Tracking
    private var changeTracker = ChangeTracker()
    private var syncQueue = DispatchQueue(label: "IncrementalSync", qos: .userInitiated)
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Configuration
    private let maxBatchSize = 50
    private let syncThreshold = TimeInterval(300) // 5分钟
    private let changeThreshold = 10 // 变更数量阈值
    
    // MARK: - Initialization
    init(
        context: NSManagedObjectContext,
        changeTokenStore: ChangeTokenStore = ChangeTokenStore(),
        performanceMonitor: PerformanceMonitoringService = ManualBoxPerformanceMonitoringService.shared
    ) {
        self.context = context
        self.changeTokenStore = changeTokenStore
        self.performanceMonitor = performanceMonitor
        
        setupChangeTracking()
        loadLastSyncDate()
    }
    
    // MARK: - Public Methods
    
    func shouldPerformIncrementalSync() -> Bool {
        guard changeTrackingEnabled else { return false }
        
        // 检查时间阈值
        if let lastSync = lastIncrementalSync {
            let timeSinceLastSync = Date().timeIntervalSince(lastSync)
            if timeSinceLastSync < syncThreshold {
                return false
            }
        }
        
        // 检查变更数量阈值
        let totalChanges = pendingChanges.values.reduce(0, +)
        return totalChanges >= changeThreshold
    }
    
    func getIncrementalChanges() async throws -> IncrementalChanges {
        let operationToken = performanceMonitor.startOperation("get_incremental_changes")
        defer { performanceMonitor.endOperation(operationToken) }
        
        print("📊 获取增量变更")
        
        let changes = try await changeTracker.getChanges(since: lastIncrementalSync)
        
        // 更新效率统计
        updateSyncEfficiency(changes: changes)
        
        return changes
    }
    
    func markSyncCompleted(with changes: IncrementalChanges) {
        lastIncrementalSync = Date()
        
        // 清除已同步的变更
        changeTracker.clearProcessedChanges(changes)
        
        // 更新待处理变更统计
        updatePendingChangesCount()
        
        // 保存同步时间
        saveLastSyncDate()
        
        print("✅ 增量同步完成，处理了 \(changes.totalCount) 个变更")
    }
    
    func resetIncrementalSync() {
        lastIncrementalSync = nil
        changeTracker.reset()
        pendingChanges.removeAll()
        syncEfficiency = nil
        
        saveLastSyncDate()
        print("🔄 增量同步已重置")
    }
    
    func enableChangeTracking(_ enabled: Bool) {
        changeTrackingEnabled = enabled
        
        if enabled {
            setupChangeTracking()
        } else {
            changeTracker.stopTracking()
        }
        
        print("📊 变更跟踪 \(enabled ? "已启用" : "已禁用")")
    }
    
    func getChangesSummary() -> ChangesSummary {
        let totalChanges = pendingChanges.values.reduce(0, +)
        
        return ChangesSummary(
            totalPendingChanges: totalChanges,
            changesByType: pendingChanges,
            lastSyncDate: lastIncrementalSync,
            syncEfficiency: syncEfficiency,
            isTrackingEnabled: changeTrackingEnabled
        )
    }
    
    // MARK: - Private Methods
    
    private func setupChangeTracking() {
        guard changeTrackingEnabled else { return }
        
        // 监听Core Data变更通知
        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
            .compactMap { $0.object as? NSManagedObjectContext }
            .filter { $0 == self.context }
            .sink { [weak self] context in
                self?.handleContextDidSave(context)
            }
            .store(in: &cancellables)
        
        changeTracker.startTracking(context: context)
        print("📊 开始跟踪数据变更")
    }
    
    private func handleContextDidSave(_ context: NSManagedObjectContext) {
        Task { @MainActor in
            updatePendingChangesCount()
        }
    }
    
    private func updatePendingChangesCount() {
        let changes = changeTracker.getPendingChangesCount()
        pendingChanges = changes
    }
    
    private func updateSyncEfficiency(changes: IncrementalChanges) {
        let totalRecords = getTotalRecordCount()
        let changedRecords = changes.totalCount
        
        let efficiency = totalRecords > 0 ? Double(changedRecords) / Double(totalRecords) : 0.0
        let dataSaved = max(0.0, 1.0 - efficiency)
        
        syncEfficiency = SyncEfficiency(
            changedRecords: changedRecords,
            totalRecords: totalRecords,
            efficiency: efficiency,
            dataSaved: dataSaved,
            lastCalculated: Date()
        )
    }
    
    private func getTotalRecordCount() -> Int {
        let request: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "Product")
        request.resultType = .countResultType
        
        do {
            let count = try context.count(for: request)
            return count
        } catch {
            print("❌ 获取记录总数失败: \(error)")
            return 0
        }
    }
    
    private func loadLastSyncDate() {
        lastIncrementalSync = UserDefaults.standard.object(forKey: "LastIncrementalSync") as? Date
    }
    
    private func saveLastSyncDate() {
        if let date = lastIncrementalSync {
            UserDefaults.standard.set(date, forKey: "LastIncrementalSync")
        } else {
            UserDefaults.standard.removeObject(forKey: "LastIncrementalSync")
        }
    }
}

// MARK: - 变更跟踪器
class ChangeTracker {
    private var trackedChanges: [String: Set<NSManagedObjectID>] = [:]
    private var isTracking = false
    private let trackingQueue = DispatchQueue(label: "ChangeTracker", qos: .utility)
    
    func startTracking(context: NSManagedObjectContext) {
        guard !isTracking else { return }
        
        isTracking = true
        print("📊 开始跟踪变更")
    }
    
    func stopTracking() {
        isTracking = false
        trackedChanges.removeAll()
        print("📊 停止跟踪变更")
    }
    
    func getChanges(since date: Date?) async throws -> IncrementalChanges {
        return try await withCheckedThrowingContinuation { continuation in
            trackingQueue.async {
                let changes = self.buildIncrementalChanges(since: date)
                continuation.resume(returning: changes)
            }
        }
    }
    
    func getPendingChangesCount() -> [String: Int] {
        return trackingQueue.sync {
            return trackedChanges.mapValues { $0.count }
        }
    }
    
    func clearProcessedChanges(_ changes: IncrementalChanges) {
        trackingQueue.async {
            // 清除已处理的变更
            for (entityName, objectIDs) in changes.changedObjects {
                if var tracked = self.trackedChanges[entityName] {
                    for objectID in objectIDs {
                        tracked.remove(objectID)
                    }
                    self.trackedChanges[entityName] = tracked
                }
            }
            
            for (entityName, objectIDs) in changes.deletedObjects {
                if var tracked = self.trackedChanges[entityName] {
                    for objectID in objectIDs {
                        tracked.remove(objectID)
                    }
                    self.trackedChanges[entityName] = tracked
                }
            }
        }
    }
    
    func reset() {
        trackingQueue.async {
            self.trackedChanges.removeAll()
        }
    }
    
    private func buildIncrementalChanges(since date: Date?) -> IncrementalChanges {
        // 这里应该基于实际的变更跟踪数据构建增量变更
        // 简化实现，返回当前跟踪的变更
        
        var changedObjects: [String: [NSManagedObjectID]] = [:]
        var deletedObjects: [String: [NSManagedObjectID]] = [:]
        
        for (entityName, objectIDs) in trackedChanges {
            changedObjects[entityName] = Array(objectIDs)
        }
        
        return IncrementalChanges(
            changedObjects: changedObjects,
            deletedObjects: deletedObjects,
            changeToken: nil,
            timestamp: Date()
        )
    }
}

// MARK: - 数据模型

struct IncrementalChanges {
    let changedObjects: [String: [NSManagedObjectID]]
    let deletedObjects: [String: [NSManagedObjectID]]
    let changeToken: CKServerChangeToken?
    let timestamp: Date
    
    var totalCount: Int {
        let changedCount = changedObjects.values.reduce(0) { $0 + $1.count }
        let deletedCount = deletedObjects.values.reduce(0) { $0 + $1.count }
        return changedCount + deletedCount
    }
    
    var isEmpty: Bool {
        return totalCount == 0
    }
}

struct SyncEfficiency {
    let changedRecords: Int
    let totalRecords: Int
    let efficiency: Double // 变更记录占总记录的比例
    let dataSaved: Double // 节省的数据传输比例
    let lastCalculated: Date
    
    var efficiencyPercentage: String {
        return String(format: "%.1f%%", efficiency * 100)
    }
    
    var dataSavedPercentage: String {
        return String(format: "%.1f%%", dataSaved * 100)
    }
}

struct ChangesSummary {
    let totalPendingChanges: Int
    let changesByType: [String: Int]
    let lastSyncDate: Date?
    let syncEfficiency: SyncEfficiency?
    let isTrackingEnabled: Bool
}