import Foundation
import CoreData

// MARK: - 服务注册配置管理器
class ServiceRegistrationManager {
    
    // MARK: - 注册所有服务
    static func registerAllServices(container: ServiceContainer = ServiceContainer.shared) {
        // 注册核心服务
        registerCoreServices(container)
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
        guard let persistenceController: PersistenceController = container.resolve(PersistenceController.self) else {
            print("❌ 无法解析 PersistenceController 服务")
            return
        }
        persistenceController.initializeDefaultData()
        
        print("✅ 核心服务初始化完成")
    }
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
    }
}