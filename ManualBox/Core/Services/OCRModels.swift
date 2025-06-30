//
//  OCRModels.swift
//  ManualBox
//
//  Created by Peter's Mac on 2025/4/27.
//

import Foundation
@preconcurrency import Vision

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

// MARK: - OCR错误类型
enum OCRError: LocalizedError, Equatable {
    case imageExtractionFailed
    case imageProcessingFailed
    case visionError(String)
    case noTextFound
    case processingFailed(String)
    case queueFull
    case networkError
    case insufficientMemory
    case unsupportedFormat
    case timeout

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
        case .networkError:
            return "网络连接错误"
        case .insufficientMemory:
            return "内存不足，请关闭其他应用后重试"
        case .unsupportedFormat:
            return "不支持的文件格式"
        case .timeout:
            return "处理超时，请重试"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .imageExtractionFailed:
            return "请检查文件是否损坏，或尝试重新上传"
        case .imageProcessingFailed:
            return "请尝试使用更清晰的图像"
        case .visionError:
            return "请重试或联系技术支持"
        case .noTextFound:
            return "请确保图像包含清晰的文本内容"
        case .processingFailed:
            return "请重试或检查文件格式"
        case .queueFull:
            return "请等待当前任务完成后重试"
        case .networkError:
            return "请检查网络连接后重试"
        case .insufficientMemory:
            return "请关闭其他应用释放内存"
        case .unsupportedFormat:
            return "请使用支持的图像格式（JPG、PNG、PDF）"
        case .timeout:
            return "请检查图像大小，较大的图像需要更长处理时间"
        }
    }
}

// MARK: - 批量处理进度
struct BatchProgress: Sendable {
    let totalItems: Int
    let completedItems: Int
    let currentItem: String?
    let overallProgress: Float
    let estimatedTimeRemaining: TimeInterval?

    var isCompleted: Bool {
        completedItems >= totalItems
    }

    var progressText: String {
        if let currentItem = currentItem {
            return "正在处理: \(currentItem) (\(completedItems)/\(totalItems))"
        } else {
            return "已完成 \(completedItems)/\(totalItems)"
        }
    }
}

// MARK: - OCR处理统计
struct OCRProcessingStats: Sendable {
    var totalRequests: Int = 0
    var successfulRequests: Int = 0
    var failedRequests: Int = 0
    var averageProcessingTime: TimeInterval = 0.0
    var totalProcessingTime: TimeInterval = 0.0

    // 错误统计
    var totalErrors: Int = 0
    var lastError: OCRError?
    var lastErrorTime: Date?
    var imageExtractionErrors: Int = 0
    var imageProcessingErrors: Int = 0
    var visionErrors: Int = 0
    var noTextFoundErrors: Int = 0
    var processingFailedErrors: Int = 0
    var queueFullErrors: Int = 0
    var networkErrors: Int = 0
    var memoryErrors: Int = 0
    var formatErrors: Int = 0
    var timeoutErrors: Int = 0

    // 批量处理统计
    var totalBatchOperations: Int = 0
    var totalBatchItems: Int = 0
    var successfulBatchItems: Int = 0
    var averageBatchProcessingTime: TimeInterval = 0.0

    // 性能指标
    var averageConfidence: Float = 0.0
    var lastProcessingTime: Date?

    var successRate: Float {
        guard totalRequests > 0 else { return 0.0 }
        return Float(successfulRequests) / Float(totalRequests)
    }

    var failureRate: Float {
        guard totalRequests > 0 else { return 0.0 }
        return Float(failedRequests) / Float(totalRequests)
    }

    mutating func updateAverageProcessingTime(_ newTime: TimeInterval) {
        totalProcessingTime += newTime
        if successfulRequests > 0 {
            averageProcessingTime = totalProcessingTime / Double(successfulRequests)
        }
    }

    mutating func reset() {
        totalRequests = 0
        successfulRequests = 0
        failedRequests = 0
        averageProcessingTime = 0.0
        totalProcessingTime = 0.0
    }
}

// MARK: - OCR质量评估
struct OCRQualityMetrics: Sendable {
    let confidence: Float
    let textLength: Int
    let wordCount: Int
    let lineCount: Int
    let detectedLanguage: String?
    let processingTime: TimeInterval

    var qualityScore: Float {
        var score: Float = 0.0

        // 置信度权重 (40%)
        score += confidence * 0.4

        // 文本长度权重 (20%)
        let lengthScore = min(Float(textLength) / 1000.0, 1.0)
        score += lengthScore * 0.2

        // 处理时间权重 (20%) - 越快越好
        let timeScore = max(0.0, 1.0 - Float(processingTime) / 30.0)
        score += timeScore * 0.2

        // 语言检测权重 (20%)
        let languageScore: Float = detectedLanguage != nil ? 1.0 : 0.5
        score += languageScore * 0.2

        return min(score, 1.0)
    }

    var qualityLevel: OCRQualityLevel {
        switch qualityScore {
        case 0.8...1.0:
            return .excellent
        case 0.6..<0.8:
            return .good
        case 0.4..<0.6:
            return .fair
        default:
            return .poor
        }
    }
}

// MARK: - OCR质量等级
enum OCRQualityLevel: String, CaseIterable, Sendable {
    case excellent = "优秀"
    case good = "良好"
    case fair = "一般"
    case poor = "较差"

    var color: String {
        switch self {
        case .excellent:
            return "green"
        case .good:
            return "blue"
        case .fair:
            return "orange"
        case .poor:
            return "red"
        }
    }
}