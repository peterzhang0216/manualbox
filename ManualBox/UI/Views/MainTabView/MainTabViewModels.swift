//
//  MainTabViewModels.swift
//  ManualBox
//
//  Created by Peter's Mac on 2025/5/10.
//

import SwiftUI
import CoreData
import Foundation

// MARK: - Selection Value

enum SelectionValue: Hashable, Codable {
    case main(Int)
    case category(UUID)
    case tag(UUID)
    case settings(SettingsPanel)
    
    // MARK: - Codable
    enum CodingKeys: String, CodingKey {
        case type, value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "main":
            let value = try container.decode(Int.self, forKey: .value)
            self = .main(value)
        case "category":
            let value = try container.decode(UUID.self, forKey: .value)
            self = .category(value)
        case "tag":
            let value = try container.decode(UUID.self, forKey: .value)
            self = .tag(value)
        case "settings":
            let value = try container.decode(SettingsPanel.self, forKey: .value)
            self = .settings(value)
        default:
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unknown type"))
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .main(let value):
            try container.encode("main", forKey: .type)
            try container.encode(value, forKey: .value)
        case .category(let value):
            try container.encode("category", forKey: .type)
            try container.encode(value, forKey: .value)
        case .tag(let value):
            try container.encode("tag", forKey: .type)
            try container.encode(value, forKey: .value)
        case .settings(let value):
            try container.encode("settings", forKey: .type)
            try container.encode(value, forKey: .value)
        }
    }
    
    // MARK: - Hashable
    func hash(into hasher: inout Hasher) {
        switch self {
        case .main(let index):
            hasher.combine("main")
            hasher.combine(index)
        case .category(let id):
            hasher.combine("category")
            hasher.combine(id)
        case .tag(let id):
            hasher.combine("tag")
            hasher.combine(id)
        case .settings(let panel):
            hasher.combine("settings")
            hasher.combine(panel)
        }
    }
    
    // MARK: - Equatable
    static func == (lhs: SelectionValue, rhs: SelectionValue) -> Bool {
        switch (lhs, rhs) {
        case (.main(let lIndex), .main(let rIndex)):
            return lIndex == rIndex
        case (.category(let lId), .category(let rId)):
            return lId == rId
        case (.tag(let lId), .tag(let rId)):
            return lId == rId
        case (.settings(let lPanel), .settings(let rPanel)):
            return lPanel == rPanel
        default:
            return false
        }
    }
}

// MARK: - Settings Panel

// SettingsPanel枚举已移至ThreeColumnSettingsViewModels.swift

// MARK: - Environment Key for Selected Product

struct SelectedProductKey: EnvironmentKey {
    static var defaultValue: Binding<Product?> = .constant(nil)
}

extension EnvironmentValues {
    var selectedProduct: Binding<Product?> {
        get { self[SelectedProductKey.self] }
        set { self[SelectedProductKey.self] = newValue }
    }
}

// MARK: - Main Tab View State

@MainActor
class MainTabViewState: ObservableObject {
    @Published var selectedTab: SelectionValue? = .main(0)
    @Published var selectedProduct: Product? = nil
    @Published var searchText = ""
    @Published var isEditing = false
    
    // 计算属性：过滤后的产品列表
    func filteredProducts(from products: FetchedResults<Product>) -> [Product] {
        return Array(products).filter { product in
            if searchText.isEmpty {
                return true
            }
            let searchLower = searchText.lowercased()
            return product.name?.lowercased().contains(searchLower) == true ||
                   product.brand?.lowercased().contains(searchLower) == true ||
                   product.model?.lowercased().contains(searchLower) == true
        }
    }
    
    // 上下文感知的默认值
    func getContextualDefaults(categories: [Category], tags: [Tag]) -> (Category?, Tag?) {
        guard let selectedTab = selectedTab else {
            return (nil, nil) // 在"所有商品"页面，不设置默认值
        }

        switch selectedTab {
        case .main(_):
            // 在主页面（所有商品、分类管理、标签管理等），不设置默认值
            return (nil, nil)
        case .category(let id):
            // 在特定分类页面，设置该分类为默认值
            let category = categories.first(where: { $0.id == id })
            return (category, nil)
        case .tag(let id):
            // 在特定标签页面，设置该标签为默认值
            let tag = tags.first(where: { $0.id == id })
            return (nil, tag)
        case .settings:
            // 在设置页面，不设置默认值
            return (nil, nil)
        }
    }
    
    // 清空选择
    func clearSelection() {
        selectedProduct = nil
    }
    
    // 更新选中的标签页
    func updateSelectedTab(_ newTab: SelectionValue?) {
        if selectedTab != newTab {
            selectedTab = newTab
            clearSelection()
        }
    }
}