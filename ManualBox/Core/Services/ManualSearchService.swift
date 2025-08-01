import Foundation
import CoreData
import Combine

// MARK: - 说明书搜索服务
class ManualSearchService: ObservableObject {
    static let shared = ManualSearchService()
    
    @Published var searchResults: [ManualSearchResult] = []
    @Published var searchSuggestions: [String] = []
    @Published var isSearching = false
    @Published var searchHistory: [String] = []
    
    private let viewContext: NSManagedObjectContext
    private let searchIndexService = ManualSearchIndexService.shared
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        self.viewContext = PersistenceController.shared.container.viewContext
        loadSearchHistory()
    }
    
    // MARK: - 主要搜索方法
    func performSearch(query: String, configuration: SearchConfiguration = .default) async {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            await MainActor.run {
                self.searchResults = []
            }
            return
        }
        
        await MainActor.run {
            self.isSearching = true
        }
        
        // 添加到搜索历史
        addToSearchHistory(query)
        
        do {
            let results = try await performCoreDataSearch(query: query, configuration: configuration)
            
            await MainActor.run {
                self.searchResults = results
                self.isSearching = false
            }
        } catch {
            await MainActor.run {
                self.searchResults = []
                self.isSearching = false
            }
            print("搜索失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Core Data搜索实现
    private func performCoreDataSearch(
        query: String,
        configuration: SearchConfiguration
    ) async throws -> [ManualSearchResult] {
        return try await withCheckedThrowingContinuation { continuation in
            viewContext.perform {
                do {
                    let request: NSFetchRequest<Manual> = Manual.fetchRequest()
                    
                    // 构建搜索谓词
                    var predicates: [NSPredicate] = []
                    
                    // 基本搜索谓词
                    let basicPredicates = self.buildBasicSearchPredicates(
                        query: query,
                        configuration: configuration
                    )
                    predicates.append(contentsOf: basicPredicates)
                    
                    // 模糊搜索谓词
                    if configuration.enableFuzzySearch {
                        let fuzzyPredicates = self.buildFuzzySearchPredicates(
                            query: query,
                            configuration: configuration
                        )
                        predicates.append(contentsOf: fuzzyPredicates)
                    }
                    
                    // 同义词搜索谓词
                    if configuration.enableSynonymSearch {
                        let synonymPredicates = self.buildSynonymSearchPredicates(
                            query: query,
                            configuration: configuration
                        )
                        predicates.append(contentsOf: synonymPredicates)
                    }
                    
                    // 组合所有谓词
                    if !predicates.isEmpty {
                        request.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: predicates)
                    }
                    
                    // 设置排序和限制
                    request.sortDescriptors = [
                        NSSortDescriptor(keyPath: \Manual.fileName, ascending: true)
                    ]
                    request.fetchLimit = configuration.maxResults
                    
                    // 执行搜索
                    let manuals = try self.viewContext.fetch(request)
                    
                    // 转换为搜索结果
                    let results = manuals.compactMap { manual -> ManualSearchResult? in
                        let relevanceScore = self.calculateRelevanceScore(
                            manual: manual,
                            query: query,
                            configuration: configuration
                        )
                        
                        guard relevanceScore >= configuration.minRelevanceScore else {
                            return nil
                        }
                        
                        return ManualSearchResult(
                            manual: manual,
                            relevanceScore: relevanceScore,
                            matchedFields: self.findMatchedFields(manual: manual, query: query),
                            highlightedSnippets: self.generateHighlightedSnippets(manual: manual, query: query)
                        )
                    }
                    
                    // 按相关性排序
                    let sortedResults = results.sorted { $0.relevanceScore > $1.relevanceScore }
                    
                    continuation.resume(returning: sortedResults)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - 相关性计算
    private func calculateRelevanceScore(
        manual: Manual,
        query: String,
        configuration: SearchConfiguration
    ) -> Float {
        var score: Float = 0.0
        let lowercasedQuery = query.lowercased()
        
        for field in configuration.searchFields {
            let fieldContent = getFieldContent(manual: manual, field: field).lowercased()
            
            if fieldContent.contains(lowercasedQuery) {
                // 精确匹配得分更高
                if fieldContent == lowercasedQuery {
                    score += field.weight * 2.0
                } else if fieldContent.hasPrefix(lowercasedQuery) {
                    score += field.weight * 1.5
                } else {
                    score += field.weight
                }
            }
        }
        
        return score
    }
    
    // MARK: - 辅助方法
    private func getFieldContent(manual: Manual, field: SearchConfiguration.SearchField) -> String {
        switch field {
        case .fileName:
            return manual.fileName ?? ""
        case .content:
            return manual.content ?? ""
        case .productName:
            return manual.product?.name ?? ""
        case .productBrand:
            return manual.product?.brand ?? ""
        case .productModel:
            return manual.product?.model ?? ""
        case .categoryName:
            return manual.product?.category?.name ?? ""
        case .tags:
            return manual.product?.tags?.compactMap { ($0 as? Tag)?.name }.joined(separator: " ") ?? ""
        }
    }
    
    private func findMatchedFields(manual: Manual, query: String) -> [ManualSearchResult.MatchedField] {
        var matchedFields: [ManualSearchResult.MatchedField] = []
        let lowercasedQuery = query.lowercased()
        
        // 检查文件名
        if let fileName = manual.fileName, fileName.lowercased().contains(lowercasedQuery) {
            let ranges = findMatchRanges(in: fileName, query: query)
            matchedFields.append(ManualSearchResult.MatchedField(
                fieldName: "fileName",
                content: fileName,
                matchRanges: ranges
            ))
        }
        
        // 检查内容
        if let content = manual.content, content.lowercased().contains(lowercasedQuery) {
            let ranges = findMatchRanges(in: content, query: query)
            matchedFields.append(ManualSearchResult.MatchedField(
                fieldName: "content",
                content: content,
                matchRanges: ranges
            ))
        }
        
        return matchedFields
    }
    
    private func findMatchRanges(in text: String, query: String) -> [NSRange] {
        var ranges: [NSRange] = []
        let nsText = text as NSString
        let nsQuery = query as NSString
        
        var searchRange = NSRange(location: 0, length: nsText.length)
        
        while searchRange.location < nsText.length {
            let foundRange = nsText.range(of: nsQuery as String, options: .caseInsensitive, range: searchRange)
            if foundRange.location == NSNotFound {
                break
            }
            
            ranges.append(foundRange)
            searchRange.location = foundRange.location + foundRange.length
            searchRange.length = nsText.length - searchRange.location
        }
        
        return ranges
    }
    
    private func generateHighlightedSnippets(manual: Manual, query: String) -> [String] {
        var snippets: [String] = []
        
        if let content = manual.content {
            let words = content.components(separatedBy: .whitespacesAndNewlines)
            let queryWords = query.components(separatedBy: .whitespacesAndNewlines)
            
            for (index, word) in words.enumerated() {
                for queryWord in queryWords {
                    if word.lowercased().contains(queryWord.lowercased()) {
                        let startIndex = max(0, index - 5)
                        let endIndex = min(words.count - 1, index + 5)
                        let snippet = words[startIndex...endIndex].joined(separator: " ")
                        snippets.append(snippet)
                        break
                    }
                }
            }
        }
        
        return Array(Set(snippets)).prefix(3).map { String($0) }
    }
    
    // MARK: - 清理方法
    func clearSearchResults() {
        searchResults = []
    }
    
    func clearSearchHistory() {
        searchHistory = []
        if let data = try? JSONEncoder().encode(searchHistory) {
            UserDefaults.standard.set(data, forKey: "ManualSearchHistory")
        }
    }
}