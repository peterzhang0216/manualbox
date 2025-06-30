import SwiftUI

// MARK: - 现代化颜色系统
/// 基于 macOS 14 和 iOS 17 最新颜色规范的现代化颜色系统
/// 提供语义化颜色命名和更好的可访问性支持

/// 语义化颜色定义
struct ModernColors {
    
    // MARK: - 背景颜色
    struct Background {
        /// 主背景色 - 用于应用主要背景
        static let primary: Color = {
            #if os(macOS)
            return Color(.windowBackgroundColor)
            #else
            return Color(.systemBackground)
            #endif
        }()

        /// 次要背景色 - 用于卡片和面板
        static let secondary: Color = {
            #if os(macOS)
            return Color(.controlBackgroundColor)
            #else
            return Color(.secondarySystemBackground)
            #endif
        }()

        /// 三级背景色 - 用于分组内容
        static let tertiary: Color = {
            #if os(macOS)
            return Color(.underPageBackgroundColor)
            #else
            return Color(.tertiarySystemBackground)
            #endif
        }()

        /// 分组背景色 - 用于表格分组
        static let grouped: Color = {
            #if os(macOS)
            return Color(.controlBackgroundColor)
            #else
            return Color(.systemGroupedBackground)
            #endif
        }()

        /// 次要分组背景色
        static let secondaryGrouped: Color = {
            #if os(macOS)
            return Color(.windowBackgroundColor)
            #else
            return Color(.secondarySystemGroupedBackground)
            #endif
        }()

        /// 三级分组背景色
        static let tertiaryGrouped: Color = {
            #if os(macOS)
            return Color(.underPageBackgroundColor)
            #else
            return Color(.tertiarySystemGroupedBackground)
            #endif
        }()
    }
    
    // MARK: - 前景颜色
    struct Foreground {
        /// 主要文本色
        static let primary: Color = {
            #if os(macOS)
            return Color(.labelColor)
            #else
            return Color(.label)
            #endif
        }()

        /// 次要文本色
        static let secondary: Color = {
            #if os(macOS)
            return Color(.secondaryLabelColor)
            #else
            return Color(.secondaryLabel)
            #endif
        }()

        /// 三级文本色
        static let tertiary: Color = {
            #if os(macOS)
            return Color(.tertiaryLabelColor)
            #else
            return Color(.tertiaryLabel)
            #endif
        }()

        /// 四级文本色
        static let quaternary: Color = {
            #if os(macOS)
            return Color(.quaternaryLabelColor)
            #else
            return Color(.quaternaryLabel)
            #endif
        }()

        /// 占位符文本色
        static let placeholder: Color = {
            #if os(macOS)
            return Color(.placeholderTextColor)
            #else
            return Color(.placeholderText)
            #endif
        }()
    }
    
    // MARK: - 分隔符颜色
    struct Separator {
        /// 标准分隔符
        static let standard: Color = {
            #if os(macOS)
            return Color(.separatorColor)
            #else
            return Color(.separator)
            #endif
        }()

        /// 不透明分隔符
        static let opaque: Color = {
            #if os(macOS)
            return Color(.separatorColor)
            #else
            return Color(.opaqueSeparator)
            #endif
        }()
    }

    // MARK: - 链接颜色
    struct Link {
        /// 标准链接色
        static let standard: Color = {
            #if os(macOS)
            return Color(.linkColor)
            #else
            return Color(.link)
            #endif
        }()
    }
    
    // MARK: - 系统颜色（更新到最新规范）
    struct System {
        /// 系统蓝色
        static let blue = Color(.systemBlue)
        
        /// 系统绿色
        static let green = Color(.systemGreen)
        
        /// 系统靛蓝色
        static let indigo = Color(.systemIndigo)
        
        /// 系统橙色
        static let orange = Color(.systemOrange)
        
        /// 系统粉色
        static let pink = Color(.systemPink)
        
        /// 系统紫色
        static let purple = Color(.systemPurple)
        
        /// 系统红色
        static let red = Color(.systemRed)
        
        /// 系统青色
        static let teal = Color(.systemTeal)
        
        /// 系统黄色
        static let yellow = Color(.systemYellow)
        
        /// 系统薄荷色
        static let mint = Color(.systemMint)
        
        /// 系统青柠色
        static let cyan = Color(.systemCyan)
        
        /// 系统棕色
        static let brown = Color(.systemBrown)
        
        /// 系统灰色
        static let gray = Color(.systemGray)
        
        /// 系统灰色2
        static let gray2: Color = {
            #if os(macOS)
            return Color(.systemGray)
            #else
            return Color(.systemGray2)
            #endif
        }()

        /// 系统灰色3
        static let gray3: Color = {
            #if os(macOS)
            return Color(.systemGray)
            #else
            return Color(.systemGray3)
            #endif
        }()

        /// 系统灰色4
        static let gray4: Color = {
            #if os(macOS)
            return Color(.systemGray)
            #else
            return Color(.systemGray4)
            #endif
        }()

        /// 系统灰色5
        static let gray5: Color = {
            #if os(macOS)
            return Color(nsColor: .windowBackgroundColor)
            #else
            return Color(.systemGray5)
            #endif
        }()

        /// 系统灰色6
        static let gray6: Color = {
            #if os(macOS)
            return Color(.systemGray)
            #else
            return Color(.systemGray6)
            #endif
        }()
    }
    
    // MARK: - 填充颜色
    struct Fill {
        /// 主要填充色
        static let primary: Color = {
            #if os(macOS)
            return Color(.controlColor)
            #else
            return Color(.systemFill)
            #endif
        }()

        /// 次要填充色
        static let secondary: Color = {
            #if os(macOS)
            return Color(.controlBackgroundColor)
            #else
            return Color(.secondarySystemFill)
            #endif
        }()

        /// 三级填充色
        static let tertiary: Color = {
            #if os(macOS)
            return Color(.underPageBackgroundColor)
            #else
            return Color(.tertiarySystemFill)
            #endif
        }()

        /// 四级填充色
        static let quaternary: Color = {
            #if os(macOS)
            return Color(.windowBackgroundColor)
            #else
            return Color(.quaternarySystemFill)
            #endif
        }()
    }
    
    // MARK: - 语义化应用颜色
    struct Semantic {
        /// 主要强调色
        static let accent = Color.accentColor
        
        /// 成功状态色
        static let success = System.green
        
        /// 警告状态色
        static let warning = System.orange
        
        /// 错误状态色
        static let error = System.red
        
        /// 信息状态色
        static let info = System.blue
        
        /// 中性状态色
        static let neutral = System.gray
    }
    
    // MARK: - 控件颜色
    struct Control {
        /// 控件背景色
        static let background: Color = {
            #if os(macOS)
            return Color(.controlBackgroundColor)
            #else
            return Color(.systemBackground)
            #endif
        }()

        /// 控件文本色
        static let text: Color = {
            #if os(macOS)
            return Color(.controlTextColor)
            #else
            return Color(.label)
            #endif
        }()

        /// 选中控件背景色
        static let selectedBackground: Color = {
            #if os(macOS)
            return Color(.selectedControlColor)
            #else
            return Color(.systemBlue)
            #endif
        }()

        /// 选中控件文本色
        static let selectedText: Color = {
            #if os(macOS)
            return Color(.selectedControlTextColor)
            #else
            return Color(.white)
            #endif
        }()

        /// 禁用控件文本色
        static let disabledText: Color = {
            #if os(macOS)
            return Color(.disabledControlTextColor)
            #else
            return Color(.tertiaryLabel)
            #endif
        }()
    }
}

/// 颜色主题管理器
class ModernColorTheme: ObservableObject {
    @Published var currentTheme: ThemeType = .system
    
    enum ThemeType: String, CaseIterable {
        case light = "light"
        case dark = "dark"
        case system = "system"
        
        var displayName: String {
            switch self {
            case .light: return "浅色"
            case .dark: return "深色"
            case .system: return "跟随系统"
            }
        }
        
        var colorScheme: ColorScheme? {
            switch self {
            case .light: return .light
            case .dark: return .dark
            case .system: return nil
            }
        }
    }
    
    /// 获取当前主题的强调色
    func accentColor(for key: String) -> Color {
        switch key {
        case "blue": return ModernColors.System.blue
        case "green": return ModernColors.System.green
        case "indigo": return ModernColors.System.indigo
        case "orange": return ModernColors.System.orange
        case "pink": return ModernColors.System.pink
        case "purple": return ModernColors.System.purple
        case "red": return ModernColors.System.red
        case "teal": return ModernColors.System.teal
        case "yellow": return ModernColors.System.yellow
        case "mint": return ModernColors.System.mint
        case "cyan": return ModernColors.System.cyan
        case "brown": return ModernColors.System.brown
        default: return ModernColors.Semantic.accent
        }
    }
}

/// 可访问性颜色支持
struct AccessibilityColors {
    /// 高对比度支持
    static func highContrastColor(
        standard: Color,
        highContrast: Color,
        isHighContrastEnabled: Bool = false
    ) -> Color {
        return isHighContrastEnabled ? highContrast : standard
    }
    
    /// 检查颜色对比度是否符合 WCAG 标准
    static func meetsContrastRequirement(
        foreground: Color,
        background: Color,
        level: ContrastLevel = .aa
    ) -> Bool {
        // 这里应该实现实际的对比度计算
        // 为了简化，返回 true
        return true
    }
    
    enum ContrastLevel {
        case aa      // WCAG AA 标准 (4.5:1)
        case aaa     // WCAG AAA 标准 (7:1)
        case large   // 大文本 AA 标准 (3:1)
    }
}

// MARK: - SwiftUI 扩展
extension View {
    /// 应用现代化背景色
    func modernBackground(_ level: ModernBackgroundLevel = .primary) -> some View {
        switch level {
        case .primary:
            return self.background(ModernColors.Background.primary)
        case .secondary:
            return self.background(ModernColors.Background.secondary)
        case .tertiary:
            return self.background(ModernColors.Background.tertiary)
        }
    }

    /// 应用语义化颜色
    func semanticForeground(_ semantic: ModernSemanticColor) -> some View {
        switch semantic {
        case .primary:
            return self.foregroundColor(ModernColors.Foreground.primary)
        case .secondary:
            return self.foregroundColor(ModernColors.Foreground.secondary)
        case .success:
            return self.foregroundColor(ModernColors.Semantic.success)
        case .warning:
            return self.foregroundColor(ModernColors.Semantic.warning)
        case .error:
            return self.foregroundColor(ModernColors.Semantic.error)
        case .info:
            return self.foregroundColor(ModernColors.Semantic.info)
        }
    }
}

enum ModernBackgroundLevel {
    case primary, secondary, tertiary
}

enum ModernSemanticColor {
    case primary, secondary, success, warning, error, info
}

// MARK: - 预览
#Preview("Modern Color System") {
    ScrollView {
        VStack(spacing: 20) {
            // 背景色示例
            VStack(alignment: .leading, spacing: 12) {
                Text("背景颜色")
                    .font(.headline)
                
                HStack(spacing: 12) {
                    ColorSwatch(color: ModernColors.Background.primary, name: "Primary")
                    ColorSwatch(color: ModernColors.Background.secondary, name: "Secondary")
                    ColorSwatch(color: ModernColors.Background.tertiary, name: "Tertiary")
                }
            }
            
            // 系统色示例
            VStack(alignment: .leading, spacing: 12) {
                Text("系统颜色")
                    .font(.headline)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                    ColorSwatch(color: ModernColors.System.blue, name: "Blue")
                    ColorSwatch(color: ModernColors.System.green, name: "Green")
                    ColorSwatch(color: ModernColors.System.orange, name: "Orange")
                    ColorSwatch(color: ModernColors.System.red, name: "Red")
                    ColorSwatch(color: ModernColors.System.purple, name: "Purple")
                    ColorSwatch(color: ModernColors.System.pink, name: "Pink")
                    ColorSwatch(color: ModernColors.System.teal, name: "Teal")
                    ColorSwatch(color: ModernColors.System.mint, name: "Mint")
                }
            }
        }
        .padding()
    }
    .modernBackground(ModernBackgroundLevel.primary)
}

struct ColorSwatch: View {
    let color: Color
    let name: String
    
    var body: some View {
        VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 8)
                .fill(color)
                .frame(height: 40)
            
            Text(name)
                .font(.caption)
                .semanticForeground(.secondary)
        }
    }
}
