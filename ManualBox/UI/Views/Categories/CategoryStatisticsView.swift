import SwiftUI
import Charts

// MARK: - 分类统计视图
struct CategoryStatisticsView: View {
    @StateObject private var categoryService = CategoryManagementService.shared
    @Environment(\.dismiss) private var dismiss
    
    private var statistics: CategoryStatistics {
        categoryService.getCategoryStatistics()
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 概览统计
                    overviewSection
                    
                    // 分类分布图表
                    distributionChart
                    
                    // 热门分类
                    topCategoriesSection
                    
                    // 层级分析
                    hierarchyAnalysis
                }
                .padding()
            }
            .navigationTitle("分类统计")
            #if os(iOS)
            .platformNavigationBarTitleDisplayMode(.inline) // 适配macOS/iOS
            #else
            .platformNavigationBarTitleDisplayMode(0) // 适配macOS/iOS
            #endif
            .platformToolbar(trailing: {
                Button("关闭") {
                    dismiss()
                }
            })
            .background(ModernColors.Background.primary)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
    }
    
    // MARK: - 概览统计
    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("概览")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                CategoryStatisticCard(
                    title: "总分类数",
                    value: "\(statistics.totalCategories)",
                    icon: "folder.fill",
                    color: .blue
                )

                CategoryStatisticCard(
                    title: "根分类数",
                    value: "\(statistics.rootCategories)",
                    icon: "folder.badge.plus",
                    color: .green
                )

                CategoryStatisticCard(
                    title: "最大层级",
                    value: "\(statistics.maxDepth + 1)",
                    icon: "arrow.down.to.line",
                    color: .orange
                )

                CategoryStatisticCard(
                    title: "总产品数",
                    value: "\(statistics.totalProducts)",
                    icon: "cube.box.fill",
                    color: .purple
                )
            }
            
            // 平均产品数
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.indigo)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("平均每分类产品数")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(String(format: "%.1f", statistics.averageProductsPerCategory))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                
                Spacer()
            }
            .padding()
            .background(ModernColors.System.gray6)
            .cornerRadius(12)
        }
    }
    
    // MARK: - 分布图表
    private var distributionChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("产品分布")
                .font(.headline)
                .fontWeight(.semibold)
            
            if #available(iOS 16.0, macOS 13.0, *) {
                Chart {
                    ForEach(statistics.topCategories.indices, id: \.self) { index in
                        let (name, count) = statistics.topCategories[index]
                        BarMark(
                            x: .value("分类", name),
                            y: .value("产品数", count)
                        )
                        .foregroundStyle(Color.accentColor.gradient)
                        .cornerRadius(4)
                    }
                }
                .frame(height: 200)
                .chartXAxis {
                    AxisMarks { _ in
                        AxisValueLabel()
                            .font(.caption)
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisGridLine()
                        AxisValueLabel()
                            .font(.caption)
                    }
                }
            } else {
                // iOS 15 及以下版本的替代方案
                VStack(spacing: 8) {
                    ForEach(statistics.topCategories.indices, id: \.self) { index in
                        let (name, count) = statistics.topCategories[index]
                        HStack {
                            Text(name)
                                .font(.caption)
                                .frame(width: 80, alignment: .leading)
                            
                            GeometryReader { geometry in
                                HStack(spacing: 0) {
                                    Rectangle()
                                        .fill(Color.accentColor)
                                        .frame(width: CGFloat(count) / CGFloat(statistics.totalProducts) * geometry.size.width)
                                        .cornerRadius(2)
                                    
                                    Spacer(minLength: 0)
                                }
                            }
                            .frame(height: 16)
                            
                            Text("\(count)")
                                .font(.caption)
                                .fontWeight(.medium)
                                .frame(width: 30, alignment: .trailing)
                        }
                    }
                }
                .padding()
                .background(ModernColors.System.gray6)
                .cornerRadius(12)
            }
        }
    }
    
    // MARK: - 热门分类
    private var topCategoriesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("热门分类")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                ForEach(statistics.topCategories.indices, id: \.self) { index in
                    let (name, count) = statistics.topCategories[index]
                    TopCategoryRow(
                        rank: index + 1,
                        name: name,
                        count: count,
                        percentage: Double(count) / Double(statistics.totalProducts) * 100
                    )
                }
            }
        }
    }
    
    // MARK: - 层级分析
    private var hierarchyAnalysis: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("层级分析")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                HierarchyLevelRow(
                    level: 0,
                    name: "根分类",
                    count: statistics.rootCategories,
                    icon: "folder.fill"
                )
                
                ForEach(1...statistics.maxDepth, id: \.self) { level in
                    let categoriesAtLevel = categoryService.categories.filter { $0.level == level }.count
                    HierarchyLevelRow(
                        level: level,
                        name: "第\(level + 1)级分类",
                        count: categoriesAtLevel,
                        icon: "folder"
                    )
                }
            }
            .padding()
            .background(ModernColors.System.gray6)
            .cornerRadius(12)
        }
    }
}

// MARK: - 统计卡片
struct CategoryStatisticCard: View {
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
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(ModernColors.Background.primary)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

// MARK: - 热门分类行
struct TopCategoryRow: View {
    let rank: Int
    let name: String
    let count: Int
    let percentage: Double
    
    var body: some View {
        HStack(spacing: 12) {
            // 排名
            Text("\(rank)")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(rankColor)
                .clipShape(Circle())
            
            // 分类名称
            Text(name)
                .font(.body)
                .fontWeight(.medium)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // 产品数量
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(count)")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(String(format: "%.1f%%", percentage))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(ModernColors.Background.primary)
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
    }
    
    private var rankColor: Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return .blue
        }
    }
}

// MARK: - 层级行
struct HierarchyLevelRow: View {
    let level: Int
    let name: String
    let count: Int
    let icon: String
    
    var body: some View {
        HStack(spacing: 12) {
            // 层级指示器
            HStack(spacing: 4) {
                ForEach(0...level, id: \.self) { _ in
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 6, height: 6)
                }
            }
            .frame(width: 60, alignment: .leading)
            
            // 图标
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(.accentColor)
                .frame(width: 20)
            
            // 名称
            Text(name)
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // 数量
            Text("\(count)")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
    }
}

#Preview {
    CategoryStatisticsView()
}
