import SwiftUI
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

// MARK: - 统一设计系统
struct UnifiedDesignSystem {
    
    // MARK: - 颜色系统
    struct Colors {
        // 主色调
        static let primary = Color.accentColor
        static let secondary = Color.secondary
        
        // 背景色
        static let background: Color = {
            #if os(macOS)
            return Color(NSColor.controlBackgroundColor)
            #else
            return Color(.systemBackground)
            #endif
        }()
        
        static let secondaryBackground: Color = {
            #if os(macOS)
            return Color(NSColor.controlColor)
            #else
            return Color(.secondarySystemBackground)
            #endif
        }()
        
        static let tertiaryBackground: Color = {
            #if os(macOS)
            return Color(NSColor.tertiaryLabelColor).opacity(0.1)
            #else
            return Color(.tertiarySystemBackground)
            #endif
        }()
        
        // 分组背景色
        static let groupedBackground: Color = {
            #if os(macOS)
            return Color(NSColor.controlBackgroundColor)
            #else
            return Color(.systemGroupedBackground)
            #endif
        }()
        
        static let secondaryGroupedBackground: Color = {
            #if os(macOS)
            return Color(NSColor.controlColor)
            #else
            return Color(.secondarySystemGroupedBackground)
            #endif
        }()
        
        // 分隔线
        static let separator: Color = {
            #if os(macOS)
            return Color(NSColor.separatorColor)
            #else
            return Color(.separator)
            #endif
        }()
        
        // 状态色
        static let success = Color.green
        static let warning = Color.orange
        static let error = Color.red
        static let info = Color.blue
        
        // 文本色
        static let primaryText: Color = {
            #if os(macOS)
            return Color(NSColor.labelColor)
            #else
            return Color(.label)
            #endif
        }()
        
        static let secondaryText: Color = {
            #if os(macOS)
            return Color(NSColor.secondaryLabelColor)
            #else
            return Color(.secondaryLabel)
            #endif
        }()
        
        static let tertiaryText: Color = {
            #if os(macOS)
            return Color(NSColor.tertiaryLabelColor)
            #else
            return Color(.tertiaryLabel)
            #endif
        }()
    }
    
    // MARK: - 字体系统
    struct Typography {
        // 标题字体
        static let largeTitle = Font.largeTitle.weight(.bold)
        static let title1 = Font.title.weight(.semibold)
        static let title2 = Font.title2.weight(.semibold)
        static let title3 = Font.title3.weight(.medium)
        
        // 正文字体
        static let headline = Font.headline.weight(.semibold)
        static let body = Font.body
        static let callout = Font.callout
        static let subheadline = Font.subheadline
        static let footnote = Font.footnote
        static let caption1 = Font.caption
        static let caption2 = Font.caption2
        
        // 特殊字体
        static let monospaced = Font.system(.body, design: .monospaced)
        static let rounded = Font.system(.body, design: .rounded)
    }
    
    // MARK: - 间距系统
    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let xxxl: CGFloat = 32
        
        // 平台特定间距
        static let defaultPadding: CGFloat = {
            #if os(macOS)
            return 16
            #else
            return 16
            #endif
        }()
        
        static let sectionSpacing: CGFloat = {
            #if os(macOS)
            return 20
            #else
            return 24
            #endif
        }()
        
        static let groupSpacing: CGFloat = {
            #if os(macOS)
            return 12
            #else
            return 16
            #endif
        }()
    }
    
    // MARK: - 圆角系统
    struct CornerRadius {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 6
        static let md: CGFloat = 8
        static let lg: CGFloat = 12
        static let xl: CGFloat = 16
        static let xxl: CGFloat = 20
        
        // 平台特定圆角
        static let card: CGFloat = {
            #if os(macOS)
            return 8
            #else
            return 12
            #endif
        }()
        
        static let button: CGFloat = {
            #if os(macOS)
            return 6
            #else
            return 8
            #endif
        }()
        
        static let sheet: CGFloat = {
            #if os(macOS)
            return 12
            #else
            return 16
            #endif
        }()
    }
    
    // MARK: - 阴影系统
    struct Shadow {
        static let light = (color: Color.black.opacity(0.05), radius: CGFloat(2), x: CGFloat(0), y: CGFloat(1))
        static let medium = (color: Color.black.opacity(0.1), radius: CGFloat(4), x: CGFloat(0), y: CGFloat(2))
        static let heavy = (color: Color.black.opacity(0.15), radius: CGFloat(8), x: CGFloat(0), y: CGFloat(4))
        
        // 平台特定阴影
        static let card: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) = {
            #if os(macOS)
            return (Color.black.opacity(0.08), 3, 0, 1)
            #else
            return (Color.black.opacity(0.1), 4, 0, 2)
            #endif
        }()
    }
    
    // MARK: - 动画系统
    struct Animations {
        static let quick = Animation.easeInOut(duration: 0.2)
        static let standard = Animation.easeInOut(duration: 0.3)
        static let slow = Animation.easeInOut(duration: 0.5)
        
        static let spring = Animation.spring(response: 0.5, dampingFraction: 0.8)
        static let bouncy = Animation.spring(response: 0.4, dampingFraction: 0.6)
        
        // 平台特定动画
        static let platformDefault: Animation = {
            #if os(macOS)
            return .easeInOut(duration: 0.25)
            #else
            return .spring(response: 0.5, dampingFraction: 0.8)
            #endif
        }()
        
        static let listAnimation: Animation = {
            #if os(macOS)
            return .easeOut(duration: 0.2)
            #else
            return .spring(response: 0.4, dampingFraction: 0.9)
            #endif
        }()
    }
    
    // MARK: - 尺寸系统
    struct Sizes {
        // 触摸目标
        static let minimumTouchTarget: CGFloat = {
            #if os(macOS)
            return 24
            #else
            return 44
            #endif
        }()
        
        // 图标尺寸
        static let iconXS: CGFloat = 12
        static let iconSM: CGFloat = 16
        static let iconMD: CGFloat = 20
        static let iconLG: CGFloat = 24
        static let iconXL: CGFloat = 32
        
        // 头像尺寸
        static let avatarSM: CGFloat = 32
        static let avatarMD: CGFloat = 40
        static let avatarLG: CGFloat = 56
        static let avatarXL: CGFloat = 80
        
        // 按钮高度
        static let buttonHeight: CGFloat = {
            #if os(macOS)
            return 32
            #else
            return 44
            #endif
        }()
        
        // 输入框高度
        static let inputHeight: CGFloat = {
            #if os(macOS)
            return 28
            #else
            return 44
            #endif
        }()
    }
}

// MARK: - 设计系统视图修饰符
extension View {
    
    // MARK: - 背景修饰符
    func unifiedBackground(_ level: BackgroundLevel = .primary) -> some View {
        self.background(level.color)
    }
    
    func unifiedCard() -> some View {
        self
            .padding(UnifiedDesignSystem.Spacing.defaultPadding)
            .background(UnifiedDesignSystem.Colors.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: UnifiedDesignSystem.CornerRadius.card))
            .shadow(
                color: UnifiedDesignSystem.Shadow.card.color,
                radius: UnifiedDesignSystem.Shadow.card.radius,
                x: UnifiedDesignSystem.Shadow.card.x,
                y: UnifiedDesignSystem.Shadow.card.y
            )
    }
    
    // MARK: - 文本修饰符
    func unifiedTitle(_ level: TitleLevel = .title1) -> some View {
        self.font(level.font)
            .foregroundColor(UnifiedDesignSystem.Colors.primaryText)
    }
    
    func unifiedBody(_ level: BodyLevel = .body) -> some View {
        self.font(level.font)
            .foregroundColor(level.color)
    }
    
    // MARK: - 交互修饰符
    func unifiedTouchTarget() -> some View {
        self.frame(minHeight: UnifiedDesignSystem.Sizes.minimumTouchTarget)
    }
    
    func unifiedHover() -> some View {
        #if os(macOS)
        self.onHover { isHovering in
            // macOS 悬停效果
        }
        #else
        self
        #endif
    }
    
    // MARK: - 动画修饰符
    func unifiedAnimation(_ type: AnimationType = .standard) -> some View {
        self.animation(type.animation, value: UUID())
    }
}

// MARK: - 设计系统枚举
enum BackgroundLevel {
    case primary, secondary, tertiary, grouped, secondaryGrouped
    
    var color: Color {
        switch self {
        case .primary: return UnifiedDesignSystem.Colors.background
        case .secondary: return UnifiedDesignSystem.Colors.secondaryBackground
        case .tertiary: return UnifiedDesignSystem.Colors.tertiaryBackground
        case .grouped: return UnifiedDesignSystem.Colors.groupedBackground
        case .secondaryGrouped: return UnifiedDesignSystem.Colors.secondaryGroupedBackground
        }
    }
}

enum TitleLevel {
    case largeTitle, title1, title2, title3, headline
    
    var font: Font {
        switch self {
        case .largeTitle: return UnifiedDesignSystem.Typography.largeTitle
        case .title1: return UnifiedDesignSystem.Typography.title1
        case .title2: return UnifiedDesignSystem.Typography.title2
        case .title3: return UnifiedDesignSystem.Typography.title3
        case .headline: return UnifiedDesignSystem.Typography.headline
        }
    }
}

enum BodyLevel {
    case body, callout, subheadline, footnote, caption1, caption2
    
    var font: Font {
        switch self {
        case .body: return UnifiedDesignSystem.Typography.body
        case .callout: return UnifiedDesignSystem.Typography.callout
        case .subheadline: return UnifiedDesignSystem.Typography.subheadline
        case .footnote: return UnifiedDesignSystem.Typography.footnote
        case .caption1: return UnifiedDesignSystem.Typography.caption1
        case .caption2: return UnifiedDesignSystem.Typography.caption2
        }
    }
    
    var color: Color {
        switch self {
        case .body: return UnifiedDesignSystem.Colors.primaryText
        case .callout, .subheadline: return UnifiedDesignSystem.Colors.secondaryText
        case .footnote, .caption1, .caption2: return UnifiedDesignSystem.Colors.tertiaryText
        }
    }
}

enum AnimationType {
    case quick, standard, slow, spring, bouncy, platform, list
    
    var animation: Animation {
        switch self {
        case .quick: return UnifiedDesignSystem.Animations.quick
        case .standard: return UnifiedDesignSystem.Animations.standard
        case .slow: return UnifiedDesignSystem.Animations.slow
        case .spring: return UnifiedDesignSystem.Animations.spring
        case .bouncy: return UnifiedDesignSystem.Animations.bouncy
        case .platform: return UnifiedDesignSystem.Animations.platformDefault
        case .list: return UnifiedDesignSystem.Animations.listAnimation
        }
    }
}
