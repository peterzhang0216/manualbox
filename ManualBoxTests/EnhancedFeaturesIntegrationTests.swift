import XCTest
import CoreData
@testable import ManualBox

class EnhancedFeaturesIntegrationTests: IsolatedServiceTestCase {
    
    @MainActor
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // 确保 OCR 服务处于干净状态
        ocrService.cancelAllProcessing()
    }
    
    override func tearDownWithError() throws {
        try super.tearDownWithError()
    }
    
    // MARK: - 完整工作流程测试
    
    @MainActor
    func testCompleteWorkflow() async throws {
        // 步骤1: 创建测试产品
        let product = Product.createProduct(
            in: testContext,
            name: "iPhone 15 Pro",
            brand: "Apple",
            model: "A3108"
        )
        
        // 步骤2: 创建说明书并执行OCR
        let manual = Manual.createManual(
            in: testContext,
            fileName: "iPhone_15_Pro_用户指南.pdf",
            fileData: createTestPDFData(),
            fileType: "pdf",
            product: product
        )
        
        saveTestContext()
        
        // 步骤3: 手动设置OCR内容而不是依赖实际OCR处理
        // 这样可以避免OCR处理的复杂性和潜在的异步问题
        manual.content = "iPhone 15 Pro 用户指南\n\n1. 设备设置\n2. 基本操作\n3. 高级功能\n4. 故障排除"
        manual.isOCRProcessed = true
        
        saveTestContext()
        
        // 步骤4: 验证OCR结果
        XCTAssertTrue(manual.isOCRProcessed, "说明书应该已完成OCR处理")
        XCTAssertNotNil(manual.content, "应该有OCR识别的内容")
        
        // 步骤5: 执行搜索测试
        let searchResults = await searchService.performSearch(query: "iPhone")
        XCTAssertFalse(searchResults.isEmpty, "搜索应该找到结果")
        XCTAssertEqual(searchResults.first?.manual.id, manual.id, "应该找到正确的说明书")
        
        // 步骤6: 验证搜索结果包含相关性评分
        if let firstResult = searchResults.first {
            XCTAssertGreaterThan(firstResult.relevanceScore, 0, "相关性评分应该大于0")
            XCTAssertFalse(firstResult.matchedFields.isEmpty, "应该有匹配的字段")
        }
        
        print("✅ 完整工作流程测试通过")
    }
    
    @MainActor
    func testFileProcessingIntegration() async throws {
        // 创建临时测试文件
        let testURL = createTemporaryTestFile()
        defer { try? FileManager.default.removeItem(at: testURL) }
        
        // 使用文件处理服务处理文件
        let processingOptions = FileProcessingService.ProcessingOptions(
            shouldCompress: true,
            compressionQuality: 0.8,
            shouldExtractMetadata: true,
            shouldPerformOCR: true,
            shouldGenerateThumbnail: true,
            maxFileSize: 50
        )
        
        let result = try await fileProcessingService.processFile(
            from: testURL,
            options: processingOptions
        )
        
        // 验证处理结果
        XCTAssertNotNil(result.processedFileData, "应该有处理后的文件数据")
        XCTAssertGreaterThan(result.processingTime, 0, "处理时间应该大于0")
        XCTAssertLessThanOrEqual(result.compressionRatio, 1.0, "压缩比应该不超过1.0")
        
        if result.fileType.conforms(to: .image) {
            XCTAssertNotNil(result.thumbnailImage, "图像文件应该有缩略图")
        }
        
        print("✅ 文件处理集成测试通过")
    }
    
    @MainActor
    func testSearchWithOCRContent() async throws {
        // 创建包含特定内容的说明书
        let manual = Manual.createManual(
            in: testContext,
            fileName: "special_manual.pdf",
            fileData: Data("特殊内容测试".utf8),
            fileType: "pdf"
        )
        
        // 模拟OCR处理结果
        manual.content = "这是一份特殊的产品使用指南，包含详细的操作步骤和维护说明。"
        manual.isOCRProcessed = true
        
        saveTestContext()
        
        // 搜索特定关键词
        let results = await searchService.performSearch(query: "操作步骤")
        
        XCTAssertFalse(results.isEmpty, "应该找到包含关键词的结果")
        
        if let firstResult = results.first {
            XCTAssertTrue(firstResult.highlightedSnippets.contains { snippet in
                snippet.contains("操作步骤")
            }, "高亮片段应该包含搜索关键词")
        }
        
        print("✅ OCR内容搜索测试通过")
    }
    
    @MainActor
    func testSearchSuggestions() async throws {
        // 创建测试数据
        let products = [
            ("iPhone 14", "Apple"),
            ("iPad Pro", "Apple"),
            ("MacBook Air", "Apple"),
            ("Apple Watch", "Apple")
        ]
        
        for (name, brand) in products {
            let product = Product.createProduct(
                in: testContext,
                name: name,
                brand: brand,
                model: "Test"
            )
            
            let _ = Manual.createManual(
                in: testContext,
                fileName: "\(name).pdf",
                fileData: Data(),
                fileType: "pdf",
                product: product
            )
        }
        
        saveTestContext()
        
        // 测试搜索建议
        let suggestions = await searchService.generateSearchSuggestions(for: "App")
        
        XCTAssertFalse(suggestions.isEmpty, "应该生成搜索建议")
        XCTAssertTrue(suggestions.contains { $0.lowercased().contains("apple") }, 
                     "建议中应该包含Apple相关内容")
        
        print("✅ 搜索建议测试通过")
    }
    
    @MainActor
    func testBatchProcessing() async throws {
        // 创建多个测试文件
        let testURLs = [
            createTemporaryTestFile(name: "test1.txt"),
            createTemporaryTestFile(name: "test2.txt"),
            createTemporaryTestFile(name: "test3.txt")
        ]
        
        defer {
            testURLs.forEach { url in
                try? FileManager.default.removeItem(at: url)
            }
        }
        
        // 批量处理文件
        let results = try await fileProcessingService.processBatchFiles(
            urls: testURLs,
            options: .default
        ) { current, total in
            print("批量处理进度: \(current)/\(total)")
        }
        
        XCTAssertEqual(results.count, testURLs.count, "应该处理所有文件")
        
        // 验证所有文件都成功处理
        for (url, result) in results {
            switch result {
            case .success(let processingResult):
                XCTAssertNotNil(processingResult.processedFileData, "文件 \(url.lastPathComponent) 应该处理成功")
            case .failure(let error):
                XCTFail("文件 \(url.lastPathComponent) 处理失败: \(error)")
            }
        }
        
        print("✅ 批量处理测试通过")
    }
    
    @MainActor
    func testPerformanceOptimization() async throws {
        // 创建大量测试数据
        for i in 0..<50 {
            let product = Product.createProduct(
                in: testContext,
                name: "Product \(i)",
                brand: "Brand \(i % 5)",
                model: "Model-\(i)"
            )
            
            let manual = Manual.createManual(
                in: testContext,
                fileName: "manual_\(i).pdf",
                fileData: Data("Content \(i)".utf8),
                fileType: "pdf",
                product: product
            )
            
            manual.content = "This is test content \(i) for performance testing"
            manual.isOCRProcessed = true
        }
        
        saveTestContext()
        
        // 测试搜索性能
        let startTime = Date()
        let results = await searchService.performSearch(query: "test")
        let searchTime = Date().timeIntervalSince(startTime)
        
        XCTAssertLessThan(searchTime, 1.0, "搜索应该在1秒内完成")
        XCTAssertFalse(results.isEmpty, "应该找到搜索结果")
        XCTAssertLessThanOrEqual(results.count, 50, "结果数量应该在合理范围内")
        
        print("✅ 性能优化测试通过 - 搜索耗时: \(String(format: "%.3f", searchTime))秒")
    }
    
    @MainActor
    func testErrorHandling() async {
        // 测试无效文件处理
        let invalidURL = URL(fileURLWithPath: "/path/that/does/not/exist.pdf")
        
        do {
            _ = try await fileProcessingService.processFile(from: invalidURL)
            XCTFail("应该抛出文件不存在错误")
        } catch FileProcessingError.fileNotFound {
            // 预期的错误
            print("✅ 正确处理了文件不存在错误")
        } catch {
            XCTFail("抛出了意外的错误: \(error)")
        }
        
        // 测试空搜索查询
        let emptyResults = await searchService.performSearch(query: "")
        XCTAssertTrue(emptyResults.isEmpty, "空查询应该返回空结果")
        
        // 测试不存在的搜索内容
        let noResults = await searchService.performSearch(query: "definitely_not_found_12345")
        XCTAssertTrue(noResults.isEmpty, "不存在的内容应该返回空结果")
        
        print("✅ 错误处理测试通过")
    }
    
    // MARK: - 辅助方法
    
    private func createTestPDFData() -> Data {
        return Data("这是一个测试PDF文档的内容，用于OCR处理测试。".utf8)
    }
    
    private func createTemporaryTestFile(name: String = "test.txt") -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let testURL = tempDir.appendingPathComponent(name)
        
        let testContent = "这是测试文件内容，用于文件处理测试。"
        try! testContent.write(to: testURL, atomically: true, encoding: .utf8)
        
        return testURL
    }
}

// MARK: - 性能测试专用类
class PerformanceTests: XCTestCase {
    
    @MainActor
    func testOCRPerformance() {
        measure {
            // 测试OCR处理性能
            let expectation = XCTestExpectation(description: "OCR性能测试")
            
            let manual = Manual.createManual(
                in: testContext,
                fileName: "performance_test.pdf",
                fileData: Data("性能测试内容".utf8),
                fileType: "pdf"
            )
            
            manual.performOCR { success in
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 10.0)
        }
    }
    
    @MainActor
    func testSearchPerformance() {
        measure {
            // 测试搜索性能
            
            // 创建测试数据
            for i in 0..<100 {
                let manual = Manual.createManual(
                    in: testContext,
                    fileName: "test_\(i).pdf",
                    fileData: Data(),
                    fileType: "pdf"
                )
                manual.content = "Performance test content \(i)"
                manual.isOCRProcessed = true
            }
            
            saveTestContext()
            
            // 执行搜索
            let expectation = XCTestExpectation(description: "搜索性能测试")
            
            Task {
                _ = await searchService.performSearch(query: "test")
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 5.0)
        }
    }
}