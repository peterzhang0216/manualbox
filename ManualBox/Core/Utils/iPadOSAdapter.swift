import SwiftUI
#if os(iOS)
import UIKit
#endif

// MARK: - iPadOS特定适配器
@available(iOS 13.0, *)
struct iPadOSAdapter {
    
    // MARK: - 设备检测
    static var isIPad: Bool {
        #if os(iOS)
        return UIDevice.current.userInterfaceIdiom == .pad
        #else
        return false
        #endif
    }
    
    static var hasExternalKeyboard: Bool {
        #if os(iOS)
        if #available(iOS 14.0, *) {
            return GCKeyboard.coalesced != nil
        }
        return false
        #else
        return false
        #endif
    }
    
    static var supportsApplePencil: Bool {
        #if os(iOS)
        return isIPad
        #else
        return false
        #endif
    }
    
    static var supportsMultitasking: Bool {
        #if os(iOS)
        return isIPad && UIDevice.current.systemVersion.compare("13.0", options: .numeric) != .orderedAscending
        #else
        return false
        #endif
    }
    
    // MARK: - 布局适配
    static var preferredSidebarWidth: CGFloat {
        #if os(iOS)
        if isIPad {
            return 320
        }
        return 280
        #else
        return 280
        #endif
    }
    
    static var preferredContentWidth: CGFloat {
        #if os(iOS)
        if isIPad {
            return 400
        }
        return 350
        #else
        return 350
        #endif
    }
    
    static var preferredDetailWidth: CGFloat {
        #if os(iOS)
        if isIPad {
            return 500
        }
        return 400
        #else
        return 400
        #endif
    }
    
    // MARK: - 交互模式
    static var supportsDragAndDrop: Bool {
        #if os(iOS)
        return isIPad
        #else
        return false
        #endif
    }
    
    static var supportsHoverEffects: Bool {
        #if os(iOS)
        if #available(iOS 13.4, *) {
            return isIPad
        }
        return false
        #else
        return false
        #endif
    }
    
    static var supportsPointerInteraction: Bool {
        #if os(iOS)
        if #available(iOS 13.4, *) {
            return isIPad
        }
        return false
        #else
        return false
        #endif
    }
    
    // MARK: - 键盘快捷键支持
    static var keyboardShortcuts: [KeyboardShortcut] {
        guard isIPad else { return [] }
        
        return [
            KeyboardShortcut(.init("n"), modifiers: [.command], action: "新建产品"),
            KeyboardShortcut(.init("f"), modifiers: [.command], action: "搜索"),
            KeyboardShortcut(.init("r"), modifiers: [.command], action: "刷新"),
            KeyboardShortcut(.init("1"), modifiers: [.command], action: "产品列表"),
            KeyboardShortcut(.init("2"), modifiers: [.command], action: "分类管理"),
            KeyboardShortcut(.init("3"), modifiers: [.command], action: "标签管理"),
            KeyboardShortcut(.init("4"), modifiers: [.command], action: "维修记录"),
            KeyboardShortcut(.init(","), modifiers: [.command], action: "设置"),
            KeyboardShortcut(.init("w"), modifiers: [.command], action: "关闭"),
            KeyboardShortcut(.init("s"), modifiers: [.command], action: "保存"),
            KeyboardShortcut(.init("z"), modifiers: [.command], action: "撤销"),
            KeyboardShortcut(.init("z"), modifiers: [.command, .shift], action: "重做")
        ]
    }
    
    // MARK: - 多任务支持
    static var supportsSlideOver: Bool {
        #if os(iOS)
        return isIPad
        #else
        return false
        #endif
    }
    
    static var supportsSplitView: Bool {
        #if os(iOS)
        return isIPad
        #else
        return false
        #endif
    }
    
    static var supportsPictureInPicture: Bool {
        #if os(iOS)
        return isIPad
        #else
        return false
        #endif
    }
    
    // MARK: - 手势支持
    static var supportsSwipeGestures: Bool {
        return true
    }
    
    static var supportsPinchZoom: Bool {
        #if os(iOS)
        return isIPad
        #else
        return false
        #endif
    }
    
    static var supportsRotationGesture: Bool {
        #if os(iOS)
        return isIPad
        #else
        return false
        #endif
    }
    
    // MARK: - 性能优化
    static var shouldUseAdvancedAnimations: Bool {
        #if os(iOS)
        if isIPad {
            // 检查设备性能
            let deviceName = UIDevice.current.name
            return !deviceName.contains("iPad Air") || !deviceName.contains("iPad mini")
        }
        return false
        #else
        return false
        #endif
    }
    
    static var preferredAnimationDuration: Double {
        #if os(iOS)
        if isIPad && shouldUseAdvancedAnimations {
            return 0.35
        }
        return 0.25
        #else
        return 0.25
        #endif
    }
}

// MARK: - 键盘快捷键结构
struct KeyboardShortcut {
    let key: KeyEquivalent
    let modifiers: EventModifiers
    let action: String
    
    init(_ key: KeyEquivalent, modifiers: EventModifiers, action: String) {
        self.key = key
        self.modifiers = modifiers
        self.action = action
    }
}

// MARK: - iPadOS特定视图修饰符
extension View {
    
    @ViewBuilder
    func iPadOSOptimized() -> some View {
        #if os(iOS)
        if iPadOSAdapter.isIPad {
            self
                .navigationBarTitleDisplayMode(.automatic)
                .toolbar(.visible, for: .navigationBar)
        } else {
            self
        }
        #else
        self
        #endif
    }
    
    @ViewBuilder
    func iPadOSKeyboardShortcuts() -> some View {
        #if os(iOS)
        if iPadOSAdapter.isIPad {
            // 使用 reduce 来应用键盘快捷键，避免在 ViewBuilder 中使用 for 循环
            iPadOSAdapter.keyboardShortcuts.reduce(AnyView(self)) { view, shortcut in
                AnyView(view.keyboardShortcut(shortcut.key, modifiers: shortcut.modifiers))
            }
        } else {
            self
        }
        #else
        self
        #endif
    }
    
    @ViewBuilder
    func iPadOSHoverEffect() -> some View {
        #if os(iOS)
        if iPadOSAdapter.supportsHoverEffects {
            if #available(iOS 13.4, *) {
                self.hoverEffect(.highlight)
            } else {
                self
            }
        } else {
            self
        }
        #else
        self
        #endif
    }
    
    @ViewBuilder
    func iPadOSPointerInteraction() -> some View {
        #if os(iOS)
        if iPadOSAdapter.supportsPointerInteraction {
            if #available(iOS 13.4, *) {
                self.contentShape(Rectangle())
                    .hoverEffect(.lift)
            } else {
                self
            }
        } else {
            self
        }
        #else
        self
        #endif
    }
    
    @ViewBuilder
    func iPadOSDragAndDrop<T: Transferable>(
        of type: T.Type,
        onDrop: @escaping ([T]) -> Bool
    ) -> some View {
        #if os(iOS)
        if iPadOSAdapter.supportsDragAndDrop {
            self.onDrop(of: [.fileURL], isTargeted: nil) { providers in
                // 处理拖拽
                return true
            }
        } else {
            self
        }
        #else
        self
        #endif
    }
    
    @ViewBuilder
    func iPadOSContextMenu<MenuItems: View>(
        @ViewBuilder menuItems: () -> MenuItems
    ) -> some View {
        #if os(iOS)
        if iPadOSAdapter.isIPad {
            self.contextMenu {
                menuItems()
            }
        } else {
            self
        }
        #else
        self
        #endif
    }
    
    @ViewBuilder
    func iPadOSMultitaskingOptimized() -> some View {
        #if os(iOS)
        if iPadOSAdapter.supportsMultitasking {
            self
                .frame(minWidth: 320) // 支持Slide Over最小宽度
                .background(Color(.systemBackground))
        } else {
            self
        }
        #else
        self
        #endif
    }
}

#if os(iOS)
import GameController

// MARK: - 外接键盘检测
@available(iOS 14.0, *)
extension iPadOSAdapter {
    static func setupKeyboardObserver() {
        NotificationCenter.default.addObserver(
            forName: .GCKeyboardDidConnect,
            object: nil,
            queue: .main
        ) { _ in
            // 键盘连接
            NotificationCenter.default.post(name: .iPadOSKeyboardConnected, object: nil)
        }
        
        NotificationCenter.default.addObserver(
            forName: .GCKeyboardDidDisconnect,
            object: nil,
            queue: .main
        ) { _ in
            // 键盘断开
            NotificationCenter.default.post(name: .iPadOSKeyboardDisconnected, object: nil)
        }
    }
}

// MARK: - 自定义通知
extension Notification.Name {
    static let iPadOSKeyboardConnected = Notification.Name("iPadOSKeyboardConnected")
    static let iPadOSKeyboardDisconnected = Notification.Name("iPadOSKeyboardDisconnected")
    static let iPadOSMultitaskingChanged = Notification.Name("iPadOSMultitaskingChanged")
}
#endif
