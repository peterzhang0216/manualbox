import XCTest
import SwiftUI
import CoreData
import PhotosUI
@testable import ManualBox

final class InteractionTests: XCTestCase {
    var container: NSPersistentContainer!
    var context: NSManagedObjectContext!
    
    override func setUpWithError() throws {
        // 创建内存中的CoreData容器用于测试
        container = NSPersistentContainer(name: "ManualBox")
        container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        container.loadPersistentStores { (_, error) in
            if let error = error {
                fatalError("加载Core Data失败: \(error)")
            }
        }
        context = container.viewContext
        
        // 创建基本测试数据
        Category.createDefaultCategories(in: context)
        Tag.createDefaultTags(in: context)
    }

    override func tearDownWithError() throws {
        // 清理测试数据
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "Product")
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        try container.persistentStoreCoordinator.execute(deleteRequest, with: context)
        
        context = nil
        container = nil
    }

    // 测试1: 验证AddProductViewModel中的异步保存逻辑
    @MainActor
    func testProductSaveAsync() async throws {
        let viewModel = AddProductViewModel()
        
        // 设置产品基本信息
        viewModel.send(AddProductAction.updateName("测试产品"))
        viewModel.send(AddProductAction.updateBrand("测试品牌"))
        viewModel.send(AddProductAction.updateModel("TS-100"))
        
        // 模拟发票图片数据 - 直接设置状态而不是通过action
        // 因为invoiceImageData是通过loadInvoiceImage方法异步设置的
        
        // 调用保存方法
        let success = await viewModel.saveProduct(in: context)
        XCTAssertTrue(success, "产品保存应该成功")
        
        // 验证产品已被保存到数据库
        let fetchRequest: NSFetchRequest<Product> = Product.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "name == %@", "测试产品")
        
        let results = try context.fetch(fetchRequest)
        XCTAssertEqual(results.count, 1, "应该找到一个产品")
        XCTAssertEqual(results.first?.name, "测试产品", "产品名称应该匹配")
        XCTAssertEqual(results.first?.brand, "测试品牌", "品牌应该匹配")
    }
    
    // 测试2: 验证通知机制是否正确触发UI更新
    func testNotificationHandling() throws {
        // 创建一个模拟的StateObject来监听通知
        class NotificationTester: ObservableObject {
            @Published var notificationReceived = false
            var cancellable: NSObjectProtocol?
            
            func startListening() {
                cancellable = NotificationCenter.default.addObserver(
                    forName: Notification.Name("CreateNewProduct"),
                    object: nil,
                    queue: .main
                ) { [weak self] _ in
                    self?.notificationReceived = true
                }
            }
            
            func stopListening() {
                if let cancellable = cancellable {
                    NotificationCenter.default.removeObserver(cancellable)
                }
            }
        }
        
        let tester = NotificationTester()
        tester.startListening()
        
        // 发送通知
        NotificationCenter.default.post(name: Notification.Name("CreateNewProduct"), object: nil)
        
        // 验证通知是否被正确接收
        XCTAssertTrue(tester.notificationReceived, "通知应该被接收")
        
        // 清理
        tester.stopListening()
    }
    
    // 测试3: 验证选择状态更新
    func testSelectionStateUpdates() throws {
        // 模拟一个小型测试环境来测试选择状态变更
        let category = Category(context: context)
        category.id = UUID()
        category.name = "测试分类"
        category.icon = "folder"
        
        let tag = Tag(context: context)
        tag.id = UUID()
        tag.name = "测试标签"
        tag.color = TagColor.blue.rawValue
        
        try context.save()
        
        // 创建选择状态
        var selection: SelectionValue? = .main(0)
        
        // 测试切换到分类
        if let categoryId = category.id {
            selection = .category(categoryId)
            // 验证选择正确更新
            if case let .category(id) = selection {
                XCTAssertEqual(id, categoryId, "分类ID应该匹配")
            } else {
                XCTFail("选择应该更新为分类类型")
            }
        }
        
        // 测试切换到标签
        if let tagId = tag.id {
            selection = .tag(tagId)
            // 验证选择正确更新
            if case let .tag(id) = selection {
                XCTAssertEqual(id, tagId, "标签ID应该匹配")
            } else {
                XCTFail("选择应该更新为标签类型")
            }
        }
    }
    
    // 测试4: 测试并发操作对CoreData的影响
    func testConcurrentDataAccess() throws {
        let concurrentExpectation = expectation(description: "并发操作完成")
        
        // 创建多个并发任务来修改数据
        let taskGroup = DispatchGroup()
        
        for i in 1...5 {
            taskGroup.enter()
            
            DispatchQueue.global(qos: .userInitiated).async {
                // 在后台上下文中执行操作
                let bgContext = self.container.newBackgroundContext()
                
                bgContext.perform {
                    let product = Product(context: bgContext)
                    product.id = UUID()
                    product.name = "并发产品\(i)"
                    product.brand = "测试品牌"
                    
                    try? bgContext.save()
                    taskGroup.leave()
                }
            }
        }
        
        // 等待所有任务完成
        taskGroup.notify(queue: .main) {
            // 验证并发操作的结果
            let fetchRequest: NSFetchRequest<Product> = Product.fetchRequest()
            
            do {
                let products = try self.context.fetch(fetchRequest)
                XCTAssertEqual(products.count, 5, "应该创建了5个产品")
            } catch {
                XCTFail("获取产品失败: \(error)")
            }
            
            concurrentExpectation.fulfill()
        }
        
        wait(for: [concurrentExpectation], timeout: 10.0)
    }
}