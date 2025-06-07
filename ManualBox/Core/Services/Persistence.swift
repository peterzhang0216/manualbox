//
//  Persistence.swift
//  ManualBox
//
//  Created by Peter's Mac on 2025/4/27.
//

import CoreData

class PersistenceController {
    static let shared = PersistenceController()

    // MARK: - Repository 实例
    private(set) lazy var productRepository: ProductRepository = {
        ProductRepository(context: container.viewContext)
    }()
    
    private(set) lazy var categoryRepository: CategoryRepository = {
        CategoryRepository(context: container.viewContext)
    }()
    
    private(set) lazy var tagRepository: TagRepository = {
        TagRepository(context: container.viewContext)
    }()
    
    private(set) lazy var orderRepository: OrderRepository = {
        OrderRepository(context: container.viewContext)
    }()
    
    private(set) lazy var repairRecordRepository: RepairRecordRepository = {
        RepairRecordRepository(context: container.viewContext)
    }()

    @MainActor
    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        
        // 创建预览数据
        // 1. 创建默认分类
        Category.createDefaultCategories(in: viewContext)
        
        // 2. 创建默认标签
        Tag.createDefaultTags(in: viewContext)
        
        // 3. 创建示例产品
        let electronicCategory = try? viewContext.fetch(NSFetchRequest<Category>(entityName: "Category")).first { $0.name == "电子产品" }
        
        // iPad
        let ipad = Product.createProduct(
            in: viewContext,
            name: "iPad Pro 12.9",
            brand: "Apple",
            model: "MXAY2CH/A",
            category: electronicCategory
        )
        
        // 创建iPad的订单
        let ipadOrder = Order.createOrder(
            in: viewContext,
            orderNumber: "202104150001",
            platform: "Apple Store",
            orderDate: Calendar.current.date(byAdding: .month, value: -10, to: Date())!,
            warrantyPeriod: 12,
            product: ipad
        )
        
        // 添加维修记录
        let _ = RepairRecord.createRepairRecord(
            in: viewContext,
            date: Calendar.current.date(byAdding: .month, value: -2, to: Date())!,
            details: "屏幕更换维修",
            cost: 1200,
            order: ipadOrder
        )
        
        // 空气净化器
        let homeCategory = try? viewContext.fetch(NSFetchRequest<Category>(entityName: "Category")).first { $0.name == "家用电器" }
        
        let airPurifier = Product.createProduct(
            in: viewContext,
            name: "空气净化器",
            brand: "小米",
            model: "Pro H",
            category: homeCategory
        )
        
        // 创建空气净化器的订单
        let _ = Order.createOrder(
            in: viewContext,
            orderNumber: "2023091520001",
            platform: "京东",
            orderDate: Calendar.current.date(byAdding: .month, value: -7, to: Date())!,
            warrantyPeriod: 24,
            product: airPurifier
        )
        
        // 保存上下文
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        
        return result
    }()

    let container: NSPersistentCloudKitContainer

    init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "ManualBox")
        
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        } else {
            configureProductionStore()
        }
        
        configureContainer()
        loadPersistentStores()
        configureContext()
        
        // 注册自动保存通知
        registerAutosaveNotification()
    }
    
    // MARK: - 配置方法
    
    private func configureProductionStore() {
        // 确保应用数据目录存在
        let fileManager = FileManager.default
        let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDataURL = appSupportURL.appendingPathComponent("ManualBox")
        
        // 如果目录不存在，创建它
        if !fileManager.fileExists(atPath: appDataURL.path) {
            do {
                try fileManager.createDirectory(at: appDataURL, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("创建应用数据目录失败: \(error.localizedDescription)")
            }
        }
        
        // 确保存储URL指向正确的位置
        if let storeDescription = container.persistentStoreDescriptions.first {
            let storeURL = appDataURL.appendingPathComponent("ManualBox.sqlite")
            storeDescription.url = storeURL
        }
    }
    
    private func configureContainer() {
        // 配置持久化存储
        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("No persistent store description found")
        }
        
        description.setOption(true as NSNumber,
                            forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        description.setOption(true as NSNumber,
                            forKey: NSPersistentHistoryTrackingKey)
        
        // 启用并发
        container.persistentStoreDescriptions.forEach { description in
            description.setOption(true as NSNumber,
                                forKey: NSPersistentHistoryTrackingKey)
            description.setOption(true as NSNumber,
                                forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        }
    }
    
    private func loadPersistentStores() {
        // 加载持久化存储
        container.loadPersistentStores { description, error in
            if let error = error as NSError? {
                fatalError("持久化存储加载失败: \(error), \(error.userInfo)")
            }
        }
    }
    
    private func configureContext() {
        // 配置视图上下文
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.automaticallyMergesChangesFromParent = true
        
        // 启用撤销管理
        container.viewContext.undoManager = UndoManager()
        
        // 配置并发
        container.viewContext.transactionAuthor = "main"
        container.viewContext.name = "viewContext"
        
        // 配置平台特定的缓存策略
        configurePlatformSpecificCaching()
    }
    
    // MARK: - Repository 工厂方法
    
    /// 创建后台上下文的 Repository 实例
    func createBackgroundRepositories() -> (
        products: ProductRepository,
        categories: CategoryRepository,
        tags: TagRepository,
        orders: OrderRepository,
        repairRecords: RepairRecordRepository
    ) {
        let backgroundContext = newBackgroundContext()
        return (
            products: ProductRepository(context: backgroundContext),
            categories: CategoryRepository(context: backgroundContext),
            tags: TagRepository(context: backgroundContext),
            orders: OrderRepository(context: backgroundContext),
            repairRecords: RepairRecordRepository(context: backgroundContext)
        )
    }
    
    /// 为特定上下文创建 Repository
    func repositories(for context: NSManagedObjectContext) -> (
        products: ProductRepository,
        categories: CategoryRepository,
        tags: TagRepository,
        orders: OrderRepository,
        repairRecords: RepairRecordRepository
    ) {
        return (
            products: ProductRepository(context: context),
            categories: CategoryRepository(context: context),
            tags: TagRepository(context: context),
            orders: OrderRepository(context: context),
            repairRecords: RepairRecordRepository(context: context)
        )
    }
    
    // 初始化默认数据
    func initializeDefaultData() {
        let context = container.viewContext
        
        // 确认数据库是否为空
        let productsRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Product")
        let productsCount = (try? context.count(for: productsRequest)) ?? 0
        
        if productsCount == 0 {
            // 创建默认分类和标签
            Category.createDefaultCategories(in: context)
            Tag.createDefaultTags(in: context)
            
            Task { @MainActor in
                await saveContext()
            }
        }
    }
    
    // MARK: - 上下文管理
    
    // 保存上下文
    @MainActor
    func saveContext() async {
        let context = container.viewContext
        if context.hasChanges {
            do {
                try context.save()
                
                // 通知性能监控器
                if let performanceMonitor: PlatformPerformanceManager = ServiceContainer.shared.resolve(PlatformPerformanceManager.self) {
                    performanceMonitor.recordMetric(
                        name: "persistence.context.save",
                        value: 1,
                        type: .counter
                    )
                }
            } catch {
                await handleSaveError(error as NSError)
            }
        }
    }
    
    // 错误处理
    @MainActor
    private func handleSaveError(_ nsError: NSError) async {
        // 处理具体的错误类型
        if nsError.domain == NSCocoaErrorDomain {
            switch nsError.code {
            case 133: // NSValidationErrorMinimum
                print("数据验证失败: \(nsError.localizedDescription)")
            case 134...2047: // 其他验证错误
                print("数据验证错误: \(nsError.localizedDescription)")
            case 134020: // 合并错误
                container.viewContext.rollback()
                print("合并冲突，已回滚更改")
            default:
                print("保存上下文失败: \(nsError), \(nsError.userInfo)")
            }
        }
        
        // 记录错误到性能监控
        if let performanceMonitor: PlatformPerformanceManager = ServiceContainer.shared.resolve(PlatformPerformanceManager.self) {
            performanceMonitor.recordMetric(
                name: "persistence.context.save.error",
                value: 1,
                type: .counter
            )
        }
    }
    
    // 创建后台上下文
    func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        context.automaticallyMergesChangesFromParent = true
        context.name = "background-\(UUID().uuidString.prefix(8))"
        return context
    }
    
    // 执行后台任务
    func performBackgroundTask(_ block: @escaping (NSManagedObjectContext) -> Void) {
        container.performBackgroundTask { context in
            context.name = "task-\(UUID().uuidString.prefix(8))"
            block(context)
            if context.hasChanges {
                do {
                    try context.save()
                } catch {
                    print("后台任务保存失败: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // 注册自动保存通知
    private func registerAutosaveNotification() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(contextObjectsDidChange),
            name: NSManagedObjectContext.didChangeObjectsNotification,
            object: container.viewContext
        )
    }
    
    @objc private func contextObjectsDidChange(_ notification: Notification) {
        Task { @MainActor in
            await saveContext()
        }
    }
}

// MARK: - 平台特定的数据同步策略
extension PersistenceController {
    
    // 平台特定的容器配置
    static func platformOptimizedContainer() -> NSPersistentCloudKitContainer {
        let container = NSPersistentCloudKitContainer(name: "ManualBox")
        
        // 配置CloudKit选项
        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("无法获取持久化存储描述")
        }
        
        // 基础 CloudKit 配置（适用于所有平台）
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        
        #if os(macOS)
        // macOS 特定配置
        description.setOption("macOS" as NSString, forKey: "CloudKitContainerEnvironment")
        #else
        // iOS 特定配置
        description.setOption("iOS" as NSString, forKey: "CloudKitContainerEnvironment")
        #endif
        
        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Core Data 加载失败: \(error)")
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        
        return container
    }
    
    // 平台特定的文件存储路径
    static var platformDocumentsDirectory: URL {
        #if os(macOS)
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("ManualBox")
        #else
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        #endif
    }
    
    // 平台特定的缓存策略
    func configurePlatformSpecificCaching() {
        #if os(macOS)
        // macOS 可以使用更多内存进行缓存
        container.viewContext.stalenessInterval = 0
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        #else
        // iOS 需要更保守的内存使用
        container.viewContext.stalenessInterval = 300 // 5分钟
        container.viewContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
        
        // 在收到内存警告时清理缓存
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { _ in
            self.container.viewContext.refreshAllObjects()
        }
        #endif
    }
}

// MARK: - 数据迁移和维护
extension PersistenceController {
    
    /// 执行数据库维护操作
    func performMaintenance() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            performBackgroundTask { context in
                do {
                    // 清理孤立的数据
                    try self.cleanupOrphanedData(in: context)
                    
                    // 优化数据库
                    try self.optimizeDatabase(in: context)
                    
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func cleanupOrphanedData(in context: NSManagedObjectContext) throws {
        // 清理没有关联产品的标签
        let orphanedTagsRequest = NSFetchRequest<Tag>(entityName: "Tag")
        orphanedTagsRequest.predicate = NSPredicate(format: "products.@count == 0")
        
        let orphanedTags = try context.fetch(orphanedTagsRequest)
        orphanedTags.forEach { context.delete($0) }
        
        // 清理没有关联产品的分类（保留默认分类）
        let orphanedCategoriesRequest = NSFetchRequest<Category>(entityName: "Category")
        orphanedCategoriesRequest.predicate = NSPredicate(
            format: "products.@count == 0 AND NOT (name IN %@)",
            Category.defaultCategories.keys.map { $0 }
        )
        
        let orphanedCategories = try context.fetch(orphanedCategoriesRequest)
        orphanedCategories.forEach { context.delete($0) }
        
        try context.save()
    }
    
    private func optimizeDatabase(in context: NSManagedObjectContext) throws {
        // 刷新所有对象以释放内存
        context.refreshAllObjects()
        
        // 强制保存以确保所有更改都写入磁盘
        try context.save()
    }
}
