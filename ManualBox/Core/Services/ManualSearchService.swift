//
//  ManualSearchService.swift
//  ManualBox
//
//  Created by Peter's Mac on 2025/4/27.
//

import Foundation
import CoreData

// MARK: - 说明书搜索服务 (重构后使用统一搜索)
@MainActor
class ManualSearchService: ObservableObject {
    static let shared = ManualSearchService()

    @Published var isSearching = false
    @Published var searchResults: [ManualSearchResult] = []
    @Published var searchSuggestions: [String] = []

    // 使用统一搜索服务
    private let unifiedSearchService = UnifiedSearchService.shared
    let context: NSManagedObjectContext
    var searchHistory: [String] = []

    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.context = context
        loadSearchHistory()
        setupUnifiedSearchBinding()
    }

    // MARK: - 主要搜索方法 (重构后使用统一搜索)
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

        // 使用统一搜索服务进行搜索
        let unifiedResults = await unifiedSearchService.search(
            query: query,
            scope: .manuals,
            configuration: convertToUnifiedConfiguration(configuration)
        )

        // 转换为ManualSearchResult格式
        let results = convertToManualSearchResults(unifiedResults)

        await MainActor.run {
            self.searchResults = results
            self.isSearching = false
            self.addToSearchHistory(query)
        }

        return results
    }

    // MARK: - 私有辅助方法

    private func setupUnifiedSearchBinding() {
        // 可以在这里设置与统一搜索服务的状态绑定
    }

    private func convertToUnifiedConfiguration(_ config: SearchConfiguration) -> UnifiedSearchConfiguration {
        return UnifiedSearchConfiguration(
            caseSensitive: false,
            enableFuzzySearch: config.enableFuzzySearch,
            enableSynonymSearch: config.enableSynonymSearch,
            maxResults: config.maxResults,
            minRelevanceScore: Double(config.minRelevanceScore),
            debounceInterval: 0.3
        )
    }

    private func convertToManualSearchResults(_ unifiedResults: [UnifiedSearchResult]) -> [ManualSearchResult] {
        return unifiedResults.compactMap { result in
            guard result.type == .manual,
                  let manual = result.entity as? Manual else {
                return nil
            }

            return ManualSearchResult(
                manual: manual,
                relevanceScore: Float(result.relevanceScore),
                matchedFields: [], // 可以从highlights转换
                highlightedSnippets: result.highlights
            )
        }
    }

    // MARK: - 搜索历史管理

    // 搜索历史方法已在 ManualSearchSuggestions.swift 中定义
}