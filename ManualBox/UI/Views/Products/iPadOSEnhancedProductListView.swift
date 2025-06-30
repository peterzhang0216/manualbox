import SwiftUI
#if os(iOS)
import UIKit
import UniformTypeIdentifiers
#endif

// MARK: - iPadOS增强产品列表视图
@available(iOS 16.0, *)
struct iPadOSEnhancedProductListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    let filteredProducts: [Product]
    let searchText: String
    let deleteProducts: (IndexSet) -> Void
    
    @State private var selectedProducts: Set<Product> = []
    @State private var isSelectionMode = false
    @State private var draggedProduct: Product?
    @State private var showingKeyboardShortcuts = false
    @State private var hoveredProduct: Product?
    
    // 键盘快捷键状态
    @State private var hasExternalKeyboard = false
    
    var body: some View {
        VStack(spacing: 0) {
            // 增强工具栏
            if !filteredProducts.isEmpty {
                iPadOSToolbar
            }
            
            // 主要内容区域
            mainContentView
                .iPadOSKeyboardShortcuts()
                .iPadOSMultitaskingOptimized()
        }
        .onAppear {
            setupKeyboardObserver()
        }
        .sheet(isPresented: $showingKeyboardShortcuts) {
            KeyboardShortcutsView()
        }
    }
    
    // MARK: - iPadOS工具栏
    private var iPadOSToolbar: some View {
        HStack {
            // 选择模式切换
            Button(action: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    isSelectionMode.toggle()
                    if !isSelectionMode {
                        selectedProducts.removeAll()
                    }
                }
            }) {
                Label(
                    isSelectionMode ? "完成" : "选择",
                    systemImage: isSelectionMode ? "checkmark.circle" : "checkmark.circle.fill"
                )
            }
            .iPadOSHoverEffect()
            
            if isSelectionMode {
                Spacer()
                
                // 批量操作按钮
                HStack(spacing: 16) {
                    Button(action: selectAllProducts) {
                        Label("全选", systemImage: "checklist")
                    }
                    .disabled(selectedProducts.count == filteredProducts.count)
                    
                    Button(action: shareSelectedProducts) {
                        Label("分享", systemImage: "square.and.arrow.up")
                    }
                    .disabled(selectedProducts.isEmpty)
                    
                    Button(action: deleteSelectedProducts) {
                        Label("删除", systemImage: "trash")
                    }
                    .disabled(selectedProducts.isEmpty)
                    .foregroundColor(.red)
                }
            } else {
                Spacer()
                
                // 视图选项
                HStack(spacing: 16) {
                    if hasExternalKeyboard {
                        Button(action: {
                            showingKeyboardShortcuts = true
                        }) {
                            Label("快捷键", systemImage: "keyboard")
                        }
                        .iPadOSHoverEffect()
                    }
                    
                    Button(action: refreshProducts) {
                        Label("刷新", systemImage: "arrow.clockwise")
                    }
                    .iPadOSHoverEffect()
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(backgroundColorForPlatform)
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(separatorColorForPlatform),
            alignment: .bottom
        )
    }
    
    // MARK: - 主要内容视图
    private var mainContentView: some View {
        List {
            ForEach(filteredProducts, id: \.self) { product in
                iPadOSProductRow(product: product)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowSeparator(.hidden)
            }
            .onDelete(perform: isSelectionMode ? nil : deleteProducts)
        }
        .listStyle(.plain)
        .refreshable {
            await refreshProductsAsync()
        }
    }
    
    // MARK: - iPadOS产品行
    @ViewBuilder
    private func iPadOSProductRow(product: Product) -> some View {
        HStack(spacing: 16) {
            // 选择指示器
            if isSelectionMode {
                Button(action: {
                    toggleProductSelection(product)
                }) {
                    Image(systemName: selectedProducts.contains(product) ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundColor(selectedProducts.contains(product) ? .accentColor : .secondary)
                }
                .buttonStyle(.plain)
            }
            
            // 产品图片
            Group {
                if let productImage = product.productImage {
                    Image(platformImage: productImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(grayColorForPlatform)
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(.secondary)
                        )
                }
            }
            .frame(width: 60, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // 产品信息
            VStack(alignment: .leading, spacing: 4) {
                Text(product.productName)
                    .font(.headline)
                    .lineLimit(1)
                
                if let brand = product.brand, !brand.isEmpty {
                    Text(brand)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                HStack {
                    if let category = product.category {
                        Label(category.categoryName, systemImage: category.categoryIcon)
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    
                    Spacer()
                    
                    if let order = product.order, let purchaseDate = order.orderDate {
                        Text(purchaseDate, style: .date)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // 状态指示器
            VStack(alignment: .trailing, spacing: 4) {
                if product.hasActiveWarranty {
                    Label("保修中", systemImage: "checkmark.shield")
                        .font(.caption)
                        .foregroundColor(.green)
                } else {
                    Label("已过保", systemImage: "exclamationmark.shield")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(hoveredProduct == product ? hoverColorForPlatform : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if isSelectionMode {
                toggleProductSelection(product)
            } else {
                // 选择产品进行详情查看
                selectProduct(product)
            }
        }
        .iPadOSHoverEffect()
        .onHover { isHovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                hoveredProduct = isHovering ? product : nil
            }
        }
        .iPadOSContextMenu {
            contextMenuItems(for: product)
        }
    }
    
    // MARK: - 上下文菜单
    @ViewBuilder
    private func contextMenuItems(for product: Product) -> some View {
        Button(action: {
            editProduct(product)
        }) {
            Label("编辑", systemImage: "pencil")
        }
        
        Button(action: {
            duplicateProduct(product)
        }) {
            Label("复制", systemImage: "doc.on.doc")
        }
        
        Button(action: {
            shareProduct(product)
        }) {
            Label("分享", systemImage: "square.and.arrow.up")
        }
        
        Divider()
        
        Button(role: .destructive, action: {
            deleteProduct(product)
        }) {
            Label("删除", systemImage: "trash")
        }
    }
    
    // MARK: - 操作方法
    private func toggleProductSelection(_ product: Product) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if selectedProducts.contains(product) {
                selectedProducts.remove(product)
            } else {
                selectedProducts.insert(product)
            }
        }
    }
    
    private func selectAllProducts() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            selectedProducts = Set(filteredProducts)
        }
    }
    
    private func selectProduct(_ product: Product) {
        // 通知主视图选择了产品
        NotificationCenter.default.post(
            name: .productSelected,
            object: product
        )
    }
    
    private func editProduct(_ product: Product) {
        NotificationCenter.default.post(
            name: .editProduct,
            object: product
        )
    }
    
    private func duplicateProduct(_ product: Product) {
        // 实现产品复制逻辑
    }
    
    private func shareProduct(_ product: Product) {
        // 实现产品分享逻辑
    }
    
    private func shareSelectedProducts() {
        // 实现批量分享逻辑
    }
    
    private func deleteProduct(_ product: Product) {
        // 实现单个产品删除逻辑
    }
    
    private func deleteSelectedProducts() {
        // 实现批量删除逻辑
    }
    
    private func refreshProducts() {
        // 实现刷新逻辑
    }
    
    private func refreshProductsAsync() async {
        // 实现异步刷新逻辑
        try? await Task.sleep(nanoseconds: 1_000_000_000)
    }
    
    private func handleProductDrop(_ products: [Product], at target: Product) -> Bool {
        // 实现拖拽重排序逻辑
        return true
    }
    
    // MARK: - 平台颜色计算属性
    private var backgroundColorForPlatform: Color {
        #if os(iOS)
        return Color(.systemBackground)
        #else
        return Color(NSColor.controlBackgroundColor)
        #endif
    }

    private var separatorColorForPlatform: Color {
        #if os(iOS)
        return Color(.separator)
        #else
        return Color(NSColor.separatorColor)
        #endif
    }

    private var grayColorForPlatform: Color {
        #if os(macOS)
        return Color(nsColor: .windowBackgroundColor)
        #else
        return Color(.systemGray5)
        #endif
    }

    private var hoverColorForPlatform: Color {
        #if os(iOS)
        return Color(.systemGray6)
        #else
        return Color(NSColor.controlColor)
        #endif
    }

    private func setupKeyboardObserver() {
        #if os(iOS)
        if #available(iOS 14.0, *) {
            hasExternalKeyboard = iPadOSAdapter.hasExternalKeyboard
            
            NotificationCenter.default.addObserver(
                forName: .iPadOSKeyboardConnected,
                object: nil,
                queue: .main
            ) { _ in
                hasExternalKeyboard = true
            }
            
            NotificationCenter.default.addObserver(
                forName: .iPadOSKeyboardDisconnected,
                object: nil,
                queue: .main
            ) { _ in
                hasExternalKeyboard = false
            }
        }
        #endif
    }
}

// MARK: - 产品拖拽预览
struct ProductDragPreview: View {
    let product: Product

    private var grayColorForPlatform: Color {
        #if os(iOS)
        return Color(.systemGray5)
        #else
        return Color(NSColor.controlColor)
        #endif
    }

    private var backgroundColorForPlatform: Color {
        #if os(iOS)
        return Color(.systemBackground)
        #else
        return Color(NSColor.controlBackgroundColor)
        #endif
    }

    var body: some View {
        HStack {
            Group {
                if let productImage = product.productImage {
                    Image(platformImage: productImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(grayColorForPlatform)
                }
            }
            .frame(width: 40, height: 40)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            Text(product.productName)
                .font(.headline)
                .lineLimit(1)
        }
        .padding(8)
        .background(backgroundColorForPlatform)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(radius: 4)
    }
}

// MARK: - 自定义通知
extension Notification.Name {
    static let productSelected = Notification.Name("productSelected")
    static let editProduct = Notification.Name("editProduct")
}

#Preview {
    if #available(iOS 16.0, *) {
        iPadOSEnhancedProductListView(
            filteredProducts: [],
            searchText: "",
            deleteProducts: { _ in }
        )
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
