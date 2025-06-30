//
//  ProductValuationView.swift
//  ManualBox
//
//  Created by Assistant on 2025/6/25.
//

import SwiftUI
import Charts

// MARK: - 产品价值评估视图
struct ProductValuationView: View {
    @StateObject private var valuationService = ProductValuationService.shared
    @Environment(\.managedObjectContext) private var viewContext
    @State private var selectedProduct: Product?
    @State private var showingValuationDetail = false
    @State private var showingBatchValuation = false
    @State private var selectedValuation: ProductValuation?
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Product.name, ascending: true)],
        animation: .default
    ) private var products: FetchedResults<Product>
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 概览统计
                if !valuationService.valuations.isEmpty {
                    valuationOverview
                }
                
                // 产品估值列表
                valuationList
            }
            .navigationTitle("产品估值")
            #if os(macOS)
            .platformNavigationBarTitleDisplayMode(0)
            .platformToolbar(trailing: {
                Button("批量估值") {
                    showingBatchValuation = true
                }
            })
            #else
            .platformNavigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button("批量估值") {
                        showingBatchValuation = true
                    }
                }
            }
            #endif
            .sheet(isPresented: $showingBatchValuation) {
                // BatchValuationView()
            }
            .sheet(item: $selectedValuation) { valuation in
                // ValuationDetailView(valuation: valuation)
            }
        }
    }
    
    // MARK: - 估值概览
    
    private var valuationOverview: some View {
        VStack(spacing: 16) {
            Text("估值概览")
                .font(.headline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            let totalOriginalValue = valuationService.valuations.reduce(0) { $0 + $1.originalPrice }
            let totalCurrentValue = valuationService.valuations.reduce(0) { $0 + $1.currentValue }
            let totalDepreciation = totalOriginalValue - totalCurrentValue
            let averageRetention = totalOriginalValue > 0 ? Double(truncating: (totalCurrentValue / totalOriginalValue) as NSNumber) * 100 : 0
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                OverviewCard(
                    title: "原始价值",
                    value: "¥\(NSDecimalNumber(decimal: totalOriginalValue).doubleValue)",
                    subtitle: "\(valuationService.valuations.count)个产品",
                    color: .blue,
                    icon: "dollarsign.circle"
                )
                
                OverviewCard(
                    title: "当前价值",
                    value: "¥\(NSDecimalNumber(decimal: totalCurrentValue).doubleValue)",
                    subtitle: "最新估值",
                    color: .green,
                    icon: "chart.line.uptrend.xyaxis"
                )
                
                OverviewCard(
                    title: "贬值金额",
                    value: "¥\(NSDecimalNumber(decimal: totalDepreciation).doubleValue)",
                    subtitle: "总贬值",
                    color: .red,
                    icon: "arrow.down.circle"
                )
                
                OverviewCard(
                    title: "保值率",
                    value: String(format: "%.1f%%", averageRetention),
                    subtitle: "平均保值率",
                    color: averageRetention > 70 ? .green : averageRetention > 50 ? .orange : .red,
                    icon: "percent"
                )
            }
        }
        .padding()
        .background(ModernColors.Background.primary)
        .cornerRadius(16)
        .shadow(radius: 2)
        .padding()
    }
    
    // MARK: - 估值列表
    
    private var valuationList: some View {
        Group {
            if valuationService.valuations.isEmpty {
                emptyStateView
            } else {
                List {
                    ForEach(valuationService.valuations) { valuation in
                        ValuationCard(valuation: valuation) {
                            selectedValuation = valuation
                        }
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
    }
    
    // MARK: - 空状态视图
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("暂无产品估值")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text("选择产品进行价值评估，了解产品的当前市场价值")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            if !products.isEmpty {
                Menu {
                    ForEach(products, id: \.self) { product in
                        Button(action: {
                            selectedProduct = product
                            evaluateProduct(product)
                        }) {
                            Text(product.productName)
                        }
                    }
                } label: {
                    Label("开始评估", systemImage: "plus")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - 评估方法
    
    private func evaluateProduct(_ product: Product) {
        Task {
            do {
                let valuation = try await valuationService.evaluateProduct(product)
                await MainActor.run {
                    selectedValuation = valuation
                }
            } catch {
                print("评估失败: \(error)")
            }
        }
    }
}

// MARK: - 概览卡片
struct OverviewCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title3)
                
                Spacer()
            }
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - 估值卡片
struct ValuationCard: View {
    let valuation: ProductValuation
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // 头部信息
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(valuation.productName)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text("评估日期: \(DateFormatter.shortDate.string(from: valuation.valuationDate))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        ValueTrendBadge(trend: valuation.valueTrend)
                        
                        Text("置信度: \(valuation.confidence * 100, specifier: "%.0f")%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // 价值信息
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("原始价值")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("¥\(NSDecimalNumber(decimal: valuation.originalPrice).doubleValue, specifier: "%.0f")")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .center, spacing: 4) {
                        Text("当前价值")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("¥\(NSDecimalNumber(decimal: valuation.currentValue).doubleValue)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(valuation.currentValue >= valuation.originalPrice ? .green : .red)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("保值率")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("\(valuation.valueRetentionRate, specifier: "%.1f")%")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(valuation.valueRetentionRate > 70 ? .green : valuation.valueRetentionRate > 50 ? .orange : .red)
                    }
                }
                
                // 状况和方法
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: valuation.condition.icon)
                            .foregroundColor(Color(valuation.condition.color))
                        
                        Text(valuation.condition.rawValue)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Image(systemName: valuation.valuationMethod.icon)
                            .foregroundColor(.blue)
                        
                        Text(valuation.valuationMethod.rawValue)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // 建议预览
                if !valuation.recommendations.isEmpty {
                    HStack {
                        Image(systemName: "lightbulb")
                            .foregroundColor(.yellow)
                            .font(.caption)
                        
                        Text("\(valuation.recommendations.count)条建议")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("点击查看详情")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                }
            }
            .padding()
            .background(ModernColors.Background.primary)
            .cornerRadius(12)
            .shadow(radius: 2)
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal)
        .padding(.vertical, 4)
    }
}

// MARK: - 价值趋势徽章
struct ValueTrendBadge: View {
    let trend: ValueTrend
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: trend.icon)
                .font(.caption)
            
            Text(trend.rawValue)
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundColor(Color(trend.color))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(trend.color).opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - 预览
struct ProductValuationView_Previews: PreviewProvider {
    static var previews: some View {
        ProductValuationView()
    }
}
