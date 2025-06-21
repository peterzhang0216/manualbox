import Foundation
import CoreData
import Combine

// MARK: - 通用搜索配置
struct UniversalSearchConfiguration {
    let caseSensitive: Bool
    let matchMode: MatchMode
    let sortDescriptors: [NSSortDescriptor]
    let fetchLimit: Int?
    let debounceInterval: TimeInterval

    enum MatchMode {
        case contains
        case beginsWith
        case endsWith
        case exact
        case fuzzy
    }

    static let `default` = UniversalSearchConfiguration(
        caseSensitive: false,
        matchMode: .contains,
        sortDescriptors: [],
        fetchLimit: nil,
        debounceInterval: 0.3
    )
}

// MARK: - 搜索字段配置
struct SearchField {
    let keyPath: String
    let weight: Double
    let isRequired: Bool
    
    init(keyPath: String, weight: Double = 1.0, isRequired: Bool = false) {
        self.keyPath = keyPath
        self.weight = weight
        self.isRequired = isRequired
    }
}

// MARK: - 搜索结果
struct SearchResult<T> {
    let items: [T]
    let totalCount: Int
    let searchTerm: String
    let executionTime: TimeInterval
    
    var isEmpty: Bool {
        return items.isEmpty
    }
}

// MARK: - 通用搜索服务
class UniversalSearchService<T: NSManagedObject> {
    private let context: NSManagedObjectContext
    private let entityName: String
    private let configuration: UniversalSearchConfiguration
    private let searchFields: [SearchField]
    
    // 搜索防抖
    private var searchCancellable: AnyCancellable?
    private let searchSubject = PassthroughSubject<String, Never>()
    
    init(
        context: NSManagedObjectContext,
        entityType: T.Type,
        searchFields: [SearchField],
        configuration: UniversalSearchConfiguration = .default
    ) {
        self.context = context
        self.entityName = String(describing: entityType)
        self.searchFields = searchFields
        self.configuration = configuration
    }
    
    // MARK: - 搜索方法
    
    /// 执行搜索
    func search(_ query: String, additionalPredicate: NSPredicate? = nil) async -> SearchResult<T> {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        return await withCheckedContinuation { continuation in
            context.perform {
                let request = NSFetchRequest<T>(entityName: self.entityName)
                
                // 构建搜索谓词
                let searchPredicate = self.buildSearchPredicate(for: query)
                
                // 组合额外的谓词
                if let additionalPredicate = additionalPredicate {
                    request.predicate = NSCompoundPredicate(
                        andPredicateWithSubpredicates: [searchPredicate, additionalPredicate]
                    )
                } else {
                    request.predicate = searchPredicate
                }
                
                // 设置排序
                request.sortDescriptors = self.configuration.sortDescriptors
                
                // 设置限制
                if let limit = self.configuration.fetchLimit {
                    request.fetchLimit = limit
                }
                
                do {
                    let results = try self.context.fetch(request)
                    let executionTime = CFAbsoluteTimeGetCurrent() - startTime
                    
                    let searchResult = SearchResult(
                        items: results,
                        totalCount: results.count,
                        searchTerm: query,
                        executionTime: executionTime
                    )
                    
                    continuation.resume(returning: searchResult)
                } catch {
                    print("[UniversalSearch] 搜索失败: \(error.localizedDescription)")
                    let searchResult = SearchResult<T>(
                        items: [],
                        totalCount: 0,
                        searchTerm: query,
                        executionTime: CFAbsoluteTimeGetCurrent() - startTime
                    )
                    continuation.resume(returning: searchResult)
                }
            }
        }
    }
    
    /// 防抖搜索
    func debouncedSearch(_ query: String) -> AnyPublisher<SearchResult<T>, Never> {
        searchSubject
            .debounce(for: .seconds(configuration.debounceInterval), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .flatMap { [weak self] searchQuery -> AnyPublisher<SearchResult<T>, Never> in
                guard let self = self else {
                    return Just(SearchResult<T>(items: [], totalCount: 0, searchTerm: searchQuery, executionTime: 0))
                        .eraseToAnyPublisher()
                }
                
                return Future { promise in
                    Task {
                        let result = await self.search(searchQuery)
                        promise(.success(result))
                    }
                }
                .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
    func triggerSearch(_ query: String) {
        searchSubject.send(query)
    }
    
    // MARK: - 私有方法
    
    private func buildSearchPredicate(for query: String) -> NSPredicate {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedQuery.isEmpty else {
            return NSPredicate(value: true) // 返回所有结果
        }
        
        var predicates: [NSPredicate] = []
        
        for field in searchFields {
            let fieldPredicate = buildFieldPredicate(for: trimmedQuery, field: field)
            predicates.append(fieldPredicate)
        }
        
        return NSCompoundPredicate(orPredicateWithSubpredicates: predicates)
    }
    
    private func buildFieldPredicate(for query: String, field: SearchField) -> NSPredicate {
        let formatString: String
        let options: String = configuration.caseSensitive ? "" : "[cd]"
        
        switch configuration.matchMode {
        case .contains:
            formatString = "\(field.keyPath) CONTAINS\(options) %@"
        case .beginsWith:
            formatString = "\(field.keyPath) BEGINSWITH\(options) %@"
        case .endsWith:
            formatString = "\(field.keyPath) ENDSWITH\(options) %@"
        case .exact:
            formatString = "\(field.keyPath) =\(options) %@"
        case .fuzzy:
            formatString = "\(field.keyPath) LIKE\(options) %@"
        }
        
        let searchValue = configuration.matchMode == .fuzzy ? "*\(query)*" : query
        return NSPredicate(format: formatString, searchValue)
    }
}

// MARK: - 通用CRUD操作服务
class UniversalCRUDService<T: NSManagedObject> {
    private let context: NSManagedObjectContext
    private let entityName: String
    
    init(context: NSManagedObjectContext, entityType: T.Type) {
        self.context = context
        self.entityName = String(describing: entityType)
    }
    
    // MARK: - Create
    
    func create() -> T {
        let entity = NSEntityDescription.entity(forEntityName: entityName, in: context)!
        return T(entity: entity, insertInto: context)
    }
    
    func create(configure: @escaping (T) -> Void) async throws -> T {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                let item = self.create()
                configure(item)

                do {
                    try self.context.save()
                    continuation.resume(returning: item)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Read
    
    func fetchAll(predicate: NSPredicate? = nil, sortDescriptors: [NSSortDescriptor] = []) async throws -> [T] {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                let request = NSFetchRequest<T>(entityName: self.entityName)
                request.predicate = predicate
                request.sortDescriptors = sortDescriptors
                
                do {
                    let results = try self.context.fetch(request)
                    continuation.resume(returning: results)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func fetchFirst(predicate: NSPredicate) async throws -> T? {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                let request = NSFetchRequest<T>(entityName: self.entityName)
                request.predicate = predicate
                request.fetchLimit = 1
                
                do {
                    let results = try self.context.fetch(request)
                    continuation.resume(returning: results.first)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func count(predicate: NSPredicate? = nil) async throws -> Int {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                let request = NSFetchRequest<T>(entityName: self.entityName)
                request.predicate = predicate
                
                do {
                    let count = try self.context.count(for: request)
                    continuation.resume(returning: count)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Update
    
    func update(_ item: T, configure: @escaping (T) -> Void) async throws {
        try await withCheckedThrowingContinuation { continuation in
            context.perform {
                configure(item)

                do {
                    try self.context.save()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Delete
    
    func delete(_ item: T) async throws {
        try await withCheckedThrowingContinuation { continuation in
            context.perform {
                self.context.delete(item)
                
                do {
                    try self.context.save()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func deleteAll(predicate: NSPredicate? = nil) async throws -> Int {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                let request = NSFetchRequest<T>(entityName: self.entityName)
                request.predicate = predicate
                
                do {
                    let items = try self.context.fetch(request)
                    let count = items.count
                    
                    for item in items {
                        self.context.delete(item)
                    }
                    
                    try self.context.save()
                    continuation.resume(returning: count)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
