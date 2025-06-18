//
//  PersistenceMaintenance.swift
//  ManualBox
//
//  Created by Peter's Mac on 2025/4/27.
//

import CoreData

// MARK: - 数据迁移和维护
extension PersistenceController {
    
    /// 执行数据库维护操作
    func performMaintenance() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            performBackgroundTask { context in
                do {
                    // 清理孤立的数据
                    try self.cleanupOrphanedData(in: context)
                    
                    // 优化数据库
                    try self.optimizeDatabase(in: context)
                    
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func cleanupOrphanedData(in context: NSManagedObjectContext) throws {
        // 清理没有关联产品的标签
        let orphanedTagsRequest = NSFetchRequest<Tag>(entityName: "Tag")
        orphanedTagsRequest.predicate = NSPredicate(format: "products.@count == 0")
        
        let orphanedTags = try context.fetch(orphanedTagsRequest)
        orphanedTags.forEach { context.delete($0) }
        
        // 清理没有关联产品的分类（保留默认分类）
        let orphanedCategoriesRequest = NSFetchRequest<Category>(entityName: "Category")
        orphanedCategoriesRequest.predicate = NSPredicate(
            format: "products.@count == 0 AND NOT (name IN %@)",
            Category.defaultCategories.keys.map { $0 }
        )
        
        let orphanedCategories = try context.fetch(orphanedCategoriesRequest)
        orphanedCategories.forEach { context.delete($0) }
        
        try context.save()
    }
    
    private func optimizeDatabase(in context: NSManagedObjectContext) throws {
        // 刷新所有对象以释放内存
        context.refreshAllObjects()

        // 强制保存以确保所有更改都写入磁盘
        try context.save()
    }
} 