import XCTest
import CoreData
import Vision
@testable import ManualBox

class OCRServiceTests: IsolatedServiceTestCase {
    
    // 移除原有的属性声明，因为现在继承自 IsolatedServiceTestCase
    // var persistenceController: PersistenceController!
    // var context: NSManagedObjectContext!
    // var ocrService: OCRService!
    
    // 不需要重写 setUpWithError 和 tearDownWithError
    // 父类已经提供了完整的隔离机制
    
    // MARK: - OCR Service Tests
    
    @MainActor
    func testOCRServiceInitialization() {
        // 使用父类提供的 assertOCRServiceIdle 方法
        assertOCRServiceIdle()
        
        // 验证服务是 ObservableObject
        XCTAssertTrue(ocrService is any ObservableObject, "服务应该是 ObservableObject")
    }
    
    @MainActor
    func testOCRConfigurationDefaults() {
        let defaultConfig = OCRConfiguration.default
        XCTAssertEqual(defaultConfig.recognitionLevel, .accurate, "默认应该使用高精度识别")
        XCTAssertTrue(defaultConfig.usesLanguageCorrection, "默认应该开启语言修正")
        XCTAssertTrue(defaultConfig.languages.contains("zh-Hans"), "默认应该支持简体中文")
        XCTAssertTrue(defaultConfig.languages.contains("en-US"), "默认应该支持英文")
        
        let fastConfig = OCRConfiguration.fast
        XCTAssertEqual(fastConfig.recognitionLevel, .fast, "快速配置应该使用快速识别")
        XCTAssertFalse(fastConfig.usesLanguageCorrection, "快速配置应该关闭语言修正")
    }
    
    @MainActor
    func testCreateManualWithImageData() async throws {
        // 使用父类提供的便捷方法创建测试图像数据
        let imageData = createTestImageData()
        
        // 创建测试说明书
        let manual = Manual.createManual(
            in: testContext,
            fileName: "test_manual.png",
            fileData: imageData,
            fileType: "png"
        )
        
        XCTAssertNotNil(manual, "应该能够创建说明书")
        XCTAssertEqual(manual.manualFileName, "test_manual.png", "文件名应该正确")
        XCTAssertEqual(manual.manualFileType, "png", "文件类型应该正确")
        XCTAssertTrue(manual.isImage, "应该识别为图像文件")
        XCTAssertFalse(manual.isPDF, "不应该识别为PDF文件")
        XCTAssertFalse(manual.isOCRProcessed, "初始状态不应该已处理OCR")
        
        // 保存到Core Data
        try saveTestContext()
        
        // 验证数据已保存 - 使用父类提供的便捷方法
        assertEntityCount(Manual.self, equals: 1)
    }
    
    @MainActor
    func testOCRProcessingFlow() async throws {
        // 创建测试图像数据
        let imageData = createTestImageData()
        
        // 创建测试说明书
        let manual = Manual.createManual(
            in: testContext,
            fileName: "test_ocr.png",
            fileData: imageData,
            fileType: "png"
        )
        
        try saveTestContext()
        
        let expectation = XCTestExpectation(description: "OCR处理完成")
        
        // 测试OCR处理
        manual.performOCR { success in
            // 由于是测试数据，OCR可能失败，但应该能够处理流程
            print("OCR处理结果: \(success)")
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 30.0)
    }
    
    @MainActor
    func testFastOCRProcessing() async throws {
        // 创建测试图像数据
        let imageData = createTestImageData()
        
        // 创建测试说明书
        let manual = Manual.createManual(
            in: testContext,
            fileName: "test_fast_ocr.png",
            fileData: imageData,
            fileType: "png"
        )
        
        try saveTestContext()
        
        let expectation = XCTestExpectation(description: "快速OCR处理完成")
        
        // 测试快速OCR处理
        manual.performFastOCR { success in
            print("快速OCR处理结果: \(success)")
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 15.0)
    }
    
    @MainActor
    func testOCRWithProgressCallback() async throws {
        // 创建测试图像数据
        let imageData = createTestImageData()
        
        // 创建测试说明书
        let manual = Manual.createManual(
            in: testContext,
            fileName: "test_progress_ocr.png",
            fileData: imageData,
            fileType: "png"
        )
        
        try saveTestContext()
        
        let expectation = XCTestExpectation(description: "带进度的OCR处理完成")
        var progressValues: [Float] = [] // 使用 Sendable 类型
        
        // 测试带进度回调的OCR处理
        manual.performOCRWithProgress(
            progressCallback: { @Sendable progress in
                DispatchQueue.main.async {
                    progressValues.append(progress)
                    print("OCR进度: \(progress)")
                }
            },
            completion: { @Sendable success in
                DispatchQueue.main.async {
                    print("带进度的OCR处理结果: \(success)")
                    print("记录的进度值: \(progressValues)")
                    expectation.fulfill()
                }
            }
        )
        
        await fulfillment(of: [expectation], timeout: 30.0)
        XCTAssertFalse(progressValues.isEmpty, "应该有进度回调")
    }
    
    @MainActor
    func testManualSearchWithoutOCR() throws {
        // 创建测试说明书（没有OCR内容）
        let _ = Manual.createManual(
            in: testContext,
            fileName: "iPhone用户手册.pdf",
            fileData: Data(),
            fileType: "pdf"
        )
        
        let _ = Manual.createManual(
            in: testContext,
            fileName: "iPad使用指南.pdf",
            fileData: Data(),
            fileType: "pdf"
        )
        
        try saveTestContext()
        
        // 测试搜索文件名
        let searchResults = Manual.searchManuals(in: testContext, query: "iPhone")
        XCTAssertEqual(searchResults.count, 1, "应该找到一个匹配的说明书")
        XCTAssertEqual(searchResults.first?.manualFileName, "iPhone用户手册.pdf", "应该找到正确的文件")
    }
    
    @MainActor
    func testManualSearchWithOCRContent() throws {
        // 创建测试说明书（有OCR内容）
        let manual = Manual.createManual(
            in: testContext,
            fileName: "product_manual.pdf",
            fileData: Data(),
            fileType: "pdf"
        )
        manual.content = "这是一份产品使用说明书，包含了详细的操作指南和维护信息"
        manual.isOCRProcessed = true
        
        try saveTestContext()
        
        // 测试搜索OCR内容
        let searchResults = Manual.searchManuals(in: testContext, query: "操作指南")
        XCTAssertEqual(searchResults.count, 1, "应该找到一个匹配的说明书")
        
        // 测试预览文本
        let previewText = manual.getPreviewText(for: "操作指南")
        XCTAssertNotNil(previewText, "应该能够获取预览文本")
        XCTAssertTrue(previewText!.contains("操作指南"), "预览文本应该包含搜索关键词")
    }
    
    @MainActor
    func testImagePreprocessor() async {
        let preprocessor = ImagePreprocessor()
        let testImage = createTestPlatformImage()
        
        // 直接在主 actor 上处理图像，避免 Sendable 警告
        let enhancedImage = await preprocessor.enhance(testImage)
        XCTAssertNotNil(enhancedImage, "图像预处理应该返回结果")
    }
    
    @MainActor
    func testTextPostprocessor() {
        let postprocessor = TextPostprocessor()
        
        // 测试文本处理
        let rawText = "这是一个    测试文本  \n\n\n包含多余空格和换行"
        let processedText = postprocessor.enhance(rawText)
        
        XCTAssertFalse(processedText.contains("    "), "应该移除多余空格")
        XCTAssertFalse(processedText.hasPrefix(" "), "应该去除开头空格")
        XCTAssertFalse(processedText.hasSuffix(" "), "应该去除结尾空格")
    }
    
    // MARK: - Helper Methods
    
    // createTestImageData() 方法已由父类 IsolatedServiceTestCase 提供
    
    private func createTestPlatformImage() -> PlatformImage {
        #if os(iOS)
        return UIImage(systemName: "doc.text") ?? UIImage()
        #else
        return NSImage(systemSymbolName: "doc.text", accessibilityDescription: nil) ?? NSImage()
        #endif
    }
}