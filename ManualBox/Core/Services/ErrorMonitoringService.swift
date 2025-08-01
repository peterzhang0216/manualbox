//
//  ErrorMonitoringService.swift
//  ManualBox
//
//  Created by Assistant on 2024/12/19.
//  错误监控服务 - 收集、分析和报告应用错误
//

import Foundation
import SwiftUI

// 导入共享错误类型以避免重复定义
// RecoveryStrategy, RecoveryAction 现在从 SharedErrorTypes.swift 导入
import Combine

// MARK: - 错误类型定义
enum ErrorCategory: String, CaseIterable, Codable {
    case network = "network"
    case database = "database"
    case validation = "validation"
    case business = "business"
    case system = "system"
    case unknown = "unknown"
    
    var displayName: String {
        switch self {
        case .network: return "网络"
        case .database: return "数据库"
        case .validation: return "验证"
        case .business: return "业务逻辑"
        case .system: return "系统"
        case .unknown: return "未知"
        }
    }
}

enum ErrorSeverity: String, CaseIterable, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
    
    var displayName: String {
        switch self {
        case .low: return "低"
        case .medium: return "中"
        case .high: return "高"
        case .critical: return "严重"
        }
    }
}

enum AlertSeverity: String, CaseIterable, Codable {
    case info = "info"
    case warning = "warning"
    case error = "error"
    case critical = "critical"
    
    var displayName: String {
        switch self {
        case .info: return "信息"
        case .warning: return "警告"
        case .error: return "错误"
        case .critical: return "严重"
        }
    }
}

enum ErrorTimeRange {
    case last24Hours
    case last7Days
    case last30Days
    case custom(from: Date, to: Date)
    
    var cutoffDate: Date {
        let now = Date()
        switch self {
        case .last24Hours:
            return Calendar.current.date(byAdding: .hour, value: -24, to: now) ?? now
        case .last7Days:
            return Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
        case .last30Days:
            return Calendar.current.date(byAdding: .day, value: -30, to: now) ?? now
        case .custom(let from, _):
            return from
        }
    }
}

// MARK: - 错误上下文
// 注意：ErrorContext 已移动到 SharedErrorTypes.swift 以避免重复定义
// 这里使用的 ErrorContext 应该引用共享定义

// ExportFormat moved to Core/Utils/ExportFormat.swift

// MARK: - 恢复结果
// 注意：RecoveryResult 已移动到 SharedErrorTypes.swift 以避免重复定义

// MARK: - 恢复策略
// 注意：RecoveryStrategy 已移动到 SharedErrorTypes.swift 以避免重复定义

// MARK: - 恢复操作
// 注意：RecoveryAction 已移动到 SharedErrorTypes.swift 以避免重复定义

// MARK: - 错误监控服务
@MainActor
class ErrorMonitoringService: ObservableObject {
    static let shared = ErrorMonitoringService()
    
    // MARK: - Published Properties
    @Published private(set) var errorHistory: [ErrorRecord] = []
    @Published private(set) var errorStatistics: ErrorStatistics = ErrorStatistics()
    @Published private(set) var activeAlerts: [ErrorAlert] = []
    @Published private(set) var errorTrends: [ErrorTrend] = []
    @Published private(set) var isMonitoringEnabled = true
    @Published private(set) var lastReportGenerated: Date?
    
    // MARK: - Private Properties
    private let maxErrorHistory = 1000
    private let errorThresholds = ErrorThresholds()
    private var cancellables = Set<AnyCancellable>()
    private let reportGenerator = ErrorReportGenerator()
    
    // MARK: - Initialization
    private init() {
        loadErrorHistory()
        setupErrorMonitoring()
        schedulePeriodicAnalysis()
    }
    
    // MARK: - Public Methods
    
    /// 记录错误
    func recordError(_ error: Error, context: ErrorContext) {
        guard isMonitoringEnabled else { return }
        
        let errorRecord = ErrorRecord(
            error: error,
            context: context,
            timestamp: Date(),
            severity: determineSeverity(error),
            category: categorizeError(error)
        )
        
        errorHistory.insert(errorRecord, at: 0)
        
        // 限制历史记录数量
        if errorHistory.count > maxErrorHistory {
            errorHistory.removeLast()
        }
        
        updateStatistics()
        checkForAlerts(errorRecord)
        saveErrorHistory()
        
        print("🚨 错误已记录: \(errorRecord.title) - \(errorRecord.severity.displayName)")
    }
    
    /// 生成错误报告
    func generateErrorReport(timeRange: ErrorTimeRange = .last24Hours) async -> ErrorReport {
        let filteredErrors = filterErrors(by: timeRange)
        let report = await reportGenerator.generateReport(from: filteredErrors)
        
        lastReportGenerated = Date()
        
        print("📊 错误报告已生成: \(filteredErrors.count) 个错误")
        return report
    }
    
    /// 获取错误趋势
    func getErrorTrends(timeRange: ErrorTimeRange = .last7Days) -> [ErrorTrend] {
        let filteredErrors = filterErrors(by: timeRange)
        return analyzeTrends(filteredErrors)
    }
    
    /// 清除错误历史
    func clearErrorHistory() {
        errorHistory.removeAll()
        errorStatistics = ErrorStatistics()
        activeAlerts.removeAll()
        errorTrends.removeAll()
        saveErrorHistory()
        
        print("🧹 错误历史已清除")
    }
    
    /// 标记错误为已解决
    func markErrorAsResolved(_ errorId: UUID) {
        if let index = errorHistory.firstIndex(where: { $0.id == errorId }) {
            errorHistory[index].isResolved = true
            errorHistory[index].resolvedAt = Date()
            saveErrorHistory()
            updateStatistics()
            
            print("✅ 错误已标记为已解决: \(errorHistory[index].title)")
        }
    }
    
    /// 忽略错误类型
    func ignoreErrorType(_ errorType: String) {
        // 在实际应用中，这里应该保存到持久化存储
        UserDefaults.standard.set(true, forKey: "IgnoreError_\(errorType)")
        
        // 移除相关的活跃告警
        activeAlerts.removeAll { alert in
            alert.errorType == errorType
        }
        
        print("🔇 错误类型已忽略: \(errorType)")
    }
    
    /// 设置错误阈值
    func setErrorThreshold(for category: ErrorCategory, threshold: Int) {
        errorThresholds.setThreshold(for: category, value: threshold)
        print("⚠️ 错误阈值已设置: \(category.displayName) - \(threshold)")
    }
    
    /// 导出错误数据
    func exportErrorData(format: ExportFormat = .json) -> Data? {
        switch format {
        case .json:
            return try? JSONEncoder().encode(errorHistory)
        case .csv:
            return generateCSVData()
        }
    }
    
    // MARK: - Private Methods
    
    private func setupErrorMonitoring() {
        // 监听应用错误
        NotificationCenter.default.publisher(for: .applicationError)
            .sink { [weak self] notification in
                if let error = notification.object as? Error,
                   let context = notification.userInfo?["context"] as? ErrorContext {
                    Task { @MainActor in
                        self?.recordError(error, context: context)
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    private func schedulePeriodicAnalysis() {
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in // 每5分钟
            Task { @MainActor in
                await self.performPeriodicAnalysis()
            }
        }
    }
    
    private func performPeriodicAnalysis() async {
        updateStatistics()
        updateErrorTrends()
        checkForPatterns()
        cleanupOldErrors()
    }
    
    private func determineSeverity(_ error: Error) -> ErrorSeverity {
        switch error {
        case is CancellationError:
            return .low
        case let appError as AppError:
            switch appError {
            case .network:
                return .medium
            case .persistence:
                return .high
            case .validation:
                return .low
            case .business:
                return .medium
            case .system:
                return .critical
            }
        default:
            return .medium
        }
    }
    
    private func categorizeError(_ error: Error) -> ErrorCategory {
        switch error {
        case is CancellationError:
            return .system
        case let appError as AppError:
            switch appError {
            case .network:
                return .network
            case .persistence:
                return .database
            case .validation:
                return .validation
            case .business:
                return .business
            case .system:
                return .system
            }
        default:
            return .unknown
        }
    }
    
    private func updateStatistics() {
        let last24Hours = filterErrors(by: .last24Hours)
        let last7Days = filterErrors(by: .last7Days)
        
        errorStatistics = ErrorStatistics(
            totalErrors: errorHistory.count,
            errorsLast24Hours: last24Hours.count,
            errorsLast7Days: last7Days.count,
            resolvedErrors: errorHistory.filter { $0.isResolved }.count,
            criticalErrors: errorHistory.filter { $0.severity == .critical }.count,
            mostCommonCategory: findMostCommonCategory(),
            averageResolutionTime: calculateAverageResolutionTime(),
            errorRate: calculateErrorRate()
        )
    }
    
    private func checkForAlerts(_ errorRecord: ErrorRecord) {
        // 检查严重错误
        if errorRecord.severity == .critical {
            createAlert(
                title: "严重错误",
                message: "检测到严重错误: \(errorRecord.title)",
                severity: .critical,
                errorType: errorRecord.category.rawValue
            )
        }
        
        // 检查错误频率
        let recentErrors = filterErrors(by: .last1Hour)
        let categoryCount = recentErrors.filter { $0.category == errorRecord.category }.count
        
        if let threshold = errorThresholds.getThreshold(for: errorRecord.category),
           categoryCount >= threshold {
            createAlert(
                title: "错误频率过高",
                message: "\(errorRecord.category.displayName)错误在过去1小时内发生了\(categoryCount)次",
                severity: .high,
                errorType: errorRecord.category.rawValue
            )
        }
    }
    
    private func createAlert(title: String, message: String, severity: AlertSeverity, errorType: String) {
        // 避免重复告警
        let existingAlert = activeAlerts.first { alert in
            alert.title == title && alert.errorType == errorType
        }
        
        guard existingAlert == nil else { return }
        
        let alert = ErrorAlert(
            title: title,
            message: message,
            severity: severity,
            errorType: errorType,
            timestamp: Date()
        )
        
        activeAlerts.append(alert)
        
        // 限制活跃告警数量
        if activeAlerts.count > 10 {
            activeAlerts.removeFirst()
        }
        
        print("🚨 新告警: \(title)")
    }
    
    private func filterErrors(by timeRange: ErrorTimeRange) -> [ErrorRecord] {
        let cutoffDate = timeRange.cutoffDate
        return errorHistory.filter { $0.timestamp >= cutoffDate }
    }
    
    private func analyzeTrends(_ errors: [ErrorRecord]) -> [ErrorTrend] {
        let groupedByHour = Dictionary(grouping: errors) { error in
            Calendar.current.dateInterval(of: .hour, for: error.timestamp)?.start ?? error.timestamp
        }
        
        return groupedByHour.map { (date, errors) in
            ErrorTrend(
                timestamp: date,
                errorCount: errors.count,
                criticalCount: errors.filter { $0.severity == .critical }.count,
                categories: Dictionary(grouping: errors, by: { $0.category })
                    .mapValues { $0.count }
            )
        }.sorted { $0.timestamp < $1.timestamp }
    }
    
    private func updateErrorTrends() {
        errorTrends = getErrorTrends()
    }
    
    private func checkForPatterns() {
        // 检查错误模式
        let recentErrors = filterErrors(by: .last24Hours)
        
        // 检查重复错误
        let errorGroups = Dictionary(grouping: recentErrors) { $0.title }
        for (title, errors) in errorGroups {
            if errors.count >= 5 {
                createAlert(
                    title: "重复错误模式",
                    message: "错误 '\(title)' 在24小时内重复出现\(errors.count)次",
                    severity: .medium,
                    errorType: "pattern_repeat"
                )
            }
        }
        
        // 检查错误激增
        let currentHourErrors = filterErrors(by: .last1Hour).count
        let previousHourErrors = errorHistory.filter { error in
            let hourAgo = Calendar.current.date(byAdding: .hour, value: -1, to: Date()) ?? Date()
            let twoHoursAgo = Calendar.current.date(byAdding: .hour, value: -2, to: Date()) ?? Date()
            return error.timestamp >= twoHoursAgo && error.timestamp < hourAgo
        }.count
        
        if currentHourErrors > previousHourErrors * 2 && currentHourErrors > 5 {
            createAlert(
                title: "错误激增",
                message: "当前小时错误数量(\(currentHourErrors))比上一小时(\(previousHourErrors))增加了\(currentHourErrors - previousHourErrors)个",
                severity: .high,
                errorType: "error_spike"
            )
        }
    }
    
    private func cleanupOldErrors() {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let oldCount = errorHistory.count
        errorHistory.removeAll { $0.timestamp < thirtyDaysAgo }
        
        if errorHistory.count < oldCount {
            saveErrorHistory()
            print("🧹 清理了 \(oldCount - errorHistory.count) 个旧错误记录")
        }
    }
    
    private func findMostCommonCategory() -> ErrorCategory {
        let categoryCount = Dictionary(grouping: errorHistory, by: { $0.category })
            .mapValues { $0.count }
        
        return categoryCount.max(by: { $0.value < $1.value })?.key ?? .unknown
    }
    
    private func calculateAverageResolutionTime() -> TimeInterval {
        let resolvedErrors = errorHistory.filter { $0.isResolved && $0.resolvedAt != nil }
        guard !resolvedErrors.isEmpty else { return 0 }
        
        let totalTime = resolvedErrors.reduce(0.0) { total, error in
            guard let resolvedAt = error.resolvedAt else { return total }
            return total + resolvedAt.timeIntervalSince(error.timestamp)
        }
        
        return totalTime / Double(resolvedErrors.count)
    }
    
    private func calculateErrorRate() -> Double {
        let last24Hours = filterErrors(by: .last24Hours)
        return Double(last24Hours.count) / 24.0 // 每小时平均错误数
    }
    
    private func generateCSVData() -> Data? {
        var csvContent = "Timestamp,Title,Category,Severity,Resolved,Context\n"
        
        for error in errorHistory {
            let row = [
                error.timestamp.ISO8601Format(),
                error.title.replacingOccurrences(of: ",", with: ";"),
                error.category.displayName,
                error.severity.displayName,
                error.isResolved ? "Yes" : "No",
                error.context.operationType.replacingOccurrences(of: ",", with: ";")
            ].joined(separator: ",")
            
            csvContent += row + "\n"
        }
        
        return csvContent.data(using: .utf8)
    }
    
    private func loadErrorHistory() {
        if let data = UserDefaults.standard.data(forKey: "ErrorHistory"),
           let history = try? JSONDecoder().decode([ErrorRecord].self, from: data) {
            errorHistory = history
            updateStatistics()
        }
    }
    
    private func saveErrorHistory() {
        if let data = try? JSONEncoder().encode(errorHistory) {
            UserDefaults.standard.set(data, forKey: "ErrorHistory")
        }
    }
}

// MARK: - 错误记录
struct ErrorRecord: Identifiable, Codable {
    let id = UUID()
    let title: String
    let message: String
    let category: ErrorCategory
    let severity: ErrorSeverity
    let timestamp: Date
    let context: ErrorContext
    var isResolved: Bool = false
    var resolvedAt: Date?
    
    init(error: Error, context: ErrorContext, timestamp: Date, severity: ErrorSeverity, category: ErrorCategory) {
        self.title = error.localizedDescription
        self.message = (error as NSError).localizedFailureReason ?? error.localizedDescription
        self.context = context
        self.timestamp = timestamp
        self.severity = severity
        self.category = category
    }
}

// MARK: - 错误统计
struct ErrorStatistics {
    let totalErrors: Int
    let errorsLast24Hours: Int
    let errorsLast7Days: Int
    let resolvedErrors: Int
    let criticalErrors: Int
    let mostCommonCategory: ErrorCategory
    let averageResolutionTime: TimeInterval
    let errorRate: Double
    
    init() {
        self.totalErrors = 0
        self.errorsLast24Hours = 0
        self.errorsLast7Days = 0
        self.resolvedErrors = 0
        self.criticalErrors = 0
        self.mostCommonCategory = .unknown
        self.averageResolutionTime = 0
        self.errorRate = 0
    }
    
    init(totalErrors: Int, errorsLast24Hours: Int, errorsLast7Days: Int, resolvedErrors: Int, criticalErrors: Int, mostCommonCategory: ErrorCategory, averageResolutionTime: TimeInterval, errorRate: Double) {
        self.totalErrors = totalErrors
        self.errorsLast24Hours = errorsLast24Hours
        self.errorsLast7Days = errorsLast7Days
        self.resolvedErrors = resolvedErrors
        self.criticalErrors = criticalErrors
        self.mostCommonCategory = mostCommonCategory
        self.averageResolutionTime = averageResolutionTime
        self.errorRate = errorRate
    }
}

// MARK: - 错误趋势
struct ErrorTrend: Identifiable {
    let id = UUID()
    let timestamp: Date
    let errorCount: Int
    let criticalCount: Int
    let categories: [ErrorCategory: Int]
}

// MARK: - 错误告警
struct ErrorAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let severity: AlertSeverity
    let errorType: String
    let timestamp: Date
}

// MARK: - 错误阈值管理
class ErrorThresholds {
    private var thresholds: [ErrorCategory: Int] = [
        .network: 10,
        .database: 5,
        .validation: 20,
        .business: 15,
        .system: 3,
        .unknown: 10
    ]
    
    func getThreshold(for category: ErrorCategory) -> Int? {
        return thresholds[category]
    }
    
    func setThreshold(for category: ErrorCategory, value: Int) {
        thresholds[category] = value
    }
}

// MARK: - 错误报告生成器
class ErrorReportGenerator {
    func generateReport(from errors: [ErrorRecord]) async -> ErrorReport {
        let statistics = generateStatistics(from: errors)
        let trends = generateTrends(from: errors)
        let recommendations = generateRecommendations(from: errors)
        
        return ErrorReport(
            generatedAt: Date(),
            timeRange: "Last 24 Hours",
            statistics: statistics,
            trends: trends,
            topErrors: Array(errors.prefix(10)),
            recommendations: recommendations
        )
    }
    
    private func generateStatistics(from errors: [ErrorRecord]) -> ErrorReportStatistics {
        let categoryCount = Dictionary(grouping: errors, by: { $0.category })
            .mapValues { $0.count }
        
        let severityCount = Dictionary(grouping: errors, by: { $0.severity })
            .mapValues { $0.count }
        
        return ErrorReportStatistics(
            totalErrors: errors.count,
            categoryCounts: categoryCount,
            severityCounts: severityCount,
            resolutionRate: Double(errors.filter { $0.isResolved }.count) / Double(max(errors.count, 1))
        )
    }
    
    private func generateTrends(from errors: [ErrorRecord]) -> [ErrorTrendData] {
        let groupedByHour = Dictionary(grouping: errors) { error in
            Calendar.current.dateInterval(of: .hour, for: error.timestamp)?.start ?? error.timestamp
        }
        
        return groupedByHour.map { (date, errors) in
            ErrorTrendData(
                timestamp: date,
                count: errors.count,
                criticalCount: errors.filter { $0.severity == .critical }.count
            )
        }.sorted { $0.timestamp < $1.timestamp }
    }
    
    private func generateRecommendations(from errors: [ErrorRecord]) -> [ErrorRecommendation] {
        var recommendations: [ErrorRecommendation] = []
        
        // 检查高频错误
        let errorGroups = Dictionary(grouping: errors, by: { $0.title })
        for (title, groupErrors) in errorGroups {
            if groupErrors.count >= 5 {
                recommendations.append(ErrorRecommendation(
                    title: "解决高频错误",
                    description: "错误 '\(title)' 出现了 \(groupErrors.count) 次，建议优先解决",
                    priority: .high,
                    category: .performance
                ))
            }
        }
        
        // 检查严重错误
        let criticalErrors = errors.filter { $0.severity == .critical }
        if !criticalErrors.isEmpty {
            recommendations.append(ErrorRecommendation(
                title: "处理严重错误",
                description: "发现 \(criticalErrors.count) 个严重错误，需要立即处理",
                priority: .critical,
                category: .stability
            ))
        }
        
        return recommendations
    }
}

// MARK: - 错误报告
struct ErrorReport {
    let generatedAt: Date
    let timeRange: String
    let statistics: ErrorReportStatistics
    let trends: [ErrorTrendData]
    let topErrors: [ErrorRecord]
    let recommendations: [ErrorRecommendation]
}

struct ErrorReportStatistics {
    let totalErrors: Int
    let categoryCounts: [ErrorCategory: Int]
    let severityCounts: [ErrorSeverity: Int]
    let resolutionRate: Double
}

struct ErrorTrendData: Identifiable {
    let id = UUID()
    let timestamp: Date
    let count: Int
    let criticalCount: Int
}

struct ErrorRecommendation: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let priority: RecommendationPriority
    let category: RecommendationCategory
}

enum RecommendationPriority {
    case low, medium, high, critical
    
    var displayName: String {
        switch self {
        case .low: return "低"
        case .medium: return "中"
        case .high: return "高"
        case .critical: return "严重"
        }
    }
}

// 注意：RecommendationCategory 已移动到 SharedUIComponents.swift 以避免重复定义

// ExportFormat is defined in Core/Utils/ExportFormat.swift

// MARK: - 通知扩展
extension Notification.Name {
    static let applicationError = Notification.Name("ApplicationError")
}