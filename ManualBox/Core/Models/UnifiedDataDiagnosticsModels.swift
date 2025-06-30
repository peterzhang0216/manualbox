import Foundation

// MARK: - 诊断配置
struct DiagnosticConfiguration {
    let caseSensitive: Bool
    let trimWhitespace: Bool
    let ignoreEmpty: Bool
    let minimumDuplicateCount: Int
    let performDeepScan: Bool
    let includePerformanceMetrics: Bool
    
    static let `default` = DiagnosticConfiguration(
        caseSensitive: false,
        trimWhitespace: true,
        ignoreEmpty: true,
        minimumDuplicateCount: 2,
        performDeepScan: true,
        includePerformanceMetrics: true
    )
    
    static let quick = DiagnosticConfiguration(
        caseSensitive: false,
        trimWhitespace: true,
        ignoreEmpty: true,
        minimumDuplicateCount: 2,
        performDeepScan: false,
        includePerformanceMetrics: false
    )
}

// MARK: - 综合诊断结果
struct ComprehensiveDiagnosticResult {
    var basicStats: BasicStatistics = BasicStatistics()
    var duplicateDetection: DuplicateDetectionSummary = DuplicateDetectionSummary()
    var orphanedData: OrphanedDataSummary = OrphanedDataSummary()
    var integrityCheck: IntegrityCheckResult = IntegrityCheckResult()
    var performanceMetrics: DiagnosticPerformanceMetrics = DiagnosticPerformanceMetrics()
    
    var hasIssues: Bool {
        return duplicateDetection.hasDuplicates ||
               orphanedData.hasOrphanedData ||
               !integrityCheck.isValid
    }
    
    var issueCount: Int {
        return duplicateDetection.totalDuplicateGroups +
               orphanedData.totalOrphanedItems +
               integrityCheck.issues.count
    }
    
    var summary: String {
        if !hasIssues {
            return "数据状态良好，未发现问题"
        }
        
        var issues: [String] = []
        
        if duplicateDetection.hasDuplicates {
            issues.append("发现 \(duplicateDetection.totalDuplicateGroups) 组重复数据")
        }
        
        if orphanedData.hasOrphanedData {
            issues.append("发现 \(orphanedData.totalOrphanedItems) 个孤立数据项")
        }
        
        if !integrityCheck.isValid {
            issues.append("发现 \(integrityCheck.issues.count) 个完整性问题")
        }
        
        return issues.joined(separator: "，")
    }
    
    var detailedReport: String {
        var report = "=== 数据诊断详细报告 ===\n\n"
        
        // 基础统计
        report += "📊 数据统计:\n"
        report += "• 分类: \(basicStats.totalCategories) 个\n"
        report += "• 标签: \(basicStats.totalTags) 个\n"
        report += "• 产品: \(basicStats.totalProducts) 个\n"
        report += "• 订单: \(basicStats.totalOrders) 个\n"
        report += "• 说明书: \(basicStats.totalManuals) 个\n"
        report += "• 维修记录: \(basicStats.totalRepairRecords) 个\n\n"
        
        // 重复数据
        if duplicateDetection.hasDuplicates {
            report += "🔄 重复数据:\n"
            if !duplicateDetection.duplicateCategories.isEmpty {
                report += "• 重复分类: \(duplicateDetection.duplicateCategories.joined(separator: ", "))\n"
            }
            if !duplicateDetection.duplicateTags.isEmpty {
                report += "• 重复标签: \(duplicateDetection.duplicateTags.joined(separator: ", "))\n"
            }
            if !duplicateDetection.duplicateProducts.isEmpty {
                report += "• 重复产品: \(duplicateDetection.duplicateProducts.count) 组\n"
            }
            report += "\n"
        }
        
        // 孤立数据
        if orphanedData.hasOrphanedData {
            report += "🔗 孤立数据:\n"
            if orphanedData.orphanedProducts > 0 {
                report += "• 无分类产品: \(orphanedData.orphanedProducts) 个\n"
            }
            if orphanedData.orphanedOrders > 0 {
                report += "• 孤立订单: \(orphanedData.orphanedOrders) 个\n"
            }
            if orphanedData.orphanedManuals > 0 {
                report += "• 孤立说明书: \(orphanedData.orphanedManuals) 个\n"
            }
            if !orphanedData.emptyCategories.isEmpty {
                report += "• 空分类: \(orphanedData.emptyCategories.joined(separator: ", "))\n"
            }
            if !orphanedData.emptyTags.isEmpty {
                report += "• 空标签: \(orphanedData.emptyTags.joined(separator: ", "))\n"
            }
            report += "\n"
        }
        
        // 完整性检查
        if !integrityCheck.isValid {
            report += "⚠️ 完整性问题:\n"
            for issue in integrityCheck.issues {
                report += "• \(issue)\n"
            }
            report += "\n"
        }
        
        // 性能指标
        report += "⚡ 性能指标:\n"
        report += "• 平均查询时间: \(String(format: "%.3f", performanceMetrics.averageQueryTime))秒\n"
        report += "• 数据库大小: \(String(format: "%.2f", performanceMetrics.databaseSize))MB\n"
        report += "• 索引效率: \(String(format: "%.1f", performanceMetrics.indexEfficiency * 100))%\n"
        report += "• 内存使用: \(String(format: "%.1f", performanceMetrics.memoryUsage))MB\n"
        
        if !hasIssues {
            report += "\n✅ 数据状态良好，未发现问题\n"
        }
        
        return report
    }
}

// MARK: - 快速诊断结果
struct QuickDiagnosticResult {
    let duplicateCategories: [String]
    let duplicateTags: [String]
    let orphanedProducts: Int
    let orphanedOrders: Int
    let orphanedManuals: Int
    let hasIssues: Bool
    
    var summary: String {
        if !hasIssues {
            return "数据状态良好"
        }
        
        var issues: [String] = []
        
        if !duplicateCategories.isEmpty {
            issues.append("\(duplicateCategories.count) 个重复分类")
        }
        
        if !duplicateTags.isEmpty {
            issues.append("\(duplicateTags.count) 个重复标签")
        }
        
        if orphanedProducts > 0 {
            issues.append("\(orphanedProducts) 个无分类产品")
        }
        
        if orphanedOrders > 0 {
            issues.append("\(orphanedOrders) 个孤立订单")
        }
        
        if orphanedManuals > 0 {
            issues.append("\(orphanedManuals) 个孤立说明书")
        }
        
        return "发现问题: " + issues.joined(separator: "，")
    }
}

// MARK: - 基础统计
struct BasicStatistics {
    let totalCategories: Int
    let totalTags: Int
    let totalProducts: Int
    let totalOrders: Int
    let totalManuals: Int
    let totalRepairRecords: Int
    let hasInitializationFlag: Bool
    
    init(
        totalCategories: Int = 0,
        totalTags: Int = 0,
        totalProducts: Int = 0,
        totalOrders: Int = 0,
        totalManuals: Int = 0,
        totalRepairRecords: Int = 0,
        hasInitializationFlag: Bool = false
    ) {
        self.totalCategories = totalCategories
        self.totalTags = totalTags
        self.totalProducts = totalProducts
        self.totalOrders = totalOrders
        self.totalManuals = totalManuals
        self.totalRepairRecords = totalRepairRecords
        self.hasInitializationFlag = hasInitializationFlag
    }
}

// MARK: - 重复检测摘要
struct DuplicateDetectionSummary {
    let duplicateCategories: [String]
    let duplicateTags: [String]
    let duplicateProducts: [String]
    let totalDuplicateGroups: Int
    
    init(
        duplicateCategories: [String] = [],
        duplicateTags: [String] = [],
        duplicateProducts: [String] = [],
        totalDuplicateGroups: Int = 0
    ) {
        self.duplicateCategories = duplicateCategories
        self.duplicateTags = duplicateTags
        self.duplicateProducts = duplicateProducts
        self.totalDuplicateGroups = totalDuplicateGroups
    }
    
    var hasDuplicates: Bool {
        return totalDuplicateGroups > 0
    }
}

// MARK: - 孤立数据摘要
struct OrphanedDataSummary {
    let orphanedProducts: Int
    let orphanedOrders: Int
    let orphanedManuals: Int
    let emptyCategories: [String]
    let emptyTags: [String]
    
    init(
        orphanedProducts: Int = 0,
        orphanedOrders: Int = 0,
        orphanedManuals: Int = 0,
        emptyCategories: [String] = [],
        emptyTags: [String] = []
    ) {
        self.orphanedProducts = orphanedProducts
        self.orphanedOrders = orphanedOrders
        self.orphanedManuals = orphanedManuals
        self.emptyCategories = emptyCategories
        self.emptyTags = emptyTags
    }
    
    var hasOrphanedData: Bool {
        return orphanedProducts > 0 ||
               orphanedOrders > 0 ||
               orphanedManuals > 0 ||
               !emptyCategories.isEmpty ||
               !emptyTags.isEmpty
    }
    
    var totalOrphanedItems: Int {
        return orphanedProducts + orphanedOrders + orphanedManuals + emptyCategories.count + emptyTags.count
    }
}

// MARK: - 完整性检查结果
struct IntegrityCheckResult {
    let isValid: Bool
    let issues: [String]
    let checkedEntities: [String]
    
    init(
        isValid: Bool = true,
        issues: [String] = [],
        checkedEntities: [String] = []
    ) {
        self.isValid = isValid
        self.issues = issues
        self.checkedEntities = checkedEntities
    }
}

// MARK: - 诊断性能指标
struct DiagnosticPerformanceMetrics {
    let averageQueryTime: TimeInterval
    let databaseSize: Double // MB
    let indexEfficiency: Double // 0.0 - 1.0
    let memoryUsage: Double // MB
    
    init(
        averageQueryTime: TimeInterval = 0.0,
        databaseSize: Double = 0.0,
        indexEfficiency: Double = 1.0,
        memoryUsage: Double = 0.0
    ) {
        self.averageQueryTime = averageQueryTime
        self.databaseSize = databaseSize
        self.indexEfficiency = indexEfficiency
        self.memoryUsage = memoryUsage
    }
    
    var performanceGrade: PerformanceGrade {
        if averageQueryTime < 0.1 && indexEfficiency > 0.9 {
            return .excellent
        } else if averageQueryTime < 0.5 && indexEfficiency > 0.7 {
            return .good
        } else if averageQueryTime < 1.0 && indexEfficiency > 0.5 {
            return .fair
        } else {
            return .poor
        }
    }
    
    enum PerformanceGrade: String, CaseIterable {
        case excellent = "excellent"
        case good = "good"
        case fair = "fair"
        case poor = "poor"
        
        var displayName: String {
            switch self {
            case .excellent: return "优秀"
            case .good: return "良好"
            case .fair: return "一般"
            case .poor: return "较差"
            }
        }
        
        var color: String {
            switch self {
            case .excellent: return "green"
            case .good: return "blue"
            case .fair: return "orange"
            case .poor: return "red"
            }
        }
    }
}

// MARK: - 修复结果
struct FixResult {
    var duplicatesFixed: Int = 0
    var orphanedDataCleaned: Int = 0
    var errors: [String] = []
    
    var isSuccessful: Bool {
        return errors.isEmpty
    }
    
    var totalItemsFixed: Int {
        return duplicatesFixed + orphanedDataCleaned
    }
    
    var summary: String {
        if totalItemsFixed == 0 && errors.isEmpty {
            return "无需修复"
        }
        
        var messages: [String] = []
        
        if duplicatesFixed > 0 {
            messages.append("修复了 \(duplicatesFixed) 个重复项")
        }
        
        if orphanedDataCleaned > 0 {
            messages.append("清理了 \(orphanedDataCleaned) 个孤立数据")
        }
        
        if !errors.isEmpty {
            messages.append("遇到 \(errors.count) 个错误")
        }
        
        return messages.joined(separator: "，")
    }
}
