import Foundation
import UniformTypeIdentifiers
import PDFKit
import ImageIO
import CoreImage
import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

// MARK: - 文件处理结果
struct FileProcessingResult {
    let originalFileSize: Int64
    let processedFileSize: Int64
    let compressionRatio: Double
    let processedFileURL: URL
    let thumbnailURL: URL?
    let extractedText: String?
    let metadata: [String: Any]
    let processingTime: TimeInterval
    
    init(
        originalFileSize: Int64,
        processedFileSize: Int64,
        processedFileURL: URL,
        thumbnailURL: URL? = nil,
        extractedText: String? = nil,
        metadata: [String: Any] = [:],
        processingTime: TimeInterval
    ) {
        self.originalFileSize = originalFileSize
        self.processedFileSize = processedFileSize
        self.compressionRatio = processedFileSize > 0 ? Double(processedFileSize) / Double(originalFileSize) : 1.0
        self.processedFileURL = processedFileURL
        self.thumbnailURL = thumbnailURL
        self.extractedText = extractedText
        self.metadata = metadata
        self.processingTime = processingTime
    }
}

// MARK: - 文件处理任务
struct FileProcessingTask: Identifiable {
    let id = UUID()
    let url: URL
    let product: Product?
    let options: FileProcessingOptions
    let startTime: Date
    var progress: Float = 0.0
    var isCompleted: Bool = false
    var result: FileProcessingResult?
    var error: Error?
}

// MARK: - 文件处理器
@MainActor
class FileProcessor: ObservableObject {
    @Published var isProcessing = false
    @Published var processingProgress: Float = 0.0
    @Published var activeTasks: [FileProcessingTask] = []
    
    private var cancellationTokens: [UUID: Bool] = [:]
    
    init() {}
    
    // MARK: - 主要处理方法
    func processFile(
        from url: URL,
        for product: Product? = nil,
        options: FileProcessingOptions = .default
    ) async throws -> FileProcessingResult {
        let startTime = Date()
        let taskId = UUID()
        
        // 创建处理任务
        let task = FileProcessingTask(
            url: url,
            product: product,
            options: options,
            startTime: startTime
        )
        
        activeTasks.append(task)
        isProcessing = true
        
        defer {
            activeTasks.removeAll { $0.id == task.id }
            if activeTasks.isEmpty {
                isProcessing = false
                processingProgress = 0.0
            }
            cancellationTokens.removeValue(forKey: taskId)
        }
        
        do {
            // 检查文件是否存在
            guard FileManager.default.fileExists(atPath: url.path) else {
                throw FileProcessingError.fileNotFound
            }
            
            // 获取文件大小
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let originalFileSize = fileAttributes[.size] as? Int64 ?? 0
            
            // 检查文件大小限制
            let maxSizeBytes = Int64(options.maxFileSize * 1024 * 1024)
            if originalFileSize > maxSizeBytes {
                throw FileProcessingError.fileTooLarge(
                    maxSize: options.maxFileSize,
                    actualSize: Int(originalFileSize / 1024 / 1024)
                )
            }
            
            // 检查是否被取消
            if cancellationTokens[taskId] == true {
                throw CancellationError()
            }
            
            updateProgress(0.1, for: taskId)
            
            // 确定文件类型
            let fileType = try determineFileType(url: url)
            
            updateProgress(0.2, for: taskId)
            
            // 创建输出目录
            let outputDirectory = createOutputDirectory()
            let processedFileURL = outputDirectory.appendingPathComponent(url.lastPathComponent)
            
            updateProgress(0.3, for: taskId)
            
            // 处理文件
            var processedFileSize = originalFileSize
            var thumbnailURL: URL?
            var extractedText: String?
            var metadata: [String: Any] = [:]
            
            // 复制原文件到输出目录
            try FileManager.default.copyItem(at: url, to: processedFileURL)
            
            updateProgress(0.5, for: taskId)
            
            // 根据文件类型进行特定处理
            switch fileType {
            case .image:
                if options.shouldCompress {
                    processedFileSize = try await compressImage(at: processedFileURL, quality: options.compressionQuality)
                }
                if options.shouldGenerateThumbnail {
                    thumbnailURL = try generateImageThumbnail(from: processedFileURL)
                }
                if options.shouldExtractMetadata {
                    metadata = extractImageMetadata(from: processedFileURL)
                }
                
            case .pdf:
                if options.shouldPerformOCR {
                    extractedText = try await extractTextFromPDF(at: processedFileURL)
                }
                if options.shouldGenerateThumbnail {
                    thumbnailURL = try generatePDFThumbnail(from: processedFileURL)
                }
                if options.shouldExtractMetadata {
                    metadata = extractPDFMetadata(from: processedFileURL)
                }
                
            case .document:
                if options.shouldPerformOCR {
                    extractedText = try await extractTextFromDocument(at: processedFileURL)
                }
                if options.shouldExtractMetadata {
                    metadata = extractDocumentMetadata(from: processedFileURL)
                }
            }
            
            updateProgress(0.9, for: taskId)
            
            // 检查是否被取消
            if cancellationTokens[taskId] == true {
                // 清理已创建的文件
                try? FileManager.default.removeItem(at: processedFileURL)
                if let thumbnailURL = thumbnailURL {
                    try? FileManager.default.removeItem(at: thumbnailURL)
                }
                throw CancellationError()
            }
            
            updateProgress(1.0, for: taskId)
            
            let processingTime = Date().timeIntervalSince(startTime)
            
            return FileProcessingResult(
                originalFileSize: originalFileSize,
                processedFileSize: processedFileSize,
                processedFileURL: processedFileURL,
                thumbnailURL: thumbnailURL,
                extractedText: extractedText,
                metadata: metadata,
                processingTime: processingTime
            )
            
        } catch {
            // 更新任务状态
            if let index = activeTasks.firstIndex(where: { $0.id == task.id }) {
                activeTasks[index].error = error
            }
            throw error
        }
    }
    
    // MARK: - 批量处理
    func processBatchFiles(
        urls: [URL],
        for product: Product? = nil,
        options: FileProcessingOptions = .default,
        progressCallback: @escaping (Int, Int) -> Void
    ) async throws -> [URL: Result<FileProcessingResult, Error>] {
        var results: [URL: Result<FileProcessingResult, Error>] = [:]
        
        for (index, url) in urls.enumerated() {
            do {
                let result = try await processFile(from: url, for: product, options: options)
                results[url] = .success(result)
            } catch {
                results[url] = .failure(error)
            }
            
            progressCallback(index + 1, urls.count)
        }
        
        return results
    }
    
    // MARK: - 取消操作
    func cancelProcessing(for taskId: UUID) {
        cancellationTokens[taskId] = true
    }
    
    func cancelAllProcessing() {
        for task in activeTasks {
            cancellationTokens[task.id] = true
        }
    }
    
    // MARK: - 私有方法
    private func updateProgress(_ progress: Float, for taskId: UUID) {
        if let index = activeTasks.firstIndex(where: { $0.id == taskId }) {
            activeTasks[index].progress = progress
        }
        
        // 计算总体进度
        let totalProgress = activeTasks.reduce(0.0) { $0 + $1.progress } / Float(max(activeTasks.count, 1))
        processingProgress = totalProgress
    }
    
    private func determineFileType(url: URL) throws -> FileType {
        let pathExtension = url.pathExtension.lowercased()
        
        switch pathExtension {
        case "jpg", "jpeg", "png", "gif", "bmp", "tiff", "heic":
            return .image
        case "pdf":
            return .pdf
        case "doc", "docx", "txt", "rtf":
            return .document
        default:
            throw FileProcessingError.unsupportedFileType(pathExtension)
        }
    }
    
    private func createOutputDirectory() -> URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let outputDirectory = documentsDirectory.appendingPathComponent("ProcessedFiles")
        
        try? FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        
        return outputDirectory
    }
    
    // MARK: - 图片处理
    private func compressImage(at url: URL, quality: Float) async throws -> Int64 {
        guard let imageData = try? Data(contentsOf: url),
              let image = UIImage(data: imageData) else {
            throw FileProcessingError.invalidImageData
        }
        
        guard let compressedData = image.jpegData(compressionQuality: CGFloat(quality)) else {
            throw FileProcessingError.compressionFailed
        }
        
        try compressedData.write(to: url)
        return Int64(compressedData.count)
    }
    
    private func generateImageThumbnail(from url: URL) throws -> URL {
        guard let imageData = try? Data(contentsOf: url) else {
            throw FileProcessingError.invalidImageData
        }
        
        #if os(macOS)
        guard let image = NSImage(data: imageData) else {
            throw FileProcessingError.invalidImageData
        }
        #else
        guard let image = UIImage(data: imageData) else {
            throw FileProcessingError.invalidImageData
        }
        #endif
        
        let thumbnailSize = CGSize(width: 200, height: 200)
        let thumbnail = image.resized(to: thumbnailSize)
        
        let thumbnailURL = url.appendingPathExtension("thumbnail.jpg")
        
        guard let thumbnailData = thumbnail.jpegData(compressionQuality: 0.8) else {
            throw FileProcessingError.compressionFailed
        }
        
        try thumbnailData.write(to: thumbnailURL)
        return thumbnailURL
    }
    
    private func extractImageMetadata(from url: URL) -> [String: Any] {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
              let metadata = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] else {
            return [:]
        }
        
        return metadata
    }
    
    // MARK: - PDF处理
    private func extractTextFromPDF(at url: URL) async throws -> String {
        guard let pdfDocument = PDFDocument(url: url) else {
            throw FileProcessingError.ocrProcessingFailed
        }
        
        var extractedText = ""
        
        for pageIndex in 0..<pdfDocument.pageCount {
            if let page = pdfDocument.page(at: pageIndex) {
                extractedText += page.string ?? ""
                extractedText += "\n"
            }
        }
        
        return extractedText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func generatePDFThumbnail(from url: URL) throws -> URL {
        guard let pdfDocument = PDFDocument(url: url),
              let firstPage = pdfDocument.page(at: 0) else {
            throw FileProcessingError.invalidImageData
        }
        
        let thumbnailSize = CGSize(width: 200, height: 200)
        let thumbnail = firstPage.thumbnail(of: thumbnailSize, for: .cropBox)
        
        let thumbnailURL = url.appendingPathExtension("thumbnail.jpg")
        
        guard let thumbnailData = thumbnail.jpegData(compressionQuality: 0.8) else {
            throw FileProcessingError.compressionFailed
        }
        
        try thumbnailData.write(to: thumbnailURL)
        return thumbnailURL
    }
    
    private func extractPDFMetadata(from url: URL) -> [String: Any] {
        guard let pdfDocument = PDFDocument(url: url) else {
            return [:]
        }
        
        var metadata: [String: Any] = [:]
        
        if let documentAttributes = pdfDocument.documentAttributes {
            metadata = documentAttributes
        }
        
        metadata["pageCount"] = pdfDocument.pageCount
        
        return metadata
    }
    
    // MARK: - 文档处理
    private func extractTextFromDocument(at url: URL) async throws -> String {
        // 简单的文本提取实现
        guard let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8) else {
            throw FileProcessingError.ocrProcessingFailed
        }
        
        return text
    }
    
    private func extractDocumentMetadata(from url: URL) -> [String: Any] {
        var metadata: [String: Any] = [:]
        
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            metadata["fileSize"] = attributes[.size]
            metadata["creationDate"] = attributes[.creationDate]
            metadata["modificationDate"] = attributes[.modificationDate]
        } catch {
            // 忽略错误
        }
        
        return metadata
    }
}

// MARK: - 文件类型
enum FileType {
    case image
    case pdf
    case document
}

// MARK: - 平台图像扩展
#if os(macOS)
extension NSImage {
    func resized(to size: CGSize) -> NSImage {
        let newImage = NSImage(size: size)
        newImage.lockFocus()
        self.draw(in: NSRect(origin: .zero, size: size))
        newImage.unlockFocus()
        return newImage
    }
}
#else
extension UIImage {
    func resized(to size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
#endif

// MARK: - PDFPage扩展
extension PDFPage {
    func jpegData(compressionQuality: CGFloat) -> Data? {
        let bounds = self.bounds(for: .mediaBox)
        let renderer = UIGraphicsImageRenderer(size: bounds.size)
        
        let image = renderer.image { context in
            UIColor.white.set()
            context.fill(bounds)
            
            context.cgContext.translateBy(x: 0, y: bounds.size.height)
            context.cgContext.scaleBy(x: 1.0, y: -1.0)
            
            self.draw(with: .mediaBox, to: context.cgContext)
        }
        
        return image.jpegData(compressionQuality: compressionQuality)
    }
}