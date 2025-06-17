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
        get { objc_getAssociatedObject(self, &AssociatedKeys.createdAtKey) as? Date }
        set { objc_setAssociatedObject(self, &AssociatedKeys.createdAtKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    
    var updatedAt: Date? {
        get { objc_getAssociatedObject(self, &AssociatedKeys.updatedAtKey) as? Date }
        set { objc_setAssociatedObject(self, &AssociatedKeys.updatedAtKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
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
    
    // MARK: - Associated Objects Keys
    private struct AssociatedKeys {
        static var createdAtKey = "category_createdAt"
        static var updatedAtKey = "category_updatedAt"
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
}

// 默认分类列表
extension Category {
    static let defaultCategories = [
        "电子产品": "laptopcomputer",
        "家用电器": "oven",
        "家具": "sofa",
        "厨房用品": "fork.knife",
        "健身器材": "dumbbell",
        "户外装备": "tent",
        "汽车配件": "car",
        "其他": "archivebox"
    ]
    
    // 在应用首次启动时创建默认分类
    static func createDefaultCategories(in context: NSManagedObjectContext) {
        // 添加线程安全检查
        context.performAndWait {
            for (name, icon) in defaultCategories {
                // 使用更严格的查询条件，同时检查名称和图标
                let fetchRequest: NSFetchRequest<Category> = Category.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "name == %@ OR (name == %@ AND icon == %@)", name, name, icon)
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