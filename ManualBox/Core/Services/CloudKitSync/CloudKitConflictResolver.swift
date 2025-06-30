//
//  CloudKitConflictResolver.swift
//  ManualBox
//
//  Created by Assistant on 2024/12/19.
//

import Foundation
import CloudKit
import CoreData

// MARK: - 冲突解决策略
public enum ConflictResolutionStrategy {
    case serverWins      // 服务器优先
    case clientWins      // 客户端优先
    case lastModifiedWins // 最后修改时间优先
    case merge           // 合并策略
    case manual          // 手动解决
}

// MARK: - 冲突信息
struct ConflictInfo {
    let recordID: CKRecord.ID
    let localRecord: CKRecord?
    let serverRecord: CKRecord
    let conflictedFields: [String]
    let strategy: ConflictResolutionStrategy
    let timestamp: Date
}

// MARK: - 冲突解决器
class CloudKitConflictResolver {
    private let context: NSManagedObjectContext
    private let defaultStrategy: ConflictResolutionStrategy
    
    init(context: NSManagedObjectContext, defaultStrategy: ConflictResolutionStrategy = .lastModifiedWins) {
        self.context = context
        self.defaultStrategy = defaultStrategy
    }
    
    // MARK: - 主要冲突解决方法
    
    func resolveConflict(
        localRecord: CKRecord?,
        serverRecord: CKRecord,
        strategy: ConflictResolutionStrategy? = nil
    ) -> CKRecord {
        let resolveStrategy = strategy ?? defaultStrategy
        
        print("🔄 解决冲突: \(serverRecord.recordID.recordName) - 策略: \(resolveStrategy)")
        
        switch resolveStrategy {
        case .serverWins:
            return resolveServerWins(localRecord: localRecord, serverRecord: serverRecord)
        case .clientWins:
            return resolveClientWins(localRecord: localRecord, serverRecord: serverRecord)
        case .lastModifiedWins:
            return resolveLastModifiedWins(localRecord: localRecord, serverRecord: serverRecord)
        case .merge:
            return resolveMerge(localRecord: localRecord, serverRecord: serverRecord)
        case .manual:
            return resolveManual(localRecord: localRecord, serverRecord: serverRecord)
        }
    }
    
    // MARK: - 具体解决策略实现
    
    private func resolveServerWins(localRecord: CKRecord?, serverRecord: CKRecord) -> CKRecord {
        print("📥 采用服务器版本: \(serverRecord.recordID.recordName)")
        return serverRecord
    }
    
    private func resolveClientWins(localRecord: CKRecord?, serverRecord: CKRecord) -> CKRecord {
        guard let localRecord = localRecord else {
            print("⚠️ 本地记录不存在，采用服务器版本")
            return serverRecord
        }
        
        print("📤 采用客户端版本: \(localRecord.recordID.recordName)")
        
        // 保持服务器的系统字段，使用本地的数据字段
        let resolvedRecord = serverRecord.copy() as! CKRecord
        
        // 复制本地记录的所有非系统字段
        for key in localRecord.allKeys() {
            if !isSystemField(key) {
                resolvedRecord[key] = localRecord[key]
            }
        }
        
        return resolvedRecord
    }
    
    private func resolveLastModifiedWins(localRecord: CKRecord?, serverRecord: CKRecord) -> CKRecord {
        guard let localRecord = localRecord,
              let localModified = localRecord.modificationDate,
              let serverModified = serverRecord.modificationDate else {
            print("📥 无法比较修改时间，采用服务器版本")
            return serverRecord
        }
        
        if localModified > serverModified {
            print("📤 本地版本更新，采用客户端版本: \(localRecord.recordID.recordName)")
            return resolveClientWins(localRecord: localRecord, serverRecord: serverRecord)
        } else {
            print("📥 服务器版本更新，采用服务器版本: \(serverRecord.recordID.recordName)")
            return serverRecord
        }
    }
    
    private func resolveMerge(localRecord: CKRecord?, serverRecord: CKRecord) -> CKRecord {
        guard let localRecord = localRecord else {
            print("📥 本地记录不存在，采用服务器版本")
            return serverRecord
        }
        
        print("🔀 合并记录: \(serverRecord.recordID.recordName)")
        
        let mergedRecord = serverRecord.copy() as! CKRecord
        
        // 根据字段类型进行智能合并
        for key in localRecord.allKeys() {
            if !isSystemField(key) {
                let localValue = localRecord[key]
                let serverValue = serverRecord[key]
                
                let mergedValue = mergeFieldValues(
                    localValue: localValue,
                    serverValue: serverValue,
                    fieldName: key
                )
                
                mergedRecord[key] = mergedValue
            }
        }
        
        return mergedRecord
    }
    
    private func resolveManual(localRecord: CKRecord?, serverRecord: CKRecord) -> CKRecord {
        // 对于手动解决，这里先返回服务器版本
        // 实际应用中应该提供UI让用户选择
        print("👤 需要手动解决冲突，暂时采用服务器版本: \(serverRecord.recordID.recordName)")
        
        // 可以在这里发送通知，让UI层处理
        NotificationCenter.default.post(
            name: .manualConflictResolutionRequired,
            object: ConflictInfo(
                recordID: serverRecord.recordID,
                localRecord: localRecord,
                serverRecord: serverRecord,
                conflictedFields: getConflictedFields(localRecord: localRecord, serverRecord: serverRecord),
                strategy: .manual,
                timestamp: Date()
            )
        )
        
        return serverRecord
    }
    
    // MARK: - 辅助方法
    
    private func isSystemField(_ fieldName: String) -> Bool {
        let systemFields = [
            "recordID", "recordType", "creationDate", "creatorUserRecordID",
            "modificationDate", "lastModifiedUserRecordID", "recordChangeTag"
        ]
        return systemFields.contains(fieldName)
    }
    
    private func mergeFieldValues(localValue: CKRecordValue?, serverValue: CKRecordValue?, fieldName: String) -> CKRecordValue? {
        // 如果其中一个值为空，使用非空值
        if localValue == nil { return serverValue }
        if serverValue == nil { return localValue }
        
        // 根据字段类型进行特殊处理
        switch fieldName {
        case "tags":
            // 对于标签，合并两个数组
            return mergeArrayValues(localValue: localValue, serverValue: serverValue)
        case "notes", "description":
            // 对于文本字段，选择更长的版本
            return mergeLongerText(localValue: localValue, serverValue: serverValue)
        default:
            // 默认使用本地值
            return localValue
        }
    }
    
    private func mergeArrayValues(localValue: CKRecordValue?, serverValue: CKRecordValue?) -> CKRecordValue? {
        guard let localArray = localValue as? [String],
              let serverArray = serverValue as? [String] else {
            return localValue ?? serverValue
        }
        
        let mergedSet = Set(localArray).union(Set(serverArray))
        return Array(mergedSet) as CKRecordValue
    }
    
    private func mergeLongerText(localValue: CKRecordValue?, serverValue: CKRecordValue?) -> CKRecordValue? {
        guard let localText = localValue as? String,
              let serverText = serverValue as? String else {
            return localValue ?? serverValue
        }
        
        return localText.count >= serverText.count ? localText : serverText
    }
    
    private func getConflictedFields(localRecord: CKRecord?, serverRecord: CKRecord) -> [String] {
        guard let localRecord = localRecord else { return [] }
        
        var conflictedFields: [String] = []
        
        for key in localRecord.allKeys() {
            if !isSystemField(key) {
                let localValue = localRecord[key]
                let serverValue = serverRecord[key]
                
                if !areValuesEqual(localValue, serverValue) {
                    conflictedFields.append(key)
                }
            }
        }
        
        return conflictedFields
    }
    
    private func areValuesEqual(_ value1: CKRecordValue?, _ value2: CKRecordValue?) -> Bool {
        if value1 == nil && value2 == nil { return true }
        if value1 == nil || value2 == nil { return false }
        
        // 这里需要根据具体的值类型进行比较
        // 简化实现，使用字符串比较
        return String(describing: value1) == String(describing: value2)
    }
}

// MARK: - 通知扩展
extension Notification.Name {
    static let manualConflictResolutionRequired = Notification.Name("ManualConflictResolutionRequired")
}