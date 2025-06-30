import SwiftUI

// MARK: - 统一按钮组件
struct UnifiedButton: View {
    let title: String
    let icon: String?
    let style: UnifiedButtonStyle
    let size: UnifiedButtonSize
    let action: () -> Void
    
    @State private var isPressed = false
    @State private var isHovered = false
    
    init(
        _ title: String,
        icon: String? = nil,
        style: UnifiedButtonStyle = .primary,
        size: UnifiedButtonSize = .medium,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.style = style
        self.size = size
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: size.iconSpacing) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: size.iconSize, weight: .medium))
                }
                
                Text(title)
                    .font(size.font)
                    .fontWeight(.medium)
            }
            .foregroundColor(foregroundColor)
            .padding(.horizontal, size.horizontalPadding)
            .padding(.vertical, size.verticalPadding)
            .frame(minHeight: size.minHeight)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: size.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: size.cornerRadius)
                    .stroke(borderColor, lineWidth: style.borderWidth)
            )
            .shadow(
                color: shadowColor,
                radius: shadowRadius,
                x: 0,
                y: shadowOffset
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .opacity(isPressed ? 0.9 : 1.0)
        }
        .buttonStyle(.plain)
        .unifiedTouchTarget()
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        .unifiedAnimation(.quick)
    }
    
    // MARK: - 计算属性
    private var foregroundColor: Color {
        switch style {
        case .primary:
            return .white
        case .secondary:
            return UnifiedDesignSystem.Colors.primary
        case .tertiary:
            return UnifiedDesignSystem.Colors.primaryText
        case .destructive:
            return .white
        case .ghost:
            return UnifiedDesignSystem.Colors.primary
        }
    }
    
    private var backgroundColor: Color {
        let baseColor: Color
        
        switch style {
        case .primary:
            baseColor = UnifiedDesignSystem.Colors.primary
        case .secondary:
            baseColor = UnifiedDesignSystem.Colors.secondaryBackground
        case .tertiary:
            baseColor = UnifiedDesignSystem.Colors.tertiaryBackground
        case .destructive:
            baseColor = UnifiedDesignSystem.Colors.error
        case .ghost:
            baseColor = Color.clear
        }
        
        if isHovered && style != .ghost {
            return baseColor.opacity(0.9)
        }
        
        return baseColor
    }
    
    private var borderColor: Color {
        switch style {
        case .primary, .destructive:
            return Color.clear
        case .secondary:
            return UnifiedDesignSystem.Colors.primary.opacity(0.3)
        case .tertiary:
            return UnifiedDesignSystem.Colors.separator
        case .ghost:
            return UnifiedDesignSystem.Colors.primary.opacity(isHovered ? 0.3 : 0.2)
        }
    }
    
    private var shadowColor: Color {
        switch style {
        case .primary, .destructive:
            return Color.black.opacity(0.1)
        case .secondary, .tertiary, .ghost:
            return Color.clear
        }
    }
    
    private var shadowRadius: CGFloat {
        switch style {
        case .primary, .destructive:
            return 2
        case .secondary, .tertiary, .ghost:
            return 0
        }
    }
    
    private var shadowOffset: CGFloat {
        switch style {
        case .primary, .destructive:
            return 1
        case .secondary, .tertiary, .ghost:
            return 0
        }
    }
}

// MARK: - 按钮样式
enum UnifiedButtonStyle {
    case primary
    case secondary
    case tertiary
    case destructive
    case ghost
    
    var borderWidth: CGFloat {
        switch self {
        case .primary, .destructive:
            return 0
        case .secondary, .tertiary, .ghost:
            return 1
        }
    }
}

// MARK: - 按钮尺寸
enum UnifiedButtonSize {
    case small
    case medium
    case large
    
    var font: Font {
        switch self {
        case .small:
            return .caption
        case .medium:
            return .body
        case .large:
            return .headline
        }
    }
    
    var horizontalPadding: CGFloat {
        switch self {
        case .small:
            return UnifiedDesignSystem.Spacing.md
        case .medium:
            return UnifiedDesignSystem.Spacing.lg
        case .large:
            return UnifiedDesignSystem.Spacing.xl
        }
    }
    
    var verticalPadding: CGFloat {
        switch self {
        case .small:
            return UnifiedDesignSystem.Spacing.sm
        case .medium:
            return UnifiedDesignSystem.Spacing.md
        case .large:
            return UnifiedDesignSystem.Spacing.lg
        }
    }
    
    var minHeight: CGFloat {
        switch self {
        case .small:
            return 32
        case .medium:
            return UnifiedDesignSystem.Sizes.buttonHeight
        case .large:
            return 52
        }
    }
    
    var cornerRadius: CGFloat {
        switch self {
        case .small:
            return UnifiedDesignSystem.CornerRadius.sm
        case .medium:
            return UnifiedDesignSystem.CornerRadius.button
        case .large:
            return UnifiedDesignSystem.CornerRadius.md
        }
    }
    
    var iconSize: CGFloat {
        switch self {
        case .small:
            return UnifiedDesignSystem.Sizes.iconSM
        case .medium:
            return UnifiedDesignSystem.Sizes.iconMD
        case .large:
            return UnifiedDesignSystem.Sizes.iconLG
        }
    }
    
    var iconSpacing: CGFloat {
        switch self {
        case .small:
            return UnifiedDesignSystem.Spacing.xs
        case .medium:
            return UnifiedDesignSystem.Spacing.sm
        case .large:
            return UnifiedDesignSystem.Spacing.md
        }
    }
}

// MARK: - 便捷构造器
extension UnifiedButton {
    
    // MARK: - 主要按钮
    static func primary(_ title: String, icon: String? = nil, action: @escaping () -> Void) -> UnifiedButton {
        UnifiedButton(title, icon: icon, style: .primary, action: action)
    }
    
    static func primaryLarge(_ title: String, icon: String? = nil, action: @escaping () -> Void) -> UnifiedButton {
        UnifiedButton(title, icon: icon, style: .primary, size: .large, action: action)
    }
    
    // MARK: - 次要按钮
    static func secondary(_ title: String, icon: String? = nil, action: @escaping () -> Void) -> UnifiedButton {
        UnifiedButton(title, icon: icon, style: .secondary, action: action)
    }
    
    // MARK: - 第三级按钮
    static func tertiary(_ title: String, icon: String? = nil, action: @escaping () -> Void) -> UnifiedButton {
        UnifiedButton(title, icon: icon, style: .tertiary, action: action)
    }
    
    // MARK: - 危险按钮
    static func destructive(_ title: String, icon: String? = nil, action: @escaping () -> Void) -> UnifiedButton {
        UnifiedButton(title, icon: icon, style: .destructive, action: action)
    }
    
    // MARK: - 幽灵按钮
    static func ghost(_ title: String, icon: String? = nil, action: @escaping () -> Void) -> UnifiedButton {
        UnifiedButton(title, icon: icon, style: .ghost, action: action)
    }
    
    // MARK: - 小尺寸按钮
    static func small(_ title: String, icon: String? = nil, style: UnifiedButtonStyle = .secondary, action: @escaping () -> Void) -> UnifiedButton {
        UnifiedButton(title, icon: icon, style: style, size: .small, action: action)
    }
}

// MARK: - 按钮组
struct UnifiedButtonGroup: View {
    let buttons: [UnifiedButton]
    let axis: Axis
    let spacing: CGFloat
    
    init(
        axis: Axis = .horizontal,
        spacing: CGFloat = UnifiedDesignSystem.Spacing.md,
        @UnifiedButtonGroupBuilder buttons: () -> [UnifiedButton]
    ) {
        self.axis = axis
        self.spacing = spacing
        self.buttons = buttons()
    }
    
    var body: some View {
        Group {
            if axis == .horizontal {
                HStack(spacing: spacing) {
                    ForEach(0..<buttons.count, id: \.self) { index in
                        buttons[index]
                    }
                }
            } else {
                VStack(spacing: spacing) {
                    ForEach(0..<buttons.count, id: \.self) { index in
                        buttons[index]
                    }
                }
            }
        }
    }
}

// MARK: - 按钮组构建器
@resultBuilder
struct UnifiedButtonGroupBuilder {
    static func buildBlock(_ buttons: UnifiedButton...) -> [UnifiedButton] {
        buttons
    }
}

#Preview {
    VStack(spacing: 20) {
        // 不同样式的按钮
        UnifiedButton.primary("主要按钮", icon: "plus") {
            print("Primary button tapped")
        }
        
        UnifiedButton.secondary("次要按钮", icon: "pencil") {
            print("Secondary button tapped")
        }
        
        UnifiedButton.tertiary("第三级按钮") {
            print("Tertiary button tapped")
        }
        
        UnifiedButton.destructive("删除", icon: "trash") {
            print("Destructive button tapped")
        }
        
        UnifiedButton.ghost("幽灵按钮", icon: "eye") {
            print("Ghost button tapped")
        }
        
        // 按钮组
        UnifiedButtonGroup {
            UnifiedButton.secondary("取消") { }
            UnifiedButton.primary("确定") { }
        }
        
        // 垂直按钮组
        UnifiedButtonGroup(axis: .vertical) {
            UnifiedButton.small("小按钮 1", style: .primary) { }
            UnifiedButton.small("小按钮 2", style: .secondary) { }
        }
    }
    .padding()
}
