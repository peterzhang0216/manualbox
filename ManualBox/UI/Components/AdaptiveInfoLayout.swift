import SwiftUI

/// 自适应信息密度布局容器
struct AdaptiveInfoLayout<Content: View>: View {
    let content: () -> Content
    
    @State private var layoutMetrics = AdaptiveLayoutMetrics()
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    
    var body: some View {
        content()
            .environment(\.adaptiveLayoutMetrics, layoutMetrics)
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
            layoutMetrics.update(
                width: window.frame.width,
                height: window.frame.height,
                horizontalSizeClass: .regular,
                verticalSizeClass: .regular
            )
        }
        #else
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            layoutMetrics.update(
                width: window.frame.width,
                height: window.frame.height,
                horizontalSizeClass: horizontalSizeClass ?? .regular,
                verticalSizeClass: verticalSizeClass ?? .regular
            )
        }
        #endif
    }
}

/// 布局度量信息
class AdaptiveLayoutMetrics: ObservableObject {
    @Published var width: CGFloat = 800
    @Published var height: CGFloat = 600
    @Published var horizontalSizeClass: UserInterfaceSizeClass = .regular
    @Published var verticalSizeClass: UserInterfaceSizeClass = .regular
    
    // 计算属性
    var isCompact: Bool {
        horizontalSizeClass == .compact || width < 600
    }
    
    var isRegular: Bool {
        horizontalSizeClass == .regular && width >= 600
    }
    
    var columns: Int {
        if width < 500 { return 1 }
        if width < 800 { return 2 }
        if width < 1200 { return 3 }
        return 4
    }
    
    var gridItemSize: CGFloat {
        let totalSpacing = CGFloat(columns - 1) * 16 + 32 // 间距和边距
        return (width - totalSpacing) / CGFloat(columns)
    }
    
    var cardPadding: CGFloat {
        isCompact ? 12 : 16
    }
    
    var sectionSpacing: CGFloat {
        isCompact ? 16 : 24
    }
    
    var contentSpacing: CGFloat {
        isCompact ? 8 : 12
    }
    
    func update(width: CGFloat, height: CGFloat, horizontalSizeClass: UserInterfaceSizeClass, verticalSizeClass: UserInterfaceSizeClass) {
        self.width = width
        self.height = height
        self.horizontalSizeClass = horizontalSizeClass
        self.verticalSizeClass = verticalSizeClass
    }
}

// Environment Key for LayoutMetrics
struct AdaptiveLayoutMetricsKey: EnvironmentKey {
    static let defaultValue = AdaptiveLayoutMetrics()
}

extension EnvironmentValues {
    var adaptiveLayoutMetrics: AdaptiveLayoutMetrics {
        get { self[AdaptiveLayoutMetricsKey.self] }
        set { self[AdaptiveLayoutMetricsKey.self] = newValue }
    }
}

/// 自适应卡片组件
struct AdaptiveCard<Content: View>: View {
    let content: () -> Content
    let style: CardStyle
    
    @Environment(\.adaptiveLayoutMetrics) private var layoutMetrics
    
    enum CardStyle {
        case primary
        case secondary
        case accent
        case plain
    }
    
    init(style: CardStyle = .primary, @ViewBuilder content: @escaping () -> Content) {
        self.style = style
        self.content = content
    }
    
    var body: some View {
        content()
            .padding(layoutMetrics.cardPadding)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: shadowOffset)
    }
    
    private var backgroundColor: Color {
        switch style {
        case .primary:
            #if os(iOS)
            return Color(.secondarySystemBackground)
            #else
            return Color(.controlBackgroundColor)
            #endif
        case .secondary:
            #if os(iOS)
            return Color(.tertiarySystemBackground)
            #else
            return Color(.tertiaryLabelColor).opacity(0.1)
            #endif
        case .accent:
            return Color.accentColor.opacity(0.1)
        case .plain:
            return Color.clear
        }
    }
    
    private var cornerRadius: CGFloat {
        layoutMetrics.isCompact ? 8 : 12
    }
    
    private var shadowRadius: CGFloat {
        layoutMetrics.isCompact ? 2 : 4
    }
    
    private var shadowOffset: CGFloat {
        layoutMetrics.isCompact ? 1 : 2
    }
    
    private var shadowColor: Color {
        Color.black.opacity(0.1)
    }
}

/// 自适应网格布局
struct AdaptiveGrid<Content: View>: View {
    let content: () -> Content
    let minimumItemWidth: CGFloat
    let spacing: CGFloat
    
    @Environment(\.adaptiveLayoutMetrics) private var layoutMetrics
    
    init(minimumItemWidth: CGFloat = 200, spacing: CGFloat = 16, @ViewBuilder content: @escaping () -> Content) {
        self.minimumItemWidth = minimumItemWidth
        self.spacing = spacing
        self.content = content
    }
    
    var body: some View {
        LazyVGrid(columns: gridColumns, spacing: spacing) {
            content()
        }
        .padding(.horizontal, layoutMetrics.cardPadding)
    }
    
    private var gridColumns: [GridItem] {
        let availableWidth = layoutMetrics.width - (layoutMetrics.cardPadding * 2)
        let columnsCount = max(1, Int(availableWidth / (minimumItemWidth + spacing)))
        return Array(repeating: GridItem(.flexible(), spacing: spacing), count: columnsCount)
    }
}

/// 自适应分组容器
struct AdaptiveSection<Header: View, Content: View, Footer: View>: View {
    let header: () -> Header
    let content: () -> Content
    let footer: () -> Footer
    
    @Environment(\.adaptiveLayoutMetrics) private var layoutMetrics
    
    init(
        @ViewBuilder header: @escaping () -> Header = { EmptyView() },
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder footer: @escaping () -> Footer = { EmptyView() }
    ) {
        self.header = header
        self.content = content
        self.footer = footer
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: layoutMetrics.contentSpacing) {
            header()
                .font(headerFont)
                .foregroundColor(.primary)
            
            content()
            
            footer()
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.bottom, layoutMetrics.sectionSpacing)
    }
    
    private var headerFont: Font {
        layoutMetrics.isCompact ? .headline : .title3
    }
}

/// 响应式文本组件
struct ResponsiveText: View {
    let text: String
    let style: TextStyle
    
    @Environment(\.adaptiveLayoutMetrics) private var layoutMetrics
    
    enum TextStyle {
        case title
        case headline
        case body
        case caption
        case label
    }
    
    var body: some View {
        Text(text)
            .font(adaptiveFont)
            .lineLimit(lineLimit)
    }
    
    private var adaptiveFont: Font {
        switch style {
        case .title:
            return layoutMetrics.isCompact ? .title2 : .largeTitle
        case .headline:
            return layoutMetrics.isCompact ? .headline : .title
        case .body:
            return .body
        case .caption:
            return .caption
        case .label:
            return layoutMetrics.isCompact ? .caption : .body
        }
    }
    
    private var lineLimit: Int? {
        switch style {
        case .title, .headline:
            return layoutMetrics.isCompact ? 2 : nil
        case .body:
            return layoutMetrics.isCompact ? 3 : nil
        case .caption, .label:
            return layoutMetrics.isCompact ? 1 : 2
        }
    }
}

/// 自适应工具栏
struct AdaptiveToolbar<Content: View>: View {
    let content: () -> Content
    let placement: ToolbarPlacement
    
    @Environment(\.adaptiveLayoutMetrics) private var layoutMetrics
    
    enum ToolbarPlacement {
        case top
        case bottom
        case floating
    }
    
    init(placement: ToolbarPlacement = .top, @ViewBuilder content: @escaping () -> Content) {
        self.placement = placement
        self.content = content
    }
    
    var body: some View {
        HStack {
            content()
        }
        .padding(.horizontal, layoutMetrics.cardPadding)
        .padding(.vertical, layoutMetrics.contentSpacing)
        .background(toolbarBackground)
        .clipShape(RoundedRectangle(cornerRadius: placement == .floating ? 12 : 0))
        .shadow(color: placement == .floating ? Color.black.opacity(0.1) : Color.clear, radius: 4)
    }
    
    private var toolbarBackground: Color {
        switch placement {
        case .top, .bottom:
            #if os(iOS)
            return Color(.secondarySystemBackground)
            #else
            return Color(.controlBackgroundColor)
            #endif
        case .floating:
            #if os(iOS)
            return Color(.systemBackground)
            #else
            return Color(.windowBackgroundColor)
            #endif
        }
    }
}

/// 自适应信息展示组件
struct InfoDisplayView<Content: View>: View {
    let title: String
    let subtitle: String?
    let content: () -> Content
    let importance: Importance
    
    @Environment(\.adaptiveLayoutMetrics) private var layoutMetrics
    
    enum Importance {
        case primary
        case secondary
        case tertiary
    }
    
    init(
        title: String,
        subtitle: String? = nil,
        importance: Importance = .primary,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.importance = importance
        self.content = content
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: spacingForImportance) {
            // 标题区域
            VStack(alignment: .leading, spacing: 4) {
                ResponsiveText(text: title, style: titleStyle)
                    .fontWeight(titleWeight)
                
                if let subtitle = subtitle {
                    ResponsiveText(text: subtitle, style: .caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // 内容区域
            content()
        }
        .padding(paddingForImportance)
        .background(backgroundForImportance)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadiusForImportance))
    }
    
    private var titleStyle: ResponsiveText.TextStyle {
        switch importance {
        case .primary: return .headline
        case .secondary: return .body
        case .tertiary: return .caption
        }
    }
    
    private var titleWeight: Font.Weight {
        switch importance {
        case .primary: return .semibold
        case .secondary: return .medium
        case .tertiary: return .regular
        }
    }
    
    private var spacingForImportance: CGFloat {
        switch importance {
        case .primary: return layoutMetrics.contentSpacing * 2
        case .secondary: return layoutMetrics.contentSpacing
        case .tertiary: return layoutMetrics.contentSpacing * 0.5
        }
    }
    
    private var paddingForImportance: CGFloat {
        switch importance {
        case .primary: return layoutMetrics.cardPadding
        case .secondary: return layoutMetrics.cardPadding * 0.75
        case .tertiary: return layoutMetrics.cardPadding * 0.5
        }
    }
    
    private var backgroundForImportance: Color {
        switch importance {
        case .primary: 
            #if os(iOS)
            return Color(.secondarySystemBackground)
            #else
            return Color(.controlBackgroundColor)
            #endif
        case .secondary: 
            #if os(iOS)
            return Color(.tertiarySystemBackground)
            #else
            return Color(.tertiaryLabelColor).opacity(0.1)
            #endif
        case .tertiary: 
            return Color.clear
        }
    }
    
    private var cornerRadiusForImportance: CGFloat {
        switch importance {
        case .primary: return 12
        case .secondary: return 8
        case .tertiary: return 0
        }
    }
}

/// 便捷扩展
extension View {
    func adaptiveLayout() -> some View {
        AdaptiveInfoLayout {
            self
        }
    }
    
    func adaptiveCard(style: AdaptiveCard<AnyView>.CardStyle = .primary) -> some View {
        AdaptiveCard(style: style) {
            AnyView(self)
        }
    }
    
    func adaptiveSection<Header: View, Footer: View>(
        @ViewBuilder header: @escaping () -> Header = { EmptyView() },
        @ViewBuilder footer: @escaping () -> Footer = { EmptyView() }
    ) -> some View {
        AdaptiveSection(header: header, content: { AnyView(self) }, footer: footer)
    }
}

#Preview {
    AdaptiveInfoLayout {
        ScrollView {
            VStack(spacing: 16) {
                AdaptiveCard {
                    VStack {
                        ResponsiveText(text: "自适应布局示例", style: .title)
                        ResponsiveText(text: "这是一个响应式布局的演示", style: .body)
                    }
                }
                
                AdaptiveGrid(minimumItemWidth: 150) {
                    ForEach(1...6, id: \.self) { i in
                        AdaptiveCard(style: .secondary) {
                            Text("项目 \(i)")
                                .frame(height: 100)
                        }
                    }
                }
                
                InfoDisplayView(
                    title: "重要信息",
                    subtitle: "这是一个子标题",
                    importance: .primary
                ) {
                    Text("这里是详细内容区域")
                }
            }
        }
    }
}
