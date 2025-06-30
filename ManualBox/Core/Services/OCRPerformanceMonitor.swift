import Foundation
import Combine

// MARK: - OCR性能监控器
/// 专门负责OCR处理的性能监控和统计
@MainActor
class OCRPerformanceMonitor: ObservableObject {
    
    @Published var currentStats: OCRProcessingStats = OCRProcessingStats()
    @Published var realtimeMetrics: OCRRealtimeMetrics = OCRRealtimeMetrics()
    
    private var processingHistory: [OCRProcessingRecord] = []
    private let maxHistoryCount = 1000
    
    // MARK: - 性能记录
    
    /// 记录OCR处理性能
    func recordProcessing(duration: TimeInterval, textLength: Int, confidence: Float) async {
        let record = OCRProcessingRecord(
            timestamp: Date(),
            duration: duration,
            textLength: textLength,
            confidence: confidence
        )
        
        processingHistory.append(record)
        
        // 保持历史记录在合理范围内
        if processingHistory.count > maxHistoryCount {
            processingHistory.removeFirst(processingHistory.count - maxHistoryCount)
        }
        
        // 更新统计信息
        updateStats()
        updateRealtimeMetrics()
    }
    
    /// 记录OCR错误
    func recordError(_ error: OCRError, context: String = "") async {
        currentStats.totalErrors += 1
        currentStats.lastError = error
        currentStats.lastErrorTime = Date()
        
        // 记录错误类型统计
        switch error {
        case .imageExtractionFailed:
            currentStats.imageExtractionErrors += 1
        case .imageProcessingFailed:
            currentStats.imageProcessingErrors += 1
        case .visionError:
            currentStats.visionErrors += 1
        case .noTextFound:
            currentStats.noTextFoundErrors += 1
        case .processingFailed:
            currentStats.processingFailedErrors += 1
        case .queueFull:
            currentStats.queueFullErrors += 1
        case .networkError:
            currentStats.networkErrors += 1
        case .insufficientMemory:
            currentStats.memoryErrors += 1
        case .unsupportedFormat:
            currentStats.formatErrors += 1
        case .timeout:
            currentStats.timeoutErrors += 1
        }
        
        print("🚨 OCR错误记录: \(error.localizedDescription) - 上下文: \(context)")
    }
    
    /// 记录批量处理性能
    func recordBatchProcessing(totalItems: Int, successCount: Int, totalDuration: TimeInterval) async {
        currentStats.totalBatchOperations += 1
        currentStats.totalBatchItems += totalItems
        currentStats.successfulBatchItems += successCount
        
        let averageTimePerItem = totalDuration / Double(totalItems)
        
        // 更新批量处理统计
        if currentStats.averageBatchProcessingTime == 0 {
            currentStats.averageBatchProcessingTime = averageTimePerItem
        } else {
            currentStats.averageBatchProcessingTime = (currentStats.averageBatchProcessingTime + averageTimePerItem) / 2.0
        }
        
        print("📊 批量处理完成: \(successCount)/\(totalItems) 成功, 平均耗时: \(String(format: "%.2f", averageTimePerItem))秒/项")
    }
    
    // MARK: - 性能分析
    
    /// 获取性能分析报告
    func getPerformanceReport() -> OCRPerformanceReport {
        let recentRecords = Array(processingHistory.suffix(100))
        
        let averageDuration = recentRecords.isEmpty ? 0 : 
            recentRecords.map { $0.duration }.reduce(0, +) / Double(recentRecords.count)
        
        let averageConfidence = recentRecords.isEmpty ? 0 : 
            recentRecords.map { $0.confidence }.reduce(0, +) / Float(recentRecords.count)
        
        let averageTextLength = recentRecords.isEmpty ? 0 : 
            recentRecords.map { $0.textLength }.reduce(0, +) / recentRecords.count
        
        let successRate = currentStats.totalRequests > 0 ? 
            Float(currentStats.successfulRequests) / Float(currentStats.totalRequests) : 0
        
        return OCRPerformanceReport(
            totalRequests: currentStats.totalRequests,
            successfulRequests: currentStats.successfulRequests,
            totalErrors: currentStats.totalErrors,
            successRate: successRate,
            averageProcessingTime: averageDuration,
            averageConfidence: averageConfidence,
            averageTextLength: averageTextLength,
            recentPerformanceTrend: calculatePerformanceTrend(),
            errorBreakdown: getErrorBreakdown(),
            recommendations: generateRecommendations()
        )
    }
    
    /// 获取实时性能指标
    func getRealtimeMetrics() -> OCRRealtimeMetrics {
        return realtimeMetrics
    }
    
    /// 重置统计信息
    func resetStats() {
        currentStats = OCRProcessingStats()
        realtimeMetrics = OCRRealtimeMetrics()
        processingHistory.removeAll()
        
        print("📊 OCR性能统计已重置")
    }
    
    // MARK: - 私有方法
    
    private func updateStats() {
        currentStats.totalRequests += 1
        currentStats.successfulRequests += 1
        currentStats.lastProcessingTime = Date()
        
        // 更新平均处理时间
        if let lastRecord = processingHistory.last {
            if currentStats.averageProcessingTime == 0 {
                currentStats.averageProcessingTime = lastRecord.duration
            } else {
                currentStats.averageProcessingTime = (currentStats.averageProcessingTime + lastRecord.duration) / 2.0
            }
            
            // 更新平均置信度
            if currentStats.averageConfidence == 0 {
                currentStats.averageConfidence = lastRecord.confidence
            } else {
                currentStats.averageConfidence = (currentStats.averageConfidence + lastRecord.confidence) / 2.0
            }
        }
    }
    
    private func updateRealtimeMetrics() {
        let recentRecords = Array(processingHistory.suffix(10))
        
        if !recentRecords.isEmpty {
            realtimeMetrics.recentAverageTime = recentRecords.map { $0.duration }.reduce(0, +) / Double(recentRecords.count)
            realtimeMetrics.recentAverageConfidence = recentRecords.map { $0.confidence }.reduce(0, +) / Float(recentRecords.count)
            realtimeMetrics.recentThroughput = Double(recentRecords.count) / 60.0 // 每分钟处理数
        }
        
        realtimeMetrics.currentQueueLength = 0 // 这个需要从外部传入
        realtimeMetrics.memoryUsage = getCurrentMemoryUsage()
        realtimeMetrics.lastUpdateTime = Date()
    }
    
    private func calculatePerformanceTrend() -> OCRPerformanceTrend {
        guard processingHistory.count >= 20 else { return .stable }
        
        let recentRecords = Array(processingHistory.suffix(10))
        let olderRecords = Array(processingHistory.suffix(20).prefix(10))
        
        let recentAverage = recentRecords.map { $0.duration }.reduce(0, +) / Double(recentRecords.count)
        let olderAverage = olderRecords.map { $0.duration }.reduce(0, +) / Double(olderRecords.count)
        
        let improvement = (olderAverage - recentAverage) / olderAverage
        
        if improvement > 0.1 {
            return .improving
        } else if improvement < -0.1 {
            return .degrading
        } else {
            return .stable
        }
    }
    
    private func getErrorBreakdown() -> [String: Int] {
        return [
            "图像提取错误": currentStats.imageExtractionErrors,
            "图像处理错误": currentStats.imageProcessingErrors,
            "视觉识别错误": currentStats.visionErrors,
            "未找到文本": currentStats.noTextFoundErrors,
            "处理失败": currentStats.processingFailedErrors,
            "队列已满": currentStats.queueFullErrors,
            "网络错误": currentStats.networkErrors,
            "内存不足": currentStats.memoryErrors,
            "格式不支持": currentStats.formatErrors,
            "处理超时": currentStats.timeoutErrors
        ]
    }
    
    private func generateRecommendations() -> [String] {
        var recommendations: [String] = []
        
        // 基于错误统计生成建议
        if currentStats.memoryErrors > 0 {
            recommendations.append("建议优化内存使用，考虑降低图像分辨率或分批处理")
        }
        
        if currentStats.timeoutErrors > 0 {
            recommendations.append("建议增加处理超时时间或优化图像预处理")
        }
        
        if currentStats.averageProcessingTime > 10.0 {
            recommendations.append("处理时间较长，建议优化图像预处理流程")
        }
        
        if currentStats.averageConfidence < 0.7 {
            recommendations.append("识别置信度较低，建议改进图像质量或调整OCR参数")
        }
        
        // 基于性能趋势生成建议
        let trend = calculatePerformanceTrend()
        switch trend {
        case .degrading:
            recommendations.append("性能呈下降趋势，建议检查系统资源使用情况")
        case .stable:
            recommendations.append("性能稳定，可以考虑进一步优化以提升效率")
        case .improving:
            recommendations.append("性能持续改善，当前优化策略有效")
        }
        
        return recommendations
    }
    
    private func getCurrentMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Double(info.resident_size) / 1024.0 / 1024.0 // MB
        } else {
            return 0.0
        }
    }
}

// MARK: - 性能记录结构
struct OCRProcessingRecord {
    let timestamp: Date
    let duration: TimeInterval
    let textLength: Int
    let confidence: Float
}

// MARK: - 实时性能指标
struct OCRRealtimeMetrics {
    var recentAverageTime: TimeInterval = 0
    var recentAverageConfidence: Float = 0
    var recentThroughput: Double = 0 // 每分钟处理数
    var currentQueueLength: Int = 0
    var memoryUsage: Double = 0 // MB
    var lastUpdateTime: Date = Date()
}

// MARK: - 性能报告
struct OCRPerformanceReport {
    let totalRequests: Int
    let successfulRequests: Int
    let totalErrors: Int
    let successRate: Float
    let averageProcessingTime: TimeInterval
    let averageConfidence: Float
    let averageTextLength: Int
    let recentPerformanceTrend: OCRPerformanceTrend
    let errorBreakdown: [String: Int]
    let recommendations: [String]

    /// 生成格式化的文本报告
    var formattedReport: String {
        var report = "OCR 性能报告\n"
        report += String(repeating: "=", count: 40) + "\n\n"

        report += "📊 基本统计:\n"
        report += "总请求数: \(totalRequests)\n"
        report += "成功请求: \(successfulRequests)\n"
        report += "错误数量: \(totalErrors)\n"
        report += "成功率: \(String(format: "%.1f", successRate * 100))%\n\n"

        report += "⏱️ 性能指标:\n"
        report += "平均处理时间: \(String(format: "%.2f", averageProcessingTime))秒\n"
        report += "平均置信度: \(String(format: "%.1f", averageConfidence * 100))%\n"
        report += "平均文本长度: \(averageTextLength)字符\n"
        report += "性能趋势: \(recentPerformanceTrend.displayName)\n\n"

        if !errorBreakdown.isEmpty {
            report += "❌ 错误分析:\n"
            for (errorType, count) in errorBreakdown.sorted(by: { $0.value > $1.value }) {
                if count > 0 {
                    report += "\(errorType): \(count)次\n"
                }
            }
            report += "\n"
        }

        if !recommendations.isEmpty {
            report += "💡 优化建议:\n"
            for (index, recommendation) in recommendations.enumerated() {
                report += "\(index + 1). \(recommendation)\n"
            }
        }

        return report
    }
}

// MARK: - 性能趋势枚举
enum OCRPerformanceTrend {
    case improving
    case stable
    case degrading

    var displayName: String {
        switch self {
        case .improving:
            return "改善中"
        case .stable:
            return "稳定"
        case .degrading:
            return "下降中"
        }
    }
}
