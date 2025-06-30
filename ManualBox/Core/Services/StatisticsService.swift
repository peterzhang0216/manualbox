//
//  StatisticsService.swift
//  ManualBox
//
//  Created by Assistant on 2025/6/24.
//

import Foundation
import CoreData
import Combine

// MARK: - 统计服务
@MainActor
class StatisticsService: ObservableObject {
    static let shared = StatisticsService()
    
    @Published var dashboardStats: DashboardStatistics?
    @Published var isLoading = false
    @Published var lastUpdateTime: Date?
    
    private let context: NSManagedObjectContext
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        self.context = PersistenceController.shared.container.viewContext
        setupAutoRefresh()
    }
    
    // MARK: - 主要统计方法
    
    /// 刷新所有统计数据
    func refreshStatistics() async {
        isLoading = true
        
        do {
            let stats = try await calculateDashboardStatistics()
            
            await MainActor.run {
                self.dashboardStats = stats
                self.lastUpdateTime = Date()
                self.isLoading = false
            }
            
            print("✅ 统计数据刷新完成")
        } catch {
            await MainActor.run {
                self.isLoading = false
            }
            print("❌ 统计数据刷新失败: \(error)")
        }
    }
    
    /// 计算仪表板统计数据
    private func calculateDashboardStatistics() async throws -> DashboardStatistics {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    // 产品统计
                    let productStats = try self.calculateProductStatistics()
                    
                    // 保修统计
                    let warrantyStats = try self.calculateWarrantyStatistics()
                    
                    // 费用统计
                    let costStats = try self.calculateCostStatistics()
                    
                    // 使用统计
                    let usageStats = try self.calculateUsageStatistics()
                    
                    // 分类统计
                    let categoryStats = try self.calculateCategoryStatistics()
                    
                    // 趋势统计
                    let trendStats = try self.calculateTrendStatistics()
                    
                    let dashboardStats = DashboardStatistics(
                        productStats: productStats,
                        warrantyStats: warrantyStats,
                        costStats: costStats,
                        usageStats: usageStats,
                        categoryStats: categoryStats,
                        trendStats: trendStats,
                        lastUpdated: Date()
                    )
                    
                    continuation.resume(returning: dashboardStats)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - 具体统计计算
    
    private func calculateProductStatistics() throws -> ProductStatistics {
        let productRequest: NSFetchRequest<Product> = Product.fetchRequest()
        let totalProducts = try context.count(for: productRequest)
        
        // 按分类统计
        let categoryRequest: NSFetchRequest<Category> = Category.fetchRequest()
        let categories = try context.fetch(categoryRequest)
        
        var productsByCategory: [String: Int] = [:]
        for category in categories {
            let categoryProductRequest: NSFetchRequest<Product> = Product.fetchRequest()
            categoryProductRequest.predicate = NSPredicate(format: "category == %@", category)
            let count = try context.count(for: categoryProductRequest)
            productsByCategory[category.name ?? "未知"] = count
        }
        
        // 最近添加的产品
        let recentRequest: NSFetchRequest<Product> = Product.fetchRequest()
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        recentRequest.predicate = NSPredicate(format: "createdAt >= %@", thirtyDaysAgo as CVarArg)
        let recentlyAdded = try context.count(for: recentRequest)
        
        // 有说明书的产品
        let withManualsRequest: NSFetchRequest<Product> = Product.fetchRequest()
        withManualsRequest.predicate = NSPredicate(format: "manuals.@count > 0")
        let withManuals = try context.count(for: withManualsRequest)
        
        return ProductStatistics(
            totalProducts: totalProducts,
            productsByCategory: productsByCategory,
            recentlyAdded: recentlyAdded,
            withManuals: withManuals,
            withoutManuals: totalProducts - withManuals
        )
    }
    
    private func calculateWarrantyStatistics() throws -> WarrantyStatistics {
        let orderRequest: NSFetchRequest<Order> = Order.fetchRequest()
        let orders = try context.fetch(orderRequest)
        
        var activeWarranties = 0
        var expiringSoon = 0
        var expired = 0
        var totalWarrantyValue: Decimal = 0
        
        let now = Date()
        let thirtyDaysFromNow = Calendar.current.date(byAdding: .day, value: 30, to: now) ?? now
        
        for order in orders {
            guard let warrantyEndDate = order.warrantyEndDate else { continue }
            
            if warrantyEndDate > now {
                activeWarranties += 1
                if warrantyEndDate <= thirtyDaysFromNow {
                    expiringSoon += 1
                }
            } else {
                expired += 1
            }
            
            if let price = order.price {
                totalWarrantyValue += price as Decimal
            }
        }
        
        return WarrantyStatistics(
            activeWarranties: activeWarranties,
            expiringSoon: expiringSoon,
            expired: expired,
            totalWarrantyValue: totalWarrantyValue
        )
    }
    
    private func calculateCostStatistics() throws -> CostStatistics {
        let orderRequest: NSFetchRequest<Order> = Order.fetchRequest()
        let orders = try context.fetch(orderRequest)
        
        let repairRecordRequest: NSFetchRequest<RepairRecord> = RepairRecord.fetchRequest()
        let repairRecords = try context.fetch(repairRecordRequest)
        
        var totalPurchaseCost: Decimal = 0
        var totalMaintenanceCost: Decimal = 0
        var monthlySpending: [String: Decimal] = [:]
        
        // 计算购买成本
        for order in orders {
            if let price = order.price {
                totalPurchaseCost += price as Decimal
            }

            if let orderDate = order.orderDate {
                let monthKey = DateFormatter.monthYear.string(from: orderDate)
                let priceDecimal = (order.price as? Decimal) ?? 0
                monthlySpending[monthKey] = (monthlySpending[monthKey] ?? 0) + priceDecimal
            }
        }
        
        // 计算维护成本
        for record in repairRecords {
            if let cost = record.cost {
                totalMaintenanceCost += cost as Decimal
            }

            if let repairDate = record.date {
                let monthKey = DateFormatter.monthYear.string(from: repairDate)
                let costDecimal = (record.cost as? Decimal) ?? 0
                monthlySpending[monthKey] = (monthlySpending[monthKey] ?? 0) + costDecimal
            }
        }
        
        return CostStatistics(
            totalPurchaseCost: totalPurchaseCost,
            totalMaintenanceCost: totalMaintenanceCost,
            totalCost: totalPurchaseCost + totalMaintenanceCost,
            monthlySpending: monthlySpending,
            averageProductCost: orders.isEmpty ? 0 : totalPurchaseCost / Decimal(orders.count)
        )
    }
    
    private func calculateUsageStatistics() throws -> UsageStatistics {
        let productRequest: NSFetchRequest<Product> = Product.fetchRequest()
        let products = try context.fetch(productRequest)
        
        let manualRequest: NSFetchRequest<Manual> = Manual.fetchRequest()
        manualRequest.predicate = NSPredicate(format: "isOCRProcessed == YES")
        let processedManuals = try context.count(for: manualRequest)
        
        let totalManuals = try context.count(for: Manual.fetchRequest())
        
        // 计算平均产品年龄
        var totalAge: TimeInterval = 0
        var validProducts = 0
        let now = Date()
        
        for product in products {
            if let createdDate = product.createdAt {
                totalAge += now.timeIntervalSince(createdDate)
                validProducts += 1
            }
        }
        
        let averageAge = validProducts > 0 ? totalAge / Double(validProducts) : 0
        
        return UsageStatistics(
            totalManuals: totalManuals,
            processedManuals: processedManuals,
            ocrProcessingRate: totalManuals > 0 ? Double(processedManuals) / Double(totalManuals) : 0,
            averageProductAge: averageAge,
            mostUsedCategories: calculateMostUsedCategories()
        )
    }
    
    private func calculateCategoryStatistics() throws -> [CategoryStatistic] {
        let categoryRequest: NSFetchRequest<Category> = Category.fetchRequest()
        let categories = try context.fetch(categoryRequest)
        
        var categoryStats: [CategoryStatistic] = []
        
        for category in categories {
            let productRequest: NSFetchRequest<Product> = Product.fetchRequest()
            productRequest.predicate = NSPredicate(format: "category == %@", category)
            let productCount = try context.count(for: productRequest)
            
            // 计算该分类的总价值
            let products = try context.fetch(productRequest)
            var totalValue: Decimal = 0
            
            for product in products {
                if let order = product.order,
                   let price = order.price {
                    totalValue += price as Decimal
                }
            }
            
            let stat = CategoryStatistic(
                name: category.name ?? "未知",
                productCount: productCount,
                totalValue: totalValue,
                iconName: category.categoryIcon
            )
            
            categoryStats.append(stat)
        }
        
        return categoryStats.sorted { $0.productCount > $1.productCount }
    }
    
    private func calculateTrendStatistics() throws -> TrendStatistics {
        let calendar = Calendar.current
        let now = Date()
        let sixMonthsAgo = calendar.date(byAdding: .month, value: -6, to: now) ?? now
        
        // 产品添加趋势
        let productRequest: NSFetchRequest<Product> = Product.fetchRequest()
        productRequest.predicate = NSPredicate(format: "createdAt >= %@", sixMonthsAgo as CVarArg)
        productRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Product.createdAt, ascending: true)]
        let recentProducts = try context.fetch(productRequest)
        
        var monthlyProductCounts: [String: Int] = [:]
        for product in recentProducts {
            if let createdDate = product.createdAt {
                let monthKey = DateFormatter.monthYear.string(from: createdDate)
                monthlyProductCounts[monthKey] = (monthlyProductCounts[monthKey] ?? 0) + 1
            }
        }
        
        // 维护趋势
        let repairRequest: NSFetchRequest<RepairRecord> = RepairRecord.fetchRequest()
        repairRequest.predicate = NSPredicate(format: "date >= %@", sixMonthsAgo as CVarArg)
        let recentRepairs = try context.fetch(repairRequest)

        var monthlyMaintenanceCounts: [String: Int] = [:]
        for record in recentRepairs {
            if let date = record.date {
                let monthKey = DateFormatter.monthYear.string(from: date)
                monthlyMaintenanceCounts[monthKey] = (monthlyMaintenanceCounts[monthKey] ?? 0) + 1
            }
        }
        
        return TrendStatistics(
            monthlyProductAdditions: monthlyProductCounts,
            monthlyMaintenanceRecords: monthlyMaintenanceCounts
        )
    }
    
    private func calculateMostUsedCategories() -> [String] {
        // 这里可以基于用户访问频率等数据计算
        // 暂时返回空数组，后续可以添加用户行为跟踪
        return []
    }
    
    // MARK: - 自动刷新设置
    
    private func setupAutoRefresh() {
        // 每5分钟自动刷新一次
        Timer.publish(every: 300, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task {
                    await self?.refreshStatistics()
                }
            }
            .store(in: &cancellables)
    }
}

// MARK: - DateFormatter 扩展
extension DateFormatter {
    static let monthYear: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter
    }()
}
