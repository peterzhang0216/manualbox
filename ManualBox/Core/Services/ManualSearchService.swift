//
//  ManualSearchService.swift
//  ManualBox
//
//  Created by Peter's Mac on 2025/4/27.
//

import Foundation
import CoreData

// MARK: - 增强版搜索服务
@MainActor
class ManualSearchService: ObservableObject {
    static let shared = ManualSearchService()
    
    @Published var isSearching = false
    @Published var searchResults: [ManualSearchResult] = []
    @Published var searchSuggestions: [String] = []
    
    let context: NSManagedObjectContext
    var searchHistory: [String] = []
    
    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.context = context
        loadSearchHistory()
    }
    
    // MARK: - 主要搜索方法
    func performSearch(
        query: String,
        configuration: SearchConfiguration = .default
    ) async -> [ManualSearchResult] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            await MainActor.run {
                self.searchResults = []
                self.isSearching = false
            }
            return []
        }
        
        await MainActor.run {
            self.isSearching = true
        }
        
        let results = await performAdvancedSearch(query: query, configuration: configuration)
        
        await MainActor.run {
            self.searchResults = results
            self.isSearching = false
            self.addToSearchHistory(query)
        }
        
        return results
    }
    
    // MARK: - 高级搜索实现
    private func performAdvancedSearch(
        query: String,
        configuration: SearchConfiguration
    ) async -> [ManualSearchResult] {
        return await withCheckedContinuation { continuation in
            context.perform {
                let request: NSFetchRequest<Manual> = Manual.fetchRequest()
                
                // 构建复合搜索谓词
                var allPredicates: [NSPredicate] = []
                
                // 基础搜索谓词
                let basicPredicates = self.buildBasicSearchPredicates(query: query, configuration: configuration)
                allPredicates.append(contentsOf: basicPredicates)
                
                // 模糊搜索谓词
                if configuration.enableFuzzySearch {
                    let fuzzyPredicates = self.buildFuzzySearchPredicates(query: query, configuration: configuration)
                    allPredicates.append(contentsOf: fuzzyPredicates)
                }
                
                // 同义词搜索谓词
                if configuration.enableSynonymSearch {
                    let synonymPredicates = self.buildSynonymSearchPredicates(query: query, configuration: configuration)
                    allPredicates.append(contentsOf: synonymPredicates)
                }
                
                // 组合所有谓词
                request.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: allPredicates)
                
                // 设置排序和限制
                request.sortDescriptors = [
                    NSSortDescriptor(keyPath: \Manual.product?.updatedAt, ascending: false)
                ]
                request.fetchLimit = configuration.maxResults
                
                do {
                    let manuals = try self.context.fetch(request)
                    
                    // 计算相关性评分并创建搜索结果
                    let searchResults = manuals.compactMap { manual -> ManualSearchResult? in
                        let result = self.calculateRelevanceScore(
                            manual: manual,
                            query: query,
                            configuration: configuration
                        )
                        
                        return result.relevanceScore >= configuration.minRelevanceScore ? result : nil
                    }
                    
                    // 按相关性评分排序
                    let sortedResults = searchResults.sorted { $0.relevanceScore > $1.relevanceScore }
                    
                    continuation.resume(returning: sortedResults)
                } catch {
                    print("搜索失败: \(error.localizedDescription)")
                    continuation.resume(returning: [])
                }
            }
        }
    }
} 