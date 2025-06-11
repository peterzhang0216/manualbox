import SwiftUI

// MARK: - 平台特定按钮组件
struct PlatformButton: View {
    let title: String
    let icon: String?
    let style: ButtonStyle
    let action: () -> Void
    
    @State private var isHovered = false
    @State private var isPressed = false
    
    enum ButtonStyle {
        case primary
        case secondary
        case destructive
        case plain
        case toolbar
        
        var backgroundColor: Color {
            switch self {
            case .primary:
                return .accentColor
            case .secondary:
                return PlatformAdapter.secondaryBackgroundColor
            case .destructive:
                return .red
            case .plain:
                return .clear
            case .toolbar:
                #if os(macOS)
                return Color(.controlBackgroundColor)
                #else
                return Color(.systemGray6)
                #endif
            }
        }
        
        var foregroundColor: Color {
            switch self {
            case .primary:
                return .white
            case .secondary:
                return .primary
            case .destructive:
                return .white
            case .plain:
                return .accentColor
            case .toolbar:
                return .primary
            }
        }
        
        var cornerRadius: CGFloat {
            switch self {
            case .primary, .secondary, .destructive:
                return PlatformAdapter.cardCornerRadius
            case .plain:
                return 0
            case .toolbar:
                #if os(macOS)
                return 6
                #else
                return 8
                #endif
            }
        }
    }
    
    init(
        _ title: String,
        icon: String? = nil,
        style: ButtonStyle = .primary,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.style = style
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: PlatformAdapter.groupSpacing / 2) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: PlatformAdapter.bodyFontSize, weight: .medium))
                }
                
                Text(title)
                    .font(.system(size: PlatformAdapter.bodyFontSize, weight: .medium))
            }
            .padding(.horizontal, PlatformAdapter.defaultPadding)
            .padding(.vertical, PlatformAdapter.groupSpacing)
            .frame(minHeight: PlatformAdapter.minimumTouchTarget)
            .background(
                RoundedRectangle(cornerRadius: style.cornerRadius)
                    .fill(buttonBackgroundColor)
            )
            .foregroundColor(style.foregroundColor)
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .opacity(isHovered ? 0.8 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .platformHover()
        .onHover { hovering in
            withAnimation(PlatformAdapter.defaultAnimation) {
                isHovered = hovering
            }
        }
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
        .platformAccessibility(label: title)
    }
    
    private var buttonBackgroundColor: Color {
        var color = style.backgroundColor
        
        if isPressed {
            color = color.opacity(0.8)
        } else if isHovered && PlatformAdapter.supportsHover {
            color = color.opacity(0.9)
        }
        
        return color
    }
}

// MARK: - 平台特定按钮样式
struct PlatformButtonStyle: ButtonStyle {
    let style: PlatformButton.ButtonStyle
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(PlatformAdapter.defaultAnimation, value: configuration.isPressed)
    }
}

// MARK: - 预览
#Preview {
    VStack(spacing: 20) {
        PlatformButton("Primary Button", icon: "star.fill", style: .primary) {
            print("Primary tapped")
        }
        
        PlatformButton("Secondary Button", icon: "gear", style: .secondary) {
            print("Secondary tapped")
        }
        
        PlatformButton("Destructive Button", icon: "trash", style: .destructive) {
            print("Destructive tapped")
        }
        
        PlatformButton("Plain Button", style: .plain) {
            print("Plain tapped")
        }
        
        PlatformButton("Toolbar Button", icon: "plus", style: .toolbar) {
            print("Toolbar tapped")
        }
    }
    .padding()
    .platformBackground()
}