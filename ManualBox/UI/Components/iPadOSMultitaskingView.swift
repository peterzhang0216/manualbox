import SwiftUI
#if os(iOS)
import UIKit
#endif

// MARK: - iPadOS多任务支持视图
@available(iOS 13.0, *)
struct iPadOSMultitaskingView<Content: View>: View {
    let content: () -> Content
    
    @State private var isCompactMode = false
    @State private var currentMultitaskingMode: MultitaskingMode = .fullScreen
    
    var body: some View {
        GeometryReader { geometry in
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(backgroundColorForPlatform)
                .onAppear {
                    detectMultitaskingMode(geometry: geometry)
                }
                .onChange(of: geometry.size) { _, newSize in
                    detectMultitaskingMode(geometry: geometry)
                }
                .environment(\.multitaskingMode, currentMultitaskingMode)
                .environment(\.isCompactMode, isCompactMode)
        }
    }
    
    private var backgroundColorForPlatform: Color {
        #if os(iOS)
        return Color(.systemBackground)
        #else
        return Color(NSColor.controlBackgroundColor)
        #endif
    }

    private func detectMultitaskingMode(geometry: GeometryProxy) {
        #if os(iOS)
        guard iPadOSAdapter.isIPad else { return }
        
        let width = geometry.size.width
        let _ = geometry.size.height
        
        // 检测多任务模式
        if width < 400 {
            // Slide Over模式
            currentMultitaskingMode = .slideOver
            isCompactMode = true
        } else if width < 600 {
            // Split View 1/3模式
            currentMultitaskingMode = .splitViewOneThird
            isCompactMode = true
        } else if width < 800 {
            // Split View 1/2模式
            currentMultitaskingMode = .splitViewHalf
            isCompactMode = false
        } else if width < 1000 {
            // Split View 2/3模式
            currentMultitaskingMode = .splitViewTwoThirds
            isCompactMode = false
        } else {
            // 全屏模式
            currentMultitaskingMode = .fullScreen
            isCompactMode = false
        }
        #endif
    }
}

// MARK: - 多任务模式枚举
enum MultitaskingMode: CaseIterable {
    case fullScreen
    case splitViewTwoThirds
    case splitViewHalf
    case splitViewOneThird
    case slideOver
    
    var displayName: String {
        switch self {
        case .fullScreen:
            return "全屏"
        case .splitViewTwoThirds:
            return "分屏 2/3"
        case .splitViewHalf:
            return "分屏 1/2"
        case .splitViewOneThird:
            return "分屏 1/3"
        case .slideOver:
            return "滑动覆盖"
        }
    }
    
    var isCompact: Bool {
        switch self {
        case .fullScreen, .splitViewTwoThirds, .splitViewHalf:
            return false
        case .splitViewOneThird, .slideOver:
            return true
        }
    }
    
    var preferredColumnCount: Int {
        switch self {
        case .fullScreen:
            return 3
        case .splitViewTwoThirds, .splitViewHalf:
            return 2
        case .splitViewOneThird:
            return 1
        case .slideOver:
            return 1
        }
    }
    
    var shouldShowSidebar: Bool {
        switch self {
        case .fullScreen, .splitViewTwoThirds:
            return true
        case .splitViewHalf, .splitViewOneThird, .slideOver:
            return false
        }
    }
}

// MARK: - 环境值扩展
private struct MultitaskingModeKey: EnvironmentKey {
    static let defaultValue: MultitaskingMode = .fullScreen
}

private struct CompactModeKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    var multitaskingMode: MultitaskingMode {
        get { self[MultitaskingModeKey.self] }
        set { self[MultitaskingModeKey.self] = newValue }
    }
    
    var isCompactMode: Bool {
        get { self[CompactModeKey.self] }
        set { self[CompactModeKey.self] = newValue }
    }
}

// MARK: - 多任务适配视图修饰符
extension View {
    func adaptForMultitasking() -> some View {
        iPadOSMultitaskingView {
            self
        }
    }
    
    @ViewBuilder
    func multitaskingOptimized() -> some View {
        #if os(iOS)
        if iPadOSAdapter.supportsMultitasking {
            self.adaptForMultitasking()
        } else {
            self
        }
        #else
        self
        #endif
    }
    
    @ViewBuilder
    func compactModeAware<CompactContent: View>(
        @ViewBuilder compactContent: @escaping () -> CompactContent
    ) -> some View {
        MultitaskingAwareView(
            regularContent: { self },
            compactContent: compactContent
        )
    }
}

// MARK: - 多任务感知视图
struct MultitaskingAwareView<RegularContent: View, CompactContent: View>: View {
    @Environment(\.isCompactMode) private var isCompactMode
    @Environment(\.multitaskingMode) private var multitaskingMode
    
    let regularContent: () -> RegularContent
    let compactContent: () -> CompactContent
    
    var body: some View {
        Group {
            if isCompactMode {
                compactContent()
            } else {
                regularContent()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isCompactMode)
    }
}

// MARK: - 多任务工具栏
struct MultitaskingToolbar: View {
    @Environment(\.multitaskingMode) private var multitaskingMode
    @Environment(\.isCompactMode) private var isCompactMode
    
    let title: String
    let actions: [ToolbarAction]
    
    var body: some View {
        HStack {
            // 标题
            if !isCompactMode {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            Spacer()
            
            // 操作按钮
            HStack(spacing: isCompactMode ? 8 : 12) {
                ForEach(visibleActions, id: \.id) { action in
                    Button(action: action.action) {
                        if isCompactMode {
                            Image(systemName: action.icon)
                                .font(.system(size: 16, weight: .medium))
                        } else {
                            Label(action.title, systemImage: action.icon)
                        }
                    }
                    .iPadOSHoverEffect()
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(backgroundColorForPlatform)
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(separatorColorForPlatform),
            alignment: .bottom
        )
    }
    
    private var visibleActions: [ToolbarAction] {
        let maxActions = isCompactMode ? 3 : actions.count
        return Array(actions.prefix(maxActions))
    }

    private var backgroundColorForPlatform: Color {
        #if os(iOS)
        return Color(.systemBackground)
        #else
        return Color(NSColor.controlBackgroundColor)
        #endif
    }

    private var separatorColorForPlatform: Color {
        #if os(iOS)
        return Color(.separator)
        #else
        return Color(NSColor.separatorColor)
        #endif
    }
}

// MARK: - 工具栏操作
struct ToolbarAction {
    let id = UUID()
    let title: String
    let icon: String
    let action: () -> Void
    let priority: Int
    
    init(title: String, icon: String, priority: Int = 0, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.priority = priority
        self.action = action
    }
}

// MARK: - 多任务状态指示器
struct MultitaskingStatusIndicator: View {
    @Environment(\.multitaskingMode) private var multitaskingMode
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            
            Text(multitaskingMode.displayName)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(grayBackgroundColorForPlatform)
        .clipShape(Capsule())
    }
    
    private var statusColor: Color {
        switch multitaskingMode {
        case .fullScreen:
            return .green
        case .splitViewTwoThirds, .splitViewHalf:
            return .blue
        case .splitViewOneThird:
            return .orange
        case .slideOver:
            return .purple
        }
    }

    private var grayBackgroundColorForPlatform: Color {
        #if os(iOS)
        return Color(.systemGray6)
        #else
        return Color(NSColor.controlColor)
        #endif
    }
}



#Preview {
    if #available(iOS 13.0, *) {
        VStack {
            MultitaskingToolbar(
                title: "产品管理",
                actions: [
                    ToolbarAction(title: "添加", icon: "plus", priority: 3) { },
                    ToolbarAction(title: "搜索", icon: "magnifyingglass", priority: 2) { },
                    ToolbarAction(title: "筛选", icon: "line.3.horizontal.decrease.circle", priority: 1) { }
                ]
            )
            
            Spacer()
            
            MultitaskingStatusIndicator()
            
            Spacer()
        }
        .multitaskingOptimized()
    }
}
