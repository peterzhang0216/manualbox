import SwiftUI
import CoreData
import Foundation

struct ProductListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest private var products: FetchedResults<Product>
    @StateObject private var viewModel: ProductListViewModel
    
    var category: Category? = nil
    var filterTag: Tag? = nil
    
    init(category: Category? = nil, tag: Tag? = nil) {
        self.category = category
        self.filterTag = tag
        
        let predicate: NSPredicate?
        if let category = category {
            predicate = NSPredicate(format: "category == %@", category)
        } else if let tag = tag {
            predicate = NSPredicate(format: "ANY tags == %@", tag)
        } else {
            predicate = nil
        }
        
        _products = FetchRequest(
            sortDescriptors: [SortOption.name.sortDescriptor],
            predicate: predicate,
            animation: .default
        )
        
        // 初始化ViewModel时需要传入viewContext，但这里还没有Environment
        // 所以我们在onAppear中初始化
        self._viewModel = StateObject(wrappedValue: ProductListViewModel(viewContext: PersistenceController.shared.container.viewContext))
    }
    
    // 筛选后的产品
    private var filteredProducts: [Product] {
        return viewModel.filteredProducts(from: Array(products))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 搜索和筛选栏
            ProductFilterView(viewModel: viewModel)
            
            if filteredProducts.isEmpty {
                ProductEmptyStateView(
                    searchText: viewModel.searchText,
                    hasFilters: hasActiveFilters
                )
            } else {
                ProductListContentView(
                    products: filteredProducts,
                    viewModel: viewModel
                )
            }
        }
        .navigationTitle(navigationTitle)
        .toolbar {
            toolbarContent
        }
        .sheet(isPresented: Binding(
            get: { viewModel.showingFilters },
            set: { _ in viewModel.send(.toggleFilters) }
        )) {
            FilterView(
                selectedCategories: Binding(
                    get: { viewModel.selectedCategories },
                    set: { viewModel.send(.updateCategories($0)) }
                ),
                selectedTags: Binding(
                    get: { viewModel.selectedTags },
                    set: { viewModel.send(.updateTags($0)) }
                ),
                showWarrantyFilter: Binding(
                    get: { viewModel.showWarrantyFilter },
                    set: { _ in viewModel.send(.toggleWarrantyFilter) }
                ),
                onlyWithManuals: Binding(
                    get: { viewModel.onlyWithManuals },
                    set: { _ in viewModel.send(.toggleOnlyWithManuals) }
                )
            )
        }
        .onChange(of: viewModel.selectedSort) { _, newSort in
            updateSortDescriptors(newSort)
        }
        .onAppear {
            viewModel.setupInitialSelection(from: filteredProducts)
        }
        .onChange(of: filteredProducts.map { $0.objectID }) { _, _ in
            viewModel.updateSelection(from: filteredProducts)
        }
    }
    
    // MARK: - 辅助属性
    
    private var hasActiveFilters: Bool {
        return !viewModel.selectedCategories.isEmpty || 
               !viewModel.selectedTags.isEmpty || 
               viewModel.showWarrantyFilter || 
               viewModel.onlyWithManuals
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        #if os(iOS)
        ToolbarItem(placement: .navigationBarLeading) {
            if viewModel.isSelectMode {
                Button("取消") {
                    viewModel.send(.toggleSelectMode)
                }
            } else {
                Button("选择") {
                    viewModel.send(.toggleSelectMode)
                }
            }
        }
        
        ToolbarItem(placement: .navigationBarTrailing) {
            if viewModel.isSelectMode {
                Menu {
                    Button {
                        viewModel.deleteSelectedProducts(viewContext: viewContext)
                    } label: {
                        Label("删除选中", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .disabled(viewModel.selectedProducts.isEmpty)
            } else {
                addButton
            }
        }
        #else
        SwiftUI.ToolbarItem(placement: .primaryAction) {
            addButton
        }
        #endif
    }
    
    // MARK: - 辅助方法
    
    private var addButton: some View {
        Button {
            NotificationCenter.default.post(name: Notification.Name("CreateNewProduct"), object: nil)
        } label: {
            Label("添加商品", systemImage: "plus")
        }
    }
    
    private func updateSortDescriptors(_ sortOption: SortOption) {
        products.sortDescriptors = [sortOption.sortDescriptor]
    }
    
    private var navigationTitle: String {
        if let category = category {
            return category.categoryName
        } else if let filterTag = filterTag {
            return "标签：\(filterTag.tagName)"
        } else {
            return "所有产品"
        }
    }
}
