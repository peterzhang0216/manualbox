//
//  DataValidationService.swift
//  ManualBox
//
//  Created by Assistant on 2025/6/17.
//

import Foundation
import CoreData

/// 数据验证服务 - 防止重复数据和维护数据完整性
class DataValidationService {
    private let context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    /// 验证结果
    struct ValidationResult {
        let isValid: Bool
        let errors: [ValidationError]
        let warnings: [ValidationWarning]
        
        var hasErrors: Bool { !errors.isEmpty }
        var hasWarnings: Bool { !warnings.isEmpty }
        
        var summary: String {
            if isValid && !hasWarnings {
                return "数据验证通过"
            }
            
            var messages: [String] = []
            if hasErrors {
                messages.append("错误: \(errors.count) 个")
            }
            if hasWarnings {
                messages.append("警告: \(warnings.count) 个")
            }
            
            return messages.joined(separator: ", ")
        }
    }
    
    /// 验证错误
    struct ValidationError {
        let type: ErrorType
        let message: String
        let entityName: String?
        let entityId: UUID?
        
        enum ErrorType {
            case duplicateName
            case missingRequiredField
            case invalidRelationship
            case dataCorruption
        }
    }
    
    /// 验证警告
    struct ValidationWarning {
        let type: WarningType
        let message: String
        let entityName: String?
        let entityId: UUID?
        
        enum WarningType {
            case emptyEntity
            case unusedEntity
            case potentialDuplicate
            case missingOptionalData
        }
    }
    
    /// 验证分类名称是否唯一
    func validateCategoryName(_ name: String, excludingId: UUID? = nil) -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedName.isEmpty else { return false }
        
        let request: NSFetchRequest<Category> = Category.fetchRequest()
        var predicateFormat = "name ==[cd] %@"
        var arguments: [Any] = [trimmedName]
        
        if let excludingId = excludingId {
            predicateFormat += " AND id != %@"
            arguments.append(excludingId)
        }
        
        request.predicate = NSPredicate(format: predicateFormat, argumentArray: arguments)
        
        do {
            let existingCategories = try context.fetch(request)
            return existingCategories.isEmpty
        } catch {
            print("[DataValidation] 验证分类名称时出错: \(error.localizedDescription)")
            return false
        }
    }
    
    /// 验证标签名称是否唯一
    func validateTagName(_ name: String, excludingId: UUID? = nil) -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedName.isEmpty else { return false }
        
        let request: NSFetchRequest<Tag> = Tag.fetchRequest()
        var predicateFormat = "name ==[cd] %@"
        var arguments: [Any] = [trimmedName]
        
        if let excludingId = excludingId {
            predicateFormat += " AND id != %@"
            arguments.append(excludingId)
        }
        
        request.predicate = NSPredicate(format: predicateFormat, argumentArray: arguments)
        
        do {
            let existingTags = try context.fetch(request)
            return existingTags.isEmpty
        } catch {
            print("[DataValidation] 验证标签名称时出错: \(error.localizedDescription)")
            return false
        }
    }
    
    /// 验证产品数据完整性
    func validateProduct(_ product: Product) -> ValidationResult {
        var errors: [ValidationError] = []
        var warnings: [ValidationWarning] = []
        
        // 检查必需字段
        if product.name?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true {
            errors.append(ValidationError(
                type: .missingRequiredField,
                message: "产品名称不能为空",
                entityName: "Product",
                entityId: product.id
            ))
        }
        
        // 检查分类关联
        if product.category == nil {
            warnings.append(ValidationWarning(
                type: .missingOptionalData,
                message: "产品没有分配分类",
                entityName: "Product",
                entityId: product.id
            ))
        }
        
        // 检查重复产品名称（在同一分类下）
        if let productName = product.name?.trimmingCharacters(in: .whitespacesAndNewlines),
           !productName.isEmpty,
           let category = product.category {
            
            let request: NSFetchRequest<Product> = Product.fetchRequest()
            let productId = product.id ?? UUID()
            request.predicate = NSPredicate(
                format: "name ==[cd] %@ AND category == %@ AND id != %@",
                productName, category, productId as CVarArg
            )
            
            do {
                let duplicates = try context.fetch(request)
                if !duplicates.isEmpty {
                    errors.append(ValidationError(
                        type: .duplicateName,
                        message: "在分类 '\(category.name ?? "")' 中已存在同名产品",
                        entityName: "Product",
                        entityId: product.id
                    ))
                }
            } catch {
                print("[DataValidation] 检查重复产品时出错: \(error.localizedDescription)")
            }
        }
        
        return ValidationResult(
            isValid: errors.isEmpty,
            errors: errors,
            warnings: warnings
        )
    }
    
    /// 执行完整的数据验证
    func performCompleteValidation() async -> ValidationResult {
        return await withCheckedContinuation { continuation in
            context.perform {
                var allErrors: [ValidationError] = []
                var allWarnings: [ValidationWarning] = []
                
                // 验证分类
                let categoryValidation = self.validateAllCategories()
                allErrors.append(contentsOf: categoryValidation.errors)
                allWarnings.append(contentsOf: categoryValidation.warnings)
                
                // 验证标签
                let tagValidation = self.validateAllTags()
                allErrors.append(contentsOf: tagValidation.errors)
                allWarnings.append(contentsOf: tagValidation.warnings)
                
                // 验证产品
                let productValidation = self.validateAllProducts()
                allErrors.append(contentsOf: productValidation.errors)
                allWarnings.append(contentsOf: productValidation.warnings)
                
                // 验证关系完整性
                let relationshipValidation = self.validateRelationships()
                allErrors.append(contentsOf: relationshipValidation.errors)
                allWarnings.append(contentsOf: relationshipValidation.warnings)
                
                let result = ValidationResult(
                    isValid: allErrors.isEmpty,
                    errors: allErrors,
                    warnings: allWarnings
                )
                
                continuation.resume(returning: result)
            }
        }
    }
    
    // MARK: - Private Validation Methods
    
    private func validateAllCategories() -> ValidationResult {
        var errors: [ValidationError] = []
        var warnings: [ValidationWarning] = []
        
        let request: NSFetchRequest<Category> = Category.fetchRequest()
        
        do {
            let categories = try context.fetch(request)
            var nameCount: [String: Int] = [:]
            
            for category in categories {
                let name = category.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                
                // 检查空名称
                if name.isEmpty {
                    errors.append(ValidationError(
                        type: .missingRequiredField,
                        message: "分类名称不能为空",
                        entityName: "Category",
                        entityId: category.id
                    ))
                    continue
                }
                
                // 统计重复名称
                nameCount[name, default: 0] += 1
                
                // 检查空分类
                if (category.products as? Set<Product>)?.isEmpty ?? true {
                    warnings.append(ValidationWarning(
                        type: .emptyEntity,
                        message: "分类 '\(name)' 没有产品",
                        entityName: "Category",
                        entityId: category.id
                    ))
                }
            }
            
            // 添加重复名称错误
            for (name, count) in nameCount where count > 1 {
                errors.append(ValidationError(
                    type: .duplicateName,
                    message: "分类名称 '\(name)' 重复 \(count) 次",
                    entityName: "Category",
                    entityId: nil
                ))
            }
            
        } catch {
            errors.append(ValidationError(
                type: .dataCorruption,
                message: "无法获取分类数据: \(error.localizedDescription)",
                entityName: "Category",
                entityId: nil
            ))
        }
        
        return ValidationResult(isValid: errors.isEmpty, errors: errors, warnings: warnings)
    }
    
    private func validateAllTags() -> ValidationResult {
        var errors: [ValidationError] = []
        var warnings: [ValidationWarning] = []
        
        let request: NSFetchRequest<Tag> = Tag.fetchRequest()
        
        do {
            let tags = try context.fetch(request)
            var nameCount: [String: Int] = [:]
            
            for tag in tags {
                let name = tag.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                
                // 检查空名称
                if name.isEmpty {
                    errors.append(ValidationError(
                        type: .missingRequiredField,
                        message: "标签名称不能为空",
                        entityName: "Tag",
                        entityId: tag.id
                    ))
                    continue
                }
                
                // 统计重复名称
                nameCount[name, default: 0] += 1
                
                // 检查空标签
                if (tag.products as? Set<Product>)?.isEmpty ?? true {
                    warnings.append(ValidationWarning(
                        type: .emptyEntity,
                        message: "标签 '\(name)' 没有产品",
                        entityName: "Tag",
                        entityId: tag.id
                    ))
                }
            }
            
            // 添加重复名称错误
            for (name, count) in nameCount where count > 1 {
                errors.append(ValidationError(
                    type: .duplicateName,
                    message: "标签名称 '\(name)' 重复 \(count) 次",
                    entityName: "Tag",
                    entityId: nil
                ))
            }
            
        } catch {
            errors.append(ValidationError(
                type: .dataCorruption,
                message: "无法获取标签数据: \(error.localizedDescription)",
                entityName: "Tag",
                entityId: nil
            ))
        }
        
        return ValidationResult(isValid: errors.isEmpty, errors: errors, warnings: warnings)
    }
    
    private func validateAllProducts() -> ValidationResult {
        var errors: [ValidationError] = []
        var warnings: [ValidationWarning] = []
        
        let request: NSFetchRequest<Product> = Product.fetchRequest()
        
        do {
            let products = try context.fetch(request)
            
            for product in products {
                let productValidation = validateProduct(product)
                errors.append(contentsOf: productValidation.errors)
                warnings.append(contentsOf: productValidation.warnings)
            }
            
        } catch {
            errors.append(ValidationError(
                type: .dataCorruption,
                message: "无法获取产品数据: \(error.localizedDescription)",
                entityName: "Product",
                entityId: nil
            ))
        }
        
        return ValidationResult(isValid: errors.isEmpty, errors: errors, warnings: warnings)
    }
    
    private func validateRelationships() -> ValidationResult {
        var errors: [ValidationError] = []
        let warnings: [ValidationWarning] = []
        
        // 检查孤立的订单
        let orphanedOrdersRequest: NSFetchRequest<Order> = Order.fetchRequest()
        orphanedOrdersRequest.predicate = NSPredicate(format: "product == nil")
        
        do {
            let orphanedOrders = try context.fetch(orphanedOrdersRequest)
            for order in orphanedOrders {
                errors.append(ValidationError(
                    type: .invalidRelationship,
                    message: "订单没有关联的产品",
                    entityName: "Order",
                    entityId: order.id
                ))
            }
        } catch {
            print("[DataValidation] 检查孤立订单时出错: \(error.localizedDescription)")
        }
        
        // 检查孤立的说明书
        let orphanedManualsRequest: NSFetchRequest<Manual> = Manual.fetchRequest()
        orphanedManualsRequest.predicate = NSPredicate(format: "product == nil")
        
        do {
            let orphanedManuals = try context.fetch(orphanedManualsRequest)
            for manual in orphanedManuals {
                errors.append(ValidationError(
                    type: .invalidRelationship,
                    message: "说明书没有关联的产品",
                    entityName: "Manual",
                    entityId: manual.id
                ))
            }
        } catch {
            print("[DataValidation] 检查孤立说明书时出错: \(error.localizedDescription)")
        }
        
        return ValidationResult(isValid: errors.isEmpty, errors: errors, warnings: warnings)
    }
}

// MARK: - PersistenceController Extension
extension PersistenceController {
    /// 获取数据验证服务
    var validationService: DataValidationService {
        DataValidationService(context: container.viewContext)
    }
    
    /// 执行完整数据验证
    func performDataValidation() async -> DataValidationService.ValidationResult {
        return await validationService.performCompleteValidation()
    }
    
    /// 验证分类名称唯一性
    func validateCategoryName(_ name: String, excludingId: UUID? = nil) -> Bool {
        return validationService.validateCategoryName(name, excludingId: excludingId)
    }
    
    /// 验证标签名称唯一性
    func validateTagName(_ name: String, excludingId: UUID? = nil) -> Bool {
        return validationService.validateTagName(name, excludingId: excludingId)
    }
}
