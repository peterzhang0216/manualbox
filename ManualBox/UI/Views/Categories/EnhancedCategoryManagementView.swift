import SwiftUI
import CoreData

// MARK: - 增强分类管理视图
struct EnhancedCategoryManagementView: View {
    @StateObject private var categoryService = CategoryManagementService.shared
    @Environment(\.managedObjectContext) private var viewContext
    
    @State private var selectedCategory: Category?
    @State private var showingAddCategory = false
    @State private var showingEditCategory = false
    @State private var showingCategoryDetail = false
    @State private var showingStatistics = false
    @State private var showingBatchOperations = false
    
    @State private var searchText = ""
    @State private var selectedCategories: Set<Category> = []
    @State private var isEditMode = false
    @State private var viewMode: CategoryViewMode = .tree
    
    private var filteredCategories: [Category] {
        if searchText.isEmpty {
            return categoryService.categories
        } else {
            return categoryService.categories.filter {
                $0.categoryName.localizedCaseInsensitiveContains(searchText) ||
                $0.fullPath.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 搜索栏
                searchBar
                
                // 工具栏
                toolbar
                
                Divider()
                
                // 主内容区域
                mainContent
            }
            .navigationTitle("分类管理")
            #if os(macOS)
            .platformNavigationBarTitleDisplayMode(0)
            #else
            .platformNavigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                SwiftUI.ToolbarItem(placement: .platformLeading) {
                    Button(isEditMode ? "完成" : "编辑") {
                        withAnimation {
                            isEditMode.toggle()
                            if !isEditMode {
                                selectedCategories.removeAll()
                            }
                        }
                    }
                }
                
                SwiftUI.ToolbarItem(placement: .platformTrailing) {
                    Menu {
                        Button(action: {
                            showingAddCategory = true
                        }) {
                            Label("添加分类", systemImage: "plus")
                        }
                        
                        Button(action: {
                            showingStatistics = true
                        }) {
                            Label("统计信息", systemImage: "chart.bar")
                        }
                        
                        Divider()
                        
                        Button(action: exportCategories) {
                            Label("导出分类", systemImage: "square.and.arrow.up")
                        }
                        
                        Button(action: importCategories) {
                            Label("导入分类", systemImage: "square.and.arrow.down")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddCategory) {
            AddCategorySheet(parentCategory: selectedCategory)
        }
        .sheet(isPresented: $showingEditCategory) {
            if let category = selectedCategory {
                EditCategorySheet(category: category)
            }
        }
        .sheet(isPresented: $showingCategoryDetail) {
            if let category = selectedCategory {
                CategoryDetailSheet(category: category)
            }
        }
        .sheet(isPresented: $showingStatistics) {
            CategoryStatisticsView()
        }
        .sheet(isPresented: $showingBatchOperations) {
            BatchOperationsSheet(selectedCategories: Array(selectedCategories))
        }
        .onAppear {
            categoryService.loadCategories()
        }
    }
    
    // MARK: - 搜索栏
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("搜索分类...", text: $searchText)
                .textFieldStyle(.plain)
            
            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.platformSystemGray6)
        .cornerRadius(8)
        .padding()
    }
    
    // MARK: - 工具栏
    private var toolbar: some View {
        HStack {
            // 视图模式切换
            Picker("视图模式", selection: $viewMode) {
                Text("树形").tag(CategoryViewMode.tree)
                Text("列表").tag(CategoryViewMode.list)
                Text("网格").tag(CategoryViewMode.grid)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 200)
            
            Spacer()
            
            // 批量操作按钮
            if isEditMode && !selectedCategories.isEmpty {
                Button("批量操作") {
                    showingBatchOperations = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
    
    // MARK: - 主内容
    private var mainContent: some View {
        Group {
            if categoryService.isLoading {
                ProgressView("加载中...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredCategories.isEmpty {
                emptyStateView
            } else {
                switch viewMode {
                case .tree:
                    treeView
                case .list:
                    listView
                case .grid:
                    gridView
                }
            }
        }
    }
    
    // MARK: - 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text(searchText.isEmpty ? "暂无分类" : "未找到匹配的分类")
                .font(.title2)
                .fontWeight(.medium)
            
            Text(searchText.isEmpty ? "点击右上角菜单添加第一个分类" : "尝试使用不同的搜索关键词")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            if searchText.isEmpty {
                Button("添加分类") {
                    showingAddCategory = true
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.platformSystemBackground)
    }
    
    // MARK: - 树形视图
    private var treeView: some View {
        List {
            ForEach(categoryService.getCategoryTree(), id: \.id) { node in
                CategoryTreeRow(
                    node: node,
                    isEditMode: isEditMode,
                    selectedCategories: $selectedCategories,
                    onTap: { category in
                        handleCategoryTap(category)
                    },
                    onEdit: { category in
                        selectedCategory = category
                        showingEditCategory = true
                    }
                )
            }
        }
        .listStyle(.sidebar)
    }
    
    // MARK: - 列表视图
    private var listView: some View {
        List {
            ForEach(filteredCategories, id: \.id) { category in
                CategoryListRow(
                    category: category,
                    isEditMode: isEditMode,
                    isSelected: selectedCategories.contains(category),
                    onTap: {
                        handleCategoryTap(category)
                    },
                    onToggleSelection: {
                        toggleCategorySelection(category)
                    },
                    onEdit: {
                        selectedCategory = category
                        showingEditCategory = true
                    }
                )
            }
        }
        .platformListStyle()
    }
    
    // MARK: - 网格视图
    private var gridView: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 160))
            ], spacing: 16) {
                ForEach(filteredCategories, id: \.id) { category in
                    CategoryGridCard(
                        category: category,
                        isEditMode: isEditMode,
                        isSelected: selectedCategories.contains(category),
                        onTap: {
                            handleCategoryTap(category)
                        },
                        onToggleSelection: {
                            toggleCategorySelection(category)
                        },
                        onEdit: {
                            selectedCategory = category
                            showingEditCategory = true
                        }
                    )
                }
            }
            .padding()
        }
    }
    
    // MARK: - 操作方法
    
    private func handleCategoryTap(_ category: Category) {
        if isEditMode {
            toggleCategorySelection(category)
        } else {
            selectedCategory = category
            showingCategoryDetail = true
        }
    }
    
    private func toggleCategorySelection(_ category: Category) {
        if selectedCategories.contains(category) {
            selectedCategories.remove(category)
        } else {
            selectedCategories.insert(category)
        }
    }
    
    private func exportCategories() {
        // 实现导出功能
        print("导出分类")
    }
    
    private func importCategories() {
        // 实现导入功能
        print("导入分类")
    }
}

// MARK: - 视图模式枚举
enum CategoryViewMode: String, CaseIterable {
    case tree = "tree"
    case list = "list"
    case grid = "grid"
    
    var displayName: String {
        switch self {
        case .tree: return "树形"
        case .list: return "列表"
        case .grid: return "网格"
        }
    }
}

// MARK: - 分类树形行
struct CategoryTreeRow: View {
    let node: CategoryNode
    let isEditMode: Bool
    @Binding var selectedCategories: Set<Category>
    let onTap: (Category) -> Void
    let onEdit: (Category) -> Void

    @State private var isExpanded = true

    private var isSelected: Bool {
        selectedCategories.contains(node.category)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 主行
            HStack(spacing: 12) {
                // 展开/收起按钮
                if node.hasChildren {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isExpanded.toggle()
                        }
                    }) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 12, height: 12)
                    }
                    .buttonStyle(.plain)
                } else {
                    Spacer()
                        .frame(width: 12, height: 12)
                }

                // 选择框（编辑模式）
                if isEditMode {
                    Button(action: {
                        onTap(node.category)
                    }) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(isSelected ? .accentColor : .secondary)
                    }
                    .buttonStyle(.plain)
                }

                // 分类图标
                Image(systemName: node.category.categoryIcon)
                    .font(.title3)
                    .foregroundColor(Color(node.category.categoryColor))
                    .frame(width: 24, height: 24)

                // 分类信息
                VStack(alignment: .leading, spacing: 2) {
                    Text(node.category.categoryName)
                        .font(.body)
                        .fontWeight(.medium)

                    HStack(spacing: 8) {
                        Text("\(node.category.productCount) 个产品")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if node.hasChildren {
                            Text("\(node.children.count) 个子分类")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()

                // 编辑按钮
                if !isEditMode {
                    Button(action: {
                        onEdit(node.category)
                    }) {
                        Image(systemName: "pencil")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .onTapGesture {
                if !isEditMode {
                    onTap(node.category)
                }
            }

            // 子分类
            if isExpanded && node.hasChildren {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(node.children, id: \.id) { childNode in
                        HStack {
                            Rectangle()
                                .fill(Color.secondary.opacity(0.3))
                                .frame(width: 1)
                                .padding(.leading, 24)

                            CategoryTreeRow(
                                node: childNode,
                                isEditMode: isEditMode,
                                selectedCategories: $selectedCategories,
                                onTap: onTap,
                                onEdit: onEdit
                            )
                            .padding(.leading, 8)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - 分类列表行
struct CategoryListRow: View {
    let category: Category
    let isEditMode: Bool
    let isSelected: Bool
    let onTap: () -> Void
    let onToggleSelection: () -> Void
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // 选择框（编辑模式）
            if isEditMode {
                Button(action: onToggleSelection) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? .accentColor : .secondary)
                }
                .buttonStyle(.plain)
            }

            // 分类图标
            Image(systemName: category.categoryIcon)
                .font(.title2)
                .foregroundColor(Color(category.categoryColor))
                .frame(width: 32, height: 32)

            // 分类信息
            VStack(alignment: .leading, spacing: 4) {
                Text(category.categoryName)
                    .font(.headline)
                    .fontWeight(.medium)

                if category.level > 0 {
                    Text(category.fullPath)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: 12) {
                    Label("\(category.productCount)", systemImage: "cube.box")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if category.hasChildren {
                        Label("\(category.childCategories.count)", systemImage: "folder")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if let value = category.totalProductValue {
                        Text("¥\(value, specifier: "%.2f")")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }

            Spacer()

            // 编辑按钮
            if !isEditMode {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}

// MARK: - 分类网格卡片
struct CategoryGridCard: View {
    let category: Category
    let isEditMode: Bool
    let isSelected: Bool
    let onTap: () -> Void
    let onToggleSelection: () -> Void
    let onEdit: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            // 选择框（编辑模式）
            if isEditMode {
                HStack {
                    Button(action: onToggleSelection) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(isSelected ? .accentColor : .secondary)
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
            }

            // 分类图标
            Image(systemName: category.categoryIcon)
                .font(.system(size: 32))
                .foregroundColor(Color(category.categoryColor))
                .frame(width: 48, height: 48)

            // 分类名称
            Text(category.categoryName)
                .font(.headline)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            // 统计信息
            VStack(spacing: 4) {
                Text("\(category.productCount) 个产品")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if category.hasChildren {
                    Text("\(category.childCategories.count) 个子分类")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // 编辑按钮
            if !isEditMode {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.platformSystemGray6)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}

#Preview {
    EnhancedCategoryManagementView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
