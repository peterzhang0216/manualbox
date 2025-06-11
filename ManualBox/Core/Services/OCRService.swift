import Foundation
@preconcurrency import Vision
@preconcurrency import CoreData
#if os(macOS)
@preconcurrency import AppKit
#endif
import PDFKit
import SwiftUI
import NaturalLanguage  // 添加Natural Language框架导入

// MARK: - OCR结果结构
struct OCRResult: Sendable {
    let text: String
    let confidence: Float
    let boundingBoxes: [VNRecognizedTextObservation]
    let processingTime: TimeInterval
    let languageDetected: String?
}

// MARK: - OCR配置
struct OCRConfiguration: Sendable {
    let recognitionLevel: VNRequestTextRecognitionLevel
    let languages: [String]
    let usesLanguageCorrection: Bool
    let minimumTextHeight: Float
    let customWords: [String]
    let progressCallback: (@Sendable (Float) -> Void)?
    
    static let `default` = OCRConfiguration(
        recognitionLevel: .accurate,
        languages: ["zh-Hans", "zh-Hant", "en-US", "ja-JP"],
        usesLanguageCorrection: true,
        minimumTextHeight: 0.02,
        customWords: [],
        progressCallback: nil
    )
    
    static let fast = OCRConfiguration(
        recognitionLevel: .fast,
        languages: ["zh-Hans", "en-US"],
        usesLanguageCorrection: false,
        minimumTextHeight: 0.03,
        customWords: [],
        progressCallback: nil
    )
}

// MARK: - 增强版OCR服务
@MainActor
class OCRService: ObservableObject {
    static let shared = OCRService()
    
    @Published var isProcessing = false
    @Published var currentProgress: Float = 0.0
    @Published var processingQueue: [UUID] = []
    
    private let imagePreprocessor = ImagePreprocessor()
    private let textPostprocessor = TextPostprocessor()
    private var activeRequests: [UUID: VNImageRequestHandler] = [:]
    
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
    
    private func getOptimizedImage(from manual: Manual) async -> PlatformImage? {
        return await withCheckedContinuation { continuation in
            // 创建manual的本地副本以避免Sendable问题
            let manualObjectID = manual.objectID
            let context = manual.managedObjectContext
            
            DispatchQueue.global(qos: .userInitiated).async { [context] in
                var image: PlatformImage?
                
                // 在后台上下文中安全访问Core Data对象
                context?.perform {
                    if let bgManual = try? context?.existingObject(with: manualObjectID) as? Manual {
                        image = bgManual.getPreviewImage()
                    }
                    continuation.resume(returning: image)
                }
            }
        }
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
                
                let textResults = observations.compactMap { observation -> (String, Float) in
                    guard let candidate = observation.topCandidates(1).first else { return ("", 0.0) }
                    return (candidate.string, candidate.confidence)
                }
                
                let fullText = textResults.map { $0.0 }.joined(separator: "\n")
                let averageConfidence = textResults.isEmpty ? 0.0 : textResults.map { $0.1 }.reduce(0, +) / Float(textResults.count)
                
                continuation.resume(returning: (
                    text: fullText,
                    confidence: averageConfidence,
                    boundingBoxes: observations
                ))
            }
            
            // 配置OCR请求
            request.recognitionLevel = configuration.recognitionLevel
            request.usesLanguageCorrection = configuration.usesLanguageCorrection
            request.minimumTextHeight = configuration.minimumTextHeight
            
            if #available(iOS 14.0, macOS 11.0, *) {
                request.recognitionLanguages = configuration.languages
            }
            
            if #available(iOS 15.0, macOS 12.0, *), !configuration.customWords.isEmpty {
                request.customWords = configuration.customWords
            }
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            self.activeRequests[requestId] = handler
            
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: OCRError.processingFailed(error.localizedDescription))
                }
                
                Task { @MainActor in
                    self.activeRequests.removeValue(forKey: requestId)
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

// MARK: - OCR错误类型
enum OCRError: LocalizedError {
    case imageExtractionFailed
    case imageProcessingFailed
    case visionError(String)
    case noTextFound
    case processingFailed(String)
    case queueFull
    
    var errorDescription: String? {
        switch self {
        case .imageExtractionFailed:
            return "无法从文件中提取图像"
        case .imageProcessingFailed:
            return "图像处理失败"
        case .visionError(let message):
            return "视觉识别错误: \(message)"
        case .noTextFound:
            return "未检测到文本内容"
        case .processingFailed(let message):
            return "处理失败: \(message)"
        case .queueFull:
            return "处理队列已满，请稍后重试"
        }
    }
}

// MARK: - 图像预处理器
class ImagePreprocessor: @unchecked Sendable {
    func enhance(_ image: PlatformImage) async -> PlatformImage {
        return await withCheckedContinuation { continuation in
            // 在主线程上创建图像副本
            Task { @MainActor in
                let imageCopy = image
                Task.detached {
                    // 图像增强处理
                    let enhancedImage = await self.applyImageEnhancements(imageCopy)
                    continuation.resume(returning: enhancedImage)
                }
            }
        }
    }
    
    private func applyImageEnhancements(_ image: PlatformImage) async -> PlatformImage {
        // 应用图像增强算法
        // 1. 对比度增强
        // 2. 噪声减少
        // 3. 锐化处理
        // 4. 二值化（如果需要）
        
        // 这里先返回原图，实际可以实现更复杂的图像处理
        return image
    }
}

// MARK: - 文本后处理器
class TextPostprocessor {
    func enhance(_ text: String) -> String {
        var processedText = text
        
        // 1. 去除多余的空白字符
        processedText = processedText.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        
        // 2. 修正常见的OCR错误
        processedText = correctCommonOCRErrors(processedText)
        
        // 3. 格式化换行
        processedText = formatLineBreaks(processedText)
        
        return processedText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func correctCommonOCRErrors(_ text: String) -> String {
        var correctedText = text
        
        // 常见OCR错误修正规则
        let corrections: [(String, String)] = [
            ("O", "0"), // 字母O误识别为数字0的情况
            ("l", "1"), // 字母l误识别为数字1的情况
            ("｜", "|"), // 全角符号修正
            ("．", "."), // 全角句号修正
            ("，", ","), // 中文逗号保持
        ]
        
        for (wrong, correct) in corrections {
            // 在特定上下文中应用修正
            correctedText = applyCorrectionInContext(correctedText, wrong: wrong, correct: correct)
        }
        
        return correctedText
    }
    
    private func applyCorrectionInContext(_ text: String, wrong: String, correct: String) -> String {
        // 在数字上下文中的修正
        let numberPattern = "\\d+[" + NSRegularExpression.escapedPattern(for: wrong) + "]\\d*|\\d*[" + NSRegularExpression.escapedPattern(for: wrong) + "]\\d+"
        
        do {
            let regex = try NSRegularExpression(pattern: numberPattern, options: [])
            let range = NSRange(location: 0, length: text.utf16.count)
            
            _ = regex.stringByReplacingMatches(
                in: text,
                options: [],
                range: range,
                withTemplate: ""
            )
            
            // 手动处理每个匹配项
            var correctedText = text
            let matches = regex.matches(in: text, options: [], range: range)
            
            // 从后往前替换以避免索引偏移问题
            for match in matches.reversed() {
                if let range = Range(match.range, in: text) {
                    let matchString = String(text[range])
                    let correctedMatch = matchString.replacingOccurrences(of: wrong, with: correct)
                    correctedText = correctedText.replacingCharacters(in: range, with: correctedMatch)
                }
            }
            
            return correctedText
        } catch {
            // 如果正则表达式失败，返回原文本
            return text
        }
    }
    
    private func formatLineBreaks(_ text: String) -> String {
        // 智能换行处理
        return text.replacingOccurrences(of: "(?<=[。！？])\n(?=[A-Za-z0-9\\u4e00-\\u9fff])", with: "\n\n", options: .regularExpression)
    }
}