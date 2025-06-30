//
//  CloudKitSyncConfiguration.swift
//  ManualBox
//
//  Created by Assistant on 2024/12/19.
//

import Foundation
import CloudKit

// MARK: - CloudKit同步配置
struct CloudKitSyncConfiguration {
    let containerIdentifier: String
    let enableSync: Bool
    let syncInterval: TimeInterval
    let maxRetryAttempts: Int
    let batchSize: Int
    let enableConflictResolution: Bool
    let enableIncrementalSync: Bool
    
    static let `default` = CloudKitSyncConfiguration(
        containerIdentifier: "iCloud.com.yourcompany.ManualBox",
        enableSync: true,
        syncInterval: 300, // 5分钟
        maxRetryAttempts: 3,
        batchSize: 100,
        enableConflictResolution: true,
        enableIncrementalSync: true
    )
    
    static let testing = CloudKitSyncConfiguration(
        containerIdentifier: "iCloud.com.yourcompany.ManualBox.testing",
        enableSync: false,
        syncInterval: 60,
        maxRetryAttempts: 1,
        batchSize: 10,
        enableConflictResolution: false,
        enableIncrementalSync: false
    )
}

// MARK: - 同步阶段枚举
enum SyncPhase {
    case idle
    case downloading
    case processing
    case uploading
    case resolving
    case completed
    
    var description: String {
        switch self {
        case .idle:
            return "空闲"
        case .downloading:
            return "下载中"
        case .processing:
            return "处理中"
        case .uploading:
            return "上传中"
        case .resolving:
            return "解决冲突中"
        case .completed:
            return "已完成"
        }
    }
}

// MARK: - SyncDetails已移至CloudKitSyncModels.swift