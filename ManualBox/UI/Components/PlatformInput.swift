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
            KeyboardShortcut(.init("r"), modifiers: [.command]) // 刷新
        ]
        #else
        return [] // iOS 主要依靠触摸交互
        #endif
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
                provider.loadObject(ofClass: URL.self) { url, error in
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
struct PlatformFilePicker: View {
    @Binding var isPresented: Bool
    let onFilesSelected: ([URL]) -> Void
    let allowedContentTypes: [UTType]
    
    #if os(macOS)
    var body: some View {
        Button("选择文件") {
            let panel = NSOpenPanel()
            panel.allowsMultipleSelection = true
            panel.canChooseFiles = true
            panel.canChooseDirectories = false
            panel.allowedContentTypes = allowedContentTypes
            
            if panel.runModal() == .OK {
                onFilesSelected(panel.urls)
            }
            isPresented = false
        }
    }
    #else
    @State private var documentPicker = DocumentPicker()
    
    var body: some View {
        Button("选择文件") {
            isPresented = true
        }
        .fileImporter(
            isPresented: $isPresented,
            allowedContentTypes: allowedContentTypes,
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                onFilesSelected(urls)
            case .failure(let error):
                print("文件选择失败: \(error)")
            }
        }
    }
    #endif
}

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

// MARK: - 平台特定的搜索栏
struct PlatformSearchBar: View {
    @Binding var searchText: String
    let placeholder: String
    let onSearchCommit: () -> Void
    
    var body: some View {
        #if os(macOS)
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField(placeholder, text: $searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .onSubmit {
                    onSearchCommit()
                }
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal)
        #else
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField(placeholder, text: $searchText)
                    .submitLabel(.search)
                    .onSubmit {
                        onSearchCommit()
                    }
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(10)
        }
        .padding(.horizontal)
        #endif
    }
}