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

    /// 安全创建标签（检查重复）
    static func createTagIfNotExists(
        in context: NSManagedObjectContext,
        name: String,
        color: String = "blue"
    ) -> Tag {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        // 检查是否已存在同名标签
        let fetchRequest: NSFetchRequest<Tag> = Tag.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "name ==[c] %@", trimmedName)
        fetchRequest.fetchLimit = 1

        do {
            let existingTags = try context.fetch(fetchRequest)
            if let existingTag = existingTags.first {
                print("[Tag] 标签已存在，返回现有标签: \(trimmedName)")
                return existingTag
            }
        } catch {
            print("[Tag] 检查标签存在性时出错: \(error.localizedDescription)")
        }

        // 创建新标签
        return createTag(in: context, name: trimmedName, color: color)
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
    static let defaultTags: [(String, String)] = [
        ("重要", "orange"),
        ("收藏", "yellow"),
        ("新购", "green"),
        ("需维修", "red"),
        ("待退货", "blue"),
        ("保修中", "purple"),
        ("已过保", "gray")
    ]
    
    // 在应用首次启动时创建默认标签
    static func createDefaultTags(in context: NSManagedObjectContext) {
        // 添加线程安全检查
        context.performAndWait {
            // 首先检查是否已经有标签存在，如果有则跳过整个创建过程
            let totalTagsRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Tag")
            let totalCount = (try? context.count(for: totalTagsRequest)) ?? 0

            if totalCount >= defaultTags.count {
                print("[Tag] 已存在 \(totalCount) 个标签，跳过默认标签创建")
                return
            }

            for (name, color) in defaultTags {
                // 使用严格的名称匹配（忽略大小写和空格）
                let fetchRequest: NSFetchRequest<Tag> = Tag.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "name ==[c] %@", name.trimmingCharacters(in: .whitespacesAndNewlines))
                fetchRequest.fetchLimit = 1

                do {
                    // 使用更严格的存在性检查
                    let existingTags = try context.fetch(fetchRequest)
                    if existingTags.isEmpty {
                        let tag = Tag(context: context)
                        tag.id = UUID()
                        tag.name = name
                        tag.color = color
                        print("[Tag] 创建默认标签: \(name)")
                    } else {
                        print("[Tag] 标签已存在，跳过创建: \(name)")
                        // 如果存在但颜色不同，更新颜色
                        if let existing = existingTags.first, existing.color != color {
                            existing.color = color
                            print("[Tag] 更新标签颜色: \(name) -> \(color)")
                        }
                    }
                } catch {
                    print("[Tag] 检查标签存在性时出错: \(error.localizedDescription)")
                }
            }

            // 保存上下文
            if context.hasChanges {
                do {
                    try context.save()
                    print("[Tag] 默认标签创建完成")
                } catch {
                    print("[Tag] 保存默认标签时出错: \(error.localizedDescription)")
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