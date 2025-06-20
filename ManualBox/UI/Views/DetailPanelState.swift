//
//  DetailPanelState.swift
//  ManualBox
//
//  Created by Peter's Mac on 2025/6/20.
//

import SwiftUI
import CoreData

// MARK: - 详情面板状态枚举
enum DetailPanelState: Equatable {
    case empty
    case productDetail(Product)
    case categoryDetail(Category)
    case tagDetail(Tag)
    case addCategory
    case editCategory(Category)
    case addTag
    case editTag(Tag)
    case addProduct
    case editProduct(Product)
    case categoryList
    case tagList
    
    static func == (lhs: DetailPanelState, rhs: DetailPanelState) -> Bool {
        switch (lhs, rhs) {
        case (.empty, .empty), (.categoryList, .categoryList), (.tagList, .tagList):
            return true
        case (.productDetail(let lhsProduct), .productDetail(let rhsProduct)):
            return lhsProduct.id == rhsProduct.id
        case (.categoryDetail(let lhsCategory), .categoryDetail(let rhsCategory)):
            return lhsCategory.id == rhsCategory.id
        case (.tagDetail(let lhsTag), .tagDetail(let rhsTag)):
            return lhsTag.id == rhsTag.id
        case (.addCategory, .addCategory), (.addTag, .addTag), (.addProduct, .addProduct):
            return true
        case (.editCategory(let lhsCategory), .editCategory(let rhsCategory)):
            return lhsCategory.id == rhsCategory.id
        case (.editTag(let lhsTag), .editTag(let rhsTag)):
            return lhsTag.id == rhsTag.id
        case (.editProduct(let lhsProduct), .editProduct(let rhsProduct)):
            return lhsProduct.id == rhsProduct.id
        default:
            return false
        }
    }
    
    var title: String {
        switch self {
        case .empty:
            return "请选择内容"
        case .productDetail(let product):
            return product.name ?? "产品详情"
        case .categoryDetail(let category):
            return category.categoryName
        case .tagDetail(let tag):
            return tag.tagName
        case .addCategory:
            return "添加分类"
        case .editCategory(let category):
            return "编辑分类: \(category.categoryName)"
        case .addTag:
            return "添加标签"
        case .editTag(let tag):
            return "编辑标签: \(tag.tagName)"
        case .addProduct:
            return "添加产品"
        case .editProduct(let product):
            return "编辑产品: \(product.name ?? "")"
        case .categoryList:
            return "分类管理"
        case .tagList:
            return "标签管理"
        }
    }
    
    var icon: String {
        switch self {
        case .empty:
            return "square.3.layers.3d"
        case .productDetail:
            return "shippingbox"
        case .categoryDetail, .categoryList:
            return "folder"
        case .tagDetail, .tagList:
            return "tag"
        case .addCategory, .editCategory:
            return "folder.badge.plus"
        case .addTag, .editTag:
            return "tag.circle"
        case .addProduct, .editProduct:
            return "plus.square"
        }
    }
}

// MARK: - 详情面板状态管理器
class DetailPanelStateManager: ObservableObject {
    @Published var currentState: DetailPanelState = .empty
    
    func setState(_ newState: DetailPanelState) {
        currentState = newState
    }
    
    func reset() {
        currentState = .empty
    }
    
    func showAddCategory() {
        currentState = .addCategory
    }
    
    func showEditCategory(_ category: Category) {
        currentState = .editCategory(category)
    }
    
    func showAddTag() {
        currentState = .addTag
    }
    
    func showEditTag(_ tag: Tag) {
        currentState = .editTag(tag)
    }
    
    func showAddProduct() {
        currentState = .addProduct
    }
    
    func showEditProduct(_ product: Product) {
        currentState = .editProduct(product)
    }
    
    func showProductDetail(_ product: Product) {
        currentState = .productDetail(product)
    }
    
    func showCategoryDetail(_ category: Category) {
        currentState = .categoryDetail(category)
    }
    
    func showTagDetail(_ tag: Tag) {
        currentState = .tagDetail(tag)
    }
    
    func showCategoryList() {
        currentState = .categoryList
    }
    
    func showTagList() {
        currentState = .tagList
    }
}

// MARK: - Environment Key
struct DetailPanelStateManagerKey: EnvironmentKey {
    static var defaultValue: DetailPanelStateManager {
        DetailPanelStateManager()
    }
}

extension EnvironmentValues {
    var detailPanelStateManager: DetailPanelStateManager {
        get { self[DetailPanelStateManagerKey.self] }
        set { self[DetailPanelStateManagerKey.self] = newValue }
    }
}
