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
        // 注意：此容器已弃用，请直接使用 MainTabView
        NavigationView {
            content()
        }
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

// MARK: - macOS 侧边栏视图 (已移除重复代码)
// 注意：实际的侧边栏视图现在在 MainTabView.swift 中的 SidebarView

// MARK: - 平台感知的工具栏
struct PlatformToolbarModifier: ViewModifier {
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
                ToolbarItemGroup(placement: .primaryAction) {
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
        modifier(PlatformToolbarModifier(actions: actions))
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