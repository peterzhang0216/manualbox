//
//  AnalysisComponents.swift
//  ManualBox
//
//  Created by Assistant on 2025/6/24.
//

import SwiftUI
import Charts
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

// MARK: - 分析卡片组件
struct AnalysisCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let subtitle: String?
    
    init(title: String, value: String, icon: String, color: Color, subtitle: String? = nil) {
        self.title = title
        self.value = value
        self.icon = icon
        self.color = color
        self.subtitle = subtitle
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Spacer()
            }
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            Color(
                #if os(iOS)
                UIColor.systemGray6
                #elseif os(macOS)
                NSColor.controlBackgroundColor
                #endif
            )
        )
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

// MARK: - 产品使用行组件
struct ProductUsageRow: View {
    let product: ProductUsageMetric
    let color: Color
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // 使用频率指示器
                Circle()
                    .fill(color)
                    .frame(width: 12, height: 12)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.productName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    if let categoryName = product.categoryName {
                        Text(categoryName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(String(format: "%.1f", product.usageFrequency * 100))%")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(color)
                    
                    Text(product.usageLevel.rawValue)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Color(
                    #if os(iOS)
                    UIColor.systemGray6
                    #elseif os(macOS)
                    NSColor.controlBackgroundColor
                    #endif
                )
            )
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 趋势指示器组件
struct TrendIndicator: View {
    let trend: TrendDirection
    let value: String?
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: trend.icon)
                .font(.caption)
                .foregroundColor(Color(trend.color))
            
            if let value = value {
                Text(value)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - 维修风险指示器
struct MaintenanceRiskIndicator: View {
    let riskLevel: MaintenanceRiskLevel
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color(riskLevel.color))
                .frame(width: 8, height: 8)
            
            Text(riskLevel.rawValue)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(Color(riskLevel.color))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(riskLevel.color).opacity(0.1))
        .cornerRadius(6)
    }
}

// MARK: - 成本效率排名组件
struct CostEfficiencyRankingRow: View {
    let efficiency: ProductCostEfficiency
    
    var body: some View {
        HStack(spacing: 12) {
            // 排名徽章
            ZStack {
                Circle()
                    .fill(rankingColor)
                    .frame(width: 32, height: 32)
                
                Text("\(efficiency.ranking)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(efficiency.productName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("每次使用成本: ¥\(formatDecimal(efficiency.costPerUsage))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(String(format: "%.1f", efficiency.efficiencyScore))")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(rankingColor)
                
                Text("效率分数")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Color(
                #if os(iOS)
                UIColor.systemGray6
                #elseif os(macOS)
                NSColor.controlBackgroundColor
                #endif
            )
        )
        .cornerRadius(8)
    }
    
    private var rankingColor: Color {
        switch efficiency.ranking {
        case 1:
            return .green
        case 2, 3:
            return .blue
        case 4, 5:
            return .orange
        default:
            return .gray
        }
    }
}

// MARK: - 分类使用指标组件
struct CategoryUsageMetricRow: View {
    let metric: CategoryUsageMetric
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(metric.categoryName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text("\(metric.productCount) 个产品")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // 使用频率进度条
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("平均使用频率")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(String(format: "%.1f", metric.averageUsageFrequency * 100))%")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                
                ProgressView(value: metric.averageUsageFrequency, total: 1.0)
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
            }
            
            // 增长率指示器
            HStack {
                Text("增长率")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                TrendIndicator(
                    trend: metric.growthRate > 0.1 ? .increasing : (metric.growthRate < -0.1 ? .decreasing : .stable),
                    value: "\(String(format: "%.1f", metric.growthRate * 100))%"
                )
            }
        }
        .padding()
        .background(
            Color(
                #if os(iOS)
                UIColor.systemGray6
                #elseif os(macOS)
                NSColor.controlBackgroundColor
                #endif
            )
        )
        .cornerRadius(12)
        .shadow(radius: 1)
    }
}

// MARK: - 年龄分布图表组件
struct AgeDistributionChart: View {
    let ageAnalysis: ProductAgeAnalysis
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("产品年龄分布")
                .font(.headline)
                .fontWeight(.semibold)
            
            if #available(iOS 16.0, *) {
                Chart {
                    ForEach(AgeGroup.allCases, id: \.self) { ageGroup in
                        let count = ageAnalysis.ageDistribution[ageGroup] ?? 0
                        BarMark(
                            x: .value("年龄组", ageGroup.rawValue),
                            y: .value("产品数量", count)
                        )
                        .foregroundStyle(.blue)
                    }
                }
                .frame(height: 200)
            } else {
                // iOS 15 兼容版本
                VStack(spacing: 8) {
                    ForEach(AgeGroup.allCases, id: \.self) { ageGroup in
                        let count = ageAnalysis.ageDistribution[ageGroup] ?? 0
                        let maxCount = ageAnalysis.ageDistribution.values.max() ?? 1
                        
                        HStack {
                            Text(ageGroup.rawValue)
                                .font(.caption)
                                .frame(width: 100, alignment: .leading)
                            
                            Rectangle()
                                .fill(.blue)
                                .frame(width: CGFloat(count) / CGFloat(maxCount) * 150, height: 20)
                            
                            Text("\(count)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                        }
                    }
                }
            }
        }
        .padding()
        .background(
            Color(
                #if os(iOS)
                UIColor.systemGray6
                #elseif os(macOS)
                NSColor.controlBackgroundColor
                #endif
            )
        )
        .cornerRadius(12)
    }
}

// MARK: - 数据质量指示器
struct DataQualityIndicator: View {
    let metrics: UsagePerformanceMetrics
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("数据质量")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                qualityMetricRow(
                    title: "数据收集准确性",
                    value: metrics.dataCollectionAccuracy,
                    color: .blue
                )
                
                qualityMetricRow(
                    title: "跟踪覆盖率",
                    value: metrics.trackingCoverage,
                    color: .green
                )
                
                qualityMetricRow(
                    title: "分析置信度",
                    value: metrics.analysisConfidenceLevel,
                    color: .orange
                )
            }
            
            HStack {
                Text("整体质量等级")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text(metrics.overallDataQuality.rawValue)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(Color(metrics.overallDataQuality.color))
            }
        }
        .padding()
        .background(
            Color(
                #if os(iOS)
                UIColor.systemGray6
                #elseif os(macOS)
                NSColor.controlBackgroundColor
                #endif
            )
        )
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private func qualityMetricRow(title: String, value: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(String(format: "%.1f", value * 100))%")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            ProgressView(value: value, total: 1.0)
                .progressViewStyle(LinearProgressViewStyle(tint: color))
        }
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
