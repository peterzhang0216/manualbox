//
//  Manual+Extensions.swift
//  ManualBox
//
//  Created by Peter's Mac on 2025/5/10.
//

import Foundation
import CoreData
import SwiftUI
import PDFKit
import Vision

extension Manual {
    // MARK: - 便利属性
    var manualFileName: String {
        get { fileName ?? "未命名说明书" }
        set { fileName = newValue }
    }
    
    var manualFileType: String {
        get { fileType ?? "unknown" }
        set { fileType = newValue }
    }
    
    var manualContent: String {
        get { content ?? "" }
        set { content = newValue }
    }
    
    var isPDF: Bool {
        return manualFileType.lowercased() == "pdf"
    }
    
    var isImage: Bool {
        let imageTypes = ["jpg", "jpeg", "png", "heic", "heif"]
        return imageTypes.contains(manualFileType.lowercased())
    }
    
    // MARK: - 工厂方法
    static func createManual(
        in context: NSManagedObjectContext,
        fileName: String,
        fileData: Data,
        fileType: String,
        product: Product? = nil
    ) -> Manual {
        let manual = Manual(context: context)
        manual.id = UUID()
        manual.fileName = fileName
        manual.fileData = fileData
        manual.fileType = fileType
        manual.isOCRProcessed = false
        manual.product = product

        // 创建初始版本
        Task {
            await ManualVersionService.shared.createVersion(
                for: manual.id ?? UUID(),
                fileData: fileData,
                fileName: fileName,
                fileType: fileType,
                content: nil,
                versionNote: "初始版本",
                changeType: .initial
            )
        }

        return manual
    }

    // MARK: - 版本管理方法

    /// 更新说明书并创建新版本
    func updateManual(
        fileName: String? = nil,
        fileData: Data? = nil,
        fileType: String? = nil,
        content: String? = nil,
        versionNote: String? = nil,
        changeType: VersionChangeType = .update
    ) async {
        let oldFileName = self.fileName
        let oldFileData = self.fileData
        let oldFileType = self.fileType
        let oldContent = self.content

        // 更新属性
        if let fileName = fileName {
            self.fileName = fileName
        }
        if let fileData = fileData {
            self.fileData = fileData
        }
        if let fileType = fileType {
            self.fileType = fileType
        }
        if let content = content {
            self.content = content
        }

        // 检查是否有实际变更
        let hasChanges = (fileName != nil && fileName != oldFileName) ||
                        (fileData != nil && fileData != oldFileData) ||
                        (fileType != nil && fileType != oldFileType) ||
                        (content != nil && content != oldContent)

        // 如果有变更，创建新版本
        if hasChanges {
            await ManualVersionService.shared.createVersion(
                for: self.id ?? UUID(),
                fileData: self.fileData ?? Data(),
                fileName: self.fileName ?? "",
                fileType: self.fileType ?? "",
                content: self.content,
                versionNote: versionNote,
                changeType: changeType
            )
        }
    }

    /// 处理OCR完成后的版本创建
    func handleOCRCompletion(content: String) async {
        self.content = content
        self.isOCRProcessed = true

        await ManualVersionService.shared.createVersion(
            for: self.id ?? UUID(),
            fileData: self.fileData ?? Data(),
            fileName: self.fileName ?? "",
            fileType: self.fileType ?? "",
            content: content,
            versionNote: "OCR处理完成",
            changeType: .ocr
        )
    }
    
    // MARK: - 文件处理方法
    
    // 获取预览图像
    func getPreviewImage() -> PlatformImage? {
        guard let data = fileData else { return nil }
        
        if isPDF {
            if let pdfDocument = PDFDocument(data: data),
               let pdfPage = pdfDocument.page(at: 0) {
                let pageRect = pdfPage.bounds(for: .mediaBox)
                #if os(macOS)
                let image = NSImage(size: pageRect.size)
                image.lockFocus()
                let context = NSGraphicsContext.current?.cgContext
                context?.translateBy(x: 0, y: pageRect.size.height)
                context?.scaleBy(x: 1, y: -1)
                pdfPage.draw(with: .mediaBox, to: context!)
                image.unlockFocus()
                return image
                #else
                let renderer = UIGraphicsImageRenderer(size: pageRect.size)
                let image = renderer.image { context in
                    UIColor.white.set()
                    context.fill(CGRect(origin: .zero, size: pageRect.size))
                    
                    context.cgContext.translateBy(x: 0, y: pageRect.size.height)
                    context.cgContext.scaleBy(x: 1, y: -1)
                    
                    pdfPage.draw(with: .mediaBox, to: context.cgContext)
                }
                return image
                #endif
            }
        } else if isImage {
            return PlatformImage(data: data)
        }
        
        return nil
    }
    
    // 执行 OCR 识别 - 使用增强版OCR服务
    @MainActor
    func performOCR(completion: @escaping (Bool) -> Void) {
        let ocrService = OCRService.shared

        ocrService.performOCR(on: self, configuration: .default) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let ocrResult):
                    self.content = ocrResult.text
                    self.isOCRProcessed = true
                    // 注意：Core Data模型中可能没有这些字段，先注释掉
                    // self.ocrConfidence = ocrResult.confidence
                    // self.detectedLanguage = ocrResult.languageDetected

                    // 保存到Core Data
                    if let context = self.managedObjectContext {
                        do {
                            try context.save()
                            completion(true)
                        } catch {
                            print("保存OCR结果失败: \(error.localizedDescription)")
                            completion(false)
                        }
                    } else {
                        completion(false)
                    }

                case .failure(let error):
                    print("OCR处理失败: \(error.localizedDescription)")
                    completion(false)
                }
            }
        }
    }

    // 执行增强OCR处理（带重试机制）
    @MainActor
    func performEnhancedOCR(completion: @escaping (Bool) -> Void) {
        let ocrService = OCRService.shared

        ocrService.performOCRWithRetry(on: self, maxRetries: 3, configuration: .default) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let ocrResult):
                    self.content = ocrResult.text
                    self.isOCRProcessed = true

                    // 评估OCR质量
                    let quality = OCRQualityMetrics(
                        confidence: ocrResult.confidence,
                        textLength: ocrResult.text.count,
                        wordCount: ocrResult.text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count,
                        lineCount: ocrResult.text.components(separatedBy: .newlines).count,
                        detectedLanguage: ocrResult.languageDetected,
                        processingTime: ocrResult.processingTime
                    )
                    print("📊 OCR质量评估: \(quality.qualityLevel.rawValue) (分数: \(String(format: "%.2f", quality.qualityScore)))")

                    // 保存到Core Data
                    if let context = self.managedObjectContext {
                        do {
                            try context.save()
                            completion(true)
                        } catch {
                            print("保存OCR结果失败: \(error.localizedDescription)")
                            completion(false)
                        }
                    } else {
                        completion(false)
                    }

                case .failure(let error):
                    print("增强OCR处理失败: \(error.localizedDescription)")
                    completion(false)
                }
            }
        }
    }
    
    // 执行快速OCR（用于预览）
    @MainActor
    func performFastOCR(completion: @escaping (Bool) -> Void) {
        let ocrService = OCRService.shared
        
        ocrService.performOCR(on: self, configuration: .fast) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let ocrResult):
                    self.content = ocrResult.text
                    self.isOCRProcessed = true
                    // self.ocrConfidence = ocrResult.confidence
                    completion(true)
                    
                case .failure(let error):
                    print("快速OCR处理失败: \(error.localizedDescription)")
                    completion(false)
                }
            }
        }
    }
    
    // 获取OCR处理进度
    @MainActor
    func performOCRWithProgress(
        progressCallback: @escaping @Sendable (Float) -> Void,
        completion: @escaping (Bool) -> Void
    ) {
        let ocrService = OCRService.shared
        
        let config = OCRConfiguration(
            recognitionLevel: .accurate,
            languages: ["zh-Hans", "zh-Hant", "en-US"],
            usesLanguageCorrection: true,
            minimumTextHeight: 0.02,
            customWords: [],
            progressCallback: progressCallback
        )
        
        ocrService.performOCR(on: self, configuration: config) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let ocrResult):
                    self.content = ocrResult.text
                    self.isOCRProcessed = true
                    // self.ocrConfidence = ocrResult.confidence
                    // self.detectedLanguage = ocrResult.languageDetected
                    
                    if let context = self.managedObjectContext {
                        do {
                            try context.save()
                            completion(true)
                        } catch {
                            completion(false)
                        }
                    } else {
                        completion(false)
                    }
                    
                case .failure(_):
                    completion(false)
                }
            }
        }
    }
    
    // 获取 PDF 文档
    func getPDFDocument() -> PDFDocument? {
        guard let data = fileData, isPDF else { return nil }
        return PDFDocument(data: data)
    }
    
    // MARK: - 搜索相关方法
    
    // 在说明书内容中搜索关键词
    static func searchManuals(in context: NSManagedObjectContext, query: String) -> [Manual] {
        let request: NSFetchRequest<Manual> = Manual.fetchRequest()
        
        // 构建搜索谓词
        var predicates: [NSPredicate] = []
        
        // 搜索文件名
        predicates.append(NSPredicate(format: "fileName CONTAINS[cd] %@", query))
        
        // 搜索已OCR的内容
        predicates.append(NSPredicate(format: "content CONTAINS[cd] %@ AND isOCRProcessed == YES", query))
        
        // 组合谓词
        request.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: predicates)
        
        // 按更新时间排序
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Manual.product?.updatedAt, ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("搜索说明书失败: \(error.localizedDescription)")
            return []
        }
    }
    
    // 获取搜索结果的预览文本
    func getPreviewText(for query: String, maxLength: Int = 100) -> String? {
        guard let content = self.content,
              !content.isEmpty,
              let range = content.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) else {
            return nil
        }
        
        let start = content.index(range.lowerBound, offsetBy: -50, limitedBy: content.startIndex) ?? content.startIndex
        let end = content.index(range.upperBound, offsetBy: 50, limitedBy: content.endIndex) ?? content.endIndex
        
        var preview = String(content[start..<end])
        
        // 添加省略号
        if start > content.startIndex {
            preview = "..." + preview
        }
        if end < content.endIndex {
            preview = preview + "..."
        }
        
        return preview
    }
}

// 预览支持
extension Manual {
    @MainActor
    static var preview: Manual {
        let context = PersistenceController.preview.container.viewContext
        let manual = Manual(context: context)
        manual.id = UUID()
        manual.fileName = "iPad_使用说明书.pdf"
        manual.fileType = "pdf"
        manual.content = "iPad Pro 使用说明书\n\n1. 初始设置\n2. 基本操作\n3. 应用与功能\n4. 维护与保养"
        manual.isOCRProcessed = true
        return manual
    }
}