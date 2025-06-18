//
//  ManualSearchPredicates.swift
//  ManualBox
//
//  Created by Peter's Mac on 2025/4/27.
//

import Foundation
import CoreData

// MARK: - 搜索谓词构建
extension ManualSearchService {
    
    // MARK: - 搜索谓词构建
    func buildBasicSearchPredicates(
        query: String,
        configuration: SearchConfiguration
    ) -> [NSPredicate] {
        var predicates: [NSPredicate] = []
        
        for field in configuration.searchFields {
            switch field {
            case .fileName:
                predicates.append(NSPredicate(format: "fileName CONTAINS[cd] %@", query))
                
            case .content:
                predicates.append(NSPredicate(
                    format: "content CONTAINS[cd] %@ AND isOCRProcessed == YES",
                    query
                ))
                
            case .productName:
                predicates.append(NSPredicate(format: "product.name CONTAINS[cd] %@", query))
                
            case .productBrand:
                predicates.append(NSPredicate(format: "product.brand CONTAINS[cd] %@", query))
                
            case .productModel:
                predicates.append(NSPredicate(format: "product.model CONTAINS[cd] %@", query))
                
            case .categoryName:
                predicates.append(NSPredicate(format: "product.category.name CONTAINS[cd] %@", query))
                
            case .tags:
                predicates.append(NSPredicate(format: "ANY product.tags.name CONTAINS[cd] %@", query))
            }
        }
        
        return predicates
    }
    
    func buildFuzzySearchPredicates(
        query: String,
        configuration: SearchConfiguration
    ) -> [NSPredicate] {
        var predicates: [NSPredicate] = []
        
        // 生成模糊搜索变体
        let fuzzyVariants = generateFuzzyVariants(query: query)
        
        for variant in fuzzyVariants {
            for field in configuration.searchFields {
                switch field {
                case .fileName:
                    predicates.append(NSPredicate(format: "fileName CONTAINS[cd] %@", variant))
                case .content:
                    predicates.append(NSPredicate(
                        format: "content CONTAINS[cd] %@ AND isOCRProcessed == YES",
                        variant
                    ))
                default:
                    break // 只对主要字段进行模糊搜索
                }
            }
        }
        
        return predicates
    }
    
    func buildSynonymSearchPredicates(
        query: String,
        configuration: SearchConfiguration
    ) -> [NSPredicate] {
        var predicates: [NSPredicate] = []
        
        // 获取同义词
        let synonyms = getSynonyms(for: query)
        
        for synonym in synonyms {
            let synonymPredicates = buildBasicSearchPredicates(
                query: synonym,
                configuration: configuration
            )
            predicates.append(contentsOf: synonymPredicates)
        }
        
        return predicates
    }
    
    // MARK: - 辅助方法
    private func generateFuzzyVariants(query: String) -> [String] {
        var variants: [String] = []
        
        // 去除一个字符的变体
        for i in 0..<query.count {
            let variant = String(query.prefix(i) + query.dropFirst(i + 1))
            if !variant.isEmpty {
                variants.append(variant)
            }
        }
        
        // 交换相邻字符的变体
        for i in 0..<query.count - 1 {
            var chars = Array(query)
            chars.swapAt(i, i + 1)
            variants.append(String(chars))
        }
        
        return variants
    }
    
    private func getSynonyms(for query: String) -> [String] {
        // 简单的同义词映射
        let synonymMap: [String: [String]] = [
            "手册": ["说明书", "指南", "教程"],
            "说明书": ["手册", "指南", "文档"],
            "指南": ["手册", "说明书", "教程"],
            "保修": ["质保", "维保", "保障"],
            "维修": ["修理", "修复", "检修"],
            "电脑": ["计算机", "PC", "笔记本"],
            "手机": ["移动电话", "智能机", "电话"]
        ]
        
        return synonymMap[query.lowercased()] ?? []
    }
} 