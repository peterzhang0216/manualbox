import Foundation
import UniformTypeIdentifiers
import PDFKit
import ImageIO
import CoreImage
import SwiftUI

// MARK: - 增强版文件处理服务
@MainActor
class FileProcessingService: ObservableObject {
    static let shared = FileProcessingService()
    
    @Published var isProcessing = false
    @Published var processingProgress: Float = 0.0
    @Published var processingQueue: [FileProcessingTask] = []
    
    private let compressionService = ImageCompressionService()
    private let validationService = FileValidationService()
    private let metadataExtractor = FileMetadataExtractor()
    
    private init() {}
    
    // MARK: - 文件处理任务
    struct FileProcessingTask: Identifiable {
        let id = UUID()
        let fileURL: URL
        let targetProduct: Product?
        let processingOptions: ProcessingOptions
        var status: TaskStatus = .pending
        var progress: Float = 0.0
        var result: ProcessingResult?
        var error: FileProcessingError?
        
        enum TaskStatus {
            case pending
            case processing
            case completed
            case failed
        }
    }
    
    // MARK: - 处理选项
    struct ProcessingOptions {
        var shouldCompress: Bool
        var compressionQuality: Float
        var shouldExtractMetadata: Bool
        var shouldPerformOCR: Bool
        var shouldGenerateThumbnail: Bool
        var maxFileSize: Int // MB
        
        static let `default` = ProcessingOptions(
            shouldCompress: true,
            compressionQuality: 0.8,
            shouldExtractMetadata: true,
            shouldPerformOCR: true,
            shouldGenerateThumbnail: true,
            maxFileSize: 50
        )
        
        static let highQuality = ProcessingOptions(
            shouldCompress: false,
            compressionQuality: 1.0,
            shouldExtractMetadata: true,
            shouldPerformOCR: true,
            shouldGenerateThumbnail: true,
            maxFileSize: 100
        )
    }
    
    // MARK: - 处理结果
    struct ProcessingResult {
        let processedFileData: Data
        let originalFileSize: Int
        let processedFileSize: Int
        let compressionRatio: Float
        let fileMetadata: FileMetadata?
        let thumbnailImage: PlatformImage?
        let ocrText: String?
        let processingTime: TimeInterval
        let fileType: UTType
    }
    
    // MARK: - 文件元数据
    struct FileMetadata {
        let fileName: String
        let fileExtension: String
        let mimeType: String
        let creationDate: Date?
        let modificationDate: Date?
        let fileSize: Int
        let imageProperties: ImageProperties?
        let pdfProperties: PDFProperties?
        
        struct ImageProperties {
            let width: Int
            let height: Int
            let colorSpace: String?
            let dpi: Float?
            let hasAlpha: Bool
        }
        
        struct PDFProperties {
            let pageCount: Int
            let title: String?
            let author: String?
            let subject: String?
            let creator: String?
            let isEncrypted: Bool
        }
    }
    
    // MARK: - 主要处理方法
    func processFile(
        from url: URL,
        for product: Product? = nil,
        options: ProcessingOptions = .default
    ) async throws -> ProcessingResult {
        
        let task = FileProcessingTask(
            fileURL: url,
            targetProduct: product,
            processingOptions: options
        )
        
        await MainActor.run {
            self.processingQueue.append(task)
            self.isProcessing = true
            self.processingProgress = 0.0
        }
        
        defer {
            Task { @MainActor in
                self.processingQueue.removeAll { $0.id == task.id }
                if self.processingQueue.isEmpty {
                    self.isProcessing = false
                    self.processingProgress = 0.0
                }
            }
        }
        
        return try await performFileProcessing(task: task)
    }
    
    // MARK: - 私有处理方法
    private func performFileProcessing(task: FileProcessingTask) async throws -> ProcessingResult {
        let startTime = Date()
        
        // 步骤1: 文件验证 (10%)
        await updateProgress(0.1)
        try validationService.validateFile(at: task.fileURL, options: task.processingOptions)
        
        // 步骤2: 读取文件数据 (20%)
        await updateProgress(0.2)
        let originalData = try Data(contentsOf: task.fileURL)
        let fileType = UTType(filenameExtension: task.fileURL.pathExtension) ?? .data
        
        // 步骤3: 提取元数据 (30%)
        await updateProgress(0.3)
        var metadata: FileMetadata? = nil
        if task.processingOptions.shouldExtractMetadata {
            metadata = try await metadataExtractor.extractMetadata(from: task.fileURL, data: originalData)
        }
        
        // 步骤4: 图像处理和压缩 (50%)
        await updateProgress(0.5)
        var processedData = originalData
        if task.processingOptions.shouldCompress && (fileType.conforms(to: .image) || fileType.conforms(to: .pdf)) {
            processedData = try await compressFile(data: originalData, fileType: fileType, options: task.processingOptions)
        }
        
        // 步骤5: 生成缩略图 (70%)
        await updateProgress(0.7)
        var thumbnailImage: PlatformImage? = nil
        if task.processingOptions.shouldGenerateThumbnail {
            thumbnailImage = try await generateThumbnail(from: processedData, fileType: fileType)
        }
        
        // 步骤6: OCR处理 (90%)
        await updateProgress(0.9)
        var ocrText: String? = nil
        if task.processingOptions.shouldPerformOCR && (fileType.conforms(to: .image) || fileType.conforms(to: .pdf)) {
            ocrText = try await performOCRProcessing(data: processedData, fileType: fileType)
        }
        
        // 步骤7: 完成处理 (100%)
        await updateProgress(1.0)
        
        let processingTime = Date().timeIntervalSince(startTime)
        let compressionRatio = Float(processedData.count) / Float(originalData.count)
        
        return ProcessingResult(
            processedFileData: processedData,
            originalFileSize: originalData.count,
            processedFileSize: processedData.count,
            compressionRatio: compressionRatio,
            fileMetadata: metadata,
            thumbnailImage: thumbnailImage,
            ocrText: ocrText,
            processingTime: processingTime,
            fileType: fileType
        )
    }
    
    // MARK: - 具体处理步骤
    private func compressFile(
        data: Data,
        fileType: UTType,
        options: ProcessingOptions
    ) async throws -> Data {
        if fileType.conforms(to: .image) {
            return try await compressionService.compressImage(data: data, quality: options.compressionQuality)
        } else if fileType.conforms(to: .pdf) {
            return try await compressionService.compressPDF(data: data, quality: options.compressionQuality)
        }
        return data
    }
    
    private func generateThumbnail(from data: Data, fileType: UTType) async throws -> PlatformImage? {
        if fileType.conforms(to: .image) {
            return try await generateImageThumbnail(from: data)
        } else if fileType.conforms(to: .pdf) {
            return try await generatePDFThumbnail(from: data)
        }
        return nil
    }
    
    private func generateImageThumbnail(from data: Data) async throws -> PlatformImage? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                guard let image = PlatformImage(data: data) else {
                    continuation.resume(returning: nil)
                    return
                }
                let targetSize = CGSize(width: 200, height: 200)
                Task { @MainActor in
                    let thumbnail = self.resizeImage(image, to: targetSize)
                    continuation.resume(returning: thumbnail)
                }
            }
        }
    }
    
    private func generatePDFThumbnail(from data: Data) async throws -> PlatformImage? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                guard let pdfDocument = PDFDocument(data: data),
                      let firstPage = pdfDocument.page(at: 0) else {
                    continuation.resume(returning: nil)
                    return
                }
                
                let pageRect = firstPage.bounds(for: .mediaBox)
                let targetSize = CGSize(width: 200, height: 200 * pageRect.height / pageRect.width)
                
                #if os(macOS)
                let image = NSImage(size: targetSize)
                image.lockFocus()
                let context = NSGraphicsContext.current?.cgContext
                context?.scaleBy(x: targetSize.width / pageRect.width, y: targetSize.height / pageRect.height)
                firstPage.draw(with: .mediaBox, to: context!)
                image.unlockFocus()
                continuation.resume(returning: image)
                #else
                let renderer = UIGraphicsImageRenderer(size: targetSize)
                let image = renderer.image { context in
                    UIColor.white.set()
                    context.fill(CGRect(origin: .zero, size: targetSize))
                    
                    context.cgContext.scaleBy(x: targetSize.width / pageRect.width, y: targetSize.height / pageRect.height)
                    firstPage.draw(with: .mediaBox, to: context.cgContext)
                }
                continuation.resume(returning: image)
                #endif
            }
        }
    }
    
    private func performOCRProcessing(data: Data, fileType: UTType) async throws -> String? {
        // 创建临时Manual对象进行OCR处理
        let tempContext = PersistenceController.shared.newBackgroundContext()
        let tempManual = Manual(context: tempContext)
        tempManual.fileData = data
        tempManual.fileType = fileType.preferredFilenameExtension ?? "unknown"
        
        return try await withCheckedThrowingContinuation { continuation in
            Task { @MainActor in
                tempManual.performOCR { success in
                    if success {
                        continuation.resume(returning: tempManual.content)
                    } else {
                        continuation.resume(throwing: FileProcessingError.ocrProcessingFailed)
                    }
                }
            }
        }
    }
    
    private func resizeImage(_ image: PlatformImage, to targetSize: CGSize) -> PlatformImage {
        #if os(macOS)
        let newImage = NSImage(size: targetSize)
        newImage.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: targetSize))
        newImage.unlockFocus()
        return newImage
        #else
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        #endif
    }
    
    private func updateProgress(_ progress: Float) async {
        await MainActor.run {
            self.processingProgress = progress
        }
    }
    
    // MARK: - 批量处理
    func processBatchFiles(
        urls: [URL],
        for product: Product? = nil,
        options: ProcessingOptions = .default,
        progressCallback: @escaping (Int, Int) -> Void
    ) async throws -> [URL: Result<ProcessingResult, Error>] {
        
        var results: [URL: Result<ProcessingResult, Error>] = [:]
        
        for (index, url) in urls.enumerated() {
            do {
                let result = try await processFile(from: url, for: product, options: options)
                results[url] = .success(result)
            } catch {
                results[url] = .failure(error)
            }
            
            await MainActor.run {
                progressCallback(index + 1, urls.count)
            }
        }
        
        return results
    }
}

// MARK: - 图像压缩服务
class ImageCompressionService {
    
    func compressImage(data: Data, quality: Float) async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                guard let image = PlatformImage(data: data) else {
                    continuation.resume(throwing: FileProcessingError.invalidImageData)
                    return
                }
                
                #if os(macOS)
                guard let tiffData = image.tiffRepresentation,
                      let bitmap = NSBitmapImageRep(data: tiffData),
                      let compressedData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: quality]) else {
                    continuation.resume(throwing: FileProcessingError.compressionFailed)
                    return
                }
                continuation.resume(returning: compressedData)
                #else
                guard let compressedData = image.jpegData(compressionQuality: CGFloat(quality)) else {
                    continuation.resume(throwing: FileProcessingError.compressionFailed)
                    return
                }
                continuation.resume(returning: compressedData)
                #endif
            }
        }
    }
    
    func compressPDF(data: Data, quality: Float) async throws -> Data {
        // PDF压缩通常涉及重新编码图像内容
        // 这里返回原数据，实际应用中可以使用PDF压缩库
        return data
    }
}

// MARK: - 文件验证服务
class FileValidationService {
    
    func validateFile(at url: URL, options: FileProcessingService.ProcessingOptions) throws {
        // 检查文件是否存在
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw FileProcessingError.fileNotFound
        }
        
        // 检查文件大小
        let fileSize = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? UInt64 ?? 0
        let fileSizeMB = Int(fileSize / 1024 / 1024)
        
        guard fileSizeMB <= options.maxFileSize else {
            throw FileProcessingError.fileTooLarge(maxSize: options.maxFileSize, actualSize: fileSizeMB)
        }
        
        // 检查文件类型
        let fileType = UTType(filenameExtension: url.pathExtension) ?? .data
        guard isValidFileType(fileType) else {
            throw FileProcessingError.unsupportedFileType(url.pathExtension)
        }
    }
    
    private func isValidFileType(_ type: UTType) -> Bool {
        return type.conforms(to: .pdf) || 
               type.conforms(to: .image) ||
               type.conforms(to: .text) ||
               type.conforms(to: .rtf)
    }
}

// MARK: - 文件元数据提取器
class FileMetadataExtractor {
    
    func extractMetadata(from url: URL, data: Data) async throws -> FileProcessingService.FileMetadata {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let fileType = UTType(filenameExtension: url.pathExtension) ?? .data
        
        var imageProperties: FileProcessingService.FileMetadata.ImageProperties?
        var pdfProperties: FileProcessingService.FileMetadata.PDFProperties?
        
        if fileType.conforms(to: .image) {
            imageProperties = try await extractImageProperties(from: data)
        } else if fileType.conforms(to: .pdf) {
            pdfProperties = try await extractPDFProperties(from: data)
        }
        
        return FileProcessingService.FileMetadata(
            fileName: url.lastPathComponent,
            fileExtension: url.pathExtension,
            mimeType: fileType.preferredMIMEType ?? "application/octet-stream",
            creationDate: attributes[.creationDate] as? Date,
            modificationDate: attributes[.modificationDate] as? Date,
            fileSize: data.count,
            imageProperties: imageProperties,
            pdfProperties: pdfProperties
        )
    }
    
    private func extractImageProperties(from data: Data) async throws -> FileProcessingService.FileMetadata.ImageProperties? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil),
                      let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] else {
                    continuation.resume(returning: nil)
                    return
                }
                
                let width = properties[kCGImagePropertyPixelWidth as String] as? Int ?? 0
                let height = properties[kCGImagePropertyPixelHeight as String] as? Int ?? 0
                let colorSpace = properties[kCGImagePropertyColorModel as String] as? String
                let dpi = properties[kCGImagePropertyDPIWidth as String] as? Float
                let hasAlpha = properties[kCGImagePropertyHasAlpha as String] as? Bool ?? false
                
                let imageProps = FileProcessingService.FileMetadata.ImageProperties(
                    width: width,
                    height: height,
                    colorSpace: colorSpace,
                    dpi: dpi,
                    hasAlpha: hasAlpha
                )
                
                continuation.resume(returning: imageProps)
            }
        }
    }
    
    private func extractPDFProperties(from data: Data) async throws -> FileProcessingService.FileMetadata.PDFProperties? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                guard let pdfDocument = PDFDocument(data: data) else {
                    continuation.resume(returning: nil)
                    return
                }
                
                let pdfProps = FileProcessingService.FileMetadata.PDFProperties(
                    pageCount: pdfDocument.pageCount,
                    title: pdfDocument.documentAttributes?[PDFDocumentAttribute.titleAttribute] as? String,
                    author: pdfDocument.documentAttributes?[PDFDocumentAttribute.authorAttribute] as? String,
                    subject: pdfDocument.documentAttributes?[PDFDocumentAttribute.subjectAttribute] as? String,
                    creator: pdfDocument.documentAttributes?[PDFDocumentAttribute.creatorAttribute] as? String,
                    isEncrypted: pdfDocument.isEncrypted
                )
                
                continuation.resume(returning: pdfProps)
            }
        }
    }
}

// MARK: - 文件处理错误
enum FileProcessingError: LocalizedError {
    case fileNotFound
    case fileTooLarge(maxSize: Int, actualSize: Int)
    case unsupportedFileType(String)
    case invalidImageData
    case compressionFailed
    case metadataExtractionFailed
    case ocrProcessingFailed
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "文件不存在"
        case .fileTooLarge(let maxSize, let actualSize):
            return "文件过大：\(actualSize)MB，最大允许：\(maxSize)MB"
        case .unsupportedFileType(let type):
            return "不支持的文件类型：\(type)"
        case .invalidImageData:
            return "无效的图像数据"
        case .compressionFailed:
            return "文件压缩失败"
        case .metadataExtractionFailed:
            return "元数据提取失败"
        case .ocrProcessingFailed:
            return "OCR处理失败"
        }
    }
}
