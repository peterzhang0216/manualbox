import Foundation

enum ViewStyle: String, CaseIterable {
    case list = "列表"
    case grid = "网格"
    
    var icon: String {
        switch self {
        case .list: return "list.bullet"
        case .grid: return "square.grid.2x2"
        }
    }
}