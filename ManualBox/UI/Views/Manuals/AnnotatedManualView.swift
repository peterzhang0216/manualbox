import SwiftUI
import PDFKit

// MARK: - 带标注功能的说明书视图
struct AnnotatedManualView: View {
    let manual: Manual
    @StateObject private var annotationService = ManualAnnotationService.shared
    @State private var selectedText: String = ""
    @State private var selectedRange: NSRange = NSRange(location: 0, length: 0)
    @State private var showingAnnotationMenu = false
    @State private var showingAnnotationEditor = false
    @State private var showingAnnotationsList = false
    @State private var currentAnnotationType: AnnotationType = .highlight
    @State private var annotationNote: String = ""
    @State private var selectedAnnotationColor: AnnotationColor = .yellow
    @Environment(\.dismiss) private var dismiss
    
    var manualAnnotations: [ManualAnnotation] {
        annotationService.getAnnotations(for: manual.id ?? UUID())
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 工具栏
                annotationToolbar
                
                Divider()
                
                // 内容视图
                contentView
            }
            .navigationTitle(manual.fileName ?? "说明书")
            #if os(macOS)
            .platformToolbar(leading: {
                Button("关闭") {
                    dismiss()
                }
            }, trailing: {
                Menu {
                    Button(action: {
                        showingAnnotationsList = true
                    }) {
                        Label("查看标注", systemImage: "list.bullet")
                    }
                    
                    Button(action: {
                        exportAnnotations()
                    }) {
                        Label("导出标注", systemImage: "square.and.arrow.up")
                    }
                    
                    Button(action: {
                        clearAllAnnotations()
                    }) {
                        Label("清除所有标注", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            })
            #else
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                SwiftUI.ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }
                
                SwiftUI.ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(action: {
                            showingAnnotationsList = true
                        }) {
                            Label("查看标注", systemImage: "list.bullet")
                        }
                        
                        Button(action: {
                            exportAnnotations()
                        }) {
                            Label("导出标注", systemImage: "square.and.arrow.up")
                        }
                        
                        Button(action: {
                            clearAllAnnotations()
                        }) {
                            Label("清除所有标注", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            #endif
        }
        .sheet(isPresented: $showingAnnotationEditor) {
            AnnotationEditorView(
                text: selectedText,
                note: $annotationNote,
                type: $currentAnnotationType,
                color: $selectedAnnotationColor,
                onSave: { saveAnnotation() },
                onCancel: { showingAnnotationEditor = false }
            )
        }
        .sheet(isPresented: $showingAnnotationsList) {
            AnnotationsListView(
                manual: manual,
                annotations: manualAnnotations
            )
        }
        .alert("添加标注", isPresented: $showingAnnotationMenu) {
            Button("高亮") {
                currentAnnotationType = .highlight
                showingAnnotationEditor = true
            }
            
            Button("下划线") {
                currentAnnotationType = .underline
                showingAnnotationEditor = true
            }
            
            Button("添加笔记") {
                currentAnnotationType = .note
                showingAnnotationEditor = true
            }
            
            Button("书签") {
                currentAnnotationType = .bookmark
                showingAnnotationEditor = true
            }
            
            Button("取消", role: .cancel) { }
        } message: {
            Text("选择标注类型")
        }
    }
    
    // MARK: - 标注工具栏
    private var annotationToolbar: some View {
        HStack(spacing: 16) {
            // 标注类型选择
            HStack(spacing: 8) {
                ForEach(AnnotationType.allCases, id: \.self) { type in
                    Button(action: {
                        currentAnnotationType = type
                    }) {
                        Image(systemName: type.icon)
                            .font(.system(size: 16))
                            .foregroundColor(currentAnnotationType == type ? .white : .primary)
                            .frame(width: 32, height: 32)
                            #if os(macOS)
                            .background(currentAnnotationType == type ? Color.accentColor : Color(nsColor: .windowBackgroundColor))
                            #else
                            .background(currentAnnotationType == type ? Color.accentColor : Color(.systemGray5))
                            #endif
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            Spacer()
            
            // 颜色选择
            HStack(spacing: 6) {
                ForEach(AnnotationColor.allCases, id: \.self) { color in
                    Button(action: {
                        selectedAnnotationColor = color
                    }) {
                        Circle()
                            .fill(Color(color.swiftUIColor))
                            .frame(width: 24, height: 24)
                            .overlay(
                                Circle()
                                    .stroke(selectedAnnotationColor == color ? Color.primary : Color.clear, lineWidth: 2)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            
            Spacer()
            
            // 标注统计
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(manualAnnotations.count)")
                    .font(.caption)
                    .fontWeight(.bold)
                
                Text("标注")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        #if os(macOS)
        .background(Color(NSColor.controlBackgroundColor))
        #else
        .background(Color(.systemGray6))
        #endif
    }
    
    // MARK: - 内容视图
    private var contentView: some View {
        Group {
            if let content = manual.content, !content.isEmpty {
                // 文本内容视图（支持标注）
                AnnotatableTextView(
                    content: content,
                    annotations: manualAnnotations,
                    onTextSelection: { text, range in
                        selectedText = text
                        selectedRange = range
                        if !text.isEmpty {
                            showingAnnotationMenu = true
                        }
                    },
                    onAnnotationTap: { annotation in
                        // 处理标注点击
                        editAnnotation(annotation)
                    }
                )
            } else if let data = manual.fileData {
                // PDF 视图（支持标注）
                if manual.isPDF {
                    AnnotatablePDFView(
                        data: data,
                        annotations: manualAnnotations,
                        onAnnotationAdded: { annotation in
                            Task {
                                await annotationService.addAnnotation(
                                    manualId: manual.id ?? UUID(),
                                    text: annotation.text,
                                    range: annotation.range,
                                    type: annotation.type,
                                    note: annotation.note,
                                    color: annotation.color
                                )
                            }
                        }
                    )
                } else {
                    // 其他文件类型的预览
                    Text("此文件类型暂不支持标注功能")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                Text("无法加载文件内容")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
    
    // MARK: - 标注操作
    
    private func saveAnnotation() {
        guard !selectedText.isEmpty else { return }
        
        Task {
            await annotationService.addAnnotation(
                manualId: manual.id ?? UUID(),
                text: selectedText,
                range: selectedRange,
                type: currentAnnotationType,
                note: annotationNote.isEmpty ? nil : annotationNote,
                color: selectedAnnotationColor
            )
        }
        
        // 重置状态
        selectedText = ""
        selectedRange = NSRange(location: 0, length: 0)
        annotationNote = ""
        showingAnnotationEditor = false
    }
    
    private func editAnnotation(_ annotation: ManualAnnotation) {
        selectedText = annotation.text
        annotationNote = annotation.note ?? ""
        currentAnnotationType = annotation.type
        selectedAnnotationColor = annotation.color
        showingAnnotationEditor = true
    }
    
    private func exportAnnotations() {
        guard let data = annotationService.exportAnnotationsAsJSON(for: manual.id ?? UUID()) else {
            return
        }
        
        let fileName = "\(manual.fileName ?? "manual")_annotations.json"
        
        #if os(iOS)
        let activityVC = UIActivityViewController(activityItems: [data], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityVC, animated: true)
        }
        #else
        let savePanel = NSSavePanel()
        savePanel.nameFieldStringValue = fileName
        savePanel.allowedContentTypes = [.json]
        
        if savePanel.runModal() == .OK {
            if let url = savePanel.url {
                try? data.write(to: url)
            }
        }
        #endif
    }
    
    private func clearAllAnnotations() {
        Task {
            for annotation in manualAnnotations {
                await annotationService.deleteAnnotation(annotation)
            }
        }
    }
}

// MARK: - 可标注文本视图
struct AnnotatableTextView: View {
    let content: String
    let annotations: [ManualAnnotation]
    let onTextSelection: (String, NSRange) -> Void
    let onAnnotationTap: (ManualAnnotation) -> Void
    
    @State private var attributedString: AttributedString
    
    init(
        content: String,
        annotations: [ManualAnnotation],
        onTextSelection: @escaping (String, NSRange) -> Void,
        onAnnotationTap: @escaping (ManualAnnotation) -> Void
    ) {
        self.content = content
        self.annotations = annotations
        self.onTextSelection = onTextSelection
        self.onAnnotationTap = onAnnotationTap
        
        // 初始化带标注的文本
        var attributedString = AttributedString(content)
        
        // 应用标注样式
        for annotation in annotations {
            let range = annotation.range
            if let attributedRange = Range(range, in: attributedString) {
                switch annotation.type {
                case .highlight:
                    attributedString[attributedRange].backgroundColor = annotation.color.swiftUIColor.opacity(0.3)
                case .underline:
                    attributedString[attributedRange].underlineStyle = .single
                    attributedString[attributedRange].foregroundColor = annotation.color.swiftUIColor
                case .note:
                    attributedString[attributedRange].backgroundColor = Color.blue.opacity(0.2)
                case .bookmark:
                    attributedString[attributedRange].backgroundColor = Color.orange.opacity(0.2)
                case .important:
                    attributedString[attributedRange].backgroundColor = Color.red.opacity(0.2)
                    #if os(macOS)
                    attributedString[attributedRange].font = .systemFont(ofSize: NSFont.systemFontSize, weight: .bold)
                    #else
                    attributedString[attributedRange].font = .systemFont(ofSize: UIFont.systemFontSize, weight: .bold)
                    #endif
                }
            }
        }
        
        self._attributedString = State(initialValue: attributedString)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                #if os(iOS)
                Text(attributedString)
                    .textSelection(.enabled)
                    .padding()
                #else
                Text(attributedString)
                    .textSelection(.enabled)
                    .padding()
                #endif
            }
        }
    }
    
    private func handleTextSelection() {
        // 这里需要实现文本选择的处理逻辑
        // 由于SwiftUI的限制，可能需要使用UIKit/AppKit的底层实现
    }
}

// MARK: - 可标注PDF视图
struct AnnotatablePDFView: View {
    let data: Data
    let annotations: [ManualAnnotation]
    let onAnnotationAdded: (ManualAnnotation) -> Void
    
    var body: some View {
        #if os(iOS)
        AnnotatablePDFKitView(
            data: data,
            annotations: annotations,
            onAnnotationAdded: onAnnotationAdded
        )
        #else
        AnnotatablePDFKitViewMac(
            data: data,
            annotations: annotations,
            onAnnotationAdded: onAnnotationAdded
        )
        #endif
    }
}

#if os(iOS)
struct AnnotatablePDFKitView: UIViewRepresentable {
    let data: Data
    let annotations: [ManualAnnotation]
    let onAnnotationAdded: (ManualAnnotation) -> Void
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        
        if let pdfDocument = PDFDocument(data: data) {
            pdfView.document = pdfDocument
        }
        
        // 添加手势识别器用于标注
        let longPressGesture = UILongPressGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleLongPress(_:))
        )
        pdfView.addGestureRecognizer(longPressGesture)
        
        return pdfView
    }
    
    func updateUIView(_ uiView: PDFView, context: Context) {
        // 更新标注显示
        context.coordinator.updateAnnotations(annotations)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        let parent: AnnotatablePDFKitView
        
        init(_ parent: AnnotatablePDFKitView) {
            self.parent = parent
        }
        
        @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            if gesture.state == .began {
                // 处理长按手势，创建标注
                let location = gesture.location(in: gesture.view)
                // 这里需要实现PDF标注的具体逻辑
            }
        }
        
        func updateAnnotations(_ annotations: [ManualAnnotation]) {
            // 更新PDF中的标注显示
        }
    }
}
#else
struct AnnotatablePDFKitViewMac: NSViewRepresentable {
    let data: Data
    let annotations: [ManualAnnotation]
    let onAnnotationAdded: (ManualAnnotation) -> Void
    
    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        
        if let pdfDocument = PDFDocument(data: data) {
            pdfView.document = pdfDocument
        }
        
        return pdfView
    }
    
    func updateNSView(_ nsView: PDFView, context: Context) {
        // 更新标注显示
    }
}
#endif

#Preview {
    AnnotatedManualView(manual: Manual.preview)
}
