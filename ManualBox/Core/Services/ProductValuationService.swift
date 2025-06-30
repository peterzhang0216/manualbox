//
//  ProductValuationService.swift
//  ManualBox
//
//  Created by Assistant on 2025/6/25.
//

import Foundation
import CoreData
import Combine

// MARK: - 产品价值评估服务
@MainActor
class ProductValuationService: ObservableObject {
    static let shared = ProductValuationService()
    
    @Published var valuations: [ProductValuation] = []
    @Published var valuationHistory: [ValuationHistory] = []
    @Published var isEvaluating = false
    @Published var lastError: Error?
    
    private let context: NSManagedObjectContext
    private var cancellables = Set<AnyCancellable>()
    
    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.context = context
        loadData()
    }
    
    // MARK: - 数据加载
    
    private func loadData() {
        loadValuations()
        loadValuationHistory()
    }
    
    private func loadValuations() {
        if let data = UserDefaults.standard.data(forKey: "ProductValuations"),
           let valuations = try? JSONDecoder().decode([ProductValuation].self, from: data) {
            self.valuations = valuations
        }
    }
    
    private func loadValuationHistory() {
        if let data = UserDefaults.standard.data(forKey: "ValuationHistory"),
           let history = try? JSONDecoder().decode([ValuationHistory].self, from: data) {
            self.valuationHistory = history
        }
    }
    
    // MARK: - 主要评估方法
    
    /// 评估单个产品价值
    func evaluateProduct(_ product: Product, method: ValuationMethod = .hybrid) async throws -> ProductValuation {
        isEvaluating = true
        defer { isEvaluating = false }
        
        do {
            // 收集产品信息
            let productInfo = collectProductInfo(product)
            
            // 获取市场数据
            let marketData = await fetchMarketData(for: product)
            
            // 分析使用情况
            let usageMetrics = analyzeUsageMetrics(product)
            
            // 评估产品状况
            let condition = assessProductCondition(product, usageMetrics: usageMetrics)
            
            // 计算估值因素
            let factors = calculateValuationFactors(
                product: product,
                marketData: marketData,
                usageMetrics: usageMetrics,
                condition: condition
            )
            
            // 执行估值
            let valuationResult = performValuation(
                productInfo: productInfo,
                marketData: marketData,
                usageMetrics: usageMetrics,
                condition: condition,
                factors: factors,
                method: method
            )
            
            // 创建临时估值对象用于生成建议
            let tempValuation = ProductValuation(
                id: UUID(),
                productId: product.id ?? UUID(),
                productName: product.productName,
                originalPrice: Decimal(product.order?.price?.doubleValue ?? 0),
                currentValue: valuationResult.currentValue,
                marketValue: valuationResult.marketValue,
                depreciationRate: valuationResult.depreciationRate,
                valuationDate: Date(),
                valuationMethod: method,
                factors: factors,
                marketData: marketData,
                condition: condition,
                usageMetrics: usageMetrics,
                recommendations: [],
                confidence: valuationResult.confidence,
                nextValuationDate: Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date()
            )
            
            // 生成建议
            let recommendations = generateRecommendations(valuation: tempValuation, factors: factors)
            
            let finalValuation = ProductValuation(
                id: UUID(),
                productId: product.id ?? UUID(),
                productName: product.productName,
                originalPrice: Decimal(product.order?.price?.doubleValue ?? 0),
                currentValue: valuationResult.currentValue,
                marketValue: valuationResult.marketValue,
                depreciationRate: valuationResult.depreciationRate,
                valuationDate: Date(),
                valuationMethod: method,
                factors: factors,
                marketData: marketData,
                condition: condition,
                usageMetrics: usageMetrics,
                recommendations: recommendations,
                confidence: valuationResult.confidence,
                nextValuationDate: Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date()
            )
            
            // 保存估值结果
            await saveValuation(finalValuation)
            
            return finalValuation
        } catch {
            lastError = error
            throw error
        }
    }
    
    /// 批量评估产品
    func evaluateProducts(_ products: [Product], method: ValuationMethod = .hybrid) async throws -> [ProductValuation] {
        isEvaluating = true
        defer { isEvaluating = false }
        
        var results: [ProductValuation] = []
        
        for product in products {
            do {
                let valuation = try await evaluateProduct(product, method: method)
                results.append(valuation)
            } catch {
                print("评估产品 \(product.productName) 失败: \(error)")
                continue
            }
        }
        
        return results
    }
    
    // MARK: - 数据收集
    
    private func collectProductInfo(_ product: Product) -> ProductInfo {
        return ProductInfo(
            id: product.id ?? UUID(),
            name: product.productName,
            brand: product.productBrand,
            model: product.productModel,
            category: product.category?.categoryName ?? "其他",
            purchaseDate: product.order?.orderDate,
            originalPrice: Decimal(product.order?.price?.doubleValue ?? 0),
            age: calculateProductAge(product)
        )
    }
    
    private func calculateProductAge(_ product: Product) -> Double {
        guard let purchaseDate = product.order?.orderDate else { return 0 }
        let ageInSeconds = Date().timeIntervalSince(purchaseDate)
        return ageInSeconds / (30 * 24 * 60 * 60) // 转换为月
    }
    
    private func fetchMarketData(for product: Product) async -> MarketData? {
        // 模拟市场数据获取
        // 在实际应用中，这里会调用外部API获取市场数据
        
        let basePrice = product.order?.price ?? 1000
        let randomFactor = Double.random(in: 0.8...1.2)
        
        return MarketData(
            averagePrice: Decimal(basePrice.doubleValue) * Decimal(randomFactor),
            priceRange: PriceRange(
                minimum: Decimal(basePrice.doubleValue) * Decimal(0.6),
                maximum: Decimal(basePrice.doubleValue) * Decimal(1.4),
                median: Decimal(basePrice.doubleValue) * Decimal(randomFactor),
                percentile25: Decimal(basePrice.doubleValue) * Decimal(0.75),
                percentile75: Decimal(basePrice.doubleValue) * Decimal(1.15)
            ),
            marketTrend: MarketTrend.allCases.randomElement() ?? .stable,
            comparableProducts: generateComparableProducts(for: product),
            dataSource: "模拟数据",
            lastUpdated: Date(),
            sampleSize: Int.random(in: 10...100),
            reliability: Double.random(in: 0.7...0.95)
        )
    }
    
    private func generateComparableProducts(for product: Product) -> [ComparableProduct] {
        let basePrice = product.order?.price ?? 1000
        var comparables: [ComparableProduct] = []
        
        for i in 0..<5 {
            let priceFactor = Double.random(in: 0.8...1.2)
            comparables.append(ComparableProduct(
                id: UUID(),
                name: "\(product.productName) 类似产品 \(i+1)",
                brand: product.productBrand,
                model: "\(product.productModel)-\(i+1)",
                price: Decimal(basePrice.doubleValue) * Decimal(priceFactor),
                condition: ProductCondition.allCases.randomElement() ?? .good,
                listingDate: Date().addingTimeInterval(-Double.random(in: 0...30*24*60*60)),
                source: "模拟市场",
                similarity: Double.random(in: 0.7...0.95)
            ))
        }
        
        return comparables
    }
    
    private func analyzeUsageMetrics(_ product: Product) -> UsageMetrics {
        let age = calculateProductAge(product)
        let repairRecords = product.order?.repairRecords?.allObjects as? [RepairRecord] ?? []
        
        return UsageMetrics(
            ageInMonths: age,
            usageFrequency: estimateUsageFrequency(product),
            maintenanceHistory: MaintenanceHistory(
                regularMaintenance: repairRecords.count > 0,
                lastMaintenanceDate: repairRecords.last?.date,
                maintenanceFrequency: Double(repairRecords.count) / max(1, age / 12),
                maintenanceQuality: .good
            ),
            repairHistory: RepairHistory(
                totalRepairs: repairRecords.count,
                majorRepairs: repairRecords.filter { ($0.cost?.decimalValue ?? 0) > 500 }.count,
                totalRepairCost: repairRecords.reduce(0) { $0 + ($1.cost?.decimalValue ?? 0) },
                lastRepairDate: repairRecords.last?.date,
                repairFrequency: Double(repairRecords.count) / max(1, age / 12)
            ),
            upgradeHistory: [],
            performanceMetrics: nil
        )
    }
    
    private func estimateUsageFrequency(_ product: Product) -> UsageFrequency {
        // 基于产品类别和年龄估算使用频率
        let category = product.category?.categoryName ?? "其他"
        let age = calculateProductAge(product)
        
        switch category {
        case "电子产品":
            return age > 24 ? .moderate : .heavy
        case "家用电器":
            return .moderate
        case "运动器材":
            return .light
        default:
            return .moderate
        }
    }
    
    private func assessProductCondition(_ product: Product, usageMetrics: UsageMetrics) -> ProductCondition {
        let age = usageMetrics.ageInMonths
        let repairCount = usageMetrics.repairHistory.totalRepairs
        let usageFrequency = usageMetrics.usageFrequency
        
        // 基于年龄、维修次数和使用频率评估状况
        var conditionScore = 1.0
        
        // 年龄影响
        conditionScore -= min(0.5, age / 60.0) // 5年内最多减0.5分
        
        // 维修次数影响
        conditionScore -= min(0.3, Double(repairCount) * 0.1)
        
        // 使用频率影响
        switch usageFrequency {
        case .heavy:
            conditionScore -= 0.2
        case .moderate:
            conditionScore -= 0.1
        case .light, .minimal:
            break
        }
        
        // 转换为状况等级
        if conditionScore >= 0.9 {
            return .likeNew
        } else if conditionScore >= 0.8 {
            return .excellent
        } else if conditionScore >= 0.7 {
            return .good
        } else if conditionScore >= 0.5 {
            return .fair
        } else {
            return .poor
        }
    }
    
    // MARK: - 保存数据
    
    private func saveValuation(_ valuation: ProductValuation) async {
        // 更新或添加估值
        if let index = valuations.firstIndex(where: { $0.productId == valuation.productId }) {
            valuations[index] = valuation
        } else {
            valuations.append(valuation)
        }
        
        // 保存到持久化存储
        if let data = try? JSONEncoder().encode(valuations) {
            UserDefaults.standard.set(data, forKey: "ProductValuations")
        }
        
        // 更新历史记录
        await updateValuationHistory(valuation)
    }
    
    private func updateValuationHistory(_ valuation: ProductValuation) async {
        let historicalValuation = HistoricalValuation(
            id: UUID(),
            date: valuation.valuationDate,
            value: valuation.currentValue,
            method: valuation.valuationMethod,
            confidence: valuation.confidence
        )
        
        if let index = valuationHistory.firstIndex(where: { $0.productId == valuation.productId }) {
            let existingHistory = valuationHistory[index]
            var updatedValuations = existingHistory.valuations
            updatedValuations.append(historicalValuation)

            let updatedHistory = ValuationHistory(
                id: existingHistory.id,
                productId: existingHistory.productId,
                valuations: updatedValuations,
                createdAt: existingHistory.createdAt,
                updatedAt: Date()
            )
            valuationHistory[index] = updatedHistory
        } else {
            let newHistory = ValuationHistory(
                id: UUID(),
                productId: valuation.productId,
                valuations: [historicalValuation],
                createdAt: Date(),
                updatedAt: Date()
            )
            valuationHistory.append(newHistory)
        }
        
        // 保存历史记录
        if let data = try? JSONEncoder().encode(valuationHistory) {
            UserDefaults.standard.set(data, forKey: "ValuationHistory")
        }
    }

    // MARK: - 估值计算

    private func calculateValuationFactors(
        product: Product,
        marketData: MarketData?,
        usageMetrics: UsageMetrics,
        condition: ProductCondition
    ) -> [ValuationFactor] {
        var factors: [ValuationFactor] = []

        // 产品状况因素
        factors.append(ValuationFactor(
            id: UUID(),
            name: "产品状况",
            category: .condition,
            impact: condition.multiplier - 1.0,
            weight: 0.3,
            description: "基于产品当前状况的价值影响",
            source: "状况评估"
        ))

        // 年龄因素
        let ageFactor = max(-0.8, -usageMetrics.ageInMonths / 60.0) // 5年内最多减80%
        factors.append(ValuationFactor(
            id: UUID(),
            name: "产品年龄",
            category: .usage,
            impact: ageFactor,
            weight: 0.25,
            description: "产品使用年限对价值的影响",
            source: "使用分析"
        ))

        // 维修历史因素
        let repairImpact = -min(0.3, Double(usageMetrics.repairHistory.totalRepairs) * 0.05)
        factors.append(ValuationFactor(
            id: UUID(),
            name: "维修历史",
            category: .maintenance,
            impact: repairImpact,
            weight: 0.2,
            description: "维修次数对产品价值的影响",
            source: "维修记录"
        ))

        // 市场趋势因素
        if let marketData = marketData {
            let trendImpact: Double
            switch marketData.marketTrend {
            case .rising:
                trendImpact = 0.1
            case .stable:
                trendImpact = 0.0
            case .declining:
                trendImpact = -0.1
            case .volatile:
                trendImpact = -0.05
            }

            factors.append(ValuationFactor(
                id: UUID(),
                name: "市场趋势",
                category: .market,
                impact: trendImpact,
                weight: 0.15,
                description: "当前市场趋势对价值的影响",
                source: "市场数据"
            ))
        }

        // 品牌因素
        let brandImpact = getBrandImpact(product.productBrand)
        factors.append(ValuationFactor(
            id: UUID(),
            name: "品牌价值",
            category: .brand,
            impact: brandImpact,
            weight: 0.1,
            description: "品牌对产品保值性的影响",
            source: "品牌分析"
        ))

        return factors
    }

    private func getBrandImpact(_ brand: String) -> Double {
        // 简化的品牌价值评估
        let premiumBrands = ["Apple", "Sony", "Samsung", "LG", "Panasonic", "苹果", "索尼", "三星"]
        let goodBrands = ["Xiaomi", "Huawei", "OPPO", "Vivo", "小米", "华为"]

        if premiumBrands.contains(brand) {
            return 0.1
        } else if goodBrands.contains(brand) {
            return 0.05
        } else {
            return 0.0
        }
    }

    private func performValuation(
        productInfo: ProductInfo,
        marketData: MarketData?,
        usageMetrics: UsageMetrics,
        condition: ProductCondition,
        factors: [ValuationFactor],
        method: ValuationMethod
    ) -> ValuationResult {
        let originalPrice = productInfo.originalPrice

        switch method {
        case .depreciation:
            return depreciationMethod(originalPrice: originalPrice, factors: factors, usageMetrics: usageMetrics)
        case .marketComparison:
            return marketComparisonMethod(originalPrice: originalPrice, marketData: marketData, factors: factors)
        case .costApproach:
            return costApproachMethod(originalPrice: originalPrice, condition: condition, factors: factors)
        case .hybrid:
            return hybridMethod(originalPrice: originalPrice, marketData: marketData, condition: condition, factors: factors, usageMetrics: usageMetrics)
        case .incomeApproach:
            return incomeApproachMethod(originalPrice: originalPrice, factors: factors)
        }
    }

    private func depreciationMethod(originalPrice: Decimal, factors: [ValuationFactor], usageMetrics: UsageMetrics) -> ValuationResult {
        let standardDepreciationRate = 0.2 // 年折旧率20%
        let ageInYears = usageMetrics.ageInMonths / 12.0
        let baseDepreciation = 1.0 - (standardDepreciationRate * ageInYears)

        let factorAdjustment = factors.reduce(0) { $0 + $1.adjustedImpact }
        let adjustedValue = max(0.1, baseDepreciation + factorAdjustment)

        return ValuationResult(
            currentValue: originalPrice * Decimal(adjustedValue),
            marketValue: originalPrice * Decimal(adjustedValue),
            depreciationRate: standardDepreciationRate,
            confidence: 0.8
        )
    }

    private func marketComparisonMethod(originalPrice: Decimal, marketData: MarketData?, factors: [ValuationFactor]) -> ValuationResult {
        guard let marketData = marketData else {
            return depreciationMethod(originalPrice: originalPrice, factors: factors, usageMetrics: UsageMetrics(ageInMonths: 0, usageFrequency: .moderate, maintenanceHistory: MaintenanceHistory(regularMaintenance: false, lastMaintenanceDate: nil, maintenanceFrequency: 0, maintenanceQuality: .average), repairHistory: RepairHistory(totalRepairs: 0, majorRepairs: 0, totalRepairCost: 0, lastRepairDate: nil, repairFrequency: 0), upgradeHistory: [], performanceMetrics: nil))
        }

        let marketValue = marketData.averagePrice
        let factorAdjustment = factors.reduce(0) { $0 + $1.adjustedImpact }
        let adjustedValue = marketValue * Decimal(1.0 + factorAdjustment)

        return ValuationResult(
            currentValue: max(originalPrice * 0.1, adjustedValue),
            marketValue: marketValue,
            depreciationRate: Double(truncating: ((originalPrice - adjustedValue) / originalPrice) as NSNumber),
            confidence: marketData.reliability
        )
    }

    private func costApproachMethod(originalPrice: Decimal, condition: ProductCondition, factors: [ValuationFactor]) -> ValuationResult {
        let conditionMultiplier = condition.multiplier
        let factorAdjustment = factors.reduce(0) { $0 + $1.adjustedImpact }
        let adjustedValue = originalPrice * Decimal(conditionMultiplier + factorAdjustment)

        return ValuationResult(
            currentValue: max(originalPrice * 0.1, adjustedValue),
            marketValue: adjustedValue,
            depreciationRate: 1.0 - (conditionMultiplier + factorAdjustment),
            confidence: 0.75
        )
    }

    private func hybridMethod(originalPrice: Decimal, marketData: MarketData?, condition: ProductCondition, factors: [ValuationFactor], usageMetrics: UsageMetrics) -> ValuationResult {
        // 综合多种方法
        let depreciationResult = depreciationMethod(originalPrice: originalPrice, factors: factors, usageMetrics: usageMetrics)
        let costResult = costApproachMethod(originalPrice: originalPrice, condition: condition, factors: factors)

        var results = [depreciationResult, costResult]
        var weights = [0.4, 0.4]

        if let marketData = marketData {
            let marketResult = marketComparisonMethod(originalPrice: originalPrice, marketData: marketData, factors: factors)
            results.append(marketResult)
            weights = [0.3, 0.3, 0.4]
        }

        let weightedValue = zip(results, weights).reduce(0) { total, pair in
            total + (pair.0.currentValue * Decimal(pair.1))
        }

        let averageConfidence = results.reduce(0) { $0 + $1.confidence } / Double(results.count)

        return ValuationResult(
            currentValue: weightedValue,
            marketValue: weightedValue,
            depreciationRate: Double(truncating: ((originalPrice - weightedValue) / originalPrice) as NSNumber),
            confidence: averageConfidence
        )
    }

    private func incomeApproachMethod(originalPrice: Decimal, factors: [ValuationFactor]) -> ValuationResult {
        // 简化的收益法，适用于可能产生收益的产品
        let factorAdjustment = factors.reduce(0) { $0 + $1.adjustedImpact }
        let adjustedValue = originalPrice * Decimal(0.8 + factorAdjustment)

        return ValuationResult(
            currentValue: max(originalPrice * 0.1, adjustedValue),
            marketValue: adjustedValue,
            depreciationRate: 0.2 - factorAdjustment,
            confidence: 0.6
        )
    }

    private func generateRecommendations(valuation: ProductValuation, factors: [ValuationFactor]) -> [ValuationRecommendation] {
        var recommendations: [ValuationRecommendation] = []

        // 基于价值趋势生成建议
        switch valuation.valueTrend {
        case .appreciating:
            recommendations.append(ValuationRecommendation(
                id: UUID(),
                type: .hold,
                title: "建议持有",
                description: "产品价值呈上升趋势，建议继续持有",
                priority: .medium,
                potentialImpact: valuation.currentValue * 0.1,
                actionRequired: false
            ))
        case .rapidDepreciation:
            recommendations.append(ValuationRecommendation(
                id: UUID(),
                type: .sell,
                title: "考虑出售",
                description: "产品价值快速下降，建议考虑出售",
                priority: .high,
                potentialImpact: valuation.currentValue * 0.2,
                actionRequired: true
            ))
        default:
            break
        }

        // 基于状况生成建议
        if valuation.condition == .poor || valuation.condition == .damaged {
            recommendations.append(ValuationRecommendation(
                id: UUID(),
                type: .repair,
                title: "维修建议",
                description: "产品状况较差，建议进行维修以提升价值",
                priority: .high,
                potentialImpact: valuation.originalPrice * 0.15,
                actionRequired: true
            ))
        }

        // 基于保修状态生成建议
        if valuation.currentValue > 1000 && valuation.condition != .poor {
            recommendations.append(ValuationRecommendation(
                id: UUID(),
                type: .insure,
                title: "保险建议",
                description: "产品价值较高，建议购买保险保护",
                priority: .medium,
                potentialImpact: valuation.currentValue * 0.05,
                actionRequired: false
            ))
        }

        return recommendations
    }
}

// MARK: - 辅助数据结构
private struct ProductInfo {
    let id: UUID
    let name: String
    let brand: String
    let model: String
    let category: String
    let purchaseDate: Date?
    let originalPrice: Decimal
    let age: Double
}

private struct ValuationResult {
    let currentValue: Decimal
    let marketValue: Decimal
    let depreciationRate: Double
    let confidence: Double
}
