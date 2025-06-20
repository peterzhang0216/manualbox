import SwiftUI
import CoreData

/// 增强的产品列表视图 - 支持多选和批量操作
struct EnhancedProductListView: View {
    @Environment(\.managedObjectContext) private var viewContext

    let filteredProducts: [Product]
    let searchText: String
    let deleteProducts: (IndexSet) -> Void

    @State private var selectedProducts: Set<Product> = []
    @State private var isSelectionMode = false
    @State private var showingBatchOperations = false

    // 列表显示模式
    @State private var viewMode: ViewMode = .list

    #if os(macOS)
    @Environment(\.selectedProduct) private var environmentSelectedProduct
    @Environment(\.productSelectionManager) private var productSelectionManager

    private var selectedProduct: Binding<Product?> {
        environmentSelectedProduct
    }
    #endif
    
    enum ViewMode: String, CaseIterable {
        case list = "列表"
        case grid = "网格"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 工具栏
            if !filteredProducts.isEmpty {
                toolbarView
            }
            
            // 批量操作工具栏
            if isSelectionMode {
                BatchOperationsToolbar(
                    selectedProducts: selectedProducts,
                    onOperationCompleted: {
                        exitSelectionMode()
                    }
                )
                .transition(.move(edge: .top))
            }
            
            // 产品列表/网格
            mainContentView
        }
        .animation(.easeInOut(duration: 0.3), value: isSelectionMode)
        .animation(.easeInOut(duration: 0.3), value: viewMode)
    }
    
    // MARK: - 工具栏
    private var toolbarView: some View {
        HStack {
            // 视图模式切换
            Picker("", selection: $viewMode) {
                ForEach(ViewMode.allCases, id: \.self) { mode in
                    Image(systemName: iconForViewMode(mode))
                        .tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 80)
            
            Spacer()
            
            // 操作按钮
            HStack(spacing: 8) {
                // 多选模式切换
                Button(action: toggleSelectionMode) {
                    Image(systemName: isSelectionMode ? "checkmark.circle.fill" : "checkmark.circle")
                }
                .foregroundColor(isSelectionMode ? .accentColor : .secondary)
                
                // 全选/取消全选
                if isSelectionMode {
                    Button(action: toggleSelectAll) {
                        Image(systemName: isAllSelected ? "minus.circle" : "plus.circle")
                    }
                    .foregroundColor(.accentColor)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.secondary.opacity(0.05))
    }
    
    // MARK: - 主要内容视图
    private var mainContentView: some View {
        Group {
            if filteredProducts.isEmpty {
                emptyStateView
            } else {
                switch viewMode {
                case .list:
                    listView
                case .grid:
                    gridView
                }
            }
        }
    }
    
    // MARK: - 列表视图
    private var listView: some View {
        List {
            ForEach(filteredProducts, id: \.self) { product in
                ProductListRow(
                    product: product,
                    isSelected: selectedProducts.contains(product),
                    isSelectionMode: isSelectionMode,
                    onSelectionToggle: {
                        toggleProductSelection(product)
                    },
                    onTap: {
                        #if os(macOS)
                        if !isSelectionMode {
                            // 使用ProductSelectionManager进行选择
                            if let manager = productSelectionManager {
                                manager.send(.selectProduct(product))
                            } else {
                                // 回退到直接设置
                                selectedProduct.wrappedValue = product
                            }
                        }
                        #endif
                    }
                )
            }
            .onDelete(perform: isSelectionMode ? nil : deleteProducts)
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #else
        .listStyle(.sidebar)
        #endif
    }
    
    // MARK: - 网格视图
    private var gridView: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 160), spacing: 16)
            ], spacing: 16) {
                ForEach(filteredProducts, id: \.self) { product in
                    ProductGridCard(
                        product: product,
                        isSelected: selectedProducts.contains(product),
                        isSelectionMode: isSelectionMode,
                        onSelectionToggle: {
                            toggleProductSelection(product)
                        },
                        onTap: {
                            #if os(macOS)
                            if !isSelectionMode {
                                // 使用ProductSelectionManager进行选择
                                if let manager = productSelectionManager {
                                    manager.send(.selectProduct(product))
                                } else {
                                    // 回退到直接设置
                                    selectedProduct.wrappedValue = product
                                }
                            }
                            #endif
                        }
                    )
                }
            }
            .padding()
        }
    }
    

    
    // MARK: - 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: searchText.isEmpty ? "shippingbox" : "magnifyingglass")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundColor(.accentColor)
            
            VStack(spacing: 8) {
                Text(searchText.isEmpty ? "没有产品" : "未找到匹配结果")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text(searchText.isEmpty ?
                     "点击右上角 + 按钮添加产品" :
                     "请尝试其他搜索关键词")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.secondary.opacity(0.05))
    }
    
    // MARK: - 辅助方法
    private func iconForViewMode(_ mode: ViewMode) -> String {
        switch mode {
        case .list: return "list.bullet"
        case .grid: return "grid"
        }
    }
    
    private func toggleSelectionMode() {
        withAnimation {
            isSelectionMode.toggle()
            if !isSelectionMode {
                selectedProducts.removeAll()
            }
        }
    }
    
    private func exitSelectionMode() {
        withAnimation {
            isSelectionMode = false
            selectedProducts.removeAll()
        }
    }
    
    private func toggleProductSelection(_ product: Product) {
        if selectedProducts.contains(product) {
            selectedProducts.remove(product)
        } else {
            selectedProducts.insert(product)
        }
    }
    
    private func toggleSelectAll() {
        if isAllSelected {
            selectedProducts.removeAll()
        } else {
            selectedProducts = Set(filteredProducts)
        }
    }
    
    private var isAllSelected: Bool {
        !filteredProducts.isEmpty && selectedProducts.count == filteredProducts.count
    }
}

// MARK: - 产品列表行组件
struct ProductListRow: View {
    let product: Product
    let isSelected: Bool
    let isSelectionMode: Bool
    let onSelectionToggle: () -> Void
    let onTap: (() -> Void)?

    init(
        product: Product,
        isSelected: Bool,
        isSelectionMode: Bool,
        onSelectionToggle: @escaping () -> Void,
        onTap: (() -> Void)? = nil
    ) {
        self.product = product
        self.isSelected = isSelected
        self.isSelectionMode = isSelectionMode
        self.onSelectionToggle = onSelectionToggle
        self.onTap = onTap
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // 选择指示器
            if isSelectionMode {
                Button(action: onSelectionToggle) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? .accentColor : .secondary)
                        .font(.title2)
                }
                .buttonStyle(.plain)
            }
            
            // 产品图片
            ProductImageView(product: product, size: 60)
            
            // 产品信息
            VStack(alignment: .leading, spacing: 4) {
                Text(product.productName)
                    .font(.headline)
                    .lineLimit(1)
                
                if !product.productBrand.isEmpty {
                    Text(product.productBrand)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                if !product.productModel.isEmpty {
                    Text(product.productModel)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                // 标签显示
                if let tags = product.tags as? Set<Tag>, !tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(Array(tags).prefix(3), id: \.self) { tag in
                                TagBadge(tag: tag)
                            }
                            if tags.count > 3 {
                                Text("+\(tags.count - 3)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            
            Spacer()
            
            // 状态指示器
            VStack(alignment: .trailing, spacing: 4) {
                if let order = product.order {
                    warrantyStatusBadge(for: order)
                }
                
                if let manuals = product.manuals, manuals.count > 0 {
                    Label("\(manuals.count)", systemImage: "doc.text")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
        .contentShape(Rectangle())
        .onTapGesture {
            if !isSelectionMode {
                onTap?()
            }
        }
    }
    
    @ViewBuilder
    private func warrantyStatusBadge(for order: Order) -> some View {
        if let warrantyEndDate = order.warrantyEndDate {
            let isActive = warrantyEndDate > Date()
            HStack(spacing: 2) {
                Circle()
                    .fill(isActive ? Color.green : Color.red)
                    .frame(width: 6, height: 6)
                Text(isActive ? "保修中" : "已过期")
                    .font(.caption2)
                    .foregroundColor(isActive ? .green : .red)
            }
        }
    }
}

// MARK: - 产品网格卡片组件
struct ProductGridCard: View {
    let product: Product
    let isSelected: Bool
    let isSelectionMode: Bool
    let onSelectionToggle: () -> Void
    let onTap: (() -> Void)?

    init(
        product: Product,
        isSelected: Bool,
        isSelectionMode: Bool,
        onSelectionToggle: @escaping () -> Void,
        onTap: (() -> Void)? = nil
    ) {
        self.product = product
        self.isSelected = isSelected
        self.isSelectionMode = isSelectionMode
        self.onSelectionToggle = onSelectionToggle
        self.onTap = onTap
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // 选择指示器和图片
            ZStack(alignment: .topTrailing) {
                ProductImageView(product: product, size: 120)
                
                if isSelectionMode {
                    Button(action: onSelectionToggle) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(isSelected ? .accentColor : .secondary)
                            .font(.title2)
                            .background(Color.white)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(8)
                }
            }
            
            // 产品信息
            VStack(spacing: 4) {
                Text(product.productName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                
                if !product.productBrand.isEmpty {
                    Text(product.productBrand)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
        }
        .frame(height: 200)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.secondary.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
        .contentShape(Rectangle())
        .onTapGesture {
            if !isSelectionMode {
                onTap?()
            }
        }
    }
}



// MARK: - 产品图片视图组件
struct ProductImageView: View {
    let product: Product
    let size: CGFloat
    
    var body: some View {
        let imageView = Group {
            if let imageData = product.imageData,
               let image = PlatformImage(data: imageData) {
                #if os(iOS)
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                #else
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                #endif
            } else {
                Image(systemName: "shippingbox")
                    .foregroundColor(.accentColor)
                    .font(.system(size: size * 0.4))
            }
        }
        
        imageView
            .frame(width: size, height: size)
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - 标签徽章组件
struct TagBadge: View {
    let tag: Tag
    
    var body: some View {
        HStack(spacing: 2) {
            Circle()
                .fill(tag.uiColor)
                .frame(width: 4, height: 4)
            Text(tag.tagName)
                .font(.caption2)
                .lineLimit(1)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(tag.uiColor.opacity(0.1))
        )
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    
    return EnhancedProductListView(
        filteredProducts: [],
        searchText: "",
        deleteProducts: { _ in }
    )
    .environment(\.managedObjectContext, context)
}
