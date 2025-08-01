//
//  AccessibilitySettingsView.swift
//  ManualBox
//
//  Created by Assistant on 2024/12/19.
//  无障碍设置界面 - 展示动态字体和高对比度功能
//

import SwiftUI

struct AccessibilitySettingsView: View {
    @StateObject private var fontManager = DynamicFontManager.shared
    @State private var showingFontPreview = false
    @State private var selectedPreviewSize: FontSize = .body
    
    var body: some View {
        List {
            // 字体设置部分
            fontSettingsSection
            
            // 对比度设置部分
            contrastSettingsSection
            
            // 动画设置部分
            motionSettingsSection
            
            // 预览部分
            previewSection
        }
        .navigationTitle("无障碍设置")
        .sheet(isPresented: $showingFontPreview) {
            FontPreviewSheet(selectedSize: $selectedPreviewSize)
        }
    }
    
    // MARK: - 字体设置部分
    
    private var fontSettingsSection: some View {
        Section {
            // 当前字体大小显示
            HStack {
                Text("当前字体大小")
                    .dynamicFont(.body)
                Spacer()
                Text(fontManager.currentContentSizeCategory.description)
                    .dynamicFont(.body, weight: .medium)
                    .foregroundColor(.secondary)
            }
            
            // 字体缩放因子
            HStack {
                Text("缩放因子")
                    .dynamicFont(.body)
                Spacer()
                Text("\(String(format: "%.1f", fontManager.fontScaleFactor))x")
                    .dynamicFont(.body, weight: .medium)
                    .foregroundColor(.secondary)
            }
            
            // 粗体文本状态
            HStack {
                Text("粗体文本")
                    .dynamicFont(.body)
                Spacer()
                if fontManager.isBoldTextEnabled {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else {
                    Image(systemName: "circle")
                        .foregroundColor(.secondary)
                }
            }
            
            // 字体预览按钮
            Button(action: {
                showingFontPreview = true
            }) {
                HStack {
                    Text("字体预览")
                        .dynamicFont(.body)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .foregroundColor(.primary)
            
        } header: {
            Text("字体设置")
                .dynamicFont(.headline, weight: .semibold)
        } footer: {
            Text("字体大小会根据系统设置自动调整。您可以在系统设置 > 显示与亮度 > 文字大小中调整。")
                .dynamicFont(.footnote)
        }
    }
    
    // MARK: - 对比度设置部分
    
    private var contrastSettingsSection: some View {
        Section {
            // 高对比度状态
            HStack {
                Text("高对比度")
                    .dynamicFont(.body)
                Spacer()
                if fontManager.isHighContrastEnabled {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("已启用")
                            .dynamicFont(.body, weight: .medium)
                            .foregroundColor(.green)
                    }
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "circle")
                            .foregroundColor(.secondary)
                        Text("未启用")
                            .dynamicFont(.body)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // 颜色对比度示例
            VStack(alignment: .leading, spacing: 8) {
                Text("颜色对比度示例")
                    .dynamicFont(.body, weight: .medium)
                
                HStack(spacing: 16) {
                    // 普通对比度
                    VStack(spacing: 4) {
                        Text("普通")
                            .dynamicFont(.caption, weight: .medium)
                            .foregroundColor(.secondary)
                        
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.blue.opacity(0.7))
                            .frame(width: 60, height: 40)
                            .overlay(
                                Text("文本")
                                    .dynamicFont(.caption)
                                    .foregroundColor(.white)
                            )
                    }
                    
                    // 高对比度
                    VStack(spacing: 4) {
                        Text("高对比度")
                            .dynamicFont(.caption, weight: .medium)
                            .foregroundColor(.secondary)
                        
                        RoundedRectangle(cornerRadius: 8)
                            .fill(fontManager.isHighContrastEnabled ? Color.blue : Color.blue.opacity(0.9))
                            .frame(width: 60, height: 40)
                            .overlay(
                                Text("文本")
                                    .dynamicFont(.caption, weight: fontManager.isBoldTextEnabled ? .bold : .regular)
                                    .foregroundColor(.white)
                            )
                    }
                }
            }
            
        } header: {
            Text("对比度设置")
                .dynamicFont(.headline, weight: .semibold)
        } footer: {
            Text("高对比度模式可以提高文本和界面元素的可读性。您可以在系统设置 > 辅助功能 > 显示与文字大小中启用。")
                .dynamicFont(.footnote)
        }
    }
    
    // MARK: - 动画设置部分
    
    private var motionSettingsSection: some View {
        Section {
            // 减少动画状态
            HStack {
                Text("减少动画")
                    .dynamicFont(.body)
                Spacer()
                if fontManager.isReduceMotionEnabled {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("已启用")
                            .dynamicFont(.body, weight: .medium)
                            .foregroundColor(.green)
                    }
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "circle")
                            .foregroundColor(.secondary)
                        Text("未启用")
                            .dynamicFont(.body)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // 动画示例
            HStack {
                Text("动画示例")
                    .dynamicFont(.body)
                
                Spacer()
                
                if fontManager.isReduceMotionEnabled {
                    // 静态图标
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)
                        .font(.title2)
                } else {
                    // 动画图标
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)
                        .font(.title2)
                        .scaleEffect(1.0)
                        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: UUID())
                }
            }
            
        } header: {
            Text("动画设置")
                .dynamicFont(.headline, weight: .semibold)
        } footer: {
            Text("减少动画可以帮助对动画敏感的用户更好地使用应用。您可以在系统设置 > 辅助功能 > 动作中启用。")
                .dynamicFont(.footnote)
        }
    }
    
    // MARK: - 预览部分
    
    private var previewSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Text("文本预览")
                    .dynamicFont(.headline, weight: .semibold)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("大标题示例")
                        .dynamicFont(.largeTitle, weight: .bold)
                        .adaptiveColor(
                            light: .primary,
                            dark: .primary,
                            highContrastLight: HighContrastColors.highContrastPrimary
                        )
                    
                    Text("标题示例")
                        .dynamicFont(.title, weight: .semibold)
                        .adaptiveColor(
                            light: .primary,
                            dark: .primary,
                            highContrastLight: HighContrastColors.highContrastPrimary
                        )
                    
                    Text("正文示例 - 这是一段正文文本，用于展示在不同字体大小设置下的显示效果。")
                        .dynamicFont(.body)
                        .adaptiveColor(
                            light: .primary,
                            dark: .primary,
                            highContrastLight: HighContrastColors.highContrastPrimary
                        )
                    
                    Text("小字体示例 - 这是较小的文本，通常用于注释或辅助信息。")
                        .dynamicFont(.footnote)
                        .adaptiveColor(
                            light: .secondary,
                            dark: .secondary,
                            highContrastLight: HighContrastColors.highContrastSecondary
                        )
                }
            }
            .padding(.vertical, 8)
            
        } header: {
            Text("预览")
                .dynamicFont(.headline, weight: .semibold)
        }
    }
}

// MARK: - 字体预览弹窗
struct FontPreviewSheet: View {
    @Binding var selectedSize: FontSize
    @Environment(\.dismiss) private var dismiss
    @StateObject private var fontManager = DynamicFontManager.shared
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 字体大小选择器
                    fontSizeSelector
                    
                    // 预览内容
                    previewContent
                    
                    // 系统信息
                    systemInfoSection
                }
                .padding()
            }
            .navigationTitle("字体预览")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var fontSizeSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("选择字体大小")
                .dynamicFont(.headline, weight: .semibold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                ForEach(FontSize.allCases, id: \.self) { size in
                    Button(action: {
                        selectedSize = size
                    }) {
                        VStack(spacing: 4) {
                            Text(size.description)
                                .font(fontManager.font(for: size))
                                .foregroundColor(selectedSize == size ? .white : .primary)
                            
                            Text("\(Int(fontManager.getScaledFontSize(for: size)))pt")
                                .font(.caption2)
                                .foregroundColor(selectedSize == size ? .white.opacity(0.8) : .secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedSize == size ? Color.blue : Color(.systemGray6))
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
    
    private var previewContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("预览内容")
                .dynamicFont(.headline, weight: .semibold)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("选中字体大小预览")
                    .font(fontManager.font(for: selectedSize, weight: .medium))
                    .foregroundColor(.primary)
                
                Text("这是使用 \(selectedSize.description) 字体大小的示例文本。您可以看到在当前系统设置下，这个字体大小的实际显示效果。")
                    .font(fontManager.font(for: selectedSize))
                    .foregroundColor(.primary)
                    .lineSpacing(fontManager.lineSpacing(for: selectedSize))
                
                if fontManager.isBoldTextEnabled {
                    Text("粗体文本已启用，所有文本都会显示得更粗一些。")
                        .font(fontManager.font(for: selectedSize))
                        .foregroundColor(.secondary)
                        .lineSpacing(fontManager.lineSpacing(for: selectedSize))
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    private var systemInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("系统信息")
                .dynamicFont(.headline, weight: .semibold)
            
            VStack(spacing: 8) {
                InfoRow(title: "内容大小类别", value: fontManager.currentContentSizeCategory.description)
                InfoRow(title: "字体缩放因子", value: "\(String(format: "%.1f", fontManager.fontScaleFactor))x")
                InfoRow(title: "粗体文本", value: fontManager.isBoldTextEnabled ? "已启用" : "未启用")
                InfoRow(title: "高对比度", value: fontManager.isHighContrastEnabled ? "已启用" : "未启用")
                InfoRow(title: "减少动画", value: fontManager.isReduceMotionEnabled ? "已启用" : "未启用")
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
}

// MARK: - 辅助视图组件

// InfoRow moved to shared components to avoid conflicts

// MARK: - ContentSizeCategory扩展
extension ContentSizeCategory {
    var description: String {
        switch self {
        case .extraSmall: return "特小"
        case .small: return "小"
        case .medium: return "中"
        case .large: return "大"
        case .extraLarge: return "特大"
        case .extraExtraLarge: return "超大"
        case .extraExtraExtraLarge: return "特超大"
        case .accessibilityMedium: return "辅助功能中"
        case .accessibilityLarge: return "辅助功能大"
        case .accessibilityExtraLarge: return "辅助功能特大"
        case .accessibilityExtraExtraLarge: return "辅助功能超大"
        case .accessibilityExtraExtraExtraLarge: return "辅助功能特超大"
        @unknown default: return "未知"
        }
    }
}

#Preview {
    NavigationView {
        AccessibilitySettingsView()
    }
}