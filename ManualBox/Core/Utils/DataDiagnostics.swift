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
        let totalProducts: Int
        let totalOrders: Int
        let totalManuals: Int
        let totalRepairRecords: Int
        let orphanedProducts: Int
        let orphanedOrders: Int
        let orphanedManuals: Int
        let emptyCategories: [String]
        let emptyTags: [String]
        let productsWithoutCategory: Int
        let hasInitializationFlag: Bool
        let hasIssues: Bool

        var summary: String {
            var messages: [String] = []

            if !duplicateCategories.isEmpty {
                messages.append("发现 \(duplicateCategories.count) 个重复分类")
            }

            if !duplicateTags.isEmpty {
                messages.append("发现 \(duplicateTags.count) 个重复标签")
            }

            if orphanedProducts > 0 {
                messages.append("\(orphanedProducts) 个产品没有分类")
            }

            if orphanedOrders > 0 {
                messages.append("\(orphanedOrders) 个订单没有关联产品")
            }

            if orphanedManuals > 0 {
                messages.append("\(orphanedManuals) 个说明书没有关联产品")
            }

            if !emptyCategories.isEmpty {
                messages.append("\(emptyCategories.count) 个空分类")
            }

            if !emptyTags.isEmpty {
                messages.append("\(emptyTags.count) 个空标签")
            }

            if messages.isEmpty {
                return "数据状态良好，未发现问题"
            } else {
                return messages.joined(separator: "，")
            }
        }

        var detailedReport: String {
            var report = "=== 数据诊断详细报告 ===\n\n"

            report += "📊 数据统计:\n"
            report += "• 分类: \(totalCategories) 个\n"
            report += "• 标签: \(totalTags) 个\n"
            report += "• 产品: \(totalProducts) 个\n"
            report += "• 订单: \(totalOrders) 个\n"
            report += "• 说明书: \(totalManuals) 个\n"
            report += "• 维修记录: \(totalRepairRecords) 个\n\n"

            report += "🔧 初始化状态:\n"
            report += "• 初始化标记: \(hasInitializationFlag ? "已设置" : "未设置")\n\n"

            if hasIssues {
                report += "⚠️ 发现的问题:\n"

                if !duplicateCategories.isEmpty {
                    report += "• 重复分类: \(duplicateCategories.joined(separator: ", "))\n"
                }

                if !duplicateTags.isEmpty {
                    report += "• 重复标签: \(duplicateTags.joined(separator: ", "))\n"
                }

                if orphanedProducts > 0 {
                    report += "• 无分类产品: \(orphanedProducts) 个\n"
                }

                if orphanedOrders > 0 {
                    report += "• 孤立订单: \(orphanedOrders) 个\n"
                }

                if orphanedManuals > 0 {
                    report += "• 孤立说明书: \(orphanedManuals) 个\n"
                }

                if !emptyCategories.isEmpty {
                    report += "• 空分类: \(emptyCategories.joined(separator: ", "))\n"
                }

                if !emptyTags.isEmpty {
                    report += "• 空标签: \(emptyTags.joined(separator: ", "))\n"
                }
            } else {
                report += "✅ 数据状态良好，未发现问题\n"
            }

            return report
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
                let totalProducts = self.getTotalCount(for: "Product")
                let totalOrders = self.getTotalCount(for: "Order")
                let totalManuals = self.getTotalCount(for: "Manual")
                let totalRepairRecords = self.getTotalCount(for: "RepairRecord")
                let orphanedProducts = self.findOrphanedProducts()
                let orphanedOrders = self.findOrphanedOrders()
                let orphanedManuals = self.findOrphanedManuals()
                let emptyCategories = self.findEmptyCategories()
                let emptyTags = self.findEmptyTags()
                let productsWithoutCategory = self.findProductsWithoutCategory()
                let hasInitializationFlag = UserDefaults.standard.bool(forKey: "ManualBox_HasInitializedDefaultData")

                let hasIssues = !duplicateCategories.isEmpty ||
                               !duplicateTags.isEmpty ||
                               orphanedProducts > 0 ||
                               orphanedOrders > 0 ||
                               orphanedManuals > 0 ||
                               !emptyCategories.isEmpty ||
                               !emptyTags.isEmpty ||
                               productsWithoutCategory > 0

                let result = DiagnosticResult(
                    duplicateCategories: duplicateCategories,
                    duplicateTags: duplicateTags,
                    totalCategories: totalCategories,
                    totalTags: totalTags,
                    totalProducts: totalProducts,
                    totalOrders: totalOrders,
                    totalManuals: totalManuals,
                    totalRepairRecords: totalRepairRecords,
                    orphanedProducts: orphanedProducts,
                    orphanedOrders: orphanedOrders,
                    orphanedManuals: orphanedManuals,
                    emptyCategories: emptyCategories,
                    emptyTags: emptyTags,
                    productsWithoutCategory: productsWithoutCategory,
                    hasInitializationFlag: hasInitializationFlag,
                    hasIssues: hasIssues
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

    private func findOrphanedProducts() -> Int {
        let request: NSFetchRequest<Product> = Product.fetchRequest()
        request.predicate = NSPredicate(format: "category == nil")

        do {
            return try context.count(for: request)
        } catch {
            print("[DataDiagnostics] 查找无分类产品时出错: \(error.localizedDescription)")
            return 0
        }
    }

    private func findOrphanedOrders() -> Int {
        let request: NSFetchRequest<Order> = Order.fetchRequest()
        request.predicate = NSPredicate(format: "product == nil")

        do {
            return try context.count(for: request)
        } catch {
            print("[DataDiagnostics] 查找孤立订单时出错: \(error.localizedDescription)")
            return 0
        }
    }

    private func findOrphanedManuals() -> Int {
        let request: NSFetchRequest<Manual> = Manual.fetchRequest()
        request.predicate = NSPredicate(format: "product == nil")

        do {
            return try context.count(for: request)
        } catch {
            print("[DataDiagnostics] 查找孤立说明书时出错: \(error.localizedDescription)")
            return 0
        }
    }

    private func findEmptyCategories() -> [String] {
        let request: NSFetchRequest<Category> = Category.fetchRequest()
        request.predicate = NSPredicate(format: "products.@count == 0")

        do {
            let categories = try context.fetch(request)
            return categories.compactMap { $0.name }
        } catch {
            print("[DataDiagnostics] 查找空分类时出错: \(error.localizedDescription)")
            return []
        }
    }

    private func findEmptyTags() -> [String] {
        let request: NSFetchRequest<Tag> = Tag.fetchRequest()
        request.predicate = NSPredicate(format: "products.@count == 0")

        do {
            let tags = try context.fetch(request)
            return tags.compactMap { $0.name }
        } catch {
            print("[DataDiagnostics] 查找空标签时出错: \(error.localizedDescription)")
            return []
        }
    }

    private func findProductsWithoutCategory() -> Int {
        let request: NSFetchRequest<Product> = Product.fetchRequest()
        request.predicate = NSPredicate(format: "category == nil")

        do {
            return try context.count(for: request)
        } catch {
            print("[DataDiagnostics] 查找无分类产品时出错: \(error.localizedDescription)")
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

    /// 自动修复重复数据问题
    @MainActor
    func autoFixDuplicateData() async -> (success: Bool, message: String, result: DataDiagnostics.DiagnosticResult?) {
        // 1. 先诊断当前状态
        let initialResult = await quickDiagnose()
        print("[AutoFix] 初始诊断结果: \(initialResult.summary)")

        if !initialResult.hasIssues {
            return (true, "数据状态良好，未发现重复项", initialResult)
        }

        // 2. 执行清理
        await cleanupDuplicateData()
        print("[AutoFix] 重复数据清理完成")

        // 3. 再次诊断验证结果
        let finalResult = await quickDiagnose()
        print("[AutoFix] 最终诊断结果: \(finalResult.summary)")

        if finalResult.hasIssues {
            return (false, "清理后仍存在重复数据: \(finalResult.summary)", finalResult)
        } else {
            let message = "重复数据修复成功！清理了 \(initialResult.duplicateCategories.count) 个重复分类和 \(initialResult.duplicateTags.count) 个重复标签"
            return (true, message, finalResult)
        }
    }
}
