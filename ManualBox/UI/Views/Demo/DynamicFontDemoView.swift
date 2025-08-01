//
//  DynamicFontDemoView.swift
//  ManualBox
//
//  Created by Assistant on 2024/12/19.
//  动态字体演示视图 - 展示各种字体大小和无障碍功能的应用
//

import SwiftUI

struct DynamicFontDemoView: View {
    @StateObject private var fontManager = DynamicFontManager.shared
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // 字体大小演示
            fontSizesDemo
                .tabItem {
                    Image(systemName: "textformat.size")
                    Text("字体大小")
                        .dynamicFont(.caption)
                }
                .tag(0)
            
            // 布局适应演示
            layoutAdaptationDemo
                .tabItem {
                    Image(systemName: "rectangle.3.group")
                    Text("布局适应")
                        .dynamicFont(.caption)
                }
                .tag(1)
            
            // 高对比度演示
            highContrastDemo
                .tabItem {
                    Image(systemName: "circle.lefthalf.striped.horizontal")
                    Text("高对比度")
                        .dynamicFont(.caption)
                }
                .tag(2)
            
            // 实际应用演示
            realWorldDemo
                .tabItem {
                    Image(systemName: "app.badge")
                    Text("实际应用")
                        .dynamicFont(.caption)
                }
                .tag(3)
        }
        .navigationTitle("动态字体演示")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - 字体大小演示
    
    private var fontSizesDemo: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection("字体大小层级", subtitle: "展示不同字体大小在当前设置下的显示效果")
                
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(FontSize.allCases, id: \.self) { size in
                        fontSizeRow(for: size)
                    }
                }
                .padding()
                .background(adaptiveCardBackground)
                .cornerRadius(12)
                
                // 系统信息卡片
                systemInfoCard
            }
            .padding()
        }
    }
    
    private func fontSizeRow(for size: FontSize) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(size.description)
                    .dynamicFont(.caption, weight: .medium)
                    .foregroundColor(adaptiveSecondaryColor)
                
                Spacer()
                
                Text("\(Int(fontManager.getScaledFontSize(for: size)))pt")
                    .dynamicFont(.caption2)
                    .foregroundColor(adaptiveSecondaryColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(adaptiveSecondaryColor.opacity(0.2))
                    )
            }
            
            Text("这是 \(size.description) 字体大小的示例文本")
                .font(fontManager.font(for: size))
                .foregroundColor(adaptivePrimaryColor)
                .lineSpacing(fontManager.lineSpacing(for: size))
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - 布局适应演示
    
    private var layoutAdaptationDemo: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection("布局自适应", subtitle: "展示界面如何根据字体大小调整布局")
                
                // 卡片布局示例
                cardLayoutExample
                
                // 列表布局示例
                listLayoutExample
                
                // 表单布局示例
                formLayoutExample
            }
            .padding()
        }
    }
    
    private var cardLayoutExample: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("卡片布局")
                .dynamicFont(.headline, weight: .semibold)
                .foregroundColor(adaptivePrimaryColor)
            
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: fontManager.currentContentSizeCategory.isAccessibilityCategory ? 1 : 2),
                spacing: 12
            ) {
                ForEach(0..<4, id: \.self) { index in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                                .font(.system(size: fontManager.getScaledFontSize(for: .title3)))
                            
                            Text("项目 \(index + 1)")
                                .dynamicFont(.headline, weight: .medium)
                                .foregroundColor(adaptivePrimaryColor)
                            
                            Spacer()
                        }
                        
                        Text("这是一个示例卡片，展示内容如何根据字体大小自动调整。")
                            .dynamicFont(.body)
                            .foregroundColor(adaptiveSecondaryColor)
                            .lineSpacing(fontManager.lineSpacing(for: .body))
                    }
                    .padding()
                    .background(adaptiveCardBackground)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(adaptiveBorderColor, lineWidth: fontManager.isHighContrastEnabled ? 2 : 1)
                    )
                }
            }
        }
    }
    
    private var listLayoutExample: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("列表布局")
                .dynamicFont(.headline, weight: .semibold)
                .foregroundColor(adaptivePrimaryColor)
            
            VStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { index in
                    HStack(spacing: 12) {
                        Image(systemName: "doc.text")
                            .foregroundColor(adaptiveAccentColor)
                            .font(.system(size: fontManager.getScaledFontSize(for: .title2)))
                            .frame(width: 40, height: 40)
                            .background(
                                Circle()
                                    .fill(adaptiveAccentColor.opacity(0.1))
                            )
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("列表项目 \(index + 1)")
                                .dynamicFont(.subheadline, weight: .medium)
                                .foregroundColor(adaptivePrimaryColor)
                            
                            Text("副标题文本，展示较小字体的显示效果")
                                .dynamicFont(.caption)
                                .foregroundColor(adaptiveSecondaryColor)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(adaptiveSecondaryColor)
                            .font(.system(size: fontManager.getScaledFontSize(for: .caption)))
                    }
                    .padding()
                    .background(adaptiveCardBackground)
                    .cornerRadius(8)
                }
            }
        }
    }
    
    private var formLayoutExample: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("表单布局")
                .dynamicFont(.headline, weight: .semibold)
                .foregroundColor(adaptivePrimaryColor)
            
            VStack(spacing: fontManager.paragraphSpacing(for: .body)) {
                // 文本输入字段
                VStack(alignment: .leading, spacing: 4) {
                    Text("产品名称")
                        .dynamicFont(.subheadline, weight: .medium)
                        .foregroundColor(adaptivePrimaryColor)
                    
                    TextField("请输入产品名称", text: .constant("示例产品"))
                        .dynamicFont(.body)
                        .padding()
                        .background(adaptiveCardBackground)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(adaptiveBorderColor, lineWidth: fontManager.isHighContrastEnabled ? 2 : 1)
                        )
                }
                
                // 选择器字段
                VStack(alignment: .leading, spacing: 4) {
                    Text("产品类别")
                        .dynamicFont(.subheadline, weight: .medium)
                        .foregroundColor(adaptivePrimaryColor)
                    
                    HStack {
                        Text("电子产品")
                            .dynamicFont(.body)
                            .foregroundColor(adaptivePrimaryColor)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.down")
                            .foregroundColor(adaptiveSecondaryColor)
                            .font(.system(size: fontManager.getScaledFontSize(for: .caption)))
                    }
                    .padding()
                    .background(adaptiveCardBackground)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(adaptiveBorderColor, lineWidth: fontManager.isHighContrastEnabled ? 2 : 1)
                    )
                }
            }
            .padding()
            .background(adaptiveCardBackground)
            .cornerRadius(12)
        }
    }
    
    // MARK: - 高对比度演示
    
    private var highContrastDemo: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection("高对比度模式", subtitle: "展示高对比度模式下的界面效果")
                
                // 对比度状态
                contrastStatusCard
                
                // 颜色对比示例
                colorContrastExamples
                
                // 边框和分隔线示例
                borderExamples
            }
            .padding()
        }
    }
    
    private var contrastStatusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: fontManager.isHighContrastEnabled ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(fontManager.isHighContrastEnabled ? .green : adaptiveSecondaryColor)
                    .font(.system(size: fontManager.getScaledFontSize(for: .title2)))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("高对比度模式")
                        .dynamicFont(.headline, weight: .semibold)
                        .foregroundColor(adaptivePrimaryColor)
                    
                    Text(fontManager.isHighContrastEnabled ? "已启用" : "未启用")
                        .dynamicFont(.subheadline)
                        .foregroundColor(adaptiveSecondaryColor)
                }
                
                Spacer()
            }
            
            Text("高对比度模式可以提高文本和界面元素的可读性，特别适合视力较弱的用户。")
                .dynamicFont(.body)
                .foregroundColor(adaptiveSecondaryColor)
                .lineSpacing(fontManager.lineSpacing(for: .body))
        }
        .padding()
        .background(adaptiveCardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(adaptiveBorderColor, lineWidth: fontManager.isHighContrastEnabled ? 2 : 1)
        )
    }
    
    private var colorContrastExamples: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("颜色对比示例")
                .dynamicFont(.headline, weight: .semibold)
                .foregroundColor(adaptivePrimaryColor)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                colorContrastCard(title: "主要文本", color: adaptivePrimaryColor, background: adaptiveCardBackground)
                colorContrastCard(title: "次要文本", color: adaptiveSecondaryColor, background: adaptiveCardBackground)
                colorContrastCard(title: "强调色", color: adaptiveAccentColor, background: adaptiveCardBackground)
                colorContrastCard(title: "成功状态", color: adaptiveSuccessColor, background: adaptiveCardBackground)
            }
        }
    }
    
    private func colorContrastCard(title: String, color: Color, background: Color) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .dynamicFont(.subheadline, weight: .medium)
                .foregroundColor(color)
            
            Text("示例文本")
                .dynamicFont(.body)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(background)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(adaptiveBorderColor, lineWidth: fontManager.isHighContrastEnabled ? 2 : 1)
        )
    }
    
    private var borderExamples: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("边框和分隔线")
                .dynamicFont(.headline, weight: .semibold)
                .foregroundColor(adaptivePrimaryColor)
            
            VStack(spacing: 8) {
                Text("普通边框")
                    .dynamicFont(.body)
                    .foregroundColor(adaptivePrimaryColor)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray, lineWidth: 1)
                    )
                
                Text("高对比度边框")
                    .dynamicFont(.body)
                    .foregroundColor(adaptivePrimaryColor)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(adaptiveBorderColor, lineWidth: fontManager.isHighContrastEnabled ? 2 : 1)
                    )
            }
        }
    }
    
    // MARK: - 实际应用演示
    
    private var realWorldDemo: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection("实际应用场景", subtitle: "展示动态字体在真实界面中的应用")
                
                // 产品卡片示例
                productCardExample
                
                // 设置界面示例
                settingsInterfaceExample
                
                // 通知界面示例
                notificationExample
            }
            .padding()
        }
    }
    
    private var productCardExample: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("产品卡片")
                .dynamicFont(.headline, weight: .semibold)
                .foregroundColor(adaptivePrimaryColor)
            
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    // 产品图片占位符
                    RoundedRectangle(cornerRadius: 8)
                        .fill(adaptiveAccentColor.opacity(0.2))
                        .frame(width: 60 * fontManager.fontScaleFactor, height: 60 * fontManager.fontScaleFactor)
                        .overlay(
                            Image(systemName: "iphone")
                                .foregroundColor(adaptiveAccentColor)
                                .font(.system(size: fontManager.getScaledFontSize(for: .title2)))
                        )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("iPhone 15 Pro")
                            .dynamicFont(.headline, weight: .semibold)
                            .foregroundColor(adaptivePrimaryColor)
                        
                        Text("购买于 2024年1月15日")
                            .dynamicFont(.subheadline)
                            .foregroundColor(adaptiveSecondaryColor)
                        
                        Text("保修期至 2025年1月15日")
                            .dynamicFont(.caption)
                            .foregroundColor(adaptiveSuccessColor)
                    }
                    
                    Spacer()
                }
                
                Divider()
                    .background(adaptiveBorderColor)
                
                HStack {
                    Text("¥8,999.00")
                        .dynamicFont(.title3, weight: .bold)
                        .foregroundColor(adaptiveAccentColor)
                    
                    Spacer()
                    
                    Button("查看详情") {
                        // 按钮操作
                    }
                    .dynamicFont(.subheadline, weight: .medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(adaptiveAccentColor)
                    .cornerRadius(8)
                }
            }
            .padding()
            .background(adaptiveCardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(adaptiveBorderColor, lineWidth: fontManager.isHighContrastEnabled ? 2 : 1)
            )
        }
    }
    
    private var settingsInterfaceExample: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("设置界面")
                .dynamicFont(.headline, weight: .semibold)
                .foregroundColor(adaptivePrimaryColor)
            
            VStack(spacing: 1) {
                ForEach(["通知设置", "隐私设置", "账户设置"], id: \.self) { setting in
                    HStack {
                        Image(systemName: "gear")
                            .foregroundColor(adaptiveAccentColor)
                            .font(.system(size: fontManager.getScaledFontSize(for: .title3)))
                            .frame(width: 30)
                        
                        Text(setting)
                            .dynamicFont(.body)
                            .foregroundColor(adaptivePrimaryColor)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(adaptiveSecondaryColor)
                            .font(.system(size: fontManager.getScaledFontSize(for: .caption)))
                    }
                    .padding()
                    .background(adaptiveCardBackground)
                }
            }
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(adaptiveBorderColor, lineWidth: fontManager.isHighContrastEnabled ? 2 : 1)
            )
        }
    }
    
    private var notificationExample: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("通知界面")
                .dynamicFont(.headline, weight: .semibold)
                .foregroundColor(adaptivePrimaryColor)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "bell.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: fontManager.getScaledFontSize(for: .title2)))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("保修提醒")
                            .dynamicFont(.subheadline, weight: .semibold)
                            .foregroundColor(adaptivePrimaryColor)
                        
                        Text("您的iPhone保修期将在30天后到期")
                            .dynamicFont(.body)
                            .foregroundColor(adaptiveSecondaryColor)
                            .lineSpacing(fontManager.lineSpacing(for: .body))
                    }
                    
                    Spacer()
                }
                
                Text("2小时前")
                    .dynamicFont(.caption)
                    .foregroundColor(adaptiveSecondaryColor)
                    .padding(.leading, 30)
            }
            .padding()
            .background(adaptiveCardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(adaptiveBorderColor, lineWidth: fontManager.isHighContrastEnabled ? 2 : 1)
            )
        }
    }
    
    // MARK: - 辅助组件
    
    private func headerSection(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .dynamicFont(.title2, weight: .bold)
                .foregroundColor(adaptivePrimaryColor)
            
            Text(subtitle)
                .dynamicFont(.subheadline)
                .foregroundColor(adaptiveSecondaryColor)
                .lineSpacing(fontManager.lineSpacing(for: .subheadline))
        }
    }
    
    private var systemInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("当前系统设置")
                .dynamicFont(.headline, weight: .semibold)
                .foregroundColor(adaptivePrimaryColor)
            
            VStack(spacing: 8) {
                infoRow("内容大小类别", fontManager.currentContentSizeCategory.description)
                infoRow("字体缩放因子", "\(String(format: "%.1f", fontManager.fontScaleFactor))x")
                infoRow("粗体文本", fontManager.isBoldTextEnabled ? "已启用" : "未启用")
                infoRow("高对比度", fontManager.isHighContrastEnabled ? "已启用" : "未启用")
                infoRow("减少动画", fontManager.isReduceMotionEnabled ? "已启用" : "未启用")
            }
        }
        .padding()
        .background(adaptiveCardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(adaptiveBorderColor, lineWidth: fontManager.isHighContrastEnabled ? 2 : 1)
        )
    }
    
    private func infoRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .dynamicFont(.body)
                .foregroundColor(adaptiveSecondaryColor)
            
            Spacer()
            
            Text(value)
                .dynamicFont(.body, weight: .medium)
                .foregroundColor(adaptivePrimaryColor)
        }
    }
    
    // MARK: - 颜色计算属性
    
    private var adaptivePrimaryColor: Color {
        fontManager.adaptiveColor(
            light: .primary,
            dark: .primary,
            highContrastLight: HighContrastColors.highContrastPrimary
        )
    }
    
    private var adaptiveSecondaryColor: Color {
        fontManager.adaptiveColor(
            light: .secondary,
            dark: .secondary,
            highContrastLight: HighContrastColors.highContrastSecondary
        )
    }
    
    private var adaptiveAccentColor: Color {
        fontManager.adaptiveColor(
            light: .blue,
            dark: .blue,
            highContrastLight: HighContrastColors.highContrastAccent
        )
    }
    
    private var adaptiveSuccessColor: Color {
        fontManager.adaptiveColor(
            light: .green,
            dark: .green,
            highContrastLight: HighContrastColors.highContrastSuccess
        )
    }
    
    private var adaptiveCardBackground: Color {
        if fontManager.isHighContrastEnabled {
            return Color(.systemBackground)
        } else {
            return Color(.secondarySystemBackground)
        }
    }
    
    private var adaptiveBorderColor: Color {
        if fontManager.isHighContrastEnabled {
            return Color(.separator)
        } else {
            return Color.clear
        }
    }
}

#Preview {
    NavigationView {
        DynamicFontDemoView()
    }
}