//
//  DynamicFontManager.swift
//  ManualBox
//
//  Created by Assistant on 2024/12/19.
//  动态字体管理器 - 支持字体大小自适应和高对比度模式
//

import SwiftUI
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

// MARK: - 动态字体管理器
@MainActor
class DynamicFontManager: ObservableObject {
    
    // MARK: - Singleton
    static let shared = DynamicFontManager()
    
    // MARK: - Published Properties
    @Published private(set) var currentContentSizeCategory: ContentSizeCategory = .medium
    @Published private(set) var isHighContrastEnabled = false
    @Published private(set) var isBoldTextEnabled = false
    @Published private(set) var isReduceMotionEnabled = false
    @Published private(set) var fontScaleFactor: CGFloat = 1.0
    
    // MARK: - Font Configurations
    private let baseFontSizes: [FontSize: CGFloat] = [
        .caption2: 11,
        .caption: 12,
        .footnote: 13,
        .subheadline: 15,
        .callout: 16,
        .body: 17,
        .headline: 17,
        .title3: 20,
        .title2: 22,
        .title: 28,
        .largeTitle: 34
    ]
    
    private let accessibilityFontSizes: [FontSize: CGFloat] = [
        .caption2: 18,
        .caption: 19,
        .footnote: 20,
        .subheadline: 22,
        .callout: 23,
        .body: 24,
        .headline: 24,
        .title3: 27,
        .title2: 29,
        .title: 35,
        .largeTitle: 41
    ]
    
    // MARK: - Initialization
    private init() {
        setupAccessibilityObservers()
        updateCurrentSettings()
    }
    
    // MARK: - Public Methods
    
    /// 获取指定字体大小的动态字体
    func font(for size: FontSize, weight: Font.Weight = .regular) -> Font {
        let scaledSize = getScaledFontSize(for: size)
        
        if isBoldTextEnabled && weight == .regular {
            return .system(size: scaledSize, weight: .medium)
        } else if isBoldTextEnabled {
            return .system(size: scaledSize, weight: .bold)
        } else {
            return .system(size: scaledSize, weight: weight)
        }
    }
    
    /// 获取NSFont版本的动态字体
    #if canImport(AppKit)
    func nsFont(for size: FontSize, weight: NSFont.Weight = .regular) -> NSFont {
        let scaledSize = getScaledFontSize(for: size)
        
        let adjustedWeight: NSFont.Weight
        if isBoldTextEnabled && weight == .regular {
            adjustedWeight = .medium
        } else if isBoldTextEnabled && weight != .bold {
            adjustedWeight = .bold
        } else {
            adjustedWeight = weight
        }
        
        return NSFont.systemFont(ofSize: scaledSize, weight: adjustedWeight)
    }
    #endif
    
    /// 获取缩放后的字体大小
    func getScaledFontSize(for size: FontSize) -> CGFloat {
        let baseSize: CGFloat
        
        // 根据内容大小类别选择基础字体大小
        if currentContentSizeCategory.isAccessibilityCategory {
            baseSize = accessibilityFontSizes[size] ?? baseFontSizes[size] ?? 17
        } else {
            baseSize = baseFontSizes[size] ?? 17
        }
        
        // 应用缩放因子
        return baseSize * fontScaleFactor
    }
    
    /// 获取适合当前设置的颜色
    func adaptiveColor(
        light: Color,
        dark: Color,
        highContrastLight: Color? = nil,
        highContrastDark: Color? = nil
    ) -> Color {
        if isHighContrastEnabled {
            return highContrastLight ?? light
        } else {
            return light
        }
    }
    
    /// 获取适合当前设置的UIColor
    #if canImport(AppKit)
    func adaptiveUIColor(
        light: NSColor,
        dark: NSColor,
        highContrastLight: NSColor? = nil,
        highContrastDark: NSColor? = nil
    ) -> NSColor {
        if isHighContrastEnabled {
            return highContrastLight ?? light
        } else {
            return light
        }
    }
    #endif
    
    /// 检查是否需要增强对比度
    func shouldUseHighContrast() -> Bool {
        return isHighContrastEnabled
    }
    
    /// 检查是否应该减少动画
    func shouldReduceMotion() -> Bool {
        return isReduceMotionEnabled
    }
    
    /// 获取推荐的行间距
    func lineSpacing(for size: FontSize) -> CGFloat {
        let fontSize = getScaledFontSize(for: size)
        return fontSize * 0.2 // 20% of font size
    }
    
    /// 获取推荐的段落间距
    func paragraphSpacing(for size: FontSize) -> CGFloat {
        let fontSize = getScaledFontSize(for: size)
        return fontSize * 0.5 // 50% of font size
    }
    
    // MARK: - Private Methods
    
    private func setupAccessibilityObservers() {
        #if canImport(AppKit)
        // 监听系统外观变化
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateCurrentSettings()
        }
        
        // 监听辅助功能设置变化
        NotificationCenter.default.addObserver(
            forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateCurrentSettings()
        }
        #endif
    }
    
    private func updateCurrentSettings() {
        // 更新内容大小类别 (macOS 使用默认值)
        currentContentSizeCategory = .medium
        
        #if canImport(AppKit)
        // 更新辅助功能设置 (macOS 简化版本)
        isHighContrastEnabled = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
        isBoldTextEnabled = false // macOS 没有直接的粗体文本设置
        isReduceMotionEnabled = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        #else
        // iOS/其他平台的默认设置
        isHighContrastEnabled = false
        isBoldTextEnabled = false
        isReduceMotionEnabled = false
        #endif
        
        // 计算字体缩放因子
        fontScaleFactor = calculateFontScaleFactor(for: "medium" as NSString)
        
        print("🖥️ 动态字体设置更新:")
        print("   内容大小类别: \(currentContentSizeCategory)")
        print("   高对比度: \(isHighContrastEnabled)")
        print("   粗体文本: \(isBoldTextEnabled)")
        print("   减少动画: \(isReduceMotionEnabled)")
        print("   字体缩放因子: \(fontScaleFactor)")
    }
    
    private func calculateFontScaleFactor(for category: NSString) -> CGFloat {
        let categoryString = category as String
        switch categoryString {
        case "extraSmall":
            return 0.8
        case "small":
            return 0.9
        case "medium":
            return 1.0
        case "large":
            return 1.1
        case "extraLarge":
            return 1.2
        case "extraExtraLarge":
            return 1.3
        case "extraExtraExtraLarge":
            return 1.4
        case "accessibilityMedium":
            return 1.6
        case "accessibilityLarge":
            return 1.8
        case "accessibilityExtraLarge":
            return 2.0
        case "accessibilityExtraExtraLarge":
            return 2.2
        case "accessibilityExtraExtraExtraLarge":
            return 2.4
        default:
            return 1.0
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - 字体大小枚举
enum FontSize: CaseIterable {
    case caption2
    case caption
    case footnote
    case subheadline
    case callout
    case body
    case headline
    case title3
    case title2
    case title
    case largeTitle
    
    var description: String {
        switch self {
        case .caption2: return "Caption 2"
        case .caption: return "Caption"
        case .footnote: return "Footnote"
        case .subheadline: return "Subheadline"
        case .callout: return "Callout"
        case .body: return "Body"
        case .headline: return "Headline"
        case .title3: return "Title 3"
        case .title2: return "Title 2"
        case .title: return "Title"
        case .largeTitle: return "Large Title"
        }
    }
}

// MARK: - ContentSizeCategory扩展
extension ContentSizeCategory {
    init(_ category: String) {
        switch uiCategory {
        case .extraSmall:
            self = .extraSmall
        case .small:
            self = .small
        case .medium:
            self = .medium
        case .large:
            self = .large
        case .extraLarge:
            self = .extraLarge
        case .extraExtraLarge:
            self = .extraExtraLarge
        case .extraExtraExtraLarge:
            self = .extraExtraExtraLarge
        case .accessibilityMedium:
            self = .accessibilityMedium
        case .accessibilityLarge:
            self = .accessibilityLarge
        case .accessibilityExtraLarge:
            self = .accessibilityExtraLarge
        case .accessibilityExtraExtraLarge:
            self = .accessibilityExtraExtraLarge
        case .accessibilityExtraExtraExtraLarge:
            self = .accessibilityExtraExtraExtraLarge
        default:
            self = .large
        }
    }
}

// MARK: - 动态字体视图修饰符
struct DynamicFontModifier: ViewModifier {
    let size: FontSize
    let weight: Font.Weight
    @StateObject private var fontManager = DynamicFontManager.shared
    
    func body(content: Content) -> some View {
        content
            .font(fontManager.font(for: size, weight: weight))
            .lineSpacing(fontManager.lineSpacing(for: size))
    }
}

// MARK: - View扩展
extension View {
    /// 应用动态字体
    func dynamicFont(_ size: FontSize, weight: Font.Weight = .regular) -> some View {
        modifier(DynamicFontModifier(size: size, weight: weight))
    }
    
    /// 应用高对比度颜色
    func adaptiveColor(
        light: Color,
        dark: Color,
        highContrastLight: Color? = nil,
        highContrastDark: Color? = nil
    ) -> some View {
        foregroundColor(
            DynamicFontManager.shared.adaptiveColor(
                light: light,
                dark: dark,
                highContrastLight: highContrastLight,
                highContrastDark: highContrastDark
            )
        )
    }
}

// MARK: - 高对比度颜色主题
struct HighContrastColors {
    static let primary = Color.primary
    static let secondary = Color.secondary
    static let accent = Color.blue
    static let success = Color.green
    static let warning = Color.orange
    static let error = Color.red
    
    // 高对比度版本
    static let highContrastPrimary = Color.black
    static let highContrastSecondary = Color.gray
    static let highContrastAccent = Color.blue
    static let highContrastSuccess = Color.green
    static let highContrastWarning = Color.orange
    static let highContrastError = Color.red
    
    static func adaptiveColor(
        normal: Color,
        highContrast: Color,
        isHighContrast: Bool = false
    ) -> Color {
        return isHighContrast ? highContrast : normal
    }
}