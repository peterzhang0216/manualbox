//
//  PersistenceInitializationTests.swift
//  ManualBoxTests
//
//  Created by AI Assistant on 2025/6/17.
//

import XCTest
import CoreData
@testable import ManualBox

class PersistenceInitializationTests: XCTestCase {

    var persistenceController: PersistenceController!
    var context: NSManagedObjectContext!

    override func setUp() {
        super.setUp()

        // 清除初始化标记
        UserDefaults.standard.removeObject(forKey: "ManualBox_HasInitializedDefaultData")

        // 创建内存中的持久化控制器用于测试
        persistenceController = PersistenceController(inMemory: true)
        context = persistenceController.container.viewContext
    }

    override func tearDown() {
        // 清理
        UserDefaults.standard.removeObject(forKey: "ManualBox_HasInitializedDefaultData")
        persistenceController = nil
        context = nil
        super.tearDown()
    }
    
    // MARK: - 测试初始化标记功能

    func testInitializationFlag() {
        // 初始状态应该是未初始化
        XCTAssertFalse(persistenceController.hasCompletedInitialSetup())

        // 执行初始化
        persistenceController.initializeDefaultDataIfNeeded()

        // 现在应该已初始化
        XCTAssertTrue(persistenceController.hasCompletedInitialSetup())

        // 重置标记
        persistenceController.resetInitializationFlag()

        // 应该回到未初始化状态
        XCTAssertFalse(persistenceController.hasCompletedInitialSetup())
    }

    // MARK: - 测试首次初始化

    func testFirstTimeInitialization() {
        // 确保初始状态
        XCTAssertFalse(persistenceController.hasCompletedInitialSetup())

        // 执行初始化
        persistenceController.initializeDefaultDataIfNeeded()

        // 验证初始化标记已设置
        XCTAssertTrue(persistenceController.hasCompletedInitialSetup())

        // 验证默认分类已创建
        let categoryRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Category")
        let categoryCount = try! context.count(for: categoryRequest)
        XCTAssertGreaterThan(categoryCount, 0)

        // 验证默认标签已创建
        let tagRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Tag")
        let tagCount = try! context.count(for: tagRequest)
        XCTAssertGreaterThan(tagCount, 0)
    }

    // MARK: - 测试重复初始化

    func testSubsequentInitializationSkipped() {
        // 首次初始化
        persistenceController.initializeDefaultDataIfNeeded()

        let categoryRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Category")
        let initialCategoryCount = try! context.count(for: categoryRequest)

        let tagRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Tag")
        let initialTagCount = try! context.count(for: tagRequest)

        // 再次调用初始化
        persistenceController.initializeDefaultDataIfNeeded()

        // 验证数量没有增加（没有重复创建）
        let finalCategoryCount = try! context.count(for: categoryRequest)
        let finalTagCount = try! context.count(for: tagRequest)

        XCTAssertEqual(initialCategoryCount, finalCategoryCount)
        XCTAssertEqual(initialTagCount, finalTagCount)
    }

    // MARK: - 测试示例数据创建

    func testSampleDataCreation() {
        // 首先初始化默认分类和标签
        persistenceController.initializeDefaultDataIfNeeded()

        // 验证没有产品数据
        let productRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Product")
        let initialProductCount = try! context.count(for: productRequest)
        XCTAssertEqual(initialProductCount, 0)

        // 创建示例数据
        persistenceController.createSampleData()

        // 验证产品数据已创建
        let finalProductCount = try! context.count(for: productRequest)
        XCTAssertGreaterThan(finalProductCount, 0)

        // 验证每个分类都有产品
        let categoryRequest: NSFetchRequest<ManualBox.Category> = ManualBox.Category.fetchRequest()
        let categories = try! context.fetch(categoryRequest)

        for category in categories {
            let categoryProducts = category.products as? Set<Product> ?? []
            XCTAssertGreaterThan(categoryProducts.count, 0, "分类 \(category.name ?? "") 应该有产品")
        }

        print("[Test] 创建了 \(finalProductCount) 个示例产品")
    }

    func testSampleDataNotDuplicated() {
        // 首先初始化默认分类和标签
        persistenceController.initializeDefaultDataIfNeeded()

        // 创建示例数据
        persistenceController.createSampleData()

        let productRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Product")
        let firstCount = try! context.count(for: productRequest)

        // 再次调用创建示例数据
        persistenceController.createSampleData()

        // 验证产品数量没有增加（没有重复创建）
        let secondCount = try! context.count(for: productRequest)
        XCTAssertEqual(firstCount, secondCount, "示例数据不应该重复创建")
    }
}
