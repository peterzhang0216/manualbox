import SwiftUI
import Charts

// MARK: - 通知统计视图
struct NotificationStatisticsView: View {
    @StateObject private var notificationService = EnhancedNotificationService.shared
    @State private var selectedTimeRange: TimeRange = .week
    @State private var statistics: NotificationStatistics?
    
    enum TimeRange: String, CaseIterable {
        case week = "本周"
        case month = "本月"
        case quarter = "本季度"
        case year = "本年"
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 时间范围选择器
                TimeRangeSelector(selectedRange: $selectedTimeRange)
                
                if let stats = statistics {
                    // 总览卡片
                    OverviewCards(statistics: stats)
                    
                    // 分类统计图表
                    CategoryChart(statistics: stats)
                    
                    // 成功率指标
                    SuccessRateCard(statistics: stats)
                    
                    // 详细统计
                    DetailedStatistics(statistics: stats)
                } else {
                    // 加载状态
                    VStack(spacing: 16) {
                        ProgressView()
                            .controlSize(.large)
                        
                        Text("正在加载统计数据...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 200)
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .navigationTitle("通知统计")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            await loadStatistics()
        }
        .onChange(of: selectedTimeRange) {
            Task {
                await loadStatistics()
            }
        }
    }
    
    private func loadStatistics() async {
        await MainActor.run {
            statistics = notificationService.getNotificationStatistics()
        }
    }
}

// MARK: - 时间范围选择器
struct TimeRangeSelector: View {
    @Binding var selectedRange: NotificationStatisticsView.TimeRange
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("时间范围")
                .font(.headline)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(NotificationStatisticsView.TimeRange.allCases, id: \.self) { range in
                        Button(action: {
                            selectedRange = range
                        }) {
                            Text(range.rawValue)
                                .font(.caption)
                                .fontWeight(.medium)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                #if os(iOS)
                                .background(selectedRange == range ? Color(.systemGray6) : Color(.systemGray6))
                                #else
                                .background(selectedRange == range ? Color(nsColor: .windowBackgroundColor) : Color(nsColor: .windowBackgroundColor))
                                #endif
                                .foregroundColor(selectedRange == range ? .white : .primary)
                                .cornerRadius(20)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
}

// MARK: - 总览卡片
struct OverviewCards: View {
    let statistics: NotificationStatistics
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("总览")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                StatCard(
                    title: "总通知数",
                    value: "\(statistics.totalNotifications)",
                    icon: "bell.fill",
                    color: .blue
                )
                
                StatCard(
                    title: "已发送",
                    value: "\(statistics.sentNotifications)",
                    icon: "checkmark.circle.fill",
                    color: .green
                )
                
                StatCard(
                    title: "待发送",
                    value: "\(statistics.scheduledNotifications)",
                    icon: "clock.fill",
                    color: .orange
                )
                
                StatCard(
                    title: "已取消",
                    value: "\(statistics.cancelledNotifications)",
                    icon: "xmark.circle.fill",
                    color: .red
                )
            }
        }
    }
}

// MARK: - 统计卡片
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(color)
                
                Spacer()
            }
            
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(16)
        #if os(iOS)
        .background(Color(uiColor: .systemGray6))
        #else
        .background(Color(nsColor: .windowBackgroundColor))
        #endif
        .cornerRadius(12)
    }
}

// MARK: - 分类图表
struct CategoryChart: View {
    let statistics: NotificationStatistics
    
    var chartData: [(String, Int)] {
        return statistics.categoryStatistics.sorted { $0.value > $1.value }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("分类分布")
                .font(.headline)
            
            if chartData.isEmpty {
                Text("暂无数据")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 100)
                    #if os(iOS)
                    .background(Color(uiColor: .systemGray6))
                    #else
                    .background(Color(nsColor: .windowBackgroundColor))
                    #endif
                    .cornerRadius(12)
            } else {
                VStack(spacing: 8) {
                    ForEach(chartData, id: \.0) { category, count in
                        NotificationCategoryRow(
                            name: categoryDisplayName(category),
                            count: count,
                            percentage: Double(count) / Double(statistics.totalNotifications),
                            color: colorForCategory(category)
                        )
                    }
                }
                .padding(16)
                #if os(iOS)
                .background(Color(uiColor: .systemGray6))
                #else
                .background(Color(nsColor: .windowBackgroundColor))
                #endif
                .cornerRadius(12)
            }
        }
    }
    
    private func categoryDisplayName(_ categoryId: String) -> String {
        switch categoryId {
        case "warranty": return "保修"
        case "maintenance": return "维护"
        case "ocr": return "OCR"
        case "sync": return "同步"
        default: return categoryId
        }
    }
    
    private func colorForCategory(_ categoryId: String) -> Color {
        switch categoryId {
        case "warranty": return .orange
        case "maintenance": return .blue
        case "ocr": return .purple
        case "sync": return .green
        default: return .gray
        }
    }
}

// MARK: - 分类行
struct NotificationCategoryRow: View {
    let name: String
    let count: Int
    let percentage: Double
    let color: Color
    
    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
            
            Text(name)
                .font(.system(size: 14, weight: .medium))
            
            Spacer()
            
            Text("\(count)")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
            
            Text("(\(Int(percentage * 100))%)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - 成功率卡片
struct SuccessRateCard: View {
    let statistics: NotificationStatistics
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("发送成功率")
                .font(.headline)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(Int(statistics.successRate * 100))%")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.green)
                    
                    Text("成功率")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(Int(statistics.cancellationRate * 100))%")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.red)
                    
                    Text("取消率")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(16)
            #if os(iOS)
            .background(Color(uiColor: .systemGray6))
            #else
            .background(Color(nsColor: .windowBackgroundColor))
            #endif
            .cornerRadius(12)
        }
    }
}

// MARK: - 详细统计
struct DetailedStatistics: View {
    let statistics: NotificationStatistics
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("详细信息")
                .font(.headline)
            
            VStack(spacing: 8) {
                NotificationDetailRow(title: "最活跃分类", value: statistics.topCategory ?? "无")
                NotificationDetailRow(title: "平均每日通知", value: "~\(statistics.totalNotifications / 7)")
                NotificationDetailRow(title: "通知响应率", value: "\(Int(statistics.successRate * 100))%")
            }
            .padding(16)
            #if os(iOS)
            .background(Color(uiColor: .systemGray6))
            #else
            .background(Color(nsColor: .windowBackgroundColor))
            #endif
            .cornerRadius(12)
        }
    }
}

// MARK: - 详细行
struct NotificationDetailRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
        }
    }
}

#Preview {
    NavigationStack {
        NotificationStatisticsView()
    }
}
