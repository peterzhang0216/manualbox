import Foundation
import os.log

// MARK: - 搜索性能监控服务
@MainActor
class SearchPerformanceMonitor: ObservableObject {
    static let shared = SearchPerformanceMonitor()
    
    @Published var performanceMetrics: SearchPerformanceMonitorMetrics = SearchPerformanceMonitorMetrics()
    @Published var isMonitoring = false
    
    private let logger = Logger(subsystem: "com.manualbox.search", category: "performance")
    private var searchSessions: [SearchSession] = []
    private var currentSession: SearchSession?
    
    private init() {
        loadPerformanceHistory()
    }
    
    // MARK: - 搜索会话管理
    
    /// 开始新的搜索会话
    func startSearchSession(query: String, filters: AdvancedSearchFilters? = nil) {
        let session = SearchSession(
            id: UUID(),
            query: query,
            filters: filters,
            startTime: Date(),
            metrics: SessionMetrics()
        )
        
        currentSession = session
        isMonitoring = true
        
        logger.info("开始搜索会话: \(query)")
    }
    
    /// 记录搜索阶段
    func recordSearchPhase(_ phase: SearchPhase, duration: TimeInterval) {
        guard var session = currentSession else { return }
        
        session.metrics.phases[phase] = duration
        currentSession = session
        
        logger.debug("搜索阶段 \(phase.rawValue) 耗时: \(duration)ms")
    }
    
    /// 记录搜索结果
    func recordSearchResults(count: Int, relevanceScores: [Float]) {
        guard var session = currentSession else { return }
        
        session.resultCount = count
        session.averageRelevance = relevanceScores.isEmpty ? 0 : relevanceScores.reduce(0, +) / Float(relevanceScores.count)
        session.metrics.resultProcessingTime = Date().timeIntervalSince(session.startTime)
        
        currentSession = session
        
        logger.info("搜索结果: \(count) 个，平均相关性: \(session.averageRelevance)")
    }
    
    /// 结束搜索会话
    func endSearchSession(success: Bool = true) {
        guard var session = currentSession else { return }
        
        session.endTime = Date()
        session.totalDuration = session.endTime!.timeIntervalSince(session.startTime)
        session.success = success
        
        // 添加到历史记录
        searchSessions.append(session)
        
        // 更新性能指标
        updatePerformanceMetrics()
        
        // 保存历史记录
        savePerformanceHistory()
        
        currentSession = nil
        isMonitoring = false
        
        logger.info("搜索会话结束，总耗时: \(session.totalDuration)ms，成功: \(success)")
    }
    
    // MARK: - 性能分析
    
    /// 分析搜索性能
    func analyzePerformance() -> SearchPerformanceAnalysis {
        let recentSessions = searchSessions.suffix(100) // 分析最近100次搜索
        
        let totalSessions = recentSessions.count
        let successfulSessions = recentSessions.filter { $0.success }.count
        let averageDuration = recentSessions.map { $0.totalDuration }.reduce(0, +) / Double(totalSessions)
        let averageResultCount = recentSessions.map { Double($0.resultCount) }.reduce(0, +) / Double(totalSessions)
        let averageRelevance = recentSessions.map { Double($0.averageRelevance) }.reduce(0, +) / Double(totalSessions)
        
        // 分析性能瓶颈
        let bottlenecks = identifyPerformanceBottlenecks(sessions: Array(recentSessions))
        
        // 生成优化建议
        let recommendations = generateOptimizationRecommendations(analysis: bottlenecks)
        
        return SearchPerformanceAnalysis(
            totalSessions: totalSessions,
            successRate: Double(successfulSessions) / Double(totalSessions),
            averageDuration: averageDuration,
            averageResultCount: averageResultCount,
            averageRelevance: averageRelevance,
            bottlenecks: bottlenecks,
            recommendations: recommendations
        )
    }
    
    private func identifyPerformanceBottlenecks(sessions: [SearchSession]) -> [PerformanceBottleneck] {
        var bottlenecks: [PerformanceBottleneck] = []
        
        // 分析各个阶段的平均耗时
        var phaseAverages: [SearchPhase: TimeInterval] = [:]
        
        for phase in SearchPhase.allCases {
            let phaseTimes = sessions.compactMap { $0.metrics.phases[phase] }
            if !phaseTimes.isEmpty {
                phaseAverages[phase] = phaseTimes.reduce(0, +) / Double(phaseTimes.count)
            }
        }
        
        // 识别耗时过长的阶段
        for (phase, averageTime) in phaseAverages {
            if averageTime > phase.expectedDuration {
                let severity: BottleneckSeverity = averageTime > phase.expectedDuration * 2 ? .high : .medium
                
                bottlenecks.append(PerformanceBottleneck(
                    phase: phase,
                    averageDuration: averageTime,
                    expectedDuration: phase.expectedDuration,
                    severity: severity,
                    description: "阶段 \(phase.displayName) 平均耗时 \(String(format: "%.2f", averageTime))ms，超出预期 \(String(format: "%.2f", phase.expectedDuration))ms"
                ))
            }
        }
        
        // 分析查询复杂度
        let complexQueries = sessions.filter { $0.query.count > 50 || $0.query.components(separatedBy: " ").count > 10 }
        if Double(complexQueries.count) / Double(sessions.count) > 0.3 {
            bottlenecks.append(PerformanceBottleneck(
                phase: .queryProcessing,
                averageDuration: 0,
                expectedDuration: 0,
                severity: .medium,
                description: "复杂查询占比过高（\(complexQueries.count)/\(sessions.count)），建议优化查询处理逻辑"
            ))
        }
        
        return bottlenecks.sorted { $0.severity.rawValue > $1.severity.rawValue }
    }
    
    private func generateOptimizationRecommendations(analysis: [PerformanceBottleneck]) -> [OptimizationRecommendation] {
        var recommendations: [OptimizationRecommendation] = []
        
        for bottleneck in analysis {
            switch bottleneck.phase {
            case .indexLoading:
                recommendations.append(OptimizationRecommendation(
                    title: "优化索引加载",
                    description: "考虑使用增量索引加载或缓存机制",
                    priority: bottleneck.severity,
                    estimatedImprovement: "减少 30-50% 的索引加载时间"
                ))
                
            case .queryProcessing:
                recommendations.append(OptimizationRecommendation(
                    title: "优化查询处理",
                    description: "实现查询预处理和缓存，优化复杂查询的解析",
                    priority: bottleneck.severity,
                    estimatedImprovement: "减少 20-40% 的查询处理时间"
                ))
                
            case .indexSearching:
                recommendations.append(OptimizationRecommendation(
                    title: "优化索引搜索",
                    description: "使用更高效的搜索算法或并行搜索",
                    priority: bottleneck.severity,
                    estimatedImprovement: "减少 25-45% 的搜索时间"
                ))
                
            case .resultRanking:
                recommendations.append(OptimizationRecommendation(
                    title: "优化结果排序",
                    description: "简化相关性计算或使用预计算的权重",
                    priority: bottleneck.severity,
                    estimatedImprovement: "减少 15-30% 的排序时间"
                ))
                
            case .resultFormatting:
                recommendations.append(OptimizationRecommendation(
                    title: "优化结果格式化",
                    description: "延迟加载详细信息或使用更高效的格式化方法",
                    priority: bottleneck.severity,
                    estimatedImprovement: "减少 10-25% 的格式化时间"
                ))
            }
        }
        
        // 通用优化建议
        if analysis.count > 3 {
            recommendations.append(OptimizationRecommendation(
                title: "整体性能优化",
                description: "考虑重构搜索架构，使用更高效的数据结构和算法",
                priority: .high,
                estimatedImprovement: "整体性能提升 40-60%"
            ))
        }
        
        return recommendations.sorted { $0.priority.rawValue > $1.priority.rawValue }
    }
    
    // MARK: - 性能指标更新
    
    private func updatePerformanceMetrics() {
        let recentSessions = searchSessions.suffix(50)
        
        performanceMetrics.totalSearches = searchSessions.count
        performanceMetrics.averageSearchTime = recentSessions.map { $0.totalDuration }.reduce(0, +) / Double(recentSessions.count)
        performanceMetrics.successRate = Double(recentSessions.filter { $0.success }.count) / Double(recentSessions.count)
        performanceMetrics.averageResultCount = recentSessions.map { Double($0.resultCount) }.reduce(0, +) / Double(recentSessions.count)
        performanceMetrics.lastUpdated = Date()
        
        // 计算性能趋势
        if searchSessions.count >= 20 {
            let recent10 = searchSessions.suffix(10)
            let previous10 = searchSessions.dropLast(10).suffix(10)
            
            let recentAvg = recent10.map { $0.totalDuration }.reduce(0, +) / Double(recent10.count)
            let previousAvg = previous10.map { $0.totalDuration }.reduce(0, +) / Double(previous10.count)
            
            performanceMetrics.performanceTrend = recentAvg < previousAvg ? .improving : .declining
        }
    }
    
    // MARK: - 数据持久化
    
    private func savePerformanceHistory() {
        // 只保存最近1000次搜索记录
        let recentSessions = searchSessions.suffix(1000)
        
        if let data = try? JSONEncoder().encode(Array(recentSessions)) {
            UserDefaults.standard.set(data, forKey: "SearchPerformanceHistory")
        }
        
        if let metricsData = try? JSONEncoder().encode(performanceMetrics) {
            UserDefaults.standard.set(metricsData, forKey: "SearchPerformanceMetrics")
        }
    }
    
    private func loadPerformanceHistory() {
        if let data = UserDefaults.standard.data(forKey: "SearchPerformanceHistory"),
           let sessions = try? JSONDecoder().decode([SearchSession].self, from: data) {
            searchSessions = sessions
        }
        
        if let data = UserDefaults.standard.data(forKey: "SearchPerformanceMetrics"),
           let metrics = try? JSONDecoder().decode(SearchPerformanceMonitorMetrics.self, from: data) {
            performanceMetrics = metrics
        }
    }
    
    // MARK: - 实时监控
    
    /// 获取当前搜索会话的实时指标
    func getCurrentSessionMetrics() -> SessionMetrics? {
        return currentSession?.metrics
    }
    
    /// 清除性能历史记录
    func clearPerformanceHistory() {
        searchSessions.removeAll()
        performanceMetrics = SearchPerformanceMonitorMetrics()
        savePerformanceHistory()
        
        logger.info("性能历史记录已清除")
    }
}

// MARK: - 搜索会话模型
struct SearchSession: Codable {
    let id: UUID
    let query: String
    let filters: AdvancedSearchFilters?
    let startTime: Date
    var endTime: Date?
    var totalDuration: TimeInterval = 0
    var resultCount: Int = 0
    var averageRelevance: Float = 0
    var success: Bool = true
    var metrics: SessionMetrics
}

// MARK: - 会话指标
struct SessionMetrics: Codable {
    var phases: [SearchPhase: TimeInterval] = [:]
    var resultProcessingTime: TimeInterval = 0
    var memoryUsage: Int64 = 0
    var cacheHitRate: Double = 0
}

// MARK: - 搜索阶段
enum SearchPhase: String, CaseIterable, Codable {
    case indexLoading = "index_loading"
    case queryProcessing = "query_processing"
    case indexSearching = "index_searching"
    case resultRanking = "result_ranking"
    case resultFormatting = "result_formatting"
    
    var displayName: String {
        switch self {
        case .indexLoading: return "索引加载"
        case .queryProcessing: return "查询处理"
        case .indexSearching: return "索引搜索"
        case .resultRanking: return "结果排序"
        case .resultFormatting: return "结果格式化"
        }
    }
    
    var expectedDuration: TimeInterval {
        switch self {
        case .indexLoading: return 50.0 // 50ms
        case .queryProcessing: return 10.0 // 10ms
        case .indexSearching: return 100.0 // 100ms
        case .resultRanking: return 30.0 // 30ms
        case .resultFormatting: return 20.0 // 20ms
        }
    }
}

// MARK: - 性能指标
struct SearchPerformanceMonitorMetrics: Codable {
    var totalSearches: Int = 0
    var averageSearchTime: TimeInterval = 0
    var successRate: Double = 1.0
    var averageResultCount: Double = 0
    var performanceTrend: PerformanceTrend = .stable
    var lastUpdated: Date = Date()
}

// MARK: - 性能趋势
enum PerformanceTrend: String, Codable {
    case improving = "improving"
    case stable = "stable"
    case declining = "declining"
    
    var displayName: String {
        switch self {
        case .improving: return "改善中"
        case .stable: return "稳定"
        case .declining: return "下降中"
        }
    }
    
    var color: String {
        switch self {
        case .improving: return "green"
        case .stable: return "blue"
        case .declining: return "red"
        }
    }
}

// MARK: - 性能分析结果
struct SearchPerformanceAnalysis {
    let totalSessions: Int
    let successRate: Double
    let averageDuration: TimeInterval
    let averageResultCount: Double
    let averageRelevance: Double
    let bottlenecks: [PerformanceBottleneck]
    let recommendations: [OptimizationRecommendation]
}

// MARK: - 性能瓶颈
struct PerformanceBottleneck {
    let phase: SearchPhase
    let averageDuration: TimeInterval
    let expectedDuration: TimeInterval
    let severity: BottleneckSeverity
    let description: String
}

// MARK: - 瓶颈严重程度
enum BottleneckSeverity: Int {
    case low = 1
    case medium = 2
    case high = 3
    
    var displayName: String {
        switch self {
        case .low: return "轻微"
        case .medium: return "中等"
        case .high: return "严重"
        }
    }
    
    var color: String {
        switch self {
        case .low: return "yellow"
        case .medium: return "orange"
        case .high: return "red"
        }
    }
}

// MARK: - 优化建议
struct OptimizationRecommendation {
    let title: String
    let description: String
    let priority: BottleneckSeverity
    let estimatedImprovement: String
}
