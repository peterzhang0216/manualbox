//
//  PerformanceReportGenerator.swift
//  ManualBox
//
//  Created by AI Assistant on 2025/7/22.
//

import Foundation
import SwiftUI

// MARK: - 性能报告生成器协议
protocol PerformanceReportGenerator {
    func generateDailyReport() async -> DailyPerformanceReport
    func generateWeeklyReport() async -> WeeklyPerformanceReport
    func generateCustomReport(from startDate: Date, to endDate: Date) async -> CustomPerformanceReport
    func exportReport(_ report: PerformanceReportExportable, format: PerformanceReportFormat) async -> Data?
}

// MARK: - 报告格式
enum PerformanceReportFormat: String, CaseIterable {
    case json = "json"
    case csv = "csv"
    case html = "html"
    case pdf = "pdf"
    
    var fileExtension: String {
        return rawValue
    }
    
    var mimeType: String {
        switch self {
        case .json: return "application/json"
        case .csv: return "text/csv"
        case .html: return "text/html"
        case .pdf: return "application/pdf"
        }
    }
}

// MARK: - 可导出报告协议
protocol PerformanceReportExportable {
    var title: String { get }
    var generatedAt: Date { get }
    var timeRange: DateInterval { get }
    func toJSON() -> Data?
    func toCSV() -> String
    func toHTML() -> String
}

// MARK: - 日报告
struct DailyPerformanceReport: PerformanceReportExportable {
    let title = "日性能报告"
    let generatedAt: Date
    let timeRange: DateInterval
    let summary: DailySummary
    let hourlyBreakdown: [HourlyStats]
    let topOperations: [OperationStats]
    let alerts: [PerformanceAlert]
    let recommendations: [PerformanceRecommendation]
    
    struct DailySummary {
        let totalOperations: Int
        let averageResponseTime: TimeInterval
        let errorRate: Double
        let peakMemoryUsage: Double
        let memoryPressureEvents: Int
        let slowestOperation: String
        let fastestOperation: String
    }
    
    struct HourlyStats {
        let hour: Int
        let operationCount: Int
        let averageResponseTime: TimeInterval
        let errorCount: Int
        let memoryUsageMB: Double
    }
    
    struct OperationStats {
        let name: String
        let category: PerformanceCategory
        let count: Int
        let totalTime: TimeInterval
        let averageTime: TimeInterval
        let minTime: TimeInterval
        let maxTime: TimeInterval
        let errorCount: Int
    }
    
    func toJSON() -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(self)
    }
    
    func toCSV() -> String {
        var csv = "操作名称,类别,执行次数,总时间,平均时间,最小时间,最大时间,错误次数\n"
        
        for operation in topOperations {
            csv += "\(operation.name),\(operation.category.rawValue),\(operation.count),\(operation.totalTime),\(operation.averageTime),\(operation.minTime),\(operation.maxTime),\(operation.errorCount)\n"
        }
        
        return csv
    }
    
    func toHTML() -> String {
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <title>\(title)</title>
            <style>
                body { font-family: Arial, sans-serif; margin: 20px; }
                .summary { background: #f5f5f5; padding: 15px; border-radius: 5px; margin-bottom: 20px; }
                table { border-collapse: collapse; width: 100%; }
                th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
                th { background-color: #f2f2f2; }
                .alert-critical { color: #d32f2f; }
                .alert-warning { color: #f57c00; }
            </style>
        </head>
        <body>
            <h1>\(title)</h1>
            <p>生成时间: \(DateFormatter.localizedString(from: generatedAt, dateStyle: .medium, timeStyle: .short))</p>
            
            <div class="summary">
                <h2>概要</h2>
                <p>总操作数: \(summary.totalOperations)</p>
                <p>平均响应时间: \(String(format: "%.3f", summary.averageResponseTime))秒</p>
                <p>错误率: \(String(format: "%.2f", summary.errorRate * 100))%</p>
                <p>峰值内存使用: \(String(format: "%.1f", summary.peakMemoryUsage))MB</p>
            </div>
            
            <h2>操作统计</h2>
            <table>
                <tr>
                    <th>操作名称</th>
                    <th>类别</th>
                    <th>执行次数</th>
                    <th>平均时间</th>
                    <th>错误次数</th>
                </tr>
                \(topOperations.map { operation in
                    "<tr><td>\(operation.name)</td><td>\(operation.category.rawValue)</td><td>\(operation.count)</td><td>\(String(format: "%.3f", operation.averageTime))s</td><td>\(operation.errorCount)</td></tr>"
                }.joined(separator: "\n"))
            </table>
        </body>
        </html>
        """
    }
}

// MARK: - 周报告
struct WeeklyPerformanceReport: PerformanceReportExportable {
    let title = "周性能报告"
    let generatedAt: Date
    let timeRange: DateInterval
    let summary: WeeklySummary
    let dailyTrends: [DailyTrend]
    let categoryAnalysis: [CategoryAnalysis]
    let performanceTrends: PerformanceTrends
    let recommendations: [PerformanceRecommendation]
    
    struct WeeklySummary {
        let totalOperations: Int
        let averageResponseTime: TimeInterval
        let responseTimeImprovement: Double // 相比上周的改善百分比
        let errorRate: Double
        let errorRateChange: Double
        let memoryEfficiency: Double
        let topPerformingDay: String
        let worstPerformingDay: String
    }
    
    struct DailyTrend {
        let date: Date
        let operationCount: Int
        let averageResponseTime: TimeInterval
        let errorRate: Double
        let memoryUsage: Double
    }
    
    struct CategoryAnalysis {
        let category: PerformanceCategory
        let operationCount: Int
        let averageResponseTime: TimeInterval
        let trend: TrendDirection
        let improvement: Double
    }
    
    struct PerformanceTrends {
        let responseTimeTrend: TrendDirection
        let memoryUsageTrend: TrendDirection
        let errorRateTrend: TrendDirection
        let operationCountTrend: TrendDirection
    }
    
    enum TrendDirection {
        case improving, stable, declining
        
        var emoji: String {
            switch self {
            case .improving: return "📈"
            case .stable: return "➡️"
            case .declining: return "📉"
            }
        }
    }
    
    func toJSON() -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(self)
    }
    
    func toCSV() -> String {
        var csv = "日期,操作数量,平均响应时间,错误率,内存使用\n"
        
        for trend in dailyTrends {
            let dateString = DateFormatter.localizedString(from: trend.date, dateStyle: .short, timeStyle: .none)
            csv += "\(dateString),\(trend.operationCount),\(trend.averageResponseTime),\(trend.errorRate),\(trend.memoryUsage)\n"
        }
        
        return csv
    }
    
    func toHTML() -> String {
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <title>\(title)</title>
            <style>
                body { font-family: Arial, sans-serif; margin: 20px; }
                .summary { background: #f5f5f5; padding: 15px; border-radius: 5px; margin-bottom: 20px; }
                .trend-up { color: #4caf50; }
                .trend-down { color: #f44336; }
                .trend-stable { color: #ff9800; }
                table { border-collapse: collapse; width: 100%; margin-bottom: 20px; }
                th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
                th { background-color: #f2f2f2; }
            </style>
        </head>
        <body>
            <h1>\(title)</h1>
            <p>生成时间: \(DateFormatter.localizedString(from: generatedAt, dateStyle: .medium, timeStyle: .short))</p>
            
            <div class="summary">
                <h2>周概要</h2>
                <p>总操作数: \(summary.totalOperations)</p>
                <p>平均响应时间: \(String(format: "%.3f", summary.averageResponseTime))秒</p>
                <p>错误率: \(String(format: "%.2f", summary.errorRate * 100))%</p>
                <p>最佳表现日: \(summary.topPerformingDay)</p>
                <p>最差表现日: \(summary.worstPerformingDay)</p>
            </div>
            
            <h2>性能趋势</h2>
            <p>响应时间趋势: \(performanceTrends.responseTimeTrend.emoji)</p>
            <p>内存使用趋势: \(performanceTrends.memoryUsageTrend.emoji)</p>
            <p>错误率趋势: \(performanceTrends.errorRateTrend.emoji)</p>
        </body>
        </html>
        """
    }
}

// MARK: - 自定义报告
struct CustomPerformanceReport: PerformanceReportExportable {
    let title: String
    let generatedAt: Date
    let timeRange: DateInterval
    let filters: ReportFilters
    let data: CustomReportData
    
    struct ReportFilters {
        let categories: [PerformanceCategory]
        let operations: [String]
        let minDuration: TimeInterval?
        let maxDuration: TimeInterval?
        let includeErrors: Bool
    }
    
    struct CustomReportData {
        let operations: [OperationDetail]
        let statistics: Statistics
        let charts: [ChartData]
    }
    
    struct OperationDetail {
        let name: String
        let category: PerformanceCategory
        let startTime: Date
        let duration: TimeInterval
        let memoryUsage: Int64
        let success: Bool
        let error: String?
    }
    
    struct Statistics {
        let count: Int
        let averageDuration: TimeInterval
        let medianDuration: TimeInterval
        let p95Duration: TimeInterval
        let totalMemoryUsed: Int64
        let successRate: Double
    }
    
    struct ChartData {
        let type: ChartType
        let title: String
        let data: [DataPoint]
        
        enum ChartType {
            case line, bar, pie
        }
        
        struct DataPoint {
            let label: String
            let value: Double
            let timestamp: Date?
        }
    }
    
    func toJSON() -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(self)
    }
    
    func toCSV() -> String {
        var csv = "操作名称,类别,开始时间,持续时间,内存使用,成功,错误\n"
        
        for operation in data.operations {
            let startTimeString = DateFormatter.localizedString(from: operation.startTime, dateStyle: .short, timeStyle: .medium)
            csv += "\(operation.name),\(operation.category.rawValue),\(startTimeString),\(operation.duration),\(operation.memoryUsage),\(operation.success),\(operation.error ?? "")\n"
        }
        
        return csv
    }
    
    func toHTML() -> String {
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <title>\(title)</title>
            <style>
                body { font-family: Arial, sans-serif; margin: 20px; }
                .summary { background: #f5f5f5; padding: 15px; border-radius: 5px; margin-bottom: 20px; }
                table { border-collapse: collapse; width: 100%; }
                th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
                th { background-color: #f2f2f2; }
                .success { color: #4caf50; }
                .error { color: #f44336; }
            </style>
        </head>
        <body>
            <h1>\(title)</h1>
            <p>生成时间: \(DateFormatter.localizedString(from: generatedAt, dateStyle: .medium, timeStyle: .short))</p>
            <p>时间范围: \(DateFormatter.localizedString(from: timeRange.start, dateStyle: .short, timeStyle: .short)) - \(DateFormatter.localizedString(from: timeRange.end, dateStyle: .short, timeStyle: .short))</p>
            
            <div class="summary">
                <h2>统计信息</h2>
                <p>操作总数: \(data.statistics.count)</p>
                <p>平均持续时间: \(String(format: "%.3f", data.statistics.averageDuration))秒</p>
                <p>中位数持续时间: \(String(format: "%.3f", data.statistics.medianDuration))秒</p>
                <p>95%分位数: \(String(format: "%.3f", data.statistics.p95Duration))秒</p>
                <p>成功率: \(String(format: "%.2f", data.statistics.successRate * 100))%</p>
            </div>
        </body>
        </html>
        """
    }
}

// MARK: - 性能报告生成器实现
class ManualBoxPerformanceReportGenerator: PerformanceReportGenerator {
    static let shared = ManualBoxPerformanceReportGenerator()
    
    private let performanceMonitor = ManualBoxPerformanceMonitoringService.shared
    private let performanceService = ManualBoxPerformanceMonitoringService.shared
    
    private init() {}
    
    func generateDailyReport() async -> DailyPerformanceReport {
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) ?? now
        
        let timeRange = DateInterval(start: startOfDay, end: endOfDay)
        
        // 获取当天的性能数据
        let operations = await getOperationsInRange(timeRange)
        
        // 生成摘要
        let summary = generateDailySummary(from: operations)
        
        // 生成小时统计
        let hourlyBreakdown = generateHourlyBreakdown(from: operations)
        
        // 获取顶级操作
        let topOperations = generateTopOperations(from: operations)
        
        // 获取告警
        let alerts = await getAlertsInRange(timeRange)
        
        // 生成建议
        let recommendations = generateRecommendations(from: operations, alerts: alerts)
        
        return DailyPerformanceReport(
            generatedAt: now,
            timeRange: timeRange,
            summary: summary,
            hourlyBreakdown: hourlyBreakdown,
            topOperations: topOperations,
            alerts: alerts,
            recommendations: recommendations
        )
    }
    
    func generateWeeklyReport() async -> WeeklyPerformanceReport {
        let now = Date()
        let calendar = Calendar.current
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        let endOfWeek = calendar.date(byAdding: .day, value: 7, to: startOfWeek) ?? now
        
        let timeRange = DateInterval(start: startOfWeek, end: endOfWeek)
        
        // 获取本周的性能数据
        let operations = await getOperationsInRange(timeRange)
        
        // 生成周摘要
        let summary = generateWeeklySummary(from: operations)
        
        // 生成每日趋势
        let dailyTrends = generateDailyTrends(from: operations, in: timeRange)
        
        // 生成分类分析
        let categoryAnalysis = generateCategoryAnalysis(from: operations)
        
        // 生成性能趋势
        let performanceTrends = generatePerformanceTrends(from: operations)
        
        // 生成建议
        let recommendations = generateWeeklyRecommendations(from: operations)
        
        return WeeklyPerformanceReport(
            generatedAt: now,
            timeRange: timeRange,
            summary: summary,
            dailyTrends: dailyTrends,
            categoryAnalysis: categoryAnalysis,
            performanceTrends: performanceTrends,
            recommendations: recommendations
        )
    }
    
    func generateCustomReport(from startDate: Date, to endDate: Date) async -> CustomPerformanceReport {
        let timeRange = DateInterval(start: startDate, end: endDate)
        let operations = await getOperationsInRange(timeRange)
        
        let filters = CustomPerformanceReport.ReportFilters(
            categories: PerformanceCategory.allCases,
            operations: [],
            minDuration: nil,
            maxDuration: nil,
            includeErrors: true
        )
        
        let operationDetails = operations.map { op in
            CustomPerformanceReport.OperationDetail(
                name: op.name,
                category: .ui, // 默认分类
                startTime: op.timestamp,
                duration: op.value,
                memoryUsage: 0,
                success: true,
                error: nil
            )
        }
        
        let statistics = generateStatistics(from: operationDetails)
        let charts = generateChartData(from: operationDetails)
        
        let data = CustomPerformanceReport.CustomReportData(
            operations: operationDetails,
            statistics: statistics,
            charts: charts
        )
        
        return CustomPerformanceReport(
            title: "自定义性能报告",
            generatedAt: Date(),
            timeRange: timeRange,
            filters: filters,
            data: data
        )
    }
    
    func exportReport(_ report: PerformanceReportExportable, format: PerformanceReportFormat) async -> Data? {
        switch format {
        case .json:
            return report.toJSON()
        case .csv:
            return report.toCSV().data(using: .utf8)
        case .html:
            return report.toHTML().data(using: .utf8)
        case .pdf:
            return await generatePDF(from: report.toHTML())
        }
    }
    
    // MARK: - 私有方法
    
    private func getOperationsInRange(_ range: DateInterval) async -> [PerformanceMetric] {
        // 从性能监控器获取指定时间范围内的操作数据
        return performanceMonitor.getMetrics(for: "").filter { metric in
            range.contains(metric.timestamp)
        }
    }
    
    private func getAlertsInRange(_ range: DateInterval) async -> [PerformanceAlert] {
        // 获取指定时间范围内的告警
        return performanceService.recentAlerts.filter { alert in
            range.contains(alert.timestamp)
        }
    }
    
    private func generateDailySummary(from operations: [PerformanceMetric]) -> DailyPerformanceReport.DailySummary {
        let totalOperations = operations.count
        let averageResponseTime = operations.isEmpty ? 0 : operations.map { $0.value }.reduce(0, +) / Double(totalOperations)
        let errorRate = 0.0 // 暂时设为0
        let peakMemoryUsage = operations.compactMap { $0.tags["memory_mb"] }.compactMap { Double($0) }.max() ?? 0
        let memoryPressureEvents = operations.filter { $0.name == "memory_pressure_event" }.count
        
        let sortedByTime = operations.sorted { $0.value < $1.value }
        let slowestOperation = sortedByTime.last?.name ?? "无"
        let fastestOperation = sortedByTime.first?.name ?? "无"
        
        return DailyPerformanceReport.DailySummary(
            totalOperations: totalOperations,
            averageResponseTime: averageResponseTime,
            errorRate: errorRate,
            peakMemoryUsage: peakMemoryUsage,
            memoryPressureEvents: memoryPressureEvents,
            slowestOperation: slowestOperation,
            fastestOperation: fastestOperation
        )
    }
    
    private func generateHourlyBreakdown(from operations: [PerformanceMetric]) -> [DailyPerformanceReport.HourlyStats] {
        let calendar = Calendar.current
        var hourlyStats: [Int: DailyPerformanceReport.HourlyStats] = [:]
        
        for operation in operations {
            let hour = calendar.component(.hour, from: operation.timestamp)
            
            if hourlyStats[hour] == nil {
                hourlyStats[hour] = DailyPerformanceReport.HourlyStats(
                    hour: hour,
                    operationCount: 0,
                    averageResponseTime: 0,
                    errorCount: 0,
                    memoryUsageMB: 0
                )
            }
            
            // 更新统计信息
            // 这里需要根据实际数据结构进行调整
        }
        
        return Array(hourlyStats.values).sorted { $0.hour < $1.hour }
    }
    
    private func generateTopOperations(from operations: [PerformanceMetric]) -> [DailyPerformanceReport.OperationStats] {
        let groupedOperations = Dictionary(grouping: operations) { $0.name }
        
        return groupedOperations.map { (name, ops) in
            let durations = ops.map { $0.value }
            return DailyPerformanceReport.OperationStats(
                name: name,
                category: .ui, // 默认分类
                count: ops.count,
                totalTime: durations.reduce(0, +),
                averageTime: durations.reduce(0, +) / Double(durations.count),
                minTime: durations.min() ?? 0,
                maxTime: durations.max() ?? 0,
                errorCount: 0
            )
        }.sorted { $0.averageTime > $1.averageTime }
    }
    
    private func generateRecommendations(from operations: [PerformanceMetric], alerts: [PerformanceAlert]) -> [PerformanceRecommendation] {
        var recommendations: [PerformanceRecommendation] = []
        
        // 基于告警生成建议
        if alerts.contains(where: { $0.category == .memory && $0.severity == .critical }) {
            recommendations.append(PerformanceRecommendation(
                id: UUID(),
                category: .memory,
                priority: .high,
                title: "优化内存使用",
                description: "检测到严重的内存压力事件",
                impact: "可能导致应用崩溃",
                actionItems: [
                    "检查内存泄漏",
                    "优化图片缓存",
                    "实施延迟加载"
                ]
            ))
        }
        
        return recommendations
    }
    
    private func generateWeeklySummary(from operations: [PerformanceMetric]) -> WeeklyPerformanceReport.WeeklySummary {
        // 生成周摘要的逻辑
        return WeeklyPerformanceReport.WeeklySummary(
            totalOperations: operations.count,
            averageResponseTime: operations.isEmpty ? 0 : operations.map { $0.value }.reduce(0, +) / Double(operations.count),
            responseTimeImprovement: 0.0,
            errorRate: 0.0,
            errorRateChange: 0.0,
            memoryEfficiency: 0.0,
            topPerformingDay: "周一",
            worstPerformingDay: "周五"
        )
    }
    
    private func generateDailyTrends(from operations: [PerformanceMetric], in range: DateInterval) -> [WeeklyPerformanceReport.DailyTrend] {
        // 生成每日趋势的逻辑
        return []
    }
    
    private func generateCategoryAnalysis(from operations: [PerformanceMetric]) -> [WeeklyPerformanceReport.CategoryAnalysis] {
        // 生成分类分析的逻辑
        return []
    }
    
    private func generatePerformanceTrends(from operations: [PerformanceMetric]) -> WeeklyPerformanceReport.PerformanceTrends {
        // 生成性能趋势的逻辑
        return WeeklyPerformanceReport.PerformanceTrends(
            responseTimeTrend: .stable,
            memoryUsageTrend: .improving,
            errorRateTrend: .stable,
            operationCountTrend: .improving
        )
    }
    
    private func generateWeeklyRecommendations(from operations: [PerformanceMetric]) -> [PerformanceRecommendation] {
        // 生成周建议的逻辑
        return []
    }
    
    private func generateStatistics(from operations: [CustomPerformanceReport.OperationDetail]) -> CustomPerformanceReport.Statistics {
        let durations = operations.map { $0.duration }
        let sortedDurations = durations.sorted()
        
        let p95Index = Int(Double(sortedDurations.count) * 0.95)
        let medianIndex = sortedDurations.count / 2
        
        return CustomPerformanceReport.Statistics(
            count: operations.count,
            averageDuration: durations.isEmpty ? 0 : durations.reduce(0, +) / Double(durations.count),
            medianDuration: sortedDurations.isEmpty ? 0 : sortedDurations[medianIndex],
            p95Duration: p95Index < sortedDurations.count ? sortedDurations[p95Index] : 0,
            totalMemoryUsed: operations.map { $0.memoryUsage }.reduce(0, +),
            successRate: operations.isEmpty ? 0 : Double(operations.filter { $0.success }.count) / Double(operations.count)
        )
    }
    
    private func generateChartData(from operations: [CustomPerformanceReport.OperationDetail]) -> [CustomPerformanceReport.ChartData] {
        // 生成图表数据的逻辑
        return []
    }
    
    private func generatePDF(from html: String) async -> Data? {
        // PDF生成逻辑（需要使用WebKit或其他PDF生成库）
        return nil
    }
}

// MARK: - Codable 支持
extension DailyPerformanceReport: Codable {}
extension DailyPerformanceReport.DailySummary: Codable {}
extension DailyPerformanceReport.HourlyStats: Codable {}
extension DailyPerformanceReport.OperationStats: Codable {}

extension WeeklyPerformanceReport: Codable {}
extension WeeklyPerformanceReport.WeeklySummary: Codable {}
extension WeeklyPerformanceReport.DailyTrend: Codable {}
extension WeeklyPerformanceReport.CategoryAnalysis: Codable {}
extension WeeklyPerformanceReport.PerformanceTrends: Codable {}
extension WeeklyPerformanceReport.TrendDirection: Codable {}

extension CustomPerformanceReport: Codable {}
extension CustomPerformanceReport.ReportFilters: Codable {}
extension CustomPerformanceReport.CustomReportData: Codable {}
extension CustomPerformanceReport.OperationDetail: Codable {}
extension CustomPerformanceReport.Statistics: Codable {}
extension CustomPerformanceReport.ChartData: Codable {}
extension CustomPerformanceReport.ChartData.ChartType: Codable {}
extension CustomPerformanceReport.ChartData.DataPoint: Codable {}