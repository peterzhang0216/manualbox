import XCTest
import CoreData
@testable import ManualBox

/// 基础测试类，提供完全隔离的数据环境
/// 所有需要 Core Data 的测试都应该继承此类
class IsolatedDataTestCase: XCTestCase {
    
    // MARK: - 测试基础设施
    
    /// 测试专用的持久化控制器
    /// 每个测试方法都会获得一个全新的实例
    private(set) var testPersistenceController: PersistenceController!
    
    /// 测试专用的 Core Data 上下文
    private(set) var testContext: NSManagedObjectContext!
    
    /// 测试开始时间，用于性能监控
    private var testStartTime: Date!
    
    // MARK: - 生命周期管理
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        testStartTime = Date()
        
        // 创建完全隔离的测试数据环境
        setupIsolatedDataEnvironment()
        
        print("🧪 [\(String(describing: type(of: self)))] 测试环境初始化完成")
    }
    
    override func tearDownWithError() throws {
        // 验证数据隔离
        verifyDataIsolation()
        
        // 清理测试环境
        cleanupTestEnvironment()
        
        // 性能监控
        let duration = Date().timeIntervalSince(testStartTime)
        if duration > 1.0 {
            print("⚠️ [\(String(describing: type(of: self)))] 测试执行时间较长: \(String(format: "%.2f", duration))s")
        }
        
        try super.tearDownWithError()
        
        print("✅ [\(String(describing: type(of: self)))] 测试环境清理完成")
    }
    
    // MARK: - 私有方法
    
    /// 设置隔离的数据环境
    private func setupIsolatedDataEnvironment() {
        // 创建独立的测试数据栈
        testPersistenceController = PersistenceController.createTestInstance()
        testContext = testPersistenceController.container.viewContext
        
        // 配置测试上下文
        testContext.automaticallyMergesChangesFromParent = false
        testContext.mergePolicy = NSErrorMergePolicy
        
        // 验证环境是干净的
        assert(testPersistenceController.isDatabaseEmpty(), 
               "测试环境初始化失败：数据库不为空")
    }
    
    /// 验证数据隔离
    private func verifyDataIsolation() {
        // 检查是否有意外的数据泄露
        if !testPersistenceController.isDatabaseEmpty() {
            print("⚠️ 警告：测试结束后数据库不为空，可能存在数据泄露")
        }
    }
    
    /// 清理测试环境
    @MainActor
    private func cleanupTestEnvironment() {
        // 清理测试数据
        testPersistenceController.cleanupTestData()
        
        // 释放资源
        testContext = nil
        testPersistenceController = nil
    }
    
    // MARK: - 辅助方法
    
    /// 保存测试上下文
    /// 提供错误处理和断言
    func saveTestContext() throws {
        guard testContext.hasChanges else { return }
        
        do {
            try testContext.save()
        } catch {
            XCTFail("保存测试上下文失败: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// 创建测试用的产品
    @discardableResult
    func createTestProduct(name: String = "测试产品", 
                          brand: String = "测试品牌",
                          model: String = "测试型号") -> Product {
        let product = Product.createProduct(
            in: testContext,
            name: name,
            brand: brand,
            model: model
        )
        
        return product
    }
    
    /// 创建测试用的分类
    @discardableResult
    func createTestCategory(name: String = "测试分类") -> ManualBox.Category {
        let category = ManualBox.Category(context: testContext)
        category.id = UUID()
        category.name = name
        category.icon = "folder"
        category.createdAt = Date()
        category.updatedAt = Date()
        
        return category
    }
    
    /// 创建测试用的说明书
    @discardableResult
    func createTestManual(fileName: String = "测试说明书.pdf",
                         fileType: String = "pdf") -> Manual {
        let testData = Data("测试内容".utf8)
        
        let manual = Manual.createManual(
            in: testContext,
            fileName: fileName,
            fileData: testData,
            fileType: fileType
        )
        
        return manual
    }
    
    /// 验证实体数量
    func assertEntityCount<T: NSManagedObject>(_ entityType: T.Type, 
                                              equals expectedCount: Int,
                                              file: StaticString = #file,
                                              line: UInt = #line) {
        let request = NSFetchRequest<T>(entityName: String(describing: entityType))
        
        do {
            let count = try testContext.count(for: request)
            XCTAssertEqual(count, expectedCount, 
                         "实体 \(entityType) 的数量不匹配", 
                         file: file, line: line)
        } catch {
            XCTFail("获取实体 \(entityType) 数量失败: \(error)", 
                   file: file, line: line)
        }
    }
    
    /// 等待异步操作完成
    func waitForAsyncOperation(timeout: TimeInterval = 5.0,
                              description: String = "异步操作") {
        let expectation = self.expectation(description: description)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: timeout)
    }
}

// MARK: - Core Data 测试扩展

extension IsolatedDataTestCase {
    
    /// 执行并验证 Core Data 操作
    func performAndWait<T>(_ operation: @escaping () throws -> T) rethrows -> T {
        var result: Result<T, Error>!
        
        testContext.performAndWait {
            do {
                let value = try operation()
                result = .success(value)
            } catch {
                result = .failure(error)
            }
        }
        
        switch result {
        case .success(let value):
            return value
        case .failure(let error):
            throw error
        }
    }
    
    /// 异步执行 Core Data 操作
    func performAsync<T>(_ operation: @escaping () throws -> T) async throws -> T {
        return try await withCheckedThrowingContinuation { continuation in
            testContext.perform {
                do {
                    let value = try operation()
                    continuation.resume(returning: value)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
