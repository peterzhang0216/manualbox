import Foundation
import CoreData
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif
import PDFKit
import UniformTypeIdentifiers

extension DataExportService {
    // MARK: - 辅助方法
    func csvEscape(_ string: String) -> String {
        let escaped = string.replacingOccurrences(of: "\"", with: "\"\"")
        if escaped.contains(",") || escaped.contains("\"") || escaped.contains("\n") {
            return "\"\(escaped)\""
        }
        return escaped
    }
    
    func dateStamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter.string(from: Date())
    }
    
    func saveToTemporaryFile(content: String, fileName: String) async throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(fileName)
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }
    
    func saveToTemporaryFile(data: Data, fileName: String) async throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(fileName)
        try data.write(to: fileURL)
        return fileURL
    }
    
    func buildProductInfoText(_ product: Product) -> String {
        var info = [String]()
        info.append("📱 \(product.productName)")
        if !product.productModel.isEmpty {
            info.append("型号: \(product.productModel)")
        }
        if !product.productBrand.isEmpty {
            info.append("品牌: \(product.productBrand)")
        }
        if let order = product.order {
            info.append("购买日期: \(order.displayDate.formatted())")
            if let price = order.price {
                info.append("价格: ¥\(String(format: "%.2f", price.doubleValue))")
            }
        }
        if let category = product.category {
            info.append("分类: \(category.categoryName)")
        }
        if !product.productTags.isEmpty {
            let tagNames = product.productTags.map { $0.tagName }.joined(separator: ", ")
            info.append("标签: \(tagNames)")
        }
        if !product.productNotes.isEmpty {
            info.append("备注: \(product.productNotes)")
        }
        return info.joined(separator: "\n")
    }
    
    func generateCSVContent(from products: [Product]) -> String {
        var csvLines = [String]()
        let headers = [
            "名称", "型号", "品牌", "购买日期", "保修期",
            "价格", "分类", "标签", "创建日期", "备注"
        ]
        csvLines.append(headers.joined(separator: ","))
        for product in products {
            let line = [
                csvEscape(product.productName),
                csvEscape(product.productModel),
                csvEscape(product.productBrand),
                product.order?.displayDate.formatted() ?? "",
                product.warrantyRemainingDays?.description ?? "",
                "¥" + String(format: "%.2f", product.order?.price?.doubleValue ?? 0),
                csvEscape(product.category?.categoryName ?? ""),
                csvEscape(product.productTags.map { $0.tagName }.joined(separator: "; ")),
                dateFormatter.string(from: product.productCreatedAt),
                csvEscape(product.productNotes)
            ]
            csvLines.append(line.joined(separator: ","))
        }
        return csvLines.joined(separator: "\n")
    }
    
    func generateRepairRecordsCSV(from records: [RepairRecord], productName: String) -> String {
        var csvLines = [String]()
        let headers = [
            "产品名称", "维修日期", "问题描述", "费用", "创建日期"
        ]
        csvLines.append(headers.joined(separator: ","))
        for record in records {
            let line = [
                csvEscape(productName),
                dateFormatter.string(from: record.recordDate),
                csvEscape(record.recordDetails),
                record.formattedCost,
                dateFormatter.string(from: record.date ?? Date())
            ]
            csvLines.append(line.joined(separator: ","))
        }
        return csvLines.joined(separator: "\n")
    }
    
    func generateJSONData(from products: [Product]) async throws -> [ProductImportData] {
        return products.map { ProductImportData(from: $0) }
    }
    
    func generatePDFContent(from products: [Product]) async throws -> Data {
        let pdfMetaData = [
            kCGPDFContextCreator: "ManualBox",
            kCGPDFContextAuthor: "ManualBox App",
            kCGPDFContextTitle: "Product Manual Export"
        ]
        #if os(iOS)
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]
        let pageRect = CGRect(x: 0, y: 0, width: 595.2, height: 841.8)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        let pdfData = renderer.pdfData { context in
            var yPosition: CGFloat = 50
            let margin: CGFloat = 50
            let pageWidth = pageRect.width - 2 * margin
            context.beginPage()
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 24),
                .foregroundColor: UIColor.black
            ]
            let title = "ManualBox 产品清单"
            title.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: titleAttributes)
            yPosition += 40
            let infoAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor.gray
            ]
            let exportInfo = "导出时间: \(dateFormatter.string(from: Date()))\n总计产品: \(products.count) 个"
            exportInfo.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: infoAttributes)
            yPosition += 50
            for product in products {
                if yPosition > pageRect.height - 150 {
                    context.beginPage()
                    yPosition = 50
                }
                let productInfo = buildProductInfoText(product)
                let productAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 10),
                    .foregroundColor: UIColor.black
                ]
                let textRect = CGRect(x: margin, y: yPosition, width: pageWidth, height: 100)
                productInfo.draw(in: textRect, withAttributes: productAttributes)
                yPosition += 120
                let path = UIBezierPath()
                path.move(to: CGPoint(x: margin, y: yPosition - 10))
                path.addLine(to: CGPoint(x: pageWidth + margin, y: yPosition - 10))
                UIColor.lightGray.setStroke()
                path.stroke()
            }
        }
        return pdfData
        #else
        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data as CFMutableData) else {
            throw ExportError.pdfGenerationFailed
        }
        var mediaBox = CGRect(x: 0, y: 0, width: 595.2, height: 841.8)
        guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, pdfMetaData as CFDictionary) else {
            throw ExportError.pdfGenerationFailed
        }
        context.beginPDFPage(nil)
        let textToRender = products.map { buildProductInfoText($0) }.joined(separator: "\n\n")
        let attributes = [
            NSAttributedString.Key.font: NSFont.systemFont(ofSize: 12)
        ] as [NSAttributedString.Key : Any]
        let attributedString = NSAttributedString(string: textToRender, attributes: attributes)
        let textRect = CGRect(x: 50, y: 50, width: mediaBox.width - 100, height: mediaBox.height - 100)
        attributedString.draw(in: textRect)
        context.endPDFPage()
        context.closePDF()
        return data as Data
        #endif
    }
} 