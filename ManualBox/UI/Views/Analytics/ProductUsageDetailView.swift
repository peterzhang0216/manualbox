//
//  ProductUsageDetailView.swift
//  ManualBox
//
//  Created by Assistant on 2025/6/24.
//

import SwiftUI
#if os(macOS)
import AppKit
#endif

// MARK: - 产品使用详情视图
struct ProductUsageDetailView: View {
    let product: ProductUsageMetric
    @Environment(\.dismiss) private var dismiss
    @StateObject private var analysisService = ProductUsageAnalysisService.shared
    @State private var detailedMetric: ProductUsageMetric?
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if isLoading {
                        loadingView
                    } else {
                        // 产品基本信息
                        productInfoSection
                        
                        // 使用频率分析
                        usageFrequencySection
                        
                        // 使用历史
                        usageHistorySection
                        
                        // 成本分析
                        costAnalysisSection
                        
                        // 维修记录
                        maintenanceRecordsSection
                        
                        // 使用建议
                        recommendationsSection
                    }
                }
                .padding()
            }
            .navigationTitle("产品使用详情")
            #if os(macOS)
            .platformNavigationBarTitleDisplayMode(0)
            #else
            .platformNavigationBarTitleDisplayMode(.inline)
            #endif
            .platformToolbar(trailing: {
                Button("关闭") {
                    dismiss()
                }
            })
        }
        .task {
            await loadDetailedMetric()
        }
    }
    
    // MARK: - 产品基本信息
    
    private var productInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("产品信息")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("产品名称")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(product.productName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                if let categoryName = product.categoryName {
                    HStack {
                        Text("分类")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(categoryName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }
                
                HStack {
                    Text("使用等级")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(product.usageLevel.rawValue)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(Color(product.usageLevel.color))
                }
                
                if let lastUsedDate = product.lastUsedDate {
                    HStack {
                        Text("最后使用")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(DateFormatter.shortDateTime.string(from: lastUsedDate))
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }
            }
        }
        .padding()
        .background(ModernColors.Background.primary)
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    // MARK: - 使用频率分析
    
    private var usageFrequencySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("使用频率分析")
                .font(.headline)
                .fontWeight(.semibold)
            
            // 使用频率圆环图
            HStack {
                ZStack {
                    Circle()
                        .stroke(ModernColors.System.gray5, lineWidth: 8)
                        .frame(width: 100, height: 100)
                    
                    Circle()
                        .trim(from: 0, to: product.usageFrequency)
                        .stroke(ModernColors.System.blue, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 100, height: 100)
                        .rotationEffect(.degrees(-90))
                    
                    VStack {
                        Text("\(String(format: "%.1f", product.usageFrequency * 100))%")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(ModernColors.System.blue)
                        
                        Text("使用率")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 8) {
                    usageMetricRow(title: "使用分数", value: String(format: "%.2f", product.usageScore))
                    usageMetricRow(title: "使用时长", value: formatTimeInterval(product.totalUsageTime))
                    usageMetricRow(title: "频率等级", value: product.usageLevel.rawValue)
                }
            }
        }
        .padding()
        .background(ModernColors.Background.primary)
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    // MARK: - 使用历史
    
    private var usageHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("使用历史")
                .font(.headline)
                .fontWeight(.semibold)
            
            // 这里可以添加使用历史的时间线
            VStack(alignment: .leading, spacing: 8) {
                Text("暂无详细使用历史记录")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("未来版本将支持详细的使用历史跟踪")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(ModernColors.Background.primary)
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    // MARK: - 成本分析
    
    private var costAnalysisSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("成本分析")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("基于使用频率的成本效率分析")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                // 这里可以添加具体的成本分析数据
                HStack {
                    Text("成本效率")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(product.usageFrequency > 0.6 ? "高效" : (product.usageFrequency > 0.3 ? "中等" : "低效"))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(product.usageFrequency > 0.6 ? .green : (product.usageFrequency > 0.3 ? .orange : .red))
                }
            }
        }
        .padding()
        .background(ModernColors.Background.primary)
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    // MARK: - 维修记录
    
    private var maintenanceRecordsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("维修记录")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("暂无维修记录")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("产品状态良好，无需维修")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(ModernColors.Background.primary)
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    // MARK: - 使用建议
    
    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("使用建议")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(getRecommendations(), id: \.self) { recommendation in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "lightbulb")
                            .font(.caption)
                            .foregroundColor(.yellow)
                        
                        Text(recommendation)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                }
            }
        }
        .padding()
        .background(ModernColors.Background.primary)
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    // MARK: - 辅助视图
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            
            Text("正在加载详细信息...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }
    
    private func usageMetricRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
    
    // MARK: - 数据加载
    
    private func loadDetailedMetric() async {
        do {
            detailedMetric = try await analysisService.getProductUsageMetric(for: product.productId)
            isLoading = false
        } catch {
            print("加载产品详细信息失败: \(error)")
            isLoading = false
        }
    }
    
    // MARK: - 辅助方法
    
    private func getRecommendations() -> [String] {
        var recommendations: [String] = []
        
        switch product.usageLevel {
        case .high:
            recommendations.append("产品使用频率很高，建议定期检查维护状态")
            recommendations.append("考虑购买延保或保险以降低维修风险")
        case .medium:
            recommendations.append("产品使用适中，保持当前使用习惯")
            recommendations.append("可以考虑扩展产品的使用场景")
        case .low:
            recommendations.append("产品使用频率较低，考虑是否真正需要")
            recommendations.append("可以尝试找到更多使用场景或考虑转让")
        case .unused:
            recommendations.append("产品长期未使用，建议重新评估其必要性")
            recommendations.append("考虑出售或捐赠以释放存储空间")
        }
        
        if let categoryName = product.categoryName {
            switch categoryName {
            case "电子产品":
                recommendations.append("注意防潮防尘，定期清洁")
            case "厨房用品":
                recommendations.append("注意食品安全，定期清洗消毒")
            case "运动器材":
                recommendations.append("使用前检查安全性，定期保养")
            default:
                break
            }
        }
        
        return recommendations
    }
    
    private func formatTimeInterval(_ interval: TimeInterval) -> String {
        if interval < 3600 {
            return "\(Int(interval / 60))分钟"
        } else if interval < 86400 {
            return "\(Int(interval / 3600))小时"
        } else {
            return "\(Int(interval / 86400))天"
        }
    }
}

// MARK: - 预览

struct ProductUsageDetailView_Previews: PreviewProvider {
    static var previews: some View {
        ProductUsageDetailView(
            product: ProductUsageMetric(
                productId: UUID(),
                productName: "iPhone 15 Pro",
                categoryName: "电子产品",
                usageFrequency: 0.85,
                lastUsedDate: Date(),
                totalUsageTime: 3600 * 24 * 30,
                usageScore: 0.85
            )
        )
    }
}
