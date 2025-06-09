import XCTest
import CoreData
@testable import ManualBox

final class ServiceLayerTests: XCTestCase {
    
    override func setUpWithError() throws {
        // 注册测试服务
        ServiceRegistrationManager.registerAllServices()
    }
    
    override func tearDownWithError() throws {
        // 清理测试环境
        ServiceContainer.shared.clear()
    }
    
    // MARK: - 服务注册测试
    
    func testServiceRegistration() {
        let container = ServiceContainer.shared
        
        // 验证核心服务已注册
        let repositoryFactory: RepositoryFactory? = container.resolve(RepositoryFactory.self)
        XCTAssertNotNil(repositoryFactory, "RepositoryFactory应该已注册")
        
        let productRepo: ProductRepository? = container.resolve(ProductRepository.self)
        XCTAssertNotNil(productRepo, "ProductRepository应该已注册")
        
        let categoryRepo: CategoryRepository? = container.resolve(CategoryRepository.self)
        XCTAssertNotNil(categoryRepo, "CategoryRepository应该已注册")
        
        let manualRepo: ManualRepository? = container.resolve(ManualRepository.self)
        XCTAssertNotNil(manualRepo, "ManualRepository应该已注册")
    }
    
    // MARK: - Repository工厂测试
    
    func testRepositoryFactory() {
        let container = ServiceContainer.shared
        guard let factory = container.resolve(RepositoryFactory.self) else {
            XCTFail("无法解析RepositoryFactory")
            return
        }
        
        // 测试创建背景仓库
        let backgroundRepos = factory.createBackgroundRepositories()
        XCTAssertNotNil(backgroundRepos.products, "背景ProductRepository应该存在")
        XCTAssertNotNil(backgroundRepos.categories, "背景CategoryRepository应该存在")
        XCTAssertNotNil(backgroundRepos.manuals, "背景ManualRepository应该存在")
    }
    
    // MARK: - ManualRepository集成测试
    
    func testManualRepositoryIntegration() {
        let container = ServiceContainer.shared
        guard let manualRepo = container.resolve(ManualRepository.self) else {
            XCTFail("无法解析ManualRepository")
            return
        }
        
        // 测试基本操作
        let manuals = manualRepo.fetchAll()
        XCTAssertNotNil(manuals, "应该能够获取手册列表")
        
        // 测试OCR统计
        let ocrStats = manualRepo.getOCRStatistics()
        XCTAssertNotNil(ocrStats, "应该能够获取OCR统计信息")
        
        // 测试文件类型统计
        let fileTypeStats = manualRepo.getFileTypeStatistics()
        XCTAssertNotNil(fileTypeStats, "应该能够获取文件类型统计信息")
    }
    
    // MARK: - 服务生命周期测试
    
    func testServiceLifetime() {
        let container = ServiceContainer.shared
        
        // 测试单例服务
        let repo1: ProductRepository? = container.resolve(ProductRepository.self)
        let repo2: ProductRepository? = container.resolve(ProductRepository.self)
        
        XCTAssertNotNil(repo1)
        XCTAssertNotNil(repo2)
        XCTAssertTrue(repo1 === repo2, "单例服务应该返回同一个实例")
    }
    
    // MARK: - 错误处理测试
    
    func testErrorHandling() {
        let container = ServiceContainer.shared
        
        // 测试解析不存在的服务
        let nonExistentService: String? = container.resolve(String.self)
        XCTAssertNil(nonExistentService, "不存在的服务应该返回nil")
        
        // 测试必需解析失败
        XCTAssertThrowsError(try {
            let _ = container.resolveRequired(String.self)
        }(), "必需解析不存在的服务应该抛出错误")
    }
}

// MARK: - 测试辅助扩展

extension ServiceContainer {
    func resolveRequired<T>(_ type: T.Type) throws -> T {
        guard let service = resolve(type) else {
            throw ServiceResolutionError.serviceNotFound(String(describing: type))
        }
        return service
    }
}

enum ServiceResolutionError: Error {
    case serviceNotFound(String)
}