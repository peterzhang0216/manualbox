//
//  SearchPerformanceMonitor.swift
//  ManualBox
//
//  Created by Assistant on 2024/12/19.
//

import Foundation
import Combine

// MARK: - 搜索阶段
enum SearchPhase: String, CaseIterable {
    case indexing = "indexing"
    case querying = "querying"
    case filtering = "filtering"
    case ranking = "ranking"
    case rendering = "rendering"
    
    var displayName: String {
        switch self {
        case .indexing: return "索引构建"
        case .querying: return "查询执行"
        case .filtering: return "结果过滤"
        case .ranking: return "相关性排序"
        case .rendering: return "结果渲染"
        }
    }
}

// MARK: - 性能趋势
enum PerformanceTrend {
    case improving
    case stable
    case declining
}



// MARK: - 性能瓶颈
struct PerformanceBottleneck {
    let phase: SearchPhase
    let severity: BottleneckSeverity
    let description: String
    let impact: Double // 0.0 - 1.0
    let suggestedFix: String
}

// MARK: - 性能建议
// PerformanceRecommendation 已在 PerformanceMonitoringService.swift 中定义

// MARK: - 搜索会话指标
struct SearchSessionMetrics {
    let sessionId: UUID
    let startTime: Date
    let endTime: Date?
    let phases: [SearchPhase: TimeInterval]
    let totalDuration: TimeInterval
    let resultCount: Int
    let success: Bool
    let errorMessage: String?
}

// MARK: - 聚合性能指标
struct AggregatedPerformanceMetrics {
    let totalSearches: Int
    let averageSearchTime: TimeInterval
    let successRate: Double
    let averageResultCount: Double
    let performanceTrend: PerformanceTrend?
    let phaseBreakdown: [SearchPhase: TimeInterval]
}

// MARK: - 搜索性能分析
struct SearchPerformanceAnalysis {
    let totalSessions: Int
    let successRate: Double
    let averageDuration: TimeInterval
    let averageResultCount: Double
    let averageRelevance: Double
    let bottlenecks: [PerformanceBottleneck]
    let recommendations: [PerformanceRecommendation]
    let phaseAnalysis: [SearchPhase: PhaseAnalysis]
}

// MARK: - 阶段分析
struct PhaseAnalysis {
    let averageDuration: TimeInterval
    let maxDuration: TimeInterval
    let minDuration: TimeInterval
    let trend: PerformanceTrend
    let bottleneckCount: Int
}

// MARK: - 搜索性能监控器
@MainActor
class SearchPerformanceMonitor: ObservableObject {
    static let shared = SearchPerformanceMonitor()
    
    // MARK: - Published Properties
    @Published var isMonitoring: Bool = false
    @Published var performanceMetrics: AggregatedPerformanceMetrics
    @Published var currentSession: SearchSessionMetrics?
    @Published var recentSessions: [SearchSessionMetrics] = []
    
    // MARK: - Private Properties
    private var sessionHistory: [SearchSessionMetrics] = []
    private var currentSessionStartTime: Date?
    private var currentSessionPhases: [SearchPhase: TimeInterval] = [:]
    private var currentPhaseStartTime: Date?
    private var currentPhase: SearchPhase?
    
    private let maxHistoryCount = 1000
    
    private init() {
        self.performanceMetrics = AggregatedPerformanceMetrics(
            totalSearches: 0,
            averageSearchTime: 0,
            successRate: 1.0,
            averageResultCount: 0,
            performanceTrend: nil,
            phaseBreakdown: [:]
        )
        
        startMonitoring()
    }
    
    // MARK: - Public Methods
    
    func startMonitoring() {
        isMonitoring = true
        print("🔍 搜索性能监控已启动")
    }
    
    func stopMonitoring() {
        isMonitoring = false
        print("🔍 搜索性能监控已停止")
    }
    
    func startSearchSession() -> UUID {
        let sessionId = UUID()
        currentSessionStartTime = Date()
        currentSessionPhases = [:]
        currentPhase = nil
        currentPhaseStartTime = nil
        
        print("🔍 开始搜索会话: \(sessionId)")
        return sessionId
    }
    
    func startPhase(_ phase: SearchPhase) {
        // 结束当前阶段
        if let currentPhase = currentPhase,
           let startTime = currentPhaseStartTime {
            let duration = Date().timeIntervalSince(startTime)
            currentSessionPhases[currentPhase] = duration
        }
        
        // 开始新阶段
        currentPhase = phase
        currentPhaseStartTime = Date()
        
        print("🔍 开始阶段: \(phase.displayName)")
    }
    
    func endSearchSession(
        sessionId: UUID,
        resultCount: Int,
        success: Bool,
        errorMessage: String? = nil
    ) {
        guard let startTime = currentSessionStartTime else { return }
        
        // 结束最后一个阶段
        if let currentPhase = currentPhase,
           let phaseStartTime = currentPhaseStartTime {
            let duration = Date().timeIntervalSince(phaseStartTime)
            currentSessionPhases[currentPhase] = duration
        }
        
        let endTime = Date()
        let totalDuration = endTime.timeIntervalSince(startTime)
        
        let session = SearchSessionMetrics(
            sessionId: sessionId,
            startTime: startTime,
            endTime: endTime,
            phases: currentSessionPhases,
            totalDuration: totalDuration,
            resultCount: resultCount,
            success: success,
            errorMessage: errorMessage
        )
        
        addSession(session)
        updateAggregatedMetrics()
        
        // 重置当前会话
        currentSession = nil
        currentSessionStartTime = nil
        currentSessionPhases = [:]
        currentPhase = nil
        currentPhaseStartTime = nil
        
        print("🔍 结束搜索会话: \(sessionId), 耗时: \(String(format: "%.3f", totalDuration))s")
    }
    
    func getCurrentSessionMetrics() -> SearchSessionMetrics? {
        guard let startTime = currentSessionStartTime else { return nil }
        
        let currentTime = Date()
        let totalDuration = currentTime.timeIntervalSince(startTime)
        
        var phases = currentSessionPhases
        if let currentPhase = currentPhase,
           let phaseStartTime = currentPhaseStartTime {
            let phaseDuration = currentTime.timeIntervalSince(phaseStartTime)
            phases[currentPhase] = phaseDuration
        }
        
        return SearchSessionMetrics(
            sessionId: UUID(),
            startTime: startTime,
            endTime: nil,
            phases: phases,
            totalDuration: totalDuration,
            resultCount: 0,
            success: true,
            errorMessage: nil
        )
    }
    
    func analyzePerformance() -> SearchPerformanceAnalysis {
        let recentSessions = getRecentSessions()
        
        let totalSessions = recentSessions.count
        let successfulSessions = recentSessions.filter { $0.success }
        let successRate = totalSessions > 0 ? Double(successfulSessions.count) / Double(totalSessions) : 1.0
        
        let averageDuration = successfulSessions.isEmpty ? 0 :
            successfulSessions.map { $0.totalDuration }.reduce(0, +) / Double(successfulSessions.count)
        
        let averageResultCount = successfulSessions.isEmpty ? 0 :
            successfulSessions.map { Double($0.resultCount) }.reduce(0, +) / Double(successfulSessions.count)
        
        let bottlenecks = identifyBottlenecks(from: recentSessions)
        let recommendations = generateRecommendations(from: bottlenecks)
        let phaseAnalysis = analyzePhases(from: recentSessions)
        
        return SearchPerformanceAnalysis(
            totalSessions: totalSessions,
            successRate: successRate,
            averageDuration: averageDuration,
            averageResultCount: averageResultCount,
            averageRelevance: 0.85, // 模拟值
            bottlenecks: bottlenecks,
            recommendations: recommendations,
            phaseAnalysis: phaseAnalysis
        )
    }
    
    // MARK: - Private Methods
    
    private func addSession(_ session: SearchSessionMetrics) {
        sessionHistory.append(session)
        recentSessions.append(session)
        
        // 限制历史记录数量
        if sessionHistory.count > maxHistoryCount {
            sessionHistory.removeFirst(sessionHistory.count - maxHistoryCount)
        }
        
        if recentSessions.count > 50 {
            recentSessions.removeFirst(recentSessions.count - 50)
        }
    }
    
    private func updateAggregatedMetrics() {
        let recentSessions = getRecentSessions()
        
        let totalSearches = recentSessions.count
        let successfulSessions = recentSessions.filter { $0.success }
        
        let averageSearchTime = successfulSessions.isEmpty ? 0 :
            successfulSessions.map { $0.totalDuration }.reduce(0, +) / Double(successfulSessions.count)
        
        let successRate = totalSearches > 0 ? Double(successfulSessions.count) / Double(totalSearches) : 1.0
        
        let averageResultCount = successfulSessions.isEmpty ? 0 :
            successfulSessions.map { Double($0.resultCount) }.reduce(0, +) / Double(successfulSessions.count)
        
        let trend = calculatePerformanceTrend()
        let phaseBreakdown = calculatePhaseBreakdown(from: successfulSessions)
        
        performanceMetrics = AggregatedPerformanceMetrics(
            totalSearches: totalSearches,
            averageSearchTime: averageSearchTime,
            successRate: successRate,
            averageResultCount: averageResultCount,
            performanceTrend: trend,
            phaseBreakdown: phaseBreakdown
        )
    }
    
    private func getRecentSessions() -> [SearchSessionMetrics] {
        let cutoffDate = Calendar.current.date(byAdding: .hour, value: -24, to: Date()) ?? Date()
        return sessionHistory.filter { $0.startTime >= cutoffDate }
    }
    
    private func calculatePerformanceTrend() -> PerformanceTrend? {
        let recentSessions = getRecentSessions()
        guard recentSessions.count >= 10 else { return nil }
        
        let halfPoint = recentSessions.count / 2
        let firstHalf = Array(recentSessions.prefix(halfPoint))
        let secondHalf = Array(recentSessions.suffix(halfPoint))
        
        let firstAverage = firstHalf.map { $0.totalDuration }.reduce(0, +) / Double(firstHalf.count)
        let secondAverage = secondHalf.map { $0.totalDuration }.reduce(0, +) / Double(secondHalf.count)
        
        let change = (secondAverage - firstAverage) / firstAverage
        
        if abs(change) < 0.05 {
            return .stable
        } else if change < 0 {
            return .improving
        } else {
            return .declining
        }
    }
    
    private func calculatePhaseBreakdown(from sessions: [SearchSessionMetrics]) -> [SearchPhase: TimeInterval] {
        var breakdown: [SearchPhase: TimeInterval] = [:]
        
        for phase in SearchPhase.allCases {
            let phaseDurations = sessions.compactMap { $0.phases[phase] }
            if !phaseDurations.isEmpty {
                breakdown[phase] = phaseDurations.reduce(0, +) / Double(phaseDurations.count)
            }
        }
        
        return breakdown
    }
    
    private func identifyBottlenecks(from sessions: [SearchSessionMetrics]) -> [PerformanceBottleneck] {
        var bottlenecks: [PerformanceBottleneck] = []
        
        // 分析每个阶段的性能
        for phase in SearchPhase.allCases {
            let phaseDurations = sessions.compactMap { $0.phases[phase] }
            guard !phaseDurations.isEmpty else { continue }
            
            let averageDuration = phaseDurations.reduce(0, +) / Double(phaseDurations.count)
            let maxDuration = phaseDurations.max() ?? 0
            
            // 如果平均耗时超过阈值，认为是瓶颈
            let threshold: TimeInterval
            switch phase {
            case .indexing: threshold = 0.1
            case .querying: threshold = 0.05
            case .filtering: threshold = 0.02
            case .ranking: threshold = 0.03
            case .rendering: threshold = 0.01
            }
            
            if averageDuration > threshold {
                let severity: BottleneckSeverity
                if averageDuration > threshold * 3 {
                    severity = .high
                } else if averageDuration > threshold * 2 {
                    severity = .medium
                } else {
                    severity = .low
                }
                
                let bottleneck = PerformanceBottleneck(
                    phase: phase,
                    severity: severity,
                    description: "\(phase.displayName)阶段平均耗时\(String(format: "%.3f", averageDuration))秒，超过建议阈值",
                    impact: min(1.0, averageDuration / threshold - 1.0),
                    suggestedFix: getSuggestedFix(for: phase)
                )
                
                bottlenecks.append(bottleneck)
            }
        }
        
        return bottlenecks.sorted { $0.impact > $1.impact }
    }
    
    private func getSuggestedFix(for phase: SearchPhase) -> String {
        switch phase {
        case .indexing:
            return "优化索引构建算法，考虑增量索引"
        case .querying:
            return "优化查询语句，添加适当的索引"
        case .filtering:
            return "优化过滤条件，减少不必要的计算"
        case .ranking:
            return "简化相关性算法，使用缓存"
        case .rendering:
            return "优化UI渲染，使用虚拟化列表"
        }
    }
    
    private func generateRecommendations(from bottlenecks: [PerformanceBottleneck]) -> [PerformanceRecommendation] {
        var recommendations: [PerformanceRecommendation] = []
        
        // 基于瓶颈生成建议
        for bottleneck in bottlenecks.prefix(3) {
            let recommendation = PerformanceRecommendation(
                title: "优化\(bottleneck.phase.displayName)",
                description: bottleneck.suggestedFix,
                priority: bottleneck.severity == .high ? 1 : (bottleneck.severity == .medium ? 2 : 3),
                estimatedImpact: "预计可提升\(Int(bottleneck.impact * 100))%性能",
                implementationEffort: bottleneck.severity == .high ? "高" : "中"
            )
            recommendations.append(recommendation)
        }
        
        // 添加通用建议
        if recommendations.isEmpty {
            recommendations.append(PerformanceRecommendation(
                title: "启用搜索缓存",
                description: "为常见搜索查询启用缓存机制",
                priority: 2,
                estimatedImpact: "预计可提升20-30%性能",
                implementationEffort: "低"
            ))
        }
        
        return recommendations
    }
    
    private func analyzePhases(from sessions: [SearchSessionMetrics]) -> [SearchPhase: PhaseAnalysis] {
        var analysis: [SearchPhase: PhaseAnalysis] = [:]
        
        for phase in SearchPhase.allCases {
            let phaseDurations = sessions.compactMap { $0.phases[phase] }
            guard !phaseDurations.isEmpty else { continue }
            
            let averageDuration = phaseDurations.reduce(0, +) / Double(phaseDurations.count)
            let maxDuration = phaseDurations.max() ?? 0
            let minDuration = phaseDurations.min() ?? 0
            
            // 简化的趋势计算
            let trend: PerformanceTrend = .stable
            
            analysis[phase] = PhaseAnalysis(
                averageDuration: averageDuration,
                maxDuration: maxDuration,
                minDuration: minDuration,
                trend: trend,
                bottleneckCount: 0
            )
        }
        
        return analysis
    }
}