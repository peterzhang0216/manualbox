//
//  ProductListViewModel.swift
//  ManualBox
//
//  Created by Assistant on 2025/1/27.
//

import Foundation
import SwiftUI
import CoreData

@MainActor
class ProductListViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var selectedSort: SortOption = .name
    @Published var viewStyle: ViewStyle = .list
    @Published var showingFilters = false
    @Published var selectedCategories: Set<Category> = []
    @Published var selectedTags: Set<Tag> = []
    @Published var showWarrantyFilter = false
    @Published var onlyWithManuals = false
    
    // 多选状态
    @Published var isSelectMode = false
    @Published var selectedProducts: Set<Product> = []
    @Published var _selectedProduct: Product? = nil
    
    private let viewContext: NSManagedObjectContext
    
    init(viewContext: NSManagedObjectContext) {
        self.viewContext = viewContext
    }
    
    // MARK: - 方法
    
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
        selectedProducts.removeAll()
        isSelectMode = false
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
        selectedProducts.removeAll()
        isSelectMode = false
    }
    
    func toggleSelectMode() {
        isSelectMode.toggle()
        if !isSelectMode {
            selectedProducts.removeAll()
        }
    }
    
    func clearSearch() {
        searchText = ""
    }
    

}