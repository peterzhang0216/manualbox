//
//  WarrantyModels.swift
//  ManualBox
//
//  Created by Assistant on 2025/6/25.
//

import Foundation
import SwiftUI

// MARK: - 扩展保修信息
struct ExtendedWarrantyInfo: Identifiable, Codable {
    let id: UUID
    let productId: UUID
    let provider: String // 保修服务提供商
    let type: WarrantyType
    let startDate: Date
    let endDate: Date
    let cost: Decimal
    let coverage: [String] // 保修覆盖范围
    let terms: String // 保修条款
    let contactInfo: ContactInfo
    let renewalInfo: RenewalInfo?
    let createdAt: Date
    let updatedAt: Date
    
    var isActive: Bool {
        let now = Date()
        return now >= startDate && now <= endDate
    }
    
    var daysRemaining: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: endDate)
        return max(0, components.day ?? 0)
    }
    
    var status: ProductSearchFilters.WarrantyStatus {
        let now = Date()
        if now > endDate {
            return .expired
        } else if daysRemaining <= 30 {
            return .expiring
        } else {
            return .active
        }
    }
}

// MARK: - 保修类型
enum WarrantyType: String, CaseIterable, Codable {
    case manufacturer = "厂商保修"
    case extended = "延长保修"
    case thirdParty = "第三方保修"
    case insurance = "保险保修"
    
    var icon: String {
        switch self {
        case .manufacturer:
            return "building.2"
        case .extended:
            return "clock.arrow.circlepath"
        case .thirdParty:
            return "person.3"
        case .insurance:
            return "shield.checkered"
        }
    }
    
    var color: String {
        switch self {
        case .manufacturer:
            return "blue"
        case .extended:
            return "green"
        case .thirdParty:
            return "orange"
        case .insurance:
            return "purple"
        }
    }
}

// MARK: - 联系信息
struct ContactInfo: Codable {
    let phone: String?
    let email: String?
    let website: String?
    let address: String?
    let serviceHours: String?
}

// MARK: - 续费信息
struct RenewalInfo: Codable {
    let isAutoRenewal: Bool
    let renewalDate: Date?
    let renewalCost: Decimal?
    let renewalPeriod: Int // 续费期限（月）
    let reminderDays: Int // 提前提醒天数
    let paymentMethod: PaymentMethod?
    let notes: String?
}

// MARK: - 支付方式
enum PaymentMethod: String, CaseIterable, Codable {
    case creditCard = "信用卡"
    case debitCard = "借记卡"
    case bankTransfer = "银行转账"
    case alipay = "支付宝"
    case wechatPay = "微信支付"
    case cash = "现金"
    case other = "其他"
    
    var icon: String {
        switch self {
        case .creditCard, .debitCard:
            return "creditcard"
        case .bankTransfer:
            return "building.columns"
        case .alipay:
            return "a.circle"
        case .wechatPay:
            return "w.circle"
        case .cash:
            return "banknote"
        case .other:
            return "questionmark.circle"
        }
    }
}

// MARK: - 保险信息
struct InsuranceInfo: Identifiable, Codable {
    let id: UUID
    let productId: UUID
    let policyNumber: String
    let provider: String
    let type: InsuranceType
    let coverage: InsuranceCoverage
    let premium: Decimal // 保费
    let deductible: Decimal // 免赔额
    let startDate: Date
    let endDate: Date
    let beneficiary: String
    let contactInfo: ContactInfo
    let documents: [InsuranceDocument]
    let claims: [InsuranceClaim]
    let renewalInfo: RenewalInfo?
    let createdAt: Date
    let updatedAt: Date
    
    var isActive: Bool {
        let now = Date()
        return now >= startDate && now <= endDate
    }
    
    var daysUntilExpiry: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: endDate)
        return max(0, components.day ?? 0)
    }
    
    var totalClaimsAmount: Decimal {
        return claims.reduce(0) { $0 + $1.amount }
    }
}

// MARK: - 保险类型
enum InsuranceType: String, CaseIterable, Codable {
    case accidental = "意外损坏险"
    case theft = "盗窃险"
    case extended = "延长保修险"
    case comprehensive = "综合险"
    case liability = "责任险"
    
    var description: String {
        return rawValue
    }
    
    var icon: String {
        switch self {
        case .accidental:
            return "exclamationmark.triangle"
        case .theft:
            return "lock.shield"
        case .extended:
            return "clock.arrow.circlepath"
        case .comprehensive:
            return "shield.checkered"
        case .liability:
            return "person.badge.shield.checkmark"
        }
    }
}

// MARK: - 保险覆盖范围
struct InsuranceCoverage: Codable {
    let maxCoverage: Decimal // 最大保额
    let coverageItems: [String] // 保险项目
    let exclusions: [String] // 除外责任
    let territorialCoverage: String // 地域范围
    let replacementValue: Bool // 是否按重置价值赔付
}

// MARK: - 保险文档
struct InsuranceDocument: Identifiable, Codable {
    let id: UUID
    let type: DocumentType
    let fileName: String
    let fileData: Data?
    let uploadDate: Date
    let description: String?
}

enum DocumentType: String, CaseIterable, Codable {
    case policy = "保险单"
    case receipt = "缴费凭证"
    case claim = "理赔单据"
    case certificate = "保险证书"
    case other = "其他"
}

// MARK: - 保险理赔
struct InsuranceClaim: Identifiable, Codable {
    let id: UUID
    let claimNumber: String
    let incidentDate: Date
    let reportDate: Date
    let description: String
    let amount: Decimal
    let status: ClaimStatus
    let documents: [InsuranceDocument]
    let notes: String?
    let createdAt: Date
    let updatedAt: Date
}

enum ClaimStatus: String, CaseIterable, Codable {
    case submitted = "已提交"
    case underReview = "审核中"
    case approved = "已批准"
    case rejected = "已拒绝"
    case paid = "已赔付"
    case closed = "已关闭"
    
    var color: String {
        switch self {
        case .submitted:
            return "blue"
        case .underReview:
            return "orange"
        case .approved:
            return "green"
        case .rejected:
            return "red"
        case .paid:
            return "purple"
        case .closed:
            return "gray"
        }
    }
}

// MARK: - 费用预测
struct CostPrediction: Identifiable, Codable {
    let id: UUID
    let productId: UUID
    let predictionDate: Date
    let timeframe: PredictionTimeframe
    let predictions: [CostPredictionItem]
    let confidence: Double // 预测置信度
    let factors: [PredictionFactor] // 影响因素
    let recommendations: [String] // 建议

    init(productId: UUID, predictionDate: Date = Date(), timeframe: PredictionTimeframe, predictions: [CostPredictionItem], confidence: Double, factors: [PredictionFactor], recommendations: [String]) {
        self.id = UUID()
        self.productId = productId
        self.predictionDate = predictionDate
        self.timeframe = timeframe
        self.predictions = predictions
        self.confidence = confidence
        self.factors = factors
        self.recommendations = recommendations
    }
}

enum PredictionTimeframe: String, CaseIterable, Codable {
    case sixMonths = "6个月"
    case oneYear = "1年"
    case twoYears = "2年"
    case fiveYears = "5年"
    
    var months: Int {
        switch self {
        case .sixMonths: return 6
        case .oneYear: return 12
        case .twoYears: return 24
        case .fiveYears: return 60
        }
    }
}

struct CostPredictionItem: Codable {
    let category: CostCategory
    let predictedCost: Decimal
    let probability: Double
    let description: String
}

enum CostCategory: String, CaseIterable, Codable {
    case maintenance = "维护费用"
    case repair = "维修费用"
    case replacement = "更换费用"
    case insurance = "保险费用"
    case warranty = "保修费用"
    
    var icon: String {
        switch self {
        case .maintenance:
            return "wrench.and.screwdriver"
        case .repair:
            return "hammer"
        case .replacement:
            return "arrow.triangle.2.circlepath"
        case .insurance:
            return "shield"
        case .warranty:
            return "checkmark.shield"
        }
    }
}

struct PredictionFactor: Codable {
    let name: String
    let impact: Double // 影响权重 (-1.0 到 1.0)
    let description: String
}

// MARK: - 保修提醒配置
struct WarrantyReminderConfig: Codable {
    let productId: UUID
    let reminderTypes: [ReminderType]
    let customDays: [Int] // 自定义提醒天数
    let notificationMethods: [NotificationMethod]
    let isEnabled: Bool
}

enum ReminderType: String, CaseIterable, Codable {
    case warranty = "保修到期"
    case insurance = "保险到期"
    case renewal = "续费提醒"
    case maintenance = "维护提醒"

    var defaultDays: [Int] {
        switch self {
        case .warranty:
            return [30, 7, 1]
        case .insurance:
            return [60, 30, 7]
        case .renewal:
            return [30, 15, 7]
        case .maintenance:
            return [90, 30, 7]
        }
    }
}

enum NotificationMethod: String, CaseIterable, Codable {
    case push = "推送通知"
    case email = "邮件"
    case sms = "短信"
    case inApp = "应用内通知"

    var icon: String {
        switch self {
        case .push:
            return "bell"
        case .email:
            return "envelope"
        case .sms:
            return "message"
        case .inApp:
            return "app.badge"
        }
    }
}

// MARK: - 保修统计增强
struct EnhancedWarrantyStatistics: Codable {
    let totalProducts: Int
    let activeWarranties: Int
    let expiredWarranties: Int
    let expiringSoon: Int
    let totalWarrantyValue: Decimal
    let totalInsuranceValue: Decimal
    let averageWarrantyPeriod: Double
    let renewalRate: Double
    let claimRate: Double
    let costSavings: Decimal // 保修节省的费用
    let upcomingRenewals: [UpcomingRenewal]
    let riskAssessment: RiskAssessment
}

struct UpcomingRenewal: Identifiable, Codable {
    let id: UUID
    let productId: UUID
    let productName: String
    let type: RenewalType
    let renewalDate: Date
    let estimatedCost: Decimal
    let priority: Priority
}

enum RenewalType: String, CaseIterable, Codable {
    case warranty = "保修续费"
    case insurance = "保险续费"
    case service = "服务续费"
}

enum Priority: String, CaseIterable, Codable {
    case high = "高"
    case medium = "中"
    case low = "低"

    var color: String {
        switch self {
        case .high: return "red"
        case .medium: return "orange"
        case .low: return "green"
        }
    }
}

struct RiskAssessment: Codable {
    let overallRisk: RiskLevel
    let factors: [RiskFactor]
    let recommendations: [String]
    let potentialSavings: Decimal
}

enum RiskLevel: String, CaseIterable, Codable {
    case low = "低风险"
    case medium = "中等风险"
    case high = "高风险"
    case critical = "严重风险"

    var color: String {
        switch self {
        case .low: return "green"
        case .medium: return "yellow"
        case .high: return "orange"
        case .critical: return "red"
        }
    }
}

struct RiskFactor: Codable {
    let name: String
    let level: RiskLevel
    let impact: String
    let mitigation: String
}
