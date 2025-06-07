import Foundation
import CoreData
import Combine

// MARK: - 数据访问层基础协议
protocol DataAccessProtocol {
    associatedtype Entity: NSManagedObject
    associatedtype EntityID: Hashable
    
    func fetchAll() async throws -> [Entity]
    func fetchBy(id: EntityID) async throws -> Entity?
    func create() -> Entity
    func save() async throws
    func delete(_ entity: Entity) async throws
    func count() async throws -> Int
}

// MARK: - 查询构建器协议
protocol QueryBuilderProtocol {
    associatedtype Entity: NSManagedObject
    
    func predicate(_ predicate: NSPredicate) -> Self
    func sortDescriptor(_ descriptor: NSSortDescriptor) -> Self
    func sortDescriptors(_ descriptors: [NSSortDescriptor]) -> Self
    func limit(_ limit: Int) -> Self
    func offset(_ offset: Int) -> Self
    func build() -> NSFetchRequest<Entity>
}

// MARK: - Repository 基础协议
protocol RepositoryProtocol: DataAccessProtocol {
    func search(_ query: String) async throws -> [Entity]
    func fetchWithFilters(_ filters: [NSPredicate]) async throws -> [Entity]
    func batchUpdate(_ updates: [EntityID: [String: Any]]) async throws
    func batchDelete(_ ids: [EntityID]) async throws
}

// MARK: - 响应式数据访问协议
protocol ReactiveDataAccessProtocol: DataAccessProtocol {
    func publisher() -> AnyPublisher<[Entity], Error>
    func publisher(for id: EntityID) -> AnyPublisher<Entity?, Error>
    func countPublisher() -> AnyPublisher<Int, Error>
}

// MARK: - 缓存协议
protocol CacheProtocol {
    associatedtype Key: Hashable
    associatedtype Value
    
    func get(_ key: Key) -> Value?
    func set(_ key: Key, value: Value)
    func remove(_ key: Key)
    func removeAll()
    func size() -> Int
}

// MARK: - 数据同步协议
protocol DataSyncProtocol {
    func sync() async throws
    func forcePull() async throws
    func forcePush() async throws
    func conflictResolution(_ conflicts: [Any]) async throws
}