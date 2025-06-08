import SwiftUI
import UniformTypeIdentifiers
import Foundation

#if os(macOS)
import AppKit
#else
import UIKit
import PhotosUI
#endif

// MARK: - 平台文件选择器
struct PlatformFilePicker: View {
    let allowedTypes: [UTType]
    let allowsMultipleSelection: Bool
    let onFilesSelected: ([URL]) -> Void
    
    @State private var isPresented = false
    
    init(
        allowedTypes: [UTType] = [.image],
        allowsMultipleSelection: Bool = false,
        onFilesSelected: @escaping ([URL]) -> Void
    ) {
        self.allowedTypes = allowedTypes
        self.allowsMultipleSelection = allowsMultipleSelection
        self.onFilesSelected = onFilesSelected
    }
    
    var body: some View {
        Button("选择文件") {
            isPresented = true
        }
        .fileImporter(
            isPresented: $isPresented,
            allowedContentTypes: allowedTypes,
            allowsMultipleSelection: allowsMultipleSelection
        ) { result in
            handleFileSelection(result)
        }
    }
    
    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            onFilesSelected(urls)
        case .failure(let error):
            print("文件选择失败: \(error.localizedDescription)")
        }
    }
}

// MARK: - 平台图片选择器
struct PlatformImagePicker: View {
    let onImageSelected: (PlatformImage) -> Void
    
    @State private var isPresented = false
    @State private var sourceType: ImageSourceType = .photoLibrary
    
    enum ImageSourceType {
        case camera
        case photoLibrary
        case files
    }
    
    init(onImageSelected: @escaping (PlatformImage) -> Void) {
        self.onImageSelected = onImageSelected
    }
    
    var body: some View {
        #if os(macOS)
        macOSImagePicker
        #else
        iOSImagePicker
        #endif
    }
    
    #if os(macOS)
    private var macOSImagePicker: some View {
        Button("选择图片") {
            let panel = NSOpenPanel()
            panel.allowedContentTypes = [.image]
            panel.allowsMultipleSelection = false
            panel.canChooseDirectories = false
            panel.canChooseFiles = true
            
            if panel.runModal() == .OK {
                if let url = panel.url,
                   let image = NSImage(contentsOf: url) {
                    onImageSelected(image)
                }
            }
        }
    }
    #else
    private var iOSImagePicker: some View {
        Menu("选择图片") {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("拍照") {
                    sourceType = .camera
                    isPresented = true
                }
            }
            
            Button("从相册选择") {
                sourceType = .photoLibrary
                isPresented = true
            }
            
            Button("从文件选择") {
                sourceType = .files
                isPresented = true
            }
        }
        .sheet(isPresented: $isPresented) {
            switch sourceType {
            case .camera, .photoLibrary:
                ImagePickerController(sourceType: sourceType == .camera ? .camera : .photoLibrary) { image in
                    onImageSelected(image)
                }
            case .files:
                PlatformFilePicker(allowedTypes: [.image]) { urls in
                    if let url = urls.first,
                       let data = try? Data(contentsOf: url),
                       let image = UIImage(data: data) {
                        onImageSelected(image)
                    }
                }
            }
        }
    }
    #endif
}

#if !os(macOS)
// MARK: - iOS 图片选择器控制器
struct ImagePickerController: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    let onImageSelected: (UIImage) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePickerController
        
        init(_ parent: ImagePickerController) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImageSelected(image)
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
#endif

// MARK: - 平台文件拖拽区域
struct PlatformDropZone<Content: View>: View {
    let allowedTypes: [UTType]
    let onFilesDropped: ([URL]) -> Void
    let content: () -> Content
    
    @State private var isTargeted = false
    
    init(
        allowedTypes: [UTType] = [.image, .pdf, .text],
        onFilesDropped: @escaping ([URL]) -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.allowedTypes = allowedTypes
        self.onFilesDropped = onFilesDropped
        self.content = content
    }
    
    var body: some View {
        content()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isTargeted ? Color.accentColor : Color.clear,
                        style: StrokeStyle(lineWidth: 2, dash: [5])
                    )
                    .animation(PlatformAdapter.defaultAnimation, value: isTargeted)
            )
            .onDrop(of: allowedTypes, isTargeted: $isTargeted) { providers in
                handleDrop(providers: providers)
                return true
            }
    }
    
    private func handleDrop(providers: [NSItemProvider]) {
        var urls: [URL] = []
        let group = DispatchGroup()
        
        for provider in providers {
            group.enter()
            
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { (urlData, error) in
                    defer { group.leave() }
                    
                    if let data = urlData as? Data,
                       let url = URL(dataRepresentation: data, relativeTo: nil) {
                        urls.append(url)
                    }
                }
            } else {
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            if !urls.isEmpty {
                onFilesDropped(urls)
            }
        }
    }
}

// MARK: - 平台文件导出器
struct PlatformFileExporter<T: SwiftUI.FileDocument>: View {
    let document: T
    let defaultName: String
    let onExport: (Result<URL, Error>) -> Void
    
    @State private var isPresented = false
    
    init(
        document: T,
        defaultName: String,
        onExport: @escaping (Result<URL, Error>) -> Void
    ) {
        self.document = document
        self.defaultName = defaultName
        self.onExport = onExport
    }
    
    var body: some View {
        Button("导出文件") {
            isPresented = true
        }
        .fileExporter(
            isPresented: $isPresented,
            document: document,
            contentType: T.readableContentTypes.first ?? .data,
            defaultFilename: defaultName
        ) { result in
            onExport(result)
        }
    }
}

// MARK: - 文本文档实现
struct TextFileDocument: SwiftUI.FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }
    
    let content: String
    
    init(content: String) {
        self.content = content
    }
    
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let string = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.content = string
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = content.data(using: .utf8) ?? Data()
        return FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - JSON文档实现
struct JSONFileDocument<T: Codable>: SwiftUI.FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    
    let data: T
    
    init(data: T) {
        self.data = data
    }
    
    init(configuration: ReadConfiguration) throws {
        guard let fileData = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = try JSONDecoder().decode(T.self, from: fileData)
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let jsonData = try JSONEncoder().encode(data)
        return FileWrapper(regularFileWithContents: jsonData)
    }
}

// MARK: - 平台文件管理器
class PlatformFileManager: ObservableObject {
    static let shared = PlatformFileManager()
    
    private init() {}
    
    // MARK: - 文档目录
    var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    // MARK: - 应用支持目录
    var applicationSupportDirectory: URL {
        let urls = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupportURL = urls.first!.appendingPathComponent(Bundle.main.bundleIdentifier!)
        
        // 确保目录存在
        try? FileManager.default.createDirectory(at: appSupportURL, withIntermediateDirectories: true)
        
        return appSupportURL
    }
    
    // MARK: - 缓存目录
    var cacheDirectory: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
    }
    
    // MARK: - 临时目录
    var temporaryDirectory: URL {
        FileManager.default.temporaryDirectory
    }
    
    // MARK: - 文件操作
    func saveData(_ data: Data, to fileName: String, in directory: URL = PlatformFileManager.shared.documentsDirectory) throws -> URL {
        let fileURL = directory.appendingPathComponent(fileName)
        try data.write(to: fileURL)
        return fileURL
    }
    
    func loadData(from fileName: String, in directory: URL = PlatformFileManager.shared.documentsDirectory) throws -> Data {
        let fileURL = directory.appendingPathComponent(fileName)
        return try Data(contentsOf: fileURL)
    }
    
    func deleteFile(at url: URL) throws {
        try FileManager.default.removeItem(at: url)
    }
    
    func fileExists(at url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }
    
    func createDirectory(at url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
    
    // MARK: - 文件大小
    func fileSize(at url: URL) -> Int64? {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            return attributes[.size] as? Int64
        } catch {
            return nil
        }
    }
    
    // MARK: - 文件修改日期
    func modificationDate(at url: URL) -> Date? {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            return attributes[.modificationDate] as? Date
        } catch {
            return nil
        }
    }
}

// MARK: - 文件信息结构
struct FileInfo {
    let url: URL
    let name: String
    let size: Int64
    let modificationDate: Date
    let type: UTType?
    
    init(url: URL) {
        self.url = url
        self.name = url.lastPathComponent
        self.size = PlatformFileManager.shared.fileSize(at: url) ?? 0
        self.modificationDate = PlatformFileManager.shared.modificationDate(at: url) ?? Date()
        self.type = UTType(filenameExtension: url.pathExtension)
    }
    
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
    
    var isImage: Bool {
        type?.conforms(to: .image) ?? false
    }
    
    var isPDF: Bool {
        type?.conforms(to: .pdf) ?? false
    }
    
    var isText: Bool {
        type?.conforms(to: .text) ?? false
    }
}