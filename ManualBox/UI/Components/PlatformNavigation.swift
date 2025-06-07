import SwiftUI
import CoreData

// MARK: - 统一的多平台导航容器
struct PlatformNavigationContainer<Content: View>: View {
    let content: () -> Content
    @State private var selectedTab: Int = 0
    @State private var selectedSidebarItem: SelectionValue? = .main(0)
    
    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }
    
    var body: some View {
        #if os(macOS)
        // macOS 使用现有的 NavigationSplitView 架构
        NavigationSplitView {
            PlatformSidebarView(selection: $selectedSidebarItem)
                .navigationSplitViewColumnWidth(min: 250, ideal: 300)
        } detail: {
            content()
        }
        .navigationSplitViewStyle(.balanced)
        #else
        // iOS 使用 TabView
        TabView(selection: $selectedTab) {
            NavigationStack {
                content()
            }
            .tabItem {
                Label("产品", systemImage: "shippingbox")
            }
            .tag(0)
            
            NavigationStack {
                CategoriesView()
            }
            .tabItem {
                Label("分类", systemImage: "folder")
            }
            .tag(1)
            
            NavigationStack {
                TagsView()
            }
            .tabItem {
                Label("标签", systemImage: "tag")
            }
            .tag(2)
            
            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("设置", systemImage: "gear")
            }
            .tag(3)
        }
        #endif
    }
}

// MARK: - 平台特定的侧边栏视图（重命名以避免冲突）
struct PlatformSidebarView: View {
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
        .listStyle(.sidebar)
        .navigationTitle("ManualBox")
    }
}

// MARK: - 平台感知的工具栏
struct PlatformToolbar: ViewModifier {
    let actions: [ToolbarAction]
    
    func body(content: Content) -> some View {
        content
            .toolbar {
                #if os(macOS)
                // macOS 工具栏布局
                ToolbarItemGroup(placement: .primaryAction) {
                    ForEach(actions, id: \.id) { action in
                        Button(action: action.action) {
                            Label(action.title, systemImage: action.icon)
                        }
                        .help(action.title)
                    }
                }
                #else
                // iOS 工具栏布局
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    ForEach(actions, id: \.id) { action in
                        Button(action: action.action) {
                            Image(systemName: action.icon)
                        }
                        .accessibilityLabel(action.title)
                    }
                }
                #endif
            }
    }
}

struct ToolbarAction {
    let id = UUID()
    let title: String
    let icon: String
    let action: () -> Void
}

extension View {
    func platformToolbar(_ actions: [ToolbarAction]) -> some View {
        modifier(PlatformToolbar(actions: actions))
    }
}

// MARK: - 响应式布局组件
struct ResponsiveLayout<Content: View>: View {
    let content: (LayoutMetrics) -> Content
    @State private var layoutMetrics = LayoutMetrics()
    
    var body: some View {
        content(layoutMetrics)
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("WindowSizeChanged"))) { _ in
                updateLayoutMetrics()
            }
            .onAppear {
                updateLayoutMetrics()
            }
    }
    
    private func updateLayoutMetrics() {
        #if os(macOS)
        if let window = NSApplication.shared.mainWindow {
            layoutMetrics.update(width: window.frame.width, height: window.frame.height)
        }
        #else
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            layoutMetrics.update(width: window.frame.width, height: window.frame.height)
        }
        #endif
    }
}

struct LayoutMetrics {
    var width: CGFloat = 800
    var height: CGFloat = 600
    
    var isCompact: Bool {
        width < 600
    }
    
    var isRegular: Bool {
        width >= 600
    }
    
    var columns: Int {
        if width < 600 { return 1 }
        if width < 900 { return 2 }
        if width < 1200 { return 3 }
        return 4
    }
    
    mutating func update(width: CGFloat, height: CGFloat) {
        self.width = width
        self.height = height
    }
}