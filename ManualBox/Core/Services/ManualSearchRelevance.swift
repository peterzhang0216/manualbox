//
//  ManualSearchRelevance.swift
//  ManualBox
//
//  Created by Peter's Mac on 2025/4/27.
//

import Foundation
import CoreData

// MARK: - 相关性评分计算
extension ManualSearchService {
    
    // MARK: - 相关性评分
    func calculateRelevanceScore(
        manual: Manual,
        query: String,
        configuration: SearchConfiguration
    ) -> ManualSearchResult {
        var totalScore: Float = 0.0
        var matchedFields: [ManualSearchResult.MatchedField] = []
        var highlightedSnippets: [String] = []
        
        let queryLower = query.lowercased()
        
        for field in configuration.searchFields {
            let (fieldScore, matchedField, snippet) = calculateFieldScore(
                manual: manual,
                field: field,
                query: queryLower
            )
            
            if fieldScore > 0 {
                totalScore += fieldScore * field.weight
                
                if let matchedField = matchedField {
                    matchedFields.append(matchedField)
                }
                
                if let snippet = snippet {
                    highlightedSnippets.append(snippet)
                }
            }
        }
        
        return ManualSearchResult(
            manual: manual,
            relevanceScore: totalScore,
            matchedFields: matchedFields,
            highlightedSnippets: highlightedSnippets
        )
    }
    
    private func calculateFieldScore(
        manual: Manual,
        field: SearchConfiguration.SearchField,
        query: String
    ) -> (Float, ManualSearchResult.MatchedField?, String?) {
        
        let content: String?
        let fieldName: String
        
        switch field {
        case .fileName:
            content = manual.fileName
            fieldName = "文件名"
        case .content:
            content = manual.isOCRProcessed ? manual.content : nil
            fieldName = "内容"
        case .productName:
            content = manual.product?.name
            fieldName = "产品名称"
        case .productBrand:
            content = manual.product?.brand
            fieldName = "品牌"
        case .productModel:
            content = manual.product?.model
            fieldName = "型号"
        case .categoryName:
            content = manual.product?.category?.name
            fieldName = "分类"
        case .tags:
            if let tags = manual.product?.tags as? Set<Tag> {
                content = tags.map { $0.name ?? "" }.joined(separator: " ")
            } else {
                content = nil
            }
            fieldName = "标签"
        }
        
        guard let text = content?.lowercased(), !text.isEmpty else {
            return (0.0, nil, nil)
        }
        
        // 计算匹配分数
        let score = calculateTextMatchScore(text: text, query: query)
        
        if score > 0 {
            // 创建匹配字段信息
            let ranges = findMatchRanges(in: text, query: query)
            let matchedField = ManualSearchResult.MatchedField(
                fieldName: fieldName,
                content: content ?? "",
                matchRanges: ranges
            )
            
            // 生成高亮片段
            let snippet = generateHighlightedSnippet(text: content ?? "", query: query)
            
            return (score, matchedField, snippet)
        }
        
        return (0.0, nil, nil)
    }
    
    // MARK: - 辅助方法
    private func calculateTextMatchScore(text: String, query: String) -> Float {
        let queryWords = query.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        
        var score: Float = 0.0
        
        for word in queryWords {
            if text.contains(word) {
                // 完全匹配得分最高
                if text == word {
                    score += 1.0
                } else if text.hasPrefix(word) || text.hasSuffix(word) {
                    score += 0.8
                } else {
                    score += 0.5
                }
            }
        }
        
        return score / Float(queryWords.count)
    }
    
    private func findMatchRanges(in text: String, query: String) -> [NSRange] {
        var ranges: [NSRange] = []
        let nsText = text as NSString
        let queryWords = query.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        
        for word in queryWords {
            var searchRange = NSRange(location: 0, length: nsText.length)
            
            while searchRange.location < nsText.length {
                let foundRange = nsText.range(of: word, options: [.caseInsensitive], range: searchRange)
                
                if foundRange.location == NSNotFound {
                    break
                }
                
                ranges.append(foundRange)
                searchRange.location = foundRange.location + foundRange.length
                searchRange.length = nsText.length - searchRange.location
            }
        }
        
        return ranges
    }
    
    private func generateHighlightedSnippet(text: String, query: String, maxLength: Int = 150) -> String {
        guard let range = text.range(of: query, options: [.caseInsensitive]) else {
            return String(text.prefix(maxLength))
        }
        
        let start = text.index(range.lowerBound, offsetBy: -50, limitedBy: text.startIndex) ?? text.startIndex
        let end = text.index(range.upperBound, offsetBy: 50, limitedBy: text.endIndex) ?? text.endIndex
        
        var snippet = String(text[start..<end])
        
        if start > text.startIndex {
            snippet = "..." + snippet
        }
        if end < text.endIndex {
            snippet = snippet + "..."
        }
        
        return snippet
    }
} 