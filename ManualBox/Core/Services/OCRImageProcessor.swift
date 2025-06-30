import Foundation
import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

#if os(macOS)
import AppKit
#endif

// MARK: - OCR专用图像处理器
/// 专门负责OCR前的图像预处理和优化
class OCRImageProcessor: @unchecked Sendable {
    
    private let context = CIContext()
    
    // MARK: - 主要处理方法
    
    /// OCR专用图像增强
    func enhance(_ image: PlatformImage) async -> PlatformImage {
        return await withCheckedContinuation { continuation in
            Task { @MainActor in
                let imageCopy = image
                Task.detached {
                    let enhancedImage = await self.applyOCROptimizations(imageCopy)
                    continuation.resume(returning: enhancedImage)
                }
            }
        }
    }
    
    /// 针对特定文档类型的OCR预处理
    func preprocessForOCR(_ image: PlatformImage, documentType: OCRDocumentType) async -> PlatformImage {
        switch documentType {
        case .manual:
            return await preprocessForManual(image)
        case .invoice:
            return await preprocessForInvoice(image)
        case .receipt:
            return await preprocessForReceipt(image)
        case .general:
            return await enhance(image)
        }
    }
    
    /// 批量图像处理
    func enhanceBatch(_ images: [PlatformImage]) async -> [PlatformImage] {
        return await withTaskGroup(of: PlatformImage.self) { group in
            for image in images {
                group.addTask {
                    await self.enhance(image)
                }
            }
            
            var results: [PlatformImage] = []
            for await result in group {
                results.append(result)
            }
            return results
        }
    }
    
    // MARK: - OCR优化处理
    
    private func applyOCROptimizations(_ image: PlatformImage) async -> PlatformImage {
        guard let cgImage = await getCGImage(from: image) else {
            return image
        }
        
        let ciImage = CIImage(cgImage: cgImage)
        var processedImage = ciImage
        
        // OCR专用处理链
        processedImage = await applyContrastEnhancement(to: processedImage)
        processedImage = await applyNoiseReduction(to: processedImage)
        processedImage = await applyTextSharpening(to: processedImage)
        processedImage = await applyBinarization(to: processedImage)
        
        return await convertCIImageToPlatformImage(processedImage, originalSize: image.size)
    }
    
    // MARK: - 文档类型专用处理
    
    private func preprocessForManual(_ image: PlatformImage) async -> PlatformImage {
        guard let cgImage = await getCGImage(from: image) else { return image }
        let ciImage = CIImage(cgImage: cgImage)
        
        var processedImage = ciImage
        
        // 说明书通常需要更强的对比度和清晰度
        processedImage = await applyManualSpecificEnhancements(to: processedImage)
        
        return await convertCIImageToPlatformImage(processedImage, originalSize: image.size)
    }
    
    private func preprocessForInvoice(_ image: PlatformImage) async -> PlatformImage {
        guard let cgImage = await getCGImage(from: image) else { return image }
        let ciImage = CIImage(cgImage: cgImage)
        
        var processedImage = ciImage
        
        // 发票需要保持表格结构清晰
        processedImage = await applyInvoiceSpecificEnhancements(to: processedImage)
        
        return await convertCIImageToPlatformImage(processedImage, originalSize: image.size)
    }
    
    private func preprocessForReceipt(_ image: PlatformImage) async -> PlatformImage {
        guard let cgImage = await getCGImage(from: image) else { return image }
        let ciImage = CIImage(cgImage: cgImage)
        
        var processedImage = ciImage
        
        // 收据通常需要放大和增强对比度
        processedImage = await applyReceiptSpecificEnhancements(to: processedImage)
        
        return await convertCIImageToPlatformImage(processedImage, originalSize: image.size)
    }
    
    // MARK: - 核心图像处理滤镜
    
    private func applyContrastEnhancement(to image: CIImage) async -> CIImage {
        let filter = CIFilter.colorControls()
        filter.inputImage = image
        filter.contrast = 1.3
        filter.brightness = 0.1
        filter.saturation = 0.8
        
        return filter.outputImage ?? image
    }
    
    private func applyNoiseReduction(to image: CIImage) async -> CIImage {
        let filter = CIFilter.noiseReduction()
        filter.inputImage = image
        filter.noiseLevel = 0.02
        filter.sharpness = 0.4
        
        return filter.outputImage ?? image
    }
    
    private func applyTextSharpening(to image: CIImage) async -> CIImage {
        let filter = CIFilter.sharpenLuminance()
        filter.inputImage = image
        filter.sharpness = 0.7
        
        return filter.outputImage ?? image
    }
    
    private func applyBinarization(to image: CIImage) async -> CIImage {
        // 转换为灰度
        let grayscaleFilter = CIFilter.colorMonochrome()
        grayscaleFilter.inputImage = image
        grayscaleFilter.color = CIColor.white
        grayscaleFilter.intensity = 1.0
        
        guard let grayscaleImage = grayscaleFilter.outputImage else { return image }
        
        // 应用阈值
        let thresholdFilter = CIFilter.colorThreshold()
        thresholdFilter.inputImage = grayscaleImage
        thresholdFilter.threshold = 0.5
        
        return thresholdFilter.outputImage ?? grayscaleImage
    }
    
    // MARK: - 文档类型专用增强
    
    private func applyManualSpecificEnhancements(to image: CIImage) async -> CIImage {
        var processedImage = image
        
        // 增强对比度
        let contrastFilter = CIFilter.colorControls()
        contrastFilter.inputImage = processedImage
        contrastFilter.contrast = 1.5
        contrastFilter.brightness = 0.2
        
        if let output = contrastFilter.outputImage {
            processedImage = output
        }
        
        // 锐化处理
        let sharpenFilter = CIFilter.sharpenLuminance()
        sharpenFilter.inputImage = processedImage
        sharpenFilter.sharpness = 0.8
        
        if let output = sharpenFilter.outputImage {
            processedImage = output
        }
        
        return processedImage
    }
    
    private func applyInvoiceSpecificEnhancements(to image: CIImage) async -> CIImage {
        var processedImage = image
        
        // 保持表格线条清晰
        let edgeFilter = CIFilter.edgeWork()
        edgeFilter.inputImage = processedImage
        edgeFilter.radius = 3.0
        
        if let edgeImage = edgeFilter.outputImage {
            // 将边缘检测结果与原图混合
            let blendFilter = CIFilter(name: "CIOverlayBlendMode")!
            blendFilter.setValue(processedImage, forKey: kCIInputImageKey)
            blendFilter.setValue(edgeImage, forKey: kCIInputBackgroundImageKey)
            
            if let output = blendFilter.outputImage {
                processedImage = output
            }
        }
        
        return processedImage
    }
    
    private func applyReceiptSpecificEnhancements(to image: CIImage) async -> CIImage {
        var processedImage = image
        
        // 放大图像
        let scaleFilter = CIFilter.lanczosScaleTransform()
        scaleFilter.inputImage = processedImage
        scaleFilter.scale = 2.0
        
        if let scaledImage = scaleFilter.outputImage {
            processedImage = scaledImage
        }
        
        // 增强对比度
        let contrastFilter = CIFilter.colorControls()
        contrastFilter.inputImage = processedImage
        contrastFilter.contrast = 1.5
        contrastFilter.brightness = 0.2
        
        if let output = contrastFilter.outputImage {
            processedImage = output
        }
        
        return processedImage
    }
    
    // MARK: - 辅助方法
    
    private func getCGImage(from image: PlatformImage) async -> CGImage? {
        #if os(macOS)
        return image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        #else
        return image.cgImage
        #endif
    }
    
    private func convertCIImageToPlatformImage(_ ciImage: CIImage, originalSize: CGSize) async -> PlatformImage {
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            #if os(macOS)
            return NSImage(size: originalSize)
            #else
            return UIImage()
            #endif
        }
        
        #if os(macOS)
        let nsImage = NSImage(cgImage: cgImage, size: originalSize)
        return nsImage
        #else
        return UIImage(cgImage: cgImage)
        #endif
    }
}

// MARK: - OCR文档类型枚举
enum OCRDocumentType {
    case manual    // 说明书
    case invoice   // 发票
    case receipt   // 收据
    case general   // 通用
}
