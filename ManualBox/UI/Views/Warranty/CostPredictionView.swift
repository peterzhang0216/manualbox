//
//  CostPredictionView.swift
//  ManualBox
//
//  Created by Assistant on 2025/6/25.
//

import SwiftUI
import Charts

// MARK: - 费用预测视图
struct CostPredictionView: View {
    @StateObject private var warrantyService = EnhancedWarrantyService.shared
    @State private var selectedTimeframe: PredictionTimeframe = .oneYear
    @State private var showingGenerator = false
    
    private var predictions: [CostPrediction] {
        return warrantyService.costPredictions.filter { $0.timeframe == selectedTimeframe }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 时间范围选择器
            timeframeSelector
            
            if predictions.isEmpty {
                emptyStateView
            } else {
                predictionContent
            }
        }
        .sheet(isPresented: $showingGenerator) {
            CostPredictionGeneratorView(isPresented: $showingGenerator)
        }
    }
    
    // MARK: - 时间范围选择器
    
    private var timeframeSelector: some View {
        Picker("预测时间范围", selection: $selectedTimeframe) {
            ForEach(PredictionTimeframe.allCases, id: \.self) { timeframe in
                Text(timeframe.rawValue).tag(timeframe)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding()
    }
    
    // MARK: - 空状态视图
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("暂无费用预测")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text("生成费用预测以了解未来的维护和保修成本")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: {
                showingGenerator = true
            }) {
                Label("生成预测", systemImage: "plus")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - 预测内容
    
    private var predictionContent: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // 总体预测概览
                overviewCard
                
                // 各产品预测详情
                ForEach(predictions) { prediction in
                    CostPredictionCard(prediction: prediction)
                }
            }
            .padding()
        }
    }
    
    // MARK: - 概览卡片
    
    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("费用预测概览")
                .font(.headline)
                .fontWeight(.semibold)
            
            // 总费用预测
            let totalCost = predictions.flatMap { $0.predictions }.reduce(0) { $0 + $1.predictedCost }
            let averageConfidence = predictions.reduce(0) { $0 + $1.confidence } / Double(max(1, predictions.count))
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("预计总费用")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("¥\(NSDecimalNumber(decimal: totalCost).doubleValue, specifier: "%.0f")")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("预测置信度")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("\(averageConfidence * 100, specifier: "%.0f")%")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(confidenceColor(averageConfidence))
                }
            }
            
            // 费用分类图表
            if !predictions.isEmpty {
                costCategoryChart
            }
        }
        .padding()
        #if os(macOS)
        .background(Color(NSColor.controlBackgroundColor))
        #else
        .background(Color(.systemBackground))
        #endif
        .cornerRadius(16)
        .shadow(radius: 2)
    }
    
    // MARK: - 费用分类图表
    
    private var costCategoryChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("费用分类")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            let categoryData = getCategoryData()
            
            Chart(categoryData, id: \.category) { item in
                BarMark(
                    x: .value("费用", item.amount),
                    y: .value("类别", item.category.rawValue)
                )
                .foregroundStyle(Color(item.category.icon))
            }
            .frame(height: 200)
            .chartXAxis {
                AxisMarks(values: .automatic) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let amount = value.as(Double.self) {
                            Text("¥\(amount, specifier: "%.0f")")
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - 辅助方法
    
    private func getCategoryData() -> [CategoryData] {
        var categoryTotals: [CostCategory: Decimal] = [:]
        
        for prediction in predictions {
            for item in prediction.predictions {
                categoryTotals[item.category, default: 0] += item.predictedCost
            }
        }
        
        return categoryTotals.map { category, amount in
            CategoryData(category: category, amount: Double(truncating: amount as NSNumber))
        }.sorted { $0.amount > $1.amount }
    }
    
    private func confidenceColor(_ confidence: Double) -> Color {
        if confidence >= 0.8 {
            return .green
        } else if confidence >= 0.6 {
            return .orange
        } else {
            return .red
        }
    }
}

// MARK: - 费用预测卡片
struct CostPredictionCard: View {
    let prediction: CostPrediction
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 头部信息
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(getProductName(prediction.productId))
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("预测时间: \(prediction.timeframe.rawValue)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("置信度")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(prediction.confidence * 100, specifier: "%.0f")%")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(confidenceColor(prediction.confidence))
                }
            }
            
            // 预测项目
            VStack(spacing: 8) {
                ForEach(prediction.predictions, id: \.category) { item in
                    PredictionItemRow(item: item)
                }
            }
            
            // 总费用
            Divider()
            
            HStack {
                Text("预计总费用")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                let totalCost = prediction.predictions.reduce(0) { $0 + $1.predictedCost }
                Text("¥\(NSDecimalNumber(decimal: totalCost).doubleValue, specifier: "%.0f")")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
            
            // 建议
            if !prediction.recommendations.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("建议")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    ForEach(prediction.recommendations, id: \.self) { recommendation in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "lightbulb")
                                .foregroundColor(.yellow)
                                .font(.caption)
                            
                            Text(recommendation)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        #if os(macOS)
        .background(Color(NSColor.controlBackgroundColor))
        #else
        .background(Color(.systemBackground))
        #endif
        .cornerRadius(16)
        .shadow(radius: 2)
    }
    
    private func getProductName(_ productId: UUID) -> String {
        // 这里应该从数据库获取产品名称
        return "产品 \(productId.uuidString.prefix(8))"
    }
    
    private func confidenceColor(_ confidence: Double) -> Color {
        if confidence >= 0.8 {
            return .green
        } else if confidence >= 0.6 {
            return .orange
        } else {
            return .red
        }
    }
}

// MARK: - 预测项目行
struct PredictionItemRow: View {
    let item: CostPredictionItem
    
    var body: some View {
        HStack {
            Image(systemName: item.category.icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.category.rawValue)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(item.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("¥\(NSDecimalNumber(decimal: item.predictedCost).doubleValue, specifier: "%.0f")")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("\(item.probability * 100, specifier: "%.0f")%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 数据结构
private struct CategoryData {
    let category: CostCategory
    let amount: Double
}

// MARK: - 费用预测生成器
struct CostPredictionGeneratorView: View {
    @Binding var isPresented: Bool
    @StateObject private var warrantyService = EnhancedWarrantyService.shared
    @State private var selectedProducts: Set<UUID> = []
    @State private var selectedTimeframe: PredictionTimeframe = .oneYear
    @State private var isGenerating = false

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("生成费用预测")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.top)

                Text("选择产品和时间范围来生成费用预测")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                // 时间范围选择
                VStack(alignment: .leading, spacing: 8) {
                    Text("预测时间范围")
                        .font(.headline)

                    Picker("时间范围", selection: $selectedTimeframe) {
                        ForEach(PredictionTimeframe.allCases, id: \.self) { timeframe in
                            Text(timeframe.rawValue).tag(timeframe)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.horizontal)

                Spacer()

                // 操作按钮
                HStack(spacing: 16) {
                    Button("取消") {
                        isPresented = false
                    }
                    .buttonStyle(.bordered)

                    Button("生成预测") {
                        generatePredictions()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isGenerating)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            #if os(iOS)
            .navigationBarHidden(true)
            #endif
        }
    }

    private func generatePredictions() {
        isGenerating = true

        // 模拟生成预测
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isGenerating = false
            isPresented = false
        }
    }
}

// MARK: - 预览
struct CostPredictionView_Previews: PreviewProvider {
    static var previews: some View {
        CostPredictionView()
    }
}
