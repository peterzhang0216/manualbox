//
//  EnhancedProductListItem.swift
//  ManualBox
//
//  Created by Assistant on 2024/12/19.
//  增强的产品列表项 - 支持动态字体和高对比度
//

import SwiftUI
import CoreData

struct EnhancedProductListItem: View {
    let product: Product
    @StateObject private var fontManager = DynamicFontManager.shared
    
    var body: some View {
        HStack(spacing: 12) {
            // 产品图片
            productImage
            
            // 产品信息
            productInfo
            
            Spacer()
            
            // 保修信息
            warrantyInfo
        }
        .padding(.vertical, fontManager.shouldReduceMotion() ? 8 : 6)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(adaptiveBackgroundColor)
                .opacity(0.5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(adaptiveBorderColor, lineWidth: fontManager.isHighContrastEnabled ? 2 : 1)
        )
        .animation(
            fontManager.shouldReduceMotion() ? .none : .easeInOut(duration: 0.2),
            value: fontManager.isHighContrastEnabled
        )
    }
    
    // MARK: - 产品图片
    
    private var productImage: some View {
        Group {
            if let imageData = product.imageData,
               let image = PlatformImage(data: imageData) {
                Image(platformImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: imageSize, height: imageSize)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(adaptiveBorderColor, lineWidth: fontManager.isHighContrastEnabled ? 2 : 0.5)
                    )
            } else {
                Image(systemName: "photo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: imageSize * 0.6, height: imageSize * 0.6)
                    .foregroundColor(adaptiveSecondaryColor)
                    .frame(width: imageSize, height: imageSize)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(adaptiveBackgroundColor)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(adaptiveBorderColor, lineWidth: fontManager.isHighContrastEnabled ? 2 : 1)
                    )
            }
        }
    }
    
    // MARK: - 产品信息
    
    private var productInfo: some View {
        VStack(alignment: .leading, spacing: fontManager.lineSpacing(for: .body) / 2) {
            // 产品名称
            Text(product.productName)
                .dynamicFont(.headline, weight: .semibold)
                .foregroundColor(adaptivePrimaryColor)
                .lineLimit(fontManager.currentContentSizeCategory.isAccessibilityCategory ? nil : 2)
            
            // 购买信息
            if let order = product.order {
                VStack(alignment: .leading, spacing: 2) {
                    if let orderDate = order.orderDate {
                        Label {
                            Text("购买于 \(orderDate.formatted(date: .abbreviated, time: .omitted))")
                                .dynamicFont(.subheadline)
                                .foregroundColor(adaptiveSecondaryColor)
                        } icon: {
                            Image(systemName: "calendar")
                                .foregroundColor(adaptiveSecondaryColor)
                                .font(.system(size: fontManager.getScaledFontSize(for: .caption)))
                        }
                    }
                    
                    if let price = order.totalPrice, price > 0 {
                        Label {
                            Text("¥\(String(format: "%.2f", price))")
                                .dynamicFont(.subheadline, weight: .medium)
                                .foregroundColor(adaptiveAccentColor)
                        } icon: {
                            Image(systemName: "yensign.circle")
                                .foregroundColor(adaptiveAccentColor)
                                .font(.system(size: fontManager.getScaledFontSize(for: .caption)))
                        }
                    }
                }
            }
            
            // 类别信息
            if let category = product.category {
                Label {
                    Text(category.categoryName)
                        .dynamicFont(.caption, weight: .medium)
                        .foregroundColor(adaptiveSecondaryColor)
                } icon: {
                    Image(systemName: "tag")
                        .foregroundColor(adaptiveSecondaryColor)
                        .font(.system(size: fontManager.getScaledFontSize(for: .caption2)))
                }
            }
        }
    }
    
    // MARK: - 保修信息
    
    private var warrantyInfo: some View {
        Group {
            if let order = product.order,
               let warrantyEndDate = order.warrantyEndDate {
                VStack(alignment: .trailing, spacing: 4) {
                    // 保修状态图标
                    Image(systemName: warrantyEndDate > Date() ? "checkmark.shield" : "exclamationmark.shield")
                        .foregroundColor(warrantyStatusColor(for: warrantyEndDate))
                        .font(.system(size: fontManager.getScaledFontSize(for: .title3)))
                    
                    // 保修状态文本
                    Text(warrantyEndDate > Date() ? "保修中" : "已过期")
                        .dynamicFont(.caption, weight: .semibold)
                        .foregroundColor(warrantyStatusColor(for: warrantyEndDate))
                    
                    // 保修到期日期
                    Text(warrantyEndDate.formatted(date: .abbreviated, time: .omitted))
                        .dynamicFont(.caption2)
                        .foregroundColor(adaptiveSecondaryColor)
                    
                    // 剩余天数（如果还在保修期内）
                    if warrantyEndDate > Date() {
                        let daysRemaining = Calendar.current.dateComponents([.day], from: Date(), to: warrantyEndDate).day ?? 0
                        Text("剩余\(daysRemaining)天")
                            .dynamicFont(.caption2, weight: .medium)
                            .foregroundColor(warrantyStatusColor(for: warrantyEndDate))
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(warrantyStatusColor(for: warrantyEndDate).opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(warrantyStatusColor(for: warrantyEndDate), lineWidth: fontManager.isHighContrastEnabled ? 2 : 1)
                )
            }
        }
    }
    
    // MARK: - 计算属性
    
    private var imageSize: CGFloat {
        // 根据字体大小调整图片尺寸
        let baseSize: CGFloat = 60
        return baseSize * fontManager.fontScaleFactor
    }
    
    private var adaptivePrimaryColor: Color {
        fontManager.adaptiveColor(
            light: .primary,
            dark: .primary,
            highContrastLight: HighContrastColors.highContrastPrimary,
            highContrastDark: HighContrastColors.highContrastPrimary
        )
    }
    
    private var adaptiveSecondaryColor: Color {
        fontManager.adaptiveColor(
            light: .secondary,
            dark: .secondary,
            highContrastLight: HighContrastColors.highContrastSecondary,
            highContrastDark: HighContrastColors.highContrastSecondary
        )
    }
    
    private var adaptiveAccentColor: Color {
        fontManager.adaptiveColor(
            light: .blue,
            dark: .blue,
            highContrastLight: HighContrastColors.highContrastAccent,
            highContrastDark: HighContrastColors.highContrastAccent
        )
    }
    
    private var adaptiveBackgroundColor: Color {
        if fontManager.isHighContrastEnabled {
            #if os(macOS)
            return Color(NSColor.controlBackgroundColor)
            #else
            return Color(.systemBackground)
            #endif
        } else {
            #if os(macOS)
            return Color(NSColor.controlBackgroundColor)
            #else
            return Color(.secondarySystemBackground)
            #endif
        }
    }
    
    private var adaptiveBorderColor: Color {
        if fontManager.isHighContrastEnabled {
            #if os(macOS)
            return Color(NSColor.separatorColor)
            #else
            return Color(.separator)
            #endif
        } else {
            return Color.clear
        }
    }
    
    private func warrantyStatusColor(for date: Date) -> Color {
        let daysRemaining = Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0
        
        if daysRemaining < 0 {
            // 已过期
            return fontManager.adaptiveColor(
                light: .red,
                dark: .red,
                highContrastLight: HighContrastColors.highContrastError,
                highContrastDark: HighContrastColors.highContrastError
            )
        } else if daysRemaining < 30 {
            // 即将过期
            return fontManager.adaptiveColor(
                light: .orange,
                dark: .orange,
                highContrastLight: HighContrastColors.highContrastWarning,
                highContrastDark: HighContrastColors.highContrastWarning
            )
        } else {
            // 正常保修期
            return fontManager.adaptiveColor(
                light: .green,
                dark: .green,
                highContrastLight: HighContrastColors.highContrastSuccess,
                highContrastDark: HighContrastColors.highContrastSuccess
            )
        }
    }
}

// MARK: - 预览
#Preview {
    List {
        // 这里需要创建示例数据来预览
        // EnhancedProductListItem(product: sampleProduct)
    }
    .listStyle(PlainListStyle())
}