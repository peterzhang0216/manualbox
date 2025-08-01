import Foundation
import SwiftUI

// MARK: - 优化建议
struct OptimizationRecommendation: Identifiable, Codable {
    let id: UUID
    let title: String
    let description: String
    let priority: BottleneckSeverity
    let estimatedImprovement: String
    let category: RecommendationCategory
    let actionRequired: Bool
    let implementationDifficulty: ImplementationDifficulty
    
    init(
        id: UUID = UUID(),
        title: String,
        description: String,
        priority: BottleneckSeverity,
        estimatedImprovement: String,
        category: RecommendationCategory = .performance,
        actionRequired: Bool = true,
        implementationDifficulty: ImplementationDifficulty = .medium
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.priority = priority
        self.estimatedImprovement = estimatedImprovement
        self.category = category
        self.actionRequired = actionRequired
        self.implementationDifficulty = implementationDifficulty
    }
}

// MARK: - 瓶颈严重程度
enum BottleneckSeverity: String, CaseIterable, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    
    var displayName: String {
        switch self {
        case .low: return "低"
        case .medium: return "中"
        case .high: return "高"
        }
    }
    
    var color: Color {
        switch self {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        }
    }
    
    var priority: Int {
        switch self {
        case .low: return 1
        case .medium: return 2
        case .high: return 3
        }
    }
}

// MARK: - 建议分类
enum RecommendationCategory: String, CaseIterable, Codable {
    case performance = "performance"
    case memory = "memory"
    case storage = "storage"
    case network = "network"
    case ui = "ui"
    case database = "database"
    case search = "search"
    case general = "general"
    
    var displayName: String {
        switch self {
        case .performance: return "性能"
        case .memory: return "内存"
        case .storage: return "存储"
        case .network: return "网络"
        case .ui: return "界面"
        case .database: return "数据库"
        case .search: return "搜索"
        case .general: return "通用"
        }
    }
    
    var icon: String {
        switch self {
        case .performance: return "speedometer"
        case .memory: return "memorychip"
        case .storage: return "internaldrive"
        case .network: return "network"
        case .ui: return "rectangle.on.rectangle"
        case .database: return "cylinder"
        case .search: return "magnifyingglass"
        case .general: return "gear"
        }
    }
    
    var color: Color {
        switch self {
        case .performance: return .blue
        case .memory: return .orange
        case .storage: return .purple
        case .network: return .green
        case .ui: return .pink
        case .database: return .brown
        case .search: return .cyan
        case .general: return .gray
        }
    }
}

// MARK: - 实施难度
enum ImplementationDifficulty: String, CaseIterable, Codable {
    case easy = "easy"
    case medium = "medium"
    case hard = "hard"
    case expert = "expert"
    
    var displayName: String {
        switch self {
        case .easy: return "简单"
        case .medium: return "中等"
        case .hard: return "困难"
        case .expert: return "专家级"
        }
    }
    
    var color: Color {
        switch self {
        case .easy: return .green
        case .medium: return .yellow
        case .hard: return .orange
        case .expert: return .red
        }
    }
    
    var estimatedTime: String {
        switch self {
        case .easy: return "< 1小时"
        case .medium: return "1-4小时"
        case .hard: return "1-3天"
        case .expert: return "1周+"
        }
    }
}