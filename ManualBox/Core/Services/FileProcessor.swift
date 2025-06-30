import Foundation
import UniformTypeIdentifiers
import SwiftUI
import PDFKit

// MARK: - 文件处理协调器
/// 负责协调文件处理流程，管理各个处理组件
@MainActor
class FileProcessor: ObservableObject {
    
    @Published var isProcessing = false
    @Published var processingProgress: Float = 0.0
    @Published var processingQueue: [FileProcessingTask] = []
    
    // 专门的处理组件
    private let validator: FileValidator
    private let metadataExtractor: FileMetadataExtractor
    private let compressionService: ImageCompressionService
    
    init() {
        self.validator = FileValidator()
        self.metadataExtractor = FileMetadataExtractor()
        self.compressionService = ImageCompressionService()
    }
    
    // MARK: - 主要处理方法
    
    /// 协调文件处理流程
    func processFile(
        from url: URL,
        for product: Product? = nil,
        options: FileProcessingOptions = .default
    ) async throws -> FileProcessingResult {
        
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
        
        return try await coordinateFileProcessing(task: task)
    }
    
    /// 批量文件处理
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
            
            await MainActor.run {
                progressCallback(index + 1, urls.count)
            }
        }
        
        return results
    }
    
    // MARK: - 私有协调方法
    
    private func coordinateFileProcessing(task: FileProcessingTask) async throws -> FileProcessingResult {
        let startTime = Date()
        
        // 步骤1: 文件验证 (10%)
        await updateProgress(0.1)
        try validator.validateFile(at: task.fileURL, options: task.processingOptions)
        
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
        if task.processingOptions.shouldCompress && (fileType.conforms(to: UTType.image) || fileType.conforms(to: UTType.pdf)) {
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
        if task.processingOptions.shouldPerformOCR {
            ocrText = try await performOCRProcessing(data: processedData, fileType: fileType)
        }
        
        // 步骤7: 完成处理 (100%)
        await updateProgress(1.0)
        
        let processingTime = Date().timeIntervalSince(startTime)
        let compressionRatio = Float(processedData.count) / Float(originalData.count)
        
        return FileProcessingResult(
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
        options: FileProcessingOptions
    ) async throws -> Data {
        if fileType.conforms(to: UTType.image) {
            return try await compressionService.compressImage(data: data, quality: options.compressionQuality)
        } else if fileType.conforms(to: UTType.pdf) {
            return try await compressionService.compressPDF(data: data, quality: options.compressionQuality)
        }
        return data
    }
    
    private func generateThumbnail(from data: Data, fileType: UTType) async throws -> PlatformImage? {
        if fileType.conforms(to: UTType.image) {
            return try await generateImageThumbnail(from: data)
        } else if fileType.conforms(to: UTType.pdf) {
            return try await generatePDFThumbnail(from: data)
        }
        return nil
    }
    
    private func generateImageThumbnail(from data: Data) async throws -> PlatformImage? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                #if os(macOS)
                guard let image = NSImage(data: data) else {
                    continuation.resume(returning: nil)
                    return
                }
                
                let thumbnailSize = NSSize(width: 200, height: 200)
                let thumbnail = NSImage(size: thumbnailSize)
                thumbnail.lockFocus()
                image.draw(in: NSRect(origin: .zero, size: thumbnailSize))
                thumbnail.unlockFocus()
                
                continuation.resume(returning: thumbnail)
                #else
                guard let image = UIImage(data: data) else {
                    continuation.resume(returning: nil)
                    return
                }
                
                let thumbnailSize = CGSize(width: 200, height: 200)
                UIGraphicsBeginImageContextWithOptions(thumbnailSize, false, 0.0)
                image.draw(in: CGRect(origin: .zero, size: thumbnailSize))
                let thumbnail = UIGraphicsGetImageFromCurrentImageContext()
                UIGraphicsEndImageContext()
                
                continuation.resume(returning: thumbnail)
                #endif
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
                let thumbnailSize = CGSize(width: 200, height: 200)
                
                #if os(macOS)
                let thumbnail = NSImage(size: thumbnailSize)
                thumbnail.lockFocus()
                
                let context = NSGraphicsContext.current?.cgContext
                context?.scaleBy(x: thumbnailSize.width / pageRect.width, 
                                y: thumbnailSize.height / pageRect.height)
                firstPage.draw(with: .mediaBox, to: context!)
                
                thumbnail.unlockFocus()
                continuation.resume(returning: thumbnail)
                #else
                UIGraphicsBeginImageContextWithOptions(thumbnailSize, false, 0.0)
                let context = UIGraphicsGetCurrentContext()!
                
                context.scaleBy(x: thumbnailSize.width / pageRect.width, 
                               y: thumbnailSize.height / pageRect.height)
                firstPage.draw(with: .mediaBox, to: context)
                
                let thumbnail = UIGraphicsGetImageFromCurrentImageContext()
                UIGraphicsEndImageContext()
                continuation.resume(returning: thumbnail)
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
    
    // MARK: - 辅助方法
    
    private func updateProgress(_ progress: Float) async {
        await MainActor.run {
            self.processingProgress = progress
        }
    }
    
    // MARK: - 队列管理
    
    func cancelProcessing(for taskId: UUID) {
        processingQueue.removeAll { $0.id == taskId }
        if processingQueue.isEmpty {
            isProcessing = false
            processingProgress = 0.0
        }
    }
    
    func cancelAllProcessing() {
        processingQueue.removeAll()
        isProcessing = false
        processingProgress = 0.0
    }
}
