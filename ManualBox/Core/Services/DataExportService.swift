import Foundation
import CoreData
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif
import PDFKit
import UniformTypeIdentifiers

// MARK: - 数据导出服务实现
class DataExportService: ExportServiceProtocol {
    
    // MARK: - Properties
    private let persistentContainer: NSPersistentContainer
    private let dateFormatter: DateFormatter
    
    // MARK: - Initialization
    init(persistentContainer: NSPersistentContainer) {
        self.persistentContainer = persistentContainer
        self.dateFormatter = DateFormatter()
        self.dateFormatter.dateStyle = .medium
        self.dateFormatter.timeStyle = .short
    }
    
    // MARK: - ServiceProtocol
    func initialize() async throws {
        print("📊 数据导出服务已初始化")
    }
    
    func cleanup() {
        // 清理临时文件等
    }
    
    // MARK: - ExportServiceProtocol
    func exportToJSON(_ products: [Product]) async throws -> Data {
        let exportData = try await generateJSONData(from: products)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(exportData)
    }
    
    func exportToCSV(_ products: [Product]) async throws -> Data {
        let csvContent = generateCSVContent(from: products)
        guard let data = csvContent.data(using: .utf8) else {
            throw ExportError.encodingFailed
        }
        return data
    }
    
    func exportToPDF(_ products: [Product]) async throws -> Data {
        return try await generatePDFContent(from: products)
    }
    
    func exportRepairRecords(for product: Product) async throws -> URL {
        let records = product.order?.displayRepairRecords ?? []
        let csvContent = generateRepairRecordsCSV(from: records, productName: product.productName)
        let fileName = "RepairRecords_\(product.productName)_\(dateStamp()).csv"
        let url = try await saveToTemporaryFile(content: csvContent, fileName: fileName)
        
        print("✅ 维修记录导出完成: \(fileName)")
        return url
    }
    
    func exportFullDatabase() async throws -> URL {
        let context = persistentContainer.viewContext
        
        // 获取所有数据
        let products = try await context.perform {
            let request: NSFetchRequest<Product> = Product.fetchRequest()
            return try context.fetch(request)
        }
        
        let categories = try await context.perform {
            let request: NSFetchRequest<Category> = Category.fetchRequest()
            return try context.fetch(request)
        }
        
        let tags = try await context.perform {
            let request: NSFetchRequest<Tag> = Tag.fetchRequest()
            return try context.fetch(request)
        }
        
        // 生成完整数据库导出
        let exportData = FullDatabaseExport(
            products: products,
            categories: categories,
            tags: tags,
            exportDate: Date()
        )
        
        let jsonData = try JSONEncoder().encode(exportData)
        let fileName = "ManualBox_FullBackup_\(dateStamp()).json"
        let url = try await saveToTemporaryFile(data: jsonData, fileName: fileName)
        
        print("✅ 完整数据库导出完成: \(fileName)")
        return url
    }
    
    // MARK: - Private Methods
    private func generateJSONData(from products: [Product]) async throws -> [ProductExportData] {
        return products.map { ProductExportData(from: $0) }
    }
    
    private func generateCSVContent(from products: [Product]) -> String {
        var csvLines = [String]()
        
        // CSV头部
        let headers = [
            "名称", "型号", "品牌", "购买日期", "保修期",
            "价格", "分类", "标签", "创建日期", "备注"
        ]
        csvLines.append(headers.joined(separator: ","))
        
        // 产品数据
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
    
    private func generateRepairRecordsCSV(from records: [RepairRecord], productName: String) -> String {
        var csvLines = [String]()
        
        // CSV头部
        let headers = [
            "产品名称", "维修日期", "问题描述", "费用", "创建日期"
        ]
        csvLines.append(headers.joined(separator: ","))
        
        // 维修记录数据
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
    
    private func generatePDFContent(from products: [Product]) async throws -> Data {
        let pdfMetaData = [
            kCGPDFContextCreator: "ManualBox",
            kCGPDFContextAuthor: "ManualBox App",
            kCGPDFContextTitle: "Product Manual Export"
        ]
        
        #if os(iOS)
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]
        
        let pageRect = CGRect(x: 0, y: 0, width: 595.2, height: 841.8) // A4 size
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        
        let pdfData = renderer.pdfData { context in
            var yPosition: CGFloat = 50
            let margin: CGFloat = 50
            let pageWidth = pageRect.width - 2 * margin
            
            context.beginPage()
            
            // 标题
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 24),
                .foregroundColor: UIColor.black
            ]
            let title = "ManualBox 产品清单"
            title.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: titleAttributes)
            yPosition += 40
            
            // 导出信息
            let infoAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor.gray
            ]
            let exportInfo = "导出时间: \(dateFormatter.string(from: Date()))\n总计产品: \(products.count) 个"
            exportInfo.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: infoAttributes)
            yPosition += 50
            
            // 产品列表
            for product in products {
                // 检查是否需要新页面
                if yPosition > pageRect.height - 150 {
                    context.beginPage()
                    yPosition = 50
                }
                
                // 产品信息
                let productInfo = buildProductInfoText(product)
                let productAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 10),
                    .foregroundColor: UIColor.black
                ]
                
                let textRect = CGRect(x: margin, y: yPosition, width: pageWidth, height: 100)
                productInfo.draw(in: textRect, withAttributes: productAttributes)
                yPosition += 120
                
                // 分隔线
                let path = UIBezierPath()
                path.move(to: CGPoint(x: margin, y: yPosition - 10))
                path.addLine(to: CGPoint(x: pageWidth + margin, y: yPosition - 10))
                UIColor.lightGray.setStroke()
                path.stroke()
            }
        }
        
        return pdfData
        #else
        // macOS implementation
        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data as CFMutableData) else {
            throw ExportError.pdfGenerationFailed
        }
        
        var mediaBox = CGRect(x: 0, y: 0, width: 595.2, height: 841.8)
        guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, pdfMetaData as CFDictionary) else {
            throw ExportError.pdfGenerationFailed
        }
        
        context.beginPDFPage(nil)
        
        // Simple PDF generation for macOS
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
    
    private func buildProductInfoText(_ product: Product) -> String {
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
    
    private func csvEscape(_ string: String) -> String {
        let escaped = string.replacingOccurrences(of: "\"", with: "\"\"")
        if escaped.contains(",") || escaped.contains("\"") || escaped.contains("\n") {
            return "\"\(escaped)\""
        }
        return escaped
    }
    
    private func dateStamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter.string(from: Date())
    }
    
    private func saveToTemporaryFile(content: String, fileName: String) async throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }
    
    private func saveToTemporaryFile(data: Data, fileName: String) async throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        try data.write(to: fileURL)
        return fileURL
    }
}

// MARK: - Supporting Types
struct FullDatabaseExport: Codable {
    let products: [ProductExportData]
    let categories: [CategoryExportData]
    let tags: [TagExportData]
    let exportDate: Date
    
    init(products: [Product], categories: [Category], tags: [Tag], exportDate: Date) {
        self.products = products.map { ProductExportData(from: $0) }
        self.categories = categories.map { CategoryExportData(from: $0) }
        self.tags = tags.map { TagExportData(from: $0) }
        self.exportDate = exportDate
    }
}

struct ProductExportData: Codable {
    let name: String
    let model: String
    let brand: String
    let notes: String
    let createdAt: Date
    let categoryName: String?
    let tagNames: [String]
    
    init(from product: Product) {
        self.name = product.productName
        self.model = product.productModel
        self.brand = product.productBrand
        self.notes = product.productNotes
        self.createdAt = product.productCreatedAt
        self.categoryName = product.category?.categoryName
        self.tagNames = product.productTags.map { $0.tagName }
    }
}

struct CategoryExportData: Codable {
    let name: String
    let icon: String
    
    init(from category: Category) {
        self.name = category.categoryName
        self.icon = category.categoryIcon
    }
}

struct TagExportData: Codable {
    let name: String
    let color: String
    
    init(from tag: Tag) {
        self.name = tag.tagName
        self.color = tag.tagColor
    }
}

// MARK: - Export Errors
enum ExportError: Error {
    case encodingFailed
    case pdfGenerationFailed
    case fileWriteFailed
    
    var localizedDescription: String {
        switch self {
        case .encodingFailed:
            return "数据编码失败"
        case .pdfGenerationFailed:
            return "PDF生成失败"
        case .fileWriteFailed:
            return "文件写入失败"
        }
    }
}