import Foundation
import CoreData

// MARK: - 服务注册配置管理器
class ServiceRegistrationManager {
    
    // MARK: - 注册所有服务
    static func registerAllServices(container: ServiceContainer = ServiceContainer.shared) {
        // 注册核心服务
        registerCoreServices(container)
        
        // 注册Repository服务
        registerRepositoryServices(container)
    }
    
    // MARK: - 核心服务注册
    private static func registerCoreServices(_ container: ServiceContainer) {
        // 持久化控制器 - 单例
        container.register(
            PersistenceController.self,
            lifetime: .singleton
        ) {
            PersistenceController.shared
        }
        
        // 平台适配器 - 单例
        container.register(
            PlatformAdapter.self,
            lifetime: .singleton
        ) {
            PlatformAdapter()
        }
        
        // 性能管理器 - 单例  
        container.register(
            PlatformPerformanceManager.self,
            lifetime: .singleton
        ) {
            PlatformPerformanceManager()
        }
    }
    
    // MARK: - Repository 服务注册
    private static func registerRepositoryServices(_ container: ServiceContainer) {
        let persistenceController = PersistenceController.shared
        
        // 注册主要的Repository实例（基于主上下文）
        container.register(
            ProductRepository.self,
            lifetime: .singleton
        ) {
            persistenceController.productRepository
        }
        
        container.register(
            CategoryRepository.self,
            lifetime: .singleton
        ) {
            persistenceController.categoryRepository
        }
        
        container.register(
            TagRepository.self,
            lifetime: .singleton
        ) {
            persistenceController.tagRepository
        }
        
        container.register(
            OrderRepository.self,
            lifetime: .singleton
        ) {
            persistenceController.orderRepository
        }
        
        container.register(
            RepairRecordRepository.self,
            lifetime: .singleton
        ) {
            persistenceController.repairRecordRepository
        }
        
        container.register(
            ManualRepository.self,
            lifetime: .singleton
        ) {
            persistenceController.manualRepository
        }
        
        // 注册RepositoryFactory
        container.register(
            RepositoryFactory.self,
            lifetime: .singleton
        ) {
            RepositoryFactory(persistenceController: persistenceController)
        }
    }
    
    // MARK: - 应用启动配置
    static func configureServices() {
        let container = ServiceContainer.shared
        
        // 注册所有服务
        registerAllServices(container: container)
        
        // 初始化核心服务
        Task {
            await initializeCoreServices(container)
        }
    }
    
    // 初始化需要异步初始化的服务
    private static func initializeCoreServices(_ container: ServiceContainer) async {
        // 初始化持久化控制器
        guard let _: PersistenceController = container.resolve(PersistenceController.self) else {
            print("❌ 无法解析 PersistenceController 服务")
            return
        }
        // 注意：默认数据初始化已移至 ManualBoxApp.swift 中的 onAppear，避免重复初始化
        
        print("✅ 核心服务初始化完成")
        print("✅ Repository 服务注册完成")
    }
}

// MARK: - Repository 工厂
class RepositoryFactory {
    private let persistenceController: PersistenceController
    
    init(persistenceController: PersistenceController) {
        self.persistenceController = persistenceController
    }
    
    /// 创建后台上下文的Repository实例
    func createBackgroundRepositories() -> BackgroundRepositories {
        let repositories = persistenceController.createBackgroundRepositories()
        return BackgroundRepositories(
            products: repositories.products,
            categories: repositories.categories,
            tags: repositories.tags,
            orders: repositories.orders,
            repairRecords: repositories.repairRecords,
            manuals: repositories.manuals
        )
    }
    
    /// 为特定上下文创建Repository实例
    func createRepositories(for context: NSManagedObjectContext) -> ContextRepositories {
        let repositories = persistenceController.repositories(for: context)
        return ContextRepositories(
            products: repositories.products,
            categories: repositories.categories,
            tags: repositories.tags,
            orders: repositories.orders,
            repairRecords: repositories.repairRecords,
            manuals: repositories.manuals
        )
    }
}

// MARK: - Repository 集合类型
struct BackgroundRepositories {
    let products: ProductRepository
    let categories: CategoryRepository
    let tags: TagRepository
    let orders: OrderRepository
    let repairRecords: RepairRecordRepository
    let manuals: ManualRepository
}

struct ContextRepositories {
    let products: ProductRepository
    let categories: CategoryRepository
    let tags: TagRepository
    let orders: OrderRepository
    let repairRecords: RepairRecordRepository
    let manuals: ManualRepository
}

// MARK: - 测试环境配置
extension ServiceRegistrationManager {
    
    // 为测试环境注册模拟服务
    @MainActor
    static func configureTestServices(_ container: ServiceContainer = ServiceContainer.shared) {
        // 注册模拟的持久化控制器
        container.register(
            PersistenceController.self,
            instance: PersistenceController.preview
        )
        
        // 注册其他测试服务
        registerCoreServices(container)
        registerRepositoryServices(container)
    }
}