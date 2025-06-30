//
//  DashboardViewHelpers.swift
//  ManualBox
//
//  Created by Assistant on 2024/12/19.
//

import SwiftUI
import Foundation

// MARK: - DashboardView 扩展 - 辅助方法
extension DashboardView {
    
    // MARK: - 格式化相对时间
    func formatRelativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    // MARK: - 格式化货币
    func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: amount as NSNumber) ?? "0"
    }
    
    // MARK: - 仪表板内容
    func dashboardContent(_ stats: DashboardStatistics) -> some View {
        VStack(spacing: 16) {
            // 概览卡片
            overviewCard(stats)
            
            // 时间范围选择器
            timeRangeSelector
            
            // 统计卡片网格
            statisticsGrid(stats)
            
            // 趋势图表
            if selectedCardTypes.contains(.trends) {
                trendsSection(stats.trendStats)
            }
            
            // 分类分布
            if selectedCardTypes.contains(.categories) {
                categoriesSection(stats.categoryStats)
            }
        }
    }
}

// MARK: - 统计卡片类型枚举已移至StatisticsModels.swift

// MARK: - 统计时间范围枚举已移至 StatisticsModels.swift

// MARK: - 数字格式化扩展
extension NumberFormatter {
    
    /// 创建货币格式化器
    static var currency: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "CNY"
        formatter.maximumFractionDigits = 0
        return formatter
    }
    
    /// 创建百分比格式化器
    static var percentage: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 1
        return formatter
    }
    
    /// 创建整数格式化器
    static var integer: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter
    }
}

// MARK: - 日期格式化扩展
extension DateFormatter {
    
    // monthYear 格式化器已移至 StatisticsService.swift
    
    /// 创建短日期格式化器
    static var shortDate: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }
}

// MARK: - 颜色扩展
extension Color {
    
    /// 根据状态获取颜色
    init(_ status: ProductSearchFilters.WarrantyStatus) {
        switch status {
        case .active:
            self = .green
        case .expiring:
            self = .orange
        case .expired:
            self = .red
        }
    }
    
    /// 根据趋势获取颜色
    init(_ trend: SpendingTrend) {
        switch trend {
        case .increasing:
            self = .red
        case .decreasing:
            self = .green
        case .stable:
            self = .blue
        }
    }
    
    /// 根据完成级别获取颜色
    init(_ level: CompletionLevel) {
        switch level {
        case .high:
            self = .green
        case .medium:
            self = .orange
        case .low:
            self = .red
        }
    }
}

// MARK: - 枚举扩展已移至相应的模型文件

// MARK: - 完成级别枚举扩展
extension CompletionLevel {
    
    /// 获取完成级别颜色
    var color: String {
        switch self {
        case .high:
            return "green"
        case .medium:
            return "orange"
        case .low:
            return "red"
        }
    }
    
    /// 获取完成级别图标
    var icon: String {
        switch self {
        case .high:
            return "checkmark.circle.fill"
        case .medium:
            return "minus.circle.fill"
        case .low:
            return "xmark.circle.fill"
        }
    }
}

// MARK: - 枚举定义已移至相应的Models文件
// WarrantyStatus -> SearchFilters.swift
// SpendingTrend, CompletionLevel -> 如需要请在StatisticsModels.swift中定义