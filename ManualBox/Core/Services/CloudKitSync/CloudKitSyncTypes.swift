//
//  CloudKitSyncTypes.swift
//  ManualBox
//
//  Created by Assistant on 2024/12/19.
//  CloudKit同步相关类型定义
//

import Foundation
import CloudKit

// MARK: - 同步协议已移至 ServiceProtocol.swift

// MARK: - 同步冲突
struct SyncConflict: Identifiable, Sendable {
    let id = UUID()
    let recordID: CKRecord.ID
    let entityType: String
    let localRecord: CKRecord?
    let serverRecord: CKRecord
    let conflictType: ConflictType
    let timestamp: Date
    
    enum ConflictType {
        case dataConflict      // 数据内容冲突
        case deleteConflict    // 删除冲突
        case typeConflict      // 类型冲突
        case versionConflict   // 版本冲突
    }
    
    var description: String {
        switch conflictType {
        case .dataConflict:
            return "数据内容冲突"
        case .deleteConflict:
            return "删除冲突"
        case .typeConflict:
            return "类型冲突"
        case .versionConflict:
            return "版本冲突"
        }
    }
}

// MARK: - 同步历史项
struct SyncHistoryItem: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let syncType: SyncType
    let status: CloudKitSyncStatus
    let description: String
    let duration: TimeInterval?
    let recordCount: Int
    let conflictCount: Int
    let errorCount: Int
    let dataTransferred: Int64
    let errors: [SyncErrorRecord]
    let detailLog: String

    enum SyncType: String, Codable {
        case manual = "manual"
        case automatic = "automatic"
        case background = "background"
        case conflictResolution = "conflictResolution"

        var description: String {
            switch self {
            case .manual: return "手动同步"
            case .automatic: return "自动同步"
            case .background: return "后台同步"
            case .conflictResolution: return "冲突解决"
            }
        }
    }

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        syncType: SyncType,
        status: CloudKitSyncStatus,
        description: String,
        duration: TimeInterval? = nil,
        recordCount: Int = 0,
        conflictCount: Int = 0,
        errorCount: Int = 0,
        dataTransferred: Int64 = 0,
        errors: [SyncErrorRecord] = [],
        detailLog: String = ""
    ) {
        self.id = id
        self.timestamp = timestamp
        self.syncType = syncType
        self.status = status
        self.description = description
        self.duration = duration
        self.recordCount = recordCount
        self.conflictCount = conflictCount
        self.errorCount = errorCount
        self.dataTransferred = dataTransferred
        self.errors = errors
        self.detailLog = detailLog
    }
}

// MARK: - 同步错误记录
struct SyncErrorRecord: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let message: String
    let details: String?
    let errorCode: String?

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        message: String,
        details: String? = nil,
        errorCode: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.message = message
        self.details = details
        self.errorCode = errorCode
    }
}

// MARK: - 同步进度信息
struct SyncProgressInfo {
    let phase: SyncPhase
    let progress: Double
    let currentOperation: String
    let estimatedTimeRemaining: TimeInterval?
    let processedItems: Int
    let totalItems: Int
    
    var progressPercentage: Int {
        Int(progress * 100)
    }
    
    var isCompleted: Bool {
        progress >= 1.0 || phase == .completed
    }
}

// MARK: - 同步统计信息
struct SyncStatistics {
    let totalSyncs: Int
    let successfulSyncs: Int
    let failedSyncs: Int
    let averageDuration: TimeInterval
    let totalDataTransferred: Int64
    let lastSyncDate: Date?
    let conflictsResolved: Int
    
    var successRate: Double {
        guard totalSyncs > 0 else { return 0.0 }
        return Double(successfulSyncs) / Double(totalSyncs)
    }
    
    var failureRate: Double {
        guard totalSyncs > 0 else { return 0.0 }
        return Double(failedSyncs) / Double(totalSyncs)
    }
}

// MARK: - 同步事件
enum SyncEvent {
    case started(type: SyncType)
    case progressUpdated(progress: Double, phase: SyncPhase)
    case conflictDetected(conflict: SyncConflict)
    case conflictResolved(conflictID: UUID)
    case completed(statistics: SyncStatistics)
    case failed(error: Error)
    case paused
    case resumed
    
    enum SyncType {
        case upload
        case download
        case bidirectional
        case conflictResolution
    }
}

// MARK: - 同步选项
struct SyncOptions {
    let includeImages: Bool
    let includeDocuments: Bool
    let batchSize: Int
    let timeout: TimeInterval
    let retryAttempts: Int
    let conflictResolutionStrategy: ConflictResolutionStrategy
    
    static let `default` = SyncOptions(
        includeImages: true,
        includeDocuments: true,
        batchSize: 100,
        timeout: 300,
        retryAttempts: 3,
        conflictResolutionStrategy: .lastModifiedWins
    )
    
    static let minimal = SyncOptions(
        includeImages: false,
        includeDocuments: false,
        batchSize: 50,
        timeout: 60,
        retryAttempts: 1,
        conflictResolutionStrategy: .serverWins
    )
}

// MARK: - 同步过滤器
struct SyncFilter {
    let recordTypes: [String]?
    let dateRange: DateInterval?
    let modifiedSince: Date?
    let excludeDeleted: Bool
    let maxRecords: Int?
    
    static let all = SyncFilter(
        recordTypes: nil,
        dateRange: nil,
        modifiedSince: nil,
        excludeDeleted: false,
        maxRecords: nil
    )
    
    static func recent(days: Int) -> SyncFilter {
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return SyncFilter(
            recordTypes: nil,
            dateRange: DateInterval(start: startDate, end: Date()),
            modifiedSince: startDate,
            excludeDeleted: true,
            maxRecords: nil
        )
    }
}