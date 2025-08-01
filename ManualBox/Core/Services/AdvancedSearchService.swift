import Foundation
import Combine

// MARK: - 高级搜索服务
class AdvancedSearchService: ObservableObject {
    static let shared = AdvancedSearchService()
    
    @Published var searchHistory: [String] = []
    @Published var savedSearches: [SavedSearchItem] = []
    @Published var recentSearches: [String] = []
    @Published var popularSearches: [String] = []
    
    private init() {
        loadSearchData()
    }
    
    // MARK: - 搜索历史管理
    func addToSearchHistory(_ query: String) {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return }
        
        // 移除重复项
        searchHistory.removeAll { $0 == trimmedQuery }
        
        // 添加到开头
        searchHistory.insert(trimmedQuery, at: 0)
        
        // 限制历史记录数量
        if searchHistory.count > 50 {
            searchHistory = Array(searchHistory.prefix(50))
        }
        
        updateRecentSearches()
        updatePopularSearches()
        saveSearchData()
    }
    
    // MARK: - 保存的搜索管理
    func saveSearch(_ item: SavedSearchItem) {
        savedSearches.append(item)
        saveSearchData()
    }
    
    func removeSavedSearch(_ item: SavedSearchItem) {
        savedSearches.removeAll { $0.id == item.id }
        saveSearchData()
    }
    
    // MARK: - 私有方法
    private func updateRecentSearches() {
        recentSearches = Array(searchHistory.prefix(10))
    }
    
    private func updatePopularSearches() {
        let searchCounts = Dictionary(grouping: searchHistory) { $0 }
            .mapValues { $0.count }
        
        popularSearches = searchCounts
            .sorted { $0.value > $1.value }
            .prefix(10)
            .map { $0.key }
    }
    
    private func loadSearchData() {
        if let historyData = UserDefaults.standard.data(forKey: "AdvancedSearchHistory"),
           let history = try? JSONDecoder().decode([String].self, from: historyData) {
            searchHistory = history
        }
        
        if let savedData = UserDefaults.standard.data(forKey: "SavedSearches"),
           let saved = try? JSONDecoder().decode([SavedSearchItem].self, from: savedData) {
            savedSearches = saved
        }
        
        updateRecentSearches()
        updatePopularSearches()
    }
    
    private func saveSearchData() {
        if let historyData = try? JSONEncoder().encode(searchHistory) {
            UserDefaults.standard.set(historyData, forKey: "AdvancedSearchHistory")
        }
        
        if let savedData = try? JSONEncoder().encode(savedSearches) {
            UserDefaults.standard.set(savedData, forKey: "SavedSearches")
        }
    }
}

// MARK: - 保存的搜索项
struct SavedSearchItem: Identifiable, Codable {
    let id = UUID()
    let name: String
    let query: String
    let filters: SearchFilters?
    let createdAt: Date
    let lastUsed: Date?
    let useCount: Int
    
    enum CodingKeys: String, CodingKey {
        case id, name, query, filters, createdAt, lastUsed, useCount
    }
    
    init(id: UUID = UUID(), name: String, query: String, filters: SearchFilters? = nil, createdAt: Date = Date(), lastUsed: Date? = nil, useCount: Int = 0) {
        self.id = id
        self.name = name
        self.query = query
        self.filters = filters
        self.createdAt = createdAt
        self.lastUsed = lastUsed
        self.useCount = useCount
    }
}



// MARK: - 搜索排序选项已移至SavedSearchesView.swift