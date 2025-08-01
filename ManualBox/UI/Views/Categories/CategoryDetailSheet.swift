import SwiftUI

// MARK: - 分类详情界面
struct CategoryDetailSheet: View {
    let category: Category
    @StateObject private var categoryService = CategoryManagementService.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingEditSheet = false
    @State private var showingAddChildSheet = false
    @State private var showingDeleteAlert = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 分类头部信息
                    categoryHeader
                    
                    // 统计信息
                    statisticsSection
                    
                    // 层级信息
                    if category.level > 0 || category.hasChildren {
                        hierarchySection
                    }
                    
                    // 产品列表
                    productsSection
                    
                    // 子分类列表
                    if category.hasChildren {
                        childCategoriesSection
                    }
                    
                    // 操作按钮
                    actionsSection
                }
                .padding()
            }
            .navigationTitle("分类详情")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(content: {
                SwiftUI.ToolbarItem(placement: .navigationBarLeading) {
                    Button("返回") {
                        dismiss()
                    }
                }
                SwiftUI.ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveCategory()
                    }
                }
            })
            #else
            .toolbar(content: {
                SwiftUI.ToolbarItem(placement: .cancellationAction) {
                    Button("返回") {
                        dismiss()
                    }
                }
                SwiftUI.ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveCategory()
                    }
                }
            })
            #endif
        }
        .sheet(isPresented: $showingEditSheet) {
            EditCategorySheet(category: category)
        }
        .sheet(isPresented: $showingAddChildSheet) {
            AddCategorySheet(parentCategory: category)
        }
        .alert("删除分类", isPresented: $showingDeleteAlert) {
            Button("删除", role: .destructive) {
                deleteCategory()
            }
            Button("取消", role: .cancel) { }
        } message: {
            Text("确定要删除\(category.categoryName)吗？子分类和产品将被重新分配。")
        }
    }
    
    // MARK: - 分类头部
    private var categoryHeader: some View {
        VStack(spacing: 16) {
            // 图标和名称
            VStack(spacing: 12) {
                Image(systemName: category.categoryIcon)
                    .font(.system(size: 48))
                    .foregroundColor(Color(category.categoryColor))
                    .frame(width: 80, height: 80)
                    .background(Color(category.categoryColor).opacity(0.1))
                    .clipShape(Circle())
                
                Text(category.categoryName)
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
            }
            
            // 路径
            if category.level > 0 {
                Text(category.fullPath)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            // 创建时间
            if let createdAt = category.createdAt {
                Text("创建于 \(formatDate(createdAt))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(ModernColors.System.gray6))
        .cornerRadius(16)
    }
    
    // MARK: - 统计信息
    private var statisticsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("统计信息")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                StatCard(
                    title: "直接产品",
                    value: "\(category.productCount)",
                    color: .blue
                )
                
                StatCard(
                    title: "总产品数",
                    value: "\(category.totalProductCount)",
                    color: .green
                )
                
                StatCard(
                    title: "子分类数",
                    value: "\(category.childCategories.count)",
                    color: .orange
                )
                
                StatCard(
                    title: "层级深度",
                    value: "\(category.level + 1)",
                    color: .purple
                )
            }
            
            // 总价值
            if let totalValue = category.totalDescendantValue {
                HStack {
                    Image(systemName: "yensign.circle.fill")
                        .foregroundColor(.green)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("总价值")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("¥\(totalValue, specifier: "%.2f")")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                }
                .padding()
                .background(Color(ModernColors.Background.primary))
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
            }
        }
    }
    
    // MARK: - 层级信息
    private var hierarchySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("层级结构")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 8) {
                // 父分类
                if let parent = category.parent {
                    HierarchyRow(
                        title: "父分类",
                        category: parent,
                        icon: "arrow.up"
                    )
                }
                
                // 当前分类
                HierarchyRow(
                    title: "当前分类",
                    category: category,
                    icon: "circle.fill",
                    isCurrent: true
                )
                
                // 子分类
                if category.hasChildren {
                    ForEach(category.childCategories.prefix(3), id: \.id) { child in
                        HierarchyRow(
                            title: "子分类",
                            category: child,
                            icon: "arrow.down"
                        )
                    }
                    
                    if category.childCategories.count > 3 {
                        Text("还有 \(category.childCategories.count - 3) 个子分类...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.leading, 32)
                    }
                }
            }
            .padding()
            .background(Color(ModernColors.System.gray6))
            .cornerRadius(12)
        }
    }
    
    // MARK: - 产品列表
    private var productsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("产品列表")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(category.productCount) 个")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if category.categoryProducts.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "cube.box")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    
                    Text("暂无产品")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(ModernColors.System.gray6))
                .cornerRadius(8)
            } else {
                VStack(spacing: 8) {
                    ForEach(category.categoryProducts.prefix(5), id: \.id) { product in
                        ProductPreviewRow(product: product)
                    }
                    
                    if category.categoryProducts.count > 5 {
                        Text("还有 \(category.categoryProducts.count - 5) 个产品...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    // MARK: - 子分类列表
    private var childCategoriesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("子分类")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(category.childCategories.count) 个")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 8) {
                ForEach(category.childCategories, id: \.id) { child in
                    ChildCategoryRow(category: child)
                }
            }
        }
    }
    
    // MARK: - 操作按钮
    private var actionsSection: some View {
        VStack(spacing: 12) {
            Button(action: {
                showingAddChildSheet = true
            }) {
                HStack {
                    Image(systemName: "plus")
                    Text("添加子分类")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            
            Button(action: {
                showingDeleteAlert = true
            }) {
                HStack {
                    Image(systemName: "trash")
                    Text("删除分类")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .foregroundColor(.red)
        }
    }
    
    // MARK: - 辅助方法
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func deleteCategory() {
        Task {
            do {
                try await categoryService.deleteCategory(category)
                await MainActor.run {
                    dismiss()
                }
            } catch {
                print("删除分类失败: \(error)")
            }
        }
    }
    
    private func saveCategory() {
        // Implementation of saveCategory method
    }
}

// MARK: - 层级行
struct HierarchyRow: View {
    let title: String
    let category: Category
    let icon: String
    let isCurrent: Bool
    
    init(title: String, category: Category, icon: String, isCurrent: Bool = false) {
        self.title = title
        self.category = category
        self.icon = icon
        self.isCurrent = isCurrent
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(isCurrent ? .accentColor : .secondary)
                .frame(width: 16)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .leading)
            
            Image(systemName: category.categoryIcon)
                .font(.body)
                .foregroundColor(Color(category.categoryColor))
            
            Text(category.categoryName)
                .font(.body)
                .fontWeight(isCurrent ? .semibold : .regular)
                .foregroundColor(isCurrent ? .accentColor : .primary)
            
            Spacer()
            
            Text("\(category.productCount)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - 产品预览行
struct ProductPreviewRow: View {
    let product: Product
    
    var body: some View {
        HStack(spacing: 12) {
            // 产品图片占位符
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(ModernColors.System.gray5))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "cube.box")
                        .foregroundColor(.secondary)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(product.productName)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                if let brand = product.brand {
                    Text(brand)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            if let price = product.order?.price?.doubleValue {
                Text("¥\(price, specifier: "%.2f")")
                    .font(.caption)
                    .foregroundColor(.green)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color(ModernColors.Background.primary))
        .cornerRadius(8)
    }
}

// MARK: - 子分类行
struct ChildCategoryRow: View {
    let category: Category
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: category.categoryIcon)
                .font(.title3)
                .foregroundColor(Color(category.categoryColor))
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(category.categoryName)
                    .font(.body)
                    .fontWeight(.medium)
                
                Text("\(category.totalProductCount) 个产品")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if category.hasChildren {
                Text("\(category.childCategories.count) 个子分类")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color(ModernColors.Background.primary))
        .cornerRadius(8)
    }
}

// MARK: - 统计卡片 (使用共享的 StatCard 组件)

#Preview {
    CategoryDetailSheet(category: Category.example)
}
