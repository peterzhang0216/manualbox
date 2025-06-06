import Foundation

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
