//
//  SearchModels.swift
//  ManualBox
//
//  Created by Assistant on 2024/12/19.
//  搜索相关的数据模型
//

import Foundation
import SwiftUI

// MARK: - 高级搜索结果
struct AdvancedSearchResult: Identifiable, Codable {
    let id = UUID()
    let title: String
    let content: String
    let type: SearchResultType
    let relevanceScore: Double
    let lastModified: Date
    let fileSize: Int64
    let filePath: String?
    let snippet: String?
    let highlights: [String]
    
    enum SearchResultType: String, CaseIterable, Codable {
        case manual = "manual"
        case product = "product"
        case category = "category"
        case tag = "tag"
        
        var displayName: String {
            switch self {
            case .manual: return "说明书"
            case .product: return "产品"
            case .category: return "分类"
            case .tag: return "标签"
            }
        }
        
        var icon: String {
            switch self {
            case .manual: return "book"
            case .product: return "cube.box"
            case .category: return "folder"
            case .tag: return "tag"
            }
        }
        
        var color: Color {
            switch self {
            case .manual: return .blue
            case .product: return .green
            case .category: return .orange
            case .tag: return .purple
            }
        }
    }
}

// MARK: - 可搜索实体
struct SearchableEntity: Identifiable, Codable {
    let id = UUID()
    let name: String
    let type: EntityType
    let description: String?
    let metadata: [String: String]
    
    enum EntityType: String, CaseIterable, Codable {
        case product = "product"
        case manual = "manual"
        case category = "category"
        case tag = "tag"
        case brand = "brand"
        
        var displayName: String {
            switch self {
            case .product: return "产品"
            case .manual: return "说明书"
            case .category: return "分类"
            case .tag: return "标签"
            case .brand: return "品牌"
            }
        }
        
        var icon: String {
            switch self {
            case .product: return "cube.box"
            case .manual: return "book"
            case .category: return "folder"
            case .tag: return "tag"
            case .brand: return "building.2"
            }
        }
        
        var color: Color {
            switch self {
            case .product: return .green
            case .manual: return .blue
            case .category: return .orange
            case .tag: return .purple
            case .brand: return .cyan
            }
        }
    }
}

// MARK: - 搜索历史项
struct SearchHistoryItem: Identifiable, Codable {
    let id = UUID()
    let query: String
    let timestamp: Date
    let resultCount: Int
    let searchDuration: TimeInterval
    let filters: SearchHistoryFilters?
    
    struct SearchHistoryFilters: Codable {
        let categories: [String]
        let tags: [String]
        let dateRange: DateRange?
        let contentTypes: [String]
        
        struct DateRange: Codable {
            let start: Date
            let end: Date
        }
    }
    
    var displayText: String {
        return query.isEmpty ? "空搜索" : query
    }
    
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
    
    var formattedDuration: String {
        return String(format: "%.2f秒", searchDuration)
    }
}