import XCTest
import CoreData
@testable import ManualBox

// MARK: - Repository架构测试
final class RepositoryArchitectureTests: XCTestCase {
    var persistenceController: PersistenceController!
    var productRepository: ProductRepository!
    var categoryRepository: CategoryRepository!
    
    override func setUpWithError() throws {
        // 创建内存中的测试环境
        persistenceController = PersistenceController(inMemory: true)
        productRepository = persistenceController.productRepository
        categoryRepository = persistenceController.categoryRepository
        
        // 初始化默认数据
        persistenceController.initializeDefaultData()
    }

    override func tearDownWithError() throws {
        persistenceController = nil
        productRepository = nil
        categoryRepository = nil
    }
    
    // MARK: - 基础Repository功能测试
    
    func testProductRepositoryBasicOperations() async throws {
        // 测试创建产品
        let product = productRepository.create()
        product.name = "测试产品"
        product.brand = "测试品牌"
        product.model = "V1.0"
        product.createdAt = Date()
        product.updatedAt = Date()
        
        // 保存
        try await productRepository.save()
        
        // 测试获取产品
        let fetchedProducts = try await productRepository.fetchAll()
        XCTAssertEqual(fetchedProducts.count, 1)
        XCTAssertEqual(fetchedProducts.first?.name, "测试产品")
        
        // 测试通过ID获取
        guard let productId = product.id else {
            XCTFail("产品ID为空")
            return
        }
        
        let fetchedProduct = try await productRepository.fetchBy(id: productId)
        XCTAssertNotNil(fetchedProduct)
        XCTAssertEqual(fetchedProduct?.name, "测试产品")
        
        // 测试删除
        try await productRepository.delete(product)
        let productsAfterDelete = try await productRepository.fetchAll()
        XCTAssertEqual(productsAfterDelete.count, 0)
    }
    
    func testProductRepositorySearch() async throws {
        // 创建测试数据
        let product1 = productRepository.create()
        product1.name = "iPhone 15 Pro"
        product1.brand = "Apple"
        product1.model = "A3108"
        product1.createdAt = Date()
        product1.updatedAt = Date()
        
        let product2 = productRepository.create()
        product2.name = "MacBook Pro"
        product2.brand = "Apple"
        product2.model = "M3"
        product2.createdAt = Date()
        product2.updatedAt = Date()
        
        let product3 = productRepository.create()
        product3.name = "Samsung Galaxy"
        product3.brand = "Samsung"
        product3.model = "S24"
        product3.createdAt = Date()
        product3.updatedAt = Date()
        
        try await productRepository.save()
        
        // 测试搜索功能
        let appleProducts = try await productRepository.search("Apple")
        XCTAssertEqual(appleProducts.count, 2)
        
        let iPhoneProducts = try await productRepository.search("iPhone")
        XCTAssertEqual(iPhoneProducts.count, 1)
        
        let samsungProducts = try await productRepository.search("Samsung")
        XCTAssertEqual(samsungProducts.count, 1)
    }
    
    func testCategoryRepositoryWithProductCount() async throws {
        // 获取电子产品分类
        let categories = try await categoryRepository.fetchAll()
        guard let electronicCategory = categories.first(where: { $0.name == "电子产品" }) else {
            XCTFail("未找到电子产品分类")
            return
        }
        
        // 创建关联到该分类的产品
        let product1 = productRepository.create()
        product1.name = "产品1"
        product1.category = electronicCategory
        product1.createdAt = Date()
        product1.updatedAt = Date()
        
        let product2 = productRepository.create()
        product2.name = "产品2"
        product2.category = electronicCategory
        product2.createdAt = Date()
        product2.updatedAt = Date()
        
        try await productRepository.save()
        
        // 测试分类产品统计
        let categoriesWithCount = try await categoryRepository.fetchWithProductCount()
        let electronicCategoryWithCount = categoriesWithCount.first { $0.0.name == "电子产品" }
        
        XCTAssertNotNil(electronicCategoryWithCount)
        XCTAssertEqual(electronicCategoryWithCount?.1, 2)
    }
    
    // MARK: - 缓存功能测试
    
    func testRepositoryCache() async throws {
        // 创建产品
        let product = productRepository.create()
        product.name = "缓存测试产品"
        product.brand = "测试品牌"
        product.createdAt = Date()
        product.updatedAt = Date()
        
        try await productRepository.save()
        
        guard let productId = product.id else {
            XCTFail("产品ID为空")
            return
        }
        
        // 第一次获取（从数据库）
        let firstFetch = try await productRepository.fetchBy(id: productId)
        XCTAssertNotNil(firstFetch)
        
        // 第二次获取（应该从缓存）
        let secondFetch = try await productRepository.fetchBy(id: productId)
        XCTAssertNotNil(secondFetch)
        XCTAssertEqual(firstFetch?.name, secondFetch?.name)
    }
    
    // MARK: - 批量操作测试
    
    func testBatchOperations() async throws {
        // 创建多个产品
        var productIds: [UUID] = []
        
        for i in 1...5 {
            let product = productRepository.create()
            product.name = "批量产品 \(i)"
            product.brand = "批量品牌"
            product.createdAt = Date()
            product.updatedAt = Date()
            
            if let id = product.id {
                productIds.append(id)
            }
        }
        
        try await productRepository.save()
        
        // 测试批量更新
        var updates: [UUID: [String: Any]] = [:]
        for id in productIds {
            updates[id] = ["brand": "更新后的品牌"]
        }
        
        try await productRepository.batchUpdate(updates)
        
        // 验证更新
        let updatedProducts = try await productRepository.fetchAll()
        XCTAssertEqual(updatedProducts.count, 5)
        XCTAssertTrue(updatedProducts.allSatisfy { $0.brand == "更新后的品牌" })
        
        // 测试批量删除
        try await productRepository.batchDelete(Array(productIds.prefix(3)))
        
        // 验证删除
        let remainingProducts = try await productRepository.fetchAll()
        XCTAssertEqual(remainingProducts.count, 2)
    }
    
    // MARK: - Repository工厂测试
    
    func testRepositoryFactory() async throws {
        guard let factory: RepositoryFactory = ServiceContainer.shared.resolve(RepositoryFactory.self) else {
            XCTFail("无法解析RepositoryFactory")
            return
        }
        
        // 测试后台Repository创建
        let backgroundRepositories = factory.createBackgroundRepositories()
        XCTAssertNotNil(backgroundRepositories.products)
        XCTAssertNotNil(backgroundRepositories.categories)
        XCTAssertNotNil(backgroundRepositories.tags)
        XCTAssertNotNil(backgroundRepositories.orders)
        XCTAssertNotNil(backgroundRepositories.repairRecords)
        
        // 测试在后台上下文中创建产品
        let backgroundProduct = backgroundRepositories.products.create()
        backgroundProduct.name = "后台产品"
        backgroundProduct.brand = "后台品牌"
        backgroundProduct.createdAt = Date()
        backgroundProduct.updatedAt = Date()
        
        try await backgroundRepositories.products.save()
        
        // 验证产品已保存
        let allProducts = try await productRepository.fetchAll()
        XCTAssertEqual(allProducts.count, 1)
        XCTAssertEqual(allProducts.first?.name, "后台产品")
    }
    
    // MARK: - 性能测试
    
    func testRepositoryPerformance() async throws {
        // 测量批量创建性能
        measure {
            let expectation = XCTestExpectation(description: "批量创建完成")
            
            Task {
                for i in 1...100 {
                    let product = productRepository.create()
                    product.name = "性能测试产品 \(i)"
                    product.brand = "性能测试品牌"
                    product.createdAt = Date()
                    product.updatedAt = Date()
                }
                
                try await productRepository.save()
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 10.0)
        }
    }
}