//
//  CloudKitSyncService.swift
//  ManualBox
//
//  Created by Assistant on 2024/12/19.
//  重构后的CloudKit同步服务主文件
//

import CloudKit
import CoreData
import Combine
import Network

// MARK: - CloudKit同步服务主类
class CloudKitSyncService: SyncServiceProtocol, ObservableObject {
    
    // MARK: - Singleton
    static let shared = CloudKitSyncService(
        persistentContainer: PersistenceController.shared.container,
        configuration: CloudKitSyncConfiguration.default
    )
    
    // MARK: - Published Properties
    @Published private(set) var syncStatus: CloudKitSyncStatus = .idle
    @Published private(set) var lastSyncDate: Date?
    @Published private(set) var syncProgress: Double = 0.0
    @Published private(set) var conflictCount: Int = 0
    @Published private(set) var pendingChanges: Int = 0
    @Published private(set) var syncDetails: SyncDetails?
    @Published private(set) var syncHistory: [SyncHistoryItem] = []
    @Published private(set) var pendingUploads: Int = 0
    @Published private(set) var pendingDownloads: Int = 0
    @Published private(set) var failedRecords: Int = 0
    
    // MARK: - Core Properties
    private let container: CKContainer
    private let persistentContainer: NSPersistentCloudKitContainer
    private let configuration: CloudKitSyncConfiguration
    private var cancellables = Set<AnyCancellable>()
    private let networkMonitor = NWPathMonitor()
    private var isNetworkAvailable = true
    private var pendingSync: (() async throws -> Void)?
    
    // MARK: - 组件
    private let changeTokenStore: ChangeTokenStore
    private let conflictResolver: CloudKitConflictResolver
    private let recordProcessor: CloudKitRecordProcessor
    private let syncOperations: CloudKitSyncOperations
    
    // MARK: - 冲突相关
    private var pendingConflicts: [SyncConflict] = []
    var pendingConflictsPublic: [SyncConflict] { pendingConflicts }
    
    // MARK: - Initialization
    init(persistentContainer: NSPersistentCloudKitContainer, configuration: CloudKitSyncConfiguration) {
        self.persistentContainer = persistentContainer
        self.configuration = configuration
        self.container = CKContainer(identifier: configuration.containerIdentifier)
        
        // 初始化组件
        self.changeTokenStore = ChangeTokenStore()
        self.conflictResolver = CloudKitConflictResolver(context: persistentContainer.viewContext)
        self.recordProcessor = CloudKitRecordProcessor(context: persistentContainer.viewContext)
        self.syncOperations = CloudKitSyncOperations(
            container: container,
            configuration: configuration
        )
        
        setupRemoteChangeNotifications()
        setupNetworkMonitor()
        loadSyncHistory()
    }
    
    // MARK: - ServiceProtocol
    nonisolated func initialize() async throws {
        try await checkCloudKitAvailability()
    }
    
    nonisolated func cleanup() {
        Task { @MainActor in
            cancellables.removeAll()
            networkMonitor.cancel()
        }
    }
    
    // MARK: - SyncServiceProtocol
    nonisolated func syncToCloud() async throws {
        let currentSyncStatus = await MainActor.run { syncStatus }
        guard currentSyncStatus != .syncing else {
            throw CloudKitSyncError.syncInProgress
        }
        
        do {
            try await checkAccountStatus()
            
            await MainActor.run {
                syncStatus = .syncing
                syncProgress = 0.0
                syncDetails = SyncDetails(
                    startTime: Date(),
                    endTime: nil,
                    totalRecords: 0,
                    processedRecords: 0,
                    failedRecords: 0,
                    conflictedRecords: 0,
                    syncType: .full,
                    phase: .uploading
                )
            }
            
            try await performUploadSync()
            
            await MainActor.run {
                syncStatus = .completed
                syncProgress = 1.0
                lastSyncDate = Date()
                if var details = syncDetails {
                    details = SyncDetails(
                        startTime: details.startTime,
                        endTime: Date(),
                        totalRecords: details.totalRecords,
                        processedRecords: details.processedRecords,
                        failedRecords: details.failedRecords,
                        conflictedRecords: details.conflictedRecords,
                        syncType: details.syncType,
                        phase: .completed
                    )
                    syncDetails = details
                }
            }
            
        } catch {
            await MainActor.run {
                syncStatus = .failed(error)
                syncProgress = 0.0
            }
            throw error
        }
    }
    
    nonisolated func syncFromCloud() async throws {
        await MainActor.run {
            if case .completed = syncStatus {
                syncStatus = .idle
            }
        }
        
        let currentSyncStatus = await MainActor.run { syncStatus }
        guard currentSyncStatus != .syncing else {
            throw CloudKitSyncError.syncInProgress
        }
        
        do {
            try await checkAccountStatus()
            
            await MainActor.run {
                syncStatus = .syncing
                syncProgress = 0.0
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
            }
            
            try await performDownloadSync()
            
            await MainActor.run {
                syncStatus = .completed
                syncProgress = 1.0
                lastSyncDate = Date()
                if var details = syncDetails {
                    details = SyncDetails(
                        startTime: details.startTime,
                        endTime: Date(),
                        totalRecords: details.totalRecords,
                        processedRecords: details.processedRecords,
                        failedRecords: details.failedRecords,
                        conflictedRecords: details.conflictedRecords,
                        syncType: details.syncType,
                        phase: .completed
                    )
                    syncDetails = details
                }
            }
            
        } catch {
            await MainActor.run {
                syncStatus = .failed(error)
                syncProgress = 0.0
            }
            throw error
        }
    }
    
    nonisolated func resolveConflicts() async throws {
        print("🔄 开始解决同步冲突")
        
        let conflicts = await MainActor.run { pendingConflicts }
        for conflict in conflicts {
            try await resolveConflict(conflict, strategy: .lastModifiedWins)
        }
        
        await MainActor.run {
            conflictCount = 0
        }
    }
    
    // MARK: - 冲突解决
    func resolveConflict(_ conflict: SyncConflict, strategy: ConflictResolutionStrategy) async throws {
        print("🔧 解决冲突: \(conflict.recordID.recordName)")
        
        // 使用冲突解决器处理
        let resolvedRecord = conflictResolver.resolveConflict(
            localRecord: conflict.localRecord,
            serverRecord: conflict.serverRecord,
            strategy: strategy
        )
        
        // 应用解决方案
        try await applyConflictResolution(conflict, resolvedRecord: resolvedRecord)
        
        await MainActor.run {
            pendingConflicts.removeAll { $0.id == conflict.id }
            conflictCount = pendingConflicts.count
        }
    }
    
    // MARK: - 私有同步方法
    
    private func performUploadSync() async throws {
        print("📤 开始上传同步")
        
        // 获取本地未同步的记录
        let unsyncedRecords = try await getUnsyncedLocalRecords()
        
        await MainActor.run {
            pendingUploads = unsyncedRecords.count
        }
        
        // 批量上传
        try await syncOperations.uploadRecords(unsyncedRecords) { progress in
            Task { @MainActor in
                self.syncProgress = progress
            }
        }
        
        await MainActor.run {
            pendingUploads = 0
        }
    }
    
    private func performDownloadSync() async throws {
        print("📥 开始下载同步")
        
        // 获取服务器变更
        let changes = try await syncOperations.fetchChanges(
            since: changeTokenStore.loadToken()
        ) { progress in
            Task { @MainActor in
                self.syncProgress = progress
            }
        }
        
        // 处理变更
        for record in changes.changedRecords {
            recordProcessor.processChangedRecord(record)
        }
        
        for recordID in changes.deletedRecordIDs {
            recordProcessor.processDeletedRecord(
                recordID: recordID.recordID,
                recordType: recordID.recordType
            )
        }
        
        // 保存新的变更令牌
        if let newToken = changes.changeToken {
            changeTokenStore.saveToken(newToken)
        }
    }
    
    // MARK: - 辅助方法
    
    private func checkCloudKitAvailability() async throws {
        let accountStatus = try await container.accountStatus()
        
        switch accountStatus {
        case .available:
            print("✅ CloudKit账户可用")
        case .noAccount:
            throw CloudKitSyncError.noAccount
        case .restricted:
            throw CloudKitSyncError.accountRestricted
        case .couldNotDetermine:
            throw CloudKitSyncError.accountStatusUnknown
        case .temporarilyUnavailable:
            throw CloudKitSyncError.temporarilyUnavailable
        @unknown default:
            throw CloudKitSyncError.accountStatusUnknown
        }
    }
    
    private func checkAccountStatus() async throws {
        try await checkCloudKitAvailability()
        
        guard isNetworkAvailable else {
            throw CloudKitSyncError.networkUnavailable
        }
    }
    
    private func getUnsyncedLocalRecords() async throws -> [CKRecord] {
        // 这里应该查询本地数据库中未同步的记录
        // 简化实现，返回空数组
        return []
    }
    
    private func applyConflictResolution(_ conflict: SyncConflict, resolvedRecord: CKRecord) async throws {
        // 应用冲突解决方案
        recordProcessor.processChangedRecord(resolvedRecord)
        print("✅ 冲突解决完成: \(conflict.recordID.recordName)")
    }
    
    // MARK: - 网络监控
    
    private func setupNetworkMonitor() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isNetworkAvailable = path.status == .satisfied
                if path.status == .satisfied {
                    print("🌐 网络连接恢复")
                    // 如果有待处理的同步，执行它
                    if let pendingSync = self?.pendingSync {
                        self?.pendingSync = nil
                        Task {
                            try await pendingSync()
                        }
                    }
                } else {
                    print("❌ 网络连接断开")
                }
            }
        }
        
        let queue = DispatchQueue(label: "NetworkMonitor")
        networkMonitor.start(queue: queue)
    }
    
    private func setupRemoteChangeNotifications() {
        // 设置远程变更通知
        NotificationCenter.default.addObserver(
            forName: .CKAccountChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task {
                try? await self?.handleAccountChange()
            }
        }
    }
    
    private func handleAccountChange() async throws {
        print("👤 CloudKit账户状态变更")
        try await checkAccountStatus()
    }
    
    private func loadSyncHistory() {
        // 加载同步历史
        // 这里可以从UserDefaults或数据库加载
        syncHistory = []
    }
}

// MARK: - 错误定义
enum CloudKitSyncError: LocalizedError {
    case syncInProgress
    case noAccount
    case accountRestricted
    case accountStatusUnknown
    case temporarilyUnavailable
    case networkUnavailable
    
    var errorDescription: String? {
        switch self {
        case .syncInProgress:
            return "同步正在进行中"
        case .noAccount:
            return "未登录iCloud账户"
        case .accountRestricted:
            return "iCloud账户受限"
        case .accountStatusUnknown:
            return "无法确定iCloud账户状态"
        case .temporarilyUnavailable:
            return "iCloud服务暂时不可用"
        case .networkUnavailable:
            return "网络连接不可用"
        }
    }
}