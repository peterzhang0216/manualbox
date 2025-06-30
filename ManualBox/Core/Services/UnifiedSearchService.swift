import Foundation
import CoreData
import Combine
import SwiftUI

// MARK: - 统一搜索服务
/// 整合所有搜索功能的统一服务，替代ManualSearchService和EnhancedProductSearchService
@MainActor
class UnifiedSearchService: ObservableObject {
    nonisolated static let shared = UnifiedSearchService()
    
    // MARK: - 发布的状态
    @Published var isSearching = false
    @Published var searchResults: [UnifiedSearchResult] = []
    @Published var searchSuggestions: [SearchSuggestion] = []
    @Published var searchHistory: [String] = []
    @Published var savedSearches: [SavedSearch] = []
    
    // MARK: - 私有属性
    private let viewContext: NSManagedObjectContext
    private let searchQueue = DispatchQueue(label: "unified.search", qos: .userInitiated)
    private var searchCancellable: AnyCancellable?
    private let searchSubject = PassthroughSubject<String, Never>()
    
    // 搜索索引缓存
    private var searchIndex: [String: Set<UUID>] = [:]
    private var lastIndexUpdate = Date.distantPast
    private let indexUpdateInterval: TimeInterval = 300 // 5分钟
    
    // MARK: - 初始化
    nonisolated private init() {
        self.viewContext = PersistenceController.shared.container.viewContext
        setupSearchDebouncing()
        loadSearchHistory()
    }
    
    // MARK: - 主要搜索方法
    
    /// 统一搜索入口 - 支持产品和说明书搜索
    func search(
        query: String,
        scope: SearchScope = .all,
        filters: UnifiedSearchFilters = UnifiedSearchFilters(),
        configuration: UnifiedSearchConfiguration = .default
    ) async -> [UnifiedSearchResult] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            await MainActor.run {
                self.searchResults = []
                self.isSearching = false
            }
            return []
        }
        
        await MainActor.run {
            self.isSearching = true
        }
        
        let results = await performUnifiedSearch(
            query: query,
            scope: scope,
            filters: filters,
            configuration: configuration
        )
        
        await MainActor.run {
            self.searchResults = results
            self.isSearching = false
            self.addToSearchHistory(query)
        }
        
        return results
    }
    
    /// 防抖搜索
    func debouncedSearch(
        query: String,
        scope: SearchScope = .all,
        filters: UnifiedSearchFilters = UnifiedSearchFilters()
    ) -> AnyPublisher<[UnifiedSearchResult], Never> {
        searchSubject
            .debounce(for: .seconds(0.3), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .flatMap { [weak self] searchQuery -> AnyPublisher<[UnifiedSearchResult], Never> in
                guard let self = self else {
                    return Just([]).eraseToAnyPublisher()
                }
                
                return Future { promise in
                    Task {
                        let results = await self.search(query: searchQuery, scope: scope, filters: filters)
                        promise(.success(results))
                    }
                }
                .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
    func triggerSearch(_ query: String) {
        searchSubject.send(query)
    }
    
    /// 获取搜索建议
    func getSearchSuggestions(for query: String, scope: SearchScope = .all) async -> [SearchSuggestion] {
        guard query.count >= 2 else { return [] }
        
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                var suggestions: [SearchSuggestion] = []
                
                switch scope {
                case .products, .all:
                    suggestions.append(contentsOf: self.getProductSuggestions(for: query))
                case .manuals, .all:
                    suggestions.append(contentsOf: self.getManualSuggestions(for: query))
                case .categories:
                    suggestions.append(contentsOf: self.getCategorySuggestions(for: query))
                case .tags:
                    suggestions.append(contentsOf: self.getTagSuggestions(for: query))
                }
                
                // 添加历史搜索建议
                let historyMatches = self.searchHistory.filter { 
                    $0.lowercased().contains(query.lowercased()) 
                }.prefix(3)
                
                for history in historyMatches {
                    suggestions.append(SearchSuggestion(
                        text: history,
                        type: .history,
                        score: 0.5
                    ))
                }
                
                // 按评分排序并限制数量
                let sortedSuggestions = suggestions
                    .sorted { $0.score > $1.score }
                    .prefix(10)
                
                continuation.resume(returning: Array(sortedSuggestions))
            }
        }
    }
    
    // MARK: - 私有搜索实现
    
    private func performUnifiedSearch(
        query: String,
        scope: SearchScope,
        filters: UnifiedSearchFilters,
        configuration: UnifiedSearchConfiguration
    ) async -> [UnifiedSearchResult] {
        
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                var allResults: [UnifiedSearchResult] = []
                
                // 根据搜索范围执行不同的搜索
                switch scope {
                case .products:
                    allResults = self.searchProducts(query: query, filters: filters, configuration: configuration)
                case .manuals:
                    allResults = self.searchManuals(query: query, filters: filters, configuration: configuration)
                case .categories:
                    allResults = self.searchCategories(query: query, filters: filters, configuration: configuration)
                case .tags:
                    allResults = self.searchTags(query: query, filters: filters, configuration: configuration)
                case .all:
                    // 搜索所有类型并合并结果
                    allResults.append(contentsOf: self.searchProducts(query: query, filters: filters, configuration: configuration))
                    allResults.append(contentsOf: self.searchManuals(query: query, filters: filters, configuration: configuration))
                    allResults.append(contentsOf: self.searchCategories(query: query, filters: filters, configuration: configuration))
                    allResults.append(contentsOf: self.searchTags(query: query, filters: filters, configuration: configuration))
                }
                
                // 按相关性评分排序
                let sortedResults = allResults
                    .filter { $0.relevanceScore >= configuration.minRelevanceScore }
                    .sorted { $0.relevanceScore > $1.relevanceScore }
                    .prefix(configuration.maxResults)
                
                continuation.resume(returning: Array(sortedResults))
            }
        }
    }
    
    // MARK: - 具体搜索实现
    
    private func searchProducts(
        query: String,
        filters: UnifiedSearchFilters,
        configuration: UnifiedSearchConfiguration
    ) -> [UnifiedSearchResult] {
        let request: NSFetchRequest<Product> = Product.fetchRequest()
        
        // 构建产品搜索谓词
        var predicates: [NSPredicate] = []
        
        // 基础文本搜索
        let textPredicates = [
            NSPredicate(format: "name CONTAINS[cd] %@", query),
            NSPredicate(format: "brand CONTAINS[cd] %@", query),
            NSPredicate(format: "model CONTAINS[cd] %@", query),
            NSPredicate(format: "notes CONTAINS[cd] %@", query)
        ]
        predicates.append(NSCompoundPredicate(orPredicateWithSubpredicates: textPredicates))
        
        // 应用过滤器
        if let category = filters.category {
            predicates.append(NSPredicate(format: "category == %@", category))
        }
        
        if !filters.tags.isEmpty {
            predicates.append(NSPredicate(format: "ANY tags IN %@", filters.tags))
        }
        
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Product.updatedAt, ascending: false)]
        request.fetchLimit = configuration.maxResults
        
        do {
            let products = try viewContext.fetch(request)
            return products.map { product in
                let relevanceScore = calculateProductRelevanceScore(product: product, query: query)
                return UnifiedSearchResult(
                    type: .product,
                    entity: product,
                    title: product.name ?? "未命名产品",
                    subtitle: [product.brand, product.model].compactMap { $0 }.joined(separator: " "),
                    relevanceScore: relevanceScore,
                    highlights: generateProductHighlights(product: product, query: query)
                )
            }
        } catch {
            print("产品搜索失败: \(error.localizedDescription)")
            return []
        }
    }
    
    private func searchManuals(
        query: String,
        filters: UnifiedSearchFilters,
        configuration: UnifiedSearchConfiguration
    ) -> [UnifiedSearchResult] {
        let request: NSFetchRequest<Manual> = Manual.fetchRequest()
        
        // 构建说明书搜索谓词
        var predicates: [NSPredicate] = []
        
        let textPredicates = [
            NSPredicate(format: "fileName CONTAINS[cd] %@", query),
            NSPredicate(format: "content CONTAINS[cd] %@", query),
            NSPredicate(format: "product.name CONTAINS[cd] %@", query)
        ]
        predicates.append(NSCompoundPredicate(orPredicateWithSubpredicates: textPredicates))
        
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Manual.fileName, ascending: true)]
        request.fetchLimit = configuration.maxResults
        
        do {
            let manuals = try viewContext.fetch(request)
            return manuals.map { manual in
                let relevanceScore = calculateManualRelevanceScore(manual: manual, query: query)
                return UnifiedSearchResult(
                    type: .manual,
                    entity: manual,
                    title: manual.fileName ?? "未命名说明书",
                    subtitle: manual.product?.name ?? "无关联产品",
                    relevanceScore: relevanceScore,
                    highlights: generateManualHighlights(manual: manual, query: query)
                )
            }
        } catch {
            print("说明书搜索失败: \(error.localizedDescription)")
            return []
        }
    }
    
    private func searchCategories(
        query: String,
        filters: UnifiedSearchFilters,
        configuration: UnifiedSearchConfiguration
    ) -> [UnifiedSearchResult] {
        let request: NSFetchRequest<Category> = Category.fetchRequest()
        request.predicate = NSPredicate(format: "name CONTAINS[cd] %@", query)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Category.name, ascending: true)]
        
        do {
            let categories = try viewContext.fetch(request)
            return categories.map { category in
                UnifiedSearchResult(
                    type: .category,
                    entity: category,
                    title: category.categoryName,
                    subtitle: "分类",
                    relevanceScore: query.lowercased() == category.name?.lowercased() ? 1.0 : 0.8,
                    highlights: []
                )
            }
        } catch {
            print("分类搜索失败: \(error.localizedDescription)")
            return []
        }
    }
    
    private func searchTags(
        query: String,
        filters: UnifiedSearchFilters,
        configuration: UnifiedSearchConfiguration
    ) -> [UnifiedSearchResult] {
        let request: NSFetchRequest<Tag> = Tag.fetchRequest()
        request.predicate = NSPredicate(format: "name CONTAINS[cd] %@", query)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Tag.name, ascending: true)]
        
        do {
            let tags = try viewContext.fetch(request)
            return tags.map { tag in
                UnifiedSearchResult(
                    type: .tag,
                    entity: tag,
                    title: tag.tagName,
                    subtitle: "标签",
                    relevanceScore: query.lowercased() == tag.name?.lowercased() ? 1.0 : 0.8,
                    highlights: []
                )
            }
        } catch {
            print("标签搜索失败: \(error.localizedDescription)")
            return []
        }
    }
    
    // MARK: - 辅助方法
    
    private func setupSearchDebouncing() {
        searchCancellable = searchSubject
            .debounce(for: .seconds(0.3), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] query in
                Task {
                    await self?.search(query: query)
                }
            }
    }
    
    private func loadSearchHistory() {
        searchHistory = UserDefaults.standard.stringArray(forKey: "searchHistory") ?? []
    }
    
    private func addToSearchHistory(_ query: String) {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return }
        
        // 移除重复项并添加到开头
        searchHistory.removeAll { $0 == trimmedQuery }
        searchHistory.insert(trimmedQuery, at: 0)
        
        // 限制历史记录数量
        if searchHistory.count > 20 {
            searchHistory = Array(searchHistory.prefix(20))
        }
        
        // 保存到UserDefaults
        UserDefaults.standard.set(searchHistory, forKey: "searchHistory")
    }

    // MARK: - 相关性评分计算

    private func calculateProductRelevanceScore(product: Product, query: String) -> Double {
        var score: Double = 0.0
        let keywords = query.lowercased().components(separatedBy: .whitespacesAndNewlines)

        for keyword in keywords {
            // 产品名称匹配 (权重: 1.0)
            if let name = product.name?.lowercased(), name.contains(keyword) {
                score += name == keyword ? 1.0 : 0.8
            }

            // 品牌匹配 (权重: 0.7)
            if let brand = product.brand?.lowercased(), brand.contains(keyword) {
                score += brand == keyword ? 0.7 : 0.5
            }

            // 型号匹配 (权重: 0.6)
            if let model = product.model?.lowercased(), model.contains(keyword) {
                score += model == keyword ? 0.6 : 0.4
            }

            // 备注匹配 (权重: 0.3)
            if let notes = product.notes?.lowercased(), notes.contains(keyword) {
                score += 0.3
            }
        }

        return min(score, 1.0)
    }

    private func calculateManualRelevanceScore(manual: Manual, query: String) -> Double {
        var score: Double = 0.0
        let keywords = query.lowercased().components(separatedBy: .whitespacesAndNewlines)

        for keyword in keywords {
            // 文件名匹配 (权重: 0.8)
            if let fileName = manual.fileName?.lowercased(), fileName.contains(keyword) {
                score += fileName == keyword ? 0.8 : 0.6
            }

            // 内容匹配 (权重: 0.9)
            if let content = manual.content?.lowercased(), content.contains(keyword) {
                score += 0.9
            }

            // 关联产品名称匹配 (权重: 0.7)
            if let productName = manual.product?.name?.lowercased(), productName.contains(keyword) {
                score += 0.7
            }
        }

        return min(score, 1.0)
    }

    // MARK: - 高亮生成

    private func generateProductHighlights(product: Product, query: String) -> [String] {
        var highlights: [String] = []
        let keywords = query.lowercased().components(separatedBy: .whitespacesAndNewlines)

        for keyword in keywords {
            if let name = product.name, name.lowercased().contains(keyword) {
                highlights.append("名称: \(name)")
            }
            if let brand = product.brand, brand.lowercased().contains(keyword) {
                highlights.append("品牌: \(brand)")
            }
            if let model = product.model, model.lowercased().contains(keyword) {
                highlights.append("型号: \(model)")
            }
        }

        return highlights
    }

    private func generateManualHighlights(manual: Manual, query: String) -> [String] {
        var highlights: [String] = []
        let keywords = query.lowercased().components(separatedBy: .whitespacesAndNewlines)

        for keyword in keywords {
            if let fileName = manual.fileName, fileName.lowercased().contains(keyword) {
                highlights.append("文件: \(fileName)")
            }
            if let content = manual.content, content.lowercased().contains(keyword) {
                // 提取包含关键词的片段
                let snippet = extractSnippet(from: content, keyword: keyword)
                highlights.append("内容: \(snippet)")
            }
        }

        return highlights
    }

    private func extractSnippet(from text: String, keyword: String, contextLength: Int = 50) -> String {
        let lowercasedText = text.lowercased()
        let lowercasedKeyword = keyword.lowercased()

        guard let range = lowercasedText.range(of: lowercasedKeyword) else {
            return String(text.prefix(contextLength))
        }

        let startIndex = max(text.startIndex, text.index(range.lowerBound, offsetBy: -contextLength, limitedBy: text.startIndex) ?? text.startIndex)
        let endIndex = min(text.endIndex, text.index(range.upperBound, offsetBy: contextLength, limitedBy: text.endIndex) ?? text.endIndex)

        return String(text[startIndex..<endIndex])
    }

    // MARK: - 搜索建议生成

    private func getProductSuggestions(for query: String) -> [SearchSuggestion] {
        let request: NSFetchRequest<Product> = Product.fetchRequest()
        request.predicate = NSPredicate(format: "name CONTAINS[cd] %@ OR brand CONTAINS[cd] %@", query, query)
        request.fetchLimit = 5

        do {
            let products = try viewContext.fetch(request)
            return products.compactMap { product in
                if let name = product.name {
                    return SearchSuggestion(text: name, type: .product, score: 0.8)
                }
                return nil
            }
        } catch {
            return []
        }
    }

    private func getManualSuggestions(for query: String) -> [SearchSuggestion] {
        let request: NSFetchRequest<Manual> = Manual.fetchRequest()
        request.predicate = NSPredicate(format: "fileName CONTAINS[cd] %@", query)
        request.fetchLimit = 5

        do {
            let manuals = try viewContext.fetch(request)
            return manuals.compactMap { manual in
                if let fileName = manual.fileName {
                    return SearchSuggestion(text: fileName, type: .manual, score: 0.7)
                }
                return nil
            }
        } catch {
            return []
        }
    }

    private func getCategorySuggestions(for query: String) -> [SearchSuggestion] {
        let request: NSFetchRequest<Category> = Category.fetchRequest()
        request.predicate = NSPredicate(format: "name CONTAINS[cd] %@", query)
        request.fetchLimit = 3

        do {
            let categories = try viewContext.fetch(request)
            return categories.compactMap { category in
                if let name = category.name {
                    return SearchSuggestion(text: name, type: .category, score: 0.6)
                }
                return nil
            }
        } catch {
            return []
        }
    }

    private func getTagSuggestions(for query: String) -> [SearchSuggestion] {
        let request: NSFetchRequest<Tag> = Tag.fetchRequest()
        request.predicate = NSPredicate(format: "name CONTAINS[cd] %@", query)
        request.fetchLimit = 3

        do {
            let tags = try viewContext.fetch(request)
            return tags.compactMap { tag in
                if let name = tag.name {
                    return SearchSuggestion(text: name, type: .tag, score: 0.5)
                }
                return nil
            }
        } catch {
            return []
        }
    }
}
