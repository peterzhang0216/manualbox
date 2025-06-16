import XCTest
import CoreData
@testable import ManualBox

/// 服务层测试基类，提供服务隔离和数据隔离
/// 适用于测试 OCRService、SearchService 等服务层组件
class IsolatedServiceTestCase: IsolatedDataTestCase {
    
    // MARK: - 服务实例
    
    /// 测试专用的 OCR 服务
    /// 在每个测试开始时重置状态
    private(set) var ocrService: OCRService!
    
    /// 测试专用的搜索服务
    private(set) var searchService: ManualSearchService!
    
    /// 测试专用的文件处理服务
    private(set) var fileProcessingService: FileProcessingService!
    
    // MARK: - 生命周期管理
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // 设置服务隔离环境
        setupServiceIsolation()
        
        print("🔧 [\(String(describing: type(of: self)))] 服务环境初始化完成")
    }
    
    override func tearDownWithError() throws {
        // 清理服务状态
        cleanupServiceState()
        
        try super.tearDownWithError()
        
        print("🔧 [\(String(describing: type(of: self)))] 服务环境清理完成")
    }
    
    // MARK: - 私有方法
    
    /// 设置服务隔离环境
    @MainActor
    private func setupServiceIsolation() {
        // 重置 OCR 服务状态
        ocrService = OCRService.shared
        ocrService.cancelAllProcessing()
        
        // 创建测试专用的搜索服务
        searchService = ManualSearchService(context: testContext)
        
        // 获取文件处理服务
        fileProcessingService = FileProcessingService.shared
        
        // 清理服务容器（如果使用依赖注入）
        ServiceContainer.shared.clear()
        ServiceRegistrationManager.registerAllServices()
        
        // 注册测试专用的 repositories
        registerTestRepositories()
    }
    
    /// 注册测试专用的仓储
    private func registerTestRepositories() {
        let container = ServiceContainer.shared
        
        // 注册使用测试上下文的仓储
        container.register(ManualRepository.self) { _ in
            ManualRepository(context: self.testContext)
        }
        
        container.register(ProductRepository.self) { _ in
            ProductRepository(context: self.testContext)
        }
        
        container.register(CategoryRepository.self) { _ in
            CategoryRepository(context: self.testContext)
        }
        
        container.register(TagRepository.self) { _ in
            TagRepository(context: self.testContext)
        }
    }
    
    /// 清理服务状态
    @MainActor
    private func cleanupServiceState() {
        // 取消所有 OCR 操作
        ocrService?.cancelAllProcessing()
        
        // 清理搜索服务
        searchService = nil
        
        // 清理服务容器
        ServiceContainer.shared.clear()
        
        // 重置文件处理服务状态（如果需要）
        // fileProcessingService 是单例，无需清理
    }
    
    // MARK: - 辅助方法
    
    /// 等待 OCR 处理完成
    @MainActor
    func waitForOCRCompletion(timeout: TimeInterval = 10.0) {
        let expectation = self.expectation(description: "OCR处理完成")
        
        func checkCompletion() {
            if !ocrService.isProcessing && ocrService.processingQueue.isEmpty {
                expectation.fulfill()
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    checkCompletion()
                }
            }
        }
        
        checkCompletion()
        wait(for: [expectation], timeout: timeout)
    }
    
    /// 创建测试用的图像数据
    func createTestImageData() -> Data {
        // 创建 1x1 像素的 PNG 图像数据
        let size = CGSize(width: 1, height: 1)
        let rect = CGRect(origin: .zero, size: size)
        
        #if os(iOS)
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        UIColor.white.setFill()
        UIRectFill(rect)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image?.pngData() ?? Data()
        #elseif os(macOS)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.white.drawSwatch(in: rect)
        image.unlockFocus()
        
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let imageRep = NSBitmapImageRep(cgImage: cgImage),
              let pngData = imageRep.representation(using: .png, properties: [:]) else {
            return Data()
        }
        return pngData
        #endif
    }
    
    /// 验证 OCR 服务状态
    @MainActor
    func assertOCRServiceIdle(file: StaticString = #file, line: UInt = #line) {
        XCTAssertFalse(ocrService.isProcessing, 
                      "OCR服务应该处于空闲状态", 
                      file: file, line: line)
        XCTAssertEqual(ocrService.currentProgress, 0.0, 
                      "OCR进度应该为0", 
                      file: file, line: line)
        XCTAssertTrue(ocrService.processingQueue.isEmpty, 
                     "OCR队列应该为空", 
                     file: file, line: line)
    }
    
    /// 执行搜索并验证结果
    func performSearchAndValidate(query: String, 
                                 expectedCount: Int? = nil,
                                 file: StaticString = #file,
                                 line: UInt = #line) -> [Manual] {
        let results = searchService.searchManuals(query: query)
        
        if let expectedCount = expectedCount {
            XCTAssertEqual(results.count, expectedCount,
                          "搜索结果数量不匹配",
                          file: file, line: line)
        }
        
        return results
    }
}

// MARK: - OCR 测试专用扩展

extension IsolatedServiceTestCase {
    
    /// 执行 OCR 并等待完成
    @MainActor
    func performOCRAndWait(on manual: Manual, 
                          timeout: TimeInterval = 10.0) throws -> OCRResult {
        var result: OCRResult?
        var error: Error?
        
        let expectation = self.expectation(description: "OCR完成")
        
        ocrService.performOCR(on: manual) { ocrResult in
            switch ocrResult {
            case .success(let ocrData):
                result = ocrData
            case .failure(let ocrError):
                error = ocrError
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: timeout)
        
        if let error = error {
            throw error
        }
        
        guard let result = result else {
            throw OCRError.processingFailed
        }
        
        return result
    }
    
    /// 创建带有 OCR 内容的测试说明书
    @MainActor
    func createManualWithOCRContent(fileName: String = "测试OCR说明书.png",
                                   ocrText: String = "测试OCR文本内容") -> Manual {
        let imageData = createTestImageData()
        let manual = Manual.createManual(
            in: testContext,
            fileName: fileName,
            fileData: imageData,
            fileType: "png"
        )
        
        // 模拟 OCR 处理结果
        manual.ocrContent = ocrText
        manual.isOCRProcessed = true
        manual.ocrProcessedAt = Date()
        
        return manual
    }
}
