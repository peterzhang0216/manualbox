//
//  MockServices.swift
//  ManualBox
//
//  Created by AI Assistant on 2025/7/22.
//

import Foundation
import CoreData
import Combine

// MARK: - 模拟产品服务
class MockProductService: ProductServiceProtocol {
    typealias Entity = Product
    typealias CreateRequest = ProductCreateRequest
    typealias UpdateRequest = ProductUpdateRequest
    
    private var products: [Product] = []
    private let context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)) {
        self.context = context
    }
    
    func initialize() async throws {
        // 模拟初始化
    }
    
    func cleanup() {
        products.removeAll()
    }
    
    func fetch() async throws -> [Product] {
        return products
    }
    
    func fetchBy(id: UUID) async throws -> Product? {
        return products.first { $0.id == id }
    }
    
    func create(_ request: CreateRequest) async throws -> Product {
        let product = Product(context: context)
        product.id = UUID()
        product.name = request.name
        product.brand = request.brand
        product.model = request.model
        product.createdAt = Date()
        product.updatedAt = Date()
        
        products.append(product)
        return product
    }
    
    func update(_ entity: Product, with request: UpdateRequest) async throws -> Product {
        entity.name = request.name ?? entity.name
        entity.brand = request.brand ?? entity.brand
        entity.model = request.model ?? entity.model
        entity.updatedAt = Date()
        
        return entity
    }
    
    func delete(_ entity: Product) async throws {
        products.removeAll { $0.id == entity.id }
    }
    
    func search(_ query: String) async throws -> [Product] {
        return products.filter { product in
            product.name?.localizedCaseInsensitiveContains(query) == true ||
            product.brand?.localizedCaseInsensitiveContains(query) == true ||
            product.model?.localizedCaseInsensitiveContains(query) == true
        }
    }
    
    func fetchByCategory(_ category: Category) async throws -> [Product] {
        return products.filter { $0.category == category }
    }
    
    func fetchByTag(_ tag: Tag) async throws -> [Product] {
        return products.filter { product in
            (product.tags as? Set<Tag>)?.contains(tag) == true
        }
    }
    
    func fetchExpiringSoon(within days: Int) async throws -> [Product] {
        let targetDate = Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date()
        
        return products.filter { product in
            guard let purchaseDate = product.purchaseDate else { return false }
            let warrantyEndDate = Calendar.current.date(byAdding: .month, value: Int(product.warrantyPeriod), to: purchaseDate)
            return warrantyEndDate ?? Date() <= targetDate
        }
    }
    
    func performOCR(for product: Product) async throws -> Bool {
        // 模拟OCR处理
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1秒延迟
        return true
    }
}

// MARK: - 模拟分类服务
class MockCategoryService: CategoryServiceProtocol {
    typealias Entity = Category
    typealias CreateRequest = CategoryCreateRequest
    typealias UpdateRequest = CategoryUpdateRequest
    
    private var categories: [Category] = []
    private let context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)) {
        self.context = context
    }
    
    func initialize() async throws {
        // 模拟初始化
    }
    
    func cleanup() {
        categories.removeAll()
    }
    
    func fetch() async throws -> [Category] {
        return categories
    }
    
    func fetchBy(id: UUID) async throws -> Category? {
        return categories.first { $0.id == id }
    }
    
    func create(_ request: CreateRequest) async throws -> Category {
        let category = Category(context: context)
        category.id = UUID()
        category.name = request.name
        category.createdAt = Date()
        category.updatedAt = Date()
        
        categories.append(category)
        return category
    }
    
    func update(_ entity: Category, with request: UpdateRequest) async throws -> Category {
        entity.name = request.name ?? entity.name
        entity.updatedAt = Date()
        
        return entity
    }
    
    func delete(_ entity: Category) async throws {
        categories.removeAll { $0.id == entity.id }
    }
    
    func search(_ query: String) async throws -> [Category] {
        return categories.filter { category in
            category.name?.localizedCaseInsensitiveContains(query) == true
        }
    }
    
    func createDefaultCategories() async throws {
        let defaultNames = ["电子产品", "家电", "工具", "汽车配件", "其他"]
        
        for name in defaultNames {
            let request = CategoryCreateRequest(name: name)
            _ = try await create(request)
        }
    }
    
    func fetchWithProductCounts() async throws -> [Category] {
        // 模拟返回带产品数量的分类
        return categories
    }
}

// MARK: - 模拟文件服务
class MockFileService: FileServiceProtocol {
    private var mockFiles: [String: Data] = [:]
    
    func initialize() async throws {
        // 模拟初始化
    }
    
    func cleanup() {
        mockFiles.removeAll()
    }
    
    func selectFiles(allowedTypes: [String]) async throws -> [URL] {
        // 模拟文件选择
        return [URL(fileURLWithPath: "/mock/file1.pdf"), URL(fileURLWithPath: "/mock/file2.jpg")]
    }
    
    func importFile(from url: URL) async throws -> Data {
        if let data = mockFiles[url.path] {
            return data
        }
        
        // 模拟文件数据
        let mockData = "Mock file content".data(using: .utf8) ?? Data()
        mockFiles[url.path] = mockData
        return mockData
    }
    
    func exportData(_ data: Data, to url: URL) async throws {
        mockFiles[url.path] = data
    }
    
    func saveImage(_ image: PlatformImage, to directory: URL) async throws -> URL {
        let fileName = UUID().uuidString + ".jpg"
        let fileURL = directory.appendingPathComponent(fileName)
        
        // 模拟图片数据
        let mockImageData = Data([0xFF, 0xD8, 0xFF, 0xE0]) // JPEG header
        mockFiles[fileURL.path] = mockImageData
        
        return fileURL
    }
}

// MARK: - 模拟通知服务
class MockNotificationService: NotificationServiceProtocol {
    private var scheduledNotifications: [UUID: Date] = [:]
    private var hasPermission = false
    
    func initialize() async throws {
        // 模拟初始化
    }
    
    func cleanup() {
        scheduledNotifications.removeAll()
    }
    
    func scheduleWarrantyReminder(for product: Product) async throws {
        guard let productId = product.id else { return }
        
        // 模拟计算提醒时间
        let reminderDate = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        scheduledNotifications[productId] = reminderDate
    }
    
    func cancelWarrantyReminder(for product: Product) async throws {
        guard let productId = product.id else { return }
        scheduledNotifications.removeValue(forKey: productId)
    }
    
    func updateAllWarrantyReminders() async throws {
        // 模拟更新所有提醒
    }
    
    func requestPermission() async throws -> Bool {
        // 模拟权限请求
        hasPermission = true
        return hasPermission
    }
}

// MARK: - 模拟同步服务
@MainActor
class MockSyncService: SyncServiceProtocol {
    private(set) var syncStatus: CloudKitSyncStatus = .idle
    private var syncProgress: Double = 0.0
    
    func initialize() async throws {
        // 模拟初始化
    }
    
    func cleanup() {
        syncStatus = .idle
        syncProgress = 0.0
    }
    
    func syncToCloud() async throws {
        syncStatus = .syncing
        
        // 模拟同步进度
        for i in 1...10 {
            syncProgress = Double(i) / 10.0
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
        
        syncStatus = .completed
    }
    
    func syncFromCloud() async throws {
        syncStatus = .syncing
        
        // 模拟从云端同步
        for i in 1...10 {
            syncProgress = Double(i) / 10.0
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
        
        syncStatus = .completed
    }
    
    func resolveConflicts() async throws {
        // 模拟冲突解决
        try await Task.sleep(nanoseconds: 500_000_000) // 500ms
    }
}

// MARK: - 请求数据模型
struct ProductCreateRequest {
    let name: String
    let brand: String?
    let model: String?
    let serialNumber: String?
    let purchaseDate: Date?
    let purchasePrice: Double?
    let warrantyPeriod: Int16
}

struct ProductUpdateRequest {
    let name: String?
    let brand: String?
    let model: String?
    let serialNumber: String?
    let purchaseDate: Date?
    let purchasePrice: Double?
    let warrantyPeriod: Int16?
}

struct CategoryCreateRequest {
    let name: String
}

struct CategoryUpdateRequest {
    let name: String?
}