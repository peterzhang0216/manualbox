import SwiftUI
import Charts

// MARK: - 搜索性能仪表板
struct SearchPerformanceDashboard: View {
    @StateObject private var performanceMonitor = SearchPerformanceMonitor.shared
    @State private var selectedTimeRange: TimeRange = .week
    @State private var performanceAnalysis: SearchPerformanceAnalysis?
    @State private var showingDetailedAnalysis = false
    
    enum TimeRange: String, CaseIterable {
        case day = "今天"
        case week = "本周"
        case month = "本月"
        case all = "全部"
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 时间范围选择器
                    timeRangeSelector
                    
                    // 性能概览卡片
                    performanceOverviewCards
                    
                    // 性能趋势图表
                    performanceTrendChart
                    
                    // 瓶颈分析
                    if let analysis = performanceAnalysis {
                        bottleneckAnalysisSection(analysis)
                    }
                    
                    // 优化建议
                    if let analysis = performanceAnalysis {
                        optimizationRecommendationsSection(analysis)
                    }
                    
                    // 高级搜索统计
                    advancedSearchStatisticsSection
                    
                    // 实时监控
                    realTimeMonitoringSection
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .navigationTitle("搜索性能")
            #if os(iOS)
            .platformNavigationBarTitleDisplayMode(.inline)
            #else
            .platformNavigationBarTitleDisplayMode(0)
            #endif
            .platformToolbar(trailing: {
                Button("详细分析") {
                    showingDetailedAnalysis = true
                }
            })
            .sheet(isPresented: $showingDetailedAnalysis) {
                DetailedPerformanceAnalysisView(analysis: performanceAnalysis)
            }
        }
        .task {
            await loadPerformanceAnalysis()
        }
        .onChange(of: selectedTimeRange) { _ in
            Task {
                await loadPerformanceAnalysis()
            }
        }
    }
    
    // MARK: - 时间范围选择器
    private var timeRangeSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("时间范围")
                .font(.headline)
            
            Picker("时间范围", selection: $selectedTimeRange) {
                ForEach(TimeRange.allCases, id: \.self) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(.segmented)
        }
    }
    
    // MARK: - 性能概览卡片
    private var performanceOverviewCards: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("性能概览")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                PerformanceCard(
                    title: "总搜索次数",
                    value: "\(performanceMonitor.performanceMetrics.totalSearches)",
                    icon: "magnifyingglass",
                    color: .blue,
                    trend: nil
                )
                
                PerformanceCard(
                    title: "平均响应时间",
                    value: String(format: "%.0fms", performanceMonitor.performanceMetrics.averageSearchTime * 1000),
                    icon: "clock",
                    color: .green,
                    trend: performanceMonitor.performanceMetrics.performanceTrend
                )
                
                PerformanceCard(
                    title: "成功率",
                    value: String(format: "%.1f%%", performanceMonitor.performanceMetrics.successRate * 100),
                    icon: "checkmark.circle",
                    color: .orange,
                    trend: nil
                )
                
                PerformanceCard(
                    title: "平均结果数",
                    value: String(format: "%.0f", performanceMonitor.performanceMetrics.averageResultCount),
                    icon: "list.number",
                    color: .purple,
                    trend: nil
                )
            }
        }
    }
    
    // MARK: - 性能趋势图表
    private var performanceTrendChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("性能趋势")
                .font(.headline)
            
            VStack {
                if #available(iOS 16.0, *) {
                    // 使用 Charts 框架绘制趋势图
                    Chart {
                        // 这里应该有实际的数据点
                        // 由于示例，我们使用模拟数据
                    }
                    .frame(height: 200)
                } else {
                    // 降级处理：使用简单的视图
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 200)
                        .overlay(
                            Text("性能趋势图\n(需要 iOS 16+)")
                                .multilineTextAlignment(.center)
                                .foregroundColor(.secondary)
                        )
                }
            }
            .padding()
            .background(ModernColors.System.gray6)
            .cornerRadius(12)
        }
    }
    
    // MARK: - 瓶颈分析
    private func bottleneckAnalysisSection(_ analysis: SearchPerformanceAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("性能瓶颈")
                .font(.headline)
            
            if analysis.bottlenecks.isEmpty {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    
                    Text("未发现明显的性能瓶颈")
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
            } else {
                VStack(spacing: 8) {
                    ForEach(analysis.bottlenecks.prefix(3), id: \.phase) { bottleneck in
                        BottleneckRow(bottleneck: bottleneck)
                    }
                    
                    if analysis.bottlenecks.count > 3 {
                        Button("查看全部 \(analysis.bottlenecks.count) 个瓶颈") {
                            showingDetailedAnalysis = true
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                }
            }
        }
    }
    
    // MARK: - 优化建议
    private func optimizationRecommendationsSection(_ analysis: SearchPerformanceAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("优化建议")
                .font(.headline)
            
            VStack(spacing: 8) {
                ForEach(analysis.recommendations.prefix(2), id: \.title) { recommendation in
                    RecommendationRow(recommendation: recommendation)
                }
                
                if analysis.recommendations.count > 2 {
                    Button("查看全部 \(analysis.recommendations.count) 个建议") {
                        showingDetailedAnalysis = true
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
        }
    }
    
    // MARK: - 实时监控
    private var realTimeMonitoringSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("实时监控")
                .font(.headline)
            
            VStack(spacing: 12) {
                HStack {
                    Circle()
                        .fill(performanceMonitor.isMonitoring ? Color.green : Color.gray)
                        .frame(width: 12, height: 12)
                    
                    Text(performanceMonitor.isMonitoring ? "正在监控搜索性能" : "监控已停止")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                
                if let currentMetrics = performanceMonitor.getCurrentSessionMetrics() {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("当前搜索会话")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        ForEach(SearchPhase.allCases, id: \.self) { phase in
                            if let duration = currentMetrics.phases[phase] {
                                HStack {
                                    Text(phase.displayName)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                    
                                    Text(String(format: "%.1fms", duration * 1000))
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(duration > phase.expectedDuration ? .red : .green)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(ModernColors.System.gray6)
                    .cornerRadius(8)
                }
            }
        }
    }
    
    // MARK: - 高级搜索统计
    private var advancedSearchStatisticsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("高级搜索统计")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                AdvancedSearchStatCard(
                    title: "搜索历史",
                    value: "\(AdvancedSearchService.shared.searchHistory.count)",
                    icon: "clock.fill",
                    color: Color.blue
                )
                
                AdvancedSearchStatCard(
                    title: "保存的搜索",
                    value: "\(AdvancedSearchService.shared.savedSearches.count)",
                    icon: "bookmark.fill",
                    color: Color.green
                )
                
                AdvancedSearchStatCard(
                    title: "最近搜索",
                    value: "\(AdvancedSearchService.shared.recentSearches.count)",
                    icon: "magnifyingglass.circle.fill",
                    color: Color.orange
                )
                
                AdvancedSearchStatCard(
                    title: "热门搜索",
                    value: "\(AdvancedSearchService.shared.popularSearches.count)",
                    icon: "flame.fill",
                    color: Color.red
                )
            }
            
            // 搜索类型分布
            if !AdvancedSearchService.shared.searchHistory.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("搜索类型分布")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    let scopeStats = calculateSearchScopeStatistics()
                    ForEach(Array(scopeStats.keys.sorted()), id: \.self) { scope in
                        if let count = scopeStats[scope] {
                            HStack {
                                Text(scope.displayName)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Text("\(count)")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                
                                Text("(\(String(format: "%.1f", Double(count) / Double(AdvancedSearchService.shared.searchHistory.count) * 100))%)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
        }
    }
    
    // MARK: - 计算搜索范围统计
    private func calculateSearchScopeStatistics() -> [AdvancedSearchScope: Int] {
        var stats: [AdvancedSearchScope: Int] = [:]
        
        for historyItem in AdvancedSearchService.shared.searchHistory {
            for scope in historyItem.filters.searchScopes {
                stats[scope, default: 0] += 1
            }
        }
        
        return stats
    }
    
    // MARK: - 数据加载
    private func loadPerformanceAnalysis() async {
        await MainActor.run {
            performanceAnalysis = performanceMonitor.analyzePerformance()
        }
    }
}

// MARK: - 性能卡片
struct PerformanceCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let trend: PerformanceTrend?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Spacer()
                
                if let trend = trend {
                    HStack(spacing: 2) {
                        Image(systemName: trendIcon(trend))
                            .font(.caption)
                            .foregroundColor(trendColor(trend))
                        
                        Text(trend.displayName)
                            .font(.caption2)
                            .foregroundColor(trendColor(trend))
                    }
                }
            }
            
            Text(value)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(ModernColors.Background.primary)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(ModernColors.System.gray4, lineWidth: 1)
        )
    }
    
    private func trendIcon(_ trend: PerformanceTrend) -> String {
        switch trend {
        case .improving: return "arrow.up.right"
        case .stable: return "minus"
        case .declining: return "arrow.down.right"
        }
    }
    
    private func trendColor(_ trend: PerformanceTrend) -> Color {
        switch trend {
        case .improving: return .green
        case .stable: return .blue
        case .declining: return .red
        }
    }
}

// MARK: - 瓶颈行
struct BottleneckRow: View {
    let bottleneck: PerformanceBottleneck
    
    var body: some View {
        HStack {
            Circle()
                .fill(severityColor(bottleneck.severity))
                .frame(width: 8, height: 8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(bottleneck.phase.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(bottleneck.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            Text(bottleneck.severity.displayName)
                .font(.caption)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(severityColor(bottleneck.severity).opacity(0.2))
                .foregroundColor(severityColor(bottleneck.severity))
                .cornerRadius(4)
        }
        .padding()
        .background(ModernColors.System.gray6)
        .cornerRadius(8)
    }
    
    private func severityColor(_ severity: BottleneckSeverity) -> Color {
        switch severity {
        case .low: return .yellow
        case .medium: return .orange
        case .high: return .red
        }
    }
}

// MARK: - 详细分析视图
// 注意：RecommendationRow 已移动到 SharedUIComponents.swift 以避免重复定义
struct DetailedPerformanceAnalysisView: View {
    let analysis: SearchPerformanceAnalysis?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let analysis = analysis {
                        // 详细统计
                        detailedStatistics(analysis)
                        
                        // 所有瓶颈
                        allBottlenecks(analysis)
                        
                        // 所有建议
                        allRecommendations(analysis)
                    } else {
                        Text("暂无分析数据")
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
            }
            .navigationTitle("详细性能分析")
            #if os(iOS)
            .platformNavigationBarTitleDisplayMode(.inline)
            #else
            .platformNavigationBarTitleDisplayMode(0)
            #endif
            .platformToolbar(trailing: {
                Button("关闭") {
                    dismiss()
                }
            })
        }
    }
    
    private func detailedStatistics(_ analysis: SearchPerformanceAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("详细统计")
                .font(.headline)
            
            VStack(spacing: 8) {
                StatisticRow(title: "总搜索次数", value: "\(analysis.totalSessions)")
                StatisticRow(title: "成功率", value: String(format: "%.2f%%", analysis.successRate * 100))
                StatisticRow(title: "平均耗时", value: String(format: "%.0fms", analysis.averageDuration * 1000))
                StatisticRow(title: "平均结果数", value: String(format: "%.1f", analysis.averageResultCount))
                StatisticRow(title: "平均相关性", value: String(format: "%.2f", analysis.averageRelevance))
            }
            .padding()
            .background(ModernColors.System.gray6)
            .cornerRadius(12)
        }
    }
    
    private func allBottlenecks(_ analysis: SearchPerformanceAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("所有性能瓶颈")
                .font(.headline)
            
            if analysis.bottlenecks.isEmpty {
                Text("未发现性能瓶颈")
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                VStack(spacing: 8) {
                    ForEach(analysis.bottlenecks, id: \.phase) { bottleneck in
                        BottleneckRow(bottleneck: bottleneck)
                    }
                }
            }
        }
    }
    
    private func allRecommendations(_ analysis: SearchPerformanceAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("所有优化建议")
                .font(.headline)
            
            VStack(spacing: 8) {
                ForEach(analysis.recommendations, id: \OptimizationRecommendation.title) { recommendation in
                    RecommendationRow(recommendation: recommendation)
                }
            }
        }
    }
}

// MARK: - 统计行组件已移至InfoRow.swift

#Preview {
    SearchPerformanceDashboard()
}
