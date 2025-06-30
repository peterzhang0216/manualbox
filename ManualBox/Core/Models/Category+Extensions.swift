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

    var categoryColor: String {
        get { color ?? "blue" }
        set { color = newValue }
    }

    var categoryProducts: [Product] {
        let productsSet = products as? Set<Product> ?? []
        return Array(productsSet).sorted { $0.productName < $1.productName }
    }

    // MARK: - 层级结构属性

    var parentCategory: Category? {
        get { parent }
        set { parent = newValue }
    }

    var childCategories: [Category] {
        let childrenSet = children as? Set<Category> ?? []
        return Array(childrenSet).sorted { $0.sortOrder < $1.sortOrder }
    }

    var isRootCategory: Bool {
        return parent == nil
    }

    var hasChildren: Bool {
        return !childCategories.isEmpty
    }

    var level: Int {
        var currentLevel = 0
        var currentParent = parent
        while currentParent != nil {
            currentLevel += 1
            currentParent = currentParent?.parent
        }
        return currentLevel
    }

    var fullPath: String {
        var path: [String] = []
        var current: Category? = self

        while let category = current {
            path.insert(category.categoryName, at: 0)
            current = category.parent
        }

        return path.joined(separator: " > ")
    }
    
    // MARK: - 工厂方法
    static func createCategory(
        in context: NSManagedObjectContext,
        name: String,
        icon: String = "folder",
        color: String = "blue",
        parent: Category? = nil,
        sortOrder: Int32 = 0,
        isDefault: Bool = false
    ) -> Category {
        let category = Category(context: context)
        category.id = UUID()
        category.name = name
        category.icon = icon
        category.color = color
        category.parent = parent
        category.sortOrder = sortOrder
        category.isDefault = isDefault
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
            return Int(sortOrder)
        }
    }

    // MARK: - 层级管理方法

    /// 添加子分类
    func addChild(_ child: Category) {
        child.parent = self
        child.sortOrder = Int32(childCategories.count)

        var currentChildren = children as? Set<Category> ?? Set<Category>()
        currentChildren.insert(child)
        children = currentChildren as NSSet

        updatedAt = Date()
    }

    /// 移除子分类
    func removeChild(_ child: Category) {
        child.parent = nil

        var currentChildren = children as? Set<Category> ?? Set<Category>()
        currentChildren.remove(child)
        children = currentChildren as NSSet

        // 重新排序剩余的子分类
        reorderChildren()
        updatedAt = Date()
    }

    /// 重新排序子分类
    func reorderChildren() {
        let sortedChildren = childCategories
        for (index, child) in sortedChildren.enumerated() {
            child.sortOrder = Int32(index)
        }
    }

    /// 移动到新的父分类
    func moveTo(parent newParent: Category?) {
        // 检查是否会造成循环引用
        if let newParent = newParent, isAncestor(of: newParent) {
            print("警告：无法移动分类，会造成循环引用")
            return
        }

        // 从当前父分类中移除
        parent?.removeChild(self)

        // 添加到新的父分类
        if let newParent = newParent {
            newParent.addChild(self)
        } else {
            parent = nil
            sortOrder = 0
        }
    }

    /// 检查是否是指定分类的祖先
    func isAncestor(of category: Category) -> Bool {
        var current = category.parent
        while let parent = current {
            if parent == self {
                return true
            }
            current = parent.parent
        }
        return false
    }

    /// 获取所有后代分类（包括子分类的子分类）
    func getAllDescendants() -> [Category] {
        var descendants: [Category] = []

        for child in childCategories {
            descendants.append(child)
            descendants.append(contentsOf: child.getAllDescendants())
        }

        return descendants
    }

    /// 获取所有后代分类中的产品总数
    var totalProductCount: Int {
        var count = productCount
        for child in childCategories {
            count += child.totalProductCount
        }
        return count
    }

    /// 获取所有后代分类中的产品总价值
    var totalDescendantValue: Double? {
        var total = totalProductValue ?? 0

        for child in childCategories {
            total += child.totalDescendantValue ?? 0
        }

        return total > 0 ? total : nil
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