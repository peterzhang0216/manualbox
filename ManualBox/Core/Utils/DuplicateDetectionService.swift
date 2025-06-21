import Foundation
import CoreData

// MARK: - 重复检测结果
struct DuplicateDetectionResult<T> {
    let duplicates: [DuplicateGroup<T>]
    let totalCount: Int
    let duplicateCount: Int
    
    var hasDuplicates: Bool {
        return !duplicates.isEmpty
    }
    
    var summary: String {
        if duplicates.isEmpty {
            return "未发现重复项"
        } else {
            return "发现 \(duplicateCount) 个重复项，涉及 \(duplicates.count) 组数据"
        }
    }
}

struct DuplicateGroup<T> {
    let key: String
    let items: [T]
    let count: Int
    
    init(key: String, items: [T]) {
        self.key = key
        self.items = items
        self.count = items.count
    }
}

// MARK: - 重复检测配置
struct DuplicateDetectionConfig {
    let caseSensitive: Bool
    let trimWhitespace: Bool
    let ignoreEmpty: Bool
    let minimumDuplicateCount: Int
    
    static let `default` = DuplicateDetectionConfig(
        caseSensitive: false,
        trimWhitespace: true,
        ignoreEmpty: true,
        minimumDuplicateCount: 2
    )
}

// MARK: - 通用重复检测服务
class DuplicateDetectionService {
    private let context: NSManagedObjectContext
    private let config: DuplicateDetectionConfig
    
    init(context: NSManagedObjectContext, config: DuplicateDetectionConfig = .default) {
        self.context = context
        self.config = config
    }
    
    // MARK: - 通用重复检测方法
    
    /// 检测Core Data实体的重复项
    func detectDuplicates<T: NSManagedObject>(
        entityType: T.Type,
        keyPath: KeyPath<T, String?>,
        additionalPredicate: NSPredicate? = nil
    ) async -> DuplicateDetectionResult<T> {
        return await withCheckedContinuation { continuation in
            context.perform {
                let result = self.performDuplicateDetection(
                    entityType: entityType,
                    keyPath: keyPath,
                    additionalPredicate: additionalPredicate
                )
                continuation.resume(returning: result)
            }
        }
    }
    
    /// 检测数组中的重复项
    func detectDuplicates<T>(
        in items: [T],
        keyExtractor: (T) -> String?
    ) -> DuplicateDetectionResult<T> {
        var keyToItems: [String: [T]] = [:]
        var totalCount = 0
        
        for item in items {
            guard let key = keyExtractor(item) else { continue }
            let normalizedKey = normalizeKey(key)
            
            if config.ignoreEmpty && normalizedKey.isEmpty { continue }
            
            keyToItems[normalizedKey, default: []].append(item)
            totalCount += 1
        }
        
        let duplicateGroups = keyToItems.compactMap { (key, items) -> DuplicateGroup<T>? in
            guard items.count >= config.minimumDuplicateCount else { return nil }
            return DuplicateGroup(key: key, items: items)
        }
        
        let duplicateCount = duplicateGroups.reduce(0) { $0 + $1.count }
        
        return DuplicateDetectionResult(
            duplicates: duplicateGroups,
            totalCount: totalCount,
            duplicateCount: duplicateCount
        )
    }
    
    // MARK: - 私有方法
    
    private func performDuplicateDetection<T: NSManagedObject>(
        entityType: T.Type,
        keyPath: KeyPath<T, String?>,
        additionalPredicate: NSPredicate?
    ) -> DuplicateDetectionResult<T> {
        let request = NSFetchRequest<T>(entityName: String(describing: entityType))
        
        if let predicate = additionalPredicate {
            request.predicate = predicate
        }
        
        do {
            let entities = try context.fetch(request)
            return detectDuplicates(in: entities) { entity in
                entity[keyPath: keyPath]
            }
        } catch {
            print("[DuplicateDetection] 获取实体失败: \(error.localizedDescription)")
            return DuplicateDetectionResult(duplicates: [], totalCount: 0, duplicateCount: 0)
        }
    }
    
    private func normalizeKey(_ key: String) -> String {
        var normalized = key
        
        if config.trimWhitespace {
            normalized = normalized.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        if !config.caseSensitive {
            normalized = normalized.lowercased()
        }
        
        return normalized
    }
}

// MARK: - 重复数据清理服务
class DuplicateCleanupService {
    private let context: NSManagedObjectContext
    private let detectionService: DuplicateDetectionService
    
    init(context: NSManagedObjectContext) {
        self.context = context
        self.detectionService = DuplicateDetectionService(context: context)
    }
    
    /// 自动清理重复的分类
    func cleanupDuplicateCategories() async -> (cleaned: Int, errors: [String]) {
        let result = await detectionService.detectDuplicates(
            entityType: Category.self,
            keyPath: \Category.name
        )
        
        return await cleanupDuplicates(result.duplicates) { [self] group in
            // 保留第一个，删除其余的
            let toKeep = group.items.first!
            let toDelete = Array(group.items.dropFirst())

            // 将要删除的分类的产品转移到保留的分类
            for category in toDelete {
                if let products = category.products {
                    for product in products {
                        (product as! Product).category = toKeep
                    }
                }
                context.delete(category)
            }

            return toDelete.count
        }
    }
    
    /// 自动清理重复的标签
    func cleanupDuplicateTags() async -> (cleaned: Int, errors: [String]) {
        let result = await detectionService.detectDuplicates(
            entityType: Tag.self,
            keyPath: \Tag.name
        )
        
        return await cleanupDuplicates(result.duplicates) { [self] group in
            // 保留第一个，删除其余的
            let toKeep = group.items.first!
            let toDelete = Array(group.items.dropFirst())

            // 将要删除的标签的产品关系转移到保留的标签
            for tag in toDelete {
                if let products = tag.products {
                    for product in products {
                        (product as! Product).addToTags(toKeep)
                        (product as! Product).removeFromTags(tag)
                    }
                }
                context.delete(tag)
            }

            return toDelete.count
        }
    }
    
    // MARK: - 私有方法
    
    private func cleanupDuplicates<T>(
        _ duplicateGroups: [DuplicateGroup<T>],
        cleanupHandler: @escaping (DuplicateGroup<T>) throws -> Int
    ) async -> (cleaned: Int, errors: [String]) {
        return await withCheckedContinuation { continuation in
            context.perform {
                var totalCleaned = 0
                var errors: [String] = []
                
                for group in duplicateGroups {
                    do {
                        let cleaned = try cleanupHandler(group)
                        totalCleaned += cleaned
                    } catch {
                        errors.append("清理重复项 '\(group.key)' 失败: \(error.localizedDescription)")
                    }
                }
                
                // 保存更改
                if self.context.hasChanges {
                    do {
                        try self.context.save()
                    } catch {
                        errors.append("保存清理结果失败: \(error.localizedDescription)")
                    }
                }
                
                continuation.resume(returning: (cleaned: totalCleaned, errors: errors))
            }
        }
    }
}

// MARK: - 便捷扩展
extension DuplicateDetectionService {
    /// 检测分类重复项
    func detectDuplicateCategories() async -> DuplicateDetectionResult<Category> {
        return await detectDuplicates(entityType: Category.self, keyPath: \Category.name)
    }
    
    /// 检测标签重复项
    func detectDuplicateTags() async -> DuplicateDetectionResult<Tag> {
        return await detectDuplicates(entityType: Tag.self, keyPath: \Tag.name)
    }
    
    /// 检测产品重复项（在同一分类下）
    func detectDuplicateProducts(in category: Category) async -> DuplicateDetectionResult<Product> {
        let predicate = NSPredicate(format: "category == %@", category)
        return await detectDuplicates(
            entityType: Product.self,
            keyPath: \Product.name,
            additionalPredicate: predicate
        )
    }
}
