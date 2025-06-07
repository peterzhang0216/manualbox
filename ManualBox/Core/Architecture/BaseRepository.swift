import Foundation
import CoreData
import Combine

// MARK: - 基础Repository实现
class BaseRepository<Entity: NSManagedObject>: RepositoryProtocol {
    typealias EntityID = UUID
    
    internal let context: NSManagedObjectContext
    internal let entityName: String
    internal let cache: MemoryCache<UUID, Entity>
    internal let performanceMonitor: PlatformPerformanceManager?
    
    // 发布者用于响应式编程
    private let entitiesSubject = CurrentValueSubject<[Entity], Error>([])
    private var cancellables = Set<AnyCancellable>()
    
    init(context: NSManagedObjectContext, entityName: String) {
        self.context = context
        self.entityName = entityName
        self.cache = MemoryCache<UUID, Entity>(maxSize: 100)
        self.performanceMonitor = ServiceContainer.shared.resolve(PlatformPerformanceManager.self)
        
        setupNotifications()
    }
    
    // MARK: - DataAccessProtocol Implementation
    
    func fetchAll() async throws -> [Entity] {
        let startTime = CFAbsoluteTimeGetCurrent()
        defer {
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            performanceMonitor?.recordDatabaseOperation(
                operation: "fetchAll",
                entityName: entityName,
                duration: duration
            )
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let request = NSFetchRequest<Entity>(entityName: self.entityName)
                    let results = try self.context.fetch(request)
                    
                    // 更新缓存
                    results.forEach { entity in
                        if let id = entity.value(forKey: "id") as? UUID {
                            self.cache.set(id, value: entity)
                        }
                    }
                    
                    continuation.resume(returning: results)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func fetchBy(id: UUID) async throws -> Entity? {
        // 先检查缓存
        if let cached = cache.get(id) {
            return cached
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let request = NSFetchRequest<Entity>(entityName: self.entityName)
                    request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
                    request.fetchLimit = 1
                    
                    let results = try self.context.fetch(request)
                    let entity = results.first
                    
                    // 更新缓存
                    if let entity = entity {
                        self.cache.set(id, value: entity)
                    }
                    
                    continuation.resume(returning: entity)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func create() -> Entity {
        let entity = NSEntityDescription.insertNewObject(forEntityName: entityName, into: context) as! Entity
        
        // 为新实体设置ID
        if entity.entity.attributesByName["id"] != nil {
            entity.setValue(UUID(), forKey: "id")
        }
        
        return entity
    }
    
    func save() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            context.perform {
                guard self.context.hasChanges else {
                    continuation.resume()
                    return
                }
                
                do {
                    try self.context.save()
                    
                    // 清理缓存中已删除的对象
                    self.cleanupDeletedObjectsFromCache()
                    
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func delete(_ entity: Entity) async throws {
        let id = entity.value(forKey: "id") as? UUID
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            context.perform {
                self.context.delete(entity)
                
                // 从缓存中移除
                if let id = id {
                    self.cache.remove(id)
                }
                
                do {
                    try self.context.save()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func count() async throws -> Int {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let request = NSFetchRequest<Entity>(entityName: self.entityName)
                    let count = try self.context.count(for: request)
                    continuation.resume(returning: count)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - RepositoryProtocol Implementation
    
    func search(_ query: String) async throws -> [Entity] {
        // 子类应该重写此方法以提供特定的搜索逻辑
        return try await fetchAll()
    }
    
    func fetchWithFilters(_ filters: [NSPredicate]) async throws -> [Entity] {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let request = NSFetchRequest<Entity>(entityName: self.entityName)
                    request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: filters)
                    
                    let results = try self.context.fetch(request)
                    continuation.resume(returning: results)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func batchUpdate(_ updates: [UUID: [String: Any]]) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            context.perform {
                do {
                    for (id, properties) in updates {
                        let request = NSFetchRequest<Entity>(entityName: self.entityName)
                        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
                        
                        if let entity = try self.context.fetch(request).first {
                            for (key, value) in properties {
                                entity.setValue(value, forKey: key)
                            }
                            
                            // 更新缓存
                            self.cache.set(id, value: entity)
                        }
                    }
                    
                    try self.context.save()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func batchDelete(_ ids: [UUID]) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            context.perform {
                do {
                    let request = NSFetchRequest<NSFetchRequestResult>(entityName: self.entityName)
                    request.predicate = NSPredicate(format: "id IN %@", ids)
                    
                    let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
                    try self.context.execute(deleteRequest)
                    
                    // 从缓存中批量移除
                    ids.forEach { self.cache.remove($0) }
                    
                    try self.context.save()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - 私有方法
    
    private func setupNotifications() {
        NotificationCenter.default.publisher(for: .NSManagedObjectContextObjectsDidChange, object: context)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.refreshData()
                }
            }
            .store(in: &cancellables)
    }
    
    private func cleanupDeletedObjectsFromCache() {
        // 清理缓存中已被删除的对象
        let deletedObjects = context.deletedObjects
        for object in deletedObjects {
            if let entity = object as? Entity,
               let id = entity.value(forKey: "id") as? UUID {
                cache.remove(id)
            }
        }
    }
    
    @MainActor
    private func refreshData() async {
        do {
            let entities = try await fetchAll()
            entitiesSubject.send(entities)
        } catch {
            entitiesSubject.send(completion: .failure(error))
        }
    }
}

// MARK: - 内存缓存实现
class MemoryCache<Key: Hashable, Value>: CacheProtocol {
    private var cache: [Key: CacheItem<Value>] = [:]
    private let maxSize: Int
    private let ttl: TimeInterval
    private let queue = DispatchQueue(label: "memory.cache.queue", attributes: .concurrent)
    
    private struct CacheItem<T> {
        let value: T
        let timestamp: Date
        
        func isExpired(ttl: TimeInterval) -> Bool {
            Date().timeIntervalSince(timestamp) > ttl
        }
    }
    
    init(maxSize: Int = 100, ttl: TimeInterval = 300) { // 5分钟TTL
        self.maxSize = maxSize
        self.ttl = ttl
    }
    
    func get(_ key: Key) -> Value? {
        return queue.sync {
            guard let item = cache[key] else { return nil }
            
            if item.isExpired(ttl: ttl) {
                cache.removeValue(forKey: key)
                return nil
            }
            
            return item.value
        }
    }
    
    func set(_ key: Key, value: Value) {
        queue.async(flags: .barrier) {
            // 如果缓存已满，移除最旧的项目
            if self.cache.count >= self.maxSize {
                self.evictOldestItem()
            }
            
            self.cache[key] = CacheItem(value: value, timestamp: Date())
        }
    }
    
    func remove(_ key: Key) {
        queue.async(flags: .barrier) {
            self.cache.removeValue(forKey: key)
        }
    }
    
    func removeAll() {
        queue.async(flags: .barrier) {
            self.cache.removeAll()
        }
    }
    
    func size() -> Int {
        return queue.sync {
            cache.count
        }
    }
    
    private func evictOldestItem() {
        guard !cache.isEmpty else { return }
        
        let oldestKey = cache.min { $0.value.timestamp < $1.value.timestamp }?.key
        if let key = oldestKey {
            cache.removeValue(forKey: key)
        }
    }
}

// MARK: - 响应式扩展
extension BaseRepository: ReactiveDataAccessProtocol {
    func publisher() -> AnyPublisher<[Entity], Error> {
        return entitiesSubject.eraseToAnyPublisher()
    }
    
    func publisher(for id: UUID) -> AnyPublisher<Entity?, Error> {
        return entitiesSubject
            .map { entities in
                entities.first { entity in
                    (entity.value(forKey: "id") as? UUID) == id
                }
            }
            .eraseToAnyPublisher()
    }
    
    func countPublisher() -> AnyPublisher<Int, Error> {
        return entitiesSubject
            .map { $0.count }
            .eraseToAnyPublisher()
    }
}