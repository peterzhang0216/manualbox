//
//  PerformanceMonitoringDashboard.swift
//  ManualBox
//
//  Created by Assistant on 2024/12/19.
//  性能监控仪表板 - 实时显示应用性能指标
//

import SwiftUI
import Charts

// MARK: - 性能监控仪表板视图
struct PerformanceMonitoringDashboard: View {
    @StateObject private var performanceMonitor = ManualBoxPerformanceMonitoringService.shared
    @StateObject private var memoryManager = MemoryManager.shared
    @State private var selectedTimeRange: TimeRange = .last24Hours
    @State private var selectedMetricType: MetricType = .all
    @State private var showingDetailView = false
    @State private var selectedMetric: PerformanceMetric?
    @State private var isRefreshing = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 20) {
                    // 时间范围选择器
                    timeRangeSelector
                    
                    // 关键指标卡片
                    keyMetricsSection
                    
                    // 性能图表
                    performanceChartsSection
                    
                    // 内存使用情况
                    memoryUsageSection
                    
                    // 操作性能列表
                    operationPerformanceSection
                    
                    // 告警和建议
                    alertsAndRecommendationsSection
                }
                .padding()
            }
            .navigationTitle("性能监控")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: refreshData) {
                        Image(systemName: "arrow.clockwise")
                            .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                            .animation(.linear(duration: 1).repeatCount(isRefreshing ? .max : 1, autoreverses: false), value: isRefreshing)
                    }
                }
            }
            .sheet(item: $selectedMetric) { metric in
                MetricDetailView(metric: metric)
            }
        }
        .onAppear {
            refreshData()
        }
    }
    
    // MARK: - 时间范围选择器
    private var timeRangeSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("时间范围")
                .font(.headline)
                .foregroundColor(.primary)
            
            Picker("时间范围", selection: $selectedTimeRange) {
                ForEach(TimeRange.allCases, id: \.self) { range in
                    Text(range.displayName).tag(range)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .onChange(of: selectedTimeRange) { _ in
                refreshData()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - 关键指标卡片
    private var keyMetricsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("关键指标")
                .font(.headline)
                .foregroundColor(.primary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                MetricCard(
                    title: "平均响应时间",
                    value: String(format: "%.0f ms", performanceMonitor.averageResponseTime * 1000),
                    trend: performanceMonitor.responseTimeTrend,
                    color: .blue
                )
                
                MetricCard(
                    title: "内存使用",
                    value: formatBytes(memoryManager.currentMemoryUsage.used),
                    trend: memoryManager.memoryUsageTrend,
                    color: .orange
                )
                
                MetricCard(
                    title: "操作吞吐量",
                    value: String(format: "%.1f/s", performanceMonitor.operationThroughput),
                    trend: performanceMonitor.throughputTrend,
                    color: .green
                )
                
                MetricCard(
                    title: "错误率",
                    value: String(format: "%.2f%%", performanceMonitor.errorRate * 100),
                    trend: performanceMonitor.errorRateTrend,
                    color: .red
                )
            }
        }
    }
    
    // MARK: - 性能图表
    private var performanceChartsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("性能趋势")
                .font(.headline)
                .foregroundColor(.primary)
            
            TabView {
                // 响应时间图表
                responseTimeChart
                    .tabItem {
                        Image(systemName: "clock")
                        Text("响应时间")
                    }
                
                // 内存使用图表
                memoryUsageChart
                    .tabItem {
                        Image(systemName: "memorychip")
                        Text("内存使用")
                    }
                
                // 吞吐量图表
                throughputChart
                    .tabItem {
                        Image(systemName: "speedometer")
                        Text("吞吐量")
                    }
            }
            .frame(height: 300)
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - 响应时间图表
    private var responseTimeChart: some View {
        Chart(performanceMonitor.responseTimeHistory) { dataPoint in
            LineMark(
                x: .value("时间", dataPoint.timestamp),
                y: .value("响应时间", dataPoint.value * 1000)
            )
            .foregroundStyle(.blue)
            .interpolationMethod(.catmullRom)
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel {
                    if let intValue = value.as(Double.self) {
                        Text("\(Int(intValue)) ms")
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour)) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel(format: .dateTime.hour())
            }
        }
        .padding()
    }
    
    // MARK: - 内存使用图表
    private var memoryUsageChart: some View {
        Chart(memoryManager.memoryUsageHistory) { dataPoint in
            AreaMark(
                x: .value("时间", dataPoint.timestamp),
                y: .value("内存使用", dataPoint.value)
            )
            .foregroundStyle(.orange.opacity(0.3))
            
            LineMark(
                x: .value("时间", dataPoint.timestamp),
                y: .value("内存使用", dataPoint.value)
            )
            .foregroundStyle(.orange)
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel {
                    if let intValue = value.as(Double.self) {
                        Text(formatBytes(Int64(intValue)))
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour)) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel(format: .dateTime.hour())
            }
        }
        .padding()
    }
    
    // MARK: - 吞吐量图表
    private var throughputChart: some View {
        Chart(performanceMonitor.throughputHistory) { dataPoint in
            BarMark(
                x: .value("时间", dataPoint.timestamp),
                y: .value("吞吐量", dataPoint.value)
            )
            .foregroundStyle(.green)
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel {
                    if let intValue = value.as(Double.self) {
                        Text("\(Int(intValue))/s")
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour)) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel(format: .dateTime.hour())
            }
        }
        .padding()
    }
    
    // MARK: - 内存使用情况
    private var memoryUsageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("内存使用详情")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 8) {
                MemoryUsageRow(
                    title: "已使用",
                    value: formatBytes(memoryManager.currentMemoryUsage.used),
                    percentage: Double(memoryManager.currentMemoryUsage.used) / Double(memoryManager.currentMemoryUsage.total),
                    color: .blue
                )
                
                MemoryUsageRow(
                    title: "缓存",
                    value: formatBytes(memoryManager.currentMemoryUsage.cached),
                    percentage: Double(memoryManager.currentMemoryUsage.cached) / Double(memoryManager.currentMemoryUsage.total),
                    color: .orange
                )
                
                MemoryUsageRow(
                    title: "可用",
                    value: formatBytes(memoryManager.currentMemoryUsage.available),
                    percentage: Double(memoryManager.currentMemoryUsage.available) / Double(memoryManager.currentMemoryUsage.total),
                    color: .green
                )
            }
            
            if memoryManager.isMemoryPressureHigh {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text("内存压力较高，建议清理缓存")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - 操作性能列表
    private var operationPerformanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("操作性能")
                .font(.headline)
                .foregroundColor(.primary)
            
            LazyVStack(spacing: 8) {
                ForEach(performanceMonitor.recentOperations.prefix(10), id: \.id) { operation in
                    OperationPerformanceRow(operation: operation)
                        .onTapGesture {
                            selectedMetric = PerformanceMetric(
                                name: operation.name,
                                value: operation.duration,
                                timestamp: operation.endTime,
                                tags: operation.tags,
                                context: operation.context
                            )
                        }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - 告警和建议
    private var alertsAndRecommendationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("告警和建议")
                .font(.headline)
                .foregroundColor(.primary)
            
            LazyVStack(spacing: 8) {
                ForEach(performanceMonitor.activeAlerts, id: \.id) { alert in
                    AlertRow(alert: alert)
                }
                
                ForEach(performanceMonitor.recommendations, id: \.id) { recommendation in
                    RecommendationRow(recommendation: recommendation)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Helper Methods
    private func refreshData() {
        isRefreshing = true
        
        Task {
            await performanceMonitor.refreshMetrics()
            await memoryManager.updateMemoryUsage()
            
            await MainActor.run {
                isRefreshing = false
            }
        }
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - 指标卡片
struct MetricCard: View {
    let title: String
    let value: String
    let trend: TrendDirection
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Image(systemName: trend.iconName)
                    .foregroundColor(trend.color)
                    .font(.caption)
            }
            
            Text(value)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - 内存使用行
struct MemoryUsageRow: View {
    let title: String
    let value: String
    let percentage: Double
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(value)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            ProgressView(value: percentage)
                .progressViewStyle(LinearProgressViewStyle(tint: color))
        }
    }
}

// MARK: - 操作性能行
struct OperationPerformanceRow: View {
    let operation: OperationPerformance
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(operation.name)
                    .font(.caption)
                    .fontWeight(.medium)
                
                Text(formatTimestamp(operation.endTime))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.0f ms", operation.duration * 1000))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(operation.success ? .primary : .red)
                
                if !operation.success {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                        .font(.caption2)
                }
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Color(.systemGray6))
        .cornerRadius(6)
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - 告警行
struct AlertRow: View {
    let alert: PerformanceAlert
    
    var body: some View {
        HStack {
            Image(systemName: alert.severity.iconName)
                .foregroundColor(alert.severity.color)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(alert.title)
                    .font(.caption)
                    .fontWeight(.medium)
                
                Text(alert.message)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(formatTimestamp(alert.timestamp))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(alert.severity.backgroundColor)
        .cornerRadius(6)
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - 指标详情视图
// 注意：RecommendationRow 已移动到 SharedUIComponents.swift 以避免重复定义
struct MetricDetailView: View {
    let metric: PerformanceMetric
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 指标基本信息
                    VStack(alignment: .leading, spacing: 8) {
                        Text("指标信息")
                            .font(.headline)
                        
                        InfoRow(label: "名称", value: metric.name)
                        InfoRow(label: "值", value: String(format: "%.3f", metric.value))
                        InfoRow(label: "时间", value: formatTimestamp(metric.timestamp))
                    }
                    
                    // 标签信息
                    if !metric.tags.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("标签")
                                .font(.headline)
                            
                            ForEach(Array(metric.tags.keys.sorted()), id: \.self) { key in
                                InfoRow(label: key, value: metric.tags[key] ?? "")
                            }
                        }
                    }
                    
                    // 上下文信息
                    VStack(alignment: .leading, spacing: 8) {
                        Text("上下文")
                            .font(.headline)
                        
                        InfoRow(label: "操作类型", value: metric.context.operationType)
                        InfoRow(label: "资源ID", value: metric.context.resourceId ?? "无")
                        InfoRow(label: "用户ID", value: metric.context.userId ?? "无")
                    }
                }
                .padding()
            }
            .navigationTitle("指标详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - 信息行
// InfoRow moved to shared components to avoid conflicts

// MARK: - 支持类型
enum TimeRange: String, CaseIterable {
    case last1Hour = "1h"
    case last6Hours = "6h"
    case last24Hours = "24h"
    case last7Days = "7d"
    case last30Days = "30d"
    
    var displayName: String {
        switch self {
        case .last1Hour: return "1小时"
        case .last6Hours: return "6小时"
        case .last24Hours: return "24小时"
        case .last7Days: return "7天"
        case .last30Days: return "30天"
        }
    }
}

// MetricType is defined in PlatformPerformance.swift

enum TrendDirection {
    case up, down, stable
    
    var iconName: String {
        switch self {
        case .up: return "arrow.up"
        case .down: return "arrow.down"
        case .stable: return "minus"
        }
    }
    
    var color: Color {
        switch self {
        case .up: return .red
        case .down: return .green
        case .stable: return .gray
        }
    }
}

// MARK: - 预览
struct PerformanceMonitoringDashboard_Previews: PreviewProvider {
    static var previews: some View {
        PerformanceMonitoringDashboard()
    }
}