//
//  DashboardViewComponents.swift
//  ManualBox
//
//  Created by Assistant on 2024/12/19.
//

import SwiftUI
import Charts

// MARK: - 概览指标组件
struct OverviewMetric: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 产品统计卡片
struct ProductStatsCard: View {
    let stats: ProductStatistics

    var body: some View {
        StatisticCard(
            title: "产品概览",
            icon: "cube.box",
            color: .blue
        ) {
            VStack(alignment: .leading, spacing: 8) {
                MetricRow(label: "总数", value: "\(stats.totalProducts)")
                MetricRow(label: "最近添加", value: "\(stats.recentlyAdded)")
                MetricRow(label: "有说明书", value: "\(stats.withManuals)")
                MetricRow(label: "覆盖率", value: "\(String(format: "%.1f", stats.manualCoverageRate * 100))%")
            }
        }
    }
}

// MARK: - 保修统计卡片
struct WarrantyStatsCard: View {
    let stats: WarrantyStatistics

    var body: some View {
        StatisticCard(
            title: "保修状态",
            icon: "shield.checkered",
            color: Color(stats.warrantyStatus.color)
        ) {
            VStack(alignment: .leading, spacing: 8) {
                MetricRow(label: "有效保修", value: "\(stats.activeWarranties)")
                MetricRow(label: "即将到期", value: "\(stats.expiringSoon)")
                MetricRow(label: "已过期", value: "\(stats.expired)")
                MetricRow(label: "有效率", value: "\(String(format: "%.1f", stats.activeRate * 100))%")
            }
        }
    }
}

// MARK: - 费用统计卡片
struct CostStatsCard: View {
    let stats: CostStatistics

    var body: some View {
        StatisticCard(
            title: "费用分析",
            icon: "dollarsign.circle",
            color: .orange
        ) {
            VStack(alignment: .leading, spacing: 8) {
                MetricRow(label: "购买费用", value: "¥\(formatDecimal(stats.totalPurchaseCost))")
                MetricRow(label: "维护费用", value: "¥\(formatDecimal(stats.totalMaintenanceCost))")
                MetricRow(label: "总费用", value: "¥\(formatDecimal(stats.totalCost))")

                HStack {
                    Text("趋势")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    Image(systemName: stats.recentSpendingTrend.icon)
                        .foregroundColor(Color(stats.recentSpendingTrend.color))
                        .font(.caption)
                }
            }
        }
    }

    private func formatDecimal(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: value as NSNumber) ?? "0"
    }
}

// MARK: - 使用统计卡片
struct UsageStatsCard: View {
    let stats: UsageStatistics

    var body: some View {
        StatisticCard(
            title: "使用情况",
            icon: "chart.bar",
            color: Color(stats.ocrCompletionLevel.color)
        ) {
            VStack(alignment: .leading, spacing: 8) {
                MetricRow(label: "说明书总数", value: "\(stats.totalManuals)")
                MetricRow(label: "已处理", value: "\(stats.processedManuals)")
                MetricRow(label: "处理率", value: "\(String(format: "%.1f", stats.ocrProcessingRate * 100))%")
                MetricRow(label: "平均年龄", value: "\(stats.averageProductAgeInDays)天")
            }
        }
    }
}

// MARK: - 通用统计卡片
struct StatisticCard<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    let content: Content

    init(title: String, icon: String, color: Color, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.color = color
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)

                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()
            }

            content
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

// MARK: - 指标行
struct MetricRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

// MARK: - 趋势图表
struct TrendChart: View {
    let title: String
    let data: [String: Int]
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)

            if #available(iOS 16.0, *) {
                Chart {
                    ForEach(sortedData, id: \.key) { item in
                        LineMark(
                            x: .value("月份", item.key),
                            y: .value("数量", item.value)
                        )
                        .foregroundStyle(color)
                    }
                }
                .frame(height: 100)
            } else {
                // iOS 15 及以下版本的简化图表
                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(sortedData.prefix(6), id: \.key) { item in
                        VStack {
                            Rectangle()
                                .fill(color)
                                .frame(width: 20, height: CGFloat(item.value * 2))

                            Text(String(item.key.suffix(2)))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .frame(height: 100)
            }
        }
    }

    private var sortedData: [(key: String, value: Int)] {
        data.sorted { $0.key < $1.key }
    }
}

// MARK: - 分类统计卡片
struct CategoryStatCard: View {
    let category: CategoryStatistic

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: category.iconName)
                .font(.title2)
                .foregroundColor(.blue)

            Text(category.name)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)

            Text("\(category.productCount)")
                .font(.headline)
                .fontWeight(.bold)

            Text("¥\(formatDecimal(category.totalValue))")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }

    private func formatDecimal(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: value as NSNumber) ?? "0"
    }
}