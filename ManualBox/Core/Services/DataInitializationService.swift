//
//  DataInitializationService.swift
//  ManualBox
//
//  Created by Assistant on 2025/6/17.
//

import Foundation
import CoreData

/// 数据初始化服务 - 负责应用的数据初始化逻辑
class DataInitializationService {
    private let context: NSManagedObjectContext
    
    // 初始化标记键
    private static let initializationKey = "ManualBox_HasInitializedDefaultData"
    private static let appVersionKey = "ManualBox_LastInitializedVersion"
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    /// 初始化结果
    struct InitializationResult {
        let categoriesCreated: Int
        let tagsCreated: Int
        let sampleProductsCreated: Int
        let wasFirstLaunch: Bool
        let success: Bool
        let message: String
        
        var summary: String {
            if !success {
                return message
            }
            
            if wasFirstLaunch {
                var details: [String] = []
                if categoriesCreated > 0 {
                    details.append("分类: \(categoriesCreated)")
                }
                if tagsCreated > 0 {
                    details.append("标签: \(tagsCreated)")
                }
                if sampleProductsCreated > 0 {
                    details.append("示例产品: \(sampleProductsCreated)")
                }
                
                if details.isEmpty {
                    return "首次启动，但无需创建数据"
                } else {
                    return "首次启动，已创建: " + details.joined(separator: ", ")
                }
            } else {
                return "非首次启动，跳过初始化"
            }
        }
    }
    
    /// 智能初始化 - 根据应用状态决定是否需要初始化
    func performSmartInitialization(createSampleData: Bool = true) async -> InitializationResult {
        return await withCheckedContinuation { continuation in
            context.perform {
                var categoriesCreated = 0
                var tagsCreated = 0
                var sampleProductsCreated = 0
                var success = true
                var message = ""
                
                do {
                    let isFirstLaunch = self.isFirstLaunch()
                    let needsDataMigration = self.needsDataMigration()
                    
                    print("[DataInit] 首次启动: \(isFirstLaunch), 需要数据迁移: \(needsDataMigration)")
                    
                    if isFirstLaunch || needsDataMigration {
                        // 首次启动或需要数据迁移
                        
                        // 1. 检查并创建默认分类
                        if self.shouldCreateDefaultCategories() {
                            categoriesCreated = self.createDefaultCategories()
                            print("[DataInit] 创建默认分类: \(categoriesCreated) 个")
                        }
                        
                        // 2. 检查并创建默认标签
                        if self.shouldCreateDefaultTags() {
                            tagsCreated = self.createDefaultTags()
                            print("[DataInit] 创建默认标签: \(tagsCreated) 个")
                        }
                        
                        // 3. 创建示例数据（可选）
                        if createSampleData && self.shouldCreateSampleData() {
                            sampleProductsCreated = self.createSampleProducts()
                            print("[DataInit] 创建示例产品: \(sampleProductsCreated) 个")
                        }
                        
                        // 4. 保存更改
                        if self.context.hasChanges {
                            try self.context.save()
                            print("[DataInit] 初始化数据已保存")
                        }
                        
                        // 5. 标记初始化完成
                        self.markInitializationComplete()
                        
                        message = "数据初始化完成"
                    } else {
                        print("[DataInit] 非首次启动，跳过初始化")
                        message = "非首次启动，跳过初始化"
                    }
                    
                } catch {
                    success = false
                    message = "数据初始化过程中出错: \(error.localizedDescription)"
                    print("[DataInit] 错误: \(message)")
                }
                
                let result = InitializationResult(
                    categoriesCreated: categoriesCreated,
                    tagsCreated: tagsCreated,
                    sampleProductsCreated: sampleProductsCreated,
                    wasFirstLaunch: self.isFirstLaunch(),
                    success: success,
                    message: message
                )
                
                continuation.resume(returning: result)
            }
        }
    }
    
    /// 强制重新初始化（用于重置应用）
    func forceReinitialize(includeSampleData: Bool = false) async -> InitializationResult {
        return await withCheckedContinuation { continuation in
            context.perform {
                var categoriesCreated = 0
                var tagsCreated = 0
                var sampleProductsCreated = 0
                var success = true
                var message = ""
                
                do {
                    print("[DataInit] 开始强制重新初始化...")
                    
                    // 1. 重置初始化标记
                    self.resetInitializationFlag()
                    
                    // 2. 创建默认分类
                    categoriesCreated = self.createDefaultCategories()
                    print("[DataInit] 强制创建默认分类: \(categoriesCreated) 个")
                    
                    // 3. 创建默认标签
                    tagsCreated = self.createDefaultTags()
                    print("[DataInit] 强制创建默认标签: \(tagsCreated) 个")
                    
                    // 4. 创建示例数据（可选）
                    if includeSampleData {
                        sampleProductsCreated = self.createSampleProducts()
                        print("[DataInit] 强制创建示例产品: \(sampleProductsCreated) 个")
                    }
                    
                    // 5. 保存更改
                    if self.context.hasChanges {
                        try self.context.save()
                        print("[DataInit] 强制初始化数据已保存")
                    }
                    
                    // 6. 标记初始化完成
                    self.markInitializationComplete()
                    
                    message = "强制重新初始化完成"
                    
                } catch {
                    success = false
                    message = "强制重新初始化过程中出错: \(error.localizedDescription)"
                    print("[DataInit] 错误: \(message)")
                }
                
                let result = InitializationResult(
                    categoriesCreated: categoriesCreated,
                    tagsCreated: tagsCreated,
                    sampleProductsCreated: sampleProductsCreated,
                    wasFirstLaunch: true, // 强制初始化视为首次启动
                    success: success,
                    message: message
                )
                
                continuation.resume(returning: result)
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func isFirstLaunch() -> Bool {
        return !UserDefaults.standard.bool(forKey: Self.initializationKey)
    }
    
    private func needsDataMigration() -> Bool {
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let lastInitializedVersion = UserDefaults.standard.string(forKey: Self.appVersionKey)
        
        // 如果版本不同，可能需要数据迁移
        return lastInitializedVersion != currentVersion
    }
    
    private func shouldCreateDefaultCategories() -> Bool {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "Category")
        let count = (try? context.count(for: request)) ?? 0
        return count == 0
    }
    
    private func shouldCreateDefaultTags() -> Bool {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "Tag")
        let count = (try? context.count(for: request)) ?? 0
        return count == 0
    }
    
    private func shouldCreateSampleData() -> Bool {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "Product")
        let count = (try? context.count(for: request)) ?? 0
        return count == 0
    }
    
    private func createDefaultCategories() -> Int {
        Category.createDefaultCategories(in: context)
        
        // 计算创建的分类数量
        let request: NSFetchRequest<Category> = Category.fetchRequest()
        let categories = (try? context.fetch(request)) ?? []
        return categories.count
    }
    
    private func createDefaultTags() -> Int {
        Tag.createDefaultTags(in: context)
        
        // 计算创建的标签数量
        let request: NSFetchRequest<Tag> = Tag.fetchRequest()
        let tags = (try? context.fetch(request)) ?? []
        return tags.count
    }
    
    private func createSampleProducts() -> Int {
        // 获取所有分类和标签
        let categoriesRequest: NSFetchRequest<Category> = Category.fetchRequest()
        let categories = (try? context.fetch(categoriesRequest)) ?? []
        
        let tagsRequest: NSFetchRequest<Tag> = Tag.fetchRequest()
        let tags = (try? context.fetch(tagsRequest)) ?? []
        
        if categories.isEmpty {
            print("[DataInit] 无分类可用，跳过示例产品创建")
            return 0
        }
        
        // 创建示例产品
        var createdCount = 0
        
        // 为每个分类创建2-4个示例产品
        for category in categories {
            let productCount = Int.random(in: 2...4)
            
            for i in 1...productCount {
                let product = Product(context: context)
                product.id = UUID()
                product.name = "\(category.name ?? "产品") \(i)"
                product.brand = "示例品牌"
                product.model = "Model-\(i)"
                product.category = category
                product.notes = "这是一个示例产品"
                
                // 随机添加标签
                if !tags.isEmpty {
                    let randomTag = tags.randomElement()
                    product.addToTags(randomTag!)
                }
                
                createdCount += 1
            }
        }
        
        return createdCount
    }
    
    private func markInitializationComplete() {
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        
        UserDefaults.standard.set(true, forKey: Self.initializationKey)
        UserDefaults.standard.set(currentVersion, forKey: Self.appVersionKey)
        
        print("[DataInit] 已标记初始化完成，版本: \(currentVersion)")
    }
    
    private func resetInitializationFlag() {
        UserDefaults.standard.removeObject(forKey: Self.initializationKey)
        UserDefaults.standard.removeObject(forKey: Self.appVersionKey)
        print("[DataInit] 已重置初始化标记")
    }
}

// MARK: - PersistenceController Extension
extension PersistenceController {
    /// 获取数据初始化服务
    var initializationService: DataInitializationService {
        DataInitializationService(context: container.viewContext)
    }
    
    /// 执行智能初始化
    func performSmartInitialization(createSampleData: Bool = true) async -> DataInitializationService.InitializationResult {
        return await initializationService.performSmartInitialization(createSampleData: createSampleData)
    }
    
    /// 强制重新初始化
    func forceReinitialize(includeSampleData: Bool = false) async -> DataInitializationService.InitializationResult {
        return await initializationService.forceReinitialize(includeSampleData: includeSampleData)
    }
}
