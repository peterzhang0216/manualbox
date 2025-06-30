import Foundation
import CoreData

// MARK: - 产品搜索结果
struct ProductSearchResult: Identifiable {
    let id = UUID()
    let product: Product
    let relevanceScore: Float
    let highlights: [String]
    let matchedFields: [String]
}

// MARK: - 产品搜索排序
enum ProductSearchSort: String, CaseIterable {
    case relevance = "relevance"
    case name = "name"
    case createdDate = "created_date"
    case updatedDate = "updated_date"
    case price = "price"

    var displayName: String {
        switch self {
        case .relevance: return "相关性"
        case .name: return "名称"
        case .createdDate: return "创建时间"
        case .updatedDate: return "更新时间"
        case .price: return "价格"
        }
    }
}



// MARK: - 产品搜索过滤器
struct ProductSearchFilters {
    var categoryId: UUID?
    var tagIds: [UUID] = []
    var minPrice: Decimal?
    var maxPrice: Decimal?
    var startDate: Date?
    var endDate: Date?
    var warrantyStatus: WarrantyStatus?
    var hasManuals: Bool?
    var hasImages: Bool?

    enum WarrantyStatus: String, CaseIterable {
        case active = "active"
        case expiring = "expiring"
        case expired = "expired"

        var displayName: String {
            switch self {
            case .active: return "在保修期内"
            case .expiring: return "即将过期"
            case .expired: return "已过期"
            }
        }
    }

    var hasActiveFilters: Bool {
        return categoryId != nil ||
               !tagIds.isEmpty ||
               minPrice != nil ||
               maxPrice != nil ||
               startDate != nil ||
               endDate != nil ||
               warrantyStatus != nil ||
               hasManuals != nil ||
               hasImages != nil
    }

    var filterCount: Int {
        var count = 0
        if categoryId != nil { count += 1 }
        if !tagIds.isEmpty { count += 1 }
        if minPrice != nil || maxPrice != nil { count += 1 }
        if startDate != nil || endDate != nil { count += 1 }
        if warrantyStatus != nil { count += 1 }
        if hasManuals != nil { count += 1 }
        if hasImages != nil { count += 1 }
        return count
    }

    init() {}
}

struct SearchFilters {
    // 搜索范围
    var searchInName: Bool = true
    var searchInBrand: Bool = true
    var searchInModel: Bool = true
    var searchInNotes: Bool = true
    
    // 分类筛选
    var filterByCategory: Bool = false
    var selectedCategoryID: String = ""
    
    // 标签筛选
    var filterByTag: Bool = false
    var selectedTagIDs: [String] = []
    
    // 保修状态筛选
    var filterByWarranty: Bool = false
    var warrantyStatus: Int = -1  // -1: 所有, 0: 在保修期内, 1: 即将过期, 2: 已过期
    
    // 日期筛选
    var filterByDate: Bool = false
    var startDate: Date = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
    var endDate: Date = Date()
    
    // 检查是否有任何筛选器被启用
    var hasActiveFilters: Bool {
        return filterByCategory || filterByTag || filterByWarranty || filterByDate
    }
    
    // 获取筛选器描述
    var filterDescription: String {
        var descriptions: [String] = []
        
        if filterByCategory, !selectedCategoryID.isEmpty {
            descriptions.append("分类筛选")
        }
        
        if filterByTag, !selectedTagIDs.isEmpty {
            descriptions.append("\(selectedTagIDs.count)个标签")
        }
        
        if filterByWarranty {
            let status: String
            switch warrantyStatus {
            case 0: status = "在保修期内"
            case 1: status = "即将过期"
            case 2: status = "已过期"
            default: status = "所有状态"
            }
            descriptions.append(status)
        }
        
        if filterByDate {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .short
            dateFormatter.timeStyle = .none
            descriptions.append("\(dateFormatter.string(from: startDate)) - \(dateFormatter.string(from: endDate))")
        }
        
        return descriptions.joined(separator: ", ")
    }
}
