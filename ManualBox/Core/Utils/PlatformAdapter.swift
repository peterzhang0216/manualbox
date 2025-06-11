import SwiftUI
import Foundation

// MARK: - 设备性能级别枚举
enum DevicePerformanceLevel {
    case low
    case medium
    case high
    
    var maxConcurrentOperations: Int {
        switch self {
        case .low: return 2
        case .medium: return 4
        case .high: return 8
        }
    }
    
    var imageCompressionQuality: CGFloat {
        switch self {
        case .low: return 0.6
        case .medium: return 0.8
        case .high: return 0.9
        }
    }
    
    var cacheSize: Int {
        switch self {
        case .low: return 50 * 1024 * 1024  // 50MB
        case .medium: return 100 * 1024 * 1024  // 100MB
        case .high: return 200 * 1024 * 1024  // 200MB
        }
    }
}

// MARK: - 平台适配管理器
struct PlatformAdapter {
    
    // MARK: - 设备性能
    static var devicePerformanceLevel: DevicePerformanceLevel {
        #if os(macOS)
        // macOS 设备根据处理器和内存综合判断
        let physicalMemory = ProcessInfo.processInfo.physicalMemory
        let memoryGB = Double(physicalMemory) / (1024 * 1024 * 1024)
        let processorCount = ProcessInfo.processInfo.processorCount
        
        if memoryGB >= 16 && processorCount >= 8 {
            return .high
        } else if memoryGB >= 8 && processorCount >= 4 {
            return .medium
        } else {
            return .low
        }
        #else
        // iOS 设备根据内存大小和处理器核心数判断性能级别
        let physicalMemory = ProcessInfo.processInfo.physicalMemory
        let memoryGB = Double(physicalMemory) / (1024 * 1024 * 1024)
        let processorCount = ProcessInfo.processInfo.processorCount
        
        if memoryGB >= 6 && processorCount >= 6 {
            return .high
        } else if memoryGB >= 3 && processorCount >= 4 {
            return .medium
        } else {
            return .low
        }
        #endif
    }
    
    // MARK: - 内存管理策略
    static var memoryPressureThreshold: Double {
        switch devicePerformanceLevel {
        case .low: return 0.7
        case .medium: return 0.8
        case .high: return 0.9
        }
    }
    
    static var shouldUseMemoryCache: Bool {
        let availableMemory = ProcessInfo.processInfo.physicalMemory
        let memoryGB = Double(availableMemory) / (1024 * 1024 * 1024)
        return memoryGB >= 2.0
    }
    
    static var maxImageCacheCount: Int {
        switch devicePerformanceLevel {
        case .low: return 50
        case .medium: return 100
        case .high: return 200
        }
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
        return Color(.windowBackgroundColor)
        #else
        return Color(.systemBackground)
        #endif
    }
    
    static var secondaryBackgroundColor: Color {
        #if os(macOS)
        return Color(.controlBackgroundColor)
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
    
    static var supportsKeyboardShortcuts: Bool {
        #if os(macOS)
        return true
        #else
        return false
        #endif
    }
    
    static var supportsMultipleWindows: Bool {
        #if os(macOS)
        return true
        #else
        return true // iOS 13+ 支持
        #endif
    }
    
    // MARK: - 平台特定动画
    static var defaultAnimation: Animation {
        #if os(macOS)
        return .easeInOut(duration: 0.25)
        #else
        return .spring(response: 0.5, dampingFraction: 0.8)
        #endif
    }
    
    static var listRowAnimation: Animation {
        #if os(macOS)
        return .easeOut(duration: 0.2)
        #else
        return .spring(response: 0.4, dampingFraction: 0.9)
        #endif
    }
    
    // MARK: - 平台特定间距
    static var sectionSpacing: CGFloat {
        #if os(macOS)
        return 20
        #else
        return 16
        #endif
    }
    
    static var groupSpacing: CGFloat {
        #if os(macOS)
        return 12
        #else
        return 8
        #endif
    }
    
    // MARK: - 平台特定字体大小
    static var titleFontSize: CGFloat {
        #if os(macOS)
        return 24
        #else
        return 28
        #endif
    }
    
    static var bodyFontSize: CGFloat {
        #if os(macOS)
        return 14
        #else
        return 16
        #endif
    }
    
    static var captionFontSize: CGFloat {
        #if os(macOS)
        return 11
        #else
        return 12
        #endif
    }
    
    // MARK: - 布局列数
    static var preferredColumnCount: Int {
        #if os(macOS)
        return 3
        #else
        return 2
        #endif
    }
    
    // MARK: - 文件系统访问适配
    static var supportsFileSystemAccess: Bool {
        #if os(macOS)
        return true
        #else
        return false // iOS 使用沙盒机制
        #endif
    }
    
    static var documentsDirectory: URL {
        #if os(macOS)
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        #else
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        #endif
    }
    
    static var supportedFileTypes: [String] {
        #if os(macOS)
        return ["pdf", "jpg", "jpeg", "png", "gif", "tiff", "bmp", "txt", "rtf", "doc", "docx"]
        #else
        return ["pdf", "jpg", "jpeg", "png", "gif", "txt"]
        #endif
    }
    
    // MARK: - 窗口管理适配
    static var supportsWindowManagement: Bool {
        #if os(macOS)
        return true
        #else
        return false
        #endif
    }
    
    static var defaultWindowSize: CGSize {
        #if os(macOS)
        return CGSize(width: 1200, height: 800)
        #else
        return CGSize.zero // iOS 不适用
        #endif
    }
    
    static var minimumWindowSize: CGSize {
        #if os(macOS)
        return CGSize(width: 800, height: 600)
        #else
        return CGSize.zero // iOS 不适用
        #endif
    }
    
    // MARK: - 触摸/鼠标交互差异处理
    static var primaryInteractionMode: InteractionMode {
        #if os(macOS)
        return .mouse
        #else
        return .touch
        #endif
    }
    
    static var supportsRightClick: Bool {
        #if os(macOS)
        return true
        #else
        return false
        #endif
    }
    
    static var supportsLongPress: Bool {
        #if os(macOS)
        return false
        #else
        return true
        #endif
    }
    
    // MARK: - 性能优化配置
    static var shouldUseHardwareAcceleration: Bool {
        return devicePerformanceLevel != .low
    }
    
    static var animationDuration: Double {
        switch devicePerformanceLevel {
        case .low: return 0.15
        case .medium: return 0.25
        case .high: return 0.3
        }
    }
    
    static var shouldPreloadImages: Bool {
        return devicePerformanceLevel == .high && shouldUseMemoryCache
    }
}

// MARK: - 交互模式枚举
enum InteractionMode {
    case touch
    case mouse
    case hybrid
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
    
    @ViewBuilder
    func platformListRow() -> some View {
        #if os(macOS)
        self
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.clear)
            )
            .contentShape(Rectangle())
        #else
        self
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        #endif
    }
    
    @ViewBuilder
    func platformHover() -> some View {
        #if os(macOS)
        self
            .onHover { isHovered in
                withAnimation(PlatformAdapter.defaultAnimation) {
                    // 悬停效果可以在这里实现
                }
            }
        #else
        self
        #endif
    }
    
    @ViewBuilder
    func platformContextMenu<MenuItems: View>(@ViewBuilder menuItems: () -> MenuItems) -> some View {
        #if os(macOS)
        self.contextMenu {
            menuItems()
        }
        #else
        self.contextMenu {
            menuItems()
        }
        #endif
    }
    
    @ViewBuilder
    func platformAnimation() -> some View {
        self.animation(PlatformAdapter.defaultAnimation, value: UUID())
    }
    
    @ViewBuilder
    func platformSectionSpacing() -> some View {
        self.padding(.vertical, PlatformAdapter.sectionSpacing / 2)
    }
    
    @ViewBuilder
    func platformGroupSpacing() -> some View {
        self.padding(.vertical, PlatformAdapter.groupSpacing / 2)
    }
    
    @ViewBuilder
    func platformFont(_ style: Font.TextStyle) -> some View {
        self.font(PlatformAdapter.dynamicFont(style: style))
    }
    
    @ViewBuilder
    func platformTouchTarget() -> some View {
        self.frame(minHeight: PlatformAdapter.minimumTouchTarget)
    }
    
    @ViewBuilder
    func platformInteraction() -> some View {
        #if os(macOS)
        self
            .onTapGesture {
                // macOS 点击处理
            }
            .onHover { isHovering in
                // macOS 悬停处理
            }
        #else
        self
            .onTapGesture {
                // iOS 触摸处理
            }
            .onLongPressGesture {
                // iOS 长按处理
            }
        #endif
    }
    
    @ViewBuilder
    func platformKeyboardShortcut(_ key: KeyEquivalent, modifiers: EventModifiers = []) -> some View {
        #if os(macOS)
        self.keyboardShortcut(key, modifiers: modifiers)
        #else
        self // iOS 不支持键盘快捷键
        #endif
    }
    
    @ViewBuilder
    func platformDragAndDrop<T: Transferable>(of type: T.Type, action: @escaping ([T]) -> Void) -> some View {
        #if os(macOS)
        self
            .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                // macOS 拖拽处理
                return true
            }
        #else
        self
            .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                // iOS 拖拽处理
                return true
            }
        #endif
    }
    
    @ViewBuilder
    func platformAccessibility(label: String, hint: String? = nil) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityAddTraits(.isButton)
    }
    
    @ViewBuilder
    func platformPerformanceOptimized() -> some View {
        if PlatformAdapter.shouldUseHardwareAcceleration {
            self
                .drawingGroup() // 硬件加速
        } else {
            self
        }
    }
    
    @ViewBuilder
    func platformMemoryOptimized() -> some View {
        if PlatformAdapter.shouldUseMemoryCache {
            self
        } else {
            self
                .clipped() // 减少内存使用
        }
    }
}