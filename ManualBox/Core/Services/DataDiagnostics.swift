//
//  DataDiagnostics.swift
//  ManualBox
//
//  Created by AI Assistant on 2025/7/22.
//

import Foundation
import CoreData

// MARK: - 数据诊断服务
/// 为了兼容现有代码而创建的DataDiagnostics类
@MainActor
class DataDiagnostics {
    private let context: NSManagedObjectContext
    private let unifiedService: UnifiedDataDiagnosticsService
    
    init(context: NSManagedObjectContext) {
        self.context = context
        self.unifiedService = UnifiedDataDiagnosticsService.shared
    }
    
    /// 执行诊断并返回兼容的结果
    func diagnose() async -> DiagnosticResult {
        let quickResult = await unifiedService.performQuickDiagnosis()
        return DiagnosticResult(from: quickResult)
    }
    
    // MARK: - 诊断结果
    struct DiagnosticResult {
        let totalCategories: Int
        let totalTags: Int
        let totalProducts: Int
        let totalOrders: Int
        let totalManuals: Int
        let totalRepairRecords: Int
        let duplicateCategories: [String]
        let duplicateTags: [String]
        let orphanedProducts: Int
        let orphanedOrders: Int
        let orphanedManuals: Int
        let hasIssues: Bool
        
        var summary: String {
            if !hasIssues {
                return "数据状态良好，未发现问题"
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
        
        var detailedReport: String {
            var report = "=== 数据诊断详细报告 ===\n\n"
            
            // 基础统计
            report += "📊 数据统计:\n"
            report += "• 分类: \(totalCategories) 个\n"
            report += "• 标签: \(totalTags) 个\n"
            report += "• 产品: \(totalProducts) 个\n"
            report += "• 订单: \(totalOrders) 个\n"
            report += "• 说明书: \(totalManuals) 个\n"
            report += "• 维修记录: \(totalRepairRecords) 个\n\n"
            
            // 重复数据
            if !duplicateCategories.isEmpty || !duplicateTags.isEmpty {
                report += "🔄 重复数据:\n"
                if !duplicateCategories.isEmpty {
                    report += "• 重复分类: \(duplicateCategories.joined(separator: ", "))\n"
                }
                if !duplicateTags.isEmpty {
                    report += "• 重复标签: \(duplicateTags.joined(separator: ", "))\n"
                }
                report += "\n"
            }
            
            // 孤立数据
            if orphanedProducts > 0 || orphanedOrders > 0 || orphanedManuals > 0 {
                report += "🔗 孤立数据:\n"
                if orphanedProducts > 0 {
                    report += "• 无分类产品: \(orphanedProducts) 个\n"
                }
                if orphanedOrders > 0 {
                    report += "• 孤立订单: \(orphanedOrders) 个\n"
                }
                if orphanedManuals > 0 {
                    report += "• 孤立说明书: \(orphanedManuals) 个\n"
                }
                report += "\n"
            }
            
            return report
        }
        
        init(from quickResult: QuickDiagnosticResult) {
            // 从统一诊断服务获取基础统计
            let stats = BasicStatistics() // 使用默认值，实际应该从服务获取
            
            self.totalCategories = stats.totalCategories
            self.totalTags = stats.totalTags
            self.totalProducts = stats.totalProducts
            self.totalOrders = stats.totalOrders
            self.totalManuals = stats.totalManuals
            self.totalRepairRecords = stats.totalRepairRecords
            
            self.duplicateCategories = quickResult.duplicateCategories
            self.duplicateTags = quickResult.duplicateTags
            self.orphanedProducts = quickResult.orphanedProducts
            self.orphanedOrders = quickResult.orphanedOrders
            self.orphanedManuals = quickResult.orphanedManuals
            self.hasIssues = quickResult.hasIssues
        }
    }
}