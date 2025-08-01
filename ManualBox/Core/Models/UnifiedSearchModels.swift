import Foundation
import CoreData
import SwiftUI

// MARK: - 统一搜索结果
struct UnifiedSearchResult: Identifiable, Hashable {
    let id = UUID()
    let type: SearchResultType
    let entity: NSManagedObject
    let title: String
    let subtitle: String
    let relevanceScore: Double
    let highlights: [String]
    
    // Hashable 实现
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: UnifiedSearchResult, rhs: UnifiedSearchResult) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - 搜索结果类型
enum SearchResultType: String, CaseIterable {
    case product = "product"
    case manual = "manual"
    case category = "category"
    case tag = "tag"
    
    var displayName: String {
        switch self {
        case .product:
            return "产品"
        case .manual:
            return "说明书"
        case .category:
            return "分类"
        case .tag:
            return "标签"
        }
    }
    
    var iconName: String {
        switch self {
        case .product:
            return "cube.box"
        case .manual:
            return "doc.text"
        case .category:
            return "folder"
        case .tag:
            return "tag"
        }
    }

    var icon: String {
        return iconName
    }

    var color: Color {
        switch self {
        case .product:
            return .green
        case .manual:
            return .blue
        case .category:
            return .orange
        case .tag:
            return .purple
        }
    }
}

// MARK: - 搜索范围
enum SearchScope: String, CaseIterable, Codable {
    case all = "all"
    case products = "products"
    case manuals = "manuals"
    case categories = "categories"
    case tags = "tags"
    
    var displayName: String {
        switch self {
        case .all:
            return "全部"
        case .products:
            return "产品"
        case .manuals:
            return "说明书"
        case .categories:
            return "分类"
        case .tags:
            return "标签"
        }
    }
}

// MARK: - 统一搜索配置
struct UnifiedSearchConfiguration {
    let caseSensitive: Bool
    let enableFuzzySearch: Bool
    let enableSynonymSearch: Bool
    let maxResults: Int
    let minRelevanceScore: Double
    let debounceInterval: TimeInterval
    
    static let `default` = UnifiedSearchConfiguration(
        caseSensitive: false,
        enableFuzzySearch: true,
        enableSynonymSearch: false,
        maxResults: 50,
        minRelevanceScore: 0.1,
        debounceInterval: 0.3
    )
    
    static let strict = UnifiedSearchConfiguration(
        caseSensitive: true,
        enableFuzzySearch: false,
        enableSynonymSearch: false,
        maxResults: 20,
        minRelevanceScore: 0.5,
        debounceInterval: 0.5
    )
    
    static let relaxed = UnifiedSearchConfiguration(
        caseSensitive: false,
        enableFuzzySearch: true,
        enableSynonymSearch: true,
        maxResults: 100,
        minRelevanceScore: 0.05,
        debounceInterval: 0.2
    )
}

// MARK: - 统一搜索过滤器
struct UnifiedSearchFilters {
    let category: Category?
    let tags: [Tag]
    let dateRange: DateRange?
    let fileTypes: [String]
    let minRelevanceScore: Double?
    
    init(
        category: Category? = nil,
        tags: [Tag] = [],
        dateRange: DateRange? = nil,
        fileTypes: [String] = [],
        minRelevanceScore: Double? = nil
    ) {
        self.category = category
        self.tags = tags
        self.dateRange = dateRange
        self.fileTypes = fileTypes
        self.minRelevanceScore = minRelevanceScore
    }
    
    struct DateRange {
        let startDate: Date
        let endDate: Date
    }
}

// MARK: - 搜索建议 (using the one from AdvancedSearchService)

// MARK: - 保存的搜索
struct SavedSearch: Identifiable, Codable, Hashable {
    let id = UUID()
    let name: String
    let query: String
    let scope: SearchScope
    let filters: SavedSearchFilters
    let createdAt: Date
    let lastUsed: Date?
    
    struct SavedSearchFilters: Codable, Hashable {
        let categoryName: String?
        let tagNames: [String]
        let dateRange: DateRange?
        let fileTypes: [String]

        struct DateRange: Codable, Hashable {
            let startDate: Date
            let endDate: Date
        }

        var hasActiveFilters: Bool {
            return categoryName != nil ||
                   !tagNames.isEmpty ||
                   dateRange != nil ||
                   !fileTypes.isEmpty
        }
    }
    
    // Hashable 实现
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: SavedSearch, rhs: SavedSearch) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - 搜索统计
struct SearchStatistics {
    let totalSearches: Int
    let averageResultCount: Double
    let mostSearchedTerms: [String: Int]
    let searchesByScope: [SearchScope: Int]
    let averageSearchTime: TimeInterval
    let lastSearchDate: Date?
    
    static let empty = SearchStatistics(
        totalSearches: 0,
        averageResultCount: 0.0,
        mostSearchedTerms: [:],
        searchesByScope: [:],
        averageSearchTime: 0.0,
        lastSearchDate: nil
    )
}

// MARK: - 搜索性能指标
struct SearchPerformanceMetrics {
    let searchDuration: TimeInterval
    let resultCount: Int
    let indexHitRate: Double
    let cacheHitRate: Double
    let memoryUsage: Double
    
    var isPerformant: Bool {
        searchDuration < 1.0 && indexHitRate > 0.8
    }
    
    var performanceGrade: PerformanceGrade {
        switch searchDuration {
        case 0..<0.1:
            return .excellent
        case 0.1..<0.5:
            return .good
        case 0.5..<1.0:
            return .fair
        default:
            return .poor
        }
    }
    
    enum PerformanceGrade: String, CaseIterable {
        case excellent = "excellent"
        case good = "good"
        case fair = "fair"
        case poor = "poor"
        
        var displayName: String {
            switch self {
            case .excellent:
                return "优秀"
            case .good:
                return "良好"
            case .fair:
                return "一般"
            case .poor:
                return "较差"
            }
        }
        
        var color: String {
            switch self {
            case .excellent:
                return "green"
            case .good:
                return "blue"
            case .fair:
                return "orange"
            case .poor:
                return "red"
            }
        }
    }
}

// MARK: - 搜索建议
struct SearchSuggestion: Identifiable, Hashable {
    let id = UUID()
    let text: String
    let type: SuggestionType
    let score: Double
    
    enum SuggestionType: String, CaseIterable {
        case history = "history"
        case product = "product"
        case category = "category"
        case tag = "tag"
        case manual = "manual"
        case autocomplete = "autocomplete"
        
        var displayName: String {
            switch self {
            case .history:
                return "历史搜索"
            case .product:
                return "产品"
            case .category:
                return "分类"
            case .tag:
                return "标签"
            case .manual:
                return "说明书"
            case .autocomplete:
                return "自动完成"
            }
        }
        
        var iconName: String {
            switch self {
            case .history:
                return "clock"
            case .product:
                return "cube.box"
            case .category:
                return "folder"
            case .tag:
                return "tag"
            case .manual:
                return "doc.text"
            case .autocomplete:
                return "magnifyingglass"
            }
        }
    }
    
    init(text: String, type: SuggestionType, score: Double = 0.5) {
        self.text = text
        self.type = type
        self.score = score
    }
    
    // Hashable 实现
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: SearchSuggestion, rhs: SearchSuggestion) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - 搜索上下文
struct SearchContext {
    let currentView: String
    let userLocation: String?
    let deviceType: String
    let searchHistory: [String]
    let userPreferences: SearchPreferences
    
    struct SearchPreferences {
        let preferredScope: SearchScope
        let maxResults: Int
        let enableAutoComplete: Bool
        let enableSearchHistory: Bool
        let enableSuggestions: Bool
    }
}
