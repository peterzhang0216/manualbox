//
//  UsageGuideModels.swift
//  ManualBox
//
//  Created by Assistant on 2025/6/24.
//

import Foundation

// MARK: - 产品使用指南
struct ProductUsageGuide: Identifiable, Codable {
    let id: UUID
    let productId: UUID
    let productName: String
    let title: String
    let subtitle: String
    let sections: [GuideSection]
    let estimatedReadingTime: Int // 分钟
    let difficultyLevel: DifficultyLevel
    let generatedAt: Date
    let version: String
    let language: String
    
    var formattedReadingTime: String {
        if estimatedReadingTime < 60 {
            return "\(estimatedReadingTime)分钟"
        } else {
            let hours = estimatedReadingTime / 60
            let minutes = estimatedReadingTime % 60
            return minutes > 0 ? "\(hours)小时\(minutes)分钟" : "\(hours)小时"
        }
    }
    
    var totalContentLength: Int {
        return sections.reduce(0) { total, section in
            total + section.content.joined(separator: " ").count
        }
    }
    
    var sectionCount: Int {
        return sections.count
    }
}

// MARK: - 指南章节
struct GuideSection: Identifiable, Codable {
    let id: UUID
    let title: String
    let type: SectionType
    let priority: Int
    let content: [String]
    
    var formattedContent: String {
        return content.joined(separator: "\n\n")
    }
    
    var contentPreview: String {
        let preview = formattedContent
        return preview.count > 100 ? String(preview.prefix(100)) + "..." : preview
    }
}

// MARK: - 章节类型
enum SectionType: String, CaseIterable, Codable {
    case overview = "概述"
    case setup = "初始设置"
    case basicOperations = "基本操作"
    case advancedFeatures = "高级功能"
    case maintenance = "维护保养"
    case safety = "安全注意事项"
    case troubleshooting = "故障排除"
    case specifications = "技术规格"
    
    var icon: String {
        switch self {
        case .overview:
            return "info.circle"
        case .setup:
            return "gearshape.2"
        case .basicOperations:
            return "hand.tap"
        case .advancedFeatures:
            return "star.circle"
        case .maintenance:
            return "wrench.and.screwdriver"
        case .safety:
            return "exclamationmark.shield"
        case .troubleshooting:
            return "questionmark.circle"
        case .specifications:
            return "list.bullet.rectangle"
        }
    }
    
    var color: String {
        switch self {
        case .overview:
            return "blue"
        case .setup:
            return "green"
        case .basicOperations:
            return "orange"
        case .advancedFeatures:
            return "purple"
        case .maintenance:
            return "brown"
        case .safety:
            return "red"
        case .troubleshooting:
            return "yellow"
        case .specifications:
            return "gray"
        }
    }
}

// MARK: - 难度等级
enum DifficultyLevel: String, CaseIterable, Codable {
    case beginner = "初级"
    case intermediate = "中级"
    case advanced = "高级"
    
    var icon: String {
        switch self {
        case .beginner:
            return "1.circle"
        case .intermediate:
            return "2.circle"
        case .advanced:
            return "3.circle"
        }
    }
    
    var color: String {
        switch self {
        case .beginner:
            return "green"
        case .intermediate:
            return "orange"
        case .advanced:
            return "red"
        }
    }
    
    var description: String {
        switch self {
        case .beginner:
            return "适合初次使用的用户"
        case .intermediate:
            return "需要一定使用经验"
        case .advanced:
            return "需要丰富的使用经验"
        }
    }
}

// MARK: - 产品信息
struct ProductInformation: Codable {
    let id: UUID
    let name: String
    let brand: String
    let model: String
    let category: String?
    let tags: [String]
    let purchaseDate: Date?
    let warrantyPeriod: Int?
    let notes: String
}

// MARK: - 说明书分析结果
struct ManualAnalysisResult: Codable {
    let combinedContent: String
    let individualAnalyses: [SingleManualAnalysis]
    let detectedLanguage: String
    let contentLength: Int
    let structuralElements: [String]
}

// MARK: - 单个说明书分析
struct SingleManualAnalysis: Codable {
    let manualId: UUID
    let fileName: String
    let contentSections: [String]
    let keyTerms: [String]
    let instructions: [String]
    let warnings: [String]
    let specifications: [String]
    let troubleshooting: [String]
}

// MARK: - 关键信息
struct KeyInformation: Codable {
    let setupInstructions: [String]
    let basicOperations: [String]
    let advancedFeatures: [String]
    let maintenanceGuidelines: [String]
    let safetyWarnings: [String]
    let technicalSpecifications: [String]
    let commonIssues: [String]
    let importantNotes: [String]
}

// MARK: - 指南结构
struct GuideStructure: Codable {
    let sections: [GuideSection]
    let estimatedReadingTime: Int
    let difficultyLevel: DifficultyLevel
}

// MARK: - 指南生成错误
enum GuideGenerationError: Error, LocalizedError {
    case noManualContent
    case insufficientContent
    case analysisFailure(String)
    case generationFailure(String)
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .noManualContent:
            return "没有找到说明书内容"
        case .insufficientContent:
            return "说明书内容不足以生成指南"
        case .analysisFailure(let message):
            return "内容分析失败: \(message)"
        case .generationFailure(let message):
            return "指南生成失败: \(message)"
        case .unknown(let message):
            return "未知错误: \(message)"
        }
    }
}

// MARK: - 指南模板
struct GuideTemplate: Codable {
    let id: UUID
    let name: String
    let category: String
    let sections: [TemplateSectionConfig]
    let isDefault: Bool
    
    static let defaultTemplates: [GuideTemplate] = [
        GuideTemplate(
            id: UUID(),
            name: "电子产品模板",
            category: "电子产品",
            sections: [
                TemplateSectionConfig(type: .overview, isRequired: true, priority: 1),
                TemplateSectionConfig(type: .setup, isRequired: true, priority: 2),
                TemplateSectionConfig(type: .basicOperations, isRequired: true, priority: 3),
                TemplateSectionConfig(type: .advancedFeatures, isRequired: false, priority: 4),
                TemplateSectionConfig(type: .maintenance, isRequired: true, priority: 5),
                TemplateSectionConfig(type: .safety, isRequired: true, priority: 6),
                TemplateSectionConfig(type: .troubleshooting, isRequired: false, priority: 7),
                TemplateSectionConfig(type: .specifications, isRequired: false, priority: 8)
            ],
            isDefault: true
        ),
        GuideTemplate(
            id: UUID(),
            name: "家用电器模板",
            category: "家用电器",
            sections: [
                TemplateSectionConfig(type: .overview, isRequired: true, priority: 1),
                TemplateSectionConfig(type: .setup, isRequired: true, priority: 2),
                TemplateSectionConfig(type: .basicOperations, isRequired: true, priority: 3),
                TemplateSectionConfig(type: .maintenance, isRequired: true, priority: 4),
                TemplateSectionConfig(type: .safety, isRequired: true, priority: 5),
                TemplateSectionConfig(type: .troubleshooting, isRequired: true, priority: 6)
            ],
            isDefault: true
        ),
        GuideTemplate(
            id: UUID(),
            name: "通用模板",
            category: "其他",
            sections: [
                TemplateSectionConfig(type: .overview, isRequired: true, priority: 1),
                TemplateSectionConfig(type: .basicOperations, isRequired: true, priority: 2),
                TemplateSectionConfig(type: .maintenance, isRequired: false, priority: 3),
                TemplateSectionConfig(type: .safety, isRequired: false, priority: 4)
            ],
            isDefault: true
        )
    ]
}

// MARK: - 模板章节配置
struct TemplateSectionConfig: Codable {
    let type: SectionType
    let isRequired: Bool
    let priority: Int
}

// MARK: - 指南生成配置
struct GuideGenerationConfig: Codable {
    let useTemplate: Bool
    let templateId: UUID?
    var includeSpecifications: Bool
    var includeTroubleshooting: Bool
    var maxSectionLength: Int
    let language: String
    let customSections: [SectionType]
    
    static let `default` = GuideGenerationConfig(
        useTemplate: true,
        templateId: nil,
        includeSpecifications: true,
        includeTroubleshooting: true,
        maxSectionLength: 1000,
        language: "zh-CN",
        customSections: []
    )
}

// MARK: - 指南统计信息
struct GuideStatistics: Codable {
    let totalGuides: Int
    let guidesByCategory: [String: Int]
    let averageReadingTime: Double
    let mostCommonSections: [SectionType]
    let difficultyDistribution: [DifficultyLevel: Int]
    let generationSuccessRate: Double
    let lastGeneratedDate: Date?
}
