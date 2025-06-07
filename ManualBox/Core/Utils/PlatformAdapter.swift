import SwiftUI
import Foundation

// MARK: - 设备性能级别枚举
enum DevicePerformanceLevel {
    case low
    case medium
    case high
}

// MARK: - 平台适配管理器
struct PlatformAdapter {
    
    // MARK: - 设备性能
    static var devicePerformanceLevel: DevicePerformanceLevel {
        #if os(macOS)
        // macOS 设备通常性能较好
        return .high
        #else
        // iOS 设备根据内存大小判断性能级别
        let physicalMemory = ProcessInfo.processInfo.physicalMemory
        let memoryGB = Double(physicalMemory) / (1024 * 1024 * 1024)
        
        if memoryGB >= 6 {
            return .high
        } else if memoryGB >= 3 {
            return .medium
        } else {
            return .low
        }
        #endif
    }
    
    // MARK: - 布局相关
    static var isCompact: Bool {
        #if os(macOS)
        return false
        #else
        return true
        #endif
    }
    
    static var navigationStyle: NavigationStyle {
        #if os(macOS)
        return .sidebar
        #else
        return .stack
        #endif
    }
    
    static var preferredListStyle: some ListStyle {
        #if os(macOS)
        return SidebarListStyle()
        #else
        return InsetGroupedListStyle()
        #endif
    }
    
    // MARK: - 间距和尺寸
    static var defaultPadding: CGFloat {
        #if os(macOS)
        return 16
        #else
        return 12
        #endif
    }
    
    static var cardCornerRadius: CGFloat {
        #if os(macOS)
        return 8
        #else
        return 12
        #endif
    }
    
    static var minimumTouchTarget: CGFloat {
        #if os(macOS)
        return 24
        #else
        return 44
        #endif
    }
    
    // MARK: - 颜色系统
    static var backgroundColor: Color {
        #if os(macOS)
        return Color(NSColor.windowBackgroundColor)
        #else
        return Color(.systemBackground)
        #endif
    }
    
    static var secondaryBackgroundColor: Color {
        #if os(macOS)
        return Color(NSColor.controlBackgroundColor)
        #else
        return Color(.secondarySystemBackground)
        #endif
    }
    
    // MARK: - 字体系统
    static func dynamicFont(style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        #if os(macOS)
        return .system(style, design: .default, weight: weight)
        #else
        return .system(style, design: .default, weight: weight)
        #endif
    }
    
    // MARK: - 交互模式
    static var supportsHover: Bool {
        #if os(macOS)
        return true
        #else
        return false
        #endif
    }
    
    static var supportsDragDrop: Bool {
        #if os(macOS)
        return true
        #else
        return true // iOS 11+ 支持
        #endif
    }
}

// MARK: - 导航样式枚举
enum NavigationStyle {
    case sidebar
    case stack
    case tabs
}

// MARK: - SwiftUI 视图扩展
extension View {
    @ViewBuilder
    func platformOptimized() -> some View {
        #if os(macOS)
        self
            .frame(minWidth: 800, minHeight: 600)
            .navigationSplitViewStyle(.balanced)
        #else
        self
            .navigationBarTitleDisplayMode(.large)
        #endif
    }
    
    @ViewBuilder
    func platformBackground() -> some View {
        self.background(PlatformAdapter.backgroundColor)
    }
    
    @ViewBuilder
    func platformCard() -> some View {
        self
            .padding(PlatformAdapter.defaultPadding)
            .background(
                RoundedRectangle(cornerRadius: PlatformAdapter.cardCornerRadius)
                    .fill(PlatformAdapter.secondaryBackgroundColor)
            )
    }
}