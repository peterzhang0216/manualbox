//
//  ProductListViewModel.swift
//  ManualBox
//
//  Created by Assistant on 2025/1/27.
//

import Foundation
import SwiftUI
import CoreData

// MARK: - ProductList State
struct ProductListState: StateProtocol {
    var isLoading: Bool = false
    var errorMessage: String? = nil
    
    // 搜索和筛选状态
    var searchText = ""
    var selectedSort: SortOption = .name
    var viewStyle: ViewStyle = .list
    var showingFilters = false
    var selectedCategories: Set<Category> = []
    var selectedTags: Set<Tag> = []
    var showWarrantyFilter = false
    var onlyWithManuals = false
    
    // 多选状态
    var isSelectMode = false
    var selectedProducts: Set<Product> = []
    var selectedProduct: Product? = nil
}

// MARK: - ProductList Actions
enum ProductListAction: ActionProtocol {
    case updateSearchText(String)
    case updateSort(SortOption)
    case updateViewStyle(ViewStyle)
    case toggleFilters
    case updateCategories(Set<Category>)
    case updateTags(Set<Tag>)
    case toggleWarrantyFilter
    case toggleOnlyWithManuals
    case toggleSelectMode
    case selectProduct(Product)
    case deselectProduct(Product)
    case clearSelection
    case setSelectedProduct(Product?)
}

@MainActor
class ProductListViewModel: BaseViewModel<ProductListState, ProductListAction> {
    private let viewContext: NSManagedObjectContext
    
    // 便利属性，直接从state获取
    var searchText: String { state.searchText }
    var selectedSort: SortOption { state.selectedSort }
    var viewStyle: ViewStyle { state.viewStyle }
    var showingFilters: Bool { state.showingFilters }
    var selectedCategories: Set<Category> { state.selectedCategories }
    var selectedTags: Set<Tag> { state.selectedTags }
    var showWarrantyFilter: Bool { state.showWarrantyFilter }
    var onlyWithManuals: Bool { state.onlyWithManuals }
    var isSelectMode: Bool { state.isSelectMode }
    var selectedProducts: Set<Product> { state.selectedProducts }
    var _selectedProduct: Product? { state.selectedProduct }
    
    init(viewContext: NSManagedObjectContext) {
        self.viewContext = viewContext
        super.init(initialState: ProductListState())
    }
    
    // MARK: - Action Handler
    override func handle(_ action: ProductListAction) async {
        switch action {
        case .updateSearchText(let text):
            updateState { $0.searchText = text }
            
        case .updateSort(let sort):
            updateState { $0.selectedSort = sort }
            
        case .updateViewStyle(let style):
            updateState { $0.viewStyle = style }
            
        case .toggleFilters:
            updateState { $0.showingFilters.toggle() }
            
        case .updateCategories(let categories):
            updateState { $0.selectedCategories = categories }
            
        case .updateTags(let tags):
            updateState { $0.selectedTags = tags }
            
        case .toggleWarrantyFilter:
            updateState { $0.showWarrantyFilter.toggle() }
            
        case .toggleOnlyWithManuals:
            updateState { $0.onlyWithManuals.toggle() }
            
        case .toggleSelectMode:
            updateState { 
                $0.isSelectMode.toggle()
                if !$0.isSelectMode {
                    $0.selectedProducts.removeAll()
                }
            }
            
        case .selectProduct(let product):
            updateState { $0.selectedProducts.insert(product) }
            
        case .deselectProduct(let product):
            updateState { $0.selectedProducts.remove(product) }
            
        case .clearSelection:
            updateState { $0.selectedProducts.removeAll() }
            
        case .setSelectedProduct(let product):
            updateState { $0.selectedProduct = product }
        }
    }
    
    // MARK: - 业务方法
    
    func filteredProducts(from products: [Product]) -> [Product] {
        var filtered = Array(products)
        
        // 搜索筛选
        if !searchText.isEmpty {
            filtered = filtered.filter { product in
                product.productName.localizedCaseInsensitiveContains(searchText) ||
                product.productBrand.localizedCaseInsensitiveContains(searchText) ||
                product.productModel.localizedCaseInsensitiveContains(searchText) ||
                (product.category?.categoryName.localizedCaseInsensitiveContains(searchText) == true) ||
                (product.tags?.contains { tag in
                    (tag as? Tag)?.tagName.localizedCaseInsensitiveContains(searchText) == true
                } == true)
            }
        }
        
        // 分类筛选
        if !selectedCategories.isEmpty {
            filtered = filtered.filter { product in
                guard let category = product.category else { return false }
                return selectedCategories.contains(category)
            }
        }
        
        // 标签筛选
        if !selectedTags.isEmpty {
            filtered = filtered.filter { product in
                guard let tags = product.tags as? Set<Tag> else { return false }
                return !selectedTags.isDisjoint(with: tags)
            }
        }
        
        // 保修状态筛选
        if showWarrantyFilter {
            filtered = filtered.filter { product in
                guard let warrantyDate = product.order?.warrantyEndDate else { return false }
                return warrantyDate > Date()
            }
        }
        
        // 说明书筛选
        if onlyWithManuals {
            filtered = filtered.filter { product in
                guard let manuals = product.manuals, manuals.count > 0 else { return false }
                return true
            }
        }
        
        return filtered
    }
    
    func deleteSelectedProducts(viewContext: NSManagedObjectContext) {
        for product in selectedProducts {
            viewContext.delete(product)
        }
        try? viewContext.save()
        send(.clearSelection)
        send(.toggleSelectMode)
    }
    
    func setupInitialSelection(from products: [Product]) {
        #if os(macOS)
        DispatchQueue.main.async {
            // 这个方法在ProductListView中会被调用
        }
        #endif
    }
    
    func updateSelection(from products: [Product]) {
        #if os(macOS)
        DispatchQueue.main.async {
            // 这个方法在ProductListView中会被调用
        }
        #endif
    }
    
    // MARK: - 操作方法
    
    func deleteItems(at offsets: IndexSet, from products: [Product]) {
        for index in offsets {
            let product = products[index]
            viewContext.delete(product)
        }
        try? viewContext.save()
    }
    
    func batchDelete() {
        for product in selectedProducts {
            viewContext.delete(product)
        }
        try? viewContext.save()
        send(.clearSelection)
        send(.toggleSelectMode)
    }
    
    func toggleSelectMode() {
        send(.toggleSelectMode)
    }
    
    func clearSearch() {
        send(.updateSearchText(""))
    }
}