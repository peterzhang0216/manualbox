import SwiftUI
import UniformTypeIdentifiers
import CoreData

// MARK: - 系统颜色扩展
extension Color {
    static var systemSecondaryBackground: Color {
        #if os(macOS)
        return Color(.controlBackgroundColor)
        #else
        return Color(UIColor.secondarySystemBackground)
        #endif
    }
    
    static var systemTertiaryBackground: Color {
        #if os(macOS)
        return Color(.tertiaryLabelColor).opacity(0.1)
        #else
        return Color(UIColor.tertiarySystemBackground)
        #endif
    }
}

struct EnhancedFileUploadView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var fileProcessingService = FileProcessingService.shared
    @StateObject private var uploadViewModel = FileUploadViewModel()
    
    let targetProduct: Product?
    let onFilesUploaded: ([Manual]) -> Void
    
    @State private var showFileImporter = false
    @State private var showProcessingOptions = false
    @State private var processingOptions = FileProcessingOptions.default
    @State private var dragOver = false
    
    var body: some View {
        VStack(spacing: 20) {
            // 文件上传区域
            fileUploadZone
            
            // 处理选项设置
            if showProcessingOptions {
                processingOptionsView
            }
            
            // 处理进度显示
            if fileProcessingService.isProcessing {
                processingProgressView
            }
            
            // 处理结果展示
            if !uploadViewModel.processedFiles.isEmpty {
                processedFilesView
            }
        }
        .padding()
        .navigationTitle("上传说明书")
        .toolbar {
            Button {
                withAnimation {
                    showProcessingOptions.toggle() 
                }
            } label: {
                Image(systemName: "gear")
            }
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.pdf, .image, .text],
            allowsMultipleSelection: true
        ) { result in
            handleFileSelection(result)
        }
    }
    
    // MARK: - 文件上传区域
    private var fileUploadZone: some View {
        VStack(spacing: 24) {
            // 拖拽上传区域
            dragDropZone
            
            // 分隔线
            HStack {
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(.secondary.opacity(0.3))
                
                Text("或")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(.secondary.opacity(0.3))
            }
            
            // 选择文件按钮
            Button(action: { showFileImporter = true }) {
                HStack(spacing: 12) {
                    Image(systemName: "folder.badge.plus")
                        .font(.title2)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("选择文件")
                            .font(.headline)
                        Text("支持 PDF、图片和文本文件")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.accentColor.opacity(0.1))
                .foregroundColor(.accentColor)
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
        }
    }
    
    private var dragDropZone: some View {
        VStack(spacing: 16) {
            Image(systemName: dragOver ? "doc.badge.plus" : "icloud.and.arrow.up")
                .font(.system(size: 48))
                .foregroundColor(dragOver ? .accentColor : .secondary)
                .scaleEffect(dragOver ? 1.1 : 1.0)
                .animation(.spring(response: 0.3), value: dragOver)
            
            VStack(spacing: 4) {
                Text(dragOver ? "松开以上传文件" : "拖拽文件到这里")
                    .font(.title3)
                    .fontWeight(.medium)
                
                Text("支持多个文件同时上传")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 120)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    dragOver ? Color.accentColor : Color.secondary.opacity(0.3),
                    style: StrokeStyle(lineWidth: 2, dash: dragOver ? [] : [5])
                )
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(dragOver ? Color.accentColor.opacity(0.1) : Color.clear)
                )
        )
        .onDrop(of: [.fileURL], isTargeted: $dragOver) { providers in
            handleDrop(providers: providers)
        }
    }
    
    // MARK: - 处理选项视图
    private var processingOptionsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("处理选项")
                    .font(.headline)
                Spacer()
                Button("重置") {
                    processingOptions = .default
                }
                .font(.caption)
                .foregroundColor(.accentColor)
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                
                OptionToggle(
                    title: "文件压缩",
                    subtitle: "减小文件大小",
                    icon: "arrow.down.circle",
                    isOn: $processingOptions.shouldCompress
                )
                
                OptionToggle(
                    title: "OCR识别",
                    subtitle: "提取文字内容",
                    icon: "doc.text.viewfinder",
                    isOn: $processingOptions.shouldPerformOCR
                )
                
                OptionToggle(
                    title: "元数据提取",
                    subtitle: "获取文件信息",
                    icon: "info.circle",
                    isOn: $processingOptions.shouldExtractMetadata
                )
                
                OptionToggle(
                    title: "生成缩略图",
                    subtitle: "创建预览图",
                    icon: "photo",
                    isOn: $processingOptions.shouldGenerateThumbnail
                )
            }
            
            // 压缩质量设置
            if processingOptions.shouldCompress {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("压缩质量")
                            .font(.subheadline)
                        Spacer()
                        Text("\(Int(processingOptions.compressionQuality * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(
                        value: Binding(
                            get: { processingOptions.compressionQuality },
                            set: { newValue in
                                processingOptions = FileProcessingOptions(
                                    shouldCompress: processingOptions.shouldCompress,
                                    compressionQuality: newValue,
                                    shouldExtractMetadata: processingOptions.shouldExtractMetadata,
                                    shouldPerformOCR: processingOptions.shouldPerformOCR,
                                    shouldGenerateThumbnail: processingOptions.shouldGenerateThumbnail,
                                    maxFileSize: processingOptions.maxFileSize
                                )
                            }
                        ),
                        in: 0.1...1.0
                    )
                    .accentColor(.accentColor)
                }
            }
        }
        .padding()
        .background(Color.systemSecondaryBackground)
        .cornerRadius(12)
        .transition(.opacity.combined(with: .scale))
    }
    
    // MARK: - 处理进度视图
    private var processingProgressView: some View {
        VStack(spacing: 12) {
            HStack {
                Text("正在处理文件...")
                    .font(.headline)
                Spacer()
                Text("\(Int(fileProcessingService.processingProgress * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            ProgressView(value: fileProcessingService.processingProgress)
                .progressViewStyle(LinearProgressViewStyle(tint: .accentColor))
            
            if !fileProcessingService.processingQueue.isEmpty {
                Text("队列中: \(fileProcessingService.processingQueue.count) 个文件")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.systemTertiaryBackground)
        .cornerRadius(12)
    }
    
    // MARK: - 处理结果视图
    private var processedFilesView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("处理完成")
                    .font(.headline)
                Spacer()
                Button("清除") {
                    uploadViewModel.clearProcessedFiles()
                }
                .font(.caption)
                .foregroundColor(.accentColor)
            }
            
            LazyVStack(spacing: 8) {
                ForEach(uploadViewModel.processedFiles, id: \.url) { processedFile in
                    ProcessedFileRow(processedFile: processedFile)
                }
            }
            
            if uploadViewModel.processedFiles.allSatisfy({ $0.success }) {
                Button(action: saveAllFiles) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("保存所有文件")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(Color.systemSecondaryBackground)
        .cornerRadius(12)
    }
    
    // MARK: - 文件处理方法
    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            processFiles(urls: urls)
        case .failure(let error):
            uploadViewModel.setError("文件选择失败: \(error.localizedDescription)")
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        let group = DispatchGroup()
        var urls: [URL] = []
        
        for provider in providers {
            group.enter()
            _ = provider.loadObject(ofClass: URL.self) { url, error in
                defer { group.leave() }
                if let url = url {
                    urls.append(url)
                }
            }
        }
        
        group.notify(queue: .main) {
            processFiles(urls: urls)
        }
        
        return true
    }
    
    private func processFiles(urls: [URL]) {
        Task {
            await uploadViewModel.processFiles(
                urls: urls,
                options: processingOptions,
                for: targetProduct
            )
        }
    }
    
    private func saveAllFiles() {
        Task {
            let manuals = await uploadViewModel.saveToDatabase(context: viewContext)
            onFilesUploaded(manuals)
        }
    }
}

// MARK: - 选项切换组件
struct OptionToggle: View {
    let title: String
    let subtitle: String
    let icon: String
    @Binding var isOn: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(isOn ? .accentColor : .secondary)
                Spacer()
                Toggle("", isOn: $isOn)
                    .toggleStyle(SwitchToggleStyle(tint: .accentColor))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .background(isOn ? Color.accentColor.opacity(0.1) : Color.systemTertiaryBackground)
        .cornerRadius(8)
    }
}

// MARK: - 处理文件行组件
struct ProcessedFileRow: View {
    let processedFile: FileUploadViewModel.ProcessedFile
    
    var body: some View {
        HStack(spacing: 12) {
            // 文件图标
            Image(systemName: processedFile.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.title2)
                .foregroundColor(processedFile.success ? .green : .red)
            
            // 文件信息
            VStack(alignment: .leading, spacing: 2) {
                Text(processedFile.url.lastPathComponent)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                if let result = processedFile.result {
                    HStack(spacing: 8) {
                        Text(formatFileSize(result.processedFileSize))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if result.compressionRatio < 1.0 {
                            Text("压缩 \(Int((1 - result.compressionRatio) * 100))%")
                                .font(.caption)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.green.opacity(0.2))
                                .foregroundColor(.green)
                                .cornerRadius(4)
                        }
                    }
                } else if let error = processedFile.error {
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundColor(.red)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            // 处理状态
            if processedFile.success {
                Image(systemName: "doc.badge.plus")
                    .foregroundColor(.green)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatFileSize(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

// MARK: - 文件上传视图模型
@MainActor
class FileUploadViewModel: ObservableObject {
    @Published var processedFiles: [ProcessedFile] = []
    @Published var isProcessing = false
    @Published var errorMessage: String?
    
    private let fileProcessingService = FileProcessingService.shared
    
    struct ProcessedFile {
        let url: URL
        let result: FileProcessingResult?
        let error: Error?
        var success: Bool { result != nil && error == nil }
    }
    
    func processFiles(
        urls: [URL],
        options: FileProcessingOptions,
        for product: Product?
    ) async {
        isProcessing = true
        processedFiles.removeAll()
        
        for url in urls {
            do {
                let result = try await fileProcessingService.processFile(
                    from: url,
                    for: product,
                    options: options
                )
                
                let processedFile = ProcessedFile(
                    url: url,
                    result: result,
                    error: nil
                )
                processedFiles.append(processedFile)
                
            } catch {
                let processedFile = ProcessedFile(
                    url: url,
                    result: nil,
                    error: error
                )
                processedFiles.append(processedFile)
            }
        }
        
        isProcessing = false
    }
    
    func saveToDatabase(context: NSManagedObjectContext) async -> [Manual] {
        var manuals: [Manual] = []
        
        for processedFile in processedFiles {
            guard let result = processedFile.result else { continue }
            
            let manual = Manual.createManual(
                in: context,
                fileName: processedFile.url.lastPathComponent,
                fileData: result.processedFileData,
                fileType: result.fileType.preferredFilenameExtension ?? "unknown",
                product: processedFile.url.lastPathComponent.contains("product") ? nil : nil // 根据需要关联产品
            )
            
            // 设置OCR内容
            if let ocrText = result.ocrText {
                manual.content = ocrText
                manual.isOCRProcessed = true
            }
            
            manuals.append(manual)
        }
        
        do {
            try context.save()
        } catch {
            setError("保存失败: \(error.localizedDescription)")
        }
        
        return manuals
    }
    
    func clearProcessedFiles() {
        processedFiles.removeAll()
    }
    
    func setError(_ message: String) {
        errorMessage = message
    }
}

#Preview {
    NavigationView {
        EnhancedFileUploadView(
            targetProduct: nil,
            onFilesUploaded: { _ in }
        )
    }
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}