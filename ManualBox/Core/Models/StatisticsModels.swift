//
//  StatisticsModels.swift
//  ManualBox
//
//  Created by Assistant on 2025/6/24.
//

import Foundation

// MARK: - 仪表板统计数据
struct DashboardStatistics {
    let productStats: ProductStatistics
    let warrantyStats: WarrantyStatistics
    let costStats: CostStatistics
    let usageStats: UsageStatistics
    let categoryStats: [CategoryStatistic]
    let trendStats: TrendStatistics
    let lastUpdated: Date
    
    var summary: String {
        return """
        📊 数据概览
        • 产品总数: \(productStats.totalProducts)
        • 有效保修: \(warrantyStats.activeWarranties)
        • 总投资: ¥\(costStats.totalCost)
        • OCR处理率: \(String(format: "%.1f", usageStats.ocrProcessingRate * 100))%
        • 更新时间: \(DateFormatter.shortDateTime.string(from: lastUpdated))
        """
    }
}

// MARK: - 支出趋势
enum SpendingTrend {
    case increasing
    case decreasing
    case stable
}

// MARK: - 完成度级别
enum CompletionLevel {
    case high
    case medium
    case low
}

// MARK: - 产品统计
struct ProductStatistics {
    let totalProducts: Int
    let productsByCategory: [String: Int]
    let recentlyAdded: Int
    let withManuals: Int
    let withoutManuals: Int
    
    var manualCoverageRate: Double {
        guard totalProducts > 0 else { return 0.0 }
        return Double(withManuals) / Double(totalProducts)
    }
    
    var topCategories: [(String, Int)] {
        return productsByCategory.sorted { $0.value > $1.value }.prefix(5).map { ($0.key, $0.value) }
    }
}

// MARK: - 保修统计
struct WarrantyStatistics {
    let activeWarranties: Int
    let expiringSoon: Int
    let expired: Int
    let totalWarrantyValue: Decimal
    
    var totalWarranties: Int {
        return activeWarranties + expired
    }
    
    var activeRate: Double {
        guard totalWarranties > 0 else { return 0.0 }
        return Double(activeWarranties) / Double(totalWarranties)
    }
    
    var expiringRate: Double {
        guard activeWarranties > 0 else { return 0.0 }
        return Double(expiringSoon) / Double(activeWarranties)
    }
    
    var warrantyStatus: ProductSearchFilters.WarrantyStatus {
        if expiringSoon > 0 {
            return .expiring
        } else if activeWarranties > expired {
            return .active
        } else {
            return .expired
        }
    }
    
    // WarrantyStatus 枚举已移至 SearchFilters.swift
}

// MARK: - 费用统计
struct CostStatistics {
    let totalPurchaseCost: Decimal
    let totalMaintenanceCost: Decimal
    let totalCost: Decimal
    let monthlySpending: [String: Decimal]
    let averageProductCost: Decimal
    
    var maintenanceRatio: Double {
        guard totalCost > 0 else { return 0.0 }
        return Double(truncating: totalMaintenanceCost / totalCost as NSNumber)
    }
    
    var recentSpendingTrend: SpendingTrend {
        let sortedMonths = monthlySpending.keys.sorted()
        guard sortedMonths.count >= 2 else { return .stable }
        
        let lastMonth = monthlySpending[sortedMonths.last!] ?? 0
        let previousMonth = monthlySpending[sortedMonths[sortedMonths.count - 2]] ?? 0
        
        if lastMonth > previousMonth * 1.2 {
            return .increasing
        } else if lastMonth < previousMonth * 0.8 {
            return .decreasing
        } else {
            return .stable
        }
    }
    
    enum SpendingTrend {
        case increasing
        case decreasing
        case stable
        
        var icon: String {
            switch self {
            case .increasing: return "arrow.up.circle.fill"
            case .decreasing: return "arrow.down.circle.fill"
            case .stable: return "minus.circle.fill"
            }
        }
        
        var color: String {
            switch self {
            case .increasing: return "red"
            case .decreasing: return "green"
            case .stable: return "blue"
            }
        }
    }
}

// MARK: - 使用统计
struct UsageStatistics {
    let totalManuals: Int
    let processedManuals: Int
    let ocrProcessingRate: Double
    let averageProductAge: TimeInterval
    let mostUsedCategories: [String]

    var averageProductAgeInDays: Int {
        return Int(averageProductAge / (24 * 60 * 60))
    }

    var ocrCompletionLevel: OCRCompletionLevel {
        switch ocrProcessingRate {
        case 0.9...1.0:
            return .excellent
        case 0.7..<0.9:
            return .good
        case 0.5..<0.7:
            return .fair
        default:
            return .poor
        }
    }
}

// MARK: - 产品使用分析
struct ProductUsageAnalysis {
    let usageFrequency: UsageFrequencyAnalysis
    let maintenanceTrends: MaintenanceTrendAnalysis
    let costAnalysis: ProductCostAnalysis
    let categoryUsage: CategoryUsageAnalysis
    let ageAnalysis: ProductAgeAnalysis
    let performanceMetrics: UsagePerformanceMetrics
    let lastUpdated: Date

    var summary: String {
        return """
        📈 使用分析概览
        • 高频使用产品: \(usageFrequency.highFrequencyProducts.count)个
        • 维修频率: \(String(format: "%.1f", maintenanceTrends.averageMaintenanceFrequency))次/年
        • 平均使用成本: ¥\(String(format: "%.2f", costAnalysis.averageUsageCost))/月
        • 最活跃分类: \(categoryUsage.mostActiveCategory ?? "无")
        • 更新时间: \(DateFormatter.shortDateTime.string(from: lastUpdated))
        """
    }
}

// MARK: - 使用频率分析
struct UsageFrequencyAnalysis {
    let highFrequencyProducts: [ProductUsageMetric]
    let mediumFrequencyProducts: [ProductUsageMetric]
    let lowFrequencyProducts: [ProductUsageMetric]
    let unusedProducts: [ProductUsageMetric]
    let averageUsageFrequency: Double
    let usageDistribution: [UsageFrequencyLevel: Int]

    var totalTrackedProducts: Int {
        return highFrequencyProducts.count + mediumFrequencyProducts.count +
               lowFrequencyProducts.count + unusedProducts.count
    }

    var activeProductsPercentage: Double {
        guard totalTrackedProducts > 0 else { return 0.0 }
        let activeProducts = highFrequencyProducts.count + mediumFrequencyProducts.count
        return Double(activeProducts) / Double(totalTrackedProducts)
    }
}

// MARK: - 维修趋势分析
struct MaintenanceTrendAnalysis {
    let monthlyMaintenanceCount: [String: Int]
    let averageMaintenanceFrequency: Double
    let maintenanceCostTrend: TrendDirection
    let topMaintenanceCategories: [CategoryMaintenanceMetric]
    let seasonalPatterns: [String: Double]
    let predictedMaintenanceNeeds: [ProductMaintenancePrediction]

    var totalMaintenanceRecords: Int {
        return monthlyMaintenanceCount.values.reduce(0, +)
    }

    var maintenanceFrequencyTrend: TrendDirection {
        let sortedData = monthlyMaintenanceCount.sorted { $0.key < $1.key }
        guard sortedData.count >= 3 else { return .stable }

        let recent = Array(sortedData.suffix(3))
        let values = recent.map { $0.value }

        if values[2] > values[1] && values[1] > values[0] {
            return .increasing
        } else if values[2] < values[1] && values[1] < values[0] {
            return .decreasing
        } else {
            return .stable
        }
    }
}

// MARK: - 产品成本分析
struct ProductCostAnalysis {
    let totalOwnershipCost: Decimal
    let averageUsageCost: Double
    let costPerCategory: [String: Decimal]
    let maintenanceCostRatio: Double
    let depreciationAnalysis: [ProductDepreciation]
    let costEfficiencyRanking: [ProductCostEfficiency]

    var mostExpensiveCategory: String? {
        return costPerCategory.max { $0.value < $1.value }?.key
    }

    var averageMaintenanceCostPerProduct: Decimal {
        guard !depreciationAnalysis.isEmpty else { return 0 }
        let totalMaintenance = depreciationAnalysis.reduce(Decimal(0)) { $0 + $1.maintenanceCost }
        return totalMaintenance / Decimal(depreciationAnalysis.count)
    }
}

// MARK: - 分类使用分析
struct CategoryUsageAnalysis {
    let categoryMetrics: [CategoryUsageMetric]
    let mostActiveCategory: String?
    let leastActiveCategory: String?
    let categoryGrowthRates: [String: Double]
    let usageDistribution: [String: Double]

    var totalCategoriesTracked: Int {
        return categoryMetrics.count
    }
}

// MARK: - 产品年龄分析
struct ProductAgeAnalysis {
    let ageDistribution: [AgeGroup: Int]
    let averageAge: TimeInterval
    let oldestProduct: ProductAgeMetric?
    let newestProduct: ProductAgeMetric?
    let ageBasedMaintenanceCorrelation: Double

    var averageAgeInMonths: Int {
        return Int(averageAge / (30 * 24 * 60 * 60))
    }
}

// MARK: - 使用性能指标
struct UsagePerformanceMetrics {
    let dataCollectionAccuracy: Double
    let trackingCoverage: Double
    let analysisConfidenceLevel: Double
    let lastDataUpdate: Date
    let missingDataPoints: Int

    var overallDataQuality: DataQualityLevel {
        let averageScore = (dataCollectionAccuracy + trackingCoverage + analysisConfidenceLevel) / 3
        switch averageScore {
        case 0.9...1.0:
            return .excellent
        case 0.7..<0.9:
            return .good
        case 0.5..<0.7:
            return .fair
        default:
            return .poor
        }
    }
}

// MARK: - 支持数据结构

struct ProductUsageMetric {
    let productId: UUID
    let productName: String
    let categoryName: String?
    let usageFrequency: Double
    let lastUsedDate: Date?
    let totalUsageTime: TimeInterval
    let usageScore: Double

    var usageLevel: UsageFrequencyLevel {
        switch usageFrequency {
        case 0.8...1.0:
            return .high
        case 0.4..<0.8:
            return .medium
        case 0.1..<0.4:
            return .low
        default:
            return .unused
        }
    }
}

struct CategoryMaintenanceMetric {
    let categoryName: String
    let maintenanceCount: Int
    let averageCost: Decimal
    let frequency: Double
    let trend: TrendDirection
}

struct ProductMaintenancePrediction {
    let productId: UUID
    let productName: String
    let predictedMaintenanceDate: Date
    let confidenceLevel: Double
    let estimatedCost: Decimal
    let riskLevel: MaintenanceRiskLevel
}

struct ProductDepreciation {
    let productId: UUID
    let productName: String
    let originalCost: Decimal
    let currentValue: Decimal
    let maintenanceCost: Decimal
    let depreciationRate: Double
    let totalCostOfOwnership: Decimal
}

struct ProductCostEfficiency {
    let productId: UUID
    let productName: String
    let costPerUsage: Decimal
    let efficiencyScore: Double
    let ranking: Int
}

struct CategoryUsageMetric {
    let categoryName: String
    let productCount: Int
    let totalUsageTime: TimeInterval
    let averageUsageFrequency: Double
    let growthRate: Double
}

struct ProductAgeMetric {
    let productId: UUID
    let productName: String
    let age: TimeInterval
    let purchaseDate: Date?
    let ageGroup: AgeGroup
}

// MARK: - 枚举定义

enum UsageFrequencyLevel: String, CaseIterable {
    case high = "高频使用"
    case medium = "中频使用"
    case low = "低频使用"
    case unused = "未使用"

    var color: String {
        switch self {
        case .high: return "green"
        case .medium: return "blue"
        case .low: return "orange"
        case .unused: return "red"
        }
    }

    var threshold: Double {
        switch self {
        case .high: return 0.8
        case .medium: return 0.4
        case .low: return 0.1
        case .unused: return 0.0
        }
    }
}

enum MaintenanceRiskLevel: String, CaseIterable {
    case low = "低风险"
    case medium = "中等风险"
    case high = "高风险"
    case critical = "紧急"

    var color: String {
        switch self {
        case .low: return "green"
        case .medium: return "yellow"
        case .high: return "orange"
        case .critical: return "red"
        }
    }
}

enum AgeGroup: String, CaseIterable {
    case new = "新购买 (< 3个月)"
    case recent = "近期购买 (3-12个月)"
    case established = "已使用 (1-3年)"
    case mature = "长期使用 (3-5年)"
    case old = "老旧产品 (> 5年)"

    var monthsRange: ClosedRange<Int> {
        switch self {
        case .new: return 0...3
        case .recent: return 4...12
        case .established: return 13...36
        case .mature: return 37...60
        case .old: return 61...Int.max
        }
    }
}

enum DataQualityLevel: String, CaseIterable {
    case excellent = "优秀"
    case good = "良好"
    case fair = "一般"
    case poor = "较差"

    var color: String {
        switch self {
        case .excellent: return "green"
        case .good: return "blue"
        case .fair: return "orange"
        case .poor: return "red"
        }
    }
}

// MARK: - DateFormatter 扩展
extension DateFormatter {
    static let shortDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()

    static let longDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter
    }()

    static let shortTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()

    static let monthName: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter
    }()
}

enum OCRCompletionLevel {
    case excellent
    case good
    case fair
    case poor

    var description: String {
        switch self {
        case .excellent: return "优秀"
        case .good: return "良好"
        case .fair: return "一般"
        case .poor: return "需要改进"
        }
    }

    var color: String {
        switch self {
        case .excellent: return "green"
        case .good: return "blue"
        case .fair: return "orange"
        case .poor: return "red"
        }
    }
}

// MARK: - 分类统计
struct CategoryStatistic: Identifiable {
    let id = UUID()
    let name: String
    let productCount: Int
    let totalValue: Decimal
    let iconName: String
    
    var averageValue: Decimal {
        guard productCount > 0 else { return 0 }
        return totalValue / Decimal(productCount)
    }
}

// MARK: - 趋势方向
enum TrendDirection {
    case increasing
    case decreasing
    case stable

    var icon: String {
        switch self {
        case .increasing: return "chart.line.uptrend.xyaxis"
        case .decreasing: return "chart.line.downtrend.xyaxis"
        case .stable: return "chart.line.flattrend.xyaxis"
        }
    }

    var color: String {
        switch self {
        case .increasing: return "green"
        case .decreasing: return "red"
        case .stable: return "blue"
        }
    }

    var description: String {
        switch self {
        case .increasing: return "上升趋势"
        case .decreasing: return "下降趋势"
        case .stable: return "稳定趋势"
        }
    }
}

// MARK: - 趋势统计
struct TrendStatistics {
    let monthlyProductAdditions: [String: Int]
    let monthlyMaintenanceRecords: [String: Int]
    
    var productAdditionTrend: TrendDirection {
        return calculateTrend(from: monthlyProductAdditions)
    }
    
    var maintenanceTrend: TrendDirection {
        return calculateTrend(from: monthlyMaintenanceRecords)
    }
    
    private func calculateTrend(from data: [String: Int]) -> TrendDirection {
        let sortedData = data.sorted { $0.key < $1.key }
        guard sortedData.count >= 3 else { return .stable }
        
        let recent = Array(sortedData.suffix(3))
        let values = recent.map { $0.value }
        
        if values[2] > values[1] && values[1] > values[0] {
            return .increasing
        } else if values[2] < values[1] && values[1] < values[0] {
            return .decreasing
        } else {
            return .stable
        }
    }
    

}

// MARK: - 统计时间范围
enum StatisticsTimeRange: String, CaseIterable {
    case week = "本周"
    case month = "本月"
    case quarter = "本季度"
    case year = "本年"
    case all = "全部"
    
    var dateRange: (start: Date, end: Date) {
        let calendar = Calendar.current
        let now = Date()
        
        switch self {
        case .week:
            let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
            return (startOfWeek, now)
        case .month:
            let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
            return (startOfMonth, now)
        case .quarter:
            let startOfQuarter = calendar.dateInterval(of: .quarter, for: now)?.start ?? now
            return (startOfQuarter, now)
        case .year:
            let startOfYear = calendar.dateInterval(of: .year, for: now)?.start ?? now
            return (startOfYear, now)
        case .all:
            return (Date.distantPast, now)
        }
    }
}

// MARK: - 统计卡片类型
enum StatisticCardType: String, CaseIterable {
    case products = "产品概览"
    case warranty = "保修状态"
    case costs = "费用分析"
    case usage = "使用情况"
    case categories = "分类分布"
    case trends = "趋势分析"
    
    var icon: String {
        switch self {
        case .products: return "cube.box"
        case .warranty: return "shield.checkered"
        case .costs: return "dollarsign.circle"
        case .usage: return "chart.bar"
        case .categories: return "folder.badge.gearshape"
        case .trends: return "chart.line.uptrend.xyaxis"
        }
    }
    
    var color: String {
        switch self {
        case .products: return "blue"
        case .warranty: return "green"
        case .costs: return "orange"
        case .usage: return "purple"
        case .categories: return "indigo"
        case .trends: return "pink"
        }
    }
}


