//
//  DataCleanupService.swift
//  ManualBox
//
//  Created by Assistant on 2025/6/17.
//

import Foundation
import CoreData

/// 数据清理服务 - 提供全面的数据清理和修复功能
class DataCleanupService {
    private let context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    /// 清理结果
    struct CleanupResult {
        let duplicateCategoriesRemoved: Int
        let duplicateTagsRemoved: Int
        let orphanedOrdersRemoved: Int
        let orphanedManualsRemoved: Int
        let emptyEntitiesRemoved: Int
        let success: Bool
        let message: String
        
        var totalItemsRemoved: Int {
            duplicateCategoriesRemoved + duplicateTagsRemoved + orphanedOrdersRemoved + orphanedManualsRemoved + emptyEntitiesRemoved
        }
        
        var summary: String {
            if totalItemsRemoved == 0 {
                return "数据状态良好，无需清理"
            }
            
            var details: [String] = []
            if duplicateCategoriesRemoved > 0 {
                details.append("重复分类: \(duplicateCategoriesRemoved)")
            }
            if duplicateTagsRemoved > 0 {
                details.append("重复标签: \(duplicateTagsRemoved)")
            }
            if orphanedOrdersRemoved > 0 {
                details.append("孤立订单: \(orphanedOrdersRemoved)")
            }
            if orphanedManualsRemoved > 0 {
                details.append("孤立说明书: \(orphanedManualsRemoved)")
            }
            if emptyEntitiesRemoved > 0 {
                details.append("空实体: \(emptyEntitiesRemoved)")
            }
            
            return "已清理: " + details.joined(separator: ", ")
        }
    }
    
    /// 执行完整的数据清理
    func performCompleteCleanup() async -> CleanupResult {
        return await withCheckedContinuation { continuation in
            context.perform {
                var duplicateCategoriesRemoved = 0
                var duplicateTagsRemoved = 0
                var orphanedOrdersRemoved = 0
                var orphanedManualsRemoved = 0
                var emptyEntitiesRemoved = 0
                var success = true
                var message = ""
                
                do {
                    print("[DataCleanup] 开始完整数据清理...")
                    
                    // 1. 清理重复分类
                    duplicateCategoriesRemoved = self.removeDuplicateCategories()
                    print("[DataCleanup] 清理重复分类: \(duplicateCategoriesRemoved) 个")
                    
                    // 2. 清理重复标签
                    duplicateTagsRemoved = self.removeDuplicateTags()
                    print("[DataCleanup] 清理重复标签: \(duplicateTagsRemoved) 个")
                    
                    // 3. 清理孤立订单
                    orphanedOrdersRemoved = self.removeOrphanedOrders()
                    print("[DataCleanup] 清理孤立订单: \(orphanedOrdersRemoved) 个")
                    
                    // 4. 清理孤立说明书
                    orphanedManualsRemoved = self.removeOrphanedManuals()
                    print("[DataCleanup] 清理孤立说明书: \(orphanedManualsRemoved) 个")
                    
                    // 5. 清理空实体（可选，保留默认分类和标签）
                    emptyEntitiesRemoved = self.removeEmptyNonDefaultEntities()
                    print("[DataCleanup] 清理空实体: \(emptyEntitiesRemoved) 个")
                    
                    // 6. 保存更改
                    if self.context.hasChanges {
                        try self.context.save()
                        print("[DataCleanup] 数据清理完成，已保存更改")
                    }
                    
                    message = "数据清理成功完成"
                    
                } catch {
                    success = false
                    message = "数据清理过程中出错: \(error.localizedDescription)"
                    print("[DataCleanup] 错误: \(message)")
                }
                
                let result = CleanupResult(
                    duplicateCategoriesRemoved: duplicateCategoriesRemoved,
                    duplicateTagsRemoved: duplicateTagsRemoved,
                    orphanedOrdersRemoved: orphanedOrdersRemoved,
                    orphanedManualsRemoved: orphanedManualsRemoved,
                    emptyEntitiesRemoved: emptyEntitiesRemoved,
                    success: success,
                    message: message
                )
                
                continuation.resume(returning: result)
            }
        }
    }
    
    /// 清理所有数据（危险操作，仅用于重置）
    func clearAllData() async -> (success: Bool, message: String) {
        return await withCheckedContinuation { continuation in
            context.perform {
                do {
                    print("[DataCleanup] 开始清理所有数据...")
                    
                    // 删除所有实体的数据
                    let entityNames = ["Product", "Category", "Tag", "Order", "Manual", "RepairRecord"]
                    var totalDeleted = 0
                    
                    for entityName in entityNames {
                        let request = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
                        let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
                        let result = try self.context.execute(deleteRequest) as? NSBatchDeleteResult
                        let deletedCount = result?.result as? Int ?? 0
                        totalDeleted += deletedCount
                        print("[DataCleanup] 删除 \(entityName): \(deletedCount) 个")
                    }
                    
                    // 重置初始化标记
                    UserDefaults.standard.removeObject(forKey: "ManualBox_HasInitializedDefaultData")
                    
                    // 保存更改
                    try self.context.save()
                    
                    let message = "成功清理所有数据，共删除 \(totalDeleted) 个项目"
                    print("[DataCleanup] \(message)")
                    continuation.resume(returning: (true, message))
                    
                } catch {
                    let message = "清理所有数据时出错: \(error.localizedDescription)"
                    print("[DataCleanup] 错误: \(message)")
                    continuation.resume(returning: (false, message))
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func removeDuplicateCategories() -> Int {
        let request: NSFetchRequest<Category> = Category.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Category.name, ascending: true)]
        
        do {
            let categories = try context.fetch(request)
            var nameToCategory: [String: Category] = [:]
            var duplicatesToDelete: [Category] = []
            
            for category in categories {
                let name = (category.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                
                if name.isEmpty {
                    duplicatesToDelete.append(category)
                    continue
                }
                
                if let existingCategory = nameToCategory[name] {
                    // 保留较早创建的分类，删除重复的
                    let categoryToDelete = category
                    
                    // 转移产品到保留的分类
                    if let products = categoryToDelete.products as? Set<Product> {
                        for product in products {
                            product.category = existingCategory
                        }
                    }
                    
                    duplicatesToDelete.append(categoryToDelete)
                } else {
                    nameToCategory[name] = category
                }
            }
            
            // 删除重复项
            for duplicate in duplicatesToDelete {
                context.delete(duplicate)
            }
            
            return duplicatesToDelete.count
            
        } catch {
            print("[DataCleanup] 清理重复分类时出错: \(error.localizedDescription)")
            return 0
        }
    }
    
    private func removeDuplicateTags() -> Int {
        let request: NSFetchRequest<Tag> = Tag.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Tag.name, ascending: true)]
        
        do {
            let tags = try context.fetch(request)
            var nameToTag: [String: Tag] = [:]
            var duplicatesToDelete: [Tag] = []
            
            for tag in tags {
                let name = (tag.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                
                if name.isEmpty {
                    duplicatesToDelete.append(tag)
                    continue
                }
                
                if let existingTag = nameToTag[name] {
                    // 保留较早创建的标签，删除重复的
                    let tagToDelete = tag
                    
                    // 转移产品到保留的标签
                    if let products = tagToDelete.products as? Set<Product> {
                        for product in products {
                            product.removeFromTags(tagToDelete)
                            product.addToTags(existingTag)
                        }
                    }
                    
                    duplicatesToDelete.append(tagToDelete)
                } else {
                    nameToTag[name] = tag
                }
            }
            
            // 删除重复项
            for duplicate in duplicatesToDelete {
                context.delete(duplicate)
            }
            
            return duplicatesToDelete.count
            
        } catch {
            print("[DataCleanup] 清理重复标签时出错: \(error.localizedDescription)")
            return 0
        }
    }
    
    private func removeOrphanedOrders() -> Int {
        let request: NSFetchRequest<Order> = Order.fetchRequest()
        request.predicate = NSPredicate(format: "product == nil")
        
        do {
            let orphanedOrders = try context.fetch(request)
            
            for order in orphanedOrders {
                context.delete(order)
            }
            
            return orphanedOrders.count
            
        } catch {
            print("[DataCleanup] 清理孤立订单时出错: \(error.localizedDescription)")
            return 0
        }
    }
    
    private func removeOrphanedManuals() -> Int {
        let request: NSFetchRequest<Manual> = Manual.fetchRequest()
        request.predicate = NSPredicate(format: "product == nil")
        
        do {
            let orphanedManuals = try context.fetch(request)
            
            for manual in orphanedManuals {
                context.delete(manual)
            }
            
            return orphanedManuals.count
            
        } catch {
            print("[DataCleanup] 清理孤立说明书时出错: \(error.localizedDescription)")
            return 0
        }
    }
    
    private func removeEmptyNonDefaultEntities() -> Int {
        var removedCount = 0
        
        // 清理空标签（不删除默认标签）
        let emptyTagsRequest: NSFetchRequest<Tag> = Tag.fetchRequest()
        emptyTagsRequest.predicate = NSPredicate(format: "products.@count == 0")

        do {
            let emptyTags = try context.fetch(emptyTagsRequest)
            let defaultTagNames = Set(Tag.defaultTags.map { $0.0 })

            for tag in emptyTags {
                if let tagName = tag.name, !defaultTagNames.contains(tagName) {
                    context.delete(tag)
                    removedCount += 1
                }
            }
        } catch {
            print("[DataCleanup] 清理空标签时出错: \(error.localizedDescription)")
        }
        
        // 清理空分类（不删除默认分类）
        let emptyCategoriesRequest: NSFetchRequest<Category> = Category.fetchRequest()
        emptyCategoriesRequest.predicate = NSPredicate(format: "products.@count == 0")

        do {
            let emptyCategories = try context.fetch(emptyCategoriesRequest)
            let defaultCategoryNames = Set(Category.defaultCategories.keys)

            for category in emptyCategories {
                if let categoryName = category.name, !defaultCategoryNames.contains(categoryName) {
                    context.delete(category)
                    removedCount += 1
                }
            }
        } catch {
            print("[DataCleanup] 清理空分类时出错: \(error.localizedDescription)")
        }
        
        return removedCount
    }
}

// MARK: - PersistenceController Extension
extension PersistenceController {
    /// 获取数据清理服务
    var cleanupService: DataCleanupService {
        DataCleanupService(context: container.viewContext)
    }
    
    /// 执行完整数据清理
    func performCompleteDataCleanup() async -> DataCleanupService.CleanupResult {
        return await cleanupService.performCompleteCleanup()
    }
    
    /// 清理所有数据并重置
    func resetAllData() async -> (success: Bool, message: String) {
        return await cleanupService.clearAllData()
    }
}
