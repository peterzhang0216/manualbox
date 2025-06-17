import SwiftUI
import CoreData

// MARK: - View 扩展：条件修饰符
extension View {
    /// 条件性地应用修饰符
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - 选择值枚举 (统一定义)
enum SelectionValue: Hashable {
    case main(Int)
    case category(UUID)
    case tag(UUID)
    case settings(SettingsPanel)
}

// MARK: - 设置面板枚举
enum SettingsPanel: String, CaseIterable, Hashable {
    case notification = "notification"
    case theme = "theme"
    case data = "data"
    case about = "about"

    var title: String {
        switch self {
        case .notification: return "通知与提醒"
        case .theme: return "外观与主题"
        case .data: return "数据与默认"
        case .about: return "关于与支持"
        }
    }

    var icon: String {
        switch self {
        case .notification: return "bell.badge.fill"
        case .theme: return "paintbrush"
        case .data: return "tray.full"
        case .about: return "info.circle"
        }
    }
}

// MARK: - 平台颜色适配
@available(iOS 14.0, macOS 11.0, *)
extension Color {
    static var adaptiveBackground: Color {
        #if os(macOS)
        return Color(.controlBackgroundColor)
        #else
        return Color(.systemBackground)
        #endif
    }
    
    static var adaptiveSecondaryBackground: Color {
        #if os(macOS)
        return Color(.controlBackgroundColor)
        #else
        return Color(.secondarySystemBackground)
        #endif
    }
}

// MARK: - 统一三栏导航容器
/// 跨平台三栏/多栏统一导航容器
/// 自动适配iOS 16+/iPadOS/macOS的NavigationSplitView，在iPhone或低版本iOS上降级为TabView+NavigationStack
struct UnifiedSplitView<Sidebar: View, Content: View, Detail: View, SelectedItem: Equatable>: View {
    // MARK: - 状态绑定
    @Binding var selection: SelectionValue?
    @Binding var selectedItem: SelectedItem?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var preferredCompactColumn: NavigationSplitViewColumn = .content
    @State private var isShowingDetail = false
    
    // MARK: - 视图构建器
    let sidebar: () -> Sidebar
    let content: () -> Content
    let detail: () -> Detail
    
    // MARK: - 配置参数
    let sidebarMinWidth: CGFloat
    let sidebarIdealWidth: CGFloat
    let sidebarMaxWidth: CGFloat
    let enableAccessibilityFeatures: Bool
    
    init(
        selection: Binding<SelectionValue?>,
        selectedItem: Binding<SelectedItem?> = .constant(nil),
        sidebarMinWidth: CGFloat = 200,
        sidebarIdealWidth: CGFloat = 280,
        sidebarMaxWidth: CGFloat = 320,
        enableAccessibilityFeatures: Bool = true,
        @ViewBuilder sidebar: @escaping () -> Sidebar,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder detail: @escaping () -> Detail
    ) {
        self._selection = selection
        self._selectedItem = selectedItem
        self.sidebarMinWidth = sidebarMinWidth
        self.sidebarIdealWidth = sidebarIdealWidth
        self.sidebarMaxWidth = sidebarMaxWidth
        self.enableAccessibilityFeatures = enableAccessibilityFeatures
        self.sidebar = sidebar
        self.content = content
        self.detail = detail
    }

    var body: some View {
        Group {
            #if os(macOS)
            // macOS：始终使用NavigationSplitView
            macOSSplitView
                .onAppear {
                    // 注册键盘快捷键
                    _ = PlatformInputHandler.keyboardShortcuts()
                    
                    // 注册侧边栏切换快捷键
                    #if os(macOS)
                    NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                        // Command+Option+S 切换侧边栏 (键码 1 = S)
                        if event.modifierFlags.contains([.command, .option]) && event.keyCode == 1 {
                            withAnimation(PlatformAnimations.quickTransition) {
                                columnVisibility = columnVisibility == .all ? .detailOnly : .all
                            }
                            return nil // 事件已处理
                        }
                        return event // 继续传递事件
                    }
                    #endif
                }
                .animation(PlatformAnimations.defaultSpring, value: columnVisibility)
            #elseif os(iOS)
            // iOS：根据设备类型和系统版本决定
            if UIDevice.current.userInterfaceIdiom == .pad {
                // iPad：优先使用NavigationSplitView（iOS 16+）
                if #available(iOS 16.0, *) {
                    iPadSplitView
                        .animation(PlatformAnimations.defaultSpring, value: columnVisibility)
                } else {
                    // iPad iOS 15及以下：使用TabView降级
                    iPhoneFallbackView
                }
            } else {
                // iPhone：始终使用TabView
                iPhoneFallbackView
            }
            #endif
        }
        .onChange(of: selectedItem) {
            // 当选中项目发生变化时，自动显示详情视图
            isShowingDetail = selectedItem != nil
            // 在有内容选择时，优先显示详情列
            if selectedItem != nil {
                preferredCompactColumn = .detail
            } else {
                preferredCompactColumn = .content
            }
        }
        .accessibilityAction(named: Text("切换侧边栏")) {
            #if os(macOS)
            withAnimation(PlatformAnimations.quickTransition) {
                columnVisibility = columnVisibility == .all ? .detailOnly : .all
            }
            #endif
        }
    }
    
    // MARK: - macOS 三栏视图
    @ViewBuilder
    private var macOSSplitView: some View {
        NavigationSplitView(
            columnVisibility: $columnVisibility,
            preferredCompactColumn: $preferredCompactColumn
        ) {
            sidebar()
                .navigationSplitViewColumnWidth(
                    min: sidebarMinWidth,
                    ideal: sidebarIdealWidth,
                    max: sidebarMaxWidth
                )
                .if(enableAccessibilityFeatures) { view in
                    view.accessibilityLabel("侧边栏导航")
                        .accessibilityHint("选择要浏览的内容分类")
                }
        } content: {
            content()
                .navigationSplitViewColumnWidth(min: 300, ideal: 400, max: 600)
                .if(enableAccessibilityFeatures) { view in
                    view.accessibilityLabel("内容列表")
                        .accessibilityHint("浏览所选分类的内容项目")
                }
        } detail: {
            detail()
                .if(enableAccessibilityFeatures) { view in
                    view.accessibilityLabel("详情视图")
                        .accessibilityHint("查看所选项目的详细信息")
                }
        }
        .navigationSplitViewStyle(.balanced)
    }
    
    // MARK: - iPad 三栏视图 (iOS 16+)
    @available(iOS 16.0, *)
    @ViewBuilder
    private var iPadSplitView: some View {
        NavigationSplitView(
            columnVisibility: $columnVisibility,
            preferredCompactColumn: $preferredCompactColumn
        ) {
            sidebar()
                .navigationSplitViewColumnWidth(
                    min: sidebarMinWidth,
                    ideal: sidebarIdealWidth,
                    max: sidebarMaxWidth
                )
                .if(enableAccessibilityFeatures) { view in
                    view.accessibilityLabel("侧边栏导航")
                        .accessibilityHint("选择要浏览的内容分类")
                }
        } content: {
            content()
                .navigationSplitViewColumnWidth(min: 300, ideal: 400, max: 600)
                .if(enableAccessibilityFeatures) { view in
                    view.accessibilityLabel("内容列表")
                        .accessibilityHint("浏览所选分类的内容项目")
                }
        } detail: {
            detail()
                .if(enableAccessibilityFeatures) { view in
                    view.accessibilityLabel("详情视图")
                        .accessibilityHint("查看所选项目的详细信息")
                }
        }
        .navigationSplitViewStyle(.balanced)
    }
    
    // MARK: - iPhone/低版本iOS 降级视图
    @ViewBuilder
    private var iPhoneFallbackView: some View {
        TabView(selection: Binding(
            get: {
                if case let .main(index) = selection {
                    return index
                }
                return 0
            },
            set: { (newValue: Int) in
                selection = SelectionValue.main(newValue)
            }
        )) {
            // 商品Tab
            NavigationStack {
                content()
                    .sheet(isPresented: $isShowingDetail) {
                        #if os(iOS)
                        NavigationStack {
                            detail()
                                .navigationBarTitleDisplayMode(.inline)
                                .toolbar(content: {
                                    SwiftUI.ToolbarItem(placement: .navigationBarTrailing) {
                                        Button("完成") {
                                            isShowingDetail = false
                                        }
                                    }
                                })
                        }
                        #else
                        detail()
                        #endif
                    }
            }
            .tabItem {
                Label("商品", systemImage: "shippingbox")
            }
            .tag(0)
            
            // 分类Tab
            NavigationStack {
                CategoryTabContent()
            }
            .tabItem {
                Label("分类", systemImage: "folder")
            }
            .tag(1)
            
            // 标签Tab
            NavigationStack {
                TagTabContent()
            }
            .tabItem {
                Label("标签", systemImage: "tag")
            }
            .tag(2)
            
            // 维修Tab
            NavigationStack {
                RepairTabContent()
            }
            .tabItem {
                Label("维修", systemImage: "wrench.and.screwdriver")
            }
            .tag(3)
            
            // 设置Tab
            NavigationStack {
                SettingsTabContent()
            }
            .tabItem {
                Label("设置", systemImage: "gear")
            }
            .tag(4)
        }
    }
}

// MARK: - iPhone Tab内容占位符
// 这些组件需要根据实际项目中的视图进行替换
struct CategoryTabContent: View {
    var body: some View {
        Text("分类管理")
            .navigationTitle("分类")
    }
}

struct TagTabContent: View {
    var body: some View {
        Text("标签管理")
            .navigationTitle("标签")
    }
}

struct RepairTabContent: View {
    var body: some View {
        Text("维修记录")
            .navigationTitle("维修")
    }
}

struct SettingsTabContent: View {
    var body: some View {
        Text("设置")
            .navigationTitle("设置")
    }
}

// MARK: - 扩展功能
extension UnifiedSplitView {
    /// 设置侧边栏可见性
    func sidebarVisibility(_ visibility: NavigationSplitViewVisibility) -> UnifiedSplitView {
        UnifiedSplitView(
            selection: _selection,
            selectedItem: _selectedItem,
            sidebarMinWidth: sidebarMinWidth,
            sidebarIdealWidth: sidebarIdealWidth,
            sidebarMaxWidth: sidebarMaxWidth,
            sidebar: sidebar,
            content: content,
            detail: detail
        )
    }
    
    /// 设置默认选中项
    func defaultSelection(_ defaultSelection: SelectionValue) -> UnifiedSplitView {
        let newSelection = _selection
        if newSelection.wrappedValue == nil {
            return UnifiedSplitView(
                selection: Binding.constant(defaultSelection),
                selectedItem: _selectedItem,
                sidebarMinWidth: sidebarMinWidth,
                sidebarIdealWidth: sidebarIdealWidth,
                sidebarMaxWidth: sidebarMaxWidth,
                sidebar: sidebar,
                content: content,
                detail: detail
            )
        }
        return UnifiedSplitView(
            selection: newSelection,
            selectedItem: _selectedItem,
            sidebarMinWidth: sidebarMinWidth,
            sidebarIdealWidth: sidebarIdealWidth,
            sidebarMaxWidth: sidebarMaxWidth,
            sidebar: sidebar,
            content: content,
            detail: detail
        )
    }
}

// MARK: - 预览支持
#if DEBUG
struct UnifiedSplitView_Previews: PreviewProvider {
    static var previews: some View {
        UnifiedSplitView<AnyView, AnyView, AnyView, String>(
            selection: .constant(.main(0)),
            selectedItem: .constant(nil),
            sidebar: {
                AnyView(
                    List {
                        Label("所有商品", systemImage: "shippingbox")
                        Label("分类", systemImage: "folder")
                        Label("标签", systemImage: "tag")
                    }
                    .listStyle(.sidebar)
                )
            },
            content: {
                AnyView(
                    Text("内容区域")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.adaptiveBackground)
                )
            },
            detail: {
                AnyView(
                    Text("详情区域")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.adaptiveSecondaryBackground)
                )
            }
        )
        .previewDisplayName("统一三栏视图")
    }
}
#endif
