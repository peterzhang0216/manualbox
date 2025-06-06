import SwiftUI
import CoreData

struct ProductListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Product.name, ascending: true)],
        animation: .default)
    private var products: FetchedResults<Product>
    
    var category: Category? = nil
    var tag: Tag? = nil
    @State private var _selectedProduct: Product? = nil
    
    #if os(macOS)
    @Environment(\.selectedProduct) private var environmentSelectedProduct
    
    // 合并内部状态与环境传递的状态
    private var selectedProduct: Binding<Product?> {
        if environmentSelectedProduct.wrappedValue != nil {
            return environmentSelectedProduct
        } else {
            return Binding(
                get: { _selectedProduct },
                set: { 
                    _selectedProduct = $0
                    environmentSelectedProduct.wrappedValue = $0
                }
            )
        }
    }
    #else
    // iOS 上直接使用内部状态
    private var selectedProduct: Binding<Product?> {
        return Binding(
            get: { _selectedProduct },
            set: { _selectedProduct = $0 }
        )
    }
    #endif
    
    init(category: Category? = nil, tag: Tag? = nil) {
        self.category = category
        self.tag = tag
        
        let predicate: NSPredicate?
        if let category = category {
            predicate = NSPredicate(format: "category == %@", category)
        } else if let tag = tag {
            predicate = NSPredicate(format: "ANY tags == %@", tag)
        } else {
            predicate = nil
        }
        
        _products = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \Product.name, ascending: true)],
            predicate: predicate,
            animation: .default
        )
    }
    
    var body: some View {
        Group {
            if products.isEmpty {
                ContentUnavailableView {
                    Label("暂无商品", systemImage: "shippingbox")
                } description: {
                    Text("点击右上角的 + 按钮添加新商品")
                } actions: {
                    Button {
                        NotificationCenter.default.post(
                            name: Notification.Name("CreateNewProduct"),
                            object: nil
                        )
                    } label: {
                        Text("添加商品")
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                List(selection: selectedProduct) {
                    ForEach(products) { product in
                        #if os(iOS)
                        NavigationLink {
                            ProductDetailView(product: product)
                        } label: {
                            ProductRow(product: product)
                        }
                        #else
                        ProductRow(product: product)
                            .tag(product)
                        #endif
                    }
                    .onDelete { indexSet in
                        deleteItems(at: indexSet)
                    }
                }
                .listStyle(.inset)
            }
        }
        .navigationTitle(navigationTitle)
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .navigationBarTrailing) {
                addButton
            }
            #else
            ToolbarItem {
                addButton
            }
            #endif
        }
        .onAppear {
            #if os(macOS)
            // 优化：确保 selectedProduct 始终与 products.first 同步
            DispatchQueue.main.async {
                if !products.isEmpty {
                    if selectedProduct.wrappedValue == nil || !products.contains(where: { $0 == selectedProduct.wrappedValue }) {
                        selectedProduct.wrappedValue = products.first
                    }
                } else {
                    selectedProduct.wrappedValue = nil
                }
            }
            #endif
        }
        .onChange(of: products.map { $0.objectID }) { oldValue, newValue in
            #if os(macOS)
            // 优化：products 变化时自动同步 selection
            DispatchQueue.main.async {
                if !products.isEmpty {
                    if selectedProduct.wrappedValue == nil || !products.contains(where: { $0 == selectedProduct.wrappedValue }) {
                        selectedProduct.wrappedValue = products.first
                    }
                } else {
                    selectedProduct.wrappedValue = nil
                }
            }
            #endif
        }
    }
    
    private var addButton: some View {
        Button {
            // macOS 下直接设置 showingAddProduct，iOS 继续发通知
            #if os(macOS)
            NotificationCenter.default.post(name: Notification.Name("CreateNewProduct"), object: nil)
            #else
            NotificationCenter.default.post(
                name: Notification.Name("CreateNewProduct"),
                object: nil
            )
            #endif
        } label: {
            Label("添加商品", systemImage: "plus")
        }
    }
    
    private func deleteItems(at offsets: IndexSet) {
        for index in offsets {
            let product = products[index]
            viewContext.delete(product)
        }
        try? viewContext.save()
    }
    
    private var navigationTitle: String {
        if let category = category {
            return category.categoryName
        } else if let tag = tag {
            return "标签：\(tag.tagName)"
        } else {
            return "所有商品"
        }
    }
}

struct ProductRow: View {
    let product: Product
    
    var body: some View {
        HStack {
            Group {
                if let imageData = product.imageData,
                   let image = PlatformImage(data: imageData) {
                    Image(platformImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    Image(systemName: "photo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                        .foregroundColor(.gray)
                        .padding(10)
                        .background(
                            Group {
                                #if os(macOS)
                                Color(nsColor: .windowBackgroundColor)
                                #else
                                Color(uiColor: .systemBackground)
                                #endif
                            }
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            
            VStack(alignment: .leading) {
                Text(product.productName)
                    .font(.headline)
                if !product.productBrand.isEmpty {
                    Text(product.productBrand)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if product.hasActiveWarranty {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundColor(.green)
            }
        }
        .padding(.vertical, 4)
    }
}