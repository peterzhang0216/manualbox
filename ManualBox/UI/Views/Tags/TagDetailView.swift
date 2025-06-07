import SwiftUI
import CoreData



struct TagDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    let tag: Tag
    
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    @State private var showAddProduct = false
    
    @FetchRequest private var products: FetchedResults<Product>
    
    init(tag: Tag) {
        self.tag = tag
        
        // 创建针对该标签的产品查询
        _products = FetchRequest<Product>(
            sortDescriptors: [
                NSSortDescriptor(keyPath: \Product.updatedAt, ascending: false),
                NSSortDescriptor(keyPath: \Product.name, ascending: true)
            ],
            predicate: NSPredicate(format: "ANY tags == %@", tag),
            animation: .default
        )
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 标签信息头部
            tagHeader
            
            Divider()
            
            // 产品列表
            if products.isEmpty {
                ContentUnavailableView {
                    Label("暂无产品", systemImage: "shippingbox")
                } description: {
                    Text("该标签下还没有产品")
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
        .navigationTitle(tag.tagName)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(action: { showAddProduct = true }) {
                        Label("添加产品", systemImage: "plus")
                    }
                    
                    Button(action: { showingEditSheet = true }) {
                        Label("编辑标签", systemImage: "pencil")
                    }
                    
                    Button(role: .destructive, action: { showingDeleteAlert = true }) {
                        Label("删除标签", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            #if os(macOS)
            EditTagSheet(tag: tag)
                .frame(minWidth: 500, minHeight: 400)
                .environment(\.managedObjectContext, viewContext)
            #else
            NavigationStack {
                EditTagSheet(tag: tag)
                    .navigationTitle("编辑标签")
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
        .alert("确定删除此标签?", isPresented: $showingDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) { deleteTag() }
        } message: {
            Text("删除后，所有关联此标签的产品将不再拥有此标签。")
        }
    }
    
    private var tagHeader: some View {
        VStack(spacing: 16) {
            HStack(spacing: 20) {
                // 标签图标
                ZStack {
                    Circle()
                        .fill(tag.uiColor)
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "tag.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(tag.tagName)
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
    
    private func deleteTag() {
        // 将此标签从所有产品中移除
        for product in products {
            product.removeTag(tag)
        }
        
        // 删除标签
        viewContext.delete(tag)
        
        // 保存更改
        do {
            try viewContext.save()
        } catch {
            print("删除标签失败: \(error.localizedDescription)")
        }
    }
}

// 预览
#Preview {
    TagDetailView(tag: Tag.example)
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
