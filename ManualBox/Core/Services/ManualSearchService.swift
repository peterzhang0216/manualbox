import Foundation
import CoreData

// MARK: - 增强版搜索服务
@MainActor
class ManualSearchService: ObservableObject {
    static let shared = ManualSearchService()
    
    @Published var isSearching = false
    @Published var searchResults: [ManualSearchResult] = []
    @Published var searchSuggestions: [String] = []
    
    private let context: NSManagedObjectContext
    private var searchHistory: [String] = []
    
    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.context = context
        loadSearchHistory()
    }
    
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
    
    // MARK: - 搜索谓词构建
    private func buildBasicSearchPredicates(
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
    
    private func buildFuzzySearchPredicates(
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
    
    private func buildSynonymSearchPredicates(
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
    
    // MARK: - 相关性评分
    private func calculateRelevanceScore(
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
    
    // MARK: - 搜索历史管理
    private func addToSearchHistory(_ query: String) {
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
    
    private func loadSearchHistory() {
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
}