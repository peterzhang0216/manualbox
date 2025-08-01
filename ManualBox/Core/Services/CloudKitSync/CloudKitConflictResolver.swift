//
//  CloudKitConflictResolver.swift
//  ManualBox
//
//  Created by Assistant on 2024/12/19.
//  智能CloudKit冲突解决器
//

import Foundation
import CloudKit
import CoreData
import Combine

// MARK: - 同步冲突模型
// SyncConflict is defined in CloudKitSyncTypes.swift

// MARK: - 冲突类型
enum ConflictType {
    case dataConflict      // 数据字段冲突
    case deleteConflict    // 删除冲突（一方删除，一方修改）
    case createConflict    // 创建冲突（同时创建相同记录）
    case versionConflict   // 版本冲突
    
    var description: String {
        switch self {
        case .dataConflict:
            return "数据冲突"
        case .deleteConflict:
            return "删除冲突"
        case .createConflict:
            return "创建冲突"
        case .versionConflict:
            return "版本冲突"
        }
    }
}

// MARK: - 字段冲突
struct FieldConflict {
    let fieldName: String
    let localValue: Any?
    let serverValue: Any?
    let conflictSeverity: ConflictSeverity
    
    enum ConflictSeverity {
        case low      // 可自动解决
        case medium   // 建议用户确认
        case high     // 需要用户决定
        
        var description: String {
            switch self {
            case .low: return "轻微"
            case .medium: return "中等"
            case .high: return "严重"
            }
        }
    }
}

// MARK: - 冲突解决策略
enum ConflictResolutionStrategy {
    case clientWins           // 客户端优先
    case serverWins          // 服务器优先
    case lastModifiedWins    // 最后修改时间优先
    case merge               // 智能合并
    case manual              // 手动解决
    case fieldByField        // 逐字段解决
    
    var description: String {
        switch self {
        case .clientWins:
            return "客户端优先"
        case .serverWins:
            return "服务器优先"
        case .lastModifiedWins:
            return "最后修改优先"
        case .merge:
            return "智能合并"
        case .manual:
            return "手动解决"
        case .fieldByField:
            return "逐字段解决"
        }
    }
}

// MARK: - 冲突解决结果
struct CloudKitConflictResolutionResult {
    let conflict: SyncConflict
    let resolution: ConflictResolution
    let resolvedRecord: CKRecord?
    let strategy: ConflictResolutionStrategy
    let resolvedAt: Date
    let notes: String?
}

// MARK: - 冲突解决选择
enum ConflictResolution {
    case useLocal
    case useServer
    case useLatest
    case merged(CKRecord)
    case skip
    case retry
    case delete
    
    var description: String {
        switch self {
        case .useLocal:
            return "使用本地版本"
        case .useServer:
            return "使用服务器版本"
        case .useLatest:
            return "使用最新版本"
        case .merged:
            return "使用合并版本"
        case .skip:
            return "跳过"
        case .retry:
            return "重试"
        case .delete:
            return "删除"
        }
    }
}

// MARK: - 智能冲突解决器
@MainActor
class CloudKitConflictResolver: ObservableObject {
    
    // MARK: - Published Properties
    @Published private(set) var pendingConflicts: [SyncConflict] = []
    @Published private(set) var resolvedConflicts: [ConflictResolutionResult] = []
    @Published private(set) var defaultStrategy: ConflictResolutionStrategy = .lastModifiedWins
    @Published private(set) var autoResolveEnabled = true
    
    // MARK: - Dependencies
    private let context: NSManagedObjectContext
    private let performanceMonitor: PerformanceMonitoringService
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Configuration
    private let conflictAnalyzer = ConflictAnalyzer()
    private let mergeEngine = RecordMergeEngine()
    
    // MARK: - Initialization
    init(
        context: NSManagedObjectContext,
        performanceMonitor: PerformanceMonitoringService = ManualBoxPerformanceMonitoringService.shared
    ) {
        self.context = context
        self.performanceMonitor = performanceMonitor
        
        setupConfiguration()
    }
    
    // MARK: - Public Methods
    
    func detectConflict(localRecord: CKRecord?, serverRecord: CKRecord?, recordID: CKRecord.ID) -> SyncConflict? {
        let operationToken = performanceMonitor.startOperation("conflict_detection")
        defer { performanceMonitor.endOperation(operationToken) }
        
        guard let conflict = conflictAnalyzer.analyzeConflict(
            localRecord: localRecord,
            serverRecord: serverRecord,
            recordID: recordID
        ) else {
            return nil
        }
        
        print("🔍 检测到冲突: \(conflict.recordType) - \(conflict.conflictType.description)")
        return conflict
    }
    
    func addConflict(_ conflict: SyncConflict) {
        pendingConflicts.append(conflict)
        
        // 如果启用自动解决，尝试自动解决
        if autoResolveEnabled && canAutoResolve(conflict) {
            Task {
                await autoResolveConflict(conflict)
            }
        }
    }
    
    func resolveConflict(
        _ conflict: SyncConflict,
        strategy: ConflictResolutionStrategy
    ) async -> ConflictResolutionResult {
        let operationToken = performanceMonitor.startOperation("conflict_resolution")
        defer { performanceMonitor.endOperation(operationToken) }
        
        print("🔧 开始解决冲突: \(conflict.recordID.recordName) 使用策略: \(strategy.description)")
        
        let resolution = await performResolution(conflict: conflict, strategy: strategy)
        let resolvedRecord = await createResolvedRecord(conflict: conflict, resolution: resolution)
        
        let result = ConflictResolutionResult(
            conflict: conflict,
            resolution: resolution,
            resolvedRecord: resolvedRecord,
            strategy: strategy,
            resolvedAt: Date(),
            notes: nil
        )
        
        // 从待解决列表中移除
        pendingConflicts.removeAll { $0.id == conflict.id }
        
        // 添加到已解决列表
        resolvedConflicts.append(result)
        
        print("✅ 冲突解决完成: \(resolution.description)")
        return result
    }
    
    func resolveConflict(
        localRecord: CKRecord?,
        serverRecord: CKRecord?,
        strategy: ConflictResolutionStrategy
    ) -> CKRecord {
        // 兼容性方法，保持与现有代码的兼容性
        guard let serverRecord = serverRecord else {
            return localRecord ?? CKRecord(recordType: "Unknown")
        }
        
        guard let localRecord = localRecord else {
            return serverRecord
        }
        
        switch strategy {
        case .clientWins:
            return localRecord
        case .serverWins:
            return serverRecord
        case .lastModifiedWins:
            let localModified = localRecord.modificationDate ?? Date.distantPast
            let serverModified = serverRecord.modificationDate ?? Date.distantPast
            return localModified > serverModified ? localRecord : serverRecord
        case .merge:
            return mergeEngine.mergeRecords(local: localRecord, server: serverRecord)
        default:
            return serverRecord
        }
    }
    
    func resolveAllConflicts(strategy: ConflictResolutionStrategy) async {
        let conflicts = pendingConflicts
        
        for conflict in conflicts {
            await resolveConflict(conflict, strategy: strategy)
        }
    }
    
    func suggestResolutionStrategy(for conflict: SyncConflict) -> ConflictResolutionStrategy {
        return conflictAnalyzer.suggestStrategy(for: conflict)
    }
    
    func setDefaultStrategy(_ strategy: ConflictResolutionStrategy) {
        defaultStrategy = strategy
    }
    
    func setAutoResolveEnabled(_ enabled: Bool) {
        autoResolveEnabled = enabled
    }
    
    func clearResolvedConflicts() {
        resolvedConflicts.removeAll()
    }
    
    // MARK: - Private Methods
    
    private func setupConfiguration() {
        // 设置默认配置
        conflictAnalyzer.configure(
            sensitiveFields: ["name", "title", "content"],
            ignoredFields: ["modificationDate", "creationDate"],
            mergeableFields: ["tags", "notes", "metadata"]
        )
    }
    
    private func canAutoResolve(_ conflict: SyncConflict) -> Bool {
        // 检查是否可以自动解决
        switch conflict.conflictType {
        case .dataConflict:
            // 只有轻微冲突才自动解决
            return conflict.fieldConflicts.allSatisfy { $0.conflictSeverity == .low }
        case .versionConflict:
            return true
        case .deleteConflict, .createConflict:
            return false
        }
    }
    
    private func autoResolveConflict(_ conflict: SyncConflict) async {
        let suggestedStrategy = suggestResolutionStrategy(for: conflict)
        await resolveConflict(conflict, strategy: suggestedStrategy)
    }
    
    private func performResolution(
        conflict: SyncConflict,
        strategy: ConflictResolutionStrategy
    ) async -> ConflictResolution {
        switch strategy {
        case .clientWins:
            return .useLocal
            
        case .serverWins:
            return .useServer
            
        case .lastModifiedWins:
            return resolveByTimestamp(conflict)
            
        case .merge:
            return await attemptMerge(conflict)
            
        case .manual:
            // 在实际UI中，这里会等待用户选择
            return resolveByTimestamp(conflict)
            
        case .fieldByField:
            return await resolveFieldByField(conflict)
        }
    }
    
    private func resolveByTimestamp(_ conflict: SyncConflict) -> ConflictResolution {
        guard let localRecord = conflict.localRecord,
              let serverRecord = conflict.serverRecord else {
            return conflict.localRecord != nil ? .useLocal : .useServer
        }
        
        let localModified = localRecord.modificationDate ?? Date.distantPast
        let serverModified = serverRecord.modificationDate ?? Date.distantPast
        
        return localModified > serverModified ? .useLocal : .useServer
    }
    
    private func attemptMerge(_ conflict: SyncConflict) async -> ConflictResolution {
        guard let localRecord = conflict.localRecord,
              let serverRecord = conflict.serverRecord else {
            return conflict.localRecord != nil ? .useLocal : .useServer
        }
        
        let mergedRecord = mergeEngine.mergeRecords(local: localRecord, server: serverRecord)
        return .merged(mergedRecord)
    }
    
    private func resolveFieldByField(_ conflict: SyncConflict) async -> ConflictResolution {
        guard let localRecord = conflict.localRecord,
              let serverRecord = conflict.serverRecord else {
            return conflict.localRecord != nil ? .useLocal : .useServer
        }
        
        let mergedRecord = serverRecord.copy() as! CKRecord
        
        // 对每个冲突字段应用智能解决策略
        for fieldConflict in conflict.fieldConflicts {
            let resolvedValue = resolveFieldConflict(fieldConflict, local: localRecord, server: serverRecord)
            mergedRecord[fieldConflict.fieldName] = resolvedValue
        }
        
        return .merged(mergedRecord)
    }
    
    private func resolveFieldConflict(
        _ fieldConflict: FieldConflict,
        local: CKRecord,
        server: CKRecord
    ) -> Any? {
        switch fieldConflict.conflictSeverity {
        case .low:
            // 自动选择最新的值
            let localModified = local.modificationDate ?? Date.distantPast
            let serverModified = server.modificationDate ?? Date.distantPast
            return localModified > serverModified ? fieldConflict.localValue : fieldConflict.serverValue
            
        case .medium:
            // 尝试智能合并
            return mergeEngine.mergeFieldValues(
                fieldName: fieldConflict.fieldName,
                localValue: fieldConflict.localValue,
                serverValue: fieldConflict.serverValue
            )
            
        case .high:
            // 保守选择服务器值
            return fieldConflict.serverValue
        }
    }
    
    private func createResolvedRecord(
        conflict: SyncConflict,
        resolution: ConflictResolution
    ) async -> CKRecord? {
        switch resolution {
        case .useLocal:
            return conflict.localRecord
        case .useServer:
            return conflict.serverRecord
        case .useLatest:
            return resolveByTimestamp(conflict) == .useLocal ? conflict.localRecord : conflict.serverRecord
        case .merged(let record):
            return record
        case .skip, .retry, .delete:
            return nil
        }
    }
}

// MARK: - 冲突分析器
class ConflictAnalyzer {
    private var sensitiveFields: Set<String> = []
    private var ignoredFields: Set<String> = []
    private var mergeableFields: Set<String> = []
    
    func configure(sensitiveFields: [String], ignoredFields: [String], mergeableFields: [String]) {
        self.sensitiveFields = Set(sensitiveFields)
        self.ignoredFields = Set(ignoredFields)
        self.mergeableFields = Set(mergeableFields)
    }
    
    func analyzeConflict(
        localRecord: CKRecord?,
        serverRecord: CKRecord?,
        recordID: CKRecord.ID
    ) -> SyncConflict? {
        // 确定冲突类型
        let conflictType = determineConflictType(local: localRecord, server: serverRecord)
        
        guard conflictType != nil else { return nil }
        
        // 分析字段冲突
        let fieldConflicts = analyzeFieldConflicts(local: localRecord, server: serverRecord)
        
        return SyncConflict(
            recordID: recordID,
            recordType: serverRecord?.recordType ?? localRecord?.recordType ?? "Unknown",
            localRecord: localRecord,
            serverRecord: serverRecord,
            conflictType: conflictType!,
            detectedAt: Date(),
            fieldConflicts: fieldConflicts
        )
    }
    
    func suggestStrategy(for conflict: SyncConflict) -> ConflictResolutionStrategy {
        switch conflict.conflictType {
        case .dataConflict:
            // 根据冲突严重程度建议策略
            let hasHighSeverityConflicts = conflict.fieldConflicts.contains { $0.conflictSeverity == .high }
            return hasHighSeverityConflicts ? .manual : .merge
            
        case .versionConflict:
            return .lastModifiedWins
            
        case .deleteConflict:
            return .manual
            
        case .createConflict:
            return .merge
        }
    }
    
    private func determineConflictType(local: CKRecord?, server: CKRecord?) -> ConflictType? {
        switch (local, server) {
        case (nil, nil):
            return nil // 没有冲突
        case (nil, _):
            return .createConflict // 服务器有，本地没有
        case (_, nil):
            return .deleteConflict // 本地有，服务器没有
        case (let localRecord?, let serverRecord?):
            // 检查是否有数据冲突
            if hasDataConflicts(local: localRecord, server: serverRecord) {
                return .dataConflict
            } else if hasVersionConflicts(local: localRecord, server: serverRecord) {
                return .versionConflict
            } else {
                return nil // 没有冲突
            }
        }
    }
    
    private func hasDataConflicts(local: CKRecord, server: CKRecord) -> Bool {
        let allKeys = Set(local.allKeys()).union(Set(server.allKeys()))
        
        for key in allKeys {
            if ignoredFields.contains(key) { continue }
            
            let localValue = local[key]
            let serverValue = server[key]
            
            if !areValuesEqual(localValue, serverValue) {
                return true
            }
        }
        
        return false
    }
    
    private func hasVersionConflicts(local: CKRecord, server: CKRecord) -> Bool {
        // 检查记录版本是否冲突
        return local.recordChangeTag != server.recordChangeTag
    }
    
    private func analyzeFieldConflicts(local: CKRecord?, server: CKRecord?) -> [FieldConflict] {
        guard let local = local, let server = server else { return [] }
        
        var conflicts: [FieldConflict] = []
        let allKeys = Set(local.allKeys()).union(Set(server.allKeys()))
        
        for key in allKeys {
            if ignoredFields.contains(key) { continue }
            
            let localValue = local[key]
            let serverValue = server[key]
            
            if !areValuesEqual(localValue, serverValue) {
                let severity = determineSeverity(for: key, localValue: localValue, serverValue: serverValue)
                
                conflicts.append(FieldConflict(
                    fieldName: key,
                    localValue: localValue,
                    serverValue: serverValue,
                    conflictSeverity: severity
                ))
            }
        }
        
        return conflicts
    }
    
    private func determineSeverity(for fieldName: String, localValue: Any?, serverValue: Any?) -> FieldConflict.ConflictSeverity {
        if sensitiveFields.contains(fieldName) {
            return .high
        }
        
        if mergeableFields.contains(fieldName) {
            return .low
        }
        
        // 根据值类型和差异程度判断
        if let localString = localValue as? String,
           let serverString = serverValue as? String {
            let similarity = calculateStringSimilarity(localString, serverString)
            if similarity > 0.8 {
                return .low
            } else if similarity > 0.5 {
                return .medium
            } else {
                return .high
            }
        }
        
        return .medium
    }
    
    private func areValuesEqual(_ value1: Any?, _ value2: Any?) -> Bool {
        switch (value1, value2) {
        case (nil, nil):
            return true
        case (let str1 as String, let str2 as String):
            return str1 == str2
        case (let date1 as Date, let date2 as Date):
            return abs(date1.timeIntervalSince(date2)) < 1.0 // 1秒容差
        case (let num1 as NSNumber, let num2 as NSNumber):
            return num1 == num2
        default:
            return false
        }
    }
    
    private func calculateStringSimilarity(_ str1: String, _ str2: String) -> Double {
        // 简单的字符串相似度计算
        let longer = str1.count > str2.count ? str1 : str2
        let shorter = str1.count > str2.count ? str2 : str1
        
        if longer.isEmpty { return 1.0 }
        
        let editDistance = levenshteinDistance(shorter, longer)
        return (Double(longer.count) - Double(editDistance)) / Double(longer.count)
    }
    
    private func levenshteinDistance(_ str1: String, _ str2: String) -> Int {
        let str1Array = Array(str1)
        let str2Array = Array(str2)
        let str1Count = str1Array.count
        let str2Count = str2Array.count
        
        var matrix = Array(repeating: Array(repeating: 0, count: str2Count + 1), count: str1Count + 1)
        
        for i in 0...str1Count {
            matrix[i][0] = i
        }
        
        for j in 0...str2Count {
            matrix[0][j] = j
        }
        
        for i in 1...str1Count {
            for j in 1...str2Count {
                let cost = str1Array[i-1] == str2Array[j-1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i-1][j] + 1,      // deletion
                    matrix[i][j-1] + 1,      // insertion
                    matrix[i-1][j-1] + cost  // substitution
                )
            }
        }
        
        return matrix[str1Count][str2Count]
    }
}

// MARK: - 记录合并引擎
class RecordMergeEngine {
    
    func mergeRecords(local: CKRecord, server: CKRecord) -> CKRecord {
        let mergedRecord = server.copy() as! CKRecord
        
        // 获取所有字段
        let allKeys = Set(local.allKeys()).union(Set(server.allKeys()))
        
        for key in allKeys {
            let mergedValue = mergeFieldValues(
                fieldName: key,
                localValue: local[key],
                serverValue: server[key]
            )
            mergedRecord[key] = mergedValue
        }
        
        return mergedRecord
    }
    
    func mergeFieldValues(fieldName: String, localValue: Any?, serverValue: Any?) -> Any? {
        switch (localValue, serverValue) {
        case (nil, let serverVal):
            return serverVal
        case (let localVal, nil):
            return localVal
        case (let localStr as String, let serverStr as String):
            return mergeStrings(local: localStr, server: serverStr)
        case (let localDate as Date, let serverDate as Date):
            return localDate > serverDate ? localDate : serverDate
        case (let localNum as NSNumber, let serverNum as NSNumber):
            return mergeNumbers(local: localNum, server: serverNum)
        case (let localArray as [Any], let serverArray as [Any]):
            return mergeArrays(local: localArray, server: serverArray)
        default:
            // 默认使用服务器值
            return serverValue
        }
    }
    
    private func mergeStrings(local: String, server: String) -> String {
        // 如果字符串相似度很高，选择较长的
        if local.contains(server) {
            return local
        } else if server.contains(local) {
            return server
        } else {
            // 选择较新的（这里简化为较长的）
            return local.count > server.count ? local : server
        }
    }
    
    private func mergeNumbers(local: NSNumber, server: NSNumber) -> NSNumber {
        // 选择较大的数值（可根据业务需求调整）
        return local.doubleValue > server.doubleValue ? local : server
    }
    
    private func mergeArrays(local: [Any], server: [Any]) -> [Any] {
        // 合并数组，去重
        var merged = local
        for item in server {
            if !containsItem(merged, item) {
                merged.append(item)
            }
        }
        return merged
    }
    
    private func containsItem(_ array: [Any], _ item: Any) -> Bool {
        // 简化的包含检查
        for element in array {
            if String(describing: element) == String(describing: item) {
                return true
            }
        }
        return false
    }
}