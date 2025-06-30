//
//  ProductUsageAnalysisView.swift
//  ManualBox
//
//  Created by Assistant on 2025/6/24.
//

import SwiftUI
import Charts

// MARK: - 产品使用分析视图
struct ProductUsageAnalysisView: View {
    @StateObject private var analysisService = ProductUsageAnalysisService.shared
    @State private var selectedTab: AnalysisTab = .frequency
    @State private var showingDetailView = false
    @State private var selectedProduct: ProductUsageMetric?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 标签选择器
                tabSelector
                
                // 内容区域
                ScrollView {
                    LazyVStack(spacing: 16) {
                        if analysisService.isLoading {
                            loadingView
                        } else if let analysis = analysisService.currentAnalysis {
                            analysisContent(analysis)
                        } else {
                            emptyStateView
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("产品使用分析")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button("刷新") {
                        Task {
                            await analysisService.refreshAnalysis()
                        }
                    }
                }
            }
            .refreshable {
                await analysisService.refreshAnalysis()
            }
            .sheet(isPresented: $showingDetailView) {
                if let product = selectedProduct {
                    ProductUsageDetailView(product: product)
                }
            }
        }
        .onAppear {
            if analysisService.currentAnalysis == nil {
                Task {
                    await analysisService.refreshAnalysis()
                }
            }
        }
    }
    
    // MARK: - 标签选择器
    
    private var tabSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(AnalysisTab.allCases, id: \.self) { tab in
                    Button(action: {
                        selectedTab = tab
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: tab.icon)
                                .font(.title2)
                            
                            Text(tab.title)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(selectedTab == tab ? .white : .primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(selectedTab == tab ? Color.blue : Color(.systemGray6))
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
    
    // MARK: - 分析内容
    
    @ViewBuilder
    private func analysisContent(_ analysis: ProductUsageAnalysis) -> some View {
        switch selectedTab {
        case .frequency:
            usageFrequencySection(analysis.usageFrequency)
        case .maintenance:
            maintenanceTrendsSection(analysis.maintenanceTrends)
        case .cost:
            costAnalysisSection(analysis.costAnalysis)
        case .category:
            categoryUsageSection(analysis.categoryUsage)
        case .age:
            ageAnalysisSection(analysis.ageAnalysis)
        case .performance:
            performanceMetricsSection(analysis.performanceMetrics)
        }
    }
    
    // MARK: - 使用频率分析
    
    private func usageFrequencySection(_ frequency: UsageFrequencyAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // 概览卡片
            usageOverviewCards(frequency)
            
            // 使用分布图表
            usageDistributionChart(frequency)
            
            // 高频使用产品列表
            if !frequency.highFrequencyProducts.isEmpty {
                productUsageList(
                    title: "高频使用产品",
                    products: frequency.highFrequencyProducts,
                    color: .green
                )
            }
            
            // 未使用产品列表
            if !frequency.unusedProducts.isEmpty {
                productUsageList(
                    title: "未使用产品",
                    products: frequency.unusedProducts,
                    color: .red
                )
            }
        }
    }
    
    private func usageOverviewCards(_ frequency: UsageFrequencyAnalysis) -> some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            AnalysisCard(
                title: "总产品数",
                value: "\(frequency.totalTrackedProducts)",
                icon: "cube.box",
                color: .blue
            )
            
            AnalysisCard(
                title: "活跃产品率",
                value: "\(String(format: "%.1f", frequency.activeProductsPercentage * 100))%",
                icon: "chart.line.uptrend.xyaxis",
                color: .green
            )
            
            AnalysisCard(
                title: "高频使用",
                value: "\(frequency.highFrequencyProducts.count)",
                icon: "star.fill",
                color: .orange
            )
            
            AnalysisCard(
                title: "未使用",
                value: "\(frequency.unusedProducts.count)",
                icon: "exclamationmark.triangle",
                color: .red
            )
        }
    }
    
    private func usageDistributionChart(_ frequency: UsageFrequencyAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("使用频率分布")
                .font(.headline)
                .fontWeight(.semibold)
            
            if #available(iOS 16.0, *) {
                Chart {
                    ForEach(UsageFrequencyLevel.allCases, id: \.self) { level in
                        let count = frequency.usageDistribution[level] ?? 0
                        BarMark(
                            x: .value("频率等级", level.rawValue),
                            y: .value("产品数量", count)
                        )
                        .foregroundStyle(Color(level.color))
                    }
                }
                .frame(height: 200)
            } else {
                // iOS 15 兼容版本
                HStack(alignment: .bottom, spacing: 12) {
                    ForEach(UsageFrequencyLevel.allCases, id: \.self) { level in
                        let count = frequency.usageDistribution[level] ?? 0
                        VStack {
                            Rectangle()
                                .fill(Color(level.color))
                                .frame(width: 40, height: CGFloat(count * 10))
                            
                            Text(level.rawValue)
                                .font(.caption2)
                                .multilineTextAlignment(.center)
                        }
                    }
                }
                .frame(height: 200)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func productUsageList(title: String, products: [ProductUsageMetric], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVStack(spacing: 8) {
                ForEach(products.prefix(5), id: \.productId) { product in
                    ProductUsageRow(product: product, color: color) {
                        selectedProduct = product
                        showingDetailView = true
                    }
                }
                
                if products.count > 5 {
                    Button("查看全部 \(products.count) 个产品") {
                        // 可以导航到完整列表
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    // MARK: - 维修趋势分析

    private func maintenanceTrendsSection(_ trends: MaintenanceTrendAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // 维修概览
            maintenanceOverviewCards(trends)

            // 维修趋势图表
            maintenanceTrendChart(trends)

            // 分类维修排名
            if !trends.topMaintenanceCategories.isEmpty {
                categoryMaintenanceRanking(trends.topMaintenanceCategories)
            }
        }
    }

    private func maintenanceOverviewCards(_ trends: MaintenanceTrendAnalysis) -> some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            AnalysisCard(
                title: "总维修记录",
                value: "\(trends.totalMaintenanceRecords)",
                icon: "wrench.and.screwdriver",
                color: .orange
            )

            AnalysisCard(
                title: "平均维修频率",
                value: "\(String(format: "%.1f", trends.averageMaintenanceFrequency))次/年",
                icon: "clock",
                color: .blue
            )
        }
    }

    private func maintenanceTrendChart(_ trends: MaintenanceTrendAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("维修趋势")
                .font(.headline)
                .fontWeight(.semibold)

            if #available(iOS 16.0, *) {
                Chart {
                    ForEach(trends.monthlyMaintenanceCount.sorted(by: { $0.key < $1.key }), id: \.key) { item in
                        LineMark(
                            x: .value("月份", item.key),
                            y: .value("维修次数", item.value)
                        )
                        .foregroundStyle(.orange)
                    }
                }
                .frame(height: 200)
            } else {
                // iOS 15 兼容版本
                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(trends.monthlyMaintenanceCount.sorted(by: { $0.key < $1.key }).prefix(12), id: \.key) { item in
                        VStack {
                            Rectangle()
                                .fill(.orange)
                                .frame(width: 20, height: CGFloat(item.value * 10))

                            Text(String(item.key.suffix(2)))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .frame(height: 200)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func categoryMaintenanceRanking(_ categories: [CategoryMaintenanceMetric]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("分类维修排名")
                .font(.headline)
                .fontWeight(.semibold)

            LazyVStack(spacing: 8) {
                ForEach(categories.prefix(5), id: \.categoryName) { category in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(category.categoryName)
                                .font(.subheadline)
                                .fontWeight(.medium)

                            Text("平均成本: ¥\(formatDecimal(category.averageCost))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            Text("\(category.maintenanceCount)")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.orange)

                            Text("次维修")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }

    // MARK: - 成本分析

    private func costAnalysisSection(_ cost: ProductCostAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // 成本概览
            costOverviewCards(cost)

            // 成本效率排名
            if !cost.costEfficiencyRanking.isEmpty {
                costEfficiencyRanking(cost.costEfficiencyRanking)
            }

            // 分类成本分布
            if !cost.costPerCategory.isEmpty {
                categoryCostDistribution(cost.costPerCategory)
            }
        }
    }

    private func costOverviewCards(_ cost: ProductCostAnalysis) -> some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            AnalysisCard(
                title: "总拥有成本",
                value: "¥\(formatDecimal(cost.totalOwnershipCost))",
                icon: "dollarsign.circle",
                color: .green
            )

            AnalysisCard(
                title: "月均使用成本",
                value: "¥\(String(format: "%.2f", cost.averageUsageCost))",
                icon: "calendar",
                color: .blue
            )

            AnalysisCard(
                title: "维修成本占比",
                value: "\(String(format: "%.1f", cost.maintenanceCostRatio * 100))%",
                icon: "wrench",
                color: .orange
            )

            AnalysisCard(
                title: "最贵分类",
                value: cost.mostExpensiveCategory ?? "无",
                icon: "crown",
                color: .purple
            )
        }
    }

    private func costEfficiencyRanking(_ ranking: [ProductCostEfficiency]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("成本效率排名")
                .font(.headline)
                .fontWeight(.semibold)

            LazyVStack(spacing: 8) {
                ForEach(ranking.prefix(5), id: \.productId) { efficiency in
                    CostEfficiencyRankingRow(efficiency: efficiency)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }

    private func categoryCostDistribution(_ costPerCategory: [String: Decimal]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("分类成本分布")
                .font(.headline)
                .fontWeight(.semibold)

            LazyVStack(spacing: 8) {
                ForEach(costPerCategory.sorted { $0.value > $1.value }.prefix(5), id: \.key) { item in
                    HStack {
                        Text(item.key)
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Spacer()

                        Text("¥\(formatDecimal(item.value))")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }

    // MARK: - 分类使用分析

    private func categoryUsageSection(_ category: CategoryUsageAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // 分类概览
            categoryOverviewCards(category)

            // 分类使用排名
            if !category.categoryMetrics.isEmpty {
                categoryUsageRanking(category.categoryMetrics)
            }
        }
    }

    private func categoryOverviewCards(_ category: CategoryUsageAnalysis) -> some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            AnalysisCard(
                title: "跟踪分类数",
                value: "\(category.totalCategoriesTracked)",
                icon: "folder",
                color: .blue
            )

            AnalysisCard(
                title: "最活跃分类",
                value: category.mostActiveCategory ?? "无",
                icon: "star",
                color: .green
            )
        }
    }

    private func categoryUsageRanking(_ metrics: [CategoryUsageMetric]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("分类使用排名")
                .font(.headline)
                .fontWeight(.semibold)

            LazyVStack(spacing: 12) {
                ForEach(metrics.prefix(8), id: \.categoryName) { metric in
                    CategoryUsageMetricRow(metric: metric)
                }
            }
        }
    }

    // MARK: - 年龄分析

    private func ageAnalysisSection(_ age: ProductAgeAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // 年龄概览
            ageOverviewCards(age)

            // 年龄分布图表
            AgeDistributionChart(ageAnalysis: age)

            // 最老和最新产品
            oldestNewestProducts(age)
        }
    }

    private func ageOverviewCards(_ age: ProductAgeAnalysis) -> some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            AnalysisCard(
                title: "平均年龄",
                value: "\(age.averageAgeInMonths)个月",
                icon: "clock",
                color: .blue
            )

            AnalysisCard(
                title: "年龄维修相关性",
                value: "\(String(format: "%.1f", age.ageBasedMaintenanceCorrelation * 100))%",
                icon: "chart.line.uptrend.xyaxis",
                color: .orange
            )
        }
    }

    private func oldestNewestProducts(_ age: ProductAgeAnalysis) -> some View {
        HStack(spacing: 16) {
            if let oldest = age.oldestProduct {
                productAgeCard(title: "最老产品", product: oldest, color: .red)
            }

            if let newest = age.newestProduct {
                productAgeCard(title: "最新产品", product: newest, color: .green)
            }
        }
    }

    private func productAgeCard(title: String, product: ProductAgeMetric, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            Text(product.productName)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(2)

            Text("\(Int(product.age / (30 * 24 * 60 * 60)))个月")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }

    // MARK: - 性能指标

    private func performanceMetricsSection(_ performance: UsagePerformanceMetrics) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // 数据质量指示器
            DataQualityIndicator(metrics: performance)

            // 性能概览
            performanceOverviewCards(performance)
        }
    }

    private func performanceOverviewCards(_ performance: UsagePerformanceMetrics) -> some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            AnalysisCard(
                title: "缺失数据点",
                value: "\(performance.missingDataPoints)",
                icon: "exclamationmark.triangle",
                color: .red
            )

            AnalysisCard(
                title: "最后更新",
                value: DateFormatter.shortTime.string(from: performance.lastDataUpdate),
                icon: "clock.arrow.circlepath",
                color: .blue
            )
        }
    }

    // MARK: - 加载和空状态视图

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)

            Text("正在分析产品使用情况...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("暂无使用分析数据")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("添加更多产品和使用记录后，这里将显示详细的使用分析")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }
}

// MARK: - 辅助函数
private func formatDecimal(_ decimal: Decimal) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.minimumFractionDigits = 0
    formatter.maximumFractionDigits = 2
    return formatter.string(from: decimal as NSNumber) ?? "0"
}

// MARK: - 分析标签枚举

enum AnalysisTab: String, CaseIterable {
    case frequency = "使用频率"
    case maintenance = "维修趋势"
    case cost = "成本分析"
    case category = "分类使用"
    case age = "年龄分析"
    case performance = "性能指标"
    
    var title: String {
        return self.rawValue
    }
    
    var icon: String {
        switch self {
        case .frequency:
            return "chart.bar"
        case .maintenance:
            return "wrench.and.screwdriver"
        case .cost:
            return "dollarsign.circle"
        case .category:
            return "folder.badge.gearshape"
        case .age:
            return "clock"
        case .performance:
            return "speedometer"
        }
    }
}

// MARK: - 预览

struct ProductUsageAnalysisView_Previews: PreviewProvider {
    static var previews: some View {
        ProductUsageAnalysisView()
    }
}
