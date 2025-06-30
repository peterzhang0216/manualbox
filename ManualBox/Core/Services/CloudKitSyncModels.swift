//
//  CloudKitSyncModels.swift
//  ManualBox
//
//  Created by Assistant on 2025/6/24.
//

import Foundation
import CloudKit
import CoreData

// MARK: - 同步详情
struct SyncDetails: Sendable {
    let startTime: Date
    let endTime: Date?
    let totalRecords: Int
    let processedRecords: Int
    let failedRecords: Int
    let conflictedRecords: Int
    let syncType: SyncType
    let phase: SyncPhase
    
    enum SyncType {
        case full
        case incremental
        case conflictResolution
    }
    
    enum SyncPhase {
        case preparing
        case uploading
        case downloading
        case processing
        case resolving
        case completed
        case failed
    }
    
    var progress: Double {
        guard totalRecords > 0 else { return 0.0 }
        return Double(processedRecords) / Double(totalRecords)
    }
    
    var duration: TimeInterval? {
        guard let endTime = endTime else { return nil }
        return endTime.timeIntervalSince(startTime)
    }
    
    var isCompleted: Bool {
        phase == .completed || phase == .failed
    }
}

// MARK: - 同步冲突和冲突解决策略已移至CloudKitSyncTypes.swift和CloudKitConflictResolver.swift

// MARK: - 冲突解决结果
enum ConflictResolution {
    case useLocal
    case useServer
    case useLatest
    case merged(CKRecord)
    case skip
    case retry
}

// MARK: - ChangeTokenStore 已移至 CloudKitChangeTokenStore.swift

// MARK: - 冲突解决器
class ConflictResolver: @unchecked Sendable {
    private var strategy: ConflictResolutionStrategy = .lastModifiedWins
    
    func setStrategy(_ strategy: ConflictResolutionStrategy) {
        self.strategy = strategy
    }
    
    func resolve(_ conflict: SyncConflict) async -> ConflictResolution {
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
            // 在实际实现中，这里会显示UI让用户选择
            return resolveByTimestamp(conflict)
        }
    }
    
    private func resolveByTimestamp(_ conflict: SyncConflict) -> ConflictResolution {
        guard let localRecord = conflict.localRecord,
              let serverRecord = conflict.serverRecord else {
            return .useServer
        }
        
        let localModified = localRecord.modificationDate ?? Date.distantPast
        let serverModified = serverRecord.modificationDate ?? Date.distantPast
        
        return localModified > serverModified ? .useLocal : .useServer
    }
    
    private func attemptMerge(_ conflict: SyncConflict) async -> ConflictResolution {
        guard let localRecord = conflict.localRecord,
              let serverRecord = conflict.serverRecord else {
            return .useServer
        }
        
        // 尝试智能合并
        let mergedRecord = serverRecord.copy() as! CKRecord
        
        // 合并非冲突字段
        for key in localRecord.allKeys() {
            if !isConflictingField(key, local: localRecord, server: serverRecord) {
                mergedRecord[key] = localRecord[key]
            }
        }
        
        return .merged(mergedRecord)
    }
    
    private func isConflictingField(_ key: String, local: CKRecord, server: CKRecord) -> Bool {
        let localValue = local[key]
        let serverValue = server[key]
        
        // 简单的值比较
        if let localString = localValue as? String,
           let serverString = serverValue as? String {
            return localString != serverString
        }
        
        if let localDate = localValue as? Date,
           let serverDate = serverValue as? Date {
            return abs(localDate.timeIntervalSince(serverDate)) > 1.0 // 1秒容差
        }
        
        return false
    }
}

// MARK: - CloudKitSyncError 已移至 CloudKitSyncService.swift

// MARK: - CloudKitSyncConfiguration 已移至 CloudKitSyncConfiguration.swift

// MARK: - CKRecord Extension
extension CKRecord {
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [:]
        for key in allKeys() {
            dict[key] = self[key]
        }
        return dict
    }
}

// MARK: - SyncHistoryItem 已移至 CloudKitSyncTypes.swift

// MARK: - 同步错误记录已移至CloudKitSyncTypes.swift

// MARK: - 同步状态扩展
extension CloudKitSyncStatus {
    var description: String {
        switch self {
        case .idle: return "空闲"
        case .syncing: return "同步中"
        case .paused: return "已暂停"
        case .completed: return "已完成"
        case .failed: return "失败"
        }
    }
}
