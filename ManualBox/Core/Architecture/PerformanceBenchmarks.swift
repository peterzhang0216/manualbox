//
//  PerformanceBenchmarks.swift
//  ManualBox
//
//  Created by AI Assistant on 2025/7/22.
//

import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - 性能基准
struct PerformanceBenchmarks {
    
    // MARK: - 响应时间基准
    struct ResponseTimeBenchmark {
        let excellent: TimeInterval
        let good: TimeInterval
        let acceptable: TimeInterval
        let poor: TimeInterval
    }
    
    // MARK: - 内存使用基准
    struct MemoryBenchmark {
        let excellent: Double  // MB
        let good: Double      // MB
        let acceptable: Double // MB
        let poor: Double      // MB
    }
    
    // MARK: - 操作类型基准
    enum OperationType {
        case database
        case network
        case ui
        case file
        case ocr
        case sync
        case startup
        case search
        case export
        case `import`
        case memory
    }
    
    // MARK: - 基准获取方法
    
    func getResponseTimeBenchmark(for operation: OperationType = .ui) -> ResponseTimeBenchmark {
        switch operation {
        case .database:
            return ResponseTimeBenchmark(
                excellent: 0.1,   // 100ms
                good: 0.5,        // 500ms
                acceptable: 2.0,  // 2s
                poor: 5.0         // 5s
            )
        case .network:
            return ResponseTimeBenchmark(
                excellent: 1.0,   // 1s
                good: 3.0,        // 3s
                acceptable: 10.0, // 10s
                poor: 30.0        // 30s
            )
        case .ui:
            return ResponseTimeBenchmark(
                excellent: 0.016, // 16ms (60fps)
                good: 0.033,      // 33ms (30fps)
                acceptable: 0.1,  // 100ms
                poor: 0.5         // 500ms
            )
        case .file:
            return ResponseTimeBenchmark(
                excellent: 0.5,   // 500ms
                good: 2.0,        // 2s
                acceptable: 5.0,  // 5s
                poor: 15.0        // 15s
            )
        case .ocr:
            return ResponseTimeBenchmark(
                excellent: 1.0,   // 1s
                good: 3.0,        // 3s
                acceptable: 10.0, // 10s
                poor: 30.0        // 30s
            )
        case .sync:
            return ResponseTimeBenchmark(
                excellent: 2.0,   // 2s
                good: 10.0,       // 10s
                acceptable: 30.0, // 30s
                poor: 120.0       // 2min
            )
        case .startup:
            return ResponseTimeBenchmark(
                excellent: 1.0,   // 1s
                good: 3.0,        // 3s
                acceptable: 5.0,  // 5s
                poor: 10.0        // 10s
            )
        case .search:
            return ResponseTimeBenchmark(
                excellent: 0.1,   // 100ms
                good: 0.5,        // 500ms
                acceptable: 2.0,  // 2s
                poor: 5.0         // 5s
            )
        case .export:
            return ResponseTimeBenchmark(
                excellent: 2.0,   // 2s
                good: 10.0,       // 10s
                acceptable: 30.0, // 30s
                poor: 120.0       // 2min
            )
        case .import:
            return ResponseTimeBenchmark(
                excellent: 1.0,   // 1s
                good: 5.0,        // 5s
                acceptable: 15.0, // 15s
                poor: 60.0        // 1min
            )
        }
    }
    
    func getMemoryBenchmark(for operation: OperationType = .ui) -> MemoryBenchmark {
        switch operation {
        case .database:
            return MemoryBenchmark(
                excellent: 50,    // 50MB
                good: 100,        // 100MB
                acceptable: 200,  // 200MB
                poor: 400         // 400MB
            )
        case .network:
            return MemoryBenchmark(
                excellent: 20,    // 20MB
                good: 50,         // 50MB
                acceptable: 100,  // 100MB
                poor: 200         // 200MB
            )
        case .ui:
            return MemoryBenchmark(
                excellent: 100,   // 100MB
                good: 200,        // 200MB
                acceptable: 300,  // 300MB
                poor: 500         // 500MB
            )
        case .file:
            return MemoryBenchmark(
                excellent: 30,    // 30MB
                good: 100,        // 100MB
                acceptable: 200,  // 200MB
                poor: 400         // 400MB
            )
        case .ocr:
            return MemoryBenchmark(
                excellent: 100,   // 100MB
                good: 200,        // 200MB
                acceptable: 400,  // 400MB
                poor: 800         // 800MB
            )
        case .sync:
            return MemoryBenchmark(
                excellent: 50,    // 50MB
                good: 150,        // 150MB
                acceptable: 300,  // 300MB
                poor: 600         // 600MB
            )
        case .startup:
            return MemoryBenchmark(
                excellent: 80,    // 80MB
                good: 150,        // 150MB
                acceptable: 250,  // 250MB
                poor: 400         // 400MB
            )
        case .search:
            return MemoryBenchmark(
                excellent: 30,    // 30MB
                good: 80,         // 80MB
                acceptable: 150,  // 150MB
                poor: 300         // 300MB
            )
        case .export:
            return MemoryBenchmark(
                excellent: 100,   // 100MB
                good: 250,        // 250MB
                acceptable: 500,  // 500MB
                poor: 1000        // 1GB
            )
        case .import:
            return MemoryBenchmark(
                excellent: 80,    // 80MB
                good: 200,        // 200MB
                acceptable: 400,  // 400MB
                poor: 800         // 800MB
            )
        }
    }
    
    // MARK: - 设备特定基准
    
    func getDeviceSpecificBenchmarks() -> DeviceBenchmarks {
        #if canImport(UIKit)
        let deviceModel = UIDevice.current.model
        let systemVersion = UIDevice.current.systemVersion
        #else
        let deviceModel = "Mac"
        let systemVersion = ProcessInfo.processInfo.operatingSystemVersionString
        #endif
        
        // 根据设备型号调整基准
        if deviceModel.contains("iPad") {
            return DeviceBenchmarks(
                memoryMultiplier: 1.5,  // iPad通常有更多内存
                cpuMultiplier: 1.2,     // 更强的处理器
                storageMultiplier: 1.0
            )
        } else {
            return DeviceBenchmarks(
                memoryMultiplier: 1.0,
                cpuMultiplier: 1.0,
                storageMultiplier: 1.0
            )
        }
    }
    
    struct DeviceBenchmarks {
        let memoryMultiplier: Double
        let cpuMultiplier: Double
        let storageMultiplier: Double
    }
    
    // MARK: - 性能等级评估
    
    func getPerformanceGrade(responseTime: TimeInterval, for operation: OperationType) -> PerformanceGrade {
        let benchmark = getResponseTimeBenchmark(for: operation)
        
        if responseTime <= benchmark.excellent {
            return .excellent
        } else if responseTime <= benchmark.good {
            return .good
        } else if responseTime <= benchmark.acceptable {
            return .acceptable
        } else {
            return .poor
        }
    }
    
    func getMemoryGrade(memoryUsage: Double, for operation: OperationType) -> PerformanceGrade {
        let benchmark = getMemoryBenchmark(for: operation)
        
        if memoryUsage <= benchmark.excellent {
            return .excellent
        } else if memoryUsage <= benchmark.good {
            return .good
        } else if memoryUsage <= benchmark.acceptable {
            return .acceptable
        } else {
            return .poor
        }
    }
    
    enum PerformanceGrade: String, CaseIterable {
        case excellent = "优秀"
        case good = "良好"
        case acceptable = "可接受"
        case poor = "较差"
        
        var color: Color {
            switch self {
            case .excellent: return .green
            case .good: return .blue
            case .acceptable: return .orange
            case .poor: return .red
            }
        }
        
        var score: Double {
            switch self {
            case .excellent: return 100.0
            case .good: return 80.0
            case .acceptable: return 60.0
            case .poor: return 40.0
            }
        }
    }
    
    // MARK: - 基准建议
    
    func getOptimizationSuggestions(for operation: OperationType, currentPerformance: PerformanceGrade) -> [OptimizationSuggestion] {
        var suggestions: [OptimizationSuggestion] = []
        
        switch operation {
        case .database:
            if currentPerformance == .poor || currentPerformance == .acceptable {
                suggestions.append(OptimizationSuggestion(
                    title: "优化数据库查询",
                    description: "使用索引、批量操作和分页加载",
                    priority: .high,
                    estimatedImprovement: "50-80%"
                ))
            }
            
        case .ui:
            if currentPerformance == .poor {
                suggestions.append(OptimizationSuggestion(
                    title: "优化UI渲染",
                    description: "减少视图层级、使用异步加载",
                    priority: .critical,
                    estimatedImprovement: "60-90%"
                ))
            }
            
        case .memory:
            if currentPerformance == .poor {
                suggestions.append(OptimizationSuggestion(
                    title: "内存优化",
                    description: "清理缓存、优化图片处理",
                    priority: .high,
                    estimatedImprovement: "40-70%"
                ))
            }
            
        case .network:
            if currentPerformance != .excellent {
                suggestions.append(OptimizationSuggestion(
                    title: "网络优化",
                    description: "使用缓存、压缩数据、并发请求",
                    priority: .medium,
                    estimatedImprovement: "30-60%"
                ))
            }
            
        default:
            break
        }
        
        return suggestions
    }
    
    struct OptimizationSuggestion {
        let title: String
        let description: String
        let priority: Priority
        let estimatedImprovement: String
        
        enum Priority {
            case low, medium, high, critical
            
            var description: String {
                switch self {
                case .low: return "低"
                case .medium: return "中"
                case .high: return "高"
                case .critical: return "紧急"
                }
            }
        }
    }
}

// MARK: - 性能基准管理器
@MainActor
class PerformanceBenchmarkManager: ObservableObject {
    static let shared = PerformanceBenchmarkManager()
    
    @Published var customBenchmarks: [String: PerformanceBenchmarks.ResponseTimeBenchmark] = [:]
    @Published var benchmarkHistory: [BenchmarkSnapshot] = []
    
    private let benchmarks = PerformanceBenchmarks()
    private let userDefaults = UserDefaults.standard
    
    struct BenchmarkSnapshot {
        let timestamp: Date
        let operation: String
        let responseTime: TimeInterval
        let memoryUsage: Double
        let grade: PerformanceBenchmarks.PerformanceGrade
    }
    
    private init() {
        loadCustomBenchmarksFromUserDefaults()
    }
    
    func setBenchmark(for operation: String, benchmark: PerformanceBenchmarks.ResponseTimeBenchmark) {
        customBenchmarks[operation] = benchmark
        saveCustomBenchmarksToUserDefaults()
    }
    
    func getBenchmark(for operation: String) -> PerformanceBenchmarks.ResponseTimeBenchmark {
        if let customBenchmark = customBenchmarks[operation] {
            return customBenchmark
        }
        
        // 尝试映射到标准操作类型
        if let operationType = mapStringToOperationType(operation) {
            return benchmarks.getResponseTimeBenchmark(for: operationType)
        }
        
        // 返回默认基准
        return benchmarks.getResponseTimeBenchmark()
    }
    
    func recordPerformance(operation: String, responseTime: TimeInterval, memoryUsage: Double) {
        let _ = getBenchmark(for: operation)
        let grade = benchmarks.getPerformanceGrade(responseTime: responseTime, for: .ui)
        
        let snapshot = BenchmarkSnapshot(
            timestamp: Date(),
            operation: operation,
            responseTime: responseTime,
            memoryUsage: memoryUsage,
            grade: grade
        )
        
        benchmarkHistory.append(snapshot)
        
        // 限制历史记录数量
        if benchmarkHistory.count > 1000 {
            benchmarkHistory.removeFirst(benchmarkHistory.count - 1000)
        }
    }
    
    func getPerformanceTrend(for operation: String, days: Int = 7) -> PerformanceTrend {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let recentSnapshots = benchmarkHistory.filter { 
            $0.operation == operation && $0.timestamp >= cutoffDate 
        }
        
        guard !recentSnapshots.isEmpty else {
            return PerformanceTrend(direction: .stable, change: 0, confidence: 0)
        }
        
        let responseTimes = recentSnapshots.map { $0.responseTime }
        let firstHalf = responseTimes.prefix(responseTimes.count / 2)
        let secondHalf = responseTimes.suffix(responseTimes.count / 2)
        
        let firstAverage = firstHalf.reduce(0, +) / Double(firstHalf.count)
        let secondAverage = secondHalf.reduce(0, +) / Double(secondHalf.count)
        
        let change = (secondAverage - firstAverage) / firstAverage
        let confidence = min(1.0, Double(recentSnapshots.count) / 50.0) // 基于样本数量的置信度
        
        let direction: PerformanceTrend.Direction
        if abs(change) < 0.05 { // 5%以内认为是稳定
            direction = .stable
        } else if change < 0 {
            direction = .improving // 响应时间减少是改善
        } else {
            direction = .declining
        }
        
        return PerformanceTrend(direction: direction, change: change, confidence: confidence)
    }
    
    struct PerformanceTrend {
        let direction: Direction
        let change: Double // 变化百分比
        let confidence: Double // 置信度 0-1
        
        enum Direction {
            case improving, stable, declining
            
            var emoji: String {
                switch self {
                case .improving: return "📈"
                case .stable: return "➡️"
                case .declining: return "📉"
                }
            }
            
            var description: String {
                switch self {
                case .improving: return "改善"
                case .stable: return "稳定"
                case .declining: return "下降"
                }
            }
        }
    }
    
    // MARK: - 私有方法
    
    private func mapStringToOperationType(_ operation: String) -> PerformanceBenchmarks.OperationType? {
        switch operation.lowercased() {
        case let op where op.contains("database") || op.contains("db"):
            return .database
        case let op where op.contains("network") || op.contains("api"):
            return .network
        case let op where op.contains("ui") || op.contains("view"):
            return .ui
        case let op where op.contains("file") || op.contains("io"):
            return .file
        case let op where op.contains("ocr") || op.contains("text"):
            return .ocr
        case let op where op.contains("sync") || op.contains("cloud"):
            return .sync
        case let op where op.contains("startup") || op.contains("launch"):
            return .startup
        case let op where op.contains("search") || op.contains("query"):
            return .search
        case let op where op.contains("export"):
            return .export
        case let op where op.contains("import"):
            return .import
        default:
            return nil
        }
    }
    
    private func loadCustomBenchmarksFromUserDefaults() {
        // 从UserDefaults加载自定义基准
        // 这里可以实现持久化逻辑
    }
    
    private func saveCustomBenchmarksToUserDefaults() {
        // 保存自定义基准到UserDefaults
        // 这里可以实现持久化逻辑
    }
}