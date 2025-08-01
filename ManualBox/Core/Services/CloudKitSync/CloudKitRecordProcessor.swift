//
//  CloudKitRecordProcessor.swift
//  ManualBox
//
//  Created by Assistant on 2024/12/19.
//

import Foundation
import CloudKit
import CoreData

// MARK: - 记录处理器
class CloudKitRecordProcessor {
    private let context: NSManagedObjectContext
    private let conflictResolver: CloudKitConflictResolver
    
    init(context: NSManagedObjectContext) {
        self.context = context
        self.conflictResolver = CloudKitConflictResolver(context: context)
    }
    
    // MARK: - 记录处理
    
    func processChangedRecord(_ record: CKRecord) {
        print("📝 处理变更记录: \(record.recordType) - \(record.recordID.recordName)")
        
        switch record.recordType {
        case "Product":
            processProductRecord(record)
        case "Manual":
            processManualRecord(record)
        case "Category":
            processCategoryRecord(record)
        default:
            print("⚠️ 未知记录类型: \(record.recordType)")
        }
    }
    
    func processDeletedRecord(recordID: CKRecord.ID, recordType: String) {
        print("🗑️ 处理删除记录: \(recordType) - \(recordID.recordName)")
        
        switch recordType {
        case "Product":
            deleteProductRecord(recordID: recordID)
        case "Manual":
            deleteManualRecord(recordID: recordID)
        case "Category":
            deleteCategoryRecord(recordID: recordID)
        default:
            print("⚠️ 未知删除记录类型: \(recordType)")
        }
    }
    
    // MARK: - Product记录处理
    
    private func processProductRecord(_ record: CKRecord) {
        let request: NSFetchRequest<Product> = Product.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", UUID(uuidString: record.recordID.recordName) ?? UUID() as UUID)
        
        do {
            let existingProducts = try context.fetch(request)
            
            if let existingProduct = existingProducts.first {
                // 检查冲突
                if hasConflict(existingProduct: existingProduct, cloudRecord: record) {
                    let localRecord = createCKRecord(from: existingProduct)
                    let resolvedRecord = conflictResolver.resolveConflict(
                        localRecord: localRecord,
                        serverRecord: record,
                        strategy: .lastModifiedWins
                    )
                    updateProduct(existingProduct, with: resolvedRecord)
                } else {
                    updateProduct(existingProduct, with: record)
                }
            } else {
                createProduct(from: record)
            }
            
            try context.save()
            print("✅ Product记录处理完成: \(record.recordID.recordName)")
            
        } catch {
            print("❌ Product记录处理失败: \(error)")
        }
    }
    
    private func createProduct(from record: CKRecord) {
        let product = Product(context: context)
        updateProduct(product, with: record)
        print("➕ 创建新Product: \(record.recordID.recordName)")
    }
    
    private func updateProduct(_ product: Product, with record: CKRecord) {
        // 只使用 Core Data 模型中实际存在的属性
        product.name = record["name"] as? String ?? ""
        product.brand = record["brand"] as? String
        product.model = record["model"] as? String
        product.notes = record["notes"] as? String
        product.updatedAt = record.modificationDate ?? Date()
        
        // 处理图片
        if let imageAsset = record["image"] as? CKAsset,
           let imageURL = imageAsset.fileURL {
            updateProductImage(product, with: imageURL)
        }
    }
    
    private func updateProductImage(_ product: Product, with imageURL: URL) {
        do {
            let imageData = try Data(contentsOf: imageURL)
            product.imageData = imageData
            print("📷 更新产品图片: \(product.name ?? "未知")")
        } catch {
            print("❌ 读取产品图片失败: \(error)")
        }
    }
    
    private func deleteProductRecord(recordID: CKRecord.ID) {
        let request: NSFetchRequest<Product> = Product.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", UUID(uuidString: recordID.recordName) ?? UUID() as UUID)
        
        do {
            let products = try context.fetch(request)
            for product in products {
                context.delete(product)
                print("🗑️ 删除Product: \(product.name ?? recordID.recordName)")
            }
            try context.save()
        } catch {
            print("❌ 删除Product记录失败: \(error)")
        }
    }
    
    // MARK: - Manual记录处理
    
    private func processManualRecord(_ record: CKRecord) {
        let request: NSFetchRequest<Manual> = Manual.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", UUID(uuidString: record.recordID.recordName) ?? UUID())
        
        do {
            let existingManuals = try context.fetch(request)
            
            if let existingManual = existingManuals.first {
                updateManual(existingManual, with: record)
            } else {
                createManual(from: record)
            }
            
            try context.save()
            print("✅ Manual记录处理完成: \(record.recordID.recordName)")
            
        } catch {
            print("❌ Manual记录处理失败: \(error)")
        }
    }
    
    private func createManual(from record: CKRecord) {
        let manual = Manual(context: context)
        updateManual(manual, with: record)
        print("➕ 创建新Manual: \(record.recordID.recordName)")
    }
    
    private func updateManual(_ manual: Manual, with record: CKRecord) {
        // 只使用 Core Data 模型中实际存在的属性
        manual.fileName = record["fileName"] as? String
        manual.fileType = record["fileType"] as? String
        manual.content = record["content"] as? String
        
        // 处理文件
        if let fileAsset = record["fileData"] as? CKAsset,
           let fileURL = fileAsset.fileURL {
            updateManualFile(manual, with: fileURL)
        }
    }
    
    private func updateManualFile(_ manual: Manual, with fileURL: URL) {
        do {
            let fileData = try Data(contentsOf: fileURL)
            manual.fileData = fileData
            print("📄 更新手册文件: \(manual.fileName ?? "未知")")
        } catch {
            print("❌ 读取手册文件失败: \(error)")
        }
    }
    
    private func deleteManualRecord(recordID: CKRecord.ID) {
        let request: NSFetchRequest<Manual> = Manual.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", UUID(uuidString: recordID.recordName) ?? UUID() as UUID)
        
        do {
            let manuals = try context.fetch(request)
            for manual in manuals {
                context.delete(manual)
                print("🗑️ 删除Manual: \(manual.fileName ?? recordID.recordName)")
            }
            try context.save()
        } catch {
            print("❌ 删除Manual记录失败: \(error)")
        }
    }
    
    // MARK: - Category记录处理
    
    private func processCategoryRecord(_ record: CKRecord) {
        // 类似的处理逻辑
        print("📂 处理Category记录: \(record.recordID.recordName)")
    }
    
    private func deleteCategoryRecord(recordID: CKRecord.ID) {
        print("🗑️ 删除Category记录: \(recordID.recordName)")
    }
    
    // MARK: - 冲突检测
    
    private func hasConflict(existingProduct: Product, cloudRecord: CKRecord) -> Bool {
        // 检查本地修改时间是否晚于云端记录的修改时间
        guard let localModified = existingProduct.updatedAt,
              let cloudModified = cloudRecord.modificationDate else {
            return false
        }
        
        // 如果本地修改时间晚于云端，则存在冲突
        return localModified > cloudModified
    }
    
    // MARK: - 记录创建
    
    private func createCKRecord(from product: Product) -> CKRecord? {
        guard let productId = product.id else { return nil }
        
        let record = CKRecord(
            recordType: "Product",
            recordID: CKRecord.ID(recordName: productId.uuidString)
        )
        
        record["name"] = product.name as CKRecordValue?
        record["brand"] = product.brand as CKRecordValue?
        record["model"] = product.model as CKRecordValue?
        record["notes"] = product.notes as CKRecordValue?
        
        return record
    }
}