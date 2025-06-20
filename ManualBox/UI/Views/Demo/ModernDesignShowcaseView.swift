import SwiftUI

// MARK: - 现代化设计展示视图
/// 展示新的 Liquid Glass 材质系统和现代化组件的示例视图
/// 用于演示第一阶段改造成果

struct ModernDesignShowcaseView: View {
    @State private var selectedMaterial: LiquidGlassMaterial = .regular
    @State private var selectedButtonStyle: ModernButton.ButtonStyle = .primary
    @State private var selectedButtonSize: ModernButton.ButtonSize = .medium
    @State private var showAlert = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 标题区域
                headerSection
                
                // Liquid Glass 材质展示
                materialShowcaseSection
                
                // 现代化按钮展示
                buttonShowcaseSection
                
                // 颜色系统展示
                colorSystemSection
                
                // 组合示例
                combinedExampleSection
            }
            .padding()
        }
        .modernBackground(ModernBackgroundLevel.primary)
        .navigationTitle("现代化设计展示")
        .alert("按钮点击", isPresented: $showAlert) {
            Button("确定") { }
        } message: {
            Text("现代化按钮工作正常！")
        }
    }
    
    // MARK: - 标题区域
    private var headerSection: some View {
        VStack(spacing: 12) {
            Text("ManualBox 现代化设计系统")
                .font(.largeTitle)
                .fontWeight(.bold)
                .modernForeground(PlatformForegroundLevel.primary)
            
            Text("基于 macOS 14 和 iOS 17 最新设计规范")
                .font(.headline)
                .modernForeground(PlatformForegroundLevel.secondary)
            
            Text("第一阶段改造成果展示")
                .font(.subheadline)
                .modernForeground(PlatformForegroundLevel.secondary)
        }
        .liquidGlassCard(material: .thin, padding: 24)
    }
    
    // MARK: - 材质展示区域
    private var materialShowcaseSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Liquid Glass 材质系统")
                .font(.title2)
                .fontWeight(.semibold)
                .modernForeground(.primary)
            
            // 材质选择器
            Picker("选择材质", selection: $selectedMaterial) {
                ForEach(LiquidGlassMaterial.allCases, id: \.self) { material in
                    Text(materialDisplayName(material))
                        .tag(material)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            
            // 材质示例卡片
            VStack(spacing: 12) {
                Text("这是一个 \(materialDisplayName(selectedMaterial)) 材质的示例卡片")
                    .font(.body)
                    .modernForeground(PlatformForegroundLevel.primary)
                
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundColor(ModernColors.Semantic.accent)
                    
                    Text("具有现代化的视觉层次感")
                        .font(.caption)
                        .modernForeground(PlatformForegroundLevel.secondary)
                    
                    Spacer()
                }
            }
            .liquidGlassCard(material: selectedMaterial, padding: 20)
        }
        .liquidGlassCard(material: .ultraThin, padding: 20)
    }
    
    // MARK: - 按钮展示区域
    private var buttonShowcaseSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("现代化按钮系统")
                .font(.title2)
                .fontWeight(.semibold)
                .modernForeground(PlatformForegroundLevel.primary)

            // 按钮样式选择器
            VStack(alignment: .leading, spacing: 8) {
                Text("按钮样式")
                    .font(.headline)
                    .modernForeground(PlatformForegroundLevel.primary)
                
                Picker("按钮样式", selection: $selectedButtonStyle) {
                    Text("主要").tag(ModernButton.ButtonStyle.primary)
                    Text("次要").tag(ModernButton.ButtonStyle.secondary)
                    Text("三级").tag(ModernButton.ButtonStyle.tertiary)
                    Text("危险").tag(ModernButton.ButtonStyle.destructive)
                    Text("幽灵").tag(ModernButton.ButtonStyle.ghost)
                    Text("纯文本").tag(ModernButton.ButtonStyle.plain)
                }
                .pickerStyle(MenuPickerStyle())
            }
            
            // 按钮尺寸选择器
            VStack(alignment: .leading, spacing: 8) {
                Text("按钮尺寸")
                    .font(.headline)
                    .modernForeground(PlatformForegroundLevel.primary)
                
                Picker("按钮尺寸", selection: $selectedButtonSize) {
                    Text("小").tag(ModernButton.ButtonSize.small)
                    Text("中").tag(ModernButton.ButtonSize.medium)
                    Text("大").tag(ModernButton.ButtonSize.large)
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            
            // 按钮示例
            HStack {
                ModernButton(
                    "示例按钮",
                    icon: "star.fill",
                    style: selectedButtonStyle,
                    size: selectedButtonSize
                ) {
                    showAlert = true
                }
                
                Spacer()
            }
        }
        .liquidGlassCard(material: .thin, padding: 20)
    }
    
    // MARK: - 颜色系统展示
    private var colorSystemSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("现代化颜色系统")
                .font(.title2)
                .fontWeight(.semibold)
                .modernForeground(PlatformForegroundLevel.primary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                ColorSwatch(color: ModernColors.System.blue, name: "蓝色")
                ColorSwatch(color: ModernColors.System.green, name: "绿色")
                ColorSwatch(color: ModernColors.System.orange, name: "橙色")
                ColorSwatch(color: ModernColors.System.red, name: "红色")
                ColorSwatch(color: ModernColors.System.purple, name: "紫色")
                ColorSwatch(color: ModernColors.System.pink, name: "粉色")
                ColorSwatch(color: ModernColors.System.teal, name: "青色")
                ColorSwatch(color: ModernColors.System.mint, name: "薄荷")
            }
        }
        .liquidGlassCard(material: .thin, padding: 20)
    }
    
    // MARK: - 组合示例
    private var combinedExampleSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("组合示例")
                .font(.title2)
                .fontWeight(.semibold)
                .modernForeground(PlatformForegroundLevel.primary)
            
            // 模拟产品卡片
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "iphone")
                        .font(.title)
                        .foregroundColor(ModernColors.System.blue)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("iPhone 15 Pro")
                            .font(.headline)
                            .modernForeground(PlatformForegroundLevel.primary)

                        Text("智能手机")
                            .font(.caption)
                            .modernForeground(PlatformForegroundLevel.secondary)
                    }
                    
                    Spacer()
                    
                    Text("¥8999")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(ModernColors.Semantic.accent)
                }
                
                Text("这是一个使用新设计系统的产品卡片示例，展示了 Liquid Glass 材质、现代化颜色和排版的组合效果。")
                    .font(.body)
                    .modernForeground(PlatformForegroundLevel.secondary)
                
                HStack {
                    ModernButton.secondary("查看详情", icon: "eye") {
                        showAlert = true
                    }
                    
                    Spacer()
                    
                    ModernButton.primary("添加到收藏", icon: "heart") {
                        showAlert = true
                    }
                }
            }
            .liquidGlassCard(material: .regular, padding: 20)
        }
        .liquidGlassCard(material: .ultraThin, padding: 20)
    }
    
    // MARK: - 辅助方法
    private func materialDisplayName(_ material: LiquidGlassMaterial) -> String {
        switch material {
        case .ultraThin: return "超薄"
        case .thin: return "薄"
        case .regular: return "常规"
        case .thick: return "厚"
        case .ultraThick: return "超厚"
        }
    }
}



// MARK: - 预览
#Preview("Modern Design Showcase") {
    NavigationView {
        ModernDesignShowcaseView()
    }
    .frame(minWidth: 800, minHeight: 600)
}
