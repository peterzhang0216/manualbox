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
    let dateFormatter: DateFormatter
    
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
        let products = try await context.perform {
            let request: NSFetchRequest<Product> = Product.fetchRequest()
            return try context.fetch(request)
        }
        let categories = try await context.perform {
            let request: NSFetchRequest<Category> = Category.fetchRequest()
            return try context.fetch(request)
        }
        let exportData = FullBackupData(
            products: products,
            categories: categories,
            exportDate: Date()
        )
        let jsonData = try JSONEncoder().encode(exportData)
        let fileName = "ManualBox_FullBackup_\(dateStamp()).json"
        let url = try await saveToTemporaryFile(data: jsonData, fileName: fileName)
        print("✅ 完整数据库导出完成: \(fileName)")
        return url
    }
}

// MARK: - Supporting Types Extensions
extension FullBackupData {
    init(products: [Product], categories: [Category], exportDate: Date) {
        self.version = "1.0"
        let formatter = ISO8601DateFormatter()
        self.exportDate = formatter.string(from: exportDate)
        self.categories = categories.map { CategoryBackupData(from: $0) }
        self.products = products.map { ProductImportData(from: $0) }
        self.metadata = BackupMetadata(
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
            deviceInfo: nil,
            totalProducts: products.count,
            totalCategories: categories.count
        )
    }
}

// CategoryBackupData extension removed - defined in BackupManager.swift

extension ProductImportData {
    init(from product: Product) {
        self.name = product.productName
        self.brand = product.productBrand
        self.model = product.productModel
        self.notes = product.productNotes
        self.categoryName = product.category?.categoryName
        if let order = product.order {
            self.order = OrderImportData(from: order)
        } else {
            self.order = nil
        }
    }
}

extension OrderImportData {
    init(from order: Order) {
        self.orderNumber = order.orderNumber
        self.platform = order.platform
        let formatter = ISO8601DateFormatter()
        if let date = order.orderDate {
            self.orderDate = formatter.string(from: date)
        } else {
            self.orderDate = ""
        }
        if let orderDate = order.orderDate,
           let warrantyEndDate = order.warrantyEndDate {
            let months = Calendar.current.dateComponents([.month], from: orderDate, to: warrantyEndDate).month ?? 0
            self.warrantyPeriod = months
        } else {
            self.warrantyPeriod = nil
        }
    }
}