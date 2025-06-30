import Foundation
import CoreData
import Combine
import SwiftUI

// MARK: - 增强产品搜索服务 (重构后使用统一搜索)
class EnhancedProductSearchService: ObservableObject {
    static let shared = EnhancedProductSearchService()

    @Published var searchResults: [ProductSearchResult] = []
    @Published var isSearching = false
    @Published var searchSuggestions: [SearchSuggestion] = []
    @Published var searchHistory: [String] = []
    @Published var savedSearches: [SavedSearch] = []

    // 使用统一搜索服务
    @MainActor
    private let unifiedSearchService: UnifiedSearchService
    private let viewContext: NSManagedObjectContext
    private let context: NSManagedObjectContext
    private let searchQueue = DispatchQueue(label: "product.search", qos: .userInitiated)
    private var searchCancellable: AnyCancellable?
    
    private init() {
        self.viewContext = PersistenceController.shared.container.viewContext
        self.context = PersistenceController.shared.container.viewContext
        self.unifiedSearchService = UnifiedSearchService.shared
        loadSearchHistory()
        loadSavedSearches()
        // buildSearchIndex()
    }

    // MARK: - 主要搜索方法 (重构后使用统一搜索)

    /// 执行产品搜索
    func searchProducts(
        query: String,
        filters: ProductSearchFilters = ProductSearchFilters(),
        sortBy: ProductSearchSort = .relevance
    ) async -> [ProductSearchResult] {
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

        // 使用统一搜索服务进行搜索
        let unifiedFilters = convertToUnifiedFilters(filters)
        let unifiedResults = await unifiedSearchService.search(
            query: query,
            scope: .products,
            filters: unifiedFilters
        )

        // 转换为ProductSearchResult格式
        let results = convertToProductSearchResults(unifiedResults, sortBy: sortBy)

        await MainActor.run {
            self.searchResults = results
            self.isSearching = false
            self.addToSearchHistory(query)
        }

        return results
    }

    /// 获取搜索建议 (重构后使用统一搜索)
    func getSearchSuggestions(for query: String) async -> [SearchSuggestion] {
        guard query.count >= 2 else { return [] }

        // 使用统一搜索服务获取建议
        let unifiedSuggestions = await unifiedSearchService.getSearchSuggestions(for: query, scope: .products)

        // 直接返回统一搜索建议
        return unifiedSuggestions
    }

    // MARK: - 转换方法

    private func convertToUnifiedFilters(_ filters: ProductSearchFilters) -> UnifiedSearchFilters {
        // 根据categoryId查找Category对象
        var category: Category? = nil
        if let categoryId = filters.categoryId {
            let request: NSFetchRequest<Category> = Category.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", categoryId as CVarArg)
            category = try? context.fetch(request).first
        }

        // 根据tagIds查找Tag对象
        var tags: [Tag] = []
        if !filters.tagIds.isEmpty {
            let request: NSFetchRequest<Tag> = Tag.fetchRequest()
            request.predicate = NSPredicate(format: "id IN %@", filters.tagIds)
            tags = (try? context.fetch(request)) ?? []
        }

        // 构建日期范围
        var dateRange: UnifiedSearchFilters.DateRange? = nil
        if let startDate = filters.startDate, let endDate = filters.endDate {
            dateRange = UnifiedSearchFilters.DateRange(startDate: startDate, endDate: endDate)
        }

        return UnifiedSearchFilters(
            category: category,
            tags: tags,
            dateRange: dateRange
        )
    }

    private func convertToProductSearchResults(
        _ unifiedResults: [UnifiedSearchResult],
        sortBy: ProductSearchSort
    ) -> [ProductSearchResult] {
        let results = unifiedResults.compactMap { result -> ProductSearchResult? in
            guard result.type == .product,
                  let product = result.entity as? Product else {
                return nil
            }

            return ProductSearchResult(
                product: product,
                relevanceScore: Float(result.relevanceScore),
                highlights: result.highlights,
                matchedFields: [] // 可以从highlights推导
            )
        }

        // 根据排序方式重新排序
        switch sortBy {
        case .relevance:
            return results.sorted { $0.relevanceScore > $1.relevanceScore }
        case .name:
            return results.sorted { ($0.product.name ?? "") < ($1.product.name ?? "") }
        case .createdDate:
            return results.sorted { ($0.product.createdAt ?? Date.distantPast) > ($1.product.createdAt ?? Date.distantPast) }
        case .updatedDate:
            return results.sorted { ($0.product.updatedAt ?? Date.distantPast) > ($1.product.updatedAt ?? Date.distantPast) }
        case .price:
            // Implement price sorting logic here
            return results
        }
    }

    /// 保存搜索
    func saveSearch(query: String, filters: ProductSearchFilters, name: String) {
        // 转换过滤器格式
        let savedFilters = SavedSearch.SavedSearchFilters(
            categoryName: nil, // 这里需要根据categoryId查找名称
            tagNames: [], // 这里需要根据tagIds查找名称
            dateRange: nil,
            fileTypes: []
        )

        let savedSearch = SavedSearch(
            name: name,
            query: query,
            scope: .products,
            filters: savedFilters,
            createdAt: Date(),
            lastUsed: nil
        )

        savedSearches.append(savedSearch)
        saveSavedSearches()
    }
    
    /// 删除保存的搜索
    func deleteSavedSearch(_ savedSearch: SavedSearch) {
        savedSearches.removeAll { $0.id == savedSearch.id }
        saveSavedSearches()
    }
    
    // MARK: - 私有搜索实现

    // MARK: - 搜索历史管理

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
        UserDefaults.standard.set(searchHistory, forKey: "productSearchHistory")
    }

    private func loadSearchHistory() {
        searchHistory = UserDefaults.standard.stringArray(forKey: "productSearchHistory") ?? []
    }

    private func loadSavedSearches() {
        if let data = UserDefaults.standard.data(forKey: "SavedProductSearches"),
           let searches = try? JSONDecoder().decode([SavedSearch].self, from: data) {
            savedSearches = searches
        }
    }

    private func saveSavedSearches() {
        if let data = try? JSONEncoder().encode(savedSearches) {
            UserDefaults.standard.set(data, forKey: "SavedProductSearches")
        }
    }
}
