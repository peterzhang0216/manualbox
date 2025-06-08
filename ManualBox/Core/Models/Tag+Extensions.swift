//
//  Tag+Extensions.swift
//  ManualBox
//
//  Created by Peter's Mac on 2025/5/10.
//

import Foundation
import CoreData
import SwiftUI

extension Tag {
    // MARK: - 便利属性
    var tagName: String {
        get { name ?? "未命名标签" }
        set { name = newValue }
    }
    
    var tagColor: String {
        get { color ?? "blue" }
        set { color = newValue }
    }
    
    var uiColor: Color {
        switch tagColor.lowercased() {
        case "red": return .red
        case "green": return .green
        case "blue": return .blue
        case "orange": return .orange
        case "yellow": return .yellow
        case "purple": return .purple
        case "pink": return .pink
        case "gray", "grey": return .gray
        default: return .blue
        }
    }
    
    // MARK: - 预览数据
    @MainActor
    static var example: Tag {
        let context = PersistenceController.preview.container.viewContext
        let tag = Tag(context: context)
        tag.id = UUID()
        tag.name = "示例标签"
        tag.color = "blue"
        return tag
    }
    
    // 获取标签下的产品数量
    var productCount: Int {
        return products?.count ?? 0
    }
    
    // 计算标签下所有产品的总值（包括购买价格和维修成本）
    var totalProductValue: Double? {
        guard let products = products as? Set<Product> else { return nil }
        let total = products.compactMap { p -> Double? in
            guard let order = p.order else { return nil }
            
            // 商品购买价格
            var totalValue = order.price?.doubleValue ?? 0
            
            // 累计维修成本
            if let repairRecords = order.repairRecords as? Set<RepairRecord> {
                totalValue += repairRecords
                    .compactMap { $0.cost?.doubleValue }
                    .reduce(0, +)
            }
            
            return totalValue > 0 ? totalValue : nil
        }.reduce(0, +)
        
        return total > 0 ? total : nil
    }
    
    // 获取最近添加的产品（最多 5 个）
    var recentProducts: [Product] {
        guard let products = products as? Set<Product> else { return [] }
        let sorted = Array(products)
            .sorted { ($0.createdAt ?? Date.distantPast) > ($1.createdAt ?? Date.distantPast) }
        return Array(sorted.prefix(5))
    }
    
    // MARK: - 工厂方法
    static func createTag(
        in context: NSManagedObjectContext,
        name: String,
        color: String = "blue"
    ) -> Tag {
        let tag = Tag(context: context)
        tag.id = UUID()
        tag.name = name
        tag.color = color
        return tag
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
}

// 默认标签列表
extension Tag {
    static let defaultTags = [
        ("需维修", "red"),
        ("重要", "orange"),
        ("收藏", "yellow"),
        ("新购", "green"),
        ("待退货", "blue")
    ]
    
    // 在应用首次启动时创建默认标签
    static func createDefaultTags(in context: NSManagedObjectContext) {
        // 添加线程安全检查
        context.performAndWait {
            for (name, color) in defaultTags {
                let fetchRequest: NSFetchRequest<Tag> = Tag.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "name == %@", name)
                fetchRequest.fetchLimit = 1
                
                do {
                    // 使用更严格的存在性检查
                    let existingTags = try context.fetch(fetchRequest)
                    if existingTags.isEmpty {
                        let tag = Tag(context: context)
                        tag.id = UUID()
                        tag.name = name
                        tag.color = color
                        print("创建默认标签: \(name)")
                    } else {
                        print("标签已存在，跳过创建: \(name)")
                    }
                } catch {
                    print("检查标签存在性时出错: \(error.localizedDescription)")
                }
            }
            
            // 保存上下文
            if context.hasChanges {
                do {
                    try context.save()
                    print("默认标签创建完成")
                } catch {
                    print("保存默认标签时出错: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // 获取预览标签
    @MainActor
    static var preview: Tag {
        let context = PersistenceController.preview.container.viewContext
        let tag = Tag(context: context)
        tag.id = UUID()
        tag.name = "重要"
        tag.color = "orange"
        return tag
    }
}

// 可用颜色列表
enum TagColor: String, CaseIterable, Identifiable {
    case red = "red"
    case orange = "orange"
    case yellow = "yellow"
    case green = "green"
    case blue = "blue"
    case purple = "purple"
    case pink = "pink"
    case gray = "gray"
    
    var id: String { self.rawValue }
    
    var color: Color {
        switch self {
        case .red: return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green: return .green
        case .blue: return .blue
        case .purple: return .purple
        case .pink: return .pink
        case .gray: return .gray
        }
    }
    
    var displayName: String {
        switch self {
        case .red: return "红色"
        case .orange: return "橙色"
        case .yellow: return "黄色"
        case .green: return "绿色"
        case .blue: return "蓝色"
        case .purple: return "紫色"
        case .pink: return "粉色"
        case .gray: return "灰色"
        }
    }
}

@MainActor
struct TagDetailView_Previews: PreviewProvider {
    static var previews: some View {
        TagDetailView(tag: Tag.preview)
    }
}