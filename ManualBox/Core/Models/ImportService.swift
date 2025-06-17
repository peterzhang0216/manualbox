import Foundation
import CoreData
import SwiftUI
import UniformTypeIdentifiers

class ImportService {
    
    // MARK: - Import Progress Callback
    typealias ProgressCallback = (Double) -> Void
    typealias WarningCallback = ([String]) -> Void
    
    // MARK: - Enhanced Import Methods
    
    // 从CSV文件导入数据（增强版）
    static func importFromCSV(
        url: URL, 
        context: NSManagedObjectContext,
        replaceExisting: Bool = false,
        progressCallback: ProgressCallback? = nil,
        warningCallback: WarningCallback? = nil
    ) async throws -> ImportResult {
        var _: [String] = []
        progressCallback?(0.1)
        
        // 读取CSV文件内容
        let csvData = try Data(contentsOf: url)
        guard let csvString = String(data: csvData, encoding: .utf8) else {
            throw ImportError.invalidEncoding
        }
        
        progressCallback?(0.2)
        
        // 解析CSV
        var rows = csvString.components(separatedBy: "\n")
        guard rows.count > 1 else {
            throw ImportError.emptyFile
        }
        
        // 第一行是标题
        let headers = parseCSVRow(rows[0])
        rows.removeFirst()
        
        // 过滤空行
        rows = rows.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        
        progressCallback?(0.3)
        
        // 如果需要替换现有数据，先清空
        if replaceExisting {
            try await clearAllProducts(context: context)
            progressCallback?(0.4)
        }
        
        return try await importCSVRows(
            rows: rows,
            headers: headers,
            context: context,
            progressCallback: { progress in
                progressCallback?(0.4 + progress * 0.6)
            },
            warningCallback: warningCallback
        )
    }
    
    // 原始CSV导入方法（保持兼容性）
    static func importFromCSV(url: URL, context: NSManagedObjectContext) async throws -> Int {
        // 读取CSV文件内容
        let csvData = try Data(contentsOf: url)
        guard let csvString = String(data: csvData, encoding: .utf8) else {
            throw ImportError.invalidEncoding
        }
        
        // 解析CSV
        var rows = csvString.components(separatedBy: "\n")
        guard rows.count > 1 else {
            throw ImportError.emptyFile
        }
        
        // 第一行是标题
        let headers = parseCSVRow(rows[0])
        rows.removeFirst()
        
        // 创建一个后台上下文来进行导入
        let backgroundContext = PersistenceController.shared.newBackgroundContext()
        
        // 在后台上下文中创建产品
        var importedCount = 0
        
        return try await withCheckedThrowingContinuation { continuation in
            backgroundContext.perform {
                // 预加载所有分类
                let categoryFetch = NSFetchRequest<Category>(entityName: "Category")
                let categories: [Category]
                do {
                    categories = try backgroundContext.fetch(categoryFetch)
                } catch {
                    continuation.resume(throwing: error)
                    return
                }
                
                // 处理每一行数据
                for row in rows where !row.isEmpty {
                    let values = self.parseCSVRow(row)
                    guard values.count == headers.count else { continue }
                    
                    // 创建数据字典
                    var productData: [String: String] = [:]
                    for (index, header) in headers.enumerated() {
                        productData[header] = values[index]
                    }
                    
                    // 创建产品
                    do {
                        _ = try self.createProductFromCSVData(productData, categories: categories, context: backgroundContext)
                        importedCount += 1
                    } catch {
                        print("导入产品失败: \(error.localizedDescription)")
                        // 继续导入下一个
                    }
                }
                
                // 保存上下文
                do {
                    try backgroundContext.save()
                    continuation.resume(returning: importedCount)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // 从JSON文件导入数据（增强版）
    static func importFromJSON(
        url: URL, 
        context: NSManagedObjectContext,
        replaceExisting: Bool = false,
        progressCallback: ProgressCallback? = nil,
        warningCallback: WarningCallback? = nil
    ) async throws -> ImportResult {
        var warnings: [String] = []
        progressCallback?(0.1)
        
        // 读取JSON文件内容
        let jsonData = try Data(contentsOf: url)
        progressCallback?(0.2)
        
        // 解析JSON
        let decoder = JSONDecoder()
        let products = try decoder.decode([ProductImportData].self, from: jsonData)
        progressCallback?(0.3)
        
        // 如果需要替换现有数据，先清空
        if replaceExisting {
            try await clearAllProducts(context: context)
            progressCallback?(0.4)
        }
        
        return try await importJSONProducts(
            products: products,
            context: context,
            progressCallback: { progress in
                progressCallback?(0.4 + progress * 0.6)
            },
            warningCallback: warningCallback
        )
    }
    
    // 原始JSON导入方法（保持兼容性）
    static func importFromJSON(url: URL, context: NSManagedObjectContext) async throws -> Int {
        // 读取JSON文件内容
        let jsonData = try Data(contentsOf: url)
        
        // 解析JSON
        let decoder = JSONDecoder()
        let products = try decoder.decode([ProductImportData].self, from: jsonData)
        
        // 创建一个后台上下文来进行导入
        let backgroundContext = PersistenceController.shared.newBackgroundContext()
        
        // 在后台上下文中创建产品
        var importedCount = 0
        
        return try await withCheckedThrowingContinuation { continuation in
            backgroundContext.perform {
                // 预加载所有分类
                let categoryFetch = NSFetchRequest<Category>(entityName: "Category")
                let categories: [Category]
                do {
                    categories = try backgroundContext.fetch(categoryFetch)
                } catch {
                    continuation.resume(throwing: error)
                    return
                }
                
                // 处理每个产品数据
                for productData in products {
                    // 找到对应的分类
                    let category = categories.first { $0.name == productData.categoryName }
                    
                    // 创建新产品
                    let product = Product(context: backgroundContext)
                    product.id = UUID()
                    product.name = productData.name
                    product.brand = productData.brand
                    product.model = productData.model
                    product.notes = productData.notes
                    product.category = category
                    
                    let now = Date()
                    product.createdAt = now
                    product.updatedAt = now
                    
                    // 如果有订单信息，创建订单
                    if let orderData = productData.order {
                        let order = Order(context: backgroundContext)
                        order.id = UUID()
                        order.orderNumber = orderData.orderNumber
                        order.platform = orderData.platform
                        
                        if let orderDate = ISO8601DateFormatter().date(from: orderData.orderDate) {
                            order.orderDate = orderDate
                            
                            // 计算保修期结束日期
                            if let warrantyPeriod = orderData.warrantyPeriod {
                                let calendar = Calendar.current
                                order.warrantyEndDate = calendar.date(byAdding: .month, value: warrantyPeriod, to: orderDate)
                            }
                        }
                        
                        order.product = product
                        product.order = order
                    }
                    
                    importedCount += 1
                }
                
                // 保存上下文
                do {
                    try backgroundContext.save()
                    continuation.resume(returning: importedCount)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // 辅助方法：从CSV数据创建产品
    private static func createProductFromCSVData(_ data: [String: String], categories: [Category], context: NSManagedObjectContext) throws -> Product {
        // 检查必要字段
        guard let name = data["名称"], !name.isEmpty else {
            throw ImportError.missingRequiredField("名称")
        }
        
        // 创建产品
        let product = Product(context: context)
        product.id = UUID()
        product.name = name
        product.brand = data["品牌"]
        product.model = data["型号"]
        product.notes = data["备注"]
        
        // 查找分类
        if let categoryName = data["分类"],
           let category = categories.first(where: { $0.name == categoryName }) {
            product.category = category
        }
        
        // 时间戳
        let now = Date()
        product.createdAt = now
        product.updatedAt = now
        
        // 如果有订单相关数据，创建订单
        if let orderNumber = data["订单号"], !orderNumber.isEmpty {
            let order = Order(context: context)
            order.id = UUID()
            order.orderNumber = orderNumber
            order.platform = data["购买平台"]
            
            // 解析购买日期
            if let dateStr = data["购买日期"],
               let date = parseDate(dateStr) {
                order.orderDate = date
                
                // 如果有保修期，计算保修结束日期
                if let warrantyStr = data["保修期(月)"],
                   let warrantyMonths = Int(warrantyStr) {
                    let calendar = Calendar.current
                    order.warrantyEndDate = calendar.date(byAdding: .month, value: warrantyMonths, to: date)
                }
            }
            
            order.product = product
            product.order = order
        }
        
        return product
    }
    
    // MARK: - Batch Import Methods
    
    // 批量导入文件
    static func importBatchFiles(
        urls: [URL],
        context: NSManagedObjectContext,
        replaceExisting: Bool = false,
        progressCallback: ProgressCallback? = nil,
        warningCallback: WarningCallback? = nil
    ) async throws -> ImportResult {
        var totalImported = 0
        var totalWarnings: [String] = []
        
        progressCallback?(0.0)
        
        // 如果需要替换现有数据，先清空（只在第一个文件时执行）
        if replaceExisting {
            try await clearAllProducts(context: context)
        }
        
        for (index, url) in urls.enumerated() {
            let fileProgress = Double(index) / Double(urls.count)
            progressCallback?(fileProgress)
            
            do {
                // 检测文件类型并导入
                let contentType = try url.resourceValues(forKeys: [.contentTypeKey]).contentType
                let result: ImportResult
                
                if contentType == UTType.commaSeparatedText {
                    result = try await importFromCSV(
                        url: url,
                        context: context,
                        replaceExisting: false, // 已经在开始时清空了
                        progressCallback: nil,
                        warningCallback: nil
                    )
                } else if contentType == UTType.json {
                    result = try await importFromJSON(
                        url: url,
                        context: context,
                        replaceExisting: false,
                        progressCallback: nil,
                        warningCallback: nil
                    )
                } else {
                    totalWarnings.append("跳过不支持的文件类型: \(url.lastPathComponent)")
                    continue
                }
                
                totalImported += result.importedCount
                totalWarnings.append(contentsOf: result.warnings)
                
            } catch {
                totalWarnings.append("导入文件 \(url.lastPathComponent) 失败: \(error.localizedDescription)")
            }
        }
        
        progressCallback?(1.0)
        warningCallback?(totalWarnings)
        
        return ImportResult(
            importedCount: totalImported,
            warnings: totalWarnings
        )
    }
    
    // 导入完整备份
    static func importFullBackup(
        url: URL,
        context: NSManagedObjectContext,
        progressCallback: ProgressCallback? = nil,
        warningCallback: WarningCallback? = nil
    ) async throws -> ImportResult {
        progressCallback?(0.1)
        
        // 读取备份文件
        let backupData = try Data(contentsOf: url)
        progressCallback?(0.2)
        
        // 解析完整备份数据
        let decoder = JSONDecoder()
        let fullBackup = try decoder.decode(FullBackupData.self, from: backupData)
        progressCallback?(0.3)
        
        // 清空现有数据
        try await clearAllData(context: context)
        progressCallback?(0.4)
        
        var warnings: [String] = []
        var totalImported = 0
        
        // 导入分类
        for categoryData in fullBackup.categories {
            let category = Category(context: context)
            category.id = categoryData.id
            category.name = categoryData.name
            category.icon = categoryData.icon
            category.createdAt = ISO8601DateFormatter().date(from: categoryData.createdAt) ?? Date()
            category.updatedAt = ISO8601DateFormatter().date(from: categoryData.updatedAt) ?? Date()
        }
        
        progressCallback?(0.6)
        
        // 导入产品
        let result = try await importJSONProducts(
            products: fullBackup.products,
            context: context,
            progressCallback: { progress in
                progressCallback?(0.6 + progress * 0.4)
            },
            warningCallback: { newWarnings in
                warnings.append(contentsOf: newWarnings)
            }
        )
        
        totalImported = result.importedCount
        warnings.append(contentsOf: result.warnings)
        
        warningCallback?(warnings)
        
        return ImportResult(
            importedCount: totalImported,
            warnings: warnings
        )
    }
    
    // MARK: - Helper Methods
    
    // 导入CSV行数据
    private static func importCSVRows(
        rows: [String],
        headers: [String],
        context: NSManagedObjectContext,
        progressCallback: ProgressCallback? = nil,
        warningCallback: WarningCallback? = nil
    ) async throws -> ImportResult {
        let backgroundContext = PersistenceController.shared.newBackgroundContext()
        var importedCount = 0
        var warnings: [String] = []
        
        return try await withCheckedThrowingContinuation { continuation in
            backgroundContext.perform {
                // 预加载所有分类
                let categoryFetch = NSFetchRequest<Category>(entityName: "Category")
                let categories: [Category]
                do {
                    categories = try backgroundContext.fetch(categoryFetch)
                } catch {
                    continuation.resume(throwing: error)
                    return
                }
                
                // 处理每一行数据
                for (index, row) in rows.enumerated() {
                    let progress = Double(index) / Double(rows.count)
                    DispatchQueue.main.async {
                        progressCallback?(progress)
                    }
                    
                    let values = self.parseCSVRow(row)
                    guard values.count == headers.count else {
                        warnings.append("第\(index + 2)行数据格式错误，已跳过")
                        continue
                    }
                    
                    // 创建数据字典
                    var productData: [String: String] = [:]
                    for (headerIndex, header) in headers.enumerated() {
                        productData[header] = values[headerIndex]
                    }
                    
                    // 创建产品
                    do {
                        _ = try self.createProductFromCSVData(productData, categories: categories, context: backgroundContext)
                        importedCount += 1
                    } catch {
                        warnings.append("第\(index + 2)行导入失败: \(error.localizedDescription)")
                    }
                }
                
                // 保存上下文
                do {
                    try backgroundContext.save()
                    DispatchQueue.main.async {
                        warningCallback?(warnings)
                    }
                    continuation.resume(returning: ImportResult(
                        importedCount: importedCount,
                        warnings: warnings
                    ))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // 导入JSON产品数据
    private static func importJSONProducts(
        products: [ProductImportData],
        context: NSManagedObjectContext,
        progressCallback: ProgressCallback? = nil,
        warningCallback: WarningCallback? = nil
    ) async throws -> ImportResult {
        let backgroundContext = PersistenceController.shared.newBackgroundContext()
        var importedCount = 0
        var warnings: [String] = []
        
        return try await withCheckedThrowingContinuation { continuation in
            backgroundContext.perform {
                // 预加载所有分类
                let categoryFetch = NSFetchRequest<Category>(entityName: "Category")
                let categories: [Category]
                do {
                    categories = try backgroundContext.fetch(categoryFetch)
                } catch {
                    continuation.resume(throwing: error)
                    return
                }
                
                // 处理每个产品数据
                for (index, productData) in products.enumerated() {
                    let progress = Double(index) / Double(products.count)
                    DispatchQueue.main.async {
                        progressCallback?(progress)
                    }
                    
                    // 找到对应的分类
                    let category = categories.first { $0.name == productData.categoryName }
                    
                    // 创建新产品
                    let product = Product(context: backgroundContext)
                    product.id = UUID()
                    product.name = productData.name
                    product.brand = productData.brand
                    product.model = productData.model
                    product.notes = productData.notes
                    product.category = category
                    
                    let now = Date()
                    product.createdAt = now
                    product.updatedAt = now
                    
                    // 如果有订单信息，创建订单
                    if let orderData = productData.order {
                        let order = Order(context: backgroundContext)
                        order.id = UUID()
                        order.orderNumber = orderData.orderNumber
                        order.platform = orderData.platform
                        
                        if let orderDate = ISO8601DateFormatter().date(from: orderData.orderDate) {
                            order.orderDate = orderDate
                            
                            // 计算保修期结束日期
                            if let warrantyPeriod = orderData.warrantyPeriod {
                                let calendar = Calendar.current
                                order.warrantyEndDate = calendar.date(byAdding: .month, value: warrantyPeriod, to: orderDate)
                            }
                        }
                        
                        order.product = product
                        product.order = order
                    }
                    
                    importedCount += 1
                }
                
                // 保存上下文
                do {
                    try backgroundContext.save()
                    DispatchQueue.main.async {
                        warningCallback?(warnings)
                    }
                    continuation.resume(returning: ImportResult(
                        importedCount: importedCount,
                        warnings: warnings
                    ))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // 清空所有产品数据
    private static func clearAllProducts(context: NSManagedObjectContext) async throws {
        try await context.perform {
            let productFetch = NSFetchRequest<NSFetchRequestResult>(entityName: "Product")
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: productFetch)
            try context.execute(deleteRequest)
            
            let orderFetch = NSFetchRequest<NSFetchRequestResult>(entityName: "Order")
            let deleteOrderRequest = NSBatchDeleteRequest(fetchRequest: orderFetch)
            try context.execute(deleteOrderRequest)
            
            try context.save()
        }
    }
    
    // 清空所有数据（包括分类）
    private static func clearAllData(context: NSManagedObjectContext) async throws {
        try await context.perform {
            // 删除产品和订单
            let productFetch = NSFetchRequest<NSFetchRequestResult>(entityName: "Product")
            let deleteProductRequest = NSBatchDeleteRequest(fetchRequest: productFetch)
            try context.execute(deleteProductRequest)
            
            let orderFetch = NSFetchRequest<NSFetchRequestResult>(entityName: "Order")
            let deleteOrderRequest = NSBatchDeleteRequest(fetchRequest: orderFetch)
            try context.execute(deleteOrderRequest)
            
            // 删除分类
            let categoryFetch = NSFetchRequest<NSFetchRequestResult>(entityName: "Category")
            let deleteCategoryRequest = NSBatchDeleteRequest(fetchRequest: categoryFetch)
            try context.execute(deleteCategoryRequest)
            
            try context.save()
        }
    }
    
    // 辅助方法：解析CSV行
    private static func parseCSVRow(_ row: String) -> [String] {
        var result: [String] = []
        var currentField = ""
        var insideQuotes = false
        
        for char in row {
            if char == "\"" {
                insideQuotes.toggle()
            } else if char == "," && !insideQuotes {
                result.append(currentField)
                currentField = ""
            } else {
                currentField.append(char)
            }
        }
        
        result.append(currentField)
        return result
    }
    
    // 辅助方法：解析日期
    private static func parseDate(_ dateString: String) -> Date? {
        let dateFormatters: [DateFormatter] = [
            // 尝试不同的日期格式
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy/MM/dd"
                return formatter
            }(),
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                return formatter
            }(),
            {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .none
                return formatter
            }()
        ]
        
        for formatter in dateFormatters {
            if let date = formatter.date(from: dateString) {
                return date
            }
        }
        
        return nil
    }
    
    // 导入错误
    enum ImportError: Error, LocalizedError {
        case invalidEncoding
        case emptyFile
        case invalidFormat
        case missingRequiredField(String)
        case unsupportedFileType
        case corruptedBackup
        case incompatibleVersion
        
        var errorDescription: String? {
            switch self {
            case .invalidEncoding:
                return "文件编码无效"
            case .emptyFile:
                return "文件为空"
            case .invalidFormat:
                return "文件格式无效"
            case .missingRequiredField(let field):
                return "缺少必要字段: \(field)"
            case .unsupportedFileType:
                return "不支持的文件类型"
            case .corruptedBackup:
                return "备份文件已损坏"
            case .incompatibleVersion:
                return "备份文件版本不兼容"
            }
        }
    }
}

// MARK: - Import Result
struct ImportResult {
    let importedCount: Int
    let warnings: [String]
    
    var hasWarnings: Bool {
        return !warnings.isEmpty
    }
}

// MARK: - Import Data Models
struct ProductImportData: Codable {
    var name: String
    var brand: String?
    var model: String?
    var notes: String?
    var categoryName: String?
    var order: OrderImportData?
}

struct OrderImportData: Codable {
    var orderNumber: String?
    var platform: String?
    var orderDate: String
    var warrantyPeriod: Int?
}

// 完整备份数据模型
struct FullBackupData: Codable {
    let version: String
    let exportDate: String
    let categories: [CategoryBackupData]
    let products: [ProductImportData]
    let metadata: BackupMetadata?
}

struct CategoryBackupData: Codable {
    let id: UUID
    let name: String
    let icon: String?
    let createdAt: String
    let updatedAt: String
}

struct BackupMetadata: Codable {
    let appVersion: String
    let deviceInfo: String?
    let totalProducts: Int
    let totalCategories: Int
}
