import SwiftUI
import Foundation

#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

// Import PlatformAdapter from Core/Utils
// Note: In a proper module structure, this would be handled by the build system

// MARK: - 平台特定工具栏组件
struct PlatformToolbar<Content: View>: View {
    let content: () -> Content
    let style: ToolbarStyle
    let placement: ToolbarPlacement
    
    enum ToolbarStyle {
        case primary
        case secondary
        case floating
        case compact
        
        var backgroundColor: Color {
            switch self {
            case .primary:
                #if os(macOS)
                return Color(NSColor.windowBackgroundColor)
                #else
                return Color(.systemBackground)
                #endif
            case .secondary:
                #if os(macOS)
                return Color(NSColor.controlBackgroundColor)
                #else
                return Color(.secondarySystemBackground)
                #endif
            case .floating:
                #if os(macOS)
                return Color(NSColor.windowBackgroundColor).opacity(0.9)
                #else
                return Color(.systemBackground).opacity(0.9)
                #endif
            case .compact:
                return Color.clear
            }
        }
        
        var shadowRadius: CGFloat {
            switch self {
            case .primary, .secondary:
                return 2
            case .floating:
                return 8
            case .compact:
                return 0
            }
        }
        
        var padding: EdgeInsets {
            switch self {
            case .primary:
                return EdgeInsets(
                    top: 12,
                    leading: 16,
                    bottom: 12,
                    trailing: 16
                )
            case .secondary, .floating:
                return EdgeInsets(
                    top: 6,
                    leading: 8,
                    bottom: 6,
                    trailing: 8
                )
            case .compact:
                return EdgeInsets(
                    top: 4,
                    leading: 8,
                    bottom: 4,
                    trailing: 8
                )
            }
        }
    }
    
    enum ToolbarPlacement {
        case top
        case bottom
        case leading
        case trailing
        case center
        
        var alignment: Alignment {
            switch self {
            case .top:
                return .top
            case .bottom:
                return .bottom
            case .leading:
                return .leading
            case .trailing:
                return .trailing
            case .center:
                return .center
            }
        }
    }
    
    init(
        style: ToolbarStyle = .primary,
        placement: ToolbarPlacement = .top,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.style = style
        self.placement = placement
        self.content = content
    }
    
    var body: some View {
        toolbarContent
            .background(toolbarBackground)
            .accessibilityLabel("Toolbar")
    }
    
    @ViewBuilder
    private var toolbarContent: some View {
        switch placement {
        case .top, .bottom:
            HStack(spacing: 12) {
                content()
            }
            .padding(style.padding)
            
        case .leading, .trailing:
            VStack(spacing: 12) {
                content()
            }
            .padding(style.padding)
            
        case .center:
            HStack(spacing: 12) {
                Spacer()
                content()
                Spacer()
            }
            .padding(style.padding)
        }
    }
    
    @ViewBuilder
    private var toolbarBackground: some View {
        RoundedRectangle(cornerRadius: style == .floating ? 12 : 0)
            .fill(style.backgroundColor)
            .shadow(
                color: .black.opacity(0.1),
                radius: style.shadowRadius,
                x: 0,
                y: style.shadowRadius / 2
            )
    }
}

// MARK: - 工具栏项目
struct ToolbarItem: View {
    let title: String?
    let icon: String
    let action: () -> Void
    let isEnabled: Bool
    let badge: String?
    
    @State private var isHovered = false
    
    init(
        title: String? = nil,
        icon: String,
        isEnabled: Bool = true,
        badge: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.isEnabled = isEnabled
        self.badge = badge
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                
                if let title = title {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                }
                
                if let badge = badge {
                    Text(badge)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color.red)
                        )
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(minHeight: 44)
             .background(
                 RoundedRectangle(cornerRadius: 8)
                     .fill(isHovered ? Color.accentColor.opacity(0.1) : Color.clear)
             )
             .overlay(
                 RoundedRectangle(cornerRadius: 8)
                     .stroke(Color.gray.opacity(0.3), lineWidth: isHovered ? 1 : 0)
             )
        }
        .disabled(!isEnabled)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        .accessibilityLabel(title ?? icon)
    }
}

// MARK: - 工具栏分隔符
struct ToolbarDivider: View {
    let orientation: Orientation
    
    enum Orientation {
        case horizontal
        case vertical
    }
    
    init(_ orientation: Orientation = .vertical) {
        self.orientation = orientation
    }
    
    var body: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.3))
            .frame(
                width: orientation == .vertical ? 1 : nil,
                height: orientation == .horizontal ? 1 : nil
            )
            .frame(
                maxWidth: orientation == .horizontal ? .infinity : nil,
                maxHeight: orientation == .vertical ? .infinity : nil
            )
    }
}

// MARK: - 便捷扩展
extension View {
    func platformToolbar<ToolbarContent: View>(
        style: PlatformToolbar<ToolbarContent>.ToolbarStyle = .primary,
        placement: PlatformToolbar<ToolbarContent>.ToolbarPlacement = .top,
        @ViewBuilder toolbar: @escaping () -> ToolbarContent
    ) -> some View {
        VStack(spacing: 0) {
            if placement == .top {
                PlatformToolbar(style: style, placement: placement, content: toolbar)
            }
            
            self
            
            if placement == .bottom {
                PlatformToolbar(style: style, placement: placement, content: toolbar)
            }
        }
    }
}

// MARK: - 预览
#Preview {
    struct ToolbarPreview: View {
        @State private var selectedTab = 0
        
        var body: some View {
            VStack {
                Text("Main Content")
                    .font(.title)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.gray.opacity(0.1))
            }
            .platformToolbar(style: .primary, placement: .top) {
                ToolbarItem(title: "New", icon: "plus") {
                    print("New tapped")
                }
                
                ToolbarItem(title: "Edit", icon: "pencil") {
                    print("Edit tapped")
                }
                
                ToolbarDivider()
                
                ToolbarItem(title: "Share", icon: "square.and.arrow.up") {
                    print("Share tapped")
                }
                
                ToolbarItem(title: "Settings", icon: "gear") {
                    print("Settings tapped")
                }
                
                Spacer()
                
                ToolbarItem(title: "Notifications", icon: "bell", badge: "3") {
                    print("Notifications tapped")
                }
            }
            .platformToolbar(style: .secondary, placement: .bottom) {
                ToolbarItem(icon: "house.fill") {
                    selectedTab = 0
                }
                
                ToolbarItem(icon: "magnifyingglass") {
                    selectedTab = 1
                }
                
                ToolbarItem(icon: "heart") {
                    selectedTab = 2
                }
                
                ToolbarItem(icon: "person") {
                    selectedTab = 3
                }
            }
        }
    }
    
    return ToolbarPreview()
}