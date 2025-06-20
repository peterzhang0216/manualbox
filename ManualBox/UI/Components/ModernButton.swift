import SwiftUI

// MARK: - 现代化按钮组件
/// 基于 Liquid Glass 材质系统的现代化按钮组件
/// 符合 macOS 14 和 iOS 17 最新设计规范

struct ModernButton: View {
    let title: String
    let icon: String?
    let style: ButtonStyle
    let size: ButtonSize
    let action: () -> Void
    
    @State private var isPressed = false
    @State private var isHovered = false
    
    /// 按钮样式
    enum ButtonStyle {
        case primary        // 主要按钮
        case secondary      // 次要按钮
        case tertiary       // 三级按钮
        case destructive    // 危险按钮
        case ghost          // 幽灵按钮
        case plain          // 纯文本按钮
        
        var material: LiquidGlassMaterial {
            switch self {
            case .primary: return .regular
            case .secondary: return .thin
            case .tertiary: return .ultraThin
            case .destructive: return .regular
            case .ghost: return .ultraThin
            case .plain: return .ultraThin
            }
        }
        
        var foregroundColor: Color {
            switch self {
            case .primary: return .white
            case .secondary: return ModernColors.Foreground.primary
            case .tertiary: return ModernColors.Foreground.secondary
            case .destructive: return .white
            case .ghost: return ModernColors.Semantic.accent
            case .plain: return ModernColors.Semantic.accent
            }
        }
        
        var backgroundColor: Color {
            switch self {
            case .primary: return ModernColors.Semantic.accent
            case .secondary: return ModernColors.Background.secondary
            case .tertiary: return ModernColors.Background.tertiary
            case .destructive: return ModernColors.Semantic.error
            case .ghost: return .clear
            case .plain: return .clear
            }
        }
        
        var borderColor: Color? {
            switch self {
            case .ghost: return ModernColors.Semantic.accent.opacity(0.3)
            case .tertiary: return ModernColors.Separator.standard.opacity(0.5)
            default: return nil
            }
        }
    }
    
    /// 按钮尺寸
    enum ButtonSize {
        case small
        case medium
        case large
        
        var height: CGFloat {
            switch self {
            case .small: return 32
            case .medium: return 44
            case .large: return 56
            }
        }
        
        var horizontalPadding: CGFloat {
            switch self {
            case .small: return 12
            case .medium: return 16
            case .large: return 24
            }
        }
        
        var fontSize: CGFloat {
            switch self {
            case .small: return 14
            case .medium: return 16
            case .large: return 18
            }
        }
        
        var iconSize: CGFloat {
            switch self {
            case .small: return 14
            case .medium: return 16
            case .large: return 20
            }
        }
        
        var cornerRadius: CGFloat {
            switch self {
            case .small: return 8
            case .medium: return 12
            case .large: return 16
            }
        }
    }
    
    init(
        _ title: String,
        icon: String? = nil,
        style: ButtonStyle = .primary,
        size: ButtonSize = .medium,
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
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: size.iconSize, weight: .medium))
                }
                
                Text(title)
                    .font(.system(size: size.fontSize, weight: .medium))
            }
            .foregroundColor(effectiveForegroundColor)
            .padding(.horizontal, size.horizontalPadding)
            .frame(height: size.height)
            .background(effectiveBackgroundView)
            .clipShape(RoundedRectangle(cornerRadius: size.cornerRadius))
            .overlay(borderOverlay)
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .opacity(pressedOpacity)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
    }
    
    // MARK: - 计算属性
    
    private var effectiveForegroundColor: Color {
        var color = style.foregroundColor
        
        if isPressed {
            color = color.opacity(0.8)
        } else if isHovered && PlatformAdapter.supportsHover {
            color = color.opacity(0.9)
        }
        
        return color
    }
    
    private var effectiveBackgroundView: some View {
        Group {
            if style == .primary || style == .destructive {
                // 实色背景按钮
                RoundedRectangle(cornerRadius: size.cornerRadius)
                    .fill(style.backgroundColor)
                    .opacity(backgroundOpacity)
            } else if style == .plain {
                // 纯文本按钮无背景
                Color.clear
            } else {
                // 使用 Liquid Glass 材质
                RoundedRectangle(cornerRadius: size.cornerRadius)
                    .fill(style.backgroundColor)
                    .liquidGlass(
                        material: style.material,
                        cornerRadius: size.cornerRadius
                    )
                    .opacity(backgroundOpacity)
            }
        }
    }
    
    private var borderOverlay: some View {
        Group {
            if let borderColor = style.borderColor {
                RoundedRectangle(cornerRadius: size.cornerRadius)
                    .strokeBorder(borderColor, lineWidth: 1)
            } else {
                EmptyView()
            }
        }
    }
    
    private var backgroundOpacity: Double {
        if isPressed {
            return 0.8
        } else if isHovered && PlatformAdapter.supportsHover {
            return 0.9
        } else {
            return 1.0
        }
    }
    
    private var pressedOpacity: Double {
        return isPressed ? 0.9 : 1.0
    }
}

// MARK: - 便利构造器
extension ModernButton {
    /// 创建主要按钮
    static func primary(
        _ title: String,
        icon: String? = nil,
        size: ButtonSize = .medium,
        action: @escaping () -> Void
    ) -> ModernButton {
        ModernButton(title, icon: icon, style: .primary, size: size, action: action)
    }
    
    /// 创建次要按钮
    static func secondary(
        _ title: String,
        icon: String? = nil,
        size: ButtonSize = .medium,
        action: @escaping () -> Void
    ) -> ModernButton {
        ModernButton(title, icon: icon, style: .secondary, size: size, action: action)
    }
    
    /// 创建危险按钮
    static func destructive(
        _ title: String,
        icon: String? = nil,
        size: ButtonSize = .medium,
        action: @escaping () -> Void
    ) -> ModernButton {
        ModernButton(title, icon: icon, style: .destructive, size: size, action: action)
    }
    
    /// 创建幽灵按钮
    static func ghost(
        _ title: String,
        icon: String? = nil,
        size: ButtonSize = .medium,
        action: @escaping () -> Void
    ) -> ModernButton {
        ModernButton(title, icon: icon, style: .ghost, size: size, action: action)
    }
}

// MARK: - 预览
#Preview("Modern Buttons") {
    VStack(spacing: 20) {
        // 不同样式的按钮
        VStack(spacing: 12) {
            Text("按钮样式")
                .font(.headline)
            
            ModernButton.primary("主要按钮", icon: "star.fill") {
                print("Primary tapped")
            }
            
            ModernButton.secondary("次要按钮", icon: "gear") {
                print("Secondary tapped")
            }
            
            ModernButton("三级按钮", icon: "info.circle", style: .tertiary) {
                print("Tertiary tapped")
            }
            
            ModernButton.destructive("删除", icon: "trash") {
                print("Delete tapped")
            }
            
            ModernButton.ghost("幽灵按钮", icon: "eye") {
                print("Ghost tapped")
            }
            
            ModernButton("纯文本", style: .plain) {
                print("Plain tapped")
            }
        }
        
        // 不同尺寸的按钮
        VStack(spacing: 12) {
            Text("按钮尺寸")
                .font(.headline)
            
            ModernButton.primary("小按钮", size: .small) {
                print("Small tapped")
            }
            
            ModernButton.primary("中按钮", size: .medium) {
                print("Medium tapped")
            }
            
            ModernButton.primary("大按钮", size: .large) {
                print("Large tapped")
            }
        }
    }
    .padding()
    .modernBackground(ModernBackgroundLevel.primary)
}
