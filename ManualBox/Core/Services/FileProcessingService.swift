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
    
    // MARK: - 主要处理方法
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
        
        return try await performFileProcessing(task: task)
    }
    
    // MARK: - 私有处理方法
    private func performFileProcessing(task: FileProcessingTask) async throws -> FileProcessingResult {
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
        if task.processingOptions.shouldPerformOCR && (fileType.conforms(to: UTType.image) || fileType.conforms(to: UTType.pdf)) {
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
} 