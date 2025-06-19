//
//  MainTabView.swift
//  ManualBox
//
//  Created by Peter's Mac on 2025/5/10.
//

import SwiftUI
import CoreData
import Foundation

// 创建 EnvironmentKey 传递选中产品状态
struct SelectedProductKey: EnvironmentKey {
    static var defaultValue: Binding<Product?> = .constant(nil)
}

extension EnvironmentValues {
    var selectedProduct: Binding<Product?> {
        get { self[SelectedProductKey.self] }
        set { self[SelectedProductKey.self] = newValue }
    }
}

struct MainTabView: View {
    @AppStorage("appTheme") private var appTheme: String = "system"
    @AppStorage("accentColor") private var accentColorKey: String = "accentColor"
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var notificationManager: AppNotificationManager
    @StateObject private var notificationObserver = NotificationObserver()
    
    @State private var selectedTab: SelectionValue? = .main(0)
    @State private var selectedProduct: Product? = nil
    @State private var showingAddProduct = false
    
    // 产品相关状态
    @State private var searchText = ""
    @State private var isEditing = false
    
    @FetchRequest(
        entity: Category.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Category.name, ascending: true)]
    ) private var categoriesRaw: FetchedResults<Category>

    // 自定义排序的分类列表，确保"其他"在最后
    private var categories: [Category] {
        return categoriesRaw.sorted { category1, category2 in
            let priority1 = category1.sortPriority
            let priority2 = category2.sortPriority

            if priority1 != priority2 {
                return priority1 < priority2
            } else {
                return category1.categoryName < category2.categoryName
            }
        }
    }
    
    @FetchRequest(
        entity: Tag.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Tag.name, ascending: true)]
    ) private var tags: FetchedResults<Tag>
    
    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \Product.updatedAt, ascending: false),
            NSSortDescriptor(keyPath: \Product.createdAt, ascending: false)
        ],
        animation: .default
    )
    private var products: FetchedResults<Product>
    
    // 计算属性：过滤后的产品列表
    private var filteredProducts: [Product] {
        return Array(products).filter { product in
            if searchText.isEmpty {
                return true
            }
            let searchLower = searchText.lowercased()
            return product.name?.lowercased().contains(searchLower) == true ||
                   product.brand?.lowercased().contains(searchLower) == true ||
                   product.model?.lowercased().contains(searchLower) == true
        }
    }
    
    // 删除产品函数
    private func deleteProducts(offsets: IndexSet) {
        withAnimation {
            offsets.map { filteredProducts[$0] }.forEach(viewContext.delete)
            
            do {
                try viewContext.save()
            } catch {
                // 处理错误
                print("删除产品失败: \(error)")
            }
        }
    }
    
    var body: some View {
        // 主题设置
        let colorScheme: ColorScheme? = {
            switch appTheme {
            case "light": return .light
            case "dark": return .dark
            default: return nil
            }
        }()
        let accentColor: Color = {
            switch accentColorKey {
            case "blue": return .blue
            case "green": return .green
            case "orange": return .orange
            case "pink": return .pink
            case "purple": return .purple
            case "red": return .red
            default: return .accentColor
            }
        }()
        UnifiedSplitView(
            selection: $selectedTab,
            selectedItem: $selectedProduct,
            sidebar: {
                #if os(macOS)
                SidebarView(selection: $selectedTab)
                #else
                EmptyView()
                #endif
            },
            content: {
                // 内容区：根据选中Tab/分类/标签动态切换
                ZStack {
                    if let selection = selectedTab {
                        switch selection {
                        case .main(let index):
                            switch index {
                            case 0:
                                EnhancedProductListView(
                                    filteredProducts: filteredProducts,
                                    searchText: searchText,
                                    deleteProducts: deleteProducts
                                )
                                    .environment(\.selectedProduct, $selectedProduct)
                                    .adaptiveLayout()
                            case 1:
                                ContentUnavailableView {
                                    Label("分类管理", systemImage: "folder")
                                } description: {
                                    Text("请从左侧选择一个分类查看相关产品")
                                }
                            case 2:
                                ContentUnavailableView {
                                    Label("标签管理", systemImage: "tag")
                                } description: {
                                    Text("请从左侧选择一个标签查看相关产品")
                                }
                            case 3:
                                RepairRecordsView()
                            default:
                                #if os(macOS)
                                EnhancedProductListView(
                                    filteredProducts: filteredProducts,
                                    searchText: searchText,
                                    deleteProducts: deleteProducts
                                )
                                    .environment(\.selectedProduct, $selectedProduct)
                                #else
                                EnhancedProductListView(
                                    filteredProducts: filteredProducts,
                                    searchText: searchText,
                                    deleteProducts: deleteProducts
                                )
                                    .environment(\.selectedProduct, $selectedProduct)
                                #endif
                            }
                        case .category(let id):
                            if let category = categories.first(where: { $0.id == id }) {
                                CategoryDetailView(category: category)
                                    .environment(\.selectedProduct, $selectedProduct)
                                    .adaptiveLayout()
                            } else {
                                EnhancedProductListView(
                                    filteredProducts: filteredProducts,
                                    searchText: searchText,
                                    deleteProducts: deleteProducts
                                )
                                    .environment(\.selectedProduct, $selectedProduct)
                                    .adaptiveLayout()
                            }
                        case .tag(let id):
                            if let tag = tags.first(where: { $0.id == id }) {
                                TagDetailView(tag: tag)
                                    .environment(\.selectedProduct, $selectedProduct)
                                    .adaptiveLayout()
                            } else {
                                EnhancedProductListView(
                                    filteredProducts: filteredProducts,
                                    searchText: searchText,
                                    deleteProducts: deleteProducts
                                )
                                    .environment(\.selectedProduct, $selectedProduct)
                                    .adaptiveLayout()
                            }
                        case .settings(let panel):
                            settingsDetailView(for: panel)
                        }
                    } else {
                        #if os(macOS)
                        EnhancedProductListView(
                            filteredProducts: filteredProducts,
                            searchText: searchText,
                            deleteProducts: deleteProducts
                        )
                            .environment(\.selectedProduct, $selectedProduct)
                        #else
                        EnhancedProductListView(
                            filteredProducts: filteredProducts,
                            searchText: searchText,
                            deleteProducts: deleteProducts
                        )
                            .environment(\.selectedProduct, $selectedProduct)
                        #endif
                    }
                }
            },
            detail: {
                // 详情区
                if let selection = selectedTab {
                    switch selection {
                    case .main(let index):
                        switch index {
                        case 0:
                            if let product = selectedProduct {
                                ProductDetailView(product: product)
                                    .id(product.id?.uuidString ?? "unknown")
                            } else {
                                ContentUnavailableView {
                                    Label("暂无选中商品", systemImage: "shippingbox")
                                } description: {
                                    Text("请从列表中选择一个商品查看详情")
                                }
                            }
                        case 1:
                            CategoryDetailView(category: categories.first ?? Category(context: viewContext))
                        case 2:
                            TagDetailView(tag: tags.first ?? Tag(context: viewContext))
                        case 3:
                            EmptyView()
                        default:
                            EmptyView()
                        }
                    case .settings(_):
                        EmptyView()
                    case .category(let id):
                        if let category = categories.first(where: { $0.id == id }) {
                            if let product = selectedProduct {
                                ProductDetailView(product: product)
                                    .id(product.id?.uuidString ?? "unknown")
                            } else {
                                ContentUnavailableView {
                                    Label("请选择产品", systemImage: "hand.tap")
                                } description: {
                                    Text("从左侧\"\(category.categoryName)\"分类中选择一个产品查看详情")
                                }
                            }
                        }
                    case .tag(let id):
                        if let tag = tags.first(where: { $0.id == id }) {
                            if let product = selectedProduct {
                                ProductDetailView(product: product)
                                    .id(product.id?.uuidString ?? "unknown")
                            } else {
                                ContentUnavailableView {
                                    Label("请选择产品", systemImage: "hand.tap")
                                } description: {
                                    Text("从左侧\"\(tag.tagName)\"标签中选择一个产品查看详情")
                                }
                            }
                        }
                    }
                } else {
                    ContentUnavailableView {
                        Label("暂无选中内容", systemImage: "square.3.layers.3d")
                    } description: {
                        Text("请从左侧选择要查看的内容")
                    }
                }
            }
        )
        .preferredColorScheme(colorScheme)
        .accentColor(accentColor)
        .toolbar(content: {
            SwiftUI.ToolbarItem(placement: .primaryAction) {
                Button(action: { showingAddProduct = true }) {
                    Label("添加产品", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
        })
        .sheet(isPresented: $showingAddProduct) {
            QuickAddProductView(isPresented: $showingAddProduct)
                #if os(iOS)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                #endif
        }
        .onAppNotification(.createNewProduct) { _ in
            showingAddProduct = true
        }
        .onAppear {
            notificationManager.updateAllWarrantyReminders(in: viewContext)
            setupNotificationObservers()
        }
        .onChange(of: selectedTab) { oldValue, newValue in
            // 当选中的标签页改变时，清空选中的商品
            if oldValue != newValue {
                selectedProduct = nil
            }
        }
    }

    // 设置详情视图
    @ViewBuilder
    private func settingsDetailView(for panel: SettingsPanel) -> some View {
        switch panel {
        case .notification:
            NotificationAdvancedSettingsPanel()
        case .theme:
            ThemeSettingsPanel()
        case .data:
            DataSettingsPanel(
                defaultWarrantyPeriod: Binding(
                    get: { UserDefaults.standard.integer(forKey: "defaultWarrantyPeriod") == 0 ? 12 : UserDefaults.standard.integer(forKey: "defaultWarrantyPeriod") },
                    set: { UserDefaults.standard.set($0, forKey: "defaultWarrantyPeriod") }
                ),
                enableOCRByDefault: Binding(
                    get: { UserDefaults.standard.bool(forKey: "enableOCRByDefault") },
                    set: { UserDefaults.standard.set($0, forKey: "enableOCRByDefault") }
                )
            )
        case .about:
            AboutSettingsPanel(
                showPrivacySheet: .constant(false),
                showAgreementSheet: .constant(false)
            )
        }
    }

    private func setupNotificationObservers() {
        // 产品导航通知
        notificationObserver.observe(.showProduct) { object in
            if let _ = object as? UUID,
               case let currentValue = selectedTab,
               !(currentValue == nil || (currentValue != nil && 
                    (currentValue! == .main(0) || 
                     (currentValue! == .main(1) && categories.isEmpty) || 
                     (currentValue! == .main(2) && tags.isEmpty)))) {
                // 如果不是在产品列表视图，则转到产品列表
                selectedTab = .main(0)
            }
        }
        
        // 分类导航通知
        notificationObserver.observe(.showCategory) { object in
            if let categoryId = object as? UUID,
               let _ = categories.first(where: { $0.id == categoryId }) {
                selectedTab = .category(categoryId)
            }
        }
        
        // 标签导航通知
        notificationObserver.observe(.showTag) { object in
            if let tagId = object as? UUID,
               let _ = tags.first(where: { $0.id == tagId }) {
                selectedTab = .tag(tagId)
            }
        }
    }
}

#if os(macOS)
struct AddProductSheet: View {
    @Binding var isPresented: Bool
    @Environment(\.managedObjectContext) private var viewContext
    
    var body: some View {
        AddProductView(isPresented: $isPresented)
            .frame(minWidth: 600, minHeight: 600) // 高度提升为 600，更适合表单
            .environment(\.managedObjectContext, viewContext)
            .formStyle(.grouped)
    }
}

// macOS 侧边栏视图
struct SidebarView: View {
    @Binding var selection: SelectionValue?
    @Environment(\.managedObjectContext) private var viewContext

    @State private var showingAddCategorySheet = false
    @State private var showingAddTagSheet = false
    
    @FetchRequest(
        entity: Category.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Category.name, ascending: true)]
    ) private var categoriesRaw: FetchedResults<Category>

    // 自定义排序的分类列表，确保"其他"在最后
    private var categories: [Category] {
        return categoriesRaw.sorted { category1, category2 in
            let priority1 = category1.sortPriority
            let priority2 = category2.sortPriority

            if priority1 != priority2 {
                return priority1 < priority2
            } else {
                return category1.categoryName < category2.categoryName
            }
        }
    }
    
    @FetchRequest(
        entity: Tag.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Tag.name, ascending: true)]
    ) private var tags: FetchedResults<Tag>
    
    var body: some View {
        List(selection: $selection) {
            Label("所有商品", systemImage: "shippingbox")
                .tag(SelectionValue.main(0))
                .accessibilityLabel("所有商品")
                .accessibilityHint("查看所有商品列表")
            
            Section(header: Text("分类")) {
                ForEach(categories) { category in
                    if let id = category.id {
                        Label(category.categoryName, systemImage: category.categoryIcon)
                            .badge(category.productCount)
                            .tag(SelectionValue.category(id))
                            .accessibilityLabel("\(category.categoryName)分类")
                            .accessibilityHint("查看\(category.categoryName)分类下的商品，共\(category.productCount)个")
                            .contextMenu {
                                Button(action: {
                                    // 编辑分类功能 - 这里需要实现
                                }) {
                                    Label("编辑分类", systemImage: "pencil")
                                }

                                Divider()

                                Button(role: .destructive, action: {
                                    // 删除分类功能 - 这里需要实现
                                }) {
                                    Label("删除分类", systemImage: "trash")
                                }
                            }
                    }
                }

                // 添加分类按钮
                Button(action: { showingAddCategorySheet = true }) {
                    Label("添加分类", systemImage: "plus")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("添加新分类")
                .accessibilityHint("点击添加新的商品分类")
            }
            
            Section(header: Text("标签")) {
                ForEach(tags) { tag in
                    if let id = tag.id {
                        Label {
                            Text(tag.tagName)
                                .badge(tag.productCount)
                        } icon: {
                            Image(systemName: "tag.fill")
                                .foregroundColor(tag.uiColor)
                        }
                        .tag(SelectionValue.tag(id))
                        .accessibilityLabel("\(tag.tagName)标签")
                        .accessibilityHint("查看\(tag.tagName)标签下的商品，共\(tag.productCount)个")
                        .contextMenu {
                            Button(action: {
                                // 编辑标签功能 - 这里需要实现
                            }) {
                                Label("编辑标签", systemImage: "pencil")
                            }

                            Divider()

                            Button(role: .destructive, action: {
                                // 删除标签功能 - 这里需要实现
                            }) {
                                Label("删除标签", systemImage: "trash")
                            }
                        }
                    }
                }

                // 添加标签按钮
                Button(action: { showingAddTagSheet = true }) {
                    Label("添加标签", systemImage: "plus")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("添加新标签")
                .accessibilityHint("点击添加新的商品标签")
            }
            
            Section(header: Text("维修管理")) {
                Label("维修记录", systemImage: "wrench.and.screwdriver")
                    .tag(SelectionValue.main(3))
                    .accessibilityLabel("维修记录")
                    .accessibilityHint("查看和管理设备维修记录")
            }
            
            Section(header: Text("设置")) {
                // 设置选项
                ForEach(SettingsPanel.allCases, id: \.self) { panel in
                    Label(panel.title, systemImage: panel.icon)
                        .tag(SelectionValue.settings(panel))
                        .accessibilityLabel(panel.title)
                        .accessibilityHint("打开\(panel.title)设置")
                }
            }
        }
        .listStyle(SidebarListStyle())
        .frame(minWidth: 200, idealWidth: 250, maxWidth: 320) // maxWidth 统一为 320
        .accessibilityLabel("主导航")
        .accessibilityHint("选择要浏览的内容分类")
        .sheet(isPresented: $showingAddCategorySheet) {
            AddCategorySheet(isPresented: $showingAddCategorySheet)
                .frame(minWidth: 400, minHeight: 300)
                .environment(\.managedObjectContext, viewContext)
        }
        .sheet(isPresented: $showingAddTagSheet) {
            AddTagSheet(isPresented: $showingAddTagSheet)
                .frame(minWidth: 400, minHeight: 300)
                .environment(\.managedObjectContext, viewContext)
        }
    }
}
#endif

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
            .environmentObject(AppNotificationManager())
    }
}
