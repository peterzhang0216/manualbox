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
    
    // 数据状态
    var filteredProductsCount: Int = 0
    var hasActiveFilters: Bool = false
    
    // 操作状态
    var isDeletingProducts: Bool = false
    var deleteError: String? = nil
}

// MARK: - ProductList Actions
enum ProductListAction: ActionProtocol {
    // 搜索和筛选动作
    case updateSearchText(String)
    case updateSort(SortOption)
    case updateViewStyle(ViewStyle)
    case toggleFilters
    case updateCategories(Set<Category>)
    case updateTags(Set<Tag>)
    case toggleWarrantyFilter
    case toggleOnlyWithManuals
    case clearAllFilters
    
    // 选择动作
    case toggleSelectMode
    case selectProduct(Product)
    case deselectProduct(Product)
    case selectAllProducts([Product])
    case clearSelection
    case setSelectedProduct(Product?)
    
    // 数据动作
    case updateFilteredCount(Int)
    case updateActiveFiltersStatus(Bool)
    
    // 操作动作
    case deleteProducts([Product])
    case deleteSelectedProducts
    case setDeletingState(Bool)
    case setDeleteError(String?)
}

@MainActor
class ProductListViewModel: BaseViewModel<ProductListState, ProductListAction> {
    private let viewContext: NSManagedObjectContext
    
    // MARK: - 便利属性
    
    // 搜索和筛选状态
    var searchText: String { state.searchText }
    var selectedSort: SortOption { state.selectedSort }
    var viewStyle: ViewStyle { state.viewStyle }
    var showingFilters: Bool { state.showingFilters }
    var selectedCategories: Set<Category> { state.selectedCategories }
    var selectedTags: Set<Tag> { state.selectedTags }
    var showWarrantyFilter: Bool { state.showWarrantyFilter }
    var onlyWithManuals: Bool { state.onlyWithManuals }
    var hasActiveFilters: Bool { state.hasActiveFilters }
    
    // 选择状态
    var isSelectMode: Bool { state.isSelectMode }
    var selectedProducts: Set<Product> { state.selectedProducts }
    var selectedProduct: Product? { state.selectedProduct }
    var hasSelectedProducts: Bool { !state.selectedProducts.isEmpty }
    var selectedProductsCount: Int { state.selectedProducts.count }
    
    // 数据状态
    var filteredProductsCount: Int { state.filteredProductsCount }
    
    // 操作状态
    var isDeletingProducts: Bool { state.isDeletingProducts }
    var deleteError: String? { state.deleteError }
    var hasDeleteError: Bool { state.deleteError != nil }
    
    // 兼容性属性（保持向后兼容）
    var _selectedProduct: Product? { state.selectedProduct }
    
    init(viewContext: NSManagedObjectContext) {
        self.viewContext = viewContext
        super.init(initialState: ProductListState())
    }
    
    // MARK: - Action Handler
    override func handle(_ action: ProductListAction) async {
        switch action {
        // 搜索和筛选动作处理
        case .updateSearchText(let text):
            updateState { 
                $0.searchText = text
                $0.hasActiveFilters = self.hasActiveFilters(in: $0)
            }
            
        case .updateSort(let sort):
            updateState { $0.selectedSort = sort }
            
        case .updateViewStyle(let style):
            updateState { $0.viewStyle = style }
            
        case .toggleFilters:
            updateState { $0.showingFilters.toggle() }
            
        case .updateCategories(let categories):
            updateState { 
                $0.selectedCategories = categories
                $0.hasActiveFilters = self.hasActiveFilters(in: $0)
            }
            
        case .updateTags(let tags):
            updateState { 
                $0.selectedTags = tags
                $0.hasActiveFilters = self.hasActiveFilters(in: $0)
            }
            
        case .toggleWarrantyFilter:
            updateState { 
                $0.showWarrantyFilter.toggle()
                $0.hasActiveFilters = self.hasActiveFilters(in: $0)
            }
            
        case .toggleOnlyWithManuals:
            updateState { 
                $0.onlyWithManuals.toggle()
                $0.hasActiveFilters = self.hasActiveFilters(in: $0)
            }
            
        case .clearAllFilters:
            updateState {
                $0.searchText = ""
                $0.selectedCategories.removeAll()
                $0.selectedTags.removeAll()
                $0.showWarrantyFilter = false
                $0.onlyWithManuals = false
                $0.hasActiveFilters = false
            }
            
        // 选择动作处理
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
            
        case .selectAllProducts(let products):
            updateState { $0.selectedProducts = Set(products) }
            
        case .clearSelection:
            updateState { $0.selectedProducts.removeAll() }
            
        case .setSelectedProduct(let product):
            updateState { $0.selectedProduct = product }
            
        // 数据动作处理
        case .updateFilteredCount(let count):
            updateState { $0.filteredProductsCount = count }
            
        case .updateActiveFiltersStatus(let hasFilters):
            updateState { $0.hasActiveFilters = hasFilters }
            
        // 操作动作处理
        case .deleteProducts(let products):
            await performDeleteOperation(products: products)
            
        case .deleteSelectedProducts:
            await performDeleteOperation(products: Array(state.selectedProducts))
            
        case .setDeletingState(let isDeleting):
            updateState { $0.isDeletingProducts = isDeleting }
            
        case .setDeleteError(let error):
            updateState { $0.deleteError = error }
        }
    }
    
    // MARK: - 业务方法
    
    /// 根据当前筛选条件过滤产品列表
    func filteredProducts(from products: [Product]) -> [Product] {
        var filtered = Array(products)
        
        // 搜索筛选
        if !searchText.isEmpty {
            filtered = applySearchFilter(to: filtered, searchText: searchText)
        }
        
        // 分类筛选
        if !selectedCategories.isEmpty {
            filtered = applyCategoryFilter(to: filtered, categories: selectedCategories)
        }
        
        // 标签筛选
        if !selectedTags.isEmpty {
            filtered = applyTagFilter(to: filtered, tags: selectedTags)
        }
        
        // 保修状态筛选
        if showWarrantyFilter {
            filtered = applyWarrantyFilter(to: filtered)
        }
        
        // 说明书筛选
        if onlyWithManuals {
            filtered = applyManualFilter(to: filtered)
        }
        
        // 更新筛选后的产品数量
        self.send(.updateFilteredCount(filtered.count))
        
        return filtered
    }
    
    // MARK: - 私有筛选方法
    
    private func applySearchFilter(to products: [Product], searchText: String) -> [Product] {
        return products.filter { product in
            product.productName.localizedCaseInsensitiveContains(searchText) ||
            product.productBrand.localizedCaseInsensitiveContains(searchText) ||
            product.productModel.localizedCaseInsensitiveContains(searchText) ||
            (product.category?.categoryName.localizedCaseInsensitiveContains(searchText) == true) ||
            (product.tags?.contains { tag in
                (tag as? Tag)?.tagName.localizedCaseInsensitiveContains(searchText) == true
            } == true)
        }
    }
    
    private func applyCategoryFilter(to products: [Product], categories: Set<Category>) -> [Product] {
        return products.filter { product in
            guard let category = product.category else { return false }
            return categories.contains(category)
        }
    }
    
    private func applyTagFilter(to products: [Product], tags: Set<Tag>) -> [Product] {
        return products.filter { product in
            guard let productTags = product.tags as? Set<Tag> else { return false }
            return !tags.isDisjoint(with: productTags)
        }
    }
    
    private func applyWarrantyFilter(to products: [Product]) -> [Product] {
        return products.filter { product in
            guard let warrantyDate = product.order?.warrantyEndDate else { return false }
            return warrantyDate > Date()
        }
    }
    
    private func applyManualFilter(to products: [Product]) -> [Product] {
        return products.filter { product in
            guard let manuals = product.manuals, manuals.count > 0 else { return false }
            return true
        }
    }
    
    private func hasActiveFilters(in state: ProductListState) -> Bool {
        return !state.searchText.isEmpty ||
               !state.selectedCategories.isEmpty ||
               !state.selectedTags.isEmpty ||
               state.showWarrantyFilter ||
               state.onlyWithManuals
    }
    
    // MARK: - 删除操作
    
    private func performDeleteOperation(products: [Product]) async {
        guard !products.isEmpty else { return }
        
        await performTask {
            self.send(.setDeletingState(true))
            
            do {
                for product in products {
                    self.viewContext.delete(product)
                }
                try self.viewContext.save()
                
                // 清理选择状态
                self.send(.clearSelection)
                 if self.state.isSelectMode {
                     self.send(.toggleSelectMode)
                 }
                
                self.send(.setDeleteError(nil))
            } catch {
                self.send(.setDeleteError("删除失败: \(error.localizedDescription)"))
                throw error
            }
            
            self.send(.setDeletingState(false))
        }
    }
    
    // MARK: - 公共操作方法
    
    /// 删除指定索引的产品
    func deleteItems(at offsets: IndexSet, from products: [Product]) {
        let productsToDelete = offsets.map { products[$0] }
        self.send(.deleteProducts(productsToDelete))
    }
    
    /// 删除选中的产品
    func deleteSelectedProducts() {
        self.send(.deleteSelectedProducts)
    }
    
    /// 批量删除产品
    func batchDelete(products: [Product]) {
        self.send(.deleteProducts(products))
    }
    
    /// 切换选择模式
    func toggleSelectMode() {
        self.send(.toggleSelectMode)
    }
    
    /// 选择所有产品
    func selectAllProducts(_ products: [Product]) {
        self.send(.selectAllProducts(products))
    }
    
    /// 清除搜索
    func clearSearch() {
        self.send(.updateSearchText(""))
    }
    
    /// 清除所有筛选条件
    func clearAllFilters() {
        self.send(.clearAllFilters)
    }
    
    // MARK: - 选择管理
    
    func setupInitialSelection(from products: [Product]) {
        #if os(macOS)
        // macOS特定的初始选择逻辑
        if let firstProduct = products.first, state.selectedProduct == nil {
            self.send(ProductListAction.setSelectedProduct(firstProduct))
        }
        #endif
    }
    
    func updateSelection(from products: [Product]) {
        #if os(macOS)
        // 确保选中的产品仍在筛选后的列表中
        if let selectedProduct = state.selectedProduct,
           !products.contains(selectedProduct) {
            self.send(ProductListAction.setSelectedProduct(products.first))
        }
        #endif
    }
}