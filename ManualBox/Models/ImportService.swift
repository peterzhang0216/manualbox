import Foundation
import CoreData
import SwiftUI

class ImportService {
    // 从CSV文件导入数据
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
    
    // 从JSON文件导入数据
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
            }
        }
    }
}

// 导入数据模型
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
