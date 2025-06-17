//
//  Persistence.swift
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
    
    // 初始化默认数据（兼容旧版本，会清理重复数据）
    // 注意：此方法主要用于数据修复和兼容性，不会检查初始化标记
    func initializeDefaultData() {
        let context = container.viewContext

        // 先清理重复数据
        removeDuplicateData()

        // 分别检查分类和标签是否为空
        let categoriesRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Category")
        let categoriesCount = (try? context.count(for: categoriesRequest)) ?? 0

        let tagsRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Tag")
        let tagsCount = (try? context.count(for: tagsRequest)) ?? 0

        var needsSave = false

        // 只有当分类表为空时才创建默认分类
        if categoriesCount == 0 {
            print("[Persistence] 创建默认分类...")
            Category.createDefaultCategories(in: context)
            needsSave = true
        } else {
            print("[Persistence] 分类已存在，跳过创建默认分类")
        }

        // 只有当标签表为空时才创建默认标签
        if tagsCount == 0 {
            print("[Persistence] 创建默认标签...")
            Tag.createDefaultTags(in: context)
            needsSave = true
        } else {
            print("[Persistence] 标签已存在，跳过创建默认标签")
        }

        // 只有在需要时才保存
        if needsSave {
            Task { @MainActor in
                await saveContext()
            }
        }
    }

    // 只在需要时初始化默认数据（不清理重复数据，更温和的方式）
    func initializeDefaultDataIfNeeded() {
        let context = container.viewContext

        // 检查是否已经进行过首次初始化
        let hasInitialized = UserDefaults.standard.bool(forKey: "ManualBox_HasInitializedDefaultData")

        if hasInitialized {
            print("[Persistence] 已完成首次初始化，跳过默认数据创建")
            return
        }

        // 分别检查分类和标签是否为空
        let categoriesRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Category")
        let categoriesCount = (try? context.count(for: categoriesRequest)) ?? 0

        let tagsRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Tag")
        let tagsCount = (try? context.count(for: tagsRequest)) ?? 0

        var needsSave = false

        // 只有当分类表为空时才创建默认分类
        if categoriesCount == 0 {
            print("[Persistence] 首次启动，创建默认分类...")
            Category.createDefaultCategories(in: context)
            needsSave = true
        } else {
            print("[Persistence] 分类已存在 (\(categoriesCount) 个)，跳过创建")
        }

        // 只有当标签表为空时才创建默认标签
        if tagsCount == 0 {
            print("[Persistence] 首次启动，创建默认标签...")
            Tag.createDefaultTags(in: context)
            needsSave = true
        } else {
            print("[Persistence] 标签已存在 (\(tagsCount) 个)，跳过创建")
        }

        // 只有在需要时才保存
        if needsSave {
            do {
                try context.save()
                print("[Persistence] 默认数据保存成功")
            } catch {
                print("[Persistence] 保存默认数据时出错: \(error.localizedDescription)")
            }
        }

        // 标记已完成首次初始化
        UserDefaults.standard.set(true, forKey: "ManualBox_HasInitializedDefaultData")
        print("[Persistence] 首次初始化完成，已设置标记")
    }

    // 重置初始化标记（用于重置应用数据时）
    func resetInitializationFlag() {
        UserDefaults.standard.removeObject(forKey: "ManualBox_HasInitializedDefaultData")
        print("[Persistence] 已重置初始化标记")
    }

    // 检查是否已完成首次初始化
    func hasCompletedInitialSetup() -> Bool {
        return UserDefaults.standard.bool(forKey: "ManualBox_HasInitializedDefaultData")
    }

    // MARK: - 数据清理

    /// 清理重复的分类和标签数据
    private func removeDuplicateData() {
        let context = container.viewContext

        context.performAndWait {
            // 清理重复分类
            removeDuplicateCategories(in: context)

            // 清理重复标签
            removeDuplicateTags(in: context)

            // 保存清理结果
            if context.hasChanges {
                do {
                    try context.save()
                    print("[Persistence] 重复数据清理完成")
                } catch {
                    print("[Persistence] 清理重复数据时出错: \(error.localizedDescription)")
                }
            }
        }
    }

    /// 清理重复分类（改进版本）
    private func removeDuplicateCategories(in context: NSManagedObjectContext) {
        let request: NSFetchRequest<Category> = Category.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Category.name, ascending: true)
        ]

        do {
            let categories = try context.fetch(request)
            var nameToCategory: [String: Category] = [:]
            var duplicatesToDelete: [Category] = []

            for category in categories {
                let name = (category.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

                if name.isEmpty {
                    // 删除空名称的分类
                    duplicatesToDelete.append(category)
                    print("[Persistence] 发现空名称分类，将删除")
                    continue
                }

                if let existingCategory = nameToCategory[name] {
                    // 发现重复，决定保留哪一个
                    let categoryToKeep = chooseCategoryToKeep(existing: existingCategory, duplicate: category)
                    let categoryToDelete = (categoryToKeep == existingCategory) ? category : existingCategory

                    // 转移产品关联到保留的分类
                    transferProductsToCategory(from: categoryToDelete, to: categoryToKeep, in: context)

                    duplicatesToDelete.append(categoryToDelete)
                    nameToCategory[name] = categoryToKeep

                    print("[Persistence] 发现重复分类: \(name)，保留较早创建的版本")
                } else {
                    nameToCategory[name] = category
                }
            }

            // 删除重复项
            for duplicate in duplicatesToDelete {
                context.delete(duplicate)
            }

            if !duplicatesToDelete.isEmpty {
                print("[Persistence] 已删除 \(duplicatesToDelete.count) 个重复分类")
            }
        } catch {
            print("[Persistence] 清理重复分类时出错: \(error.localizedDescription)")
        }
    }

    /// 清理重复标签（改进版本）
    private func removeDuplicateTags(in context: NSManagedObjectContext) {
        let request: NSFetchRequest<Tag> = Tag.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Tag.name, ascending: true)
        ]

        do {
            let tags = try context.fetch(request)
            var nameToTag: [String: Tag] = [:]
            var duplicatesToDelete: [Tag] = []

            for tag in tags {
                let name = (tag.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

                if name.isEmpty {
                    // 删除空名称的标签
                    duplicatesToDelete.append(tag)
                    print("[Persistence] 发现空名称标签，将删除")
                    continue
                }

                if let existingTag = nameToTag[name] {
                    // 发现重复，决定保留哪一个
                    let tagToKeep = chooseTagToKeep(existing: existingTag, duplicate: tag)
                    let tagToDelete = (tagToKeep == existingTag) ? tag : existingTag

                    // 转移产品关联到保留的标签
                    transferProductsToTag(from: tagToDelete, to: tagToKeep, in: context)

                    duplicatesToDelete.append(tagToDelete)
                    nameToTag[name] = tagToKeep

                    print("[Persistence] 发现重复标签: \(name)，保留较早创建的版本")
                } else {
                    nameToTag[name] = tag
                }
            }

            // 删除重复项
            for duplicate in duplicatesToDelete {
                context.delete(duplicate)
            }

            if !duplicatesToDelete.isEmpty {
                print("[Persistence] 已删除 \(duplicatesToDelete.count) 个重复标签")
            }
        } catch {
            print("[Persistence] 清理重复标签时出错: \(error.localizedDescription)")
        }
    }

    /// 公开的清理重复数据方法，可以在设置中调用
    @MainActor
    func cleanupDuplicateData() async {
        removeDuplicateData()
    }

    // MARK: - 辅助方法

    /// 选择要保留的分类（优先保留有更多产品关联的）
    private func chooseCategoryToKeep(existing: Category, duplicate: Category) -> Category {
        let existingProductCount = (existing.products as? Set<Product>)?.count ?? 0
        let duplicateProductCount = (duplicate.products as? Set<Product>)?.count ?? 0

        // 优先保留有更多产品的分类
        if existingProductCount != duplicateProductCount {
            return existingProductCount > duplicateProductCount ? existing : duplicate
        }

        // 如果产品数量相同，保留第一个（existing）
        return existing
    }

    /// 选择要保留的标签（优先保留有更多产品关联的）
    private func chooseTagToKeep(existing: Tag, duplicate: Tag) -> Tag {
        let existingProductCount = (existing.products as? Set<Product>)?.count ?? 0
        let duplicateProductCount = (duplicate.products as? Set<Product>)?.count ?? 0

        // 优先保留有更多产品的标签
        if existingProductCount != duplicateProductCount {
            return existingProductCount > duplicateProductCount ? existing : duplicate
        }

        // 如果产品数量相同，保留第一个（existing）
        return existing
    }

    /// 将产品从一个分类转移到另一个分类
    private func transferProductsToCategory(from source: Category, to target: Category, in context: NSManagedObjectContext) {
        guard let sourceProducts = source.products as? Set<Product> else { return }

        for product in sourceProducts {
            product.category = target
            print("[Persistence] 转移产品 '\(product.name ?? "未知")' 从分类 '\(source.name ?? "")' 到 '\(target.name ?? "")'")
        }
    }

    /// 将产品从一个标签转移到另一个标签
    private func transferProductsToTag(from source: Tag, to target: Tag, in context: NSManagedObjectContext) {
        guard let sourceProducts = source.products as? Set<Product> else { return }

        for product in sourceProducts {
            // 移除旧标签关联
            product.removeFromTags(source)
            // 添加新标签关联（如果还没有的话）
            if let targetProducts = target.products as? Set<Product>, !targetProducts.contains(product) {
                product.addToTags(target)
                print("[Persistence] 转移产品 '\(product.name ?? "未知")' 从标签 '\(source.name ?? "")' 到 '\(target.name ?? "")'")
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

// MARK: - 示例数据创建
extension PersistenceController {

    /// 创建示例产品数据（用于测试和演示）
    func createSampleData() {
        let context = container.viewContext

        context.performAndWait {
            do {
                // 检查是否已有产品数据
                let productRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Product")
                let productCount = try context.count(for: productRequest)

                if productCount > 0 {
                    print("[Persistence] 已存在产品数据，跳过示例数据创建")
                    return
                }

                // 获取所有分类和标签
                let categoriesRequest: NSFetchRequest<Category> = Category.fetchRequest()
                let categories = try context.fetch(categoriesRequest)

                let tagsRequest: NSFetchRequest<Tag> = Tag.fetchRequest()
                let tags = try context.fetch(tagsRequest)

                // 为每个分类创建示例产品
                createSampleProductsForCategories(categories, tags: tags, in: context)

                // 保存更改
                if context.hasChanges {
                    try context.save()
                    print("[Persistence] 示例数据创建完成")
                }

            } catch {
                print("[Persistence] 创建示例数据时出错: \(error.localizedDescription)")
            }
        }
    }

    /// 删除所有示例数据
    @MainActor
    func deleteSampleData() async -> (success: Bool, message: String, deletedCount: Int) {
        let context = container.viewContext

        return await withCheckedContinuation { continuation in
            context.perform {
                do {
                    // 识别示例数据
                    let sampleProducts = self.identifySampleProducts(in: context)
                    let deletedCount = sampleProducts.count

                    if sampleProducts.isEmpty {
                        continuation.resume(returning: (true, "未发现示例数据", 0))
                        return
                    }

                    // 删除示例产品及其关联数据
                    for product in sampleProducts {
                        // 删除关联的订单
                        if let order = product.order {
                            context.delete(order)
                        }

                        // 删除关联的说明书
                        if let manuals = product.manuals as? Set<Manual> {
                            for manual in manuals {
                                context.delete(manual)
                            }
                        }

                        // 删除产品本身
                        context.delete(product)
                    }

                    // 保存更改
                    try context.save()

                    let message = "成功删除 \(deletedCount) 个示例产品及其关联数据"
                    print("[Persistence] \(message)")
                    continuation.resume(returning: (true, message, deletedCount))

                } catch {
                    let errorMessage = "删除示例数据时出错: \(error.localizedDescription)"
                    print("[Persistence] \(errorMessage)")
                    continuation.resume(returning: (false, errorMessage, 0))
                }
            }
        }
    }

    /// 检查是否存在示例数据
    @MainActor
    func hasSampleData() async -> Bool {
        let context = container.viewContext

        return await withCheckedContinuation { continuation in
            context.perform {
                let sampleProducts = self.identifySampleProducts(in: context)
                continuation.resume(returning: !sampleProducts.isEmpty)
            }
        }
    }

    /// 获取示例数据统计信息
    @MainActor
    func getSampleDataInfo() async -> (productCount: Int, categoryCount: Int, hasOrders: Bool) {
        let context = container.viewContext

        return await withCheckedContinuation { continuation in
            context.perform {
                let sampleProducts = self.identifySampleProducts(in: context)
                let categories = Set(sampleProducts.compactMap { $0.category })
                let hasOrders = sampleProducts.contains { $0.order != nil }

                continuation.resume(returning: (
                    productCount: sampleProducts.count,
                    categoryCount: categories.count,
                    hasOrders: hasOrders
                ))
            }
        }
    }

    /// 识别示例产品
    private func identifySampleProducts(in context: NSManagedObjectContext) -> [Product] {
        let request: NSFetchRequest<Product> = Product.fetchRequest()

        // 示例产品的特征：特定的品牌和型号组合
        let sampleProductIdentifiers = [
            ("iPhone 15 Pro", "Apple", "A3102"),
            ("MacBook Pro", "Apple", "M3 Max"),
            ("iPad Air", "Apple", "M2"),
            ("AirPods Pro", "Apple", "第二代"),
            ("小米空气净化器", "小米", "Pro H"),
            ("戴森吸尘器", "Dyson", "V15"),
            ("美的电饭煲", "美的", "MB-WFS4029"),
            ("海尔冰箱", "海尔", "BCD-470WDPG"),
            ("宜家沙发", "IKEA", "KIVIK"),
            ("办公椅", "Herman Miller", "Aeron"),
            ("书桌", "宜家", "BEKANT"),
            ("床垫", "席梦思", "黑标"),
            ("九阳豆浆机", "九阳", "DJ13B-D08D"),
            ("苏泊尔炒锅", "苏泊尔", "PC32H1"),
            ("摩飞榨汁机", "摩飞", "MR9600"),
            ("双立人刀具", "双立人", "Twin Signature"),
            ("跑步机", "舒华", "SH-T5517i"),
            ("哑铃", "海德", "可调节"),
            ("瑜伽垫", "Lululemon", "The Mat 5mm"),
            ("健身手环", "小米", "Mi Band 8"),
            ("登山包", "始祖鸟", "Beta AR 65"),
            ("帐篷", "MSR", "Hubba Hubba NX"),
            ("睡袋", "Mountain Hardwear", "Phantom 32"),
            ("登山鞋", "Salomon", "X Ultra 4"),
            ("行车记录仪", "70迈", "A800S"),
            ("车载充电器", "Anker", "PowerDrive Speed+"),
            ("轮胎", "米其林", "Pilot Sport 4"),
            ("机油", "美孚", "1号全合成"),
            ("蓝牙音箱", "Bose", "SoundLink Revolve+"),
            ("移动电源", "Anker", "PowerCore 26800"),
            ("无线鼠标", "罗技", "MX Master 3S"),
            ("机械键盘", "Cherry", "MX Keys")
        ]

        do {
            let allProducts = try context.fetch(request)

            // 筛选出示例产品
            let sampleProducts = allProducts.filter { product in
                guard let productName = product.name,
                      let productBrand = product.brand,
                      let productModel = product.model else {
                    return false
                }

                return sampleProductIdentifiers.contains { (name, brand, model) in
                    productName == name && productBrand == brand && productModel == model
                }
            }

            return sampleProducts

        } catch {
            print("[Persistence] 识别示例产品时出错: \(error.localizedDescription)")
            return []
        }
    }

    /// 为分类创建示例产品
    private func createSampleProductsForCategories(_ categories: [Category], tags: [Tag], in context: NSManagedObjectContext) {
        // 示例产品数据
        let sampleProducts: [String: [(name: String, brand: String, model: String, tagNames: [String])]] = [
            "电子产品": [
                ("iPhone 15 Pro", "Apple", "A3102", ["新购", "重要"]),
                ("MacBook Pro", "Apple", "M3 Max", ["重要", "收藏"]),
                ("iPad Air", "Apple", "M2", ["新购"]),
                ("AirPods Pro", "Apple", "第二代", ["收藏"])
            ],
            "家用电器": [
                ("小米空气净化器", "小米", "Pro H", ["新购"]),
                ("戴森吸尘器", "Dyson", "V15", ["重要", "收藏"]),
                ("美的电饭煲", "美的", "MB-WFS4029", ["需维修"]),
                ("海尔冰箱", "海尔", "BCD-470WDPG", ["重要"])
            ],
            "家具家私": [
                ("宜家沙发", "IKEA", "KIVIK", ["收藏"]),
                ("办公椅", "Herman Miller", "Aeron", ["重要", "收藏"]),
                ("书桌", "宜家", "BEKANT", ["新购"]),
                ("床垫", "席梦思", "黑标", ["重要"])
            ],
            "厨房用品": [
                ("九阳豆浆机", "九阳", "DJ13B-D08D", ["需维修"]),
                ("苏泊尔炒锅", "苏泊尔", "PC32H1", ["收藏"]),
                ("摩飞榨汁机", "摩飞", "MR9600", ["新购"]),
                ("双立人刀具", "双立人", "Twin Signature", ["重要"])
            ],
            "健身器材": [
                ("跑步机", "舒华", "SH-T5517i", ["重要", "收藏"]),
                ("哑铃", "海德", "可调节", ["新购"]),
                ("瑜伽垫", "Lululemon", "The Mat 5mm", ["收藏"]),
                ("健身手环", "小米", "Mi Band 8", ["新购"])
            ],
            "户外装备": [
                ("登山包", "始祖鸟", "Beta AR 65", ["重要", "收藏"]),
                ("帐篷", "MSR", "Hubba Hubba NX", ["收藏"]),
                ("睡袋", "Mountain Hardwear", "Phantom 32", ["新购"]),
                ("登山鞋", "Salomon", "X Ultra 4", ["重要"])
            ],
            "汽车配件": [
                ("行车记录仪", "70迈", "A800S", ["新购", "重要"]),
                ("车载充电器", "Anker", "PowerDrive Speed+", ["收藏"]),
                ("轮胎", "米其林", "Pilot Sport 4", ["需维修"]),
                ("机油", "美孚", "1号全合成", ["新购"])
            ],
            "其他": [
                ("蓝牙音箱", "Bose", "SoundLink Revolve+", ["收藏"]),
                ("移动电源", "Anker", "PowerCore 26800", ["新购"]),
                ("无线鼠标", "罗技", "MX Master 3S", ["重要"]),
                ("机械键盘", "Cherry", "MX Keys", ["收藏"])
            ]
        ]

        // 为每个分类创建产品
        for category in categories {
            guard let categoryName = category.name,
                  let products = sampleProducts[categoryName] else { continue }

            for productData in products {
                // 创建产品
                let product = Product.createProduct(
                    in: context,
                    name: productData.name,
                    brand: productData.brand,
                    model: productData.model,
                    category: category
                )

                // 添加标签
                for tagName in productData.tagNames {
                    if let tag = tags.first(where: { $0.name == tagName }) {
                        product.addTag(tag)
                    }
                }

                // 添加一些随机的创建时间（过去30天内）
                let randomDaysAgo = Int.random(in: 0...30)
                product.createdAt = Calendar.current.date(byAdding: .day, value: -randomDaysAgo, to: Date())
                product.updatedAt = product.createdAt

                // 为部分产品添加订单信息
                if Bool.random() && productData.name.contains("iPhone") || productData.name.contains("MacBook") || productData.name.contains("iPad") {
                    createSampleOrder(for: product, in: context)
                }

                print("[Persistence] 创建示例产品: \(productData.name) - \(categoryName)")
            }
        }
    }

    /// 为产品创建示例订单
    private func createSampleOrder(for product: Product, in context: NSManagedObjectContext) {
        let platforms = ["Apple Store", "京东", "天猫", "苏宁易购", "拼多多"]
        let randomPlatform = platforms.randomElement() ?? "Apple Store"

        let orderNumber = "ORD\(Int.random(in: 100000...999999))"
        let orderDate = Calendar.current.date(byAdding: .day, value: -Int.random(in: 1...90), to: Date()) ?? Date()
        let warrantyPeriod = [12, 24, 36].randomElement() ?? 12

        let _ = Order.createOrder(
            in: context,
            orderNumber: orderNumber,
            platform: randomPlatform,
            orderDate: orderDate,
            warrantyPeriod: warrantyPeriod,
            product: product
        )

        print("[Persistence] 为产品 \(product.name ?? "") 创建订单: \(orderNumber)")
    }
}
