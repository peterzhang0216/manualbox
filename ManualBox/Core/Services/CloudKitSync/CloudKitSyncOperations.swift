//
//  CloudKitSyncOperations.swift
//  ManualBox
//
//  Created by Assistant on 2024/12/19.
//

import Foundation
import CloudKit

// MARK: - 同步变更结果
struct SyncChangesResult {
    let changedRecords: [CKRecord]
    let deletedRecordIDs: [(recordID: CKRecord.ID, recordType: String)]
    let changeToken: CKServerChangeToken?
    let moreComing: Bool
}

// MARK: - CloudKit同步操作类
class CloudKitSyncOperations {
    private let container: CKContainer
    private let database: CKDatabase
    private let configuration: CloudKitSyncConfiguration
    
    init(container: CKContainer, configuration: CloudKitSyncConfiguration) {
        self.container = container
        self.database = container.privateCloudDatabase
        self.configuration = configuration
    }
    
    // MARK: - 上传操作
    
    func uploadRecords(
        _ records: [CKRecord],
        progressHandler: @escaping (Double) -> Void
    ) async throws {
        guard !records.isEmpty else {
            print("📤 没有记录需要上传")
            return
        }
        
        print("📤 开始上传 \(records.count) 条记录")
        
        // 分批上传
        let batches = records.chunked(into: configuration.batchSize)
        var processedCount = 0
        
        for (index, batch) in batches.enumerated() {
            print("📤 上传批次 \(index + 1)/\(batches.count)，包含 \(batch.count) 条记录")
            
            try await uploadBatch(batch)
            
            processedCount += batch.count
            let progress = Double(processedCount) / Double(records.count)
            progressHandler(progress)
        }
        
        print("✅ 所有记录上传完成")
    }
    
    private func uploadBatch(_ records: [CKRecord]) async throws {
        let operation = CKModifyRecordsOperation(
            recordsToSave: records,
            recordIDsToDelete: nil
        )
        
        operation.savePolicy = .changedKeys
        operation.qualityOfService = .userInitiated
        
        return try await withCheckedThrowingContinuation { continuation in
            operation.modifyRecordsResultBlock = { result in
                switch result {
                case .success():
                    print("✅ 批次上传成功")
                    continuation.resume()
                case .failure(let error):
                    print("❌ 批次上传失败: \(error)")
                    continuation.resume(throwing: error)
                }
            }
            
            operation.perRecordResultBlock = { (recordID: CKRecord.ID, result: Result<CKRecord, Error>) in
                switch result {
                case .success(let record):
                    print("✅ 记录上传成功: \(record.recordID.recordName)")
                case .failure(let error):
                    print("❌ 记录上传失败: \(recordID.recordName) - \(error)")
                }
            }
            
            database.add(operation)
        }
    }
    
    // MARK: - 下载操作
    
    func fetchChanges(
        since token: CKServerChangeToken?,
        progressHandler: @escaping (Double) -> Void
    ) async throws -> SyncChangesResult {
        print("📥 开始获取服务器变更")
        
        if token != nil {
            print("📥 执行增量同步")
            return try await fetchIncrementalChanges(since: token, progressHandler: progressHandler)
        } else {
            print("📥 执行完整同步")
            return try await fetchAllRecords(progressHandler: progressHandler)
        }
    }
    
    private func fetchIncrementalChanges(
        since token: CKServerChangeToken?,
        progressHandler: @escaping (Double) -> Void
    ) async throws -> SyncChangesResult {
        let operation = CKFetchDatabaseChangesOperation(previousServerChangeToken: token)
        operation.fetchAllChanges = true
        operation.qualityOfService = .userInitiated
        
        var changedZoneIDs: [CKRecordZone.ID] = []
        var deletedZoneIDs: [CKRecordZone.ID] = []
        var newToken: CKServerChangeToken?
        
        return try await withCheckedThrowingContinuation { continuation in
            operation.recordZoneWithIDChangedBlock = { zoneID in
                changedZoneIDs.append(zoneID)
                print("📝 发现变更区域: \(zoneID.zoneName)")
            }
            
            operation.recordZoneWithIDWasDeletedBlock = { zoneID in
                deletedZoneIDs.append(zoneID)
                print("🗑️ 发现删除区域: \(zoneID.zoneName)")
            }
            
            operation.changeTokenUpdatedBlock = { token in
                newToken = token
            }
            
            operation.fetchDatabaseChangesResultBlock = { result in
                switch result {
                case .success((let token, let moreComing)):
                    newToken = token
                    
                    Task {
                        do {
                            // 获取区域变更
                            let zoneChanges = try await self.fetchZoneChanges(
                                for: changedZoneIDs,
                                progressHandler: progressHandler
                            )
                            
                            let result = SyncChangesResult(
                                changedRecords: zoneChanges.changedRecords,
                                deletedRecordIDs: zoneChanges.deletedRecordIDs,
                                changeToken: newToken,
                                moreComing: moreComing
                            )
                            
                            continuation.resume(returning: result)
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    }
                    
                case .failure(let error):
                    print("❌ 获取数据库变更失败: \(error)")
                    continuation.resume(throwing: error)
                }
            }
            
            database.add(operation)
        }
    }
    
    private func fetchZoneChanges(
        for zoneIDs: [CKRecordZone.ID],
        progressHandler: @escaping (Double) -> Void
    ) async throws -> (changedRecords: [CKRecord], deletedRecordIDs: [(recordID: CKRecord.ID, recordType: String)]) {
        var allChangedRecords: [CKRecord] = []
        var allDeletedRecordIDs: [(recordID: CKRecord.ID, recordType: String)] = []
        
        for (index, zoneID) in zoneIDs.enumerated() {
            let zoneChanges = try await fetchZoneChanges(for: zoneID)
            allChangedRecords.append(contentsOf: zoneChanges.changedRecords)
            allDeletedRecordIDs.append(contentsOf: zoneChanges.deletedRecordIDs)
            
            let progress = Double(index + 1) / Double(zoneIDs.count)
            progressHandler(progress)
        }
        
        return (allChangedRecords, allDeletedRecordIDs)
    }
    
    private func fetchZoneChanges(
        for zoneID: CKRecordZone.ID
    ) async throws -> (changedRecords: [CKRecord], deletedRecordIDs: [(recordID: CKRecord.ID, recordType: String)]) {
        let operation = CKFetchRecordZoneChangesOperation(recordZoneIDs: [zoneID])
        operation.fetchAllChanges = true
        operation.qualityOfService = .userInitiated
        
        var changedRecords: [CKRecord] = []
        var deletedRecordIDs: [(recordID: CKRecord.ID, recordType: String)] = []
        
        return try await withCheckedThrowingContinuation { continuation in
            operation.recordWasChangedBlock = { recordID, result in
                switch result {
                case .success(let record):
                    changedRecords.append(record)
                    print("📝 记录变更: \(record.recordType) - \(record.recordID.recordName)")
                case .failure(let error):
                    print("❌ 记录变更失败: \(recordID.recordName) - \(error)")
                }
            }
            
            operation.recordWithIDWasDeletedBlock = { recordID, recordType in
                deletedRecordIDs.append((recordID, recordType))
                print("🗑️ 记录删除: \(recordType) - \(recordID.recordName)")
            }
            
            operation.fetchRecordZoneChangesResultBlock = { result in
                switch result {
                case .success():
                    continuation.resume(returning: (changedRecords, deletedRecordIDs))
                case .failure(let error):
                    print("❌ 获取区域变更失败: \(error)")
                    continuation.resume(throwing: error)
                }
            }
            
            database.add(operation)
        }
    }
    
    private func fetchAllRecords(
        progressHandler: @escaping (Double) -> Void
    ) async throws -> SyncChangesResult {
        print("📥 执行完整记录获取")
        
        // 获取所有记录类型
        let recordTypes = ["Product", "Manual", "Category"]
        var allRecords: [CKRecord] = []
        
        for (index, recordType) in recordTypes.enumerated() {
            let records = try await fetchRecords(ofType: recordType)
            allRecords.append(contentsOf: records)
            
            let progress = Double(index + 1) / Double(recordTypes.count)
            progressHandler(progress)
        }
        
        return SyncChangesResult(
            changedRecords: allRecords,
            deletedRecordIDs: [],
            changeToken: nil,
            moreComing: false
        )
    }
    
    private func fetchRecords(ofType recordType: String) async throws -> [CKRecord] {
        let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "modificationDate", ascending: false)]
        
        let operation = CKQueryOperation(query: query)
        operation.qualityOfService = .userInitiated
        operation.resultsLimit = configuration.batchSize
        
        var records: [CKRecord] = []
        
        return try await withCheckedThrowingContinuation { continuation in
            operation.recordMatchedBlock = { recordID, result in
                switch result {
                case .success(let record):
                    records.append(record)
                    print("📥 获取记录: \(record.recordType) - \(record.recordID.recordName)")
                case .failure(let error):
                    print("❌ 获取记录失败: \(recordID.recordName) - \(error)")
                }
            }
            
            operation.queryResultBlock = { result in
                switch result {
                case .success(let cursor):
                    if let cursor = cursor {
                        // 还有更多记录，继续获取
                        Task {
                            do {
                                let moreRecords = try await self.fetchMoreRecords(with: cursor)
                                records.append(contentsOf: moreRecords)
                                continuation.resume(returning: records)
                            } catch {
                                continuation.resume(throwing: error)
                            }
                        }
                    } else {
                        continuation.resume(returning: records)
                    }
                case .failure(let error):
                    print("❌ 查询失败: \(error)")
                    continuation.resume(throwing: error)
                }
            }
            
            database.add(operation)
        }
    }
    
    private func fetchMoreRecords(with cursor: CKQueryOperation.Cursor) async throws -> [CKRecord] {
        let operation = CKQueryOperation(cursor: cursor)
        operation.qualityOfService = .userInitiated
        
        var records: [CKRecord] = []
        
        return try await withCheckedThrowingContinuation { continuation in
            operation.recordMatchedBlock = { recordID, result in
                switch result {
                case .success(let record):
                    records.append(record)
                case .failure(let error):
                    print("❌ 获取更多记录失败: \(recordID.recordName) - \(error)")
                }
            }
            
            operation.queryResultBlock = { result in
                switch result {
                case .success(let cursor):
                    if let cursor = cursor {
                        // 递归获取更多记录
                        Task {
                            do {
                                let moreRecords = try await self.fetchMoreRecords(with: cursor)
                                records.append(contentsOf: moreRecords)
                                continuation.resume(returning: records)
                            } catch {
                                continuation.resume(throwing: error)
                            }
                        }
                    } else {
                        continuation.resume(returning: records)
                    }
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            
            database.add(operation)
        }
    }
    
    // MARK: - 删除操作
    
    func deleteRecords(_ recordIDs: [CKRecord.ID]) async throws {
        guard !recordIDs.isEmpty else { return }
        
        print("🗑️ 开始删除 \(recordIDs.count) 条记录")
        
        let operation = CKModifyRecordsOperation(
            recordsToSave: nil,
            recordIDsToDelete: recordIDs
        )
        
        operation.qualityOfService = .userInitiated
        
        return try await withCheckedThrowingContinuation { continuation in
            operation.modifyRecordsResultBlock = { result in
                switch result {
                case .success():
                    print("✅ 记录删除成功")
                    continuation.resume()
                case .failure(let error):
                    print("❌ 记录删除失败: \(error)")
                    continuation.resume(throwing: error)
                }
            }
            
            database.add(operation)
        }
    }
}

// MARK: - Array扩展
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}