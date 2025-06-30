import Foundation
@preconcurrency import Vision
@preconcurrency import CoreData
import SwiftUI
import NaturalLanguage

// MARK: - OCR协调器
/// 负责协调OCR处理流程，管理队列和状态
@MainActor
class OCRCoordinator: ObservableObject {
    
    // MARK: - 队列管理
    private var activeRequests: [UUID: VNImageRequestHandler] = [:]
    private let processingQueue = DispatchQueue(label: "com.manualbox.ocr.coordinator", qos: .userInitiated)
    
    // MARK: - 主要协调方法
    
    /// 协调OCR处理流程
    func coordinateOCR(
        on manual: Manual,
        configuration: OCRConfiguration = .default,
        imageProcessor: OCRImageProcessor,
        textProcessor: OCRTextProcessor,
        performanceMonitor: OCRPerformanceMonitor,
        progressCallback: @escaping (Float) -> Void
    ) async throws -> OCRResult {
        
        let startTime = Date()
        let requestId = UUID()
        
        // 步骤1: 图像提取和预处理 (30%)
        progressCallback(0.1)
        guard let image = await getOptimizedImage(from: manual) else {
            throw OCRError.imageExtractionFailed
        }
        
        progressCallback(0.3)
        let preprocessedImage = await imageProcessor.enhance(image)
        
        // 步骤2: OCR识别 (50%)
        progressCallback(0.5)
        let ocrResult = try await performVisionOCR(
            on: preprocessedImage,
            configuration: configuration,
            requestId: requestId
        )
        
        // 步骤3: 文本后处理 (80%)
        progressCallback(0.8)
        let processedText = textProcessor.enhance(ocrResult.text)
        
        // 步骤4: 完成处理 (100%)
        progressCallback(1.0)
        
        let processingTime = Date().timeIntervalSince(startTime)
        
        // 记录性能指标
        await performanceMonitor.recordProcessing(
            duration: processingTime,
            textLength: processedText.count,
            confidence: ocrResult.confidence
        )
        
        return OCRResult(
            text: processedText,
            confidence: ocrResult.confidence,
            boundingBoxes: ocrResult.boundingBoxes,
            processingTime: processingTime,
            languageDetected: detectLanguage(from: processedText)
        )
    }
    
    /// 批量OCR协调
    func coordinateBatchOCR(
        manuals: [Manual],
        configuration: OCRConfiguration = .default,
        imageProcessor: OCRImageProcessor,
        textProcessor: OCRTextProcessor,
        performanceMonitor: OCRPerformanceMonitor,
        progressCallback: @escaping (Int, Int) -> Void
    ) async -> [UUID: Result<OCRResult, OCRError>] {
        
        var results: [UUID: Result<OCRResult, OCRError>] = [:]
        
        for (index, manual) in manuals.enumerated() {
            do {
                let result = try await coordinateOCR(
                    on: manual,
                    configuration: configuration,
                    imageProcessor: imageProcessor,
                    textProcessor: textProcessor,
                    performanceMonitor: performanceMonitor
                ) { _ in }
                
                results[manual.id ?? UUID()] = .success(result)
            } catch {
                let ocrError = error as? OCRError ?? .processingFailed(error.localizedDescription)
                results[manual.id ?? UUID()] = .failure(ocrError)
            }
            
            progressCallback(index + 1, manuals.count)
        }
        
        return results
    }
    
    /// 智能重试协调
    func coordinateOCRWithRetry(
        on manual: Manual,
        maxRetries: Int = 3,
        configuration: OCRConfiguration = .default,
        imageProcessor: OCRImageProcessor,
        textProcessor: OCRTextProcessor,
        performanceMonitor: OCRPerformanceMonitor
    ) async -> Result<OCRResult, OCRError> {
        
        for attempt in 1...maxRetries {
            do {
                let result = try await coordinateOCR(
                    on: manual,
                    configuration: configuration,
                    imageProcessor: imageProcessor,
                    textProcessor: textProcessor,
                    performanceMonitor: performanceMonitor
                ) { _ in }
                
                // 评估质量
                let quality = evaluateOCRQuality(from: result)
                if quality.qualityScore >= 0.3 || attempt == maxRetries {
                    return .success(result)
                }
                
                print("🔄 OCR质量较低 (\(quality.qualityScore)), 进行第 \(attempt + 1) 次重试")
                
            } catch {
                let ocrError = error as? OCRError ?? .processingFailed(error.localizedDescription)
                
                if !shouldRetryForError(ocrError) || attempt == maxRetries {
                    return .failure(ocrError)
                }
                
                print("🔄 OCR失败，进行第 \(attempt + 1) 次重试: \(ocrError.localizedDescription)")
                
                // 延迟重试
                try? await Task.sleep(nanoseconds: UInt64(attempt * 1_000_000_000))
            }
        }
        
        return .failure(.processingFailed("重试次数已用完"))
    }
    
    // MARK: - 私有辅助方法
    
    private func getOptimizedImage(from manual: Manual) async -> PlatformImage? {
        return manual.getPreviewImage()
    }
    
    private func performVisionOCR(
        on image: PlatformImage,
        configuration: OCRConfiguration,
        requestId: UUID
    ) async throws -> (text: String, confidence: Float, boundingBoxes: [VNRecognizedTextObservation]) {
        
        #if os(macOS)
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw OCRError.imageProcessingFailed
        }
        #else
        guard let cgImage = image.cgImage else {
            throw OCRError.imageProcessingFailed
        }
        #endif
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: OCRError.visionError(error.localizedDescription))
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(throwing: OCRError.noTextFound)
                    return
                }
                
                let recognizedStrings = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }
                
                let text = recognizedStrings.joined(separator: "\n")
                let confidence = observations.isEmpty ? 0.0 : 
                    observations.compactMap { $0.topCandidates(1).first?.confidence }.reduce(0, +) / Float(observations.count)
                
                continuation.resume(returning: (text: text, confidence: confidence, boundingBoxes: observations))
            }
            
            request.recognitionLevel = configuration.recognitionLevel
            request.recognitionLanguages = configuration.languages
            request.usesLanguageCorrection = configuration.usesLanguageCorrection
            request.minimumTextHeight = configuration.minimumTextHeight
            request.customWords = configuration.customWords
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            activeRequests[requestId] = handler
            
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: OCRError.processingFailed(error.localizedDescription))
                }
                
                Task { @MainActor [weak self] in
                    self?.activeRequests.removeValue(forKey: requestId)
                }
            }
        }
    }
    
    private func detectLanguage(from text: String) -> String? {
        if #available(iOS 14.0, macOS 11.0, *) {
            let recognizer = NLLanguageRecognizer()
            recognizer.processString(text)
            return recognizer.dominantLanguage?.rawValue
        }
        return nil
    }
    
    private func evaluateOCRQuality(from result: OCRResult) -> OCRQualityMetrics {
        return OCRQualityMetrics(
            confidence: result.confidence,
            textLength: result.text.count,
            wordCount: result.text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count,
            lineCount: result.text.components(separatedBy: .newlines).count,
            detectedLanguage: result.languageDetected,
            processingTime: result.processingTime
        )
    }
    
    private func shouldRetryForError(_ error: OCRError) -> Bool {
        switch error {
        case .networkError, .timeout, .processingFailed:
            return true
        case .queueFull, .insufficientMemory:
            return true
        default:
            return false
        }
    }
}
