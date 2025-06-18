//
//  ManualSearchModels.swift
//  ManualBox
//
//  Created by Peter's Mac on 2025/4/27.
//

import Foundation
import CoreData

// MARK: - 搜索结果模型
struct ManualSearchResult: Identifiable {
    let id = UUID()
    let manual: Manual
    let relevanceScore: Float
    let matchedFields: [MatchedField]
    let highlightedSnippets: [String]
    
    struct MatchedField {
        let fieldName: String
        let content: String
        let matchRanges: [NSRange]
    }
}

// MARK: - 搜索配置
struct SearchConfiguration {
    let enableFuzzySearch: Bool
    let enableSynonymSearch: Bool
    let maxResults: Int
    let minRelevanceScore: Float
    let searchFields: [SearchField]
    
    enum SearchField: CaseIterable {
        case fileName
        case content
        case productName
        case productBrand
        case productModel
        case categoryName
        case tags
        
        var weight: Float {
            switch self {
            case .fileName: return 1.0
            case .content: return 0.8
            case .productName: return 0.9
            case .productBrand: return 0.7
            case .productModel: return 0.7
            case .categoryName: return 0.6
            case .tags: return 0.5
            }
        }
    }
    
    static let `default` = SearchConfiguration(
        enableFuzzySearch: true,
        enableSynonymSearch: true,
        maxResults: 50,
        minRelevanceScore: 0.1,
        searchFields: SearchField.allCases
    )
} 