import Foundation
import CoreData
import Combine

// MARK: - 产品Repository
class ProductRepository: BaseRepository<Product> {
    
    init(context: NSManagedObjectContext) {
        super.init(context: context, entityName: "Product")
    }
    
    // MARK: - 产品特定查询
    
    func fetchByCategory(_ category: Category) async throws -> [Product] {
        let predicate = NSPredicate(format: "category == %@", category)
        return try await fetchWithFilters([predicate])
    }
    
    func fetchByTag(_ tag: Tag) async throws -> [Product] {
        let predicate = NSPredicate(format: "ANY tags == %@", tag)
        return try await fetchWithFilters([predicate])
    }
    
    func fetchExpiringSoon(within days: Int) async throws -> [Product] {
        let futureDate = Calendar.current.date(byAdding: .day, value: days, to: Date())!
        let predicates = [
            NSPredicate(format: "order != nil"),
            NSPredicate(format: "order.warrantyEndDate != nil"),
            NSPredicate(format: "order.warrantyEndDate <= %@", futureDate as NSDate),
            NSPredicate(format: "order.warrantyEndDate >= %@", Date() as NSDate)
        ]
        return try await fetchWithFilters(predicates)
    }
    
    func fetchRecent(limit: Int = 10) async throws -> [Product] {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let request = NSFetchRequest<Product>(entityName: "Product")
                    request.sortDescriptors = [
                        NSSortDescriptor(keyPath: \Product.updatedAt, ascending: false)
                    ]
                    request.fetchLimit = limit
                    
                    let results = try self.context.fetch(request)
                    continuation.resume(returning: results)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    override func search(_ query: String) async throws -> [Product] {
        let predicates = [
            NSPredicate(format: "name CONTAINS[cd] %@", query),
            NSPredicate(format: "brand CONTAINS[cd] %@", query),
            NSPredicate(format: "model CONTAINS[cd] %@", query),
            NSPredicate(format: "notes CONTAINS[cd] %@", query)
        ]
        let compoundPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: predicates)
        return try await fetchWithFilters([compoundPredicate])
    }
    
    // MARK: - 统计查询
    
    func countByCategory() async throws -> [String: Int] {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let request = NSFetchRequest<NSDictionary>(entityName: "Product")
                    request.resultType = .dictionaryResultType
                    
                    let categoryExpression = NSExpression(forKeyPath: "category.name")
                    let countExpression = NSExpression(forFunction: "count:", arguments: [NSExpression(forKeyPath: "id")])
                    
                    let categoryExpressionDescription = NSExpressionDescription()
                    categoryExpressionDescription.name = "category"
                    categoryExpressionDescription.expression = categoryExpression
                    categoryExpressionDescription.expressionResultType = .stringAttributeType
                    
                    let countExpressionDescription = NSExpressionDescription()
                    countExpressionDescription.name = "count"
                    countExpressionDescription.expression = countExpression
                    countExpressionDescription.expressionResultType = .integer32AttributeType
                    
                    request.propertiesToFetch = [categoryExpressionDescription, countExpressionDescription]
                    request.propertiesToGroupBy = [categoryExpressionDescription]
                    
                    let results = try self.context.fetch(request)
                    var categoryCount: [String: Int] = [:]
                    
                    for result in results {
                        if let categoryName = result["category"] as? String,
                           let count = result["count"] as? Int {
                            categoryCount[categoryName] = count
                        }
                    }
                    
                    continuation.resume(returning: categoryCount)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

// MARK: - 分类Repository
class CategoryRepository: BaseRepository<Category> {
    
    init(context: NSManagedObjectContext) {
        super.init(context: context, entityName: "Category")
    }
    
    func fetchWithProductCount() async throws -> [(Category, Int)] {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let request = NSFetchRequest<Category>(entityName: "Category")
                    let categories = try self.context.fetch(request)
                    var result: [(Category, Int)] = []
                    
                    for category in categories {
                        let productCount = category.products?.count ?? 0
                        result.append((category, productCount))
                    }
                    
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    override func search(_ query: String) async throws -> [Category] {
        let predicate = NSPredicate(format: "name CONTAINS[cd] %@", query)
        return try await fetchWithFilters([predicate])
    }
}

// MARK: - 标签Repository
class TagRepository: BaseRepository<Tag> {
    
    init(context: NSManagedObjectContext) {
        super.init(context: context, entityName: "Tag")
    }
    
    func fetchPopular(limit: Int = 10) async throws -> [Tag] {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let request = NSFetchRequest<Tag>(entityName: "Tag")
                    // 按关联的产品数量排序
                    request.sortDescriptors = [
                        NSSortDescriptor(key: "products.@count", ascending: false)
                    ]
                    request.fetchLimit = limit
                    
                    let results = try self.context.fetch(request)
                    continuation.resume(returning: results)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    override func search(_ query: String) async throws -> [Tag] {
        let predicate = NSPredicate(format: "name CONTAINS[cd] %@", query)
        return try await fetchWithFilters([predicate])
    }
}

// MARK: - 订单Repository
class OrderRepository: BaseRepository<Order> {
    
    init(context: NSManagedObjectContext) {
        super.init(context: context, entityName: "Order")
    }
    
    func fetchByDateRange(from startDate: Date, to endDate: Date) async throws -> [Order] {
        let predicate = NSPredicate(format: "orderDate >= %@ AND orderDate <= %@", 
                                  startDate as NSDate, endDate as NSDate)
        return try await fetchWithFilters([predicate])
    }
    
    func fetchByPlatform(_ platform: String) async throws -> [Order] {
        let predicate = NSPredicate(format: "platform CONTAINS[cd] %@", platform)
        return try await fetchWithFilters([predicate])
    }
    
    override func search(_ query: String) async throws -> [Order] {
        let predicates = [
            NSPredicate(format: "orderNumber CONTAINS[cd] %@", query),
            NSPredicate(format: "platform CONTAINS[cd] %@", query),
            NSPredicate(format: "product.name CONTAINS[cd] %@", query)
        ]
        let compoundPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: predicates)
        return try await fetchWithFilters([compoundPredicate])
    }
}

// MARK: - 维修记录Repository
class RepairRecordRepository: BaseRepository<RepairRecord> {
    
    init(context: NSManagedObjectContext) {
        super.init(context: context, entityName: "RepairRecord")
    }
    
    func fetchByProduct(_ product: Product) async throws -> [RepairRecord] {
        let predicate = NSPredicate(format: "order.product == %@", product)
        return try await fetchWithFilters([predicate])
    }
    
    func fetchByCostRange(min: Double, max: Double) async throws -> [RepairRecord] {
        let predicate = NSPredicate(format: "cost >= %@ AND cost <= %@", 
                                  NSNumber(value: min), NSNumber(value: max))
        return try await fetchWithFilters([predicate])
    }
    
    override func search(_ query: String) async throws -> [RepairRecord] {
        let predicates = [
            NSPredicate(format: "details CONTAINS[cd] %@", query),
            NSPredicate(format: "order.product.name CONTAINS[cd] %@", query)
        ]
        let compoundPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: predicates)
        return try await fetchWithFilters([compoundPredicate])
    }
}

// MARK: - 说明书Repository
class ManualRepository: BaseRepository<Manual> {
    
    init(context: NSManagedObjectContext) {
        super.init(context: context, entityName: "Manual")
    }
    
    // MARK: - 说明书特定查询
    
    /// 根据产品获取说明书
    func fetchByProduct(_ product: Product) async throws -> [Manual] {
        let predicate = NSPredicate(format: "product == %@", product)
        return try await fetchWithFilters([predicate])
    }
    
    /// 获取待OCR处理的说明书
    func fetchPendingOCR() async throws -> [Manual] {
        let predicate = NSPredicate(format: "isOCRPending == YES AND isOCRProcessed == NO")
        return try await fetchWithFilters([predicate])
    }
    
    /// 获取已完成OCR的说明书
    func fetchOCRProcessed() async throws -> [Manual] {
        let predicate = NSPredicate(format: "isOCRProcessed == YES")
        return try await fetchWithFilters([predicate])
    }
    
    /// 根据文件类型获取说明书
    func fetchByFileType(_ fileType: String) async throws -> [Manual] {
        let predicate = NSPredicate(format: "fileType == %@", fileType)
        return try await fetchWithFilters([predicate])
    }
    
    override func search(_ query: String) async throws -> [Manual] {
        let predicates = [
            NSPredicate(format: "fileName CONTAINS[cd] %@", query),
            NSPredicate(format: "content CONTAINS[cd] %@", query),
            NSPredicate(format: "product.name CONTAINS[cd] %@", query),
            NSPredicate(format: "product.brand CONTAINS[cd] %@", query)
        ]
        let compoundPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: predicates)
        return try await fetchWithFilters([compoundPredicate])
    }
}