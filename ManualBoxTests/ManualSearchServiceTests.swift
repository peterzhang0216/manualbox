import XCTest
import CoreData
@testable import ManualBox

class ManualSearchServiceTests: XCTestCase {
    
    var persistenceController: PersistenceController!
    var context: NSManagedObjectContext!
    var searchService: ManualSearchService!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // 创建内存中的Core Data堆栈用于测试
        persistenceController = PersistenceController(inMemory: true)
        context = persistenceController.container.viewContext
        searchService = ManualSearchService(context: context)
    }
    
    override func tearDownWithError() throws {
        context = nil
        persistenceController = nil
        searchService = nil
        try super.tearDownWithError()
    }
    
    // MARK: - 搜索服务基础功能测试
    
    @MainActor
    func testSearchServiceInitialization() {
        XCTAssertNotNil(searchService, "搜索服务应该能够正常初始化")
        XCTAssertFalse(searchService.isSearching, "初始状态下不应该正在搜索")
        XCTAssertTrue(searchService.searchResults.isEmpty, "初始状态下搜索结果应该为空")
        XCTAssertTrue(searchService.searchSuggestions.isEmpty, "初始状态下搜索建议应该为空")
    }
    
    @MainActor
    func testSearchConfigurationDefaults() {
        let defaultConfig = ManualSearchService.SearchConfiguration.default
        
        XCTAssertTrue(defaultConfig.enableFuzzySearch, "默认配置应该启用模糊搜索")
        XCTAssertTrue(defaultConfig.enableSynonymSearch, "默认配置应该启用同义词搜索")
        XCTAssertEqual(defaultConfig.maxResults, 50, "默认最大结果数应该为50")
        XCTAssertEqual(defaultConfig.minRelevanceScore, 0.1, "默认最小相关性分数应该为0.1")
        XCTAssertEqual(defaultConfig.searchFields.count, 7, "默认应该搜索所有字段")
    }
    
    @MainActor
    func testSearchFieldWeights() {
        let fileName = ManualSearchService.SearchConfiguration.SearchField.fileName
        let content = ManualSearchService.SearchConfiguration.SearchField.content
        let productName = ManualSearchService.SearchConfiguration.SearchField.productName
        
        XCTAssertEqual(fileName.weight, 1.0, "文件名权重应该最高")
        XCTAssertEqual(productName.weight, 0.9, "产品名称权重应该为0.9")
        XCTAssertEqual(content.weight, 0.8, "内容权重应该为0.8")
    }
    
    // MARK: - 搜索功能测试
    
    @MainActor
    func testEmptyQuerySearch() async {
        let results = await searchService.performSearch(query: "")
        
        XCTAssertTrue(results.isEmpty, "空查询应该返回空结果")
        XCTAssertFalse(searchService.isSearching, "搜索完成后isSearching应该为false")
    }
    
    @MainActor
    func testBasicSearchWithTestData() async throws {
        // 创建测试数据
        try createTestData()
        
        // 执行搜索
        let results = await searchService.performSearch(query: "iPhone")
        
        XCTAssertFalse(results.isEmpty, "应该找到包含iPhone的结果")
        XCTAssertFalse(searchService.isSearching, "搜索完成后isSearching应该为false")
        
        // 验证结果包含相关性评分
        if let firstResult = results.first {
            XCTAssertGreaterThan(firstResult.relevanceScore, 0, "相关性评分应该大于0")
            XCTAssertEqual(firstResult.manual.product?.name, "iPhone 14 Pro", "应该找到正确的产品")
        }
    }
    
    @MainActor
    func testContentSearch() async throws {
        // 创建包含OCR内容的测试数据
        try createTestDataWithOCRContent()
        
        // 搜索OCR内容
        let results = await searchService.performSearch(query: "操作指南")
        
        XCTAssertFalse(results.isEmpty, "应该在OCR内容中找到结果")
        
        if let firstResult = results.first {
            XCTAssertTrue(firstResult.manual.isOCRProcessed, "找到的说明书应该已经处理过OCR")
            XCTAssertNotNil(firstResult.highlightedSnippets.first, "应该有高亮片段")
        }
    }
    
    @MainActor
    func testRelevanceScoring() async throws {
        // 创建多个测试数据用于评分测试
        try createMultipleTestData()
        
        // 搜索应该按相关性排序
        let results = await searchService.performSearch(query: "Apple")
        
        XCTAssertGreaterThanOrEqual(results.count, 2, "应该找到多个结果")
        
        // 验证结果按相关性排序
        for i in 0..<(results.count - 1) {
            XCTAssertGreaterThanOrEqual(
                results[i].relevanceScore,
                results[i + 1].relevanceScore,
                "结果应该按相关性降序排列"
            )
        }
    }
    
    // MARK: - 搜索建议测试
    
    @MainActor
    func testSearchSuggestions() async throws {
        // 创建测试数据
        try createTestData()
        
        // 测试搜索建议
        let suggestions = await searchService.generateSearchSuggestions(for: "iP")
        
        XCTAssertFalse(suggestions.isEmpty, "应该生成搜索建议")
        XCTAssertTrue(suggestions.contains { $0.lowercased().contains("iphone") }, "建议中应该包含iPhone相关内容")
    }
    
    @MainActor
    func testSearchSuggestionsTooShort() async {
        let suggestions = await searchService.generateSearchSuggestions(for: "i")
        
        XCTAssertTrue(suggestions.isEmpty, "太短的查询不应该生成建议")
    }
    
    // MARK: - 搜索历史测试
    
    @MainActor
    func testSearchHistoryManagement() async {
        // 执行几次搜索
        await searchService.performSearch(query: "iPhone")
        await searchService.performSearch(query: "iPad")
        await searchService.performSearch(query: "MacBook")
        
        // 验证历史记录功能（通过搜索建议间接验证）
        let suggestions = await searchService.generateSearchSuggestions(for: "iP")
        
        // 应该包含历史搜索的iPhone和iPad
        let suggestionText = suggestions.joined(separator: " ").lowercased()
        XCTAssertTrue(suggestionText.contains("iphone") || suggestionText.contains("ipad"), 
                     "搜索建议应该包含历史搜索内容")
    }
    
    // MARK: - 错误处理测试
    
    @MainActor
    func testSearchWithCorruptedData() async {
        // 创建损坏的测试数据
        let manual = Manual.createManual(
            in: context,
            fileName: "corrupted.pdf",
            fileData: Data(), // 空数据
            fileType: "pdf"
        )
        manual.content = nil // 没有内容
        
        try! context.save()
        
        // 搜索不应该崩溃
        let results = await searchService.performSearch(query: "corrupted")
        
        // 可能找到文件名匹配，但不应该崩溃
        XCTAssertNoThrow("搜索损坏数据不应该抛出异常")
    }
    
    // MARK: - 性能测试
    
    @MainActor
    func testSearchPerformance() async throws {
        // 创建大量测试数据
        try createLargeTestDataSet()
        
        let startTime = Date()
        let results = await searchService.performSearch(query: "test")
        let searchTime = Date().timeIntervalSince(startTime)
        
        XCTAssertLessThan(searchTime, 2.0, "搜索应该在2秒内完成")
        XCTAssertLessThanOrEqual(results.count, 50, "结果数量不应该超过配置的最大值")
    }
    
    // MARK: - 辅助方法
    
    private func createTestData() throws {
        // 创建分类
        let category = Category(context: context)
        category.id = UUID()
        category.name = "电子产品"
        category.icon = "iphone"
        
        // 创建标签
        let tag = Tag(context: context)
        tag.id = UUID()
        tag.name = "重要"
        tag.color = "red"
        
        // 创建产品
        let product = Product.createProduct(
            in: context,
            name: "iPhone 14 Pro",
            brand: "Apple",
            model: "A2894"
        )
        product.category = category
        product.tags = NSSet(array: [tag])
        
        // 创建说明书
        let manual = Manual.createManual(
            in: context,
            fileName: "iPhone_14_Pro_用户指南.pdf",
            fileData: Data("测试PDF内容".utf8),
            fileType: "pdf",
            product: product
        )
        
        try context.save()
    }
    
    private func createTestDataWithOCRContent() throws {
        let product = Product.createProduct(
            in: context,
            name: "智能手表",
            brand: "Apple",
            model: "Series 9"
        )
        
        let manual = Manual.createManual(
            in: context,
            fileName: "watch_manual.pdf",
            fileData: Data("测试PDF内容".utf8),
            fileType: "pdf",
            product: product
        )
        
        // 模拟OCR处理后的内容
        manual.content = "Apple Watch 操作指南\n\n1. 基本设置\n2. 健康监测\n3. 应用使用\n4. 故障排除"
        manual.isOCRProcessed = true
        
        try context.save()
    }
    
    private func createMultipleTestData() throws {
        let products = [
            ("iPhone 14", "Apple", "A2649"),
            ("iPad Pro", "Apple", "A2759"),
            ("MacBook Pro", "Apple", "A2485"),
            ("Galaxy S23", "Samsung", "SM-S911B")
        ]
        
        for (name, brand, model) in products {
            let product = Product.createProduct(
                in: context,
                name: name,
                brand: brand,
                model: model
            )
            
            let manual = Manual.createManual(
                in: context,
                fileName: "\(name.replacingOccurrences(of: " ", with: "_"))_manual.pdf",
                fileData: Data("测试内容".utf8),
                fileType: "pdf",
                product: product
            )
            
            manual.content = "\(name) 使用说明书内容"
            manual.isOCRProcessed = true
        }
        
        try context.save()
    }
    
    private func createLargeTestDataSet() throws {
        for i in 0..<100 {
            let product = Product.createProduct(
                in: context,
                name: "Test Product \(i)",
                brand: "Test Brand",
                model: "Model-\(i)"
            )
            
            let manual = Manual.createManual(
                in: context,
                fileName: "test_manual_\(i).pdf",
                fileData: Data("测试内容 \(i)".utf8),
                fileType: "pdf",
                product: product
            )
            
            manual.content = "Test content for product \(i)"
            manual.isOCRProcessed = true
        }
        
        try context.save()
    }
}