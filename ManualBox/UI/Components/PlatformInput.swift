import SwiftUI
import UniformTypeIdentifiers

// MARK: - 平台特定输入处理器
struct PlatformInputHandler {
    
    // MARK: - 键盘快捷键
    static func keyboardShortcuts() -> [KeyboardShortcut] {
        #if os(macOS)
        return [
            KeyboardShortcut(.init("n"), modifiers: [.command]), // 新建
            KeyboardShortcut(.init("f"), modifiers: [.command]), // 搜索
            KeyboardShortcut(.init("e"), modifiers: [.command]), // 编辑
            KeyboardShortcut(.delete, modifiers: [.command]), // 删除
            KeyboardShortcut(.init("r"), modifiers: [.command]), // 刷新
            KeyboardShortcut(.init("s"), modifiers: [.command]), // 保存
            KeyboardShortcut(.init("z"), modifiers: [.command]), // 撤销
            KeyboardShortcut(.init("z"), modifiers: [.command, .shift]), // 重做
            KeyboardShortcut(.init("a"), modifiers: [.command]), // 全选
            KeyboardShortcut(.init("c"), modifiers: [.command]), // 复制
            KeyboardShortcut(.init("v"), modifiers: [.command]), // 粘贴
            KeyboardShortcut(.init("x"), modifiers: [.command]), // 剪切
            KeyboardShortcut(.init("w"), modifiers: [.command]), // 关闭
            KeyboardShortcut(.init("q"), modifiers: [.command]), // 退出
            KeyboardShortcut(.init(","), modifiers: [.command]), // 偏好设置
            KeyboardShortcut(.init("1"), modifiers: [.command]), // 切换到第一个标签
            KeyboardShortcut(.init("2"), modifiers: [.command]), // 切换到第二个标签
            KeyboardShortcut(.init("3"), modifiers: [.command]), // 切换到第三个标签
            KeyboardShortcut(.init("4"), modifiers: [.command])  // 切换到第四个标签
        ]
        #else
        return [] // iOS 主要依靠触摸交互
        #endif
    }
    
    // MARK: - 快捷键动作映射
    enum ShortcutAction: String, CaseIterable {
        case newItem = "n"
        case search = "f"
        case edit = "e"
        case delete = "delete"
        case refresh = "r"
        case save = "s"
        case undo = "z"
        case redo = "z+shift"
        case selectAll = "a"
        case copy = "c"
        case paste = "v"
        case cut = "x"
        case close = "w"
        case quit = "q"
        case preferences = ","
        case tab1 = "1"
        case tab2 = "2"
        case tab3 = "3"
        case tab4 = "4"
        
        var keyboardShortcut: KeyboardShortcut {
            #if os(macOS)
            switch self {
            case .newItem:
                return KeyboardShortcut(.init("n"), modifiers: [.command])
            case .search:
                return KeyboardShortcut(.init("f"), modifiers: [.command])
            case .edit:
                return KeyboardShortcut(.init("e"), modifiers: [.command])
            case .delete:
                return KeyboardShortcut(.delete, modifiers: [.command])
            case .refresh:
                return KeyboardShortcut(.init("r"), modifiers: [.command])
            case .save:
                return KeyboardShortcut(.init("s"), modifiers: [.command])
            case .undo:
                return KeyboardShortcut(.init("z"), modifiers: [.command])
            case .redo:
                return KeyboardShortcut(.init("z"), modifiers: [.command, .shift])
            case .selectAll:
                return KeyboardShortcut(.init("a"), modifiers: [.command])
            case .copy:
                return KeyboardShortcut(.init("c"), modifiers: [.command])
            case .paste:
                return KeyboardShortcut(.init("v"), modifiers: [.command])
            case .cut:
                return KeyboardShortcut(.init("x"), modifiers: [.command])
            case .close:
                return KeyboardShortcut(.init("w"), modifiers: [.command])
            case .quit:
                return KeyboardShortcut(.init("q"), modifiers: [.command])
            case .preferences:
                return KeyboardShortcut(.init(","), modifiers: [.command])
            case .tab1:
                return KeyboardShortcut(.init("1"), modifiers: [.command])
            case .tab2:
                return KeyboardShortcut(.init("2"), modifiers: [.command])
            case .tab3:
                return KeyboardShortcut(.init("3"), modifiers: [.command])
            case .tab4:
                return KeyboardShortcut(.init("4"), modifiers: [.command])
            }
            #else
            return KeyboardShortcut(.space) // iOS 占位符
            #endif
        }
        
        var description: String {
            switch self {
            case .newItem: return "新建项目"
            case .search: return "搜索"
            case .edit: return "编辑"
            case .delete: return "删除"
            case .refresh: return "刷新"
            case .save: return "保存"
            case .undo: return "撤销"
            case .redo: return "重做"
            case .selectAll: return "全选"
            case .copy: return "复制"
            case .paste: return "粘贴"
            case .cut: return "剪切"
            case .close: return "关闭"
            case .quit: return "退出"
            case .preferences: return "偏好设置"
            case .tab1: return "产品"
            case .tab2: return "分类"
            case .tab3: return "标签"
            case .tab4: return "设置"
            }
        }
    }
    
    // MARK: - 文件拖拽处理
    static func handleFileDrop(providers: [NSItemProvider], completion: @escaping ([URL]) -> Void) {
        var urls: [URL] = []
        let group = DispatchGroup()
        
        for provider in providers {
            group.enter()
            
            #if os(macOS)
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { (urlData, error) in
                    if let data = urlData as? Data,
                       let url = URL(dataRepresentation: data, relativeTo: nil) {
                        urls.append(url)
                    }
                    group.leave()
                }
            } else {
                group.leave()
            }
            #else
            if provider.canLoadObject(ofClass: URL.self) {
                _ = provider.loadObject(ofClass: URL.self) { url, error in
                    if let url = url {
                        urls.append(url)
                    }
                    group.leave()
                }
            } else {
                group.leave()
            }
            #endif
        }
        
        group.notify(queue: .main) {
            completion(urls)
        }
    }
    
    // MARK: - 上下文菜单
    static func contextMenu(for item: Any) -> ContextMenu<AnyView> {
        #if os(macOS)
        return ContextMenu {
            AnyView(
                Group {
                    Button("编辑", action: {})
                    Button("复制", action: {})
                    Button("分享", action: {})
                    Divider()
                    Button("删除", role: .destructive, action: {})
                }
            )
        }
        #else
        return ContextMenu {
            AnyView(
                Group {
                    Button(action: {}) {
                        Label("编辑", systemImage: "pencil")
                    }
                    Button(action: {}) {
                        Label("分享", systemImage: "square.and.arrow.up")
                    }
                    Button(action: {}) {
                        Label("删除", systemImage: "trash")
                    }
                }
            )
        }
        #endif
    }
    
    // MARK: - 触摸手势处理
    static var longPressGesture: some Gesture {
        #if os(macOS)
        return TapGesture(count: 2) // macOS 双击
        #else
        return LongPressGesture(minimumDuration: 0.5) // iOS 长按
        #endif
    }
}

// MARK: - 平台特定的文件选择器

#if os(iOS)
struct DocumentPicker: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf, .image])
        picker.allowsMultipleSelection = true
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
}
#endif

// MARK: - 平台感知的列表组件
struct PlatformList<Content: View>: View {
    let content: () -> Content
    @State private var hoveredItem: UUID?
    
    var body: some View {
        List {
            content()
        }
        .listStyle(PlatformAdapter.preferredListStyle)
        #if os(macOS)
        .alternatingRowBackgrounds()
        .onHover { isHovering in
            // macOS 悬停效果
        }
        #else
        .refreshable {
            // iOS 下拉刷新
        }
        #endif
    }
}