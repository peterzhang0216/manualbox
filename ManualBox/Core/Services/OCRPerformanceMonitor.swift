import Foundation
import os.log

// MARK: - OCR性能监控器
class OCRPerformanceMonitor {
    private let logger = Logger(subsystem: "ManualBox", category: "OCRPerformance")
    private var metrics: OCRRealtimeMetrics
    private var performanceHistory: [OCRPerformanceReport] = []
    private let maxHistoryCount = 100
    
    init() {
        self.metrics = OCRRealtimeMetrics()
    }
    
    // MARK: - 性能监控方法
    func startMonitoring(for requestId: UUID) {
        metrics.activeRequests += 1
        metrics.requestStartTimes[requestId] = Date()
        logger.info("Started monitoring OCR request: \(requestId)")
    }
    
    func stopMonitoring(for requestId: UUID, success: Bool) {
        guard let startTime = metrics.requestStartTimes[requestId] else { return }
        
        let duration = Date().timeIntervalSince(startTime)
        metrics.requestStartTimes.removeValue(forKey: requestId)
        metrics.activeRequests = max(0, metrics.activeRequests - 1)
        
        if success {
            metrics.successfulRequests += 1
            metrics.totalProcessingTime += duration
            metrics.averageProcessingTime = metrics.totalProcessingTime / Double(metrics.successfulRequests)
        } else {
            metrics.failedRequests += 1
        }
        
        updatePerformanceHistory(duration: duration, success: success)
        logger.info("Stopped monitoring OCR request: \(requestId), duration: \(duration)s, success: \(success)")
    }
    
    func recordError(_ error: OCRError, context: String) async {
        metrics.errorCount += 1
        metrics.lastError = error
        metrics.lastErrorTime = Date()
        
        logger.error("OCR Error recorded: \(error.localizedDescription) - Context: \(context)")
    }
    
    func recordMemoryUsage(_ usage: Double) {
        metrics.memoryUsage = usage
        if usage > metrics.peakMemoryUsage {
            metrics.peakMemoryUsage = usage
        }
    }
    
    func recordCPUUsage(_ usage: Double) {
        metrics.cpuUsage = usage
        if usage > metrics.peakCPUUsage {
            metrics.peakCPUUsage = usage
        }
    }
    
    // MARK: - 报告生成
    func generatePerformanceReport() -> OCRPerformanceReport {
        let report = OCRPerformanceReport(
            timestamp: Date(),
            totalRequests: metrics.successfulRequests + metrics.failedRequests,
            successfulRequests: metrics.successfulRequests,
            failedRequests: metrics.failedRequests,
            averageProcessingTime: metrics.averageProcessingTime,
            totalProcessingTime: metrics.totalProcessingTime,
            errorCount: metrics.errorCount,
            memoryUsage: metrics.memoryUsage,
            peakMemoryUsage: metrics.peakMemoryUsage,
            cpuUsage: metrics.cpuUsage,
            peakCPUUsage: metrics.peakCPUUsage,
            activeRequests: metrics.activeRequests
        )
        
        addToHistory(report)
        return report
    }
    
    func getRealtimeMetrics() -> OCRRealtimeMetrics {
        return metrics
    }
    
    func resetMetrics() {
        metrics = OCRRealtimeMetrics()
        performanceHistory.removeAll()
        logger.info("OCR performance metrics reset")
    }
    
    // MARK: - 批量处理记录
    func recordBatchProcessing(totalItems: Int, successCount: Int, totalDuration: TimeInterval) async {
        logger.info("Batch processing completed: \(successCount)/\(totalItems) items in \(totalDuration)s")
    }
    
    func getPerformanceReport() -> OCRPerformanceReport {
        return generatePerformanceReport()
    }
    
    func resetStats() async {
        resetMetrics()
    }
    
    // MARK: - 私有方法
    private func updatePerformanceHistory(duration: TimeInterval, success: Bool) {
        // 更新性能历史记录的逻辑
        if performanceHistory.count >= maxHistoryCount {
            performanceHistory.removeFirst()
        }
    }
    
    private func addToHistory(_ report: OCRPerformanceReport) {
        performanceHistory.append(report)
        if performanceHistory.count > maxHistoryCount {
            performanceHistory.removeFirst()
        }
    }
}

// MARK: - OCR性能报告
struct OCRPerformanceReport {
    let timestamp: Date
    let totalRequests: Int
    let successfulRequests: Int
    let failedRequests: Int
    let averageProcessingTime: TimeInterval
    let totalProcessingTime: TimeInterval
    let errorCount: Int
    let memoryUsage: Double
    let peakMemoryUsage: Double
    let cpuUsage: Double
    let peakCPUUsage: Double
    let activeRequests: Int
    
    var successRate: Double {
        guard totalRequests > 0 else { return 0 }
        return Double(successfulRequests) / Double(totalRequests)
    }
    
    var errorRate: Double {
        guard totalRequests > 0 else { return 0 }
        return Double(failedRequests) / Double(totalRequests)
    }
}

// MARK: - OCR实时指标
struct OCRRealtimeMetrics {
    var activeRequests: Int = 0
    var successfulRequests: Int = 0
    var failedRequests: Int = 0
    var averageProcessingTime: TimeInterval = 0
    var totalProcessingTime: TimeInterval = 0
    var errorCount: Int = 0
    var memoryUsage: Double = 0
    var peakMemoryUsage: Double = 0
    var cpuUsage: Double = 0
    var peakCPUUsage: Double = 0
    var lastError: OCRError?
    var lastErrorTime: Date?
    var requestStartTimes: [UUID: Date] = [:]
    
    var currentThroughput: Double {
        guard totalProcessingTime > 0 else { return 0 }
        return Double(successfulRequests) / totalProcessingTime
    }
}