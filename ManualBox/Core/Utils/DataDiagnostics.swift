//
//  DataDiagnostics.swift
//  ManualBox
//
//  Created by Assistant on 2025/1/27.
//

import Foundation
import CoreData

/// 数据诊断工具
struct DataDiagnostics {
    private let context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    /// 诊断结果
    struct DiagnosticResult {
        let duplicateCategories: [String]
        let duplicateTags: [String]
        let totalCategories: Int
        let totalTags: Int
        let hasIssues: Bool
        
        var summary: String {
            var messages: [String] = []
            
            if !duplicateCategories.isEmpty {
                messages.append("发现 \(duplicateCategories.count) 个重复分类")
            }
            
            if !duplicateTags.isEmpty {
                messages.append("发现 \(duplicateTags.count) 个重复标签")
            }
            
            if messages.isEmpty {
                return "数据状态良好，未发现重复项"
            } else {
                return messages.joined(separator: "，")
            }
        }
    }
    
    /// 执行数据诊断
    func diagnose() async -> DiagnosticResult {
        return await withCheckedContinuation { continuation in
            context.perform {
                let duplicateCategories = self.findDuplicateCategories()
                let duplicateTags = self.findDuplicateTags()
                let totalCategories = self.getTotalCount(for: "Category")
                let totalTags = self.getTotalCount(for: "Tag")
                
                let result = DiagnosticResult(
                    duplicateCategories: duplicateCategories,
                    duplicateTags: duplicateTags,
                    totalCategories: totalCategories,
                    totalTags: totalTags,
                    hasIssues: !duplicateCategories.isEmpty || !duplicateTags.isEmpty
                )
                
                continuation.resume(returning: result)
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func findDuplicateCategories() -> [String] {
        let request: NSFetchRequest<Category> = Category.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Category.name, ascending: true)]
        
        do {
            let categories = try context.fetch(request)
            var nameCount: [String: Int] = [:]
            var duplicates: [String] = []
            
            for category in categories {
                let name = category.name ?? ""
                nameCount[name, default: 0] += 1
                
                if nameCount[name] == 2 {
                    duplicates.append(name)
                }
            }
            
            return duplicates
        } catch {
            print("[DataDiagnostics] 查找重复分类时出错: \(error.localizedDescription)")
            return []
        }
    }
    
    private func findDuplicateTags() -> [String] {
        let request: NSFetchRequest<Tag> = Tag.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Tag.name, ascending: true)]
        
        do {
            let tags = try context.fetch(request)
            var nameCount: [String: Int] = [:]
            var duplicates: [String] = []
            
            for tag in tags {
                let name = tag.name ?? ""
                nameCount[name, default: 0] += 1
                
                if nameCount[name] == 2 {
                    duplicates.append(name)
                }
            }
            
            return duplicates
        } catch {
            print("[DataDiagnostics] 查找重复标签时出错: \(error.localizedDescription)")
            return []
        }
    }
    
    private func getTotalCount(for entityName: String) -> Int {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
        
        do {
            return try context.count(for: request)
        } catch {
            print("[DataDiagnostics] 获取 \(entityName) 数量时出错: \(error.localizedDescription)")
            return 0
        }
    }
}

// MARK: - 扩展 PersistenceController
extension PersistenceController {
    /// 获取数据诊断工具
    var diagnostics: DataDiagnostics {
        DataDiagnostics(context: container.viewContext)
    }
    
    /// 快速诊断数据状态
    func quickDiagnose() async -> DataDiagnostics.DiagnosticResult {
        return await diagnostics.diagnose()
    }
}
