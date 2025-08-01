//
//  DataValidator.swift
//  ManualBox
//
//  Created by AI Assistant on 2025/7/22.
//

import Foundation
import CoreData
import Combine

// MARK: - 数据验证器协议
protocol DataValidator {
    func validate<T: NSManagedObject>(_ object: T) -> ValidationResult
    func validateRelationships<T: NSManagedObject>(_ object: T) -> ValidationResult
    func validateConstraints<T: NSManagedObject>(_ object: T) -> ValidationResult
    nonisolated func performBatchValidation<T: NSManagedObject>(_ objects: [T]) async -> BatchValidationResult
    nonisolated func validateDataIntegrity() async -> DataIntegrityResult
}

// MARK: - 验证结果
struct ValidationResult {
    let isValid: Bool
    let errors: [ValidationError]
    let warnings: [ValidationWarning]
    let suggestions: [ValidationSuggestion]
    let validatedAt: Date
    let validationDuration: TimeInterval
    
    var hasErrors: Bool { !errors.isEmpty }
    var hasWarnings: Bool { !warnings.isEmpty }
    var hasSuggestions: Bool { !suggestions.isEmpty }
    
    var summary: String {
        if isValid && !hasWarnings {
            return "验证通过"
        }
        
        var components: [String] = []
        if hasErrors {
            components.append("错误: \(errors.count)")
        }
        if hasWarnings {
            components.append("警告: \(warnings.count)")
        }
        if hasSuggestions {
            components.append("建议: \(suggestions.count)")
        }
        
        return components.joined(separator: ", ")
    }
}

// MARK: - 批量验证结果
struct BatchValidationResult {
    let totalObjects: Int
    let validObjects: Int
    let invalidObjects: Int
    let results: [ValidationResult]
    let processingTime: TimeInterval
    let memoryUsage: Int64
    
    var successRate: Double {
        guard totalObjects > 0 else { return 0 }
        return Double(validObjects) / Double(totalObjects)
    }
    
    var allErrors: [ValidationError] {
        results.flatMap { $0.errors }
    }
    
    var allWarnings: [ValidationWarning] {
        results.flatMap { $0.warnings }
    }
}

// MARK: - 数据完整性结果
struct DataIntegrityResult {
    let isHealthy: Bool
    let issues: [DataIntegrityIssue]
    let statistics: DataStatistics
    let recommendations: [DataIntegrityRecommendation]
    let checkedAt: Date
    
    struct DataStatistics {
        let totalEntities: Int
        let orphanedEntities: Int
        let duplicateEntities: Int
        let corruptedEntities: Int
        let relationshipIssues: Int
        let constraintViolations: Int
    }
    
    struct DataIntegrityIssue {
        let type: IssueType
        let severity: Severity
        let entityType: String
        let entityId: UUID?
        let description: String
        let affectedCount: Int
        
        enum IssueType {
            case orphanedRecord
            case duplicateRecord
            case corruptedData
            case brokenRelationship
            case constraintViolation
            case inconsistentState
        }
        
        enum Severity {
            case low, medium, high, critical
            
            var description: String {
                switch self {
                case .low: return "低"
                case .medium: return "中"
                case .high: return "高"
                case .critical: return "严重"
                }
            }
        }
    }
    
    struct DataIntegrityRecommendation {
        let priority: Priority
        let title: String
        let description: String
        let actionItems: [String]
        let estimatedImpact: String
        
        enum Priority {
            case low, medium, high, urgent
        }
    }
}

// MARK: - 验证错误
struct ValidationError {
    let id: UUID
    let type: ErrorType
    let severity: Severity
    let message: String
    let entityType: String
    let entityId: UUID?
    let fieldName: String?
    let context: [String: Any]
    let timestamp: Date
    
    enum ErrorType {
        case missingRequiredField
        case invalidFormat
        case duplicateValue
        case constraintViolation
        case relationshipError
        case dataCorruption
        case businessRuleViolation
    }
    
    enum Severity {
        case info, warning, error, critical
        
        var description: String {
            switch self {
            case .info: return "信息"
            case .warning: return "警告"
            case .error: return "错误"
            case .critical: return "严重"
            }
        }
    }
    
    init(type: ErrorType, severity: Severity = .error, message: String, entityType: String, entityId: UUID? = nil, fieldName: String? = nil, context: [String: Any] = [:]) {
        self.id = UUID()
        self.type = type
        self.severity = severity
        self.message = message
        self.entityType = entityType
        self.entityId = entityId
        self.fieldName = fieldName
        self.context = context
        self.timestamp = Date()
    }
}

// MARK: - 验证警告
struct ValidationWarning {
    let id: UUID
    let type: WarningType
    let message: String
    let entityType: String
    let entityId: UUID?
    let recommendation: String?
    let timestamp: Date
    
    enum WarningType {
        case emptyOptionalField
        case unusedEntity
        case potentialDuplicate
        case performanceImpact
        case dataQualityIssue
    }
    
    init(type: WarningType, message: String, entityType: String, entityId: UUID? = nil, recommendation: String? = nil) {
        self.id = UUID()
        self.type = type
        self.message = message
        self.entityType = entityType
        self.entityId = entityId
        self.recommendation = recommendation
        self.timestamp = Date()
    }
}

// MARK: - 验证建议
struct ValidationSuggestion {
    let id: UUID
    let type: SuggestionType
    let title: String
    let description: String
    let priority: Priority
    let estimatedBenefit: String
    let actionRequired: String
    
    enum SuggestionType {
        case optimization
        case cleanup
        case enhancement
        case maintenance
    }
    
    enum Priority {
        case low, medium, high
    }
    
    init(type: SuggestionType, title: String, description: String, priority: Priority = .medium, estimatedBenefit: String = "", actionRequired: String = "") {
        self.id = UUID()
        self.type = type
        self.title = title
        self.description = description
        self.priority = priority
        self.estimatedBenefit = estimatedBenefit
        self.actionRequired = actionRequired
    }
}

// MARK: - 数据验证器实现
@MainActor
class ManualBoxDataValidator: DataValidator, ObservableObject {
    static let shared = ManualBoxDataValidator()
    
    @Published var isValidating = false
    @Published var validationProgress: Double = 0.0
    @Published var lastValidationResult: DataIntegrityResult?
    
    private let context: NSManagedObjectContext
    private let performanceMonitor: ManualBoxPerformanceMonitoringService
    private let errorHandler: ManualBoxErrorHandlingService
    
    // 验证规则缓存
    private var validationRules: [String: [ValidationRule]] = [:]
    
    private init() {
        self.context = PersistenceController.shared.container.viewContext
        self.performanceMonitor = ManualBoxPerformanceMonitoringService.shared
        self.errorHandler = ManualBoxErrorHandlingService.shared
        
        setupValidationRules()
    }
    
    // MARK: - 公共接口实现
    
    func validate<T: NSManagedObject>(_ object: T) -> ValidationResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        let token = performanceMonitor.startOperation("data_validation", category: .database)
        defer { performanceMonitor.endOperation(token) }
        
        var errors: [ValidationError] = []
        var warnings: [ValidationWarning] = []
        var suggestions: [ValidationSuggestion] = []
        
        let entityName = String(describing: type(of: object))
        
        // 基础字段验证
        let fieldValidation = validateFields(object)
        errors.append(contentsOf: fieldValidation.errors)
        warnings.append(contentsOf: fieldValidation.warnings)
        
        // 约束验证
        let constraintValidation = validateConstraints(object)
        errors.append(contentsOf: constraintValidation.errors)
        warnings.append(contentsOf: constraintValidation.warnings)
        
        // 关系验证
        let relationshipValidation = validateRelationships(object)
        errors.append(contentsOf: relationshipValidation.errors)
        warnings.append(contentsOf: relationshipValidation.warnings)
        
        // 业务规则验证
        let businessValidation = validateBusinessRules(object)
        errors.append(contentsOf: businessValidation.errors)
        warnings.append(contentsOf: businessValidation.warnings)
        suggestions.append(contentsOf: businessValidation.suggestions)
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime
        
        return ValidationResult(
            isValid: errors.isEmpty,
            errors: errors,
            warnings: warnings,
            suggestions: suggestions,
            validatedAt: Date(),
            validationDuration: duration
        )
    }
    
    func validateRelationships<T: NSManagedObject>(_ object: T) -> ValidationResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        var errors: [ValidationError] = []
        var warnings: [ValidationWarning] = []
        
        let entityName = String(describing: type(of: object))
        let entity = object.entity
        
        // 检查所有关系
        for relationship in entity.relationshipsByName {
            let relationshipName = relationship.key
            let relationshipDescription = relationship.value
            
            if relationshipDescription.isToMany {
                // 一对多或多对多关系
                if let relatedObjects = object.value(forKey: relationshipName) as? Set<NSManagedObject> {
                    // 检查关系完整性
                    for relatedObject in relatedObjects {
                        if relatedObject.isDeleted {
                            errors.append(ValidationError(
                                type: .relationshipError,
                                message: "关系 '\(relationshipName)' 包含已删除的对象",
                                entityType: entityName,
                                entityId: getObjectId(object),
                                fieldName: relationshipName
                            ))
                        }
                    }
                    
                    // 检查最小/最大数量约束
                    if relationshipDescription.minCount > 0 && relatedObjects.count < relationshipDescription.minCount {
                        errors.append(ValidationError(
                            type: .constraintViolation,
                            message: "关系 '\(relationshipName)' 数量不足，最少需要 \(relationshipDescription.minCount) 个",
                            entityType: entityName,
                            entityId: getObjectId(object),
                            fieldName: relationshipName
                        ))
                    }
                    
                    if relationshipDescription.maxCount > 0 && relatedObjects.count > relationshipDescription.maxCount {
                        errors.append(ValidationError(
                            type: .constraintViolation,
                            message: "关系 '\(relationshipName)' 数量超限，最多允许 \(relationshipDescription.maxCount) 个",
                            entityType: entityName,
                            entityId: getObjectId(object),
                            fieldName: relationshipName
                        ))
                    }
                }
            } else {
                // 一对一关系
                if let relatedObject = object.value(forKey: relationshipName) as? NSManagedObject {
                    if relatedObject.isDeleted {
                        errors.append(ValidationError(
                            type: .relationshipError,
                            message: "关系 '\(relationshipName)' 指向已删除的对象",
                            entityType: entityName,
                            entityId: getObjectId(object),
                            fieldName: relationshipName
                        ))
                    }
                } else if !relationshipDescription.isOptional {
                    errors.append(ValidationError(
                        type: .missingRequiredField,
                        message: "必需的关系 '\(relationshipName)' 为空",
                        entityType: entityName,
                        entityId: getObjectId(object),
                        fieldName: relationshipName
                    ))
                }
            }
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime
        
        return ValidationResult(
            isValid: errors.isEmpty,
            errors: errors,
            warnings: warnings,
            suggestions: [],
            validatedAt: Date(),
            validationDuration: duration
        )
    }
    
    func validateConstraints<T: NSManagedObject>(_ object: T) -> ValidationResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        var errors: [ValidationError] = []
        var warnings: [ValidationWarning] = []
        
        let entityName = String(describing: type(of: object))
        let entity = object.entity
        
        // 检查属性约束
        for attribute in entity.attributesByName {
            let attributeName = attribute.key
            let attributeDescription = attribute.value
            let value = object.value(forKey: attributeName)
            
            // 检查必需字段
            if !attributeDescription.isOptional && (value == nil || isEmptyValue(value)) {
                errors.append(ValidationError(
                    type: .missingRequiredField,
                    message: "必需字段 '\(attributeName)' 为空",
                    entityType: entityName,
                    entityId: getObjectId(object),
                    fieldName: attributeName
                ))
                continue
            }
            
            guard let value = value else { continue }
            
            // 类型特定验证
            switch attributeDescription.attributeType {
            case .stringAttributeType:
                if let stringValue = value as? String {
                    validateStringConstraints(stringValue, attribute: attributeDescription, attributeName: attributeName, object: object, errors: &errors, warnings: &warnings)
                }
            case .integer16AttributeType, .integer32AttributeType, .integer64AttributeType:
                if let numberValue = value as? NSNumber {
                    validateNumberConstraints(numberValue, attribute: attributeDescription, attributeName: attributeName, object: object, errors: &errors, warnings: &warnings)
                }
            case .doubleAttributeType, .floatAttributeType, .decimalAttributeType:
                if let numberValue = value as? NSNumber {
                    validateNumberConstraints(numberValue, attribute: attributeDescription, attributeName: attributeName, object: object, errors: &errors, warnings: &warnings)
                }
            case .dateAttributeType:
                if let dateValue = value as? Date {
                    validateDateConstraints(dateValue, attribute: attributeDescription, attributeName: attributeName, object: object, errors: &errors, warnings: &warnings)
                }
            default:
                break
            }
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime
        
        return ValidationResult(
            isValid: errors.isEmpty,
            errors: errors,
            warnings: warnings,
            suggestions: [],
            validatedAt: Date(),
            validationDuration: duration
        )
    }
    
    nonisolated func performBatchValidation<T: NSManagedObject>(_ objects: [T]) async -> BatchValidationResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        let startMemory = MemoryManager.getCurrentMemoryUsage().physical
        
        await MainActor.run {
            isValidating = true
            validationProgress = 0.0
        }
        
        var results: [ValidationResult] = []
        var validCount = 0
        
        let batchSize = 100 // 批量处理大小
        let totalBatches = (objects.count + batchSize - 1) / batchSize
        
        for (batchIndex, batch) in objects.chunked(into: batchSize).enumerated() {
            let batchResults = await processBatch(batch)
            results.append(contentsOf: batchResults)
            
            validCount += batchResults.filter { $0.isValid }.count
            
            // 更新进度
            await MainActor.run {
                validationProgress = Double(batchIndex + 1) / Double(totalBatches)
            }
            
            // 内存压力检查
            let currentMemory = MemoryManager.getCurrentMemoryUsage().physical
            if currentMemory > startMemory * 2 {
                await MemoryManager.shared.clearCache()
            }
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let endMemory = MemoryManager.getCurrentMemoryUsage().physical
        
        await MainActor.run {
            isValidating = false
            validationProgress = 1.0
        }
        
        return BatchValidationResult(
            totalObjects: objects.count,
            validObjects: validCount,
            invalidObjects: objects.count - validCount,
            results: results,
            processingTime: endTime - startTime,
            memoryUsage: endMemory - startMemory
        )
    }
    
    nonisolated func validateDataIntegrity() async -> DataIntegrityResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        let token = performanceMonitor.startOperation("data_integrity_check", category: .database)
        defer { performanceMonitor.endOperation(token) }
        
        await MainActor.run {
            isValidating = true
            validationProgress = 0.0
        }
        
        var issues: [DataIntegrityResult.DataIntegrityIssue] = []
        var statistics = DataIntegrityResult.DataStatistics(
            totalEntities: 0,
            orphanedEntities: 0,
            duplicateEntities: 0,
            corruptedEntities: 0,
            relationshipIssues: 0,
            constraintViolations: 0
        )
        
        // 检查各种数据完整性问题
        let orphanedIssues = await checkOrphanedRecords()
        issues.append(contentsOf: orphanedIssues)
        statistics.orphanedEntities = orphanedIssues.count
        await MainActor.run {
            validationProgress = 0.2
        }
        
        let duplicateIssues = await checkDuplicateRecords()
        issues.append(contentsOf: duplicateIssues)
        statistics.duplicateEntities = duplicateIssues.count
        await MainActor.run {
            validationProgress = 0.4
        }
        
        let relationshipIssues = await checkRelationshipIntegrity()
        issues.append(contentsOf: relationshipIssues)
        statistics.relationshipIssues = relationshipIssues.count
        await MainActor.run {
            validationProgress = 0.6
        }
        
        let constraintIssues = await checkConstraintViolations()
        issues.append(contentsOf: constraintIssues)
        statistics.constraintViolations = constraintIssues.count
        await MainActor.run {
            validationProgress = 0.8
        }
        
        let corruptionIssues = await checkDataCorruption()
        issues.append(contentsOf: corruptionIssues)
        statistics.corruptedEntities = corruptionIssues.count
        await MainActor.run {
            validationProgress = 1.0
        }
        
        // 计算总实体数
        statistics.totalEntities = await getTotalEntityCount()
        
        // 生成建议
        let recommendations = generateIntegrityRecommendations(from: issues)
        
        await MainActor.run {
            isValidating = false
        }
        
        let result = DataIntegrityResult(
            isHealthy: issues.filter { $0.severity == .high || $0.severity == .critical }.isEmpty,
            issues: issues,
            statistics: statistics,
            recommendations: recommendations,
            checkedAt: Date()
        )
        
        await MainActor.run {
            lastValidationResult = result
        }
        return result
    }
    
    // MARK: - 私有方法
    
    private func setupValidationRules() {
        // 设置产品验证规则
        validationRules["Product"] = [
            ValidationRule(field: "name", type: .required, message: "产品名称不能为空"),
            ValidationRule(field: "name", type: .minLength(1), message: "产品名称不能为空"),
            ValidationRule(field: "name", type: .maxLength(100), message: "产品名称过长"),
            ValidationRule(field: "brand", type: .maxLength(50), message: "品牌名称过长"),
            ValidationRule(field: "model", type: .maxLength(50), message: "型号过长")
        ]
        
        // 设置分类验证规则
        validationRules["Category"] = [
            ValidationRule(field: "name", type: .required, message: "分类名称不能为空"),
            ValidationRule(field: "name", type: .unique, message: "分类名称已存在"),
            ValidationRule(field: "name", type: .maxLength(30), message: "分类名称过长")
        ]
        
        // 设置标签验证规则
        validationRules["Tag"] = [
            ValidationRule(field: "name", type: .required, message: "标签名称不能为空"),
            ValidationRule(field: "name", type: .unique, message: "标签名称已存在"),
            ValidationRule(field: "name", type: .maxLength(20), message: "标签名称过长")
        ]
    }
    
    private func validateFields<T: NSManagedObject>(_ object: T) -> (errors: [ValidationError], warnings: [ValidationWarning]) {
        var errors: [ValidationError] = []
        var warnings: [ValidationWarning] = []
        
        let entityName = String(describing: type(of: object))
        guard let rules = validationRules[entityName] else { return (errors, warnings) }
        
        for rule in rules {
            let value = object.value(forKey: rule.field)
            let validationResult = rule.validate(value, object: object, context: context)
            
            if let error = validationResult.error {
                errors.append(ValidationError(
                    type: error.type,
                    severity: error.severity,
                    message: error.message,
                    entityType: entityName,
                    entityId: getObjectId(object),
                    fieldName: rule.field
                ))
            }
            
            if let warning = validationResult.warning {
                warnings.append(ValidationWarning(
                    type: warning.type,
                    message: warning.message,
                    entityType: entityName,
                    entityId: getObjectId(object),
                    recommendation: warning.recommendation
                ))
            }
        }
        
        return (errors, warnings)
    }
    
    private func validateBusinessRules<T: NSManagedObject>(_ object: T) -> (errors: [ValidationError], warnings: [ValidationWarning], suggestions: [ValidationSuggestion]) {
        var errors: [ValidationError] = []
        var warnings: [ValidationWarning] = []
        var suggestions: [ValidationSuggestion] = []
        
        let entityName = String(describing: type(of: object))
        
        // 产品特定的业务规则
        if let product = object as? Product {
            // 检查产品是否有分类
            if product.category == nil {
                warnings.append(ValidationWarning(
                    type: .dataQualityIssue,
                    message: "产品未分配分类",
                    entityType: entityName,
                    entityId: product.id,
                    recommendation: "为产品分配合适的分类以便更好地组织"
                ))
                
                suggestions.append(ValidationSuggestion(
                    type: .enhancement,
                    title: "分配产品分类",
                    description: "为产品分配分类可以提高数据组织性和搜索效率",
                    priority: .medium,
                    estimatedBenefit: "提高数据组织性",
                    actionRequired: "选择合适的分类"
                ))
            }
            
            // 检查产品是否有标签
            if (product.tags as? Set<Tag>)?.isEmpty ?? true {
                suggestions.append(ValidationSuggestion(
                    type: .enhancement,
                    title: "添加产品标签",
                    description: "添加标签可以提高产品的可发现性",
                    priority: .low,
                    estimatedBenefit: "提高搜索效率",
                    actionRequired: "添加相关标签"
                ))
            }
        }
        
        return (errors, warnings, suggestions)
    }
    
    private func processBatch<T: NSManagedObject>(_ batch: [T]) async -> [ValidationResult] {
        return await withTaskGroup(of: ValidationResult.self) { group in
            for object in batch {
                group.addTask {
                    return self.validate(object)
                }
            }
            
            var results: [ValidationResult] = []
            for await result in group {
                results.append(result)
            }
            return results
        }
    }
    
    // 数据完整性检查方法
    private func checkOrphanedRecords() async -> [DataIntegrityResult.DataIntegrityIssue] {
        var issues: [DataIntegrityResult.DataIntegrityIssue] = []
        
        // 检查孤立的订单
        let orphanedOrdersRequest: NSFetchRequest<Order> = Order.fetchRequest()
        orphanedOrdersRequest.predicate = NSPredicate(format: "product == nil")
        
        do {
            let orphanedOrders = try context.fetch(orphanedOrdersRequest)
            if !orphanedOrders.isEmpty {
                issues.append(DataIntegrityResult.DataIntegrityIssue(
                    type: .orphanedRecord,
                    severity: .medium,
                    entityType: "Order",
                    entityId: nil,
                    description: "发现 \(orphanedOrders.count) 个孤立的订单记录",
                    affectedCount: orphanedOrders.count
                ))
            }
        } catch {
            print("检查孤立订单时出错: \(error)")
        }
        
        // 检查孤立的说明书
        let orphanedManualsRequest: NSFetchRequest<Manual> = Manual.fetchRequest()
        orphanedManualsRequest.predicate = NSPredicate(format: "product == nil")
        
        do {
            let orphanedManuals = try context.fetch(orphanedManualsRequest)
            if !orphanedManuals.isEmpty {
                issues.append(DataIntegrityResult.DataIntegrityIssue(
                    type: .orphanedRecord,
                    severity: .medium,
                    entityType: "Manual",
                    entityId: nil,
                    description: "发现 \(orphanedManuals.count) 个孤立的说明书记录",
                    affectedCount: orphanedManuals.count
                ))
            }
        } catch {
            print("检查孤立说明书时出错: \(error)")
        }
        
        return issues
    }
    
    private func checkDuplicateRecords() async -> [DataIntegrityResult.DataIntegrityIssue] {
        var issues: [DataIntegrityResult.DataIntegrityIssue] = []
        
        // 检查重复的分类名称
        let categoryRequest: NSFetchRequest<Category> = Category.fetchRequest()
        do {
            let categories = try context.fetch(categoryRequest)
            let nameGroups = Dictionary(grouping: categories) { $0.name?.lowercased() ?? "" }
            
            for (name, group) in nameGroups where group.count > 1 && !name.isEmpty {
                issues.append(DataIntegrityResult.DataIntegrityIssue(
                    type: .duplicateRecord,
                    severity: .high,
                    entityType: "Category",
                    entityId: nil,
                    description: "分类名称 '\(name)' 重复 \(group.count) 次",
                    affectedCount: group.count
                ))
            }
        } catch {
            print("检查重复分类时出错: \(error)")
        }
        
        return issues
    }
    
    private func checkRelationshipIntegrity() async -> [DataIntegrityResult.DataIntegrityIssue] {
        var issues: [DataIntegrityResult.DataIntegrityIssue] = []
        
        // 检查产品-分类关系
        let productsWithoutCategoryRequest: NSFetchRequest<Product> = Product.fetchRequest()
        productsWithoutCategoryRequest.predicate = NSPredicate(format: "category == nil")
        
        do {
            let productsWithoutCategory = try context.fetch(productsWithoutCategoryRequest)
            if !productsWithoutCategory.isEmpty {
                issues.append(DataIntegrityResult.DataIntegrityIssue(
                    type: .brokenRelationship,
                    severity: .low,
                    entityType: "Product",
                    entityId: nil,
                    description: "\(productsWithoutCategory.count) 个产品没有分配分类",
                    affectedCount: productsWithoutCategory.count
                ))
            }
        } catch {
            print("检查产品分类关系时出错: \(error)")
        }
        
        return issues
    }
    
    private func checkConstraintViolations() async -> [DataIntegrityResult.DataIntegrityIssue] {
        var issues: [DataIntegrityResult.DataIntegrityIssue] = []
        
        // 检查空名称的产品
        let productsWithEmptyNameRequest: NSFetchRequest<Product> = Product.fetchRequest()
        productsWithEmptyNameRequest.predicate = NSPredicate(format: "name == nil OR name == ''")
        
        do {
            let productsWithEmptyName = try context.fetch(productsWithEmptyNameRequest)
            if !productsWithEmptyName.isEmpty {
                issues.append(DataIntegrityResult.DataIntegrityIssue(
                    type: .constraintViolation,
                    severity: .high,
                    entityType: "Product",
                    entityId: nil,
                    description: "\(productsWithEmptyName.count) 个产品名称为空",
                    affectedCount: productsWithEmptyName.count
                ))
            }
        } catch {
            print("检查产品名称约束时出错: \(error)")
        }
        
        return issues
    }
    
    private func checkDataCorruption() async -> [DataIntegrityResult.DataIntegrityIssue] {
        var issues: [DataIntegrityResult.DataIntegrityIssue] = []
        
        // 检查数据损坏的迹象
        // 这里可以添加更多的数据损坏检查逻辑
        
        return issues
    }
    
    private func getTotalEntityCount() async -> Int {
        var totalCount = 0
        
        let entityNames = ["Product", "Category", "Tag", "Order", "Manual", "RepairRecord"]
        
        for entityName in entityNames {
            let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
            do {
                let count = try context.count(for: request)
                totalCount += count
            } catch {
                print("获取 \(entityName) 数量时出错: \(error)")
            }
        }
        
        return totalCount
    }
    
    private func generateIntegrityRecommendations(from issues: [DataIntegrityResult.DataIntegrityIssue]) -> [DataIntegrityResult.DataIntegrityRecommendation] {
        var recommendations: [DataIntegrityResult.DataIntegrityRecommendation] = []
        
        let criticalIssues = issues.filter { $0.severity == .critical }
        let highIssues = issues.filter { $0.severity == .high }
        let orphanedIssues = issues.filter { $0.type == .orphanedRecord }
        let duplicateIssues = issues.filter { $0.type == .duplicateRecord }
        
        if !criticalIssues.isEmpty {
            recommendations.append(DataIntegrityResult.DataIntegrityRecommendation(
                priority: .urgent,
                title: "立即修复严重问题",
                description: "发现 \(criticalIssues.count) 个严重的数据完整性问题",
                actionItems: [
                    "备份当前数据",
                    "修复数据损坏问题",
                    "验证修复结果"
                ],
                estimatedImpact: "防止数据丢失和应用崩溃"
            ))
        }
        
        if !duplicateIssues.isEmpty {
            recommendations.append(DataIntegrityResult.DataIntegrityRecommendation(
                priority: .high,
                title: "清理重复数据",
                description: "发现重复的数据记录",
                actionItems: [
                    "识别重复记录",
                    "合并或删除重复项",
                    "更新相关引用"
                ],
                estimatedImpact: "提高数据质量和查询性能"
            ))
        }
        
        if !orphanedIssues.isEmpty {
            recommendations.append(DataIntegrityResult.DataIntegrityRecommendation(
                priority: .medium,
                title: "处理孤立记录",
                description: "发现孤立的数据记录",
                actionItems: [
                    "重新建立关系链接",
                    "删除无用的孤立记录",
                    "更新数据模型约束"
                ],
                estimatedImpact: "减少存储空间占用，提高数据一致性"
            ))
        }
        
        return recommendations
    }
    
    // 辅助方法
    private func getObjectId<T: NSManagedObject>(_ object: T) -> UUID? {
        return object.value(forKey: "id") as? UUID
    }
    
    private func isEmptyValue(_ value: Any?) -> Bool {
        if let stringValue = value as? String {
            return stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return value == nil
    }
    
    private func validateStringConstraints(_ value: String, attribute: NSAttributeDescription, attributeName: String, object: NSManagedObject, errors: inout [ValidationError], warnings: inout [ValidationWarning]) {
        // 长度检查
        if let maxLength = attribute.userInfo?["maxLength"] as? Int, value.count > maxLength {
            errors.append(ValidationError(
                type: .constraintViolation,
                message: "字段 '\(attributeName)' 长度超过限制 (\(maxLength))",
                entityType: String(describing: type(of: object)),
                entityId: getObjectId(object),
                fieldName: attributeName
            ))
        }
        
        if let minLength = attribute.userInfo?["minLength"] as? Int, value.count < minLength {
            errors.append(ValidationError(
                type: .constraintViolation,
                message: "字段 '\(attributeName)' 长度不足 (最少\(minLength)个字符)",
                entityType: String(describing: type(of: object)),
                entityId: getObjectId(object),
                fieldName: attributeName
            ))
        }
        
        // 格式检查
        if let pattern = attribute.userInfo?["pattern"] as? String {
            let regex = try? NSRegularExpression(pattern: pattern)
            let range = NSRange(location: 0, length: value.utf16.count)
            if regex?.firstMatch(in: value, options: [], range: range) == nil {
                errors.append(ValidationError(
                    type: .invalidFormat,
                    message: "字段 '\(attributeName)' 格式不正确",
                    entityType: String(describing: type(of: object)),
                    entityId: getObjectId(object),
                    fieldName: attributeName
                ))
            }
        }
    }
    
    private func validateNumberConstraints(_ value: NSNumber, attribute: NSAttributeDescription, attributeName: String, object: NSManagedObject, errors: inout [ValidationError], warnings: inout [ValidationWarning]) {
        // 范围检查
        if let minValue = attribute.userInfo?["minValue"] as? NSNumber, value.compare(minValue) == .orderedAscending {
            errors.append(ValidationError(
                type: .constraintViolation,
                message: "字段 '\(attributeName)' 值过小 (最小值: \(minValue))",
                entityType: String(describing: type(of: object)),
                entityId: getObjectId(object),
                fieldName: attributeName
            ))
        }
        
        if let maxValue = attribute.userInfo?["maxValue"] as? NSNumber, value.compare(maxValue) == .orderedDescending {
            errors.append(ValidationError(
                type: .constraintViolation,
                message: "字段 '\(attributeName)' 值过大 (最大值: \(maxValue))",
                entityType: String(describing: type(of: object)),
                entityId: getObjectId(object),
                fieldName: attributeName
            ))
        }
    }
    
    private func validateDateConstraints(_ value: Date, attribute: NSAttributeDescription, attributeName: String, object: NSManagedObject, errors: inout [ValidationError], warnings: inout [ValidationWarning]) {
        let now = Date()
        
        // 未来日期检查
        if let allowFuture = attribute.userInfo?["allowFuture"] as? Bool, !allowFuture && value > now {
            errors.append(ValidationError(
                type: .constraintViolation,
                message: "字段 '\(attributeName)' 不能是未来日期",
                entityType: String(describing: type(of: object)),
                entityId: getObjectId(object),
                fieldName: attributeName
            ))
        }
        
        // 过去日期检查
        if let allowPast = attribute.userInfo?["allowPast"] as? Bool, !allowPast && value < now {
            errors.append(ValidationError(
                type: .constraintViolation,
                message: "字段 '\(attributeName)' 不能是过去日期",
                entityType: String(describing: type(of: object)),
                entityId: getObjectId(object),
                fieldName: attributeName
            ))
        }
    }
}

// MARK: - 验证规则
struct ValidationRule {
    let field: String
    let type: RuleType
    let message: String
    
    enum RuleType {
        case required
        case unique
        case minLength(Int)
        case maxLength(Int)
        case pattern(String)
        case range(min: Double, max: Double)
        case custom((Any?, NSManagedObject, NSManagedObjectContext) -> Bool)
    }
    
    func validate(_ value: Any?, object: NSManagedObject, context: NSManagedObjectContext) -> (error: ValidationError?, warning: ValidationWarning?) {
        switch type {
        case .required:
            if value == nil || (value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true {
                return (ValidationError(
                    type: .missingRequiredField,
                    message: message,
                    entityType: String(describing: type(of: object)),
                    entityId: object.value(forKey: "id") as? UUID,
                    fieldName: field
                ), nil)
            }
        case .unique:
            if let stringValue = value as? String, !stringValue.isEmpty {
                // 检查唯一性
                let request = NSFetchRequest<NSManagedObject>(entityName: object.entity.name!)
                request.predicate = NSPredicate(format: "%K ==[cd] %@", field, stringValue)
                
                do {
                    let existingObjects = try context.fetch(request)
                    let duplicates = existingObjects.filter { $0.objectID != object.objectID }
                    if !duplicates.isEmpty {
                        return (ValidationError(
                            type: .duplicateValue,
                            message: message,
                            entityType: String(describing: type(of: object)),
                            entityId: object.value(forKey: "id") as? UUID,
                            fieldName: field
                        ), nil)
                    }
                } catch {
                    print("唯一性检查失败: \(error)")
                }
            }
        case .minLength(let min):
            if let stringValue = value as? String, stringValue.count < min {
                return (ValidationError(
                    type: .constraintViolation,
                    message: message,
                    entityType: String(describing: type(of: object)),
                    entityId: object.value(forKey: "id") as? UUID,
                    fieldName: field
                ), nil)
            }
        case .maxLength(let max):
            if let stringValue = value as? String, stringValue.count > max {
                return (ValidationError(
                    type: .constraintViolation,
                    message: message,
                    entityType: String(describing: type(of: object)),
                    entityId: object.value(forKey: "id") as? UUID,
                    fieldName: field
                ), nil)
            }
        case .pattern(let pattern):
            if let stringValue = value as? String {
                let regex = try? NSRegularExpression(pattern: pattern)
                let range = NSRange(location: 0, length: stringValue.utf16.count)
                if regex?.firstMatch(in: stringValue, options: [], range: range) == nil {
                    return (ValidationError(
                        type: .invalidFormat,
                        message: message,
                        entityType: String(describing: type(of: object)),
                        entityId: object.value(forKey: "id") as? UUID,
                        fieldName: field
                    ), nil)
                }
            }
        case .range(let min, let max):
            if let numberValue = value as? NSNumber {
                let doubleValue = numberValue.doubleValue
                if doubleValue < min || doubleValue > max {
                    return (ValidationError(
                        type: .constraintViolation,
                        message: message,
                        entityType: String(describing: type(of: object)),
                        entityId: object.value(forKey: "id") as? UUID,
                        fieldName: field
                    ), nil)
                }
            }
        case .custom(let validator):
            if !validator(value, object, context) {
                return (ValidationError(
                    type: .businessRuleViolation,
                    message: message,
                    entityType: String(describing: type(of: object)),
                    entityId: object.value(forKey: "id") as? UUID,
                    fieldName: field
                ), nil)
            }
        }
        
        return (nil, nil)
    }
}