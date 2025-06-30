//
//  OCRImagePreprocessor.swift
//  ManualBox
//
//  Created by Peter's Mac on 2025/4/27.
//

import Foundation
import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

#if os(macOS)
import AppKit
#endif

// MARK: - 图像预处理器
class ImagePreprocessor: @unchecked Sendable {
    
    // MARK: - 主要增强方法
    func enhance(_ image: PlatformImage) async -> PlatformImage {
        return await withCheckedContinuation { continuation in
            Task { @MainActor in
                let imageCopy = image
                Task.detached {
                    let enhancedImage = await self.applyImageEnhancements(imageCopy)
                    continuation.resume(returning: enhancedImage)
                }
            }
        }
    }
    
    // MARK: - 图像增强处理
    private func applyImageEnhancements(_ image: PlatformImage) async -> PlatformImage {
        guard let cgImage = await getCGImage(from: image) else {
            return image
        }
        
        let ciImage = CIImage(cgImage: cgImage)
        
        // 应用图像增强滤镜链
        var processedImage = ciImage
        
        // 1. 自动调整对比度和亮度
        processedImage = await applyAutoAdjustments(to: processedImage)
        
        // 2. 降噪处理
        processedImage = await applyNoiseReduction(to: processedImage)
        
        // 3. 锐化处理
        processedImage = await applySharpening(to: processedImage)
        
        // 4. 边缘增强
        processedImage = await applyEdgeEnhancement(to: processedImage)
        
        // 5. 二值化处理（针对文本优化）
        processedImage = await applyTextOptimizedBinarization(to: processedImage)
        
        // 转换回PlatformImage
        return await convertCIImageToPlatformImage(processedImage, originalSize: image.size)
    }
    
    // MARK: - 具体增强方法
    
    /// 自动调整对比度和亮度
    private func applyAutoAdjustments(to image: CIImage) async -> CIImage {
        let autoFilters = image.autoAdjustmentFilters(options: nil)
        for filter in autoFilters {
            filter.setValue(image, forKey: kCIInputImageKey)
            if let output = filter.outputImage {
                return output
            }
        }
        return image
    }
    
    /// 降噪处理
    private func applyNoiseReduction(to image: CIImage) async -> CIImage {
        let filter = CIFilter.gaussianBlur()
        filter.inputImage = image
        filter.radius = 0.5 // 轻微模糊以减少噪声
        
        return filter.outputImage ?? image
    }
    
    /// 锐化处理
    private func applySharpening(to image: CIImage) async -> CIImage {
        let filter = CIFilter.unsharpMask()
        filter.inputImage = image
        filter.radius = 2.5
        filter.intensity = 0.5
        
        return filter.outputImage ?? image
    }
    
    /// 边缘增强
    private func applyEdgeEnhancement(to image: CIImage) async -> CIImage {
        let filter = CIFilter.edges()
        filter.inputImage = image
        filter.intensity = 1.0
        
        guard let edgeImage = filter.outputImage else { return image }
        
        // 将边缘图像与原图混合
        let blendFilter = CIFilter.sourceOverCompositing()
        blendFilter.inputImage = edgeImage
        blendFilter.backgroundImage = image
        
        return blendFilter.outputImage ?? image
    }
    
    /// 针对文本优化的二值化处理
    private func applyTextOptimizedBinarization(to image: CIImage) async -> CIImage {
        // 转换为灰度
        let grayscaleFilter = CIFilter.colorMonochrome()
        grayscaleFilter.inputImage = image
        grayscaleFilter.color = CIColor(red: 0.299, green: 0.587, blue: 0.114)
        grayscaleFilter.intensity = 1.0
        
        guard let grayscaleImage = grayscaleFilter.outputImage else { return image }
        
        // 自适应阈值二值化
        let thresholdFilter = CIFilter.colorThreshold()
        thresholdFilter.inputImage = grayscaleImage
        thresholdFilter.threshold = 0.5
        
        return thresholdFilter.outputImage ?? grayscaleImage
    }
    
    // MARK: - 辅助方法
    
    /// 获取CGImage
    private func getCGImage(from image: PlatformImage) async -> CGImage? {
        #if os(macOS)
        return image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        #else
        return image.cgImage
        #endif
    }
    
    /// 转换CIImage回PlatformImage
    private func convertCIImageToPlatformImage(_ ciImage: CIImage, originalSize: CGSize) async -> PlatformImage {
        let context = CIContext()
        
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            // 如果转换失败，返回原图
            return await createFallbackImage(size: originalSize)
        }
        
        #if os(macOS)
        return NSImage(cgImage: cgImage, size: originalSize)
        #else
        return UIImage(cgImage: cgImage)
        #endif
    }
    
    /// 创建备用图像
    private func createFallbackImage(size: CGSize) async -> PlatformImage {
        #if os(macOS)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.white.set()
        NSRect(origin: .zero, size: size).fill()
        image.unlockFocus()
        return image
        #else
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        #endif
    }
    
    // MARK: - 高级预处理方法
    
    /// 针对特定文档类型的预处理
    func preprocessForDocumentType(_ image: PlatformImage, documentType: ImageDocumentType) async -> PlatformImage {
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
    
    /// 说明书专用预处理
    private func preprocessForManual(_ image: PlatformImage) async -> PlatformImage {
        guard let cgImage = await getCGImage(from: image) else { return image }
        let ciImage = CIImage(cgImage: cgImage)
        
        var processedImage = ciImage
        
        // 说明书通常需要更强的对比度
        processedImage = await applyManualSpecificEnhancements(to: processedImage)
        
        return await convertCIImageToPlatformImage(processedImage, originalSize: image.size)
    }
    
    /// 发票专用预处理
    private func preprocessForInvoice(_ image: PlatformImage) async -> PlatformImage {
        guard let cgImage = await getCGImage(from: image) else { return image }
        let ciImage = CIImage(cgImage: cgImage)
        
        var processedImage = ciImage
        
        // 发票需要保持表格结构
        processedImage = await applyInvoiceSpecificEnhancements(to: processedImage)
        
        return await convertCIImageToPlatformImage(processedImage, originalSize: image.size)
    }
    
    /// 收据专用预处理
    private func preprocessForReceipt(_ image: PlatformImage) async -> PlatformImage {
        guard let cgImage = await getCGImage(from: image) else { return image }
        let ciImage = CIImage(cgImage: cgImage)
        
        var processedImage = ciImage
        
        // 收据通常较小，需要放大和增强
        processedImage = await applyReceiptSpecificEnhancements(to: processedImage)
        
        return await convertCIImageToPlatformImage(processedImage, originalSize: image.size)
    }
    
    /// 说明书专用增强
    private func applyManualSpecificEnhancements(to image: CIImage) async -> CIImage {
        var processedImage = image
        
        // 增强对比度
        let contrastFilter = CIFilter.colorControls()
        contrastFilter.inputImage = processedImage
        contrastFilter.contrast = 1.3
        contrastFilter.brightness = 0.1
        contrastFilter.saturation = 0.0 // 转为灰度
        
        if let output = contrastFilter.outputImage {
            processedImage = output
        }
        
        // 锐化
        let sharpenFilter = CIFilter.unsharpMask()
        sharpenFilter.inputImage = processedImage
        sharpenFilter.radius = 3.0
        sharpenFilter.intensity = 0.7
        
        if let output = sharpenFilter.outputImage {
            processedImage = output
        }
        
        return processedImage
    }
    
    /// 发票专用增强
    private func applyInvoiceSpecificEnhancements(to image: CIImage) async -> CIImage {
        var processedImage = image
        
        // 保持表格线条
        let edgeFilter = CIFilter.edges()
        edgeFilter.inputImage = processedImage
        edgeFilter.intensity = 0.8
        
        if let edgeImage = edgeFilter.outputImage {
            // 混合边缘和原图
            let blendFilter = CIFilter.sourceOverCompositing()
            blendFilter.inputImage = edgeImage
            blendFilter.backgroundImage = processedImage
            
            if let output = blendFilter.outputImage {
                processedImage = output
            }
        }
        
        return processedImage
    }
    
    /// 收据专用增强
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
}

// MARK: - 图像预处理文档类型枚举
enum ImageDocumentType {
    case manual    // 说明书
    case invoice   // 发票
    case receipt   // 收据
    case general   // 通用
}