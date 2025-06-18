import Foundation
@preconcurrency import Vision
@preconcurrency import CoreData
#if os(macOS)
@preconcurrency import AppKit
#endif
import PDFKit
import SwiftUI
import NaturalLanguage

// MARK: - 增强版OCR服务
@MainActor
class OCRService: ObservableObject {
    static let shared = OCRService()
    
    @Published var isProcessing = false
    @Published var currentProgress: Float = 0.0
    @Published var processingQueue: [UUID] = []
    
    private let imagePreprocessor = ImagePreprocessor()
    private let textPostprocessor = TextPostprocessor()
    var activeRequests: [UUID: VNImageRequestHandler] = [:]
    
    private init() {}
    
    // MARK: - 主要OCR方法
    func performOCR(
        on manual: Manual,
        configuration: OCRConfiguration = .default,
        completion: @escaping (Result<OCRResult, OCRError>) -> Void
    ) {
        guard !isProcessing || processingQueue.count < 3 else {
            completion(.failure(.queueFull))
            return
        }
        
        let requestId = UUID()
        processingQueue.append(requestId)
        
        Task {
            do {
                let result = try await processManual(manual, configuration: configuration, requestId: requestId)
                await MainActor.run {
                    self.processingQueue.removeAll { $0 == requestId }
                    completion(.success(result))
                }
            } catch let error as OCRError {
                await MainActor.run {
                    self.processingQueue.removeAll { $0 == requestId }
                    completion(.failure(error))
                }
            } catch {
                await MainActor.run {
                    self.processingQueue.removeAll { $0 == requestId }
                    completion(.failure(.processingFailed(error.localizedDescription)))
                }
            }
        }
    }
    
    // MARK: - 私有处理方法
    private func processManual(
        _ manual: Manual,
        configuration: OCRConfiguration,
        requestId: UUID
    ) async throws -> OCRResult {
        let startTime = Date()
        
        // 更新处理状态
        await MainActor.run {
            self.isProcessing = true
            self.currentProgress = 0.1
            configuration.progressCallback?(0.1)
        }
        
        // 获取并预处理图像
        guard let originalImage = await getOptimizedImage(from: manual) else {
            throw OCRError.imageExtractionFailed
        }
        
        await MainActor.run {
            self.currentProgress = 0.3
            configuration.progressCallback?(0.3)
        }
        
        // 预处理图像以提高OCR准确性
        let preprocessedImage = await imagePreprocessor.enhance(originalImage)
        
        await MainActor.run {
            self.currentProgress = 0.4
            configuration.progressCallback?(0.4)
        }
        
        // 执行OCR识别
        let ocrResult = try await performVisionOCR(
            on: preprocessedImage,
            configuration: configuration,
            requestId: requestId
        )
        
        await MainActor.run {
            self.currentProgress = 0.8
            configuration.progressCallback?(0.8)
        }
        
        // 后处理文本
        let processedText = textPostprocessor.enhance(ocrResult.text)
        
        await MainActor.run {
            self.currentProgress = 1.0
            configuration.progressCallback?(1.0)
            self.isProcessing = false
        }
        
        let processingTime = Date().timeIntervalSince(startTime)
        
        return OCRResult(
            text: processedText,
            confidence: ocrResult.confidence,
            boundingBoxes: ocrResult.boundingBoxes,
            processingTime: processingTime,
            languageDetected: detectLanguage(from: processedText)
        )
    }
    
    // MARK: - 批量处理
    func batchProcessManuals(
        _ manuals: [Manual],
        configuration: OCRConfiguration = .default,
        progressCallback: @escaping @Sendable (Int, Int, Manual?) -> Void,
        completion: @escaping @Sendable ([Manual: Result<OCRResult, OCRError>]) -> Void
    ) {
        Task {
            var results: [Manual: Result<OCRResult, OCRError>] = [:]
            
            for (index, manual) in manuals.enumerated() {
                let result = await withCheckedContinuation { (continuation: CheckedContinuation<Result<OCRResult, OCRError>, Never>) in
                    Task { @MainActor in
                        self.performOCR(on: manual, configuration: configuration) { result in
                            continuation.resume(returning: result)
                        }
                    }
                }
                
                results[manual] = result
                
                await MainActor.run {
                    progressCallback(index + 1, manuals.count, manual)
                }
            }
            
            await MainActor.run {
                completion(results)
            }
        }
    }
    
    // MARK: - 取消处理
    func cancelProcessing(for requestId: UUID) {
        processingQueue.removeAll { $0 == requestId }
        activeRequests.removeValue(forKey: requestId)
    }
    
    func cancelAllProcessing() {
        processingQueue.removeAll()
        activeRequests.removeAll()
        isProcessing = false
        currentProgress = 0.0
    }
} 