import Foundation
import CoreData
import Combine

// MARK: - 查询缓存配置
struct QueryCacheConfiguration {
    let maxCacheSize: Int
    let cacheExpirationTime: TimeInterval
    let enableMemoryPressureEviction: Bool
    
    static let `default` = QueryCacheConfiguration(
        maxCacheSize: 100,
        cacheExpirationTime: 300, // 5分钟
        enableMemoryPressureEviction: true
    )
}

// MARK: - 缓存条目
private class CacheEntry<T> {
    let data: T
    let timestamp: Date
    let accessCount: Int
    
    init(data: T) {
        self.data = data
        self.timestamp = Date()
        self.accessCount = 1
    }
    
    var isExpired: Bool {
        Date().timeIntervalSince(timestamp) > 300 // 5分钟过期
    }
}

// MARK: - 优化的数据服务
class OptimizedDataService {
    private let context: NSManagedObjectContext
    private let backgroundContext: NSManagedObjectContext
    private let cache: NSCache<NSString, AnyObject>
    private let configuration: QueryCacheConfiguration
    
    // 性能监控
    private let performanceMonitor: PlatformPerformanceManager?
    
    // 批量操作队列
    private let batchOperationQueue = DispatchQueue(label: "batch.operations", qos: .userInitiated)
    private var pendingBatchOperations: [() -> Void] = []
    private var batchTimer: Timer?
    
    init(
        context: NSManagedObjectContext,
        configuration: QueryCacheConfiguration = .default
    ) {
        self.context = context
        self.configuration = configuration
        self.backgroundContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        self.backgroundContext.persistentStoreCoordinator = context.persistentStoreCoordinator
        self.cache = NSCache<NSString, AnyObject>()
        self.performanceMonitor = ServiceContainer.shared.resolve(PlatformPerformanceManager.self)
        
        setupCache()
        setupMemoryPressureHandling()
    }
    
    // MARK: - 优化的查询方法
    
    /// 带缓存的查询
    func fetchWithCache<T: NSManagedObject>(
        entityType: T.Type,
        predicate: NSPredicate? = nil,
        sortDescriptors: [NSSortDescriptor] = [],
        cacheKey: String? = nil,
        useCache: Bool = true
    ) async -> Result<[T], Error> {
        let startTime = CFAbsoluteTimeGetCurrent()
        let entityName = String(describing: entityType)
        
        // 生成缓存键
        let finalCacheKey = cacheKey ?? generateCacheKey(
            entityName: entityName,
            predicate: predicate,
            sortDescriptors: sortDescriptors
        )
        
        // 尝试从缓存获取
        if useCache, let cachedResult = getCachedResult(for: finalCacheKey) as? [T] {
            recordPerformanceMetric(operation: "fetch_cached", entityName: entityName, duration: CFAbsoluteTimeGetCurrent() - startTime)
            return .success(cachedResult)
        }
        
        // 从数据库查询
        return await withCheckedContinuation { continuation in
            backgroundContext.perform {
                let request = NSFetchRequest<T>(entityName: entityName)
                request.predicate = predicate
                request.sortDescriptors = sortDescriptors
                
                // 优化查询性能
                request.returnsObjectsAsFaults = false
                request.includesSubentities = false
                
                do {
                    let results = try self.backgroundContext.fetch(request)
                    
                    // 缓存结果
                    if useCache {
                        self.setCachedResult(results, for: finalCacheKey)
                    }
                    
                    let duration = CFAbsoluteTimeGetCurrent() - startTime
                    self.recordPerformanceMetric(operation: "fetch_db", entityName: entityName, duration: duration)
                    
                    continuation.resume(returning: .success(results))
                } catch {
                    continuation.resume(returning: .failure(error))
                }
            }
        }
    }
    
    /// 分页查询
    func fetchPaginated<T: NSManagedObject>(
        entityType: T.Type,
        predicate: NSPredicate? = nil,
        sortDescriptors: [NSSortDescriptor] = [],
        offset: Int = 0,
        limit: Int = 50
    ) async -> Result<PaginatedResult<T>, Error> {
        let startTime = CFAbsoluteTimeGetCurrent()
        let entityName = String(describing: entityType)
        
        return await withCheckedContinuation { continuation in
            backgroundContext.perform {
                // 获取总数
                let countRequest = NSFetchRequest<T>(entityName: entityName)
                countRequest.predicate = predicate
                
                do {
                    let totalCount = try self.backgroundContext.count(for: countRequest)
                    
                    // 获取分页数据
                    let dataRequest = NSFetchRequest<T>(entityName: entityName)
                    dataRequest.predicate = predicate
                    dataRequest.sortDescriptors = sortDescriptors
                    dataRequest.fetchOffset = offset
                    dataRequest.fetchLimit = limit
                    dataRequest.returnsObjectsAsFaults = false
                    
                    let results = try self.backgroundContext.fetch(dataRequest)
                    
                    let paginatedResult = PaginatedResult(
                        items: results,
                        totalCount: totalCount,
                        offset: offset,
                        limit: limit
                    )
                    
                    let duration = CFAbsoluteTimeGetCurrent() - startTime
                    self.recordPerformanceMetric(operation: "fetch_paginated", entityName: entityName, duration: duration)
                    
                    continuation.resume(returning: .success(paginatedResult))
                } catch {
                    continuation.resume(returning: .failure(error))
                }
            }
        }
    }
    
    /// 预取关联数据
    func fetchWithPrefetch<T: NSManagedObject>(
        entityType: T.Type,
        predicate: NSPredicate? = nil,
        sortDescriptors: [NSSortDescriptor] = [],
        relationshipKeyPaths: [String] = []
    ) async -> Result<[T], Error> {
        let startTime = CFAbsoluteTimeGetCurrent()
        let entityName = String(describing: entityType)
        
        return await withCheckedContinuation { continuation in
            backgroundContext.perform {
                let request = NSFetchRequest<T>(entityName: entityName)
                request.predicate = predicate
                request.sortDescriptors = sortDescriptors
                request.relationshipKeyPathsForPrefetching = relationshipKeyPaths
                request.returnsObjectsAsFaults = false
                
                do {
                    let results = try self.backgroundContext.fetch(request)
                    
                    let duration = CFAbsoluteTimeGetCurrent() - startTime
                    self.recordPerformanceMetric(operation: "fetch_prefetch", entityName: entityName, duration: duration)
                    
                    continuation.resume(returning: .success(results))
                } catch {
                    continuation.resume(returning: .failure(error))
                }
            }
        }
    }
    
    // MARK: - 批量操作
    
    /// 批量插入
    func batchInsert<T: NSManagedObject>(
        entityType: T.Type,
        data: [[String: Any]]
    ) async -> Result<Int, Error> {
        let startTime = CFAbsoluteTimeGetCurrent()
        let entityName = String(describing: entityType)
        
        return await withCheckedContinuation { continuation in
            backgroundContext.perform {
                let batchInsertRequest = NSBatchInsertRequest(
                    entityName: entityName,
                    objects: data
                )
                batchInsertRequest.resultType = .count
                
                do {
                    let result = try self.backgroundContext.execute(batchInsertRequest) as! NSBatchInsertResult
                    let insertedCount = result.result as! Int
                    
                    // 清除相关缓存
                    self.invalidateCache(for: entityName)
                    
                    let duration = CFAbsoluteTimeGetCurrent() - startTime
                    self.recordPerformanceMetric(operation: "batch_insert", entityName: entityName, duration: duration)
                    
                    continuation.resume(returning: .success(insertedCount))
                } catch {
                    continuation.resume(returning: .failure(error))
                }
            }
        }
    }
    
    /// 批量更新
    func batchUpdate<T: NSManagedObject>(
        entityType: T.Type,
        predicate: NSPredicate,
        propertiesToUpdate: [String: Any]
    ) async -> Result<Int, Error> {
        let startTime = CFAbsoluteTimeGetCurrent()
        let entityName = String(describing: entityType)
        
        return await withCheckedContinuation { continuation in
            backgroundContext.perform {
                let batchUpdateRequest = NSBatchUpdateRequest(entityName: entityName)
                batchUpdateRequest.predicate = predicate
                batchUpdateRequest.propertiesToUpdate = propertiesToUpdate
                batchUpdateRequest.resultType = .updatedObjectsCountResultType
                
                do {
                    let result = try self.backgroundContext.execute(batchUpdateRequest) as! NSBatchUpdateResult
                    let updatedCount = result.result as! Int
                    
                    // 清除相关缓存
                    self.invalidateCache(for: entityName)
                    
                    let duration = CFAbsoluteTimeGetCurrent() - startTime
                    self.recordPerformanceMetric(operation: "batch_update", entityName: entityName, duration: duration)
                    
                    continuation.resume(returning: .success(updatedCount))
                } catch {
                    continuation.resume(returning: .failure(error))
                }
            }
        }
    }
    
    /// 批量删除
    func batchDelete<T: NSManagedObject>(
        entityType: T.Type,
        predicate: NSPredicate
    ) async -> Result<Int, Error> {
        let startTime = CFAbsoluteTimeGetCurrent()
        let entityName = String(describing: entityType)
        
        return await withCheckedContinuation { continuation in
            backgroundContext.perform {
                let batchDeleteRequest = NSBatchDeleteRequest(
                    fetchRequest: NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
                )
                batchDeleteRequest.fetchRequest.predicate = predicate
                batchDeleteRequest.resultType = .resultTypeCount
                
                do {
                    let result = try self.backgroundContext.execute(batchDeleteRequest) as! NSBatchDeleteResult
                    let deletedCount = result.result as! Int
                    
                    // 清除相关缓存
                    self.invalidateCache(for: entityName)
                    
                    let duration = CFAbsoluteTimeGetCurrent() - startTime
                    self.recordPerformanceMetric(operation: "batch_delete", entityName: entityName, duration: duration)
                    
                    continuation.resume(returning: .success(deletedCount))
                } catch {
                    continuation.resume(returning: .failure(error))
                }
            }
        }
    }
    
    // MARK: - 私有方法
    
    private func setupCache() {
        cache.countLimit = configuration.maxCacheSize
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB
    }
    
    private func setupMemoryPressureHandling() {
        if configuration.enableMemoryPressureEviction {
            #if os(iOS)
            NotificationCenter.default.addObserver(
                forName: UIApplication.didReceiveMemoryWarningNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.cache.removeAllObjects()
            }
            #else
            // macOS 内存压力处理
            NotificationCenter.default.addObserver(
                forName: .NSApplicationDidReceiveMemoryWarning,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.cache.removeAllObjects()
            }
            #endif
        }
    }
    
    private func generateCacheKey(
        entityName: String,
        predicate: NSPredicate?,
        sortDescriptors: [NSSortDescriptor]
    ) -> String {
        var key = entityName
        
        if let predicate = predicate {
            key += "_\(predicate.predicateFormat.hashValue)"
        }
        
        if !sortDescriptors.isEmpty {
            let sortKey = sortDescriptors.map { "\($0.key ?? "")_\($0.ascending)" }.joined(separator: "_")
            key += "_\(sortKey.hashValue)"
        }
        
        return key
    }
    
    private func getCachedResult(for key: String) -> Any? {
        return cache.object(forKey: key as NSString)
    }
    
    private func setCachedResult(_ result: Any, for key: String) {
        cache.setObject(result as AnyObject, forKey: key as NSString)
    }
    
    private func invalidateCache(for entityName: String) {
        // 简单实现：清除所有缓存
        // 更复杂的实现可以只清除相关的缓存条目
        cache.removeAllObjects()
    }
    
    private func recordPerformanceMetric(operation: String, entityName: String, duration: TimeInterval) {
        performanceMonitor?.recordDatabaseOperation(
            operation: operation,
            entityName: entityName,
            duration: duration
        )
    }
}

// MARK: - 分页结果
struct PaginatedResult<T> {
    let items: [T]
    let totalCount: Int
    let offset: Int
    let limit: Int
    
    var hasMore: Bool {
        return offset + items.count < totalCount
    }
    
    var currentPage: Int {
        return offset / limit + 1
    }
    
    var totalPages: Int {
        return (totalCount + limit - 1) / limit
    }
}
