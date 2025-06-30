import Foundation
import CoreData
import SwiftUI

// MARK: - 分类管理服务
class CategoryManagementService: ObservableObject {
    static let shared = CategoryManagementService()
    
    @Published var categories: [Category] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let viewContext: NSManagedObjectContext
    
    private init() {
        self.viewContext = PersistenceController.shared.container.viewContext
        loadCategories()
    }
    
    // MARK: - 基本操作
    
    /// 加载所有分类
    func loadCategories() {
        isLoading = true
        
        let request: NSFetchRequest<Category> = Category.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Category.parent, ascending: true),
            NSSortDescriptor(keyPath: \Category.sortOrder, ascending: true),
            NSSortDescriptor(keyPath: \Category.name, ascending: true)
        ]
        
        do {
            categories = try viewContext.fetch(request)
            isLoading = false
        } catch {
            errorMessage = "加载分类失败: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    /// 创建分类
    func createCategory(
        name: String,
        icon: String = "folder",
        color: String = "blue",
        parent: Category? = nil
    ) async throws -> Category {
        return try await withCheckedThrowingContinuation { continuation in
            viewContext.perform {
                do {
                    let category = Category.createCategory(
                        in: self.viewContext,
                        name: name,
                        icon: icon,
                        color: color,
                        parent: parent,
                        sortOrder: Int32(parent?.childCategories.count ?? self.getRootCategories().count)
                    )
                    
                    try self.viewContext.save()
                    
                    DispatchQueue.main.async {
                        self.loadCategories()
                    }
                    
                    continuation.resume(returning: category)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// 更新分类
    func updateCategory(
        _ category: Category,
        name: String? = nil,
        icon: String? = nil,
        color: String? = nil
    ) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            viewContext.perform {
                do {
                    if let name = name {
                        category.name = name
                    }
                    if let icon = icon {
                        category.icon = icon
                    }
                    if let color = color {
                        category.color = color
                    }
                    
                    category.updatedAt = Date()
                    
                    try self.viewContext.save()
                    
                    DispatchQueue.main.async {
                        self.loadCategories()
                    }
                    
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// 删除分类
    func deleteCategory(_ category: Category) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            viewContext.perform {
                do {
                    // 处理子分类
                    for child in category.childCategories {
                        child.parent = category.parent
                    }
                    
                    // 处理产品 - 移动到父分类或"其他"分类
                    let products = category.categoryProducts
                    if !products.isEmpty {
                        let targetCategory = category.parent ?? self.getOrCreateOtherCategory()
                        for product in products {
                            product.category = targetCategory
                        }
                    }
                    
                    self.viewContext.delete(category)
                    try self.viewContext.save()
                    
                    DispatchQueue.main.async {
                        self.loadCategories()
                    }
                    
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - 层级管理
    
    /// 获取根分类
    func getRootCategories() -> [Category] {
        return categories.filter { $0.parent == nil }
            .sorted { $0.sortOrder < $1.sortOrder }
    }
    
    /// 获取分类树结构
    func getCategoryTree() -> [CategoryNode] {
        let rootCategories = getRootCategories()
        return rootCategories.map { buildCategoryNode($0) }
    }
    
    private func buildCategoryNode(_ category: Category) -> CategoryNode {
        let children = category.childCategories.map { buildCategoryNode($0) }
        return CategoryNode(category: category, children: children)
    }
    
    /// 移动分类
    func moveCategory(_ category: Category, to newParent: Category?, at index: Int? = nil) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            viewContext.perform {
                do {
                    category.moveTo(parent: newParent)
                    
                    // 如果指定了索引，重新排序
                    if let index = index {
                        if let newParent = newParent {
                            self.reorderChildren(of: newParent, movingCategory: category, to: index)
                        } else {
                            self.reorderRootCategories(movingCategory: category, to: index)
                        }
                    }
                    
                    try self.viewContext.save()
                    
                    DispatchQueue.main.async {
                        self.loadCategories()
                    }
                    
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func reorderChildren(of parent: Category, movingCategory: Category, to index: Int) {
        var children = parent.childCategories.filter { $0 != movingCategory }
        children.insert(movingCategory, at: min(index, children.count))
        
        for (i, child) in children.enumerated() {
            child.sortOrder = Int32(i)
        }
    }
    
    private func reorderRootCategories(movingCategory: Category, to index: Int) {
        var rootCategories = getRootCategories().filter { $0 != movingCategory }
        rootCategories.insert(movingCategory, at: min(index, rootCategories.count))
        
        for (i, category) in rootCategories.enumerated() {
            category.sortOrder = Int32(i)
        }
    }
    
    // MARK: - 批量操作
    
    /// 批量删除分类
    func deleteCategories(_ categories: [Category]) async throws {
        for category in categories {
            try await deleteCategory(category)
        }
    }
    
    /// 批量移动分类
    func moveCategories(_ categories: [Category], to newParent: Category?) async throws {
        for category in categories {
            try await moveCategory(category, to: newParent)
        }
    }
    
    // MARK: - 统计分析
    
    /// 获取分类统计信息
    func getCategoryStatistics() -> CategoryStatistics {
        let totalCategories = categories.count
        let rootCategories = getRootCategories().count
        let maxDepth = categories.map { $0.level }.max() ?? 0
        let totalProducts = categories.reduce(0) { $0 + $1.productCount }
        let averageProductsPerCategory = totalCategories > 0 ? Double(totalProducts) / Double(totalCategories) : 0
        
        let categoryProductCounts = categories.map { ($0.categoryName, $0.totalProductCount) }
            .sorted { $0.1 > $1.1 }
        
        return CategoryStatistics(
            totalCategories: totalCategories,
            rootCategories: rootCategories,
            maxDepth: maxDepth,
            totalProducts: totalProducts,
            averageProductsPerCategory: averageProductsPerCategory,
            topCategories: Array(categoryProductCounts.prefix(5))
        )
    }
    
    // MARK: - 辅助方法
    
    private func getOrCreateOtherCategory() -> Category {
        let request: NSFetchRequest<Category> = Category.fetchRequest()
        request.predicate = NSPredicate(format: "name == %@", "其他")
        request.fetchLimit = 1
        
        do {
            if let existingCategory = try viewContext.fetch(request).first {
                return existingCategory
            }
        } catch {
            print("查找'其他'分类失败: \(error)")
        }
        
        // 创建"其他"分类
        let otherCategory = Category.createCategory(
            in: viewContext,
            name: "其他",
            icon: "archivebox",
            color: "gray",
            isDefault: true
        )
        
        do {
            try viewContext.save()
        } catch {
            print("创建'其他'分类失败: \(error)")
        }
        
        return otherCategory
    }
}

// MARK: - 数据模型

/// 分类节点（用于树形结构）
struct CategoryNode: Identifiable {
    let id = UUID()
    let category: Category
    let children: [CategoryNode]
    
    var hasChildren: Bool {
        return !children.isEmpty
    }
}

/// 分类统计信息
struct CategoryStatistics {
    let totalCategories: Int
    let rootCategories: Int
    let maxDepth: Int
    let totalProducts: Int
    let averageProductsPerCategory: Double
    let topCategories: [(String, Int)]
}

// MARK: - 分类颜色预设
extension CategoryManagementService {
    static let availableColors = [
        "blue", "green", "red", "orange", "yellow", "purple", "pink", "indigo", "teal", "gray"
    ]
    
    static let availableIcons = [
        "folder", "folder.fill", "archivebox", "archivebox.fill",
        "laptopcomputer", "desktopcomputer", "iphone", "ipad",
        "tv", "speaker", "headphones", "camera",
        "car", "bicycle", "scooter", "airplane",
        "house", "building", "bed.double", "sofa",
        "fork.knife", "cup.and.saucer", "refrigerator", "oven",
        "dumbbell", "tennis.racket", "basketball", "football",
        "book", "pencil", "paintbrush", "scissors",
        "wrench", "hammer", "screwdriver", "gear",
        "heart", "star", "flag", "tag"
    ]
}
