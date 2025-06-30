import SwiftUI
import PDFKit
import UniformTypeIdentifiers
#if os(iOS)
import QuickLook
#endif

struct ManualPreviewView: View {
    let manual: Manual
    @Environment(\.dismiss) private var dismiss
    @State private var previewImage: PlatformImage?
    @State private var previewURL: URL?
    @State private var showingAnnotationView = false
    @State private var showingVersionView = false
    
    private var contentView: some View {
        Group {
            if let content = manual.content, !content.isEmpty {
                // 如果有OCR内容，显示文本
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(content)
                            .padding()
                    }
                }
            } else if let data = manual.fileData {
                // 根据文件类型显示不同的预览
                filePreviewView(data: data)
                    .padding()
            } else {
                Text("无法加载文件内容")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func filePreviewView(data: Data) -> some View {
        Group {
            if manual.fileType == "pdf" {
                PDFPreview(data: data)
            } else if let image = PlatformImage(data: data) {
                Image(platformImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Text("无法预览此文件类型")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    var body: some View {
        VStack {
            contentView
        }
        .navigationTitle(manual.fileName ?? "说明书预览")
        .toolbar {
            SwiftUI.ToolbarItem(placement: .confirmationAction) {
                Button("完成") {
                    dismiss()
                }
            }

            SwiftUI.ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showingAnnotationView = true
                    } label: {
                        Label("标注", systemImage: "highlighter")
                    }

                    Button {
                        showingVersionView = true
                    } label: {
                        Label("版本历史", systemImage: "clock.arrow.circlepath")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }

            if let fileData = manual.fileData {
                SwiftUI.ToolbarItem(placement: .secondaryAction) {
                    Button {
                        exportFile(data: fileData, name: manual.fileName ?? "manual.pdf")
                    } label: {
                        Label("导出", systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
        .sheet(isPresented: $showingAnnotationView) {
            AnnotatedManualView(manual: manual)
        }
        .sheet(isPresented: $showingVersionView) {
            ManualVersionView(manual: manual)
        }
        .onAppear {
            loadPreview()
        }
    }
    
    private func loadPreview() {
        guard let data = manual.fileData else { return }
        
        // 创建临时文件用于预览
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = manual.fileName ?? "preview.\(manual.fileType ?? "pdf")"
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        do {
            try data.write(to: fileURL)
            self.previewURL = fileURL
            
            // 如果是图片，也加载为图像
            if manual.fileType != "pdf" {
                self.previewImage = PlatformImage(data: data)
            }
        } catch {
            print("无法创建预览文件: \(error.localizedDescription)")
        }
    }
    
    private func exportFile(data: Data, name: String) {
        guard let url = previewURL else { return }
        
        #if os(iOS)
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            activityVC.popoverPresentationController?.sourceView = rootVC.view
            rootVC.present(activityVC, animated: true)
        }
        #else
        let savePanel = NSSavePanel()
        savePanel.nameFieldStringValue = name
        savePanel.allowedContentTypes = [UTType(filenameExtension: URL(fileURLWithPath: name).pathExtension) ?? .data]
        
        savePanel.begin { result in
            if result == .OK, let url = savePanel.url {
                do {
                    try data.write(to: url)
                } catch {
                    print("导出失败: \(error.localizedDescription)")
                }
            }
        }
        #endif
    }
}

// PDF预览组件
struct PDFPreview: View {
    let data: Data
    
    var body: some View {
        #if os(iOS)
        PDFUIKitWrapper(data: data)
            .edgesIgnoringSafeArea(.all)
        #else
        ManualPDFKitView(data: data)
            .edgesIgnoringSafeArea(.all)
        #endif
    }
}

#if os(iOS)
struct PDFUIKitWrapper: UIViewRepresentable {
    let data: Data
    
    func makeUIView(context: Context) -> PDFKit.PDFView {
        let pdfView = PDFKit.PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        
        if let pdfDocument = PDFDocument(data: data) {
            pdfView.document = pdfDocument
        }
        
        return pdfView
    }
    
    func updateUIView(_ uiView: PDFKit.PDFView, context: Context) {}
}
#else
struct ManualPDFKitView: NSViewRepresentable {
    let data: Data
    
    func makeNSView(context: Context) -> PDFKit.PDFView {
        let pdfView = PDFKit.PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        
        if let pdfDocument = PDFDocument(data: data) {
            pdfView.document = pdfDocument
        }
        
        return pdfView
    }
    
    func updateNSView(_ nsView: PDFKit.PDFView, context: Context) {}
}
#endif

struct ManualPreviewView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ManualPreviewView(manual: PersistenceController.preview.previewManual())
        }
    }
}

// 预览用的扩展
extension PersistenceController {
    func previewManual() -> Manual {
        let context = container.viewContext
        let manual = Manual(context: context)
        manual.id = UUID()
        manual.fileName = "说明书.pdf"
        manual.fileType = "pdf"
        manual.content = "OCR识别的内容将显示在这里。"
        return manual
    }
}
