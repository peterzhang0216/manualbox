//
//  TestDataFactory.swift
//  ManualBox
//
//  Created by AI Assistant on 2025/7/22.
//

import Foundation
import CoreData

// MARK: - 测试数据工厂协议
protocol TestDataFactory {
    func createProduct(name: String, category: Category?) -> Product
    func createCategory(name: String) -> Category
    func createTag(name: String) -> Tag
    func createTestDataSet() -> TestDataSet
    func createRandomProduct() -> Product
    func createProductWithManual() -> Product
    func createProductWithWarranty() -> Product
}

// MARK: - 测试数据集
struct TestDataSet {
    let categories: [Category]
    let tags: [Tag]
    let products: [Product]
    let manuals: [Manual]
    let repairRecords: [RepairRecord]
}

// MARK: - 测试数据工厂实现
class ManualBoxTestDataFactory: TestDataFactory {
    private let context: NSManagedObjectContext
    private let dateFormatter: DateFormatter
    
    init(context: NSManagedObjectContext) {
        self.context = context
        self.dateFormatter = DateFormatter()
        self.dateFormatter.dateFormat = "yyyy-MM-dd"
    }
    
    func createProduct(name: String, category: Category? = nil) -> Product {
        let product = Product(context: context)
        product.id = UUID()
        product.name = name
        product.createdAt = Date()
        product.updatedAt = Date()
        product.category = category
        
        return product
    }
    
    func createCategory(name: String) -> Category {
        let category = Category(context: context)
        category.id = UUID()
        category.name = name
        category.createdAt = Date()
        category.updatedAt = Date()
        
        return category
    }
    
    func createTag(name: String) -> Tag {
        let tag = Tag(context: context)
        tag.id = UUID()
        tag.name = name
        tag.createdAt = Date()
        tag.updatedAt = Date()
        
        return tag
    }
    
    func createTestDataSet() -> TestDataSet {
        // 创建测试分类
        let categories = [
            createCategory(name: "测试电子产品"),
            createCategory(name: "测试家电"),
            createCategory(name: "测试工具"),
            createCategory(name: "测试汽车配件")
        ]
        
        // 创建测试标签
        let tags = [
            createTag(name: "测试重要"),
            createTag(name: "测试保修中"),
            createTag(name: "测试需维修"),
            createTag(name: "测试已过期")
        ]
        
        // 创建测试产品
        var products: [Product] = []
        for (index, category) in categories.enumerated() {
            for i in 1...3 {
                let product = createProduct(name: "测试产品\(index + 1)-\(i)", category: category)
                product.brand = "测试品牌\(index + 1)"
                product.model = "型号\(i)"
                
                // 随机添加标签
                if let randomTag = tags.randomElement() {
                    product.addToTags(randomTag)
                }
                
                products.append(product)
            }
        }
        
        // 创建测试手册
        var manuals: [Manual] = []
        for product in products.prefix(6) {
            let manual = Manual(context: context)
            manual.id = UUID()
            manual.fileName = "\(product.name ?? "")使用手册.pdf"
            manual.fileType = "pdf"
            manual.content = "这是\(product.name ?? "")的测试使用手册内容。"
            manual.product = product
            
            manuals.append(manual)
        }
        
        // 创建测试维修记录
        var repairRecords: [RepairRecord] = []
        for product in products.prefix(4) {
            // 首先为产品创建订单（如果不存在）
            if product.order == nil {
                let order = Order(context: context)
                order.id = UUID()
                order.orderDate = Calendar.current.date(byAdding: .month, value: -Int.random(in: 1...12), to: Date())
                order.orderNumber = "ORD\(Int.random(in: 100000...999999))"
                order.platform = ["官网", "京东", "天猫", "苏宁"].randomElement()
                order.price = NSDecimalNumber(value: Double.random(in: 100...5000))
                order.product = product
            }
            
            let record = RepairRecord(context: context)
            record.id = UUID()
            record.details = "测试故障：\(["屏幕问题", "电池问题", "按键失灵", "系统故障"].randomElement() ?? "未知问题") - 已修复"
            record.cost = NSDecimalNumber(value: Double.random(in: 50...500))
            record.date = Calendar.current.date(byAdding: .day, value: -Int.random(in: 1...90), to: Date())
            record.order = product.order
            
            repairRecords.append(record)
        }
        
        return TestDataSet(
            categories: categories,
            tags: tags,
            products: products,
            manuals: manuals,
            repairRecords: repairRecords
        )
    }
    
    func createRandomProduct() -> Product {
        let names = ["iPhone", "MacBook", "iPad", "Apple Watch", "AirPods", "Samsung Galaxy", "Dell Laptop", "Sony Camera"]
        let brands = ["Apple", "Samsung", "Dell", "Sony", "HP", "Lenovo", "Microsoft", "Google"]
        
        let product = createProduct(name: names.randomElement() ?? "测试产品")
        product.brand = brands.randomElement()
        product.model = "Model-\(Int.random(in: 100...999))"
        
        return product
    }
    
    func createProductWithManual() -> Product {
        let product = createRandomProduct()
        
        let manual = Manual(context: context)
        manual.id = UUID()
        manual.fileName = "\(product.name ?? "")用户手册.pdf"
        manual.fileType = "pdf"
        manual.content = "详细的使用说明和操作指南。"
        manual.product = product
        
        return product
    }
    
    func createProductWithWarranty() -> Product {
        let product = createRandomProduct()
        
        // 创建订单来表示购买信息和保修信息
        let order = Order(context: context)
        order.id = UUID()
        order.orderDate = Calendar.current.date(byAdding: .month, value: -6, to: Date()) // 6个月前购买
        order.orderNumber = "ORD\(Int.random(in: 100000...999999))"
        order.platform = "官网"
        order.price = NSDecimalNumber(value: Double.random(in: 1000...5000))
        order.warrantyEndDate = Calendar.current.date(byAdding: .month, value: 18, to: Date()) // 24个月保修，还剩18个月
        order.product = product
        
        return product
    }
}

// MARK: - 测试断言助手
class TestAssertionHelper {
    static func assertProductValid(_ product: Product, file: StaticString = #file, line: UInt = #line) {
        XCTAssertNotNil(product.id, "产品ID不能为空", file: file, line: line)
        XCTAssertNotNil(product.name, "产品名称不能为空", file: file, line: line)
        XCTAssertNotNil(product.createdAt, "创建时间不能为空", file: file, line: line)
        XCTAssertNotNil(product.updatedAt, "更新时间不能为空", file: file, line: line)
        
        if let name = product.name {
            XCTAssertFalse(name.isEmpty, "产品名称不能为空字符串", file: file, line: line)
        }
    }
    
    static func assertCategoryValid(_ category: Category, file: StaticString = #file, line: UInt = #line) {
        XCTAssertNotNil(category.id, "分类ID不能为空", file: file, line: line)
        XCTAssertNotNil(category.name, "分类名称不能为空", file: file, line: line)
        XCTAssertNotNil(category.createdAt, "创建时间不能为空", file: file, line: line)
        XCTAssertNotNil(category.updatedAt, "更新时间不能为空", file: file, line: line)
        
        if let name = category.name {
            XCTAssertFalse(name.isEmpty, "分类名称不能为空字符串", file: file, line: line)
        }
    }
    
    static func assertTagValid(_ tag: Tag, file: StaticString = #file, line: UInt = #line) {
        XCTAssertNotNil(tag.id, "标签ID不能为空", file: file, line: line)
        XCTAssertNotNil(tag.name, "标签名称不能为空", file: file, line: line)
        XCTAssertNotNil(tag.createdAt, "创建时间不能为空", file: file, line: line)
        XCTAssertNotNil(tag.updatedAt, "更新时间不能为空", file: file, line: line)
        
        if let name = tag.name {
            XCTAssertFalse(name.isEmpty, "标签名称不能为空字符串", file: file, line: line)
        }
    }
}

// MARK: - 测试数据清理器
class TestDataCleaner {
    private let context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    func cleanAllTestData() throws {
        let entityNames = ["Product", "Category", "Tag", "Manual", "RepairRecord", "Order"]
        
        for entityName in entityNames {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            
            try context.execute(deleteRequest)
        }
        
        try context.save()
    }
    
    func cleanTestDataByPrefix(_ prefix: String) throws {
        // 清理以特定前缀开头的测试数据
        let productRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Product")
        productRequest.predicate = NSPredicate(format: "name BEGINSWITH %@", prefix)
        let deleteProductRequest = NSBatchDeleteRequest(fetchRequest: productRequest)
        try context.execute(deleteProductRequest)
        
        let categoryRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Category")
        categoryRequest.predicate = NSPredicate(format: "name BEGINSWITH %@", prefix)
        let deleteCategoryRequest = NSBatchDeleteRequest(fetchRequest: categoryRequest)
        try context.execute(deleteCategoryRequest)
        
        let tagRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Tag")
        tagRequest.predicate = NSPredicate(format: "name BEGINSWITH %@", prefix)
        let deleteTagRequest = NSBatchDeleteRequest(fetchRequest: tagRequest)
        try context.execute(deleteTagRequest)
        
        try context.save()
    }
}