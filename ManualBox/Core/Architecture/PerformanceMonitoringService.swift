//
//  PerformanceMonitoringService.swift
//  ManualBox
//
//  Created by AI Assistant on 2025/7/22.
//

import Foundation
import SwiftUI
import Combine
import os.log

// MARK: - 操作令牌类型别名
typealias OperationToken = EnhancedOperationToken

// MARK: - 性能监控服务协议
protocol PerformanceMonitoringService {
    nonisolated func startOperation(_ name: String, category: PerformanceCategory) -> OperationToken
    nonisolated func endOperation(_ token: OperationToken)
    nonisolated func recordMetric(_ name: String, value: Double, unit: String, tags: [String: String])
    nonisolated func recordError(_ error: Error, context: [String: Any])
    func getPerformanceReport() -> PerformanceReport
    func enableRealTimeMonitoring(_ enabled: Bool)
    func setPerformanceThreshold(_ threshold: PerformanceThreshold)
}

// MARK: - 性能类别
enum PerformanceCategory: String, CaseIterable, Codable {
    case database = "database"
    case network = "network"
    case ui = "ui"
    case sync = "sync"
    case file = "file"
    case ocr = "ocr"
    case memory = "memory"
    case startup = "startup"
    case search = "search"
    case export = "export"
    case `import` = "import"
}

// MARK: - 性能指标
struct PerformanceMetric: Codable {
    let name: String
    let value: Double
    let timestamp: Date
    let tags: [String: String]
    let context: PerformanceContext
    
    struct PerformanceContext: Codable {
        let operationId: UUID?
        let duration: TimeInterval?
        let memoryUsage: Int64?
        let threadInfo: ThreadInfo
        
        struct ThreadInfo: Codable {
            let isMainThread: Bool
            let threadName: String?
            let queueLabel: String?
        }
    }
}

// MARK: - 性能阈值
struct PerformanceThreshold {
    let category: PerformanceCategory
    let warningThreshold: TimeInterval
    let criticalThreshold: TimeInterval
    let memoryWarningMB: Double
    let memoryCriticalMB: Double
    
    static let defaultThresholds: [PerformanceCategory: PerformanceThreshold] = [
        .database: PerformanceThreshold(category: .database, warningThreshold: 0.5, criticalThreshold: 2.0, memoryWarningMB: 50, memoryCriticalMB: 100),
        .network: PerformanceThreshold(category: .network, warningThreshold: 3.0, criticalThreshold: 10.0, memoryWarningMB: 20, memoryCriticalMB: 50),
        .ui: PerformanceThreshold(category: .ui, warningThreshold: 0.016, criticalThreshold: 0.1, memoryWarningMB: 30, memoryCriticalMB: 80),
        .sync: PerformanceThreshold(category: .sync, warningThreshold: 5.0, criticalThreshold: 30.0, memoryWarningMB: 100, memoryCriticalMB: 200),
        .file: PerformanceThreshold(category: .file, warningThreshold: 1.0, criticalThreshold: 5.0, memoryWarningMB: 50, memoryCriticalMB: 150),
        .ocr: PerformanceThreshold(category: .ocr, warningThreshold: 2.0, criticalThreshold: 10.0, memoryWarningMB: 100, memoryCriticalMB: 300),
        .startup: PerformanceThreshold(category: .startup, warningThreshold: 2.0, criticalThreshold: 5.0, memoryWarningMB: 100, memoryCriticalMB: 200)
    ]
}

// MARK: - 性能报告
struct PerformanceReport {
    let generatedAt: Date
    let timeRange: DateInterval
    let summary: PerformanceSummary
    let categoryReports: [PerformanceCategory: CategoryReport]
    let alerts: [PerformanceAlert]
    let recommendations: [PerformanceRecommendation]
    
    struct PerformanceSummary {
        let totalOperations: Int
        let averageResponseTime: TimeInterval
        let errorRate: Double
        let memoryUsage: MemoryUsageStats
        let topSlowOperations: [SlowOperation]
    }
    
    struct CategoryReport {
        let category: PerformanceCategory
        let operationCount: Int
        let averageTime: TimeInterval
        let minTime: TimeInterval
        let maxTime: TimeInterval
        let p95Time: TimeInterval
        let errorCount: Int
        let memoryImpact: Double
    }
    
    struct SlowOperation {
        let name: String
        let category: PerformanceCategory
        let duration: TimeInterval
        let timestamp: Date
        let memoryUsage: Int64
    }
    
    struct MemoryUsageStats {
        let current: Double
        let average: Double
        let peak: Double
        let pressureEvents: Int
    }
}

// MARK: - 性能告警
struct PerformanceAlert: Codable {
    let id: UUID
    let timestamp: Date
    let severity: AlertSeverity
    let category: PerformanceCategory
    let operation: String
    let message: String
    let metrics: [String: Double]
    
    enum AlertSeverity: String, CaseIterable, Codable {
        case info = "INFO"
        case warning = "WARNING"
        case critical = "CRITICAL"
    }
}

// MARK: - 性能建议
struct PerformanceRecommendation: Codable {
    let id: UUID
    let category: PerformanceCategory
    let priority: Priority
    let title: String
    let description: String
    let impact: String
    let actionItems: [String]
    
    enum Priority: String, CaseIterable, Codable {
        case low = "LOW"
        case medium = "MEDIUM"
        case high = "HIGH"
        case critical = "CRITICAL"
    }
}

// MARK: - 增强的操作令牌
struct EnhancedOperationToken {
    let id: UUID
    let operationName: String
    let category: PerformanceCategory
    let startTime: CFAbsoluteTime
    let startMemory: Int64
    let threadInfo: ThreadInfo
    let tags: [String: String]
    
    struct ThreadInfo {
        let isMainThread: Bool
        let threadName: String?
        let queueLabel: String?
    }
    
    init(operationName: String, category: PerformanceCategory, tags: [String: String] = [:]) {
        self.id = UUID()
        self.operationName = operationName
        self.category = category
        self.startTime = CFAbsoluteTimeGetCurrent()
        self.startMemory = MemoryMonitor.getCurrentMemoryUsage()
        self.threadInfo = ThreadInfo(
            isMainThread: Thread.isMainThread,
            threadName: Thread.current.name,
            queueLabel: DispatchQueue.currentLabel
        )
        self.tags = tags
    }
}

// MARK: - 性能监控服务实现
@MainActor
class ManualBoxPerformanceMonitoringService: PerformanceMonitoringService, ObservableObject {
    nonisolated static let shared: ManualBoxPerformanceMonitoringService = {
        MainActor.assumeIsolated {
            ManualBoxPerformanceMonitoringService()
        }
    }()
    
    // 发布状态
    @Published var isRealTimeMonitoringEnabled = true
    @Published var currentPerformanceStatus: PerformanceStatus = .normal
    @Published var activeOperationsCount = 0
    @Published var memoryPressureLevel: MemoryPressureLevel = .normal
    @Published var recentAlerts: [PerformanceAlert] = []
    
    // 私有属性
    private var activeOperations: [UUID: EnhancedOperationToken] = [:]
    private var completedOperations: [CompletedOperation] = []
    private var performanceThresholds: [PerformanceCategory: PerformanceThreshold] = PerformanceThreshold.defaultThresholds
    private var alerts: [PerformanceAlert] = []
    private var recommendations: [PerformanceRecommendation] = []
    
    private let metricsQueue = DispatchQueue(label: "com.manualbox.performance.metrics", qos: .utility)
    private let maxOperationsHistory = 10000
    private let maxAlertsHistory = 1000
    
    private var memoryMonitorTimer: Timer?
    private var reportGenerationTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    enum PerformanceStatus {
        case normal, warning, critical
    }
    
    enum MemoryPressureLevel {
        case normal, warning, critical
    }
    
    struct CompletedOperation {
        let token: EnhancedOperationToken
        let endTime: CFAbsoluteTime
        let endMemory: Int64
        let duration: TimeInterval
        let success: Bool
        let error: Error?
        
        var memoryDelta: Int64 { endMemory - token.startMemory }
    }
    
    private init() {
        setupMonitoring()
    }
    
    // MARK: - 公共接口实现
    
    nonisolated func startOperation(_ name: String, category: PerformanceCategory = .ui) -> OperationToken {
        let enhancedToken = EnhancedOperationToken(operationName: name, category: category)
        let basicToken = OperationToken(operationName: name)
        
        metricsQueue.async {
            self.activeOperations[enhancedToken.id] = enhancedToken
            
            DispatchQueue.main.async {
                self.activeOperationsCount = self.activeOperations.count
            }
        }
        
        // 记录操作开始指标
        recordMetric("operation_started", value: 1, unit: "count", tags: [
            "operation": name,
            "category": category.rawValue,
            "thread": Thread.isMainThread ? "main" : "background"
        ])
        
        return basicToken
    }
    
    nonisolated func endOperation(_ token: OperationToken) {
        let endTime = CFAbsoluteTimeGetCurrent()
        let endMemory = MemoryMonitor.getCurrentMemoryUsage()
        
        metricsQueue.async {
            // 查找对应的增强令牌
            if let enhancedToken = self.activeOperations.values.first(where: { $0.operationName == token.operationName }) {
                let duration = endTime - enhancedToken.startTime
                
                let completedOp = CompletedOperation(
                    token: enhancedToken,
                    endTime: endTime,
                    endMemory: endMemory,
                    duration: duration,
                    success: true,
                    error: nil
                )
                
                self.activeOperations.removeValue(forKey: enhancedToken.id)
                self.addCompletedOperation(completedOp)
                
                // 检查性能阈值
                self.checkPerformanceThresholds(for: completedOp)
                
                // 记录完成指标
                self.recordMetric("operation_completed", value: duration, unit: "seconds", tags: [
                    "operation": enhancedToken.operationName,
                    "category": enhancedToken.category.rawValue,
                    "success": "true"
                ])
                
                DispatchQueue.main.async {
                    self.activeOperationsCount = self.activeOperations.count
                    self.updatePerformanceStatus()
                }
            }
        }
    }
    
    nonisolated func recordMetric(_ name: String, value: Double, unit: String = "", tags: [String: String] = [:]) {
        let metric = PerformanceMetric(
            name: name,
            value: value,
            timestamp: Date(),
            tags: tags.merging(["unit": unit]) { _, new in new },
            context: PerformanceMetric.PerformanceContext(
                operationId: nil,
                duration: nil,
                memoryUsage: nil,
                threadInfo: PerformanceMetric.PerformanceContext.ThreadInfo(
                    isMainThread: Thread.isMainThread,
                    threadName: Thread.current.name,
                    queueLabel: DispatchQueue.currentLabel
                )
            )
        )
        
        // 发布到性能监控系统
        ManualBoxPerformanceMonitor.shared.recordMetric(name, value: value, tags: tags)
        
        // 发布到事件总线
        EventBus.shared.publishPerformanceMetric(name: name, value: value, unit: unit)
    }
    
    nonisolated func recordError(_ error: Error, context: [String: Any] = [:]) {
        let errorTags = [
            "error_type": String(describing: type(of: error)),
            "error_domain": (error as NSError).domain,
            "error_code": String((error as NSError).code)
        ]
        
        recordMetric("error_occurred", value: 1, unit: "count", tags: errorTags)
        
        // 创建错误告警
        let alert = PerformanceAlert(
            id: UUID(),
            timestamp: Date(),
            severity: .warning,
            category: .ui, // 默认分类，可以根据上下文调整
            operation: "error_handling",
            message: "发生错误: \(error.localizedDescription)",
            metrics: ["error_code": Double((error as NSError).code)]
        )
        
        addAlert(alert)
    }
    
    nonisolated func getPerformanceReport() -> PerformanceReport {
        return metricsQueue.sync {
            generatePerformanceReport()
        }
    }
    
    nonisolated func enableRealTimeMonitoring(_ enabled: Bool) {
        isRealTimeMonitoringEnabled = enabled
        
        if enabled {
            startRealTimeMonitoring()
        } else {
            stopRealTimeMonitoring()
        }
    }
    
    nonisolated func setPerformanceThreshold(_ threshold: PerformanceThreshold) {
        performanceThresholds[threshold.category] = threshold
    }
    
    // MARK: - 私有方法
    
    private func setupMonitoring() {
        startMemoryMonitoring()
        startPeriodicReporting()
        enableRealTimeMonitoring(true)
    }
    
    private func startMemoryMonitoring() {
        memoryMonitorTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            let currentMemory = MemoryMonitor.getCurrentMemoryUsage()
            let memoryMB = Double(currentMemory) / 1024 / 1024
            
            // 记录内存使用指标
            self.recordMetric("memory_usage", value: memoryMB, unit: "MB", tags: ["type": "current"])
            
            // 更新内存压力级别
            Task { @MainActor in
                let newLevel: MemoryPressureLevel
                if memoryMB > 500 {
                    newLevel = .critical
                } else if memoryMB > 300 {
                    newLevel = .warning
                } else {
                    newLevel = .normal
                }
                
                if newLevel != self.memoryPressureLevel {
                    self.memoryPressureLevel = newLevel
                    
                    // 创建内存压力告警
                    if newLevel != .normal {
                        let alert = PerformanceAlert(
                            id: UUID(),
                            timestamp: Date(),
                            severity: newLevel == .critical ? .critical : .warning,
                            category: .memory,
                            operation: "memory_monitoring",
                            message: "内存使用量达到\(newLevel == .critical ? "严重" : "警告")级别: \(String(format: "%.1f", memoryMB))MB",
                            metrics: ["memory_mb": memoryMB]
                        )
                        self.addAlert(alert)
                    }
                }
            }
        }
    }
    
    private func startPeriodicReporting() {
        reportGenerationTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            Task {
                let report = await self.getPerformanceReport()
                await self.analyzePerformanceAndGenerateRecommendations(report)
            }
        }
    }
    
    private func startRealTimeMonitoring() {
        // 实时监控逻辑
        print("🔍 [PerformanceMonitoring] 实时监控已启用")
    }
    
    private func stopRealTimeMonitoring() {
        // 停止实时监控
        print("🔍 [PerformanceMonitoring] 实时监控已停用")
    }
    
    private func addCompletedOperation(_ operation: CompletedOperation) {
        completedOperations.append(operation)
        
        // 限制历史记录数量
        if completedOperations.count > maxOperationsHistory {
            completedOperations.removeFirst(completedOperations.count - maxOperationsHistory)
        }
    }
    
    private func checkPerformanceThresholds(for operation: CompletedOperation) {
        guard let threshold = performanceThresholds[operation.token.category] else { return }
        
        let duration = operation.duration
        let memoryMB = Double(abs(operation.memoryDelta)) / 1024 / 1024
        
        var alertSeverity: PerformanceAlert.AlertSeverity?
        var alertMessage = ""
        
        // 检查时间阈值
        if duration >= threshold.criticalThreshold {
            alertSeverity = .critical
            alertMessage = "操作 '\(operation.token.operationName)' 执行时间过长: \(String(format: "%.2f", duration))秒"
        } else if duration >= threshold.warningThreshold {
            alertSeverity = .warning
            alertMessage = "操作 '\(operation.token.operationName)' 执行时间较长: \(String(format: "%.2f", duration))秒"
        }
        
        // 检查内存阈值
        if memoryMB >= threshold.memoryCriticalMB {
            alertSeverity = .critical
            alertMessage += (alertMessage.isEmpty ? "" : "; ") + "内存使用过高: \(String(format: "%.1f", memoryMB))MB"
        } else if memoryMB >= threshold.memoryWarningMB {
            if alertSeverity != .critical {
                alertSeverity = .warning
            }
            alertMessage += (alertMessage.isEmpty ? "" : "; ") + "内存使用较高: \(String(format: "%.1f", memoryMB))MB"
        }
        
        // 创建告警
        if let severity = alertSeverity {
            let alert = PerformanceAlert(
                id: UUID(),
                timestamp: Date(),
                severity: severity,
                category: operation.token.category,
                operation: operation.token.operationName,
                message: alertMessage,
                metrics: [
                    "duration": duration,
                    "memory_mb": memoryMB
                ]
            )
            
            addAlert(alert)
        }
    }
    
    private func addAlert(_ alert: PerformanceAlert) {
        metricsQueue.async {
            self.alerts.append(alert)
            
            // 限制告警历史数量
            if self.alerts.count > self.maxAlertsHistory {
                self.alerts.removeFirst(self.alerts.count - self.maxAlertsHistory)
            }
            
            DispatchQueue.main.async {
                self.recentAlerts = Array(self.alerts.suffix(10))
            }
        }
    }
    
    private func updatePerformanceStatus() {
        let recentCriticalAlerts = alerts.suffix(20).filter { 
            $0.severity == .critical && Date().timeIntervalSince($0.timestamp) < 300 // 5分钟内
        }
        
        let recentWarningAlerts = alerts.suffix(50).filter { 
            $0.severity == .warning && Date().timeIntervalSince($0.timestamp) < 600 // 10分钟内
        }
        
        if !recentCriticalAlerts.isEmpty {
            currentPerformanceStatus = .critical
        } else if recentWarningAlerts.count > 3 {
            currentPerformanceStatus = .warning
        } else {
            currentPerformanceStatus = .normal
        }
    }
    
    private func generatePerformanceReport() -> PerformanceReport {
        let now = Date()
        let oneHourAgo = now.addingTimeInterval(-3600)
        let timeRange = DateInterval(start: oneHourAgo, end: now)
        
        let recentOperations = completedOperations.filter { 
            Date(timeIntervalSinceReferenceDate: $0.endTime).timeIntervalSince(oneHourAgo) >= 0
        }
        
        // 生成摘要
        let summary = generateSummary(from: recentOperations)
        
        // 生成分类报告
        let categoryReports = generateCategoryReports(from: recentOperations)
        
        // 获取最近的告警
        let recentAlerts = alerts.filter { $0.timestamp.timeIntervalSince(oneHourAgo) >= 0 }
        
        return PerformanceReport(
            generatedAt: now,
            timeRange: timeRange,
            summary: summary,
            categoryReports: categoryReports,
            alerts: recentAlerts,
            recommendations: recommendations
        )
    }
    
    private func generateSummary(from operations: [CompletedOperation]) -> PerformanceReport.PerformanceSummary {
        let totalOperations = operations.count
        let averageResponseTime = operations.isEmpty ? 0 : operations.map { $0.duration }.reduce(0, +) / Double(totalOperations)
        let errorRate = 0.0 // 暂时设为0，后续可以根据实际错误统计
        
        let memoryUsages = operations.map { Double($0.endMemory) / 1024 / 1024 }
        let memoryStats = PerformanceReport.MemoryUsageStats(
            current: memoryUsages.last ?? 0,
            average: memoryUsages.isEmpty ? 0 : memoryUsages.reduce(0, +) / Double(memoryUsages.count),
            peak: memoryUsages.max() ?? 0,
            pressureEvents: alerts.filter { $0.category == .memory }.count
        )
        
        let topSlowOperations = operations
            .sorted { $0.duration > $1.duration }
            .prefix(10)
            .map { op in
                PerformanceReport.SlowOperation(
                    name: op.token.operationName,
                    category: op.token.category,
                    duration: op.duration,
                    timestamp: Date(timeIntervalSinceReferenceDate: op.endTime),
                    memoryUsage: op.endMemory
                )
            }
        
        return PerformanceReport.PerformanceSummary(
            totalOperations: totalOperations,
            averageResponseTime: averageResponseTime,
            errorRate: errorRate,
            memoryUsage: memoryStats,
            topSlowOperations: Array(topSlowOperations)
        )
    }
    
    private func generateCategoryReports(from operations: [CompletedOperation]) -> [PerformanceCategory: PerformanceReport.CategoryReport] {
        var reports: [PerformanceCategory: PerformanceReport.CategoryReport] = [:]
        
        for category in PerformanceCategory.allCases {
            let categoryOps = operations.filter { $0.token.category == category }
            
            if !categoryOps.isEmpty {
                let durations = categoryOps.map { $0.duration }
                let sortedDurations = durations.sorted()
                let p95Index = Int(Double(sortedDurations.count) * 0.95)
                
                reports[category] = PerformanceReport.CategoryReport(
                    category: category,
                    operationCount: categoryOps.count,
                    averageTime: durations.reduce(0, +) / Double(durations.count),
                    minTime: durations.min() ?? 0,
                    maxTime: durations.max() ?? 0,
                    p95Time: p95Index < sortedDurations.count ? sortedDurations[p95Index] : 0,
                    errorCount: 0, // 暂时设为0
                    memoryImpact: categoryOps.map { Double($0.memoryDelta) }.reduce(0, +) / 1024 / 1024
                )
            }
        }
        
        return reports
    }
    
    private func analyzePerformanceAndGenerateRecommendations(_ report: PerformanceReport) async {
        var newRecommendations: [PerformanceRecommendation] = []
        
        // 分析慢操作
        if report.summary.averageResponseTime > 1.0 {
            newRecommendations.append(PerformanceRecommendation(
                id: UUID(),
                category: .ui,
                priority: .high,
                title: "优化响应时间",
                description: "平均响应时间过长(\(String(format: "%.2f", report.summary.averageResponseTime))秒)",
                impact: "用户体验下降，应用响应缓慢",
                actionItems: [
                    "检查并优化慢查询",
                    "实施异步处理",
                    "优化算法复杂度",
                    "考虑使用缓存"
                ]
            ))
        }
        
        // 分析内存使用
        if report.summary.memoryUsage.peak > 400 {
            newRecommendations.append(PerformanceRecommendation(
                id: UUID(),
                category: .memory,
                priority: .medium,
                title: "优化内存使用",
                description: "峰值内存使用过高(\(String(format: "%.1f", report.summary.memoryUsage.peak))MB)",
                impact: "可能导致应用崩溃或系统性能下降",
                actionItems: [
                    "检查内存泄漏",
                    "优化图片缓存策略",
                    "实施延迟加载",
                    "清理未使用的对象"
                ]
            ))
        }
        
        await MainActor.run {
            self.recommendations = newRecommendations
        }
    }
    
    deinit {
        memoryMonitorTimer?.invalidate()
        reportGenerationTimer?.invalidate()
    }
}

// MARK: - 便利扩展
extension ManualBoxPerformanceMonitoringService {
    
    // 便利方法：监控数据库操作
    func monitorDatabaseOperation<T>(_ operation: () async throws -> T) async rethrows -> T {
        let token = startOperation("database_operation", category: .database)
        defer { endOperation(token) }
        
        return try await operation()
    }
    
    // 便利方法：监控网络请求
    func monitorNetworkRequest<T>(_ operation: () async throws -> T) async rethrows -> T {
        let token = startOperation("network_request", category: .network)
        defer { endOperation(token) }
        
        return try await operation()
    }
    
    // 便利方法：监控UI操作
    func monitorUIOperation<T>(_ operationName: String, _ operation: () async throws -> T) async rethrows -> T {
        let token = startOperation(operationName, category: .ui)
        defer { endOperation(token) }
        
        return try await operation()
    }
    
    // 便利方法：监控文件操作
    func monitorFileOperation<T>(_ operation: () async throws -> T) async rethrows -> T {
        let token = startOperation("file_operation", category: .file)
        defer { endOperation(token) }
        
        return try await operation()
    }
}

// MARK: - SwiftUI 环境键
struct PerformanceMonitoringServiceKey: EnvironmentKey {
    static let defaultValue: ManualBoxPerformanceMonitoringService = ManualBoxPerformanceMonitoringService.shared
}

extension EnvironmentValues {
    var performanceMonitoringService: ManualBoxPerformanceMonitoringService {
        get { self[PerformanceMonitoringServiceKey.self] }
        set { self[PerformanceMonitoringServiceKey.self] = newValue }
    }
}