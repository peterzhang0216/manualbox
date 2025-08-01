//
//  SyncPriorityManager.swift
//  ManualBox
//
//  Created by Assistant on 2024/12/19.
//  同步优先级管理器 - 智能管理同步任务的优先级和调度
//

import Foundation
import CloudKit
import CoreData
import Combine

// MARK: - 同步优先级
enum SyncPriority: Int, CaseIterable, Comparable {
    case critical = 0    // 关键数据，立即同步
    case high = 1       // 高优先级，优先同步
    case normal = 2     // 正常优先级
    case low = 3        // 低优先级，延迟同步
    case background = 4 // 后台同步
    
    var description: String {
        switch self {
        case .critical: return "关键"
        case .high: return "高"
        case .normal: return "正常"
        case .low: return "低"
        case .background: return "后台"
        }
    }
    
    var color: String {
        switch self {
        case .critical: return "red"
        case .high: return "orange"
        case .normal: return "blue"
        case .low: return "gray"
        case .background: return "secondary"
        }
    }
    
    static func < (lhs: SyncPriority, rhs: SyncPriority) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

// MARK: - 同步任务
struct SyncTask: Identifiable, Comparable {
    let id = UUID()
    let recordType: String
    let recordID: CKRecord.ID
    let operation: SyncOperation
    let priority: SyncPriority
    let createdAt: Date
    let estimatedSize: Int64
    let dependencies: [UUID]
    let metadata: [String: Any]
    
    static func < (lhs: SyncTask, rhs: SyncTask) -> Bool {
        // 首先按优先级排序
        if lhs.priority != rhs.priority {
            return lhs.priority < rhs.priority
        }
        
        // 相同优先级按创建时间排序
        return lhs.createdAt < rhs.createdAt
    }
    
    static func == (lhs: SyncTask, rhs: SyncTask) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - 同步操作类型
enum SyncOperation {
    case upload(CKRecord)
    case download(CKRecord.ID)
    case delete(CKRecord.ID)
    case resolve(SyncConflict)
    
    var description: String {
        switch self {
        case .upload: return "上传"
        case .download: return "下载"
        case .delete: return "删除"
        case .resolve: return "解决冲突"
        }
    }
    
    var estimatedDuration: TimeInterval {
        switch self {
        case .upload: return 2.0
        case .download: return 1.5
        case .delete: return 1.0
        case .resolve: return 3.0
        }
    }
}

// MARK: - 同步优先级管理器
@MainActor
class SyncPriorityManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published private(set) var taskQueue: [SyncTask] = []
    @Published private(set) var activeTasks: [SyncTask] = []
    @Published private(set) var completedTasks: [SyncTask] = []
    @Published private(set) var failedTasks: [SyncTask] = []
    @Published private(set) var queueStatistics: QueueStatistics?
    
    // MARK: - Configuration
    @Published var maxConcurrentTasks = 3
    @Published var priorityBoostEnabled = true
    @Published var adaptiveSchedulingEnabled = true
    
    // MARK: - Dependencies
    private let performanceMonitor: PerformanceMonitoringService
    private let networkMonitor = NetworkMonitor()
    
    // MARK: - Internal State
    private var taskScheduler: TaskScheduler
    private var priorityAnalyzer: PriorityAnalyzer
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init(performanceMonitor: PerformanceMonitoringService = ManualBoxPerformanceMonitoringService.shared) {
        self.performanceMonitor = performanceMonitor
        self.taskScheduler = TaskScheduler()
        self.priorityAnalyzer = PriorityAnalyzer()
        
        setupScheduling()
        setupNetworkMonitoring()
    }
    
    // MARK: - Public Methods
    
    func addTask(_ task: SyncTask) {
        print("📋 添加同步任务: \(task.recordType) - \(task.priority.description)")
        
        // 检查是否需要优先级提升
        let adjustedTask = priorityBoostEnabled ? priorityAnalyzer.adjustPriority(task) : task
        
        // 插入到队列中的正确位置
        insertTaskInQueue(adjustedTask)
        
        // 更新统计信息
        updateQueueStatistics()
        
        // 触发调度
        scheduleNextTasks()
    }
    
    func removeTask(_ taskID: UUID) {
        taskQueue.removeAll { $0.id == taskID }
        activeTasks.removeAll { $0.id == taskID }
        
        updateQueueStatistics()
        scheduleNextTasks()
        
        print("🗑️ 移除同步任务: \(taskID)")
    }
    
    func updateTaskPriority(_ taskID: UUID, newPriority: SyncPriority) {
        if let index = taskQueue.firstIndex(where: { $0.id == taskID }) {
            var task = taskQueue[index]
            taskQueue.remove(at: index)
            
            // 创建新的任务实例（因为priority是let）
            let updatedTask = SyncTask(
                recordType: task.recordType,
                recordID: task.recordID,
                operation: task.operation,
                priority: newPriority,
                createdAt: task.createdAt,
                estimatedSize: task.estimatedSize,
                dependencies: task.dependencies,
                metadata: task.metadata
            )
            
            insertTaskInQueue(updatedTask)
            updateQueueStatistics()
            scheduleNextTasks()
            
            print("🔄 更新任务优先级: \(taskID) -> \(newPriority.description)")
        }
    }
    
    func pauseScheduling() {
        taskScheduler.pause()
        print("⏸️ 暂停任务调度")
    }
    
    func resumeScheduling() {
        taskScheduler.resume()
        scheduleNextTasks()
        print("▶️ 恢复任务调度")
    }
    
    func clearCompletedTasks() {
        completedTasks.removeAll()
        updateQueueStatistics()
        print("🧹 清除已完成任务")
    }
    
    func clearFailedTasks() {
        failedTasks.removeAll()
        updateQueueStatistics()
        print("🧹 清除失败任务")
    }
    
    func retryFailedTasks() {
        let tasksToRetry = failedTasks
        failedTasks.removeAll()
        
        for task in tasksToRetry {
            addTask(task)
        }
        
        print("🔄 重试 \(tasksToRetry.count) 个失败任务")
    }
    
    func getTasksByPriority(_ priority: SyncPriority) -> [SyncTask] {
        return taskQueue.filter { $0.priority == priority }
    }
    
    func getEstimatedCompletionTime() -> TimeInterval {
        let totalDuration = taskQueue.reduce(0) { $0 + $1.operation.estimatedDuration }
        let concurrentFactor = Double(maxConcurrentTasks)
        return totalDuration / concurrentFactor
    }
    
    // MARK: - Private Methods
    
    private func setupScheduling() {
        taskScheduler.onTaskCompleted = { [weak self] task, success in
            Task { @MainActor in
                self?.handleTaskCompletion(task, success: success)
            }
        }
        
        taskScheduler.onTaskStarted = { [weak self] task in
            Task { @MainActor in
                self?.handleTaskStarted(task)
            }
        }
    }
    
    private func setupNetworkMonitoring() {
        networkMonitor.$networkQuality
            .sink { [weak self] quality in
                self?.adjustSchedulingForNetworkQuality(quality)
            }
            .store(in: &cancellables)
    }
    
    private func insertTaskInQueue(_ task: SyncTask) {
        // 检查依赖关系
        if !task.dependencies.isEmpty {
            let dependenciesMet = task.dependencies.allSatisfy { depID in
                completedTasks.contains { $0.id == depID }
            }
            
            if !dependenciesMet {
                // 依赖未满足，降低优先级或延迟
                print("⏳ 任务依赖未满足，延迟执行: \(task.id)")
                // 这里可以实现依赖等待逻辑
            }
        }
        
        // 使用二分查找插入到正确位置
        let insertIndex = taskQueue.insertionIndex(of: task)
        taskQueue.insert(task, at: insertIndex)
    }
    
    private func scheduleNextTasks() {
        guard taskScheduler.canScheduleMore(maxConcurrent: maxConcurrentTasks) else {
            return
        }
        
        let availableSlots = maxConcurrentTasks - activeTasks.count
        let tasksToSchedule = Array(taskQueue.prefix(availableSlots))
        
        for task in tasksToSchedule {
            if let index = taskQueue.firstIndex(where: { $0.id == task.id }) {
                taskQueue.remove(at: index)
                taskScheduler.scheduleTask(task)
            }
        }
    }
    
    private func handleTaskStarted(_ task: SyncTask) {
        activeTasks.append(task)
        updateQueueStatistics()
        
        print("🚀 开始执行任务: \(task.recordType) - \(task.priority.description)")
    }
    
    private func handleTaskCompletion(_ task: SyncTask, success: Bool) {
        activeTasks.removeAll { $0.id == task.id }
        
        if success {
            completedTasks.append(task)
            print("✅ 任务完成: \(task.recordType)")
        } else {
            failedTasks.append(task)
            print("❌ 任务失败: \(task.recordType)")
        }
        
        updateQueueStatistics()
        scheduleNextTasks()
    }
    
    private func updateQueueStatistics() {
        let totalTasks = taskQueue.count + activeTasks.count + completedTasks.count + failedTasks.count
        let priorityDistribution = Dictionary(grouping: taskQueue, by: { $0.priority })
            .mapValues { $0.count }
        
        queueStatistics = QueueStatistics(
            totalTasks: totalTasks,
            queuedTasks: taskQueue.count,
            activeTasks: activeTasks.count,
            completedTasks: completedTasks.count,
            failedTasks: failedTasks.count,
            priorityDistribution: priorityDistribution,
            estimatedCompletionTime: getEstimatedCompletionTime(),
            averageTaskDuration: calculateAverageTaskDuration(),
            lastUpdated: Date()
        )
    }
    
    private func calculateAverageTaskDuration() -> TimeInterval {
        guard !completedTasks.isEmpty else { return 0 }
        
        let totalDuration = completedTasks.reduce(0) { $0 + $1.operation.estimatedDuration }
        return totalDuration / Double(completedTasks.count)
    }
    
    private func adjustSchedulingForNetworkQuality(_ quality: NetworkQuality) {
        switch quality {
        case .excellent, .good:
            maxConcurrentTasks = 5
        case .fair:
            maxConcurrentTasks = 3
        case .poor:
            maxConcurrentTasks = 1
        case .unavailable:
            pauseScheduling()
            return
        }
        
        if taskScheduler.isPaused {
            resumeScheduling()
        }
        
        print("📶 根据网络质量调整并发数: \(maxConcurrentTasks)")
    }
}

// MARK: - 任务调度器
class TaskScheduler {
    private var isScheduling = true
    private var runningTasks: Set<UUID> = []
    
    var onTaskStarted: ((SyncTask) -> Void)?
    var onTaskCompleted: ((SyncTask, Bool) -> Void)?
    
    var isPaused: Bool { !isScheduling }
    
    func canScheduleMore(maxConcurrent: Int) -> Bool {
        return isScheduling && runningTasks.count < maxConcurrent
    }
    
    func scheduleTask(_ task: SyncTask) {
        guard isScheduling else { return }
        
        runningTasks.insert(task.id)
        onTaskStarted?(task)
        
        // 模拟异步任务执行
        Task {
            do {
                try await Task.sleep(nanoseconds: UInt64(task.operation.estimatedDuration * 1_000_000_000))
                
                await MainActor.run {
                    self.runningTasks.remove(task.id)
                    self.onTaskCompleted?(task, true)
                }
            } catch {
                await MainActor.run {
                    self.runningTasks.remove(task.id)
                    self.onTaskCompleted?(task, false)
                }
            }
        }
    }
    
    func pause() {
        isScheduling = false
    }
    
    func resume() {
        isScheduling = true
    }
}

// MARK: - 优先级分析器
class PriorityAnalyzer {
    private let criticalRecordTypes: Set<String> = ["User", "Settings"]
    private let highPriorityRecordTypes: Set<String> = ["Product", "Manual"]
    
    func adjustPriority(_ task: SyncTask) -> SyncTask {
        let adjustedPriority = calculateAdjustedPriority(task)
        
        if adjustedPriority != task.priority {
            return SyncTask(
                recordType: task.recordType,
                recordID: task.recordID,
                operation: task.operation,
                priority: adjustedPriority,
                createdAt: task.createdAt,
                estimatedSize: task.estimatedSize,
                dependencies: task.dependencies,
                metadata: task.metadata
            )
        }
        
        return task
    }
    
    private func calculateAdjustedPriority(_ task: SyncTask) -> SyncPriority {
        var priority = task.priority
        
        // 基于记录类型调整
        if criticalRecordTypes.contains(task.recordType) {
            priority = min(priority, .critical)
        } else if highPriorityRecordTypes.contains(task.recordType) {
            priority = min(priority, .high)
        }
        
        // 基于操作类型调整
        switch task.operation {
        case .resolve:
            priority = min(priority, .high) // 冲突解决优先级较高
        case .delete:
            priority = min(priority, .normal) // 删除操作正常优先级
        default:
            break
        }
        
        // 基于时间调整（老任务提升优先级）
        let age = Date().timeIntervalSince(task.createdAt)
        if age > 3600 { // 1小时
            priority = SyncPriority(rawValue: max(0, priority.rawValue - 1)) ?? priority
        }
        
        return priority
    }
}

// MARK: - 网络监控器
class NetworkMonitor: ObservableObject {
    @Published var networkQuality: NetworkQuality = .good
    
    // 简化实现，实际应该监控真实网络状态
    init() {
        // 模拟网络质量变化
        Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            self.networkQuality = NetworkQuality.allCases.randomElement() ?? .good
        }
    }
}

// MARK: - 网络质量
enum NetworkQuality: CaseIterable {
    case excellent
    case good
    case fair
    case poor
    case unavailable
    
    var description: String {
        switch self {
        case .excellent: return "优秀"
        case .good: return "良好"
        case .fair: return "一般"
        case .poor: return "较差"
        case .unavailable: return "不可用"
        }
    }
}

// MARK: - 队列统计
struct QueueStatistics {
    let totalTasks: Int
    let queuedTasks: Int
    let activeTasks: Int
    let completedTasks: Int
    let failedTasks: Int
    let priorityDistribution: [SyncPriority: Int]
    let estimatedCompletionTime: TimeInterval
    let averageTaskDuration: TimeInterval
    let lastUpdated: Date
    
    var completionRate: Double {
        guard totalTasks > 0 else { return 0 }
        return Double(completedTasks) / Double(totalTasks)
    }
    
    var failureRate: Double {
        guard totalTasks > 0 else { return 0 }
        return Double(failedTasks) / Double(totalTasks)
    }
}

// MARK: - Array扩展
extension Array where Element: Comparable {
    func insertionIndex(of element: Element) -> Int {
        var low = 0
        var high = count
        
        while low < high {
            let mid = (low + high) / 2
            if self[mid] < element {
                low = mid + 1
            } else {
                high = mid
            }
        }
        
        return low
    }
}