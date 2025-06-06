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
        
        return manual
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
    
    // 执行 OCR 识别
    func performOCR(completion: @escaping (Bool) -> Void) {
        guard let image = getPreviewImage() else {
            completion(false)
            return
        }
        
        #if os(macOS)
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            completion(false)
            return
        }
        #else
        guard let cgImage = image.cgImage else {
            completion(false)
            return
        }
        #endif
        
        // 创建 OCR 请求
        let request = VNRecognizeTextRequest { [weak self] request, error in
            guard let self = self else {
                completion(false)
                return
            }
            
            guard error == nil else {
                print("OCR 错误: \(error!.localizedDescription)")
                completion(false)
                return
            }
            
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                completion(false)
                return
            }
            
            // 提取识别的文本
            let recognizedText = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }.joined(separator: "\n")
            
            DispatchQueue.main.async {
                self.content = recognizedText
                self.isOCRProcessed = true
                
                // 保存 CoreData 上下文
                if let context = self.managedObjectContext {
                    do {
                        try context.save()
                        completion(true)
                    } catch {
                        print("保存 OCR 结果失败: \(error.localizedDescription)")
                        completion(false)
                    }
                } else {
                    completion(false)
                }
            }
        }
        
        // 配置 OCR 请求
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        
        // 支持中文识别
        if #available(iOS 14.0, macOS 11.0, *) {
            request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US"]
        }
        
        // 执行 OCR 请求
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                print("OCR 处理失败: \(error.localizedDescription)")
                DispatchQueue.main.async {
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