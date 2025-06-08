//
//  MainTabView.swift
//  ManualBox
//
//  Created by Peter's Mac on 2025/5/10.
//

import SwiftUI
import CoreData



// 添加 SelectionValue 枚举来统一处理选择类型
enum SelectionValue: Hashable {
    case main(Int)
    case category(UUID)
    case tag(UUID)
}

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
    
    @FetchRequest(
        entity: Category.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Category.name, ascending: true)]
    ) private var categories: FetchedResults<Category>
    
    @FetchRequest(
        entity: Tag.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Tag.name, ascending: true)]
    ) private var tags: FetchedResults<Tag>
    
    var body: some View {
        // 主题设置
        let colorScheme: ColorScheme? = {
            switch appTheme {
            case "light": return .light
            case "dark": return .dark
            default: return nil
            }
        }()
        
        // 主题色设置
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
        
        Group {
            #if os(iOS)
            TabView(selection: Binding(
                get: {
                    if case let .main(index) = selectedTab ?? .main(0) {
                        return index
                    }
                    return 0
                },
                set: { selectedTab = .main($0) }
            )) {
                NavigationView {
                    ProductListView()
                }
                .tabItem {
                    Label("商品", systemImage: "shippingbox")
                }
                .tag(0)
                
                NavigationView {
                    CategoriesView()
                }
                .tabItem {
                    Label("分类", systemImage: "folder")
                }
                .tag(1)
                
                NavigationView {
                    TagsView()
                }
                .tabItem {
                    Label("标签", systemImage: "tag")
                }
                .tag(2)
                
                NavigationView {
                    RepairRecordsView()
                }
                .tabItem {
                    Label("维修", systemImage: "wrench.and.screwdriver")
                }
                .tag(3)
                
                NavigationView {
                    SettingsView()
                }
                .tabItem {
                    Label("设置", systemImage: "gear")
                }
                .tag(4)
            }
            .sheet(isPresented: $showingAddProduct) {
                NavigationView {
                    AddProductView(isPresented: $showingAddProduct)
                }
                .navigationViewStyle(StackNavigationViewStyle())
            }
            .onAppNotification(.createNewProduct) { _ in
                showingAddProduct = true
            }
            .onAppear {
                // 更新所有保修提醒
                notificationManager.updateAllWarrantyReminders(in: viewContext)
                
                // 设置通知观察者
                setupNotificationObservers()
            }
            #else
            // macOS 使用三列 NavigationSplitView
            NavigationSplitView {
                // 第一列：侧边栏
                SidebarView(selection: $selectedTab)
            } content: {
                // 第二列：产品列表
                ZStack {
                    if let selection = selectedTab {
                        switch selection {
                        case .main(let index):
                            switch index {
                            case 0:
                                ProductListView()
                                    .id("main-\(index)")
                                    .environment(\.selectedProduct, $selectedProduct)
                            case 1:
                                // 分类管理页面 - 显示空白或说明页面，避免重复显示分类
                                ContentUnavailableView {
                                    Label("分类管理", systemImage: "folder")
                                } description: {
                                    Text("请从左侧选择一个分类查看相关产品")
                                }
                                .id("main-\(index)")
                            case 2:
                                // 标签管理页面 - 显示空白或说明页面，避免重复显示标签
                                ContentUnavailableView {
                                    Label("标签管理", systemImage: "tag")
                                } description: {
                                    Text("请从左侧选择一个标签查看相关产品")
                                }
                                .id("main-\(index)")
                            case 3:
                                RepairRecordsView()
                                    .id("main-\(index)")
                            case 4:
                                SettingsView()
                                    .id("main-\(index)")
                            default:
                                ProductListView()
                                    .id("main-\(index)")
                                    .environment(\.selectedProduct, $selectedProduct)
                            }
                        case .category(let id):
                            if let category = categories.first(where: { $0.id == id }) {
                                ProductListView(category: category)
                                    .id("category-\(id)")
                                    .environment(\.selectedProduct, $selectedProduct)
                            } else {
                                ProductListView()
                                    .id("category-default")
                                    .environment(\.selectedProduct, $selectedProduct)
                            }
                        case .tag(let id):
                            if let tag = tags.first(where: { $0.id == id }) {
                                ProductListView(tag: tag)
                                    .id("tag-\(id)")
                                    .environment(\.selectedProduct, $selectedProduct)
                            } else {
                                ProductListView()
                                    .id("tag-default")
                                    .environment(\.selectedProduct, $selectedProduct)
                            }
                        }
                    } else {
                        ProductListView()
                            .id("default")
                            .environment(\.selectedProduct, $selectedProduct)
                    }
                }
            } detail: {
                // 第三列：根据选中的页面显示不同内容
                if let selection = selectedTab {
                    switch selection {
                    case .main(let index):
                        switch index {
                        case 0:  // 商品列表页面
                            ZStack {
                                if let product = selectedProduct {
                                    ProductDetailView(product: product)
                                        .id(product.id?.uuidString ?? "unknown") // 强制刷新详情视图，防止内容错乱
                                } else {
                                    ContentUnavailableView {
                                        Label("暂无选中商品", systemImage: "shippingbox")
                                    } description: {
                                        Text("请从列表中选择一个商品查看详情")
                                    }
                                }
                            }
                        case 1:  // 分类页面
                            CategoryDetailView(category: categories.first ?? Category(context: viewContext))
                                .id("category-detail")
                        case 2:  // 标签页面
                            TagDetailView(tag: tags.first ?? Tag(context: viewContext))
                                .id("tag-detail")
                        case 3:  // 设置页面
                            EmptyView()
                        default:
                            EmptyView()
                        }
                    case .category(let id):
                        if let category = categories.first(where: { $0.id == id }) {
                            if let product = selectedProduct {
                                ProductDetailView(product: product)
                                    .id(product.id?.uuidString ?? "unknown")
                            } else {
                                CategoryDetailView(category: category)
                                    .id("category-\(id)-detail")
                            }
                        }
                    case .tag(let id):
                        if let tag = tags.first(where: { $0.id == id }) {
                            if let product = selectedProduct {
                                ProductDetailView(product: product)
                                    .id(product.id?.uuidString ?? "unknown")
                            } else {
                                TagDetailView(tag: tag)
                                    .id("tag-\(id)-detail")
                            }
                        }
                    }
                } else {
                    // 默认显示空白或占位内容
                    ContentUnavailableView {
                        Label("暂无选中内容", systemImage: "square.3.layers.3d")
                    } description: {
                        Text("请从左侧选择要查看的内容")
                    }
                }
            }
            .navigationSplitViewStyle(.balanced)
            .navigationSplitViewColumnWidth(min: 200, ideal: 280, max: 320)
            .sheet(isPresented: $showingAddProduct) {
                AddProductSheet(isPresented: $showingAddProduct)
            }
            .onAppNotification(.createNewProduct) { _ in
                showingAddProduct = true
            }
            .onAppear {
                notificationManager.updateAllWarrantyReminders(in: viewContext)
                setupNotificationObservers()
            }
            #endif
        }
        .preferredColorScheme(colorScheme)
        .accentColor(accentColor)
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
    
    @FetchRequest(
        entity: Category.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Category.name, ascending: true)]
    ) private var categories: FetchedResults<Category>
    
    @FetchRequest(
        entity: Tag.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Tag.name, ascending: true)]
    ) private var tags: FetchedResults<Tag>
    
    var body: some View {
        List(selection: $selection) {
            Label("所有商品", systemImage: "shippingbox")
                .tag(SelectionValue.main(0))
            
            Section(header: Text("分类")) {
                Label("全部分类", systemImage: "folder")
                    .tag(SelectionValue.main(1))
                
                ForEach(categories) { category in
                    if let id = category.id {
                        Label(category.categoryName, systemImage: category.categoryIcon)
                            .badge(category.productCount)
                            .tag(SelectionValue.category(id))
                    }
                }
            }
            
            Section(header: Text("标签")) {
                Label("全部标签", systemImage: "tag")
                    .tag(SelectionValue.main(2))
                
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
                    }
                }
            }
            
            Section(header: Text("维修管理")) {
                Label("维修记录", systemImage: "wrench.and.screwdriver")
                    .tag(SelectionValue.main(3))
            }
            
            Section(header: Text("设置")) {
                Label("设置与偏好", systemImage: "gear")
                    .tag(SelectionValue.main(4))
            }
        }
        .listStyle(SidebarListStyle())
        .frame(minWidth: 200, idealWidth: 250, maxWidth: 320) // maxWidth 统一为 320
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
