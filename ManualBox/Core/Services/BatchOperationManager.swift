//
//  BatchOperationManager.swift
//  ManualBox
//
//  Created by Assistant on 2024/12/19.
//  批量操作管理器 - 处理批量编辑、导出等操作
//

import SwiftUI
import CoreData
import Combine

// MARK: - 批量操作类型
enum BatchOperationType: String, CaseIterable {
    case export = "export"
    case edit = "edit"
    case delete = "delete"
    case duplicate = "duplicate"
    case categorize = "categorize"
    case tag = "tag"
    
    var displayName: String {
        switch self {
        case .export: return "导出"
        case .edit: return "编辑"
        case .delete: return "删除"
        case .duplicate: return "复制"
        case .categorize: return "分类"
        case .tag: return "标签"
        }
    }
    
    var icon: String {
        switch self {
        case .export: return "square.and.arrow.up"
        case .edit: return "pencil"
        case .delete: return "trash"
        case .duplicate: return "doc.on.doc"
        case .categorize: return "folder"
        case .tag: return "tag"
        }
    }
}

// MARK: - 批量操作状态
enum BatchOperationStatus {
    case idle
    case preparing
    case running(progress: Double)
    case completed(success: Int, failed: Int)
    case cancelled
    case failed(error: Error)
    
    var isRunning: Bool {
        switch self {
        case .preparing, .running: return true
        default: return false
        }
    }
}

// MARK: - 批量操作结果
struct BatchOperationResult {
    let operationType: BatchOperationType
    let totalItems: Int
    let successCount: Int
    let failedCount: Int
    let errors: [Error]
    let duration: TimeInterval
    let startTime: Date
    let endTime: Date
    
    var successRate: Double {
        guard totalItems > 0 else { return 0 }
        return Double(successCount) / Double(totalItems)
    }
    
    var isSuccessful: Bool {
        return failedCount == 0
    }
}

// MARK: - 批量操作管理器
@MainActor
class BatchOperationManager: ObservableObject {
    
    // MARK: - Singleton
    static let shared = BatchOperationManager()
    
    // MARK: - Published Properties
    @Published private(set) var currentOperation: BatchOperationType?
    @Published private(set) var operationStatus: BatchOperationStatus = .idle
    @Published private(set) var operationProgress: Double = 0.0
    @Published private(set) var currentItemIndex: Int = 0
    @Published private(set) var totalItems: Int = 0
    @Published private(set) var operationHistory: [BatchOperationResult] = []
    @Published private(set) var estimatedTimeRemaining: TimeInterval = 0
    
    // MARK: - Internal State
    private var cancellationToken: AnyCancellable?
    private var operationStartTime: Date?
    private var performanceMonitor = ManualBoxPerformanceMonitoringService.shared
    
    // MARK: - Initialization
    private init() {
        loadOperationHistory()
    }
    
    // MARK: - Public Methods
    
    /// 执行批量导出操作
    func performBatchExport<T: NSManagedObject>(
        items: [T],
        format: ExportFormat,
        destination: URL
    ) async throws -> BatchOperationResult {
        return try await performBatchOperation(
            type: .export,
            items: items
        ) { item, index in
            // 导出单个项目
            try await exportSingleItem(item, format: format, destination: destination, index: index)
        }
    }
    
    /// 执行批量编辑操作
    func performBatchEdit<T: NSManagedObject>(
        items: [T],
        editAction: @escaping (T) throws -> Void
    ) async throws -> BatchOperationResult {
        return try await performBatchOperation(
            type: .edit,
            items: items
        ) { item, _ in
            try editAction(item)
        }
    }
    
    /// 执行批量删除操作
    func performBatchDelete<T: NSManagedObject>(
        items: [T],
        context: NSManagedObjectContext
    ) async throws -> BatchOperationResult {
        return try await performBatchOperation(
            type: .delete,
            items: items
        ) { item, _ in
            context.delete(item)
        }
    }
    
    /// 执行批量复制操作
    func performBatchDuplicate<T: NSManagedObject>(
        items: [T],
        context: NSManagedObjectContext,
        duplicateAction: @escaping (T, NSManagedObjectContext) throws -> T
    ) async throws -> BatchOperationResult {
        return try await performBatchOperation(
            type: .duplicate,
            items: items
        ) { item, _ in
            _ = try duplicateAction(item, context)
        }
    }
    
    /// 执行批量分类操作
    func performBatchCategorize<T: NSManagedObject>(
        items: [T],
        category: Category,
        assignAction: @escaping (T, Category) throws -> Void
    ) async throws -> BatchOperationResult {
        return try await performBatchOperation(
            type: .categorize,
            items: items
        ) { item, _ in
            try assignAction(item, category)
        }
    }
    
    /// 执行批量标签操作
    func performBatchTag<T: NSManagedObject>(
        items: [T],
        tags: [Tag],
        assignAction: @escaping (T, [Tag]) throws -> Void
    ) async throws -> BatchOperationResult {
        return try await performBatchOperation(
            type: .tag,
            items: items
        ) { item, _ in
            try assignAction(item, tags)
        }
    }
    
    /// 取消当前操作
    func cancelCurrentOperation() {
        guard operationStatus.isRunning else { return }
        
        cancellationToken?.cancel()
        operationStatus = .cancelled
        currentOperation = nil
        
        print("📦 批量操作已取消")
    }
    
    /// 获取操作历史
    func getOperationHistory(for type: BatchOperationType? = nil) -> [BatchOperationResult] {
        if let type = type {
            return operationHistory.filter { $0.operationType == type }
        }
        return operationHistory
    }
    
    /// 清除操作历史
    func clearOperationHistory() {
        operationHistory.removeAll()
        saveOperationHistory()
    }
    
    /// 获取操作统计信息
    func getOperationStatistics() -> BatchOperationStatistics {
        let totalOperations = operationHistory.count
        let successfulOperations = operationHistory.filter { $0.isSuccessful }.count
        let totalItemsProcessed = operationHistory.reduce(0) { $0 + $1.totalItems }
        let totalSuccessfulItems = operationHistory.reduce(0) { $0 + $1.successCount }
        let averageDuration = operationHistory.isEmpty ? 0 : 
            operationHistory.reduce(0) { $0 + $1.duration } / Double(operationHistory.count)
        
        return BatchOperationStatistics(
            totalOperations: totalOperations,
            successfulOperations: successfulOperations,
            totalItemsProcessed: totalItemsProcessed,
            totalSuccessfulItems: totalSuccessfulItems,
            averageDuration: averageDuration,
            operationsByType: Dictionary(grouping: operationHistory) { $0.operationType }
        )
    }
    
    // MARK: - Private Methods
    
    private func performBatchOperation<T>(
        type: BatchOperationType,
        items: [T],
        operation: @escaping (T, Int) async throws -> Void
    ) async throws -> BatchOperationResult {
        
        // 检查是否已有操作在进行
        guard !operationStatus.isRunning else {
            throw BatchOperationError.operationInProgress
        }
        
        // 初始化操作状态
        currentOperation = type
        operationStatus = .preparing
        totalItems = items.count
        currentItemIndex = 0
        operationProgress = 0.0
        operationStartTime = Date()
        
        print("📦 开始批量\(type.displayName)操作，共\(items.count)个项目")
        
        // 开始性能监控
        let performanceToken = performanceMonitor.startOperation("batch_\(type.rawValue)")
        
        var successCount = 0
        var errors: [Error] = []
        let startTime = Date()
        
        do {
            operationStatus = .running(progress: 0.0)
            
            // 创建取消令牌
            cancellationToken = AnyCancellable {
                print("📦 批量操作取消令牌被触发")
            }
            
            // 执行批量操作
            for (index, item) in items.enumerated() {
                // 检查是否被取消
                if cancellationToken?.isCancelled == true {
                    operationStatus = .cancelled
                    break
                }
                
                do {
                    // 执行单个操作
                    try await operation(item, index)
                    successCount += 1
                } catch {
                    errors.append(error)
                    print("📦 处理项目\(index)时出错: \(error.localizedDescription)")
                }
                
                // 更新进度
                currentItemIndex = index + 1
                operationProgress = Double(currentItemIndex) / Double(totalItems)
                
                // 估算剩余时间
                let elapsed = Date().timeIntervalSince(startTime)
                let averageTimePerItem = elapsed / Double(currentItemIndex)
                estimatedTimeRemaining = averageTimePerItem * Double(totalItems - currentItemIndex)
                
                operationStatus = .running(progress: operationProgress)
                
                // 短暂延迟以允许UI更新
                try await Task.sleep(nanoseconds: 10_000_000) // 10ms
            }
            
            let endTime = Date()
            let duration = endTime.timeIntervalSince(startTime)
            
            // 创建操作结果
            let result = BatchOperationResult(
                operationType: type,
                totalItems: items.count,
                successCount: successCount,
                failedCount: errors.count,
                errors: errors,
                duration: duration,
                startTime: startTime,
                endTime: endTime
            )
            
            // 更新状态
            if cancellationToken?.isCancelled == true {
                operationStatus = .cancelled
            } else {
                operationStatus = .completed(success: successCount, failed: errors.count)
            }
            
            // 保存到历史记录
            operationHistory.append(result)
            saveOperationHistory()
            
            // 结束性能监控
            performanceMonitor.endOperation(performanceToken)
            
            print("📦 批量\(type.displayName)操作完成: 成功\(successCount)个，失败\(errors.count)个")
            
            // 重置状态
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.currentOperation = nil
                self.operationStatus = .idle
                self.operationProgress = 0.0
                self.currentItemIndex = 0
                self.totalItems = 0
                self.estimatedTimeRemaining = 0
            }
            
            return result
            
        } catch {
            operationStatus = .failed(error: error)
            performanceMonitor.endOperation(performanceToken)
            
            print("📦 批量\(type.displayName)操作失败: \(error.localizedDescription)")
            
            // 重置状态
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.currentOperation = nil
                self.operationStatus = .idle
                self.operationProgress = 0.0
                self.currentItemIndex = 0
                self.totalItems = 0
                self.estimatedTimeRemaining = 0
            }
            
            throw error
        }
    }
    
    private func exportSingleItem<T: NSManagedObject>(
        _ item: T,
        format: ExportFormat,
        destination: URL,
        index: Int
    ) async throws {
        // 根据格式导出单个项目
        switch format {
        case .csv:
            try await exportToCSV(item, destination: destination, index: index)
        case .json:
            try await exportToJSON(item, destination: destination, index: index)
        case .pdf:
            try await exportToPDF(item, destination: destination, index: index)
        }
    }
    
    private func exportToCSV<T: NSManagedObject>(_ item: T, destination: URL, index: Int) async throws {
        // CSV导出实现
        // 这里应该根据具体的数据模型实现CSV导出逻辑
        print("📦 导出项目\(index)到CSV格式")
    }
    
    private func exportToJSON<T: NSManagedObject>(_ item: T, destination: URL, index: Int) async throws {
        // JSON导出实现
        print("📦 导出项目\(index)到JSON格式")
    }
    
    private func exportToPDF<T: NSManagedObject>(_ item: T, destination: URL, index: Int) async throws {
        // PDF导出实现
        print("📦 导出项目\(index)到PDF格式")
    }
    
    private func loadOperationHistory() {
        // 从UserDefaults加载操作历史
        if let data = UserDefaults.standard.data(forKey: "BatchOperationHistory"),
           let history = try? JSONDecoder().decode([BatchOperationResult].self, from: data) {
            operationHistory = history
        }
    }
    
    private func saveOperationHistory() {
        // 保存操作历史到UserDefaults
        if let data = try? JSONEncoder().encode(operationHistory) {
            UserDefaults.standard.set(data, forKey: "BatchOperationHistory")
        }
    }
}

// ExportFormat is defined in Core/Utils/ExportFormat.swift

// MARK: - 批量操作错误
enum BatchOperationError: LocalizedError {
    case operationInProgress
    case invalidItems
    case exportFailed(reason: String)
    case editFailed(reason: String)
    case insufficientPermissions
    
    var errorDescription: String? {
        switch self {
        case .operationInProgress:
            return "已有批量操作正在进行中"
        case .invalidItems:
            return "选择的项目无效"
        case .exportFailed(let reason):
            return "导出失败: \(reason)"
        case .editFailed(let reason):
            return "编辑失败: \(reason)"
        case .insufficientPermissions:
            return "权限不足"
        }
    }
}

// MARK: - 批量操作统计
struct BatchOperationStatistics {
    let totalOperations: Int
    let successfulOperations: Int
    let totalItemsProcessed: Int
    let totalSuccessfulItems: Int
    let averageDuration: TimeInterval
    let operationsByType: [BatchOperationType: [BatchOperationResult]]
    
    var successRate: Double {
        guard totalOperations > 0 else { return 0 }
        return Double(successfulOperations) / Double(totalOperations)
    }
    
    var itemSuccessRate: Double {
        guard totalItemsProcessed > 0 else { return 0 }
        return Double(totalSuccessfulItems) / Double(totalItemsProcessed)
    }
}

// MARK: - Codable支持
extension BatchOperationResult: Codable {
    enum CodingKeys: String, CodingKey {
        case operationType, totalItems, successCount, failedCount
        case duration, startTime, endTime
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        operationType = try container.decode(BatchOperationType.self, forKey: .operationType)
        totalItems = try container.decode(Int.self, forKey: .totalItems)
        successCount = try container.decode(Int.self, forKey: .successCount)
        failedCount = try container.decode(Int.self, forKey: .failedCount)
        duration = try container.decode(TimeInterval.self, forKey: .duration)
        startTime = try container.decode(Date.self, forKey: .startTime)
        endTime = try container.decode(Date.self, forKey: .endTime)
        errors = [] // 不持久化错误对象
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(operationType, forKey: .operationType)
        try container.encode(totalItems, forKey: .totalItems)
        try container.encode(successCount, forKey: .successCount)
        try container.encode(failedCount, forKey: .failedCount)
        try container.encode(duration, forKey: .duration)
        try container.encode(startTime, forKey: .startTime)
        try container.encode(endTime, forKey: .endTime)
    }
}