//
//  ProductUsageAnalysisService.swift
//  ManualBox
//
//  Created by Assistant on 2025/6/24.
//

import Foundation
import CoreData
import Combine

// MARK: - 产品使用分析服务
@MainActor
class ProductUsageAnalysisService: ObservableObject {
    static let shared = ProductUsageAnalysisService()
    
    @Published var currentAnalysis: ProductUsageAnalysis?
    @Published var isLoading = false
    @Published var lastUpdateTime: Date?
    
    private let context: NSManagedObjectContext
    private var cancellables = Set<AnyCancellable>()
    
    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.context = context
        setupAutoRefresh()
    }
    
    // MARK: - 主要分析方法
    
    /// 刷新产品使用分析
    func refreshAnalysis() async {
        isLoading = true
        
        do {
            let analysis = try await calculateProductUsageAnalysis()
            
            await MainActor.run {
                self.currentAnalysis = analysis
                self.lastUpdateTime = Date()
                self.isLoading = false
            }
            
            print("✅ 产品使用分析刷新完成")
        } catch {
            await MainActor.run {
                self.isLoading = false
            }
            print("❌ 产品使用分析刷新失败: \(error)")
        }
    }
    
    /// 获取特定产品的使用分析
    func getProductUsageMetric(for productId: UUID) async throws -> ProductUsageMetric? {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let request: NSFetchRequest<Product> = Product.fetchRequest()
                    request.predicate = NSPredicate(format: "id == %@", productId as CVarArg)
                    
                    guard let product = try self.context.fetch(request).first else {
                        continuation.resume(returning: nil)
                        return
                    }
                    
                    let metric = self.calculateProductUsageMetric(for: product)
                    continuation.resume(returning: metric)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// 获取分类使用排名
    func getCategoryUsageRanking() async throws -> [CategoryUsageMetric] {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let categoryRequest: NSFetchRequest<Category> = Category.fetchRequest()
                    let categories = try self.context.fetch(categoryRequest)
                    
                    var metrics: [CategoryUsageMetric] = []
                    
                    for category in categories {
                        let metric = self.calculateCategoryUsageMetric(for: category)
                        metrics.append(metric)
                    }
                    
                    // 按使用频率排序
                    metrics.sort { $0.averageUsageFrequency > $1.averageUsageFrequency }
                    
                    continuation.resume(returning: metrics)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - 私有计算方法
    
    private func calculateProductUsageAnalysis() async throws -> ProductUsageAnalysis {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let usageFrequency = try self.calculateUsageFrequencyAnalysis()
                    let maintenanceTrends = try self.calculateMaintenanceTrendAnalysis()
                    let costAnalysis = try self.calculateProductCostAnalysis()
                    let categoryUsage = try self.calculateCategoryUsageAnalysis()
                    let ageAnalysis = try self.calculateProductAgeAnalysis()
                    let performanceMetrics = try self.calculateUsagePerformanceMetrics()
                    
                    let analysis = ProductUsageAnalysis(
                        usageFrequency: usageFrequency,
                        maintenanceTrends: maintenanceTrends,
                        costAnalysis: costAnalysis,
                        categoryUsage: categoryUsage,
                        ageAnalysis: ageAnalysis,
                        performanceMetrics: performanceMetrics,
                        lastUpdated: Date()
                    )
                    
                    continuation.resume(returning: analysis)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func calculateUsageFrequencyAnalysis() throws -> UsageFrequencyAnalysis {
        let productRequest: NSFetchRequest<Product> = Product.fetchRequest()
        let products = try context.fetch(productRequest)
        
        var highFrequency: [ProductUsageMetric] = []
        var mediumFrequency: [ProductUsageMetric] = []
        var lowFrequency: [ProductUsageMetric] = []
        var unused: [ProductUsageMetric] = []
        var totalUsageFrequency: Double = 0
        var usageDistribution: [UsageFrequencyLevel: Int] = [:]
        
        for product in products {
            let metric = calculateProductUsageMetric(for: product)
            totalUsageFrequency += metric.usageFrequency
            
            switch metric.usageLevel {
            case .high:
                highFrequency.append(metric)
                usageDistribution[.high] = (usageDistribution[.high] ?? 0) + 1
            case .medium:
                mediumFrequency.append(metric)
                usageDistribution[.medium] = (usageDistribution[.medium] ?? 0) + 1
            case .low:
                lowFrequency.append(metric)
                usageDistribution[.low] = (usageDistribution[.low] ?? 0) + 1
            case .unused:
                unused.append(metric)
                usageDistribution[.unused] = (usageDistribution[.unused] ?? 0) + 1
            }
        }
        
        let averageUsageFrequency = products.isEmpty ? 0 : totalUsageFrequency / Double(products.count)
        
        return UsageFrequencyAnalysis(
            highFrequencyProducts: highFrequency.sorted { $0.usageFrequency > $1.usageFrequency },
            mediumFrequencyProducts: mediumFrequency.sorted { $0.usageFrequency > $1.usageFrequency },
            lowFrequencyProducts: lowFrequency.sorted { $0.usageFrequency > $1.usageFrequency },
            unusedProducts: unused.sorted { $0.productName < $1.productName },
            averageUsageFrequency: averageUsageFrequency,
            usageDistribution: usageDistribution
        )
    }
    
    private func calculateProductUsageMetric(for product: Product) -> ProductUsageMetric {
        // 基于产品的各种活动计算使用频率
        let now = Date()
        let createdDate = product.createdAt ?? now
        let daysSinceCreation = now.timeIntervalSince(createdDate) / (24 * 60 * 60)
        
        // 计算使用指标
        var usageScore: Double = 0
        var lastUsedDate: Date?
        var totalUsageTime: TimeInterval = 0
        
        // 基于说明书访问频率
        let manuals = product.productManuals
        if !manuals.isEmpty {
            usageScore += 0.3 // 有说明书加分
            // 这里可以添加说明书访问记录的分析
        }
        
        // 基于维修记录
        if let order = product.order {
            let repairRecords = order.repairRecords?.allObjects as? [RepairRecord] ?? []
            if !repairRecords.isEmpty {
                usageScore += 0.2 // 有维修记录说明在使用
                lastUsedDate = repairRecords.compactMap { $0.date }.max()
                
                // 维修频率影响使用分数
                let repairFrequency = Double(repairRecords.count) / max(daysSinceCreation / 365, 1)
                usageScore += min(repairFrequency * 0.1, 0.3)
            }
        }
        
        // 基于产品年龄调整分数
        let ageInMonths = daysSinceCreation / 30
        if ageInMonths < 3 {
            usageScore += 0.2 // 新产品可能使用频率高
        } else if ageInMonths > 36 {
            usageScore *= 0.8 // 老产品可能使用频率降低
        }
        
        // 基于分类调整分数（某些分类的产品使用频率可能更高）
        if let categoryName = product.category?.categoryName {
            switch categoryName {
            case "电子产品", "家用电器":
                usageScore += 0.1
            case "厨房用品":
                usageScore += 0.15
            case "运动器材":
                usageScore += 0.05
            default:
                break
            }
        }
        
        // 确保分数在0-1范围内
        usageScore = min(max(usageScore, 0), 1)
        
        return ProductUsageMetric(
            productId: product.id ?? UUID(),
            productName: product.productName,
            categoryName: product.category?.categoryName,
            usageFrequency: usageScore,
            lastUsedDate: lastUsedDate ?? product.updatedAt,
            totalUsageTime: totalUsageTime,
            usageScore: usageScore
        )
    }
    
    private func calculateMaintenanceTrendAnalysis() throws -> MaintenanceTrendAnalysis {
        let repairRequest: NSFetchRequest<RepairRecord> = RepairRecord.fetchRequest()
        let repairRecords = try context.fetch(repairRequest)

        var monthlyCount: [String: Int] = [:]
        var categoryMetrics: [String: (count: Int, totalCost: Decimal)] = [:]
        var totalMaintenanceFrequency: Double = 0

        let calendar = Calendar.current
        let now = Date()
        let oneYearAgo = calendar.date(byAdding: .year, value: -1, to: now) ?? now

        for record in repairRecords {
            guard let date = record.date, date >= oneYearAgo else { continue }

            let monthKey = DateFormatter.monthYear.string(from: date)
            monthlyCount[monthKey] = (monthlyCount[monthKey] ?? 0) + 1

            // 分类维修统计
            if let categoryName = record.order?.product?.category?.categoryName {
                let current = categoryMetrics[categoryName] ?? (count: 0, totalCost: 0)
                categoryMetrics[categoryName] = (
                    count: current.count + 1,
                    totalCost: current.totalCost + (record.cost ?? 0)
                )
            }
        }

        // 计算平均维修频率
        let productRequest: NSFetchRequest<Product> = Product.fetchRequest()
        let totalProducts = try context.count(for: productRequest)
        totalMaintenanceFrequency = totalProducts > 0 ? Double(repairRecords.count) / Double(totalProducts) : 0

        // 构建分类维修指标
        let topCategories = categoryMetrics.map { (key, value) in
            CategoryMaintenanceMetric(
                categoryName: key,
                maintenanceCount: value.count,
                averageCost: value.count > 0 ? value.totalCost / Decimal(value.count) : 0,
                frequency: Double(value.count),
                trend: .stable // 简化处理，实际可以计算趋势
            )
        }.sorted { $0.maintenanceCount > $1.maintenanceCount }

        return MaintenanceTrendAnalysis(
            monthlyMaintenanceCount: monthlyCount,
            averageMaintenanceFrequency: totalMaintenanceFrequency,
            maintenanceCostTrend: .stable, // 简化处理
            topMaintenanceCategories: Array(topCategories.prefix(5)),
            seasonalPatterns: [:], // 可以后续添加季节性分析
            predictedMaintenanceNeeds: [] // 可以后续添加预测功能
        )
    }

    private func calculateProductCostAnalysis() throws -> ProductCostAnalysis {
        let orderRequest: NSFetchRequest<Order> = Order.fetchRequest()
        let orders = try context.fetch(orderRequest)

        let repairRequest: NSFetchRequest<RepairRecord> = RepairRecord.fetchRequest()
        let repairRecords = try context.fetch(repairRequest)

        var totalOwnershipCost: Decimal = 0
        var costPerCategory: [String: Decimal] = [:]
        var depreciationAnalysis: [ProductDepreciation] = []
        var costEfficiencyRanking: [ProductCostEfficiency] = []

        var totalMaintenanceCost: Decimal = 0
        var totalPurchaseCost: Decimal = 0

        for order in orders {
            let purchaseCost = order.price
            totalPurchaseCost += Decimal(truncating: purchaseCost ?? 0)
            totalOwnershipCost += Decimal(truncating: purchaseCost ?? 0)

            // 分类成本统计
            if let categoryName = order.product?.category?.categoryName {
                costPerCategory[categoryName] = (costPerCategory[categoryName] ?? 0) + Decimal(truncating: purchaseCost ?? 0)
            }

            // 维修成本
            let orderRepairs = repairRecords.filter { $0.order == order }
            let maintenanceCost = orderRepairs.reduce(Decimal(0)) { $0 + ($1.cost ?? 0) }
            totalMaintenanceCost += maintenanceCost
            totalOwnershipCost += maintenanceCost

            // 折旧分析
            if let product = order.product {
                let depreciation = calculateProductDepreciation(product: product, order: order, maintenanceCost: maintenanceCost)
                depreciationAnalysis.append(depreciation)

                // 成本效率分析
                let efficiency = calculateProductCostEfficiency(product: product, order: order, maintenanceCost: maintenanceCost)
                costEfficiencyRanking.append(efficiency)
            }
        }

        // 排序成本效率
        costEfficiencyRanking.sort { $0.efficiencyScore > $1.efficiencyScore }
        for (index, _) in costEfficiencyRanking.enumerated() {
            costEfficiencyRanking[index] = ProductCostEfficiency(
                productId: costEfficiencyRanking[index].productId,
                productName: costEfficiencyRanking[index].productName,
                costPerUsage: costEfficiencyRanking[index].costPerUsage,
                efficiencyScore: costEfficiencyRanking[index].efficiencyScore,
                ranking: index + 1
            )
        }

        let maintenanceCostRatio = totalOwnershipCost > 0 ? Double(truncating: totalMaintenanceCost as NSNumber) / Double(truncating: totalOwnershipCost as NSNumber) : 0
        let averageUsageCost = orders.isEmpty ? 0 : Double(truncating: totalOwnershipCost as NSNumber) / Double(orders.count) / 12 // 月均成本

        return ProductCostAnalysis(
            totalOwnershipCost: totalOwnershipCost,
            averageUsageCost: averageUsageCost,
            costPerCategory: costPerCategory,
            maintenanceCostRatio: maintenanceCostRatio,
            depreciationAnalysis: depreciationAnalysis,
            costEfficiencyRanking: costEfficiencyRanking
        )
    }

    private func calculateCategoryUsageAnalysis() throws -> CategoryUsageAnalysis {
        let categoryRequest: NSFetchRequest<Category> = Category.fetchRequest()
        let categories = try context.fetch(categoryRequest)

        var categoryMetrics: [CategoryUsageMetric] = []
        var categoryGrowthRates: [String: Double] = [:]
        var usageDistribution: [String: Double] = [:]
        var totalUsageTime: TimeInterval = 0

        for category in categories {
            let metric = calculateCategoryUsageMetric(for: category)
            categoryMetrics.append(metric)
            totalUsageTime += metric.totalUsageTime

            // 简化的增长率计算
            categoryGrowthRates[metric.categoryName] = metric.growthRate
        }

        // 计算使用分布
        for metric in categoryMetrics {
            if totalUsageTime > 0 {
                usageDistribution[metric.categoryName] = metric.totalUsageTime / totalUsageTime
            }
        }

        // 排序并找出最活跃和最不活跃的分类
        categoryMetrics.sort { $0.averageUsageFrequency > $1.averageUsageFrequency }

        return CategoryUsageAnalysis(
            categoryMetrics: categoryMetrics,
            mostActiveCategory: categoryMetrics.first?.categoryName,
            leastActiveCategory: categoryMetrics.last?.categoryName,
            categoryGrowthRates: categoryGrowthRates,
            usageDistribution: usageDistribution
        )
    }

    private func calculateCategoryUsageMetric(for category: Category) -> CategoryUsageMetric {
        let products = category.categoryProducts
        let productCount = products.count

        var totalUsageTime: TimeInterval = 0
        var totalUsageFrequency: Double = 0

        for product in products {
            let metric = calculateProductUsageMetric(for: product)
            totalUsageTime += metric.totalUsageTime
            totalUsageFrequency += metric.usageFrequency
        }

        let averageUsageFrequency = productCount > 0 ? totalUsageFrequency / Double(productCount) : 0

        // 简化的增长率计算（基于最近添加的产品数量）
        let now = Date()
        let threeMonthsAgo = Calendar.current.date(byAdding: .month, value: -3, to: now) ?? now
        let recentProducts = products.filter { ($0.createdAt ?? Date.distantPast) >= threeMonthsAgo }
        let growthRate = productCount > 0 ? Double(recentProducts.count) / Double(productCount) : 0

        return CategoryUsageMetric(
            categoryName: category.categoryName,
            productCount: productCount,
            totalUsageTime: totalUsageTime,
            averageUsageFrequency: averageUsageFrequency,
            growthRate: growthRate
        )
    }

    private func calculateProductAgeAnalysis() throws -> ProductAgeAnalysis {
        let productRequest: NSFetchRequest<Product> = Product.fetchRequest()
        let products = try context.fetch(productRequest)

        var ageDistribution: [AgeGroup: Int] = [:]
        var totalAge: TimeInterval = 0
        var validProducts = 0
        var oldestProduct: ProductAgeMetric?
        var newestProduct: ProductAgeMetric?

        let now = Date()

        for product in products {
            guard let createdDate = product.createdAt else { continue }

            let age = now.timeIntervalSince(createdDate)
            totalAge += age
            validProducts += 1

            let ageInMonths = Int(age / (30 * 24 * 60 * 60))
            let ageGroup = AgeGroup.allCases.first { $0.monthsRange.contains(ageInMonths) } ?? .old

            ageDistribution[ageGroup] = (ageDistribution[ageGroup] ?? 0) + 1

            let ageMetric = ProductAgeMetric(
                productId: product.id ?? UUID(),
                productName: product.productName,
                age: age,
                purchaseDate: product.order?.orderDate,
                ageGroup: ageGroup
            )

            if oldestProduct == nil || age > oldestProduct!.age {
                oldestProduct = ageMetric
            }

            if newestProduct == nil || age < newestProduct!.age {
                newestProduct = ageMetric
            }
        }

        let averageAge = validProducts > 0 ? totalAge / Double(validProducts) : 0

        // 简化的年龄与维修相关性分析
        let ageBasedMaintenanceCorrelation = calculateAgeMaintenanceCorrelation()

        return ProductAgeAnalysis(
            ageDistribution: ageDistribution,
            averageAge: averageAge,
            oldestProduct: oldestProduct,
            newestProduct: newestProduct,
            ageBasedMaintenanceCorrelation: ageBasedMaintenanceCorrelation
        )
    }

    private func calculateUsagePerformanceMetrics() throws -> UsagePerformanceMetrics {
        let productRequest: NSFetchRequest<Product> = Product.fetchRequest()
        let totalProducts = try context.count(for: productRequest)

        // 数据收集准确性（基于有完整信息的产品比例）
        let completeProductsRequest: NSFetchRequest<Product> = Product.fetchRequest()
        completeProductsRequest.predicate = NSPredicate(format: "name != nil AND createdAt != nil")
        let completeProducts = try context.count(for: completeProductsRequest)

        let dataCollectionAccuracy = totalProducts > 0 ? Double(completeProducts) / Double(totalProducts) : 0

        // 跟踪覆盖率（基于有订单信息的产品比例）
        let trackedProductsRequest: NSFetchRequest<Product> = Product.fetchRequest()
        trackedProductsRequest.predicate = NSPredicate(format: "order != nil")
        let trackedProducts = try context.count(for: trackedProductsRequest)

        let trackingCoverage = totalProducts > 0 ? Double(trackedProducts) / Double(totalProducts) : 0

        // 分析置信度（基于数据完整性）
        let analysisConfidenceLevel = (dataCollectionAccuracy + trackingCoverage) / 2

        // 缺失数据点
        let missingDataPoints = totalProducts - completeProducts

        return UsagePerformanceMetrics(
            dataCollectionAccuracy: dataCollectionAccuracy,
            trackingCoverage: trackingCoverage,
            analysisConfidenceLevel: analysisConfidenceLevel,
            lastDataUpdate: Date(),
            missingDataPoints: missingDataPoints
        )
    }

    // MARK: - 辅助计算方法

    private func calculateProductDepreciation(product: Product, order: Order, maintenanceCost: Decimal) -> ProductDepreciation {
        let originalCost = order.price
        let now = Date()
        let purchaseDate = order.orderDate ?? now
        let ageInYears = now.timeIntervalSince(purchaseDate) / (365 * 24 * 60 * 60)

        // 简化的折旧计算（年折旧率20%）
        let depreciationRate = min(ageInYears * 0.2, 0.8) // 最大折旧80%
        let currentValue = Decimal(truncating: originalCost ?? 0) * Decimal(1 - depreciationRate)
        let totalCostOfOwnership = Decimal(truncating: originalCost ?? 0) + Decimal(truncating: maintenanceCost ?? 0)

        return ProductDepreciation(
            productId: product.id ?? UUID(),
            productName: product.productName,
            originalCost: Decimal(truncating: originalCost ?? 0),
            currentValue: max(currentValue, Decimal(truncating: originalCost ?? 0) * 0.1), // 最低保留10%价值
            maintenanceCost: Decimal(truncating: maintenanceCost ?? 0),
            depreciationRate: depreciationRate,
            totalCostOfOwnership: totalCostOfOwnership
        )
    }

    private func calculateProductCostEfficiency(product: Product, order: Order, maintenanceCost: Decimal) -> ProductCostEfficiency {
        let totalCost = Decimal(truncating: order.price ?? 0) + Decimal(truncating: maintenanceCost ?? 0)
        let usageMetric = calculateProductUsageMetric(for: product)

        // 基于使用频率计算成本效率
        let costPerUsage = usageMetric.usageFrequency > 0 ? totalCost / Decimal(usageMetric.usageFrequency) : totalCost

        // 效率分数（使用频率高且成本低的产品效率高）
        let costScore = Double(truncating: (1000 / max(costPerUsage, 1)) as NSNumber) // 成本越低分数越高
        let usageScore = usageMetric.usageFrequency * 100 // 使用频率分数
        let efficiencyScore = (costScore + usageScore) / 2

        return ProductCostEfficiency(
            productId: product.id ?? UUID(),
            productName: product.productName,
            costPerUsage: costPerUsage,
            efficiencyScore: efficiencyScore,
            ranking: 0 // 将在外部设置
        )
    }

    private func calculateAgeMaintenanceCorrelation() -> Double {
        // 简化的相关性计算
        // 实际实现中可以使用更复杂的统计方法
        return 0.65 // 假设有中等程度的正相关
    }

    // MARK: - 自动刷新设置

    private func setupAutoRefresh() {
        // 每10分钟自动刷新一次
        Timer.publish(every: 600, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task {
                    await self?.refreshAnalysis()
                }
            }
            .store(in: &cancellables)
    }
}
