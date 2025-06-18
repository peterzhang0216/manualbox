//
//  ManualSearchSuggestions.swift
//  ManualBox
//
//  Created by Peter's Mac on 2025/4/27.
//

import Foundation
import CoreData

// MARK: - 搜索建议和历史管理
extension ManualSearchService {
    
    // MARK: - 搜索建议
    func generateSearchSuggestions(for partialQuery: String) async -> [String] {
        guard partialQuery.count >= 2 else { return [] }
        
        var suggestions: [String] = []
        
        // 从搜索历史中获取建议
        let historySuggestions = searchHistory.filter { 
            $0.lowercased().contains(partialQuery.lowercased()) 
        }.prefix(5)
        suggestions.append(contentsOf: historySuggestions)
        
        // 从数据库中获取建议
        let dbSuggestions = await getDatabaseSuggestions(for: partialQuery)
        suggestions.append(contentsOf: dbSuggestions)
        
        // 去重并限制数量
        let uniqueSuggestions = Array(Set(suggestions)).prefix(10)
        
        await MainActor.run {
            self.searchSuggestions = Array(uniqueSuggestions)
        }
        
        return Array(uniqueSuggestions)
    }
    
    private func getDatabaseSuggestions(for partialQuery: String) async -> [String] {
        return await withCheckedContinuation { continuation in
            context.perform {
                var suggestions: [String] = []
                
                // 从产品名称获取建议
                let productRequest: NSFetchRequest<Product> = Product.fetchRequest()
                productRequest.predicate = NSPredicate(format: "name CONTAINS[cd] %@", partialQuery)
                productRequest.fetchLimit = 5
                
                if let products = try? self.context.fetch(productRequest) {
                    suggestions.append(contentsOf: products.compactMap { $0.name })
                }
                
                // 从品牌获取建议
                let brandRequest: NSFetchRequest<Product> = Product.fetchRequest()
                brandRequest.predicate = NSPredicate(format: "brand CONTAINS[cd] %@", partialQuery)
                brandRequest.fetchLimit = 5
                
                if let brands = try? self.context.fetch(brandRequest) {
                    suggestions.append(contentsOf: brands.compactMap { $0.brand })
                }
                
                continuation.resume(returning: suggestions)
            }
        }
    }
    
    // MARK: - 搜索历史管理
    func addToSearchHistory(_ query: String) {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return }
        
        // 移除重复项并添加到开头
        searchHistory.removeAll { $0 == trimmedQuery }
        searchHistory.insert(trimmedQuery, at: 0)
        
        // 限制历史记录数量
        if searchHistory.count > 20 {
            searchHistory = Array(searchHistory.prefix(20))
        }
        
        saveSearchHistory()
    }
    
    func loadSearchHistory() {
        if let data = UserDefaults.standard.data(forKey: "ManualSearchHistory"),
           let history = try? JSONDecoder().decode([String].self, from: data) {
            searchHistory = history
        }
    }
    
    private func saveSearchHistory() {
        if let data = try? JSONEncoder().encode(searchHistory) {
            UserDefaults.standard.set(data, forKey: "ManualSearchHistory")
        }
    }
    
    // MARK: - 公开的历史管理方法
    func clearSearchHistory() {
        searchHistory.removeAll()
        UserDefaults.standard.removeObject(forKey: "ManualSearchHistory")
    }
    
    func getSearchHistory() -> [String] {
        return searchHistory
    }
} 