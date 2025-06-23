//
//  Category+Extensions.swift
//  ManualBox
//
//  Created by Peter's Mac on 2025/5/10.
//

import Foundation
import CoreData
import SwiftUI
import ObjectiveC

extension Category {
    // MARK: - 便利属性
    var categoryName: String {
        get { name ?? "未命名分类" }
        set { name = newValue }
    }
    
    var categoryIcon: String {
        get { icon ?? "folder" }
        set { icon = newValue }
    }
    
    var categoryProducts: [Product] {
        let productsSet = products as? Set<Product> ?? []
        return Array(productsSet).sorted { $0.productName < $1.productName }
    }
    
    // 添加createdAt和updatedAt属性
    var createdAt: Date? {
        get { objc_getAssociatedObject(self, AssociatedKeys.createdAtKey) as? Date }
        set { objc_setAssociatedObject(self, AssociatedKeys.createdAtKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    var updatedAt: Date? {
        get { objc_getAssociatedObject(self, AssociatedKeys.updatedAtKey) as? Date }
        set { objc_setAssociatedObject(self, AssociatedKeys.updatedAtKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    
    // MARK: - 工厂方法
    static func createCategory(
        in context: NSManagedObjectContext,
        name: String,
        icon: String = "folder"
    ) -> Category {
        let category = Category(context: context)
        category.id = UUID()
        category.name = name
        category.icon = icon
        category.createdAt = Date()
        category.updatedAt = Date()
        return category
    }

    /// 安全创建分类（检查重复）
    static func createCategoryIfNotExists(
        in context: NSManagedObjectContext,
        name: String,
        icon: String = "folder"
    ) -> Category {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        // 检查是否已存在同名分类
        let fetchRequest: NSFetchRequest<Category> = Category.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "name ==[c] %@", trimmedName)
        fetchRequest.fetchLimit = 1

        do {
            let existingCategories = try context.fetch(fetchRequest)
            if let existingCategory = existingCategories.first {
                print("[Category] 分类已存在，返回现有分类: \(trimmedName)")
                return existingCategory
            }
        } catch {
            print("[Category] 检查分类存在性时出错: \(error.localizedDescription)")
        }

        // 创建新分类
        return createCategory(in: context, name: trimmedName, icon: icon)
    }
    
    // MARK: - Associated Objects Keys
    private struct AssociatedKeys {
        static let createdAtKey = UnsafeRawPointer(bitPattern: "category_createdAt".hashValue)!
        static let updatedAtKey = UnsafeRawPointer(bitPattern: "category_updatedAt".hashValue)!
    }
    
    // MARK: - 预览数据
    @MainActor
    static var example: Category {
        let context = PersistenceController.preview.container.viewContext
        let category = createCategory(in: context, name: "示例分类", icon: "folder.fill")
        return category
    }
    
    // MARK: - 辅助方法
    func addProduct(_ product: Product) {
        var currentProducts = products as? Set<Product> ?? Set<Product>()
        currentProducts.insert(product)
        products = currentProducts as NSSet
    }
    
    func removeProduct(_ product: Product) {
        var currentProducts = products as? Set<Product> ?? Set<Product>()
        currentProducts.remove(product)
        products = currentProducts as NSSet
    }
    
    // 获取该分类下的商品数量
    var productCount: Int {
        return categoryProducts.count
    }
    
    var totalProductValue: Double? {
        guard let products = products as? Set<Product> else { return nil }
        let total = products.compactMap { product -> Double? in
            guard let order = product.order else { return nil }
            var total = order.price?.doubleValue ?? 0
            
            // 加上维修成本
            if let repairRecords = order.repairRecords as? Set<RepairRecord> {
                total += repairRecords
                    .compactMap { $0.cost?.doubleValue }
                    .reduce(0, +)
            }
            
            return total > 0 ? total : nil
        }.reduce(0, +)
        return total > 0 ? total : nil
    }
    
    var recentProducts: [Product] {
        guard let products = products as? Set<Product> else { return [] }
        let sorted = Array(products)
            .sorted { ($0.createdAt ?? Date.distantPast) > ($1.createdAt ?? Date.distantPast) }
        return Array(sorted.prefix(5))
    }

    // 自定义排序优先级，确保"其他"分类显示在最下面
    var sortPriority: Int {
        if categoryName == "其他" {
            return 999 // 最大值，确保排在最后
        } else {
            return 0 // 其他分类正常排序
        }
    }
}

// 默认分类列表
extension Category {
    static let defaultCategories: [String: String] = [
        "电子产品": "laptopcomputer",
        "家用电器": "oven",
        "家具家私": "sofa",
        "厨房用品": "fork.knife",
        "运动器材": "dumbbell",
        "汽车配件": "car",
        "文玩": "cube.box",
        "其他": "archivebox"
    ]
    
    // 清空所有分类中的产品，但保留分类结构
    static func clearAllCategoryProducts(in context: NSManagedObjectContext) {
        context.performAndWait {
            do {
                // 1. 获取所有产品并清空其分类关联
                let productFetchRequest: NSFetchRequest<Product> = Product.fetchRequest()
                let allProducts = try context.fetch(productFetchRequest)

                for product in allProducts {
                    product.category = nil
                    print("[Category] 清空产品分类关联: \(product.name ?? "未知产品")")
                }

                // 2. 保存更改
                try context.save()
                print("[Category] 所有产品的分类关联已清空")

            } catch {
                print("[Category] 清空分类关联时出错: \(error.localizedDescription)")
            }
        }
    }

    // 重置到默认分类（删除现有分类并重新创建）
    static func resetToDefaultCategories(in context: NSManagedObjectContext) {
        context.performAndWait {
            do {
                // 1. 删除所有现有分类
                let fetchRequest: NSFetchRequest<Category> = Category.fetchRequest()
                let existingCategories = try context.fetch(fetchRequest)

                for category in existingCategories {
                    // 将该分类下的产品移动到"其他"分类（如果存在）
                    if let products = category.products as? Set<Product> {
                        for product in products {
                            product.category = nil // 先清空分类关联
                        }
                    }
                    context.delete(category)
                    print("[Category] 删除分类: \(category.name ?? "未知")")
                }

                // 2. 创建新的默认分类
                for (name, icon) in defaultCategories {
                    let category = Category(context: context)
                    category.id = UUID()
                    category.name = name
                    category.icon = icon
                    print("[Category] 创建新分类: \(name)")
                }

                // 3. 保存更改
                try context.save()
                print("[Category] 分类重置完成")

            } catch {
                print("[Category] 重置分类时出错: \(error.localizedDescription)")
            }
        }
    }

    // 在应用首次启动时创建默认分类
    static func createDefaultCategories(in context: NSManagedObjectContext) {
        // 添加线程安全检查
        context.performAndWait {
            // 首先检查是否已经有分类存在，如果有则跳过整个创建过程
            let totalCategoriesRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Category")
            let totalCount = (try? context.count(for: totalCategoriesRequest)) ?? 0

            if totalCount >= defaultCategories.count {
                print("[Category] 已存在 \(totalCount) 个分类，跳过默认分类创建")
                return
            }

            for (name, icon) in defaultCategories {
                // 使用严格的名称匹配（忽略大小写和空格）
                let fetchRequest: NSFetchRequest<Category> = Category.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "name ==[c] %@", name.trimmingCharacters(in: .whitespacesAndNewlines))
                fetchRequest.fetchLimit = 1

                do {
                    // 使用更严格的存在性检查
                    let existingCategories = try context.fetch(fetchRequest)
                    if existingCategories.isEmpty {
                        let category = Category(context: context)
                        category.id = UUID()
                        category.name = name
                        category.icon = icon
                        print("[Category] 创建默认分类: \(name)")
                    } else {
                        print("[Category] 分类已存在，跳过创建: \(name)")
                        // 如果存在但图标不同，更新图标
                        if let existing = existingCategories.first, existing.icon != icon {
                            existing.icon = icon
                            print("[Category] 更新分类图标: \(name) -> \(icon)")
                        }
                    }
                } catch {
                    print("[Category] 检查分类存在性时出错: \(error.localizedDescription)")
                }
            }

            // 保存上下文
            if context.hasChanges {
                do {
                    try context.save()
                    print("[Category] 默认分类创建完成")
                } catch {
                    print("[Category] 保存默认分类时出错: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // 获取预览分类
    @MainActor
    static var preview: Category {
        let context = PersistenceController.preview.container.viewContext
        let category = Category(context: context)
        category.id = UUID()
        category.name = "电子产品"
        category.icon = "laptopcomputer"
        return category
    }
}

@MainActor
struct CategoryDetailView_Previews: PreviewProvider {
    static var previews: some View {
        CategoryDetailView(category: Category.preview)
    }
}