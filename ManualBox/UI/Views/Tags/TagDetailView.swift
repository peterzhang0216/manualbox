import SwiftUI
import CoreData



struct TagDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var detailPanelStateManager: DetailPanelStateManager
    let tag: Tag

    @State private var showingDeleteAlert = false

    #if os(macOS)
    @Environment(\.selectedProduct) private var selectedProduct
    #endif
    
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
                VStack {
                    ContentUnavailableView {
                        Label("暂无产品", systemImage: "shippingbox")
                    } description: {
                        Text("该标签下还没有产品")
                    } actions: {
                        Button(action: { detailPanelStateManager.showAddProduct() }) {
                            Text("添加产品")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    Spacer()
                }
            } else {
                List {
                    ForEach(products) { product in
                        #if os(iOS)
                        NavigationLink(destination: ProductDetailView(product: product)) {
                            ProductRow(product: product)
                        }
                        #else
                        ProductRow(product: product)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedProduct.wrappedValue = product
                            }
                        #endif
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

                // 标签管理按钮
                HStack(spacing: 8) {
                    Button(action: { detailPanelStateManager.showEditTag(tag) }) {
                        Image(systemName: "pencil")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .help("编辑标签")

                    Button(action: { showingDeleteAlert = true }) {
                        Image(systemName: "trash")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)
                    .help("删除标签")
                }
            }
            .padding()
            
            // 统计信息 - 始终显示
            HStack(spacing: 24) {
                // 统计卡片
                StatisticCard(
                    title: "最新添加",
                    value: products.first?.productName ?? "暂无产品",
                    icon: "clock",
                    color: .blue
                )

                // 价值统计
                StatisticCard(
                    title: "总价值",
                    value: products.count > 0 ? String(format: "¥%.2f", calculateTotalValue()) : "¥0.00",
                    icon: "creditcard",
                    color: .green
                )
            }
            .padding(.horizontal)
            .padding(.bottom)
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
