//
//  PersistenceController.swift
//  ManualBox
//
//  Created by Peter's Mac on 2025/4/27.
//

import CoreData
#if os(iOS)
import UIKit
#endif

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
    
    private(set) lazy var manualRepository: ManualRepository = {
        ManualRepository(context: container.viewContext)
    }()

    @MainActor
    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext

        // 创建预览数据 - 使用默认创建方法确保一致性
        Category.createDefaultCategories(in: viewContext)
        Tag.createDefaultTags(in: viewContext)

        // 获取创建的分类和标签
        let categoriesRequest: NSFetchRequest<Category> = Category.fetchRequest()
        let categories = try! viewContext.fetch(categoriesRequest)

        let tagsRequest: NSFetchRequest<Tag> = Tag.fetchRequest()
        let tags = try! viewContext.fetch(tagsRequest)

        let electronicCategory = categories.first { $0.name == "电子产品" }!
        let homeCategory = categories.first { $0.name == "家用电器" }!
        let importantTag = tags.first { $0.name == "重要" }!
        
        // 3. 创建示例产品
        
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
    
    // MARK: - 数据诊断
    
    /// 执行快速数据诊断
    @MainActor
    func quickDiagnose() async -> DataDiagnostics.DiagnosticResult {
        let diagnosticsService = UnifiedDataDiagnosticsService.shared
        let quickResult = await diagnosticsService.performQuickDiagnosis()
        
        // 创建兼容的诊断结果
        let dataDiagnostics = DataDiagnostics(context: container.viewContext)
        return DataDiagnostics.DiagnosticResult(from: quickResult)
    }
    
    // MARK: - Repository 工厂方法
    
    /// 创建后台上下文的 Repository 实例
    func createBackgroundRepositories() -> (
        products: ProductRepository,
        categories: CategoryRepository,
        tags: TagRepository,
        orders: OrderRepository,
        repairRecords: RepairRecordRepository,
        manuals: ManualRepository
    ) {
        let backgroundContext = newBackgroundContext()
        return (
            products: ProductRepository(context: backgroundContext),
            categories: CategoryRepository(context: backgroundContext),
            tags: TagRepository(context: backgroundContext),
            orders: OrderRepository(context: backgroundContext),
            repairRecords: RepairRecordRepository(context: backgroundContext),
            manuals: ManualRepository(context: backgroundContext)
        )
    }
    
    /// 为特定上下文创建 Repository
    func repositories(for context: NSManagedObjectContext) -> (
        products: ProductRepository,
        categories: CategoryRepository,
        tags: TagRepository,
        orders: OrderRepository,
        repairRecords: RepairRecordRepository,
        manuals: ManualRepository
    ) {
        return (
            products: ProductRepository(context: context),
            categories: CategoryRepository(context: context),
            tags: TagRepository(context: context),
            orders: OrderRepository(context: context),
            repairRecords: RepairRecordRepository(context: context),
            manuals: ManualRepository(context: context)
        )
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
    
    // MARK: - 平台特定的缓存策略
    private func configurePlatformSpecificCaching() {
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