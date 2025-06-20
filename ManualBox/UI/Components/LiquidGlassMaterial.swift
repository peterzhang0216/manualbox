import SwiftUI

// MARK: - Liquid Glass 材质系统
/// 基于 macOS 14 和 iOS 17 最新设计规范的 Liquid Glass 材质系统
/// 提供现代化的视觉层次和深度感知

/// Liquid Glass 材质类型
enum LiquidGlassMaterial: CaseIterable {
    case ultraThin      // 超薄材质 - 用于浮动元素
    case thin           // 薄材质 - 用于卡片和面板
    case regular        // 常规材质 - 用于主要内容区域
    case thick          // 厚材质 - 用于模态视图
    case ultraThick     // 超厚材质 - 用于重要提示
    
    /// 模糊半径
    var blurRadius: CGFloat {
        switch self {
        case .ultraThin: return 10
        case .thin: return 20
        case .regular: return 30
        case .thick: return 40
        case .ultraThick: return 50
        }
    }
    
    /// 透明度
    var opacity: Double {
        switch self {
        case .ultraThin: return 0.6
        case .thin: return 0.7
        case .regular: return 0.8
        case .thick: return 0.85
        case .ultraThick: return 0.9
        }
    }
    
    /// 边框透明度
    var borderOpacity: Double {
        switch self {
        case .ultraThin: return 0.1
        case .thin: return 0.15
        case .regular: return 0.2
        case .thick: return 0.25
        case .ultraThick: return 0.3
        }
    }
    
    /// 阴影配置
    var shadowConfig: ShadowConfig {
        switch self {
        case .ultraThin:
            return ShadowConfig(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        case .thin:
            return ShadowConfig(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
        case .regular:
            return ShadowConfig(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        case .thick:
            return ShadowConfig(color: .black.opacity(0.12), radius: 12, x: 0, y: 6)
        case .ultraThick:
            return ShadowConfig(color: .black.opacity(0.15), radius: 16, x: 0, y: 8)
        }
    }
}

/// 阴影配置
struct ShadowConfig {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

/// Liquid Glass 视觉效果修饰符
struct LiquidGlassEffect: ViewModifier {
    let material: LiquidGlassMaterial
    let cornerRadius: CGFloat
    let borderWidth: CGFloat
    
    @Environment(\.colorScheme) private var colorScheme
    
    init(
        material: LiquidGlassMaterial = .regular,
        cornerRadius: CGFloat = 12,
        borderWidth: CGFloat = 0.5
    ) {
        self.material = material
        self.cornerRadius = cornerRadius
        self.borderWidth = borderWidth
    }
    
    func body(content: Content) -> some View {
        content
            .background(backgroundMaterial)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(borderOverlay)
            .shadow(
                color: material.shadowConfig.color,
                radius: material.shadowConfig.radius,
                x: material.shadowConfig.x,
                y: material.shadowConfig.y
            )
    }
    
    /// 背景材质
    private var backgroundMaterial: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(backgroundFill)
            .background(
                // 模糊背景效果
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.ultraThinMaterial)
                    .opacity(material.opacity)
            )
    }
    
    /// 背景填充色
    private var backgroundFill: some ShapeStyle {
        if colorScheme == .dark {
            return .regularMaterial.opacity(material.opacity * 0.8)
        } else {
            return .regularMaterial.opacity(material.opacity)
        }
    }
    
    /// 边框叠加层
    private var borderOverlay: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .strokeBorder(
                LinearGradient(
                    colors: [
                        .white.opacity(material.borderOpacity),
                        .clear,
                        .black.opacity(material.borderOpacity * 0.3)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: borderWidth
            )
    }
}

/// Liquid Glass 卡片组件
struct LiquidGlassCard<Content: View>: View {
    let content: () -> Content
    let material: LiquidGlassMaterial
    let padding: CGFloat
    let cornerRadius: CGFloat
    
    init(
        material: LiquidGlassMaterial = .thin,
        padding: CGFloat = 16,
        cornerRadius: CGFloat = 12,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.content = content
        self.material = material
        self.padding = padding
        self.cornerRadius = cornerRadius
    }
    
    var body: some View {
        content()
            .padding(padding)
            .modifier(LiquidGlassEffect(
                material: material,
                cornerRadius: cornerRadius
            ))
    }
}

/// Liquid Glass 工具栏组件
struct LiquidGlassToolbar<Content: View>: View {
    let content: () -> Content
    let material: LiquidGlassMaterial
    let height: CGFloat
    
    init(
        material: LiquidGlassMaterial = .regular,
        height: CGFloat = 44,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.content = content
        self.material = material
        self.height = height
    }
    
    var body: some View {
        HStack {
            content()
        }
        .frame(height: height)
        .padding(.horizontal, 16)
        .modifier(LiquidGlassEffect(
            material: material,
            cornerRadius: 0
        ))
    }
}

/// Liquid Glass 侧边栏组件
struct LiquidGlassSidebar<Content: View>: View {
    let content: () -> Content
    let material: LiquidGlassMaterial
    let width: CGFloat
    
    init(
        material: LiquidGlassMaterial = .thin,
        width: CGFloat = 280,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.content = content
        self.material = material
        self.width = width
    }
    
    var body: some View {
        content()
            .frame(width: width)
            .modifier(LiquidGlassEffect(
                material: material,
                cornerRadius: 0
            ))
    }
}

// MARK: - SwiftUI 扩展
extension View {
    /// 应用 Liquid Glass 效果
    func liquidGlass(
        material: LiquidGlassMaterial = .regular,
        cornerRadius: CGFloat = 12,
        borderWidth: CGFloat = 0.5
    ) -> some View {
        self.modifier(LiquidGlassEffect(
            material: material,
            cornerRadius: cornerRadius,
            borderWidth: borderWidth
        ))
    }
    
    /// 应用 Liquid Glass 卡片样式
    func liquidGlassCard(
        material: LiquidGlassMaterial = .thin,
        padding: CGFloat = 16,
        cornerRadius: CGFloat = 12
    ) -> some View {
        self
            .padding(padding)
            .liquidGlass(
                material: material,
                cornerRadius: cornerRadius
            )
    }
}

// MARK: - 预览
#Preview("Liquid Glass Materials") {
    VStack(spacing: 20) {
        ForEach(LiquidGlassMaterial.allCases, id: \.self) { material in
            LiquidGlassCard(material: material) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(String(describing: material).capitalized)")
                        .font(.headline)
                    Text("这是一个 \(String(describing: material)) 材质的示例卡片")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    .padding()
    .background(
        LinearGradient(
            colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    )
}
