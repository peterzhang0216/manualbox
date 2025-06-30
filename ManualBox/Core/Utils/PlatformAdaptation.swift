import SwiftUI

// MARK: - 平台适配层
// 处理iOS和macOS之间的API差异

#if os(iOS)
import UIKit

// iOS特定的适配
extension View {
    func platformNavigationBarTitleDisplayMode(_ mode: NavigationBarItem.TitleDisplayMode) -> some View {
        self.navigationBarTitleDisplayMode(mode)
    }
    
    func platformListStyle() -> some View {
        self.listStyle(.insetGrouped)
    }
    
    func platformToolbarItem(placement: ToolbarItemPlacement, @ViewBuilder content: () -> some View) -> some ToolbarContent {
        SwiftUI.ToolbarItem(placement: placement, content: content)
    }
}

// iOS颜色适配
extension Color {
    static let platformSystemGray6 = Color(.systemGray6)
    static let platformSystemBackground = Color(.systemBackground)
    static let platformSecondarySystemBackground = Color(.secondarySystemBackground)
}

// iOS工具栏位置
extension ToolbarItemPlacement {
    static let platformLeading = ToolbarItemPlacement.topBarLeading
    static let platformTrailing = ToolbarItemPlacement.topBarTrailing
}

#elseif os(macOS)
import AppKit

// macOS特定的适配
extension View {
    func platformNavigationBarTitleDisplayMode(_ mode: Int) -> some View {
        // macOS不支持navigationBarTitleDisplayMode，返回原视图
        self
    }
    
    func platformListStyle() -> some View {
        // macOS使用默认列表样式
        self.listStyle(.sidebar)
    }
    
    func platformToolbarItem(placement: ToolbarItemPlacement, @ViewBuilder content: () -> some View) -> some ToolbarContent {
        SwiftUI.ToolbarItem(placement: placement, content: content)
    }
}

// macOS颜色适配
extension Color {
    static let platformSystemGray6 = Color(.controlBackgroundColor)
    static let platformSystemBackground = Color(.windowBackgroundColor)
    static let platformSecondarySystemBackground = Color(.controlBackgroundColor)
}

// macOS工具栏位置
extension ToolbarItemPlacement {
    static let platformLeading = ToolbarItemPlacement.navigation
    static let platformTrailing = ToolbarItemPlacement.primaryAction
}

#endif

// MARK: - 通用平台适配
struct PlatformAdaptiveView<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        #if os(iOS)
        content
            .navigationBarTitleDisplayMode(.large)
        #else
        content
        #endif
    }
}

// MARK: - 平台特定的修饰符
struct PlatformToolbarModifier: ViewModifier {
    let leadingContent: AnyView?
    let trailingContent: AnyView?
    
    init(
        leading: (() -> AnyView)? = nil,
        trailing: (() -> AnyView)? = nil
    ) {
        self.leadingContent = leading?()
        self.trailingContent = trailing?()
    }
    
    func body(content: Content) -> some View {
        content
            .toolbar {
                Group {
                    if let leadingContent = leadingContent {
                        SwiftUI.ToolbarItem(placement: .platformLeading) {
                            leadingContent
                        }
                    }
                    
                    if let trailingContent = trailingContent {
                        SwiftUI.ToolbarItem(placement: .platformTrailing) {
                            trailingContent
                        }
                    }
                }
            }
    }
}

extension View {
    func platformToolbar(
        @ViewBuilder leading: @escaping () -> some View = { EmptyView() },
        @ViewBuilder trailing: @escaping () -> some View = { EmptyView() }
    ) -> some View {
        let leadingView = AnyView(leading())
        let trailingView = AnyView(trailing())
        
        return self.modifier(
            PlatformToolbarModifier(
                leading: leadingView is EmptyView ? nil : { leadingView },
                trailing: trailingView is EmptyView ? nil : { trailingView }
            )
        )
    }
}

// MARK: - 平台特定的布局适配
struct PlatformAdaptiveLayout<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        #if os(iOS)
        content
            .background(Color.platformSystemBackground)
        #else
        content
            .background(Color.platformSystemBackground)
            .frame(minWidth: 300, minHeight: 200)
        #endif
    }
}

// MARK: - 平台特定的列表样式
struct PlatformList<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        List {
            content
        }
        .platformListStyle()
    }
}
