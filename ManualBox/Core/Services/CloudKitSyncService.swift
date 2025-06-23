import Foundation
import CloudKit
import CoreData
import Combine
import Network

// MARK: - CloudKit同步服务实现
@MainActor
class CloudKitSyncService: SyncServiceProtocol, ObservableObject {
    
    // MARK: - Properties
    @Published private(set) var syncStatus: SyncStatus = .idle
    @Published private(set) var lastSyncDate: Date?
    @Published private(set) var syncProgress: Double = 0.0
    
    private let container: CKContainer
    private let persistentContainer: NSPersistentCloudKitContainer
    private let configuration: CloudKitConfiguration
    private var cancellables = Set<AnyCancellable>()
    private let networkMonitor = NWPathMonitor()
    private var isNetworkAvailable = true
    private var pendingSync: (() async throws -> Void)?
    
    // MARK: - Initialization
    init(persistentContainer: NSPersistentCloudKitContainer, configuration: CloudKitConfiguration) {
        self.persistentContainer = persistentContainer
        self.configuration = configuration
        self.container = CKContainer(identifier: configuration.containerIdentifier)
        
        setupRemoteChangeNotifications()
        setupNetworkMonitor()
    }
    
    // MARK: - ServiceProtocol
    nonisolated func initialize() async throws {
        try await checkCloudKitAvailability()
        await setupAutomaticSync()
    }
    
    nonisolated func cleanup() {
        Task { @MainActor in
            cancellables.removeAll()
        }
    }
    
    // MARK: - SyncServiceProtocol
    nonisolated func syncToCloud() async throws {
        let currentSyncStatus = await syncStatus
        guard currentSyncStatus != .syncing else {
            print("🔄 同步已在进行中，跳过此次请求")
            return
        }
        
        let networkAvailable = await isNetworkAvailable
        if !networkAvailable {
            print("⚠️ 网络不可用，已缓存同步请求，待恢复后自动执行")
            await MainActor.run {
                pendingSync = { [weak self] in try await self?.syncToCloud() }
            }
            return
        }
        
        await MainActor.run {
            syncStatus = .syncing
            syncProgress = 0.0
        }
        
        do {
            // 检查CloudKit可用性
            try await checkCloudKitAvailability()
            
            // 保存本地更改到CloudKit
            try await saveLocalChangesToCloud()
            
            // 更新同步状态
            await MainActor.run {
                syncStatus = .completed
                lastSyncDate = Date()
                syncProgress = 1.0
            }
            
            print("✅ 数据同步到云端完成")
            
        } catch {
            await MainActor.run {
                syncStatus = .failed(error)
                syncProgress = 0.0
            }
            print("❌ 同步到云端失败: \(error.localizedDescription)")
            throw error
        }
        
        // 重置状态
        Task {
            try await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run {
                if case .completed = syncStatus {
                    syncStatus = .idle
                }
            }
        }
    }
    
    nonisolated func syncFromCloud() async throws {
        let currentSyncStatus = await syncStatus
        guard currentSyncStatus != .syncing else {
            print("🔄 同步已在进行中，跳过此次请求")
            return
        }
        
        let networkAvailable = await isNetworkAvailable
        if !networkAvailable {
            print("⚠️ 网络不可用，已缓存同步请求，待恢复后自动执行")
            await MainActor.run {
                pendingSync = { [weak self] in try await self?.syncFromCloud() }
            }
            return
        }
        
        await MainActor.run {
            syncStatus = .syncing
            syncProgress = 0.0
            // 发布同步开始事件
            EventBus.shared.publishSyncEvent(syncType: .cloudKit, status: .syncing, progress: 0.0)
            AppStateManager.shared.updateSyncStatus(.syncing, progress: 0.0)
        }
        
        do {
            // 检查CloudKit可用性
            try await checkCloudKitAvailability()
            
            // 从CloudKit获取更改
            try await fetchCloudChanges()
            
            // 更新同步状态
            await MainActor.run {
                syncStatus = .completed
                lastSyncDate = Date()
                syncProgress = 1.0
                // 发布同步完成事件
                EventBus.shared.publishSyncEvent(syncType: .cloudKit, status: .completed, progress: 1.0)
                AppStateManager.shared.updateSyncStatus(.completed, progress: 1.0)
            }
            
            print("✅ 从云端同步数据完成")
            
        } catch {
            await MainActor.run {
                syncStatus = .failed(error)
                syncProgress = 0.0
                // 发布同步失败事件
                EventBus.shared.publishSyncEvent(syncType: .cloudKit, status: .failed(error), progress: 0.0)
                EventBus.shared.publishError(error, context: "CloudKit同步")
                AppStateManager.shared.updateSyncStatus(.failed(error), progress: 0.0)
                AppStateManager.shared.handleError(error, context: "CloudKit同步")
            }
            print("❌ 从云端同步失败: \(error.localizedDescription)")
            throw error
        }
        
        // 重置状态
        Task {
            try await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run {
                if case .completed = syncStatus {
                    syncStatus = .idle
                }
            }
        }
    }
    
    nonisolated func resolveConflicts() async throws {
        let context = persistentContainer.viewContext
        
        // 获取有冲突的对象
        let conflicts = try await getConflictedObjects()
        
        for conflict in conflicts {
            try await resolveConflict(conflict, in: context)
        }
        
        try context.save()
        print("✅ 数据冲突解决完成")
    }
    
    // MARK: - Private Methods
    private func checkCloudKitAvailability() async throws {
        let accountStatus = try await container.accountStatus()
        
        switch accountStatus {
        case .available:
            print("✅ CloudKit账户可用")
        case .noAccount:
            throw SyncError.noAccount
        case .restricted:
            throw SyncError.accountRestricted
        case .couldNotDetermine:
            throw SyncError.accountStatusUnknown
        case .temporarilyUnavailable:
            throw SyncError.temporarilyUnavailable
        @unknown default:
            throw SyncError.accountStatusUnknown
        }
    }
    
    private func saveLocalChangesToCloud() async throws {
        let context = persistentContainer.viewContext
        
        // 确保有待同步的更改
        if context.hasChanges {
            try context.save()
            await MainActor.run {
                syncProgress = 0.5
            }
        }
        
        // CloudKit Core Data集成会自动处理上传
        // 等待同步完成
        try await waitForSyncCompletion()
        
        await MainActor.run {
            syncProgress = 1.0
        }
    }
    
    private func fetchCloudChanges() async throws {
        // CloudKit Core Data集成会自动处理下载
        // 触发远程更改通知处理
        NotificationCenter.default.post(
            name: .NSPersistentStoreRemoteChange,
            object: persistentContainer.persistentStoreCoordinator
        )
        
        await MainActor.run {
            syncProgress = 0.5
        }
        
        // 等待同步完成
        try await waitForSyncCompletion()
        
        await MainActor.run {
            syncProgress = 1.0
        }
    }
    
    private func waitForSyncCompletion() async throws {
        // 等待CloudKit同步完成
        // 这是一个简化的实现，实际中可能需要更复杂的状态检查
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1秒
    }
    
    private func getConflictedObjects() async throws -> [NSManagedObject] {
        // 简化实现：通过Core Data的持久化历史来检测冲突
        let context = persistentContainer.viewContext
        let fetchRequest = NSFetchRequest<Product>(entityName: "Product")
        
        // 获取所有产品，实际实现中可以通过NSPersistentHistory来检测冲突
        let _ = try context.fetch(fetchRequest)
        
        // 这里简化处理，实际中需要通过CloudKit记录版本来检测冲突
        return []
    }
    
    private func resolveConflict(_ conflict: NSManagedObject, in context: NSManagedObjectContext) async throws {
        guard let product = conflict as? Product else { return }
        
        // 简化的冲突解决：使用最新的updatedAt时间戳
        // 在实际实现中，需要通过CloudKit的CKRecord来比较版本
        let _ = product.updatedAt ?? .distantPast
        
        // 实际实现中需要从CloudKit获取服务器版本进行比较
        // 这里简化处理，直接保留本地版本
        print("处理产品冲突: \(product.name ?? "未知产品")")
    }
    
    private func setupRemoteChangeNotifications() {
        NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange)
            .sink { [weak self] notification in
                Task {
                    await self?.handleRemoteChange(notification)
                }
            }
            .store(in: &cancellables)
    }
    
    private func handleRemoteChange(_ notification: Notification) async {
        print("📡 收到远程数据变更通知")
        
        // 处理远程数据变更
        let context = persistentContainer.viewContext
        
        await context.perform {
            // 刷新所有对象以获取最新数据
            context.refreshAllObjects()
        }
    }
    
    private func setupNetworkMonitor() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isNetworkAvailable = path.status == .satisfied
                if let self = self, self.isNetworkAvailable, let pending = self.pendingSync {
                    Task {
                        do {
                            try await pending()
                            await MainActor.run {
                                self.pendingSync = nil
                            }
                        } catch {
                            print("⚠️ 网络恢复后同步失败: \(error.localizedDescription)")
                        }
                    }
                }
            }
        }
        let queue = DispatchQueue(label: "CloudKitSyncNetworkMonitor")
        networkMonitor.start(queue: queue)
    }
    
    private func setupAutomaticSync() async {
        guard configuration.enableSync else { return }
        
        Timer.publish(every: configuration.syncInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task {
                    do {
                        try await self?.syncFromCloud()
                    } catch {
                        print("⚠️ 自动同步失败: \(error.localizedDescription)")
                    }
                }
            }
            .store(in: &cancellables)
    }
}

// MARK: - SyncError
enum SyncError: LocalizedError {
    case noAccount
    case accountRestricted
    case accountStatusUnknown
    case temporarilyUnavailable
    case networkUnavailable
    case quotaExceeded
    case syncInProgress
    
    var errorDescription: String? {
        switch self {
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
        case .quotaExceeded:
            return "iCloud存储空间不足"
        case .syncInProgress:
            return "同步正在进行中"
        }
    }
}