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