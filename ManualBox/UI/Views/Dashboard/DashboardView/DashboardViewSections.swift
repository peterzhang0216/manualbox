//
//  DashboardViewSections.swift
//  ManualBox
//
//  Created by Assistant on 2024/12/19.
//

import SwiftUI

// MARK: - DashboardView 扩展 - 各个部分
extension DashboardView {
    
    // MARK: - 概览卡片
    func overviewCard(_ stats: DashboardStatistics) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.doc.horizontal")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                Text("数据概览")
                    .font(.headline)
                
                Spacer()
                
                if let lastUpdate = statisticsService.lastUpdateTime {
                    Text("更新于 \(formatRelativeTime(lastUpdate))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            HStack(spacing: 20) {
                OverviewMetric(
                    title: "产品总数",
                    value: "\(stats.productStats.totalProducts)",
                    icon: "cube.box",
                    color: .blue
                )
                
                OverviewMetric(
                    title: "有效保修",
                    value: "\(stats.warrantyStats.activeWarranties)",
                    icon: "shield.checkered",
                    color: .green
                )
                
                OverviewMetric(
                    title: "总投资",
                    value: "¥\(formatCurrency(stats.costStats.totalCost))",
                    icon: "dollarsign.circle",
                    color: .orange
                )
                
                OverviewMetric(
                    title: "OCR完成率",
                    value: "\(String(format: "%.1f", stats.usageStats.ocrProcessingRate * 100))%",
                    icon: "doc.text.viewfinder",
                    color: .purple
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    // MARK: - 时间范围选择器
    var timeRangeSelector: some View {
        Picker("时间范围", selection: $selectedTimeRange) {
            ForEach(StatisticsTimeRange.allCases, id: \.self) { range in
                Text(range.rawValue).tag(range)
            }
        }
        .pickerStyle(.segmented)
    }
    
    // MARK: - 统计卡片网格
    func statisticsGrid(_ stats: DashboardStatistics) -> some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            if selectedCardTypes.contains(.products) {
                ProductStatsCard(stats: stats.productStats)
            }
            
            if selectedCardTypes.contains(.warranty) {
                WarrantyStatsCard(stats: stats.warrantyStats)
            }
            
            if selectedCardTypes.contains(.costs) {
                CostStatsCard(stats: stats.costStats)
            }
            
            if selectedCardTypes.contains(.usage) {
                UsageStatsCard(stats: stats.usageStats)
            }

            // 产品使用分析快速访问卡片
            NavigationLink(destination: ProductUsageAnalysisView()) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "chart.bar.doc.horizontal")
                            .font(.title2)
                            .foregroundColor(.blue)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Text("产品使用分析")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text("查看详细的产品使用情况、维修趋势和成本分析")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(radius: 2)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    // MARK: - 趋势部分
    func trendsSection(_ trendStats: TrendStatistics) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.pink)
                
                Text("趋势分析")
                    .font(.headline)
                
                Spacer()
            }
            
            VStack(spacing: 16) {
                TrendChart(
                    title: "产品添加趋势",
                    data: trendStats.monthlyProductAdditions,
                    color: .blue
                )
                
                TrendChart(
                    title: "维护记录趋势",
                    data: trendStats.monthlyMaintenanceRecords,
                    color: .orange
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    // MARK: - 分类部分
    func categoriesSection(_ categoryStats: [CategoryStatistic]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "folder.badge.gearshape")
                    .foregroundColor(.indigo)
                
                Text("分类分布")
                    .font(.headline)
                
                Spacer()
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(categoryStats.prefix(6)) { category in
                    CategoryStatCard(category: category)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    // MARK: - 加载视图
    var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("正在加载统计数据...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - 空状态视图
    var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("暂无统计数据")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("添加一些产品后再查看统计信息")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("刷新数据") {
                Task {
                    await statisticsService.refreshStatistics()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - 设置视图
    var dashboardSettingsView: some View {
        NavigationView {
            Form {
                Section("显示卡片") {
                    ForEach(StatisticCardType.allCases, id: \.self) { cardType in
                        Toggle(cardType.rawValue, isOn: Binding(
                            get: { selectedCardTypes.contains(cardType) },
                            set: { isOn in
                                if isOn {
                                    selectedCardTypes.insert(cardType)
                                } else {
                                    selectedCardTypes.remove(cardType)
                                }
                            }
                        ))
                    }
                }
                
                Section("数据管理") {
                    Button("刷新所有数据") {
                        Task {
                            await statisticsService.refreshStatistics()
                        }
                    }
                    
                    Button("导出统计报告") {
                        // 实现导出功能
                    }
                }
            }
            .navigationTitle("仪表板设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                SwiftUI.ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        showingSettings = false
                    }
                }
            }
        }
    }
}