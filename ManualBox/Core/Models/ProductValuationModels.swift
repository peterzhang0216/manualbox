//
//  ProductValuationModels.swift
//  ManualBox
//
//  Created by Assistant on 2025/6/25.
//

import Foundation
import SwiftUI

// MARK: - 产品价值评估
struct ProductValuation: Identifiable, Codable {
    let id: UUID
    let productId: UUID
    let productName: String
    let originalPrice: Decimal
    let currentValue: Decimal
    let marketValue: Decimal
    let depreciationRate: Double
    let valuationDate: Date
    let valuationMethod: ValuationMethod
    let factors: [ValuationFactor]
    let marketData: MarketData?
    let condition: ProductCondition
    let usageMetrics: UsageMetrics
    let recommendations: [ValuationRecommendation]
    let confidence: Double
    let nextValuationDate: Date
    
    var depreciationAmount: Decimal {
        return originalPrice - currentValue
    }
    
    var depreciationPercentage: Double {
        guard originalPrice > 0 else { return 0.0 }
        return Double(truncating: (depreciationAmount / originalPrice) as NSNumber) * 100
    }
    
    var valueRetentionRate: Double {
        guard originalPrice > 0 else { return 0.0 }
        return Double(truncating: (currentValue / originalPrice) as NSNumber) * 100
    }
    
    var isAppreciating: Bool {
        return currentValue > originalPrice
    }
    
    var valueTrend: ValueTrend {
        if currentValue > originalPrice * 1.1 {
            return .appreciating
        } else if currentValue > originalPrice * 0.9 {
            return .stable
        } else if currentValue > originalPrice * 0.5 {
            return .depreciating
        } else {
            return .rapidDepreciation
        }
    }
}

// MARK: - 估值方法
enum ValuationMethod: String, CaseIterable, Codable {
    case marketComparison = "市场比较法"
    case costApproach = "成本法"
    case incomeApproach = "收益法"
    case depreciation = "折旧法"
    case hybrid = "综合评估法"
    
    var description: String {
        switch self {
        case .marketComparison:
            return "基于同类产品的市场价格进行评估"
        case .costApproach:
            return "基于重置成本减去折旧进行评估"
        case .incomeApproach:
            return "基于产品产生的收益进行评估"
        case .depreciation:
            return "基于标准折旧率进行评估"
        case .hybrid:
            return "综合多种方法进行评估"
        }
    }
    
    var icon: String {
        switch self {
        case .marketComparison:
            return "chart.bar.xaxis"
        case .costApproach:
            return "dollarsign.circle"
        case .incomeApproach:
            return "arrow.up.right.circle"
        case .depreciation:
            return "arrow.down.right.circle"
        case .hybrid:
            return "gearshape.2"
        }
    }
}

// MARK: - 估值因素
struct ValuationFactor: Identifiable, Codable {
    let id: UUID
    let name: String
    let category: FactorCategory
    let impact: Double // -1.0 到 1.0
    let weight: Double // 0.0 到 1.0
    let description: String
    let source: String
    
    var adjustedImpact: Double {
        return impact * weight
    }
}

enum FactorCategory: String, CaseIterable, Codable {
    case condition = "产品状况"
    case market = "市场因素"
    case usage = "使用情况"
    case maintenance = "维护状况"
    case technology = "技术因素"
    case brand = "品牌因素"
    case rarity = "稀有性"
    case demand = "需求状况"
    
    var icon: String {
        switch self {
        case .condition:
            return "checkmark.seal"
        case .market:
            return "chart.line.uptrend.xyaxis"
        case .usage:
            return "clock"
        case .maintenance:
            return "wrench.and.screwdriver"
        case .technology:
            return "cpu"
        case .brand:
            return "star"
        case .rarity:
            return "diamond"
        case .demand:
            return "person.3"
        }
    }
}

// MARK: - 市场数据
struct MarketData: Codable {
    let averagePrice: Decimal
    let priceRange: PriceRange
    let marketTrend: MarketTrend
    let comparableProducts: [ComparableProduct]
    let dataSource: String
    let lastUpdated: Date
    let sampleSize: Int
    let reliability: Double
}

struct PriceRange: Codable {
    let minimum: Decimal
    let maximum: Decimal
    let median: Decimal
    let percentile25: Decimal
    let percentile75: Decimal
}

enum MarketTrend: String, CaseIterable, Codable {
    case rising = "上涨"
    case stable = "稳定"
    case declining = "下跌"
    case volatile = "波动"
    
    var color: String {
        switch self {
        case .rising:
            return "green"
        case .stable:
            return "blue"
        case .declining:
            return "red"
        case .volatile:
            return "orange"
        }
    }
    
    var icon: String {
        switch self {
        case .rising:
            return "arrow.up.right"
        case .stable:
            return "arrow.right"
        case .declining:
            return "arrow.down.right"
        case .volatile:
            return "arrow.up.and.down"
        }
    }
}

struct ComparableProduct: Identifiable, Codable {
    let id: UUID
    let name: String
    let brand: String
    let model: String
    let price: Decimal
    let condition: ProductCondition
    let listingDate: Date
    let source: String
    let similarity: Double // 0.0 到 1.0
}

// MARK: - 产品状况
enum ProductCondition: String, CaseIterable, Codable {
    case new = "全新"
    case likeNew = "几乎全新"
    case excellent = "优秀"
    case good = "良好"
    case fair = "一般"
    case poor = "较差"
    case damaged = "损坏"
    
    var multiplier: Double {
        switch self {
        case .new:
            return 1.0
        case .likeNew:
            return 0.95
        case .excellent:
            return 0.85
        case .good:
            return 0.75
        case .fair:
            return 0.60
        case .poor:
            return 0.40
        case .damaged:
            return 0.20
        }
    }
    
    var color: String {
        switch self {
        case .new, .likeNew:
            return "green"
        case .excellent, .good:
            return "blue"
        case .fair:
            return "orange"
        case .poor, .damaged:
            return "red"
        }
    }
    
    var icon: String {
        switch self {
        case .new:
            return "star.fill"
        case .likeNew:
            return "star"
        case .excellent:
            return "checkmark.circle"
        case .good:
            return "checkmark"
        case .fair:
            return "minus.circle"
        case .poor:
            return "xmark.circle"
        case .damaged:
            return "exclamationmark.triangle"
        }
    }
}

// MARK: - 使用指标
struct UsageMetrics: Codable {
    let ageInMonths: Double
    let usageFrequency: UsageFrequency
    let maintenanceHistory: MaintenanceHistory
    let repairHistory: RepairHistory
    let upgradeHistory: [Upgrade]
    let performanceMetrics: ValuationPerformanceMetrics?
}

enum UsageFrequency: String, CaseIterable, Codable {
    case heavy = "重度使用"
    case moderate = "中度使用"
    case light = "轻度使用"
    case minimal = "极少使用"
    
    var multiplier: Double {
        switch self {
        case .heavy:
            return 0.7
        case .moderate:
            return 0.85
        case .light:
            return 0.95
        case .minimal:
            return 1.0
        }
    }
}

struct MaintenanceHistory: Codable {
    let regularMaintenance: Bool
    let lastMaintenanceDate: Date?
    let maintenanceFrequency: Double // 每年次数
    let maintenanceQuality: MaintenanceQuality
}

enum MaintenanceQuality: String, CaseIterable, Codable {
    case excellent = "优秀"
    case good = "良好"
    case average = "一般"
    case poor = "较差"
    
    var multiplier: Double {
        switch self {
        case .excellent:
            return 1.1
        case .good:
            return 1.05
        case .average:
            return 1.0
        case .poor:
            return 0.9
        }
    }
}

struct RepairHistory: Codable {
    let totalRepairs: Int
    let majorRepairs: Int
    let totalRepairCost: Decimal
    let lastRepairDate: Date?
    let repairFrequency: Double // 每年次数
}

struct Upgrade: Identifiable, Codable {
    let id: UUID
    let name: String
    let cost: Decimal
    let date: Date
    let valueImpact: Double
}

struct ValuationPerformanceMetrics: Codable {
    let currentPerformance: Double // 0.0 到 1.0
    let originalPerformance: Double
    let performanceDegradation: Double
    let benchmarkScores: [String: Double]
}

// MARK: - 价值趋势
enum ValueTrend: String, CaseIterable, Codable {
    case appreciating = "增值"
    case stable = "稳定"
    case depreciating = "贬值"
    case rapidDepreciation = "快速贬值"
    
    var color: String {
        switch self {
        case .appreciating:
            return "green"
        case .stable:
            return "blue"
        case .depreciating:
            return "orange"
        case .rapidDepreciation:
            return "red"
        }
    }
    
    var icon: String {
        switch self {
        case .appreciating:
            return "arrow.up.circle.fill"
        case .stable:
            return "arrow.right.circle.fill"
        case .depreciating:
            return "arrow.down.circle.fill"
        case .rapidDepreciation:
            return "arrow.down.circle"
        }
    }
}

// MARK: - 估值建议
struct ValuationRecommendation: Identifiable, Codable {
    let id: UUID
    let type: RecommendationType
    let title: String
    let description: String
    let priority: Priority
    let potentialImpact: Decimal
    let actionRequired: Bool
}

enum RecommendationType: String, CaseIterable, Codable {
    case sell = "出售建议"
    case hold = "持有建议"
    case upgrade = "升级建议"
    case maintain = "维护建议"
    case insure = "保险建议"
    case repair = "维修建议"
    
    var icon: String {
        switch self {
        case .sell:
            return "dollarsign.circle"
        case .hold:
            return "hand.raised"
        case .upgrade:
            return "arrow.up.circle"
        case .maintain:
            return "wrench.and.screwdriver"
        case .insure:
            return "shield"
        case .repair:
            return "hammer"
        }
    }
}

// MARK: - 估值历史
struct ValuationHistory: Identifiable, Codable {
    let id: UUID
    let productId: UUID
    let valuations: [HistoricalValuation]
    let createdAt: Date
    let updatedAt: Date
    
    var latestValuation: HistoricalValuation? {
        return valuations.max { $0.date < $1.date }
    }
    
    var valueChangeOverTime: [ValueChange] {
        guard valuations.count > 1 else { return [] }
        
        let sortedValuations = valuations.sorted { $0.date < $1.date }
        var changes: [ValueChange] = []
        
        for i in 1..<sortedValuations.count {
            let previous = sortedValuations[i-1]
            let current = sortedValuations[i]
            let change = current.value - previous.value
            let changePercentage = Double(truncating: (change / previous.value) as NSNumber) * 100
            
            changes.append(ValueChange(
                date: current.date,
                value: current.value,
                change: change,
                changePercentage: changePercentage
            ))
        }
        
        return changes
    }
}

struct HistoricalValuation: Identifiable, Codable {
    let id: UUID
    let date: Date
    let value: Decimal
    let method: ValuationMethod
    let confidence: Double
}

struct ValueChange: Identifiable, Codable {
    let id = UUID()
    let date: Date
    let value: Decimal
    let change: Decimal
    let changePercentage: Double
}
