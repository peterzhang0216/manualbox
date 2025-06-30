//
//  WarrantyManagementView.swift
//  ManualBox
//
//  Created by Assistant on 2025/6/25.
//

import SwiftUI

// MARK: - 保修管理主视图
struct WarrantyManagementView: View {
    @StateObject private var warrantyService = EnhancedWarrantyService.shared
    @State private var selectedTab = 0
    @State private var showingAddWarranty = false
    @State private var showingAddInsurance = false
    @State private var showingCostPrediction = false
    @State private var showingReminderSettings = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 统计概览
                if let statistics = warrantyService.statistics {
                    WarrantyStatisticsCard(statistics: statistics)
                        .padding()
                }
                
                // 标签页选择器
                Picker("保修管理", selection: $selectedTab) {
                    Text("扩展保修").tag(0)
                    Text("保险信息").tag(1)
                    Text("费用预测").tag(2)
                    Text("提醒设置").tag(3)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                
                // 内容区域
                TabView {
                    ExtendedWarrantyListView()
                        .tag(0)
                    
                    Text("保险信息管理")
                        .tag(1)
                    
                    CostPredictionView()
                        .tag(2)
                    
                    Text("提醒设置")
                        .tag(3)
                }
                #if os(macOS)
                .tabViewStyle(DefaultTabViewStyle())
                #else
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                #endif
            }
            .navigationTitle("保修管理")
            #if os(macOS)
            .platformToolbar(trailing: {
                Menu {
                    Button(action: {
                        showingAddWarranty = true
                    }) {
                        Label("添加扩展保修", systemImage: "plus.circle")
                    }
                    
                    Button(action: {
                        showingAddInsurance = true
                    }) {
                        Label("添加保险信息", systemImage: "shield.checkered")
                    }
                    
                    Divider()
                    
                    Button(action: {
                        showingCostPrediction = true
                    }) {
                        Label("生成费用预测", systemImage: "chart.line.uptrend.xyaxis")
                    }
                    
                    Button(action: {
                        showingReminderSettings = true
                    }) {
                        Label("提醒设置", systemImage: "bell.badge")
                    }
                } label: {
                    Image(systemName: "plus")
                }
            })
            #else
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: {
                            showingAddWarranty = true
                        }) {
                            Label("添加扩展保修", systemImage: "plus.circle")
                        }
                        
                        Button(action: {
                            showingAddInsurance = true
                        }) {
                            Label("添加保险信息", systemImage: "shield.checkered")
                        }
                        
                        Divider()
                        
                        Button(action: {
                            showingCostPrediction = true
                        }) {
                            Label("生成费用预测", systemImage: "chart.line.uptrend.xyaxis")
                        }
                        
                        Button(action: {
                            showingReminderSettings = true
                        }) {
                            Label("提醒设置", systemImage: "bell.badge")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            #endif
            .sheet(isPresented: $showingAddWarranty) {
                Text("添加扩展保修")
            }
            .sheet(isPresented: $showingAddInsurance) {
                Text("添加保险信息")
            }
            .sheet(isPresented: $showingCostPrediction) {
                CostPredictionView()
            }
            .sheet(isPresented: $showingReminderSettings) {
                Text("提醒设置")
            }
        }
    }
}

// MARK: - 保修统计卡片
struct WarrantyStatisticsCard: View {
    let statistics: EnhancedWarrantyStatistics
    
    var body: some View {
        VStack(spacing: 16) {
            // 标题
            HStack {
                Text("保修概览")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                // 风险指示器
                RiskIndicator(level: statistics.riskAssessment.overallRisk)
            }
            
            // 统计数据网格
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                StatisticItem(
                    title: "活跃保修",
                    value: "\(statistics.activeWarranties)",
                    subtitle: "共\(statistics.totalProducts)个产品",
                    color: .green,
                    icon: "checkmark.shield"
                )
                
                StatisticItem(
                    title: "即将到期",
                    value: "\(statistics.expiringSoon)",
                    subtitle: "需要关注",
                    color: .orange,
                    icon: "clock.badge.exclamationmark"
                )
                
                StatisticItem(
                    title: "保修价值",
                    value: "¥\(String(format: "%.0f", NSDecimalNumber(decimal: statistics.totalWarrantyValue).doubleValue))",
                    subtitle: "总保修价值",
                    color: .blue,
                    icon: "dollarsign.circle"
                )
                
                StatisticItem(
                    title: "节省费用",
                    value: "¥\(String(format: "%.0f", NSDecimalNumber(decimal: statistics.costSavings).doubleValue))",
                    subtitle: "已节省",
                    color: .purple,
                    icon: "arrow.down.circle"
                )
            }
            
            // 即将到期的续费
            if !statistics.upcomingRenewals.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("即将到期")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    ForEach(statistics.upcomingRenewals.prefix(3)) { renewal in
                        UpcomingRenewalRow(renewal: renewal)
                    }
                    
                    if statistics.upcomingRenewals.count > 3 {
                        Text("还有\(statistics.upcomingRenewals.count - 3)项即将到期...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        #if os(macOS)
        .background(Color(NSColor.windowBackgroundColor))
        #else
        .background(Color(.systemBackground))
        #endif
        .cornerRadius(16)
        .shadow(radius: 2)
    }
}

// MARK: - 统计项目
struct StatisticItem: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
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

// MARK: - 风险指示器
struct RiskIndicator: View {
    let level: RiskLevel
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color(level.color))
                .frame(width: 8, height: 8)
            
            Text(level.rawValue)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(Color(level.color))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(level.color).opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - 即将到期续费行
struct UpcomingRenewalRow: View {
    let renewal: UpcomingRenewal
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(renewal.productName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(renewal.type.rawValue)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("¥\(String(format: "%.0f", NSDecimalNumber(decimal: renewal.estimatedCost).doubleValue))")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(DateFormatter.shortDate.string(from: renewal.renewalDate))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Circle()
                .fill(Color(renewal.priority.color))
                .frame(width: 8, height: 8)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 预览
struct WarrantyManagementView_Previews: PreviewProvider {
    static var previews: some View {
        WarrantyManagementView()
    }
}

// MARK: - DateFormatter 扩展
// DateFormatter扩展已移至DashboardViewHelpers.swift
