import SwiftUI
import Foundation

enum SortOption: String, CaseIterable {
    case name = "名称"
    case createdDate = "创建时间"
    case updatedDate = "更新时间"
    case warrantyDate = "保修日期"
    
    var sortDescriptor: SortDescriptor<Product> {
        switch self {
        case .name:
            return SortDescriptor(\Product.name, order: .forward)
        case .createdDate:
            return SortDescriptor(\Product.createdAt, order: .reverse)
        case .updatedDate:
            return SortDescriptor(\Product.updatedAt, order: .reverse)
        case .warrantyDate:
            return SortDescriptor(\Product.order?.warrantyEndDate, order: .reverse)
        }
    }
}