//
//  OCRVisionProcessor.swift
//  ManualBox
//
//  Created by Peter's Mac on 2025/4/27.
//

import Foundation
import Vision
import SwiftUI
import NaturalLanguage

#if os(macOS)
import AppKit
#endif

// MARK: - Vision OCR处理器
extension OCRService {
    
    func performVisionOCR(
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
    
    func detectLanguage(from text: String) -> String? {
        if #available(iOS 14.0, macOS 11.0, *) {
            let recognizer = NLLanguageRecognizer()
            recognizer.processString(text)
            return recognizer.dominantLanguage?.rawValue
        }
        return nil
    }
} 