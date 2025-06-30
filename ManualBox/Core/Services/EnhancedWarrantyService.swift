//
//  EnhancedWarrantyService.swift
//  ManualBox
//
//  Created by Assistant on 2025/6/25.
//

import Foundation
import CoreData
import Combine
import UserNotifications
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

// MARK: - 增强保修管理服务
@MainActor
class EnhancedWarrantyService: ObservableObject {
    static let shared = EnhancedWarrantyService()
    
    @Published var extendedWarranties: [ExtendedWarrantyInfo] = []
    @Published var insuranceInfos: [InsuranceInfo] = []
    @Published var costPredictions: [CostPrediction] = []
    @Published var reminderConfigs: [WarrantyReminderConfig] = []
    @Published var statistics: EnhancedWarrantyStatistics?
    @Published var isLoading = false
    @Published var lastError: Error?
    
    private let context: NSManagedObjectContext
    private var cancellables = Set<AnyCancellable>()
    
    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.context = context
        loadData()
        setupNotificationObservers()
    }
    
    // MARK: - 数据加载
    
    private func loadData() {
        loadExtendedWarranties()
        loadInsuranceInfos()
        loadCostPredictions()
        loadReminderConfigs()
        updateStatistics()
    }
    
    private func loadExtendedWarranties() {
        // 从 UserDefaults 或其他持久化存储加载扩展保修信息
        if let data = UserDefaults.standard.data(forKey: "ExtendedWarranties"),
           let warranties = try? JSONDecoder().decode([ExtendedWarrantyInfo].self, from: data) {
            extendedWarranties = warranties
        }
    }
    
    private func loadInsuranceInfos() {
        // 从 UserDefaults 或其他持久化存储加载保险信息
        if let data = UserDefaults.standard.data(forKey: "InsuranceInfos"),
           let insurances = try? JSONDecoder().decode([InsuranceInfo].self, from: data) {
            insuranceInfos = insurances
        }
    }
    
    private func loadCostPredictions() {
        // 从 UserDefaults 或其他持久化存储加载费用预测
        if let data = UserDefaults.standard.data(forKey: "CostPredictions"),
           let predictions = try? JSONDecoder().decode([CostPrediction].self, from: data) {
            costPredictions = predictions
        }
    }
    
    private func loadReminderConfigs() {
        // 从 UserDefaults 或其他持久化存储加载提醒配置
        if let data = UserDefaults.standard.data(forKey: "ReminderConfigs"),
           let configs = try? JSONDecoder().decode([WarrantyReminderConfig].self, from: data) {
            reminderConfigs = configs
        }
    }
    
    // MARK: - 扩展保修管理
    
    func addExtendedWarranty(_ warranty: ExtendedWarrantyInfo) async {
        extendedWarranties.append(warranty)
        await saveExtendedWarranties()
        await scheduleWarrantyReminders(for: warranty)
        updateStatistics()
    }
    
    func updateExtendedWarranty(_ warranty: ExtendedWarrantyInfo) async {
        if let index = extendedWarranties.firstIndex(where: { $0.id == warranty.id }) {
            extendedWarranties[index] = warranty
            await saveExtendedWarranties()
            await scheduleWarrantyReminders(for: warranty)
            updateStatistics()
        }
    }
    
    func removeExtendedWarranty(_ warrantyId: UUID) async {
        extendedWarranties.removeAll { $0.id == warrantyId }
        await saveExtendedWarranties()
        await removeWarrantyReminders(for: warrantyId)
        updateStatistics()
    }
    
    private func saveExtendedWarranties() async {
        if let data = try? JSONEncoder().encode(extendedWarranties) {
            UserDefaults.standard.set(data, forKey: "ExtendedWarranties")
        }
    }
    
    // MARK: - 保险信息管理
    
    func addInsuranceInfo(_ insurance: InsuranceInfo) async {
        insuranceInfos.append(insurance)
        await saveInsuranceInfos()
        await scheduleInsuranceReminders(for: insurance)
        updateStatistics()
    }
    
    func updateInsuranceInfo(_ insurance: InsuranceInfo) async {
        if let index = insuranceInfos.firstIndex(where: { $0.id == insurance.id }) {
            insuranceInfos[index] = insurance
            await saveInsuranceInfos()
            await scheduleInsuranceReminders(for: insurance)
            updateStatistics()
        }
    }
    
    func removeInsuranceInfo(_ insuranceId: UUID) async {
        insuranceInfos.removeAll { $0.id == insuranceId }
        await saveInsuranceInfos()
        await removeInsuranceReminders(for: insuranceId)
        updateStatistics()
    }
    
    func addInsuranceClaim(_ claim: InsuranceClaim, to insuranceId: UUID) async {
        if let index = insuranceInfos.firstIndex(where: { $0.id == insuranceId }) {
            let insurance = insuranceInfos[index]
            var claims = insurance.claims
            claims.append(claim)
            
            let updatedInsurance = InsuranceInfo(
                id: insurance.id,
                productId: insurance.productId,
                policyNumber: insurance.policyNumber,
                provider: insurance.provider,
                type: insurance.type,
                coverage: insurance.coverage,
                premium: insurance.premium,
                deductible: insurance.deductible,
                startDate: insurance.startDate,
                endDate: insurance.endDate,
                beneficiary: insurance.beneficiary,
                contactInfo: insurance.contactInfo,
                documents: insurance.documents,
                claims: claims,
                renewalInfo: insurance.renewalInfo,
                createdAt: insurance.createdAt,
                updatedAt: Date()
            )
            
            insuranceInfos[index] = updatedInsurance
            await saveInsuranceInfos()
            updateStatistics()
        }
    }
    
    private func saveInsuranceInfos() async {
        if let data = try? JSONEncoder().encode(insuranceInfos) {
            UserDefaults.standard.set(data, forKey: "InsuranceInfos")
        }
    }
    
    // MARK: - 费用预测
    
    func generateCostPrediction(for productId: UUID, timeframe: PredictionTimeframe) async -> CostPrediction? {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // 获取产品信息
            guard let product = try await getProduct(by: productId) else {
                return nil
            }
            
            // 分析历史数据
            let historicalData = await analyzeHistoricalData(for: product)
            
            // 生成预测
            let prediction = await generatePrediction(
                for: product,
                timeframe: timeframe,
                historicalData: historicalData
            )
            
            // 保存预测结果
            costPredictions.append(prediction)
            await saveCostPredictions()
            
            return prediction
        } catch {
            lastError = error
            return nil
        }
    }
    
    private func getProduct(by id: UUID) async throws -> Product? {
        let request: NSFetchRequest<Product> = Product.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        
        return try context.fetch(request).first
    }
    
    private func analyzeHistoricalData(for product: Product) async -> HistoricalData {
        // 分析维修记录、保修使用情况等历史数据
        let repairRecords = product.order?.repairRecords?.allObjects as? [RepairRecord] ?? []
        let totalRepairCost = repairRecords.reduce(0) { $0 + ($1.cost?.decimalValue ?? 0) }
        let averageRepairCost = repairRecords.isEmpty ? 0 : totalRepairCost / Decimal(repairRecords.count)
        
        let productAge = product.order?.orderDate?.timeIntervalSinceNow ?? 0
        let ageInMonths = abs(productAge) / (30 * 24 * 60 * 60) // 转换为月
        
        return HistoricalData(
            totalRepairCost: totalRepairCost,
            averageRepairCost: averageRepairCost,
            repairFrequency: Double(repairRecords.count) / max(1, ageInMonths),
            productAge: ageInMonths,
            warrantyUsage: calculateWarrantyUsage(for: product)
        )
    }
    
    private func calculateWarrantyUsage(for product: Product) -> Double {
        // 计算保修使用率
        guard let order = product.order,
              let warrantyEndDate = order.warrantyEndDate,
              let orderDate = order.orderDate else {
            return 0.0
        }
        
        let totalWarrantyPeriod = warrantyEndDate.timeIntervalSince(orderDate)
        let usedWarrantyPeriod = Date().timeIntervalSince(orderDate)
        
        return min(1.0, usedWarrantyPeriod / totalWarrantyPeriod)
    }
    
    private func generatePrediction(
        for product: Product,
        timeframe: PredictionTimeframe,
        historicalData: HistoricalData
    ) async -> CostPrediction {
        var predictions: [CostPredictionItem] = []
        var factors: [PredictionFactor] = []
        var recommendations: [String] = []
        
        // 维修费用预测
        let repairPrediction = predictRepairCosts(
            historicalData: historicalData,
            timeframe: timeframe,
            product: product
        )
        predictions.append(repairPrediction.item)
        factors.append(contentsOf: repairPrediction.factors)
        
        // 维护费用预测
        let maintenancePrediction = predictMaintenanceCosts(
            product: product,
            timeframe: timeframe
        )
        predictions.append(maintenancePrediction.item)
        factors.append(contentsOf: maintenancePrediction.factors)
        
        // 保险费用预测
        if let insurancePrediction = predictInsuranceCosts(
            for: product.id ?? UUID(),
            timeframe: timeframe
        ) {
            predictions.append(insurancePrediction.item)
            factors.append(contentsOf: insurancePrediction.factors)
        }
        
        // 生成建议
        recommendations = generateRecommendations(
            based: predictions,
            factors: factors,
            product: product
        )
        
        return CostPrediction(
            productId: product.id ?? UUID(),
            predictionDate: Date(),
            timeframe: timeframe,
            predictions: predictions,
            confidence: calculateConfidence(factors: factors),
            factors: factors,
            recommendations: recommendations
        )
    }
    
    private func saveCostPredictions() async {
        if let data = try? JSONEncoder().encode(costPredictions) {
            UserDefaults.standard.set(data, forKey: "CostPredictions")
        }
    }

    // MARK: - 预测辅助方法

    private func predictRepairCosts(
        historicalData: HistoricalData,
        timeframe: PredictionTimeframe,
        product: Product
    ) -> (item: CostPredictionItem, factors: [PredictionFactor]) {
        let baseRepairCost = historicalData.averageRepairCost
        let frequencyMultiplier = historicalData.repairFrequency * Double(timeframe.months)
        let ageFactor = min(2.0, 1.0 + historicalData.productAge / 60.0) // 产品年龄影响

        let predictedCost = baseRepairCost * Decimal(frequencyMultiplier * ageFactor)

        let factors = [
            PredictionFactor(
                name: "历史维修频率",
                impact: historicalData.repairFrequency > 0.5 ? 0.8 : 0.3,
                description: "基于历史维修记录的频率分析"
            ),
            PredictionFactor(
                name: "产品年龄",
                impact: historicalData.productAge > 36 ? 0.7 : 0.2,
                description: "产品使用年限对维修成本的影响"
            )
        ]

        return (
            CostPredictionItem(
                category: .repair,
                predictedCost: predictedCost,
                probability: calculateRepairProbability(historicalData),
                description: "基于历史数据预测的维修费用"
            ),
            factors
        )
    }

    private func predictMaintenanceCosts(
        product: Product,
        timeframe: PredictionTimeframe
    ) -> (item: CostPredictionItem, factors: [PredictionFactor]) {
        // 基于产品类别和年龄预测维护费用
        let categoryMultiplier = getMaintenanceMultiplier(for: product.category?.categoryName ?? "其他")
        let baseCost = Decimal(100) // 基础维护费用
        let predictedCost = baseCost * Decimal(categoryMultiplier) * Decimal(timeframe.months) / 12

        let factors = [
            PredictionFactor(
                name: "产品类别",
                impact: categoryMultiplier > 1.5 ? 0.6 : 0.3,
                description: "不同产品类别的维护需求差异"
            )
        ]

        return (
            CostPredictionItem(
                category: .maintenance,
                predictedCost: predictedCost,
                probability: 0.8,
                description: "基于产品类别的定期维护费用"
            ),
            factors
        )
    }

    private func predictInsuranceCosts(
        for productId: UUID,
        timeframe: PredictionTimeframe
    ) -> (item: CostPredictionItem, factors: [PredictionFactor])? {
        guard let insurance = insuranceInfos.first(where: { $0.productId == productId }) else {
            return nil
        }

        let annualPremium = insurance.premium
        let predictedCost = annualPremium * Decimal(timeframe.months) / 12

        let factors = [
            PredictionFactor(
                name: "保险续费",
                impact: 0.9,
                description: "保险费用相对固定且必需"
            )
        ]

        return (
            CostPredictionItem(
                category: .insurance,
                predictedCost: predictedCost,
                probability: 0.95,
                description: "保险续费费用"
            ),
            factors
        )
    }

    private func calculateRepairProbability(_ historicalData: HistoricalData) -> Double {
        if historicalData.repairFrequency > 1.0 {
            return 0.9
        } else if historicalData.repairFrequency > 0.5 {
            return 0.7
        } else if historicalData.repairFrequency > 0.1 {
            return 0.4
        } else {
            return 0.2
        }
    }

    private func getMaintenanceMultiplier(for category: String) -> Double {
        switch category {
        case "电子产品":
            return 1.5
        case "家用电器":
            return 2.0
        case "汽车配件":
            return 2.5
        case "运动器材":
            return 1.2
        default:
            return 1.0
        }
    }

    private func generateRecommendations(
        based predictions: [CostPredictionItem],
        factors: [PredictionFactor],
        product: Product
    ) -> [String] {
        var recommendations: [String] = []

        let totalPredictedCost = predictions.reduce(0) { $0 + $1.predictedCost }

        if totalPredictedCost > 1000 {
            recommendations.append("建议考虑购买延长保修服务以降低维修风险")
        }

        if let repairPrediction = predictions.first(where: { $0.category == .repair }),
           repairPrediction.probability > 0.7 {
            recommendations.append("建议定期进行预防性维护以减少故障发生")
        }

        if factors.contains(where: { $0.name == "产品年龄" && $0.impact > 0.6 }) {
            recommendations.append("产品已使用较长时间，建议考虑更换新产品")
        }

        return recommendations
    }

    private func calculateConfidence(factors: [PredictionFactor]) -> Double {
        let averageImpact = factors.reduce(0) { $0 + abs($1.impact) } / Double(factors.count)
        return min(0.95, 0.5 + averageImpact * 0.4)
    }

    // MARK: - 提醒管理

    func configureReminders(for productId: UUID, config: WarrantyReminderConfig) async {
        // 移除现有配置
        reminderConfigs.removeAll { $0.productId == productId }

        // 添加新配置
        reminderConfigs.append(config)
        await saveReminderConfigs()

        // 重新安排提醒
        await rescheduleReminders(for: productId)
    }

    private func scheduleWarrantyReminders(for warranty: ExtendedWarrantyInfo) async {
        guard let config = reminderConfigs.first(where: { $0.productId == warranty.productId }),
              config.isEnabled,
              config.reminderTypes.contains(.warranty) else {
            return
        }

        let reminderDays = config.customDays.isEmpty ? ReminderType.warranty.defaultDays : config.customDays

        for days in reminderDays {
            let reminderDate = Calendar.current.date(byAdding: .day, value: -days, to: warranty.endDate)

            guard let reminderDate = reminderDate, reminderDate > Date() else { continue }

            await scheduleNotification(
                identifier: "warranty-\(warranty.id.uuidString)-\(days)",
                title: "保修即将到期",
                body: "您的\(warranty.provider)保修服务将在\(days)天后到期",
                date: reminderDate,
                methods: config.notificationMethods
            )
        }
    }

    private func scheduleInsuranceReminders(for insurance: InsuranceInfo) async {
        guard let config = reminderConfigs.first(where: { $0.productId == insurance.productId }),
              config.isEnabled,
              config.reminderTypes.contains(.insurance) else {
            return
        }

        let reminderDays = config.customDays.isEmpty ? ReminderType.insurance.defaultDays : config.customDays

        for days in reminderDays {
            let reminderDate = Calendar.current.date(byAdding: .day, value: -days, to: insurance.endDate)

            guard let reminderDate = reminderDate, reminderDate > Date() else { continue }

            await scheduleNotification(
                identifier: "insurance-\(insurance.id.uuidString)-\(days)",
                title: "保险即将到期",
                body: "您的\(insurance.provider)保险将在\(days)天后到期",
                date: reminderDate,
                methods: config.notificationMethods
            )
        }

        // 续费提醒
        if let renewalInfo = insurance.renewalInfo,
           let renewalDate = renewalInfo.renewalDate,
           config.reminderTypes.contains(.renewal) {

            let reminderDate = Calendar.current.date(byAdding: .day, value: -renewalInfo.reminderDays, to: renewalDate)

            if let reminderDate = reminderDate, reminderDate > Date() {
                await scheduleNotification(
                    identifier: "renewal-\(insurance.id.uuidString)",
                    title: "保险续费提醒",
                    body: "您的\(insurance.provider)保险需要续费，费用约为¥\(renewalInfo.renewalCost ?? 0)",
                    date: reminderDate,
                    methods: config.notificationMethods
                )
            }
        }
    }

    private func scheduleNotification(
        identifier: String,
        title: String,
        body: String,
        date: Date,
        methods: [NotificationMethod]
    ) async {
        // 只处理推送通知，其他方法需要额外的集成
        guard methods.contains(.push) else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = UNNotificationSound.default

        let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print("安排提醒失败: \(error)")
        }
    }

    private func removeWarrantyReminders(for warrantyId: UUID) async {
        let identifiers = ReminderType.warranty.defaultDays.map { "warranty-\(warrantyId.uuidString)-\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    private func removeInsuranceReminders(for insuranceId: UUID) async {
        let identifiers = ReminderType.insurance.defaultDays.map { "insurance-\(insuranceId.uuidString)-\($0)" }
        identifiers.forEach { identifier in
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        }

        // 移除续费提醒
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["renewal-\(insuranceId.uuidString)"])
    }

    private func rescheduleReminders(for productId: UUID) async {
        // 重新安排该产品的所有提醒
        if let warranty = extendedWarranties.first(where: { $0.productId == productId }) {
            await scheduleWarrantyReminders(for: warranty)
        }

        if let insurance = insuranceInfos.first(where: { $0.productId == productId }) {
            await scheduleInsuranceReminders(for: insurance)
        }
    }

    private func saveReminderConfigs() async {
        if let data = try? JSONEncoder().encode(reminderConfigs) {
            UserDefaults.standard.set(data, forKey: "ReminderConfigs")
        }
    }

    // MARK: - 统计更新

    private func updateStatistics() {
        Task {
            let stats = await calculateEnhancedStatistics()
            await MainActor.run {
                self.statistics = stats
            }
        }
    }

    private func calculateEnhancedStatistics() async -> EnhancedWarrantyStatistics {
        // 获取所有产品
        let request: NSFetchRequest<Product> = Product.fetchRequest()
        let products = (try? context.fetch(request)) ?? []

        let totalProducts = products.count
        var activeWarranties = 0
        var expiredWarranties = 0
        var expiringSoon = 0
        var totalWarrantyValue: Decimal = 0
        var totalInsuranceValue: Decimal = 0

        // 计算基础统计
        for product in products {
            if let order = product.order, let warrantyEndDate = order.warrantyEndDate {
                if let price = order.price {
                    totalWarrantyValue += price.decimalValue
                }

                if warrantyEndDate > Date() {
                    activeWarranties += 1
                    if warrantyEndDate.timeIntervalSinceNow < 30 * 24 * 60 * 60 {
                        expiringSoon += 1
                    }
                } else {
                    expiredWarranties += 1
                }
            }
        }

        // 计算保险价值
        totalInsuranceValue = insuranceInfos.reduce(0) { $0 + $1.premium }

        // 计算续费率和理赔率
        let renewalRate = calculateRenewalRate()
        let claimRate = calculateClaimRate()

        // 计算节省费用
        let costSavings = calculateCostSavings()

        // 获取即将到期的续费
        let upcomingRenewals = getUpcomingRenewals()

        // 风险评估
        let riskAssessment = performRiskAssessment(
            products: products,
            activeWarranties: activeWarranties,
            expiringSoon: expiringSoon
        )

        return EnhancedWarrantyStatistics(
            totalProducts: totalProducts,
            activeWarranties: activeWarranties,
            expiredWarranties: expiredWarranties,
            expiringSoon: expiringSoon,
            totalWarrantyValue: totalWarrantyValue,
            totalInsuranceValue: totalInsuranceValue,
            averageWarrantyPeriod: calculateAverageWarrantyPeriod(products),
            renewalRate: renewalRate,
            claimRate: claimRate,
            costSavings: costSavings,
            upcomingRenewals: upcomingRenewals,
            riskAssessment: riskAssessment
        )
    }

    private func setupNotificationObservers() {
        // 监听应用状态变化，定期更新统计信息
        #if os(macOS)
        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.updateStatistics()
            }
            .store(in: &cancellables)
        #else
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.updateStatistics()
            }
            .store(in: &cancellables)
        #endif
    }

    // MARK: - 统计辅助方法

    private func calculateRenewalRate() -> Double {
        let totalRenewals = extendedWarranties.count + insuranceInfos.count
        let autoRenewals = extendedWarranties.filter { $0.renewalInfo?.isAutoRenewal == true }.count +
                          insuranceInfos.filter { $0.renewalInfo?.isAutoRenewal == true }.count

        return totalRenewals > 0 ? Double(autoRenewals) / Double(totalRenewals) : 0.0
    }

    private func calculateClaimRate() -> Double {
        let totalInsurances = insuranceInfos.count
        let insurancesWithClaims = insuranceInfos.filter { !$0.claims.isEmpty }.count

        return totalInsurances > 0 ? Double(insurancesWithClaims) / Double(totalInsurances) : 0.0
    }

    private func calculateCostSavings() -> Decimal {
        // 计算通过保修和保险节省的费用
        let warrantyUsage = extendedWarranties.filter { $0.isActive }.reduce(0) { $0 + $1.cost }
        let insuranceClaims = insuranceInfos.flatMap { $0.claims }.reduce(0) { $0 + $1.amount }

        return warrantyUsage + insuranceClaims
    }

    private func getUpcomingRenewals() -> [UpcomingRenewal] {
        var renewals: [UpcomingRenewal] = []
        let thirtyDaysFromNow = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()

        // 保修续费
        for warranty in extendedWarranties {
            if let renewalInfo = warranty.renewalInfo,
               let renewalDate = renewalInfo.renewalDate,
               renewalDate <= thirtyDaysFromNow {

                renewals.append(UpcomingRenewal(
                    id: UUID(),
                    productId: warranty.productId,
                    productName: getProductName(for: warranty.productId),
                    type: .warranty,
                    renewalDate: renewalDate,
                    estimatedCost: renewalInfo.renewalCost ?? 0,
                    priority: getPriority(for: renewalDate)
                ))
            }
        }

        // 保险续费
        for insurance in insuranceInfos {
            if let renewalInfo = insurance.renewalInfo,
               let renewalDate = renewalInfo.renewalDate,
               renewalDate <= thirtyDaysFromNow {

                renewals.append(UpcomingRenewal(
                    id: UUID(),
                    productId: insurance.productId,
                    productName: getProductName(for: insurance.productId),
                    type: .insurance,
                    renewalDate: renewalDate,
                    estimatedCost: renewalInfo.renewalCost ?? insurance.premium,
                    priority: getPriority(for: renewalDate)
                ))
            }
        }

        return renewals.sorted { $0.renewalDate < $1.renewalDate }
    }

    private func performRiskAssessment(
        products: [Product],
        activeWarranties: Int,
        expiringSoon: Int
    ) -> RiskAssessment {
        var riskFactors: [RiskFactor] = []
        var recommendations: [String] = []

        // 评估保修覆盖率
        let warrantyRate = products.isEmpty ? 0.0 : Double(activeWarranties) / Double(products.count)
        if warrantyRate < 0.5 {
            riskFactors.append(RiskFactor(
                name: "保修覆盖率低",
                level: .high,
                impact: "大部分产品缺乏保修保护",
                mitigation: "考虑为重要产品购买延长保修"
            ))
            recommendations.append("建议为价值较高的产品购买延长保修服务")
        }

        // 评估即将到期的保修
        if expiringSoon > 0 {
            let expiringRate = Double(expiringSoon) / Double(max(1, activeWarranties))
            let riskLevel: RiskLevel = expiringRate > 0.3 ? .high : .medium

            riskFactors.append(RiskFactor(
                name: "保修即将到期",
                level: riskLevel,
                impact: "多个产品保修即将失效",
                mitigation: "及时续费或购买新的保修服务"
            ))
            recommendations.append("请及时处理即将到期的保修服务")
        }

        // 评估保险覆盖
        let insuranceCoverage = Double(insuranceInfos.count) / Double(max(1, products.count))
        if insuranceCoverage < 0.2 {
            riskFactors.append(RiskFactor(
                name: "保险覆盖不足",
                level: .medium,
                impact: "缺乏意外损失保护",
                mitigation: "考虑为贵重物品购买保险"
            ))
            recommendations.append("建议为贵重产品购买意外损坏保险")
        }

        // 计算整体风险等级
        let overallRisk = calculateOverallRisk(factors: riskFactors)

        // 计算潜在节省
        let potentialSavings = calculatePotentialSavings(products: products)

        return RiskAssessment(
            overallRisk: overallRisk,
            factors: riskFactors,
            recommendations: recommendations,
            potentialSavings: potentialSavings
        )
    }

    private func calculateAverageWarrantyPeriod(_ products: [Product]) -> Double {
        let warrantyPeriods = products.compactMap { product -> Double? in
            guard let order = product.order,
                  let startDate = order.orderDate,
                  let endDate = order.warrantyEndDate else {
                return nil
            }
            return endDate.timeIntervalSince(startDate) / (30 * 24 * 60 * 60) // 转换为月
        }

        return warrantyPeriods.isEmpty ? 0.0 : warrantyPeriods.reduce(0, +) / Double(warrantyPeriods.count)
    }

    private func getProductName(for productId: UUID) -> String {
        let request: NSFetchRequest<Product> = Product.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", productId as CVarArg)
        request.fetchLimit = 1

        if let product = try? context.fetch(request).first {
            return product.productName
        }
        return "未知产品"
    }

    private func getPriority(for date: Date) -> Priority {
        let daysUntil = Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0

        if daysUntil <= 7 {
            return .high
        } else if daysUntil <= 15 {
            return .medium
        } else {
            return .low
        }
    }

    private func calculateOverallRisk(factors: [RiskFactor]) -> RiskLevel {
        let highRiskCount = factors.filter { $0.level == .high }.count
        let mediumRiskCount = factors.filter { $0.level == .medium }.count

        if highRiskCount > 0 {
            return .high
        } else if mediumRiskCount > 1 {
            return .medium
        } else if mediumRiskCount > 0 {
            return .low
        } else {
            return .low
        }
    }

    private func calculatePotentialSavings(products: [Product]) -> Decimal {
        // 估算通过更好的保修和保险管理可以节省的费用
        let unprotectedProducts = products.filter { product in
            !extendedWarranties.contains { $0.productId == product.id } &&
            !insuranceInfos.contains { $0.productId == product.id }
        }

        let averageProductValue = products.compactMap { $0.order?.price?.decimalValue }.reduce(0, +) / Decimal(max(1, products.count))
        let potentialRisk = Decimal(unprotectedProducts.count) * averageProductValue * 0.1 // 假设10%的风险

        return potentialRisk
    }
}

// MARK: - 历史数据结构
private struct HistoricalData {
    let totalRepairCost: Decimal
    let averageRepairCost: Decimal
    let repairFrequency: Double // 每月维修次数
    let productAge: Double // 产品年龄（月）
    let warrantyUsage: Double // 保修使用率
}
