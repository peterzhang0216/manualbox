import SwiftUI
import CoreData



struct CategoryDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    let category: Category
    
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    @State private var showAddProduct = false
    
    @FetchRequest private var products: FetchedResults<Product>
    
    init(category: Category) {
        self.category = category
        
        // 创建针对该分类的产品查询
        _products = FetchRequest<Product>(
            sortDescriptors: [
                NSSortDescriptor(keyPath: \Product.updatedAt, ascending: false),
                NSSortDescriptor(keyPath: \Product.name, ascending: true)
            ],
            predicate: NSPredicate(format: "category == %@", category),
            animation: .default
        )
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 分类信息头部
            categoryHeader
            
            Divider()
            
            // 产品列表
            if products.isEmpty {
                ContentUnavailableView {
                    Label("暂无产品", systemImage: "shippingbox")
                } description: {
                    Text("该分类下还没有产品")
                } actions: {
                    Button(action: { showAddProduct = true }) {
                        Text("添加产品")
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                List {
                    ForEach(products) { product in
                        NavigationLink(destination: ProductDetailView(product: product)) {
                            ProductRowView(product: product)
                        }
                    }
                }
#if os(iOS)
                .listStyle(.insetGrouped)
#else
                .listStyle(SidebarListStyle())
#endif
            }
        }
        .navigationTitle(category.categoryName)
        .toolbar {
            SwiftUI.ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(action: { showAddProduct = true }) {
                        Label("添加产品", systemImage: "plus")
                    }
                    
                    Button(action: { showingEditSheet = true }) {
                        Label("编辑分类", systemImage: "pencil")
                    }
                    
                    Button(role: .destructive, action: { showingDeleteAlert = true }) {
                        Label("删除分类", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            #if os(macOS)
            EditCategorySheet(category: category)
                .frame(minWidth: 500, minHeight: 400)
                .environment(\.managedObjectContext, viewContext)
            #else
            NavigationStack {
                EditCategorySheet(category: category)
                    .navigationTitle("编辑分类")
            }
            #endif
        }
        .sheet(isPresented: $showAddProduct) {
            NavigationStack {
                AddProductView(isPresented: $showAddProduct)
                    .environment(\.managedObjectContext, viewContext)
            }
            .presentationDetents([.large])
        }
        .alert("确定删除此分类?", isPresented: $showingDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) { deleteCategory() }
        } message: {
            Text("删除后，所有归属于该分类的产品将变为\"未分类\"。")
        }
    }
    
    private var categoryHeader: some View {
        VStack(spacing: 16) {
            HStack(spacing: 20) {
                // 分类图标
                Image(systemName: category.categoryIcon)
                    .font(.system(size: 40))
                    .frame(width: 80, height: 80)
                    .foregroundColor(.white)
                    .background(Color.accentColor)
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(category.categoryName)
                        .font(.title)
                        .bold()
                    
                    Text("共 \(products.count) 个产品")
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding()
            
            // 统计信息
            if products.count > 0 {
                HStack(spacing: 24) {
                    // 统计卡片
                    StatisticCard(
                        title: "最新添加",
                        value: products.first?.productName ?? "-",
                        icon: "clock",
                        color: .blue
                    )
                    
                    // 价值统计
                    StatisticCard(
                        title: "总价值",
                        value: String(format: "¥%.2f", calculateTotalValue()),
                        icon: "creditcard",
                        color: .green
                    )
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
        .background(Color.secondary.opacity(0.05))
    }
    
    private func calculateTotalValue() -> Double {
        products.compactMap { product -> Double? in
            guard let order = product.order else { return nil }
            var total = order.price?.doubleValue ?? 0
            
            // 加上维修成本
            if let repairRecords = order.repairRecords as? Set<RepairRecord> {
                total += repairRecords
                    .compactMap { $0.cost?.doubleValue }
                    .reduce(0, +)
            }
            
            return total > 0 ? total : nil
        }.reduce(0, +)
    }
    
    private func deleteCategory() {
        // 将属于此分类的产品设为无分类
        for product in products {
            product.category = nil
        }
        
        // 删除分类
        viewContext.delete(category)
        
        // 保存更改
        do {
            try viewContext.save()
        } catch {
            print("删除分类失败: \(error.localizedDescription)")
        }
    }
}

// 统计卡片组件
struct StatisticCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(value)
                .font(.headline)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

// 预览
#Preview {
    CategoryDetailView(category: Category.example)
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
