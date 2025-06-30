import Foundation
import CoreData
import NaturalLanguage

// MARK: - 智能搜索建议服务
@MainActor
class IntelligentSearchSuggestionService: ObservableObject {
    static let shared = IntelligentSearchSuggestionService()
    
    @Published var suggestions: [SearchSuggestion] = []
    @Published var isGeneratingSuggestions = false
    
    private let context: NSManagedObjectContext
    private let nlProcessor = NLLanguageRecognizer()
    private let tagger = NLTagger(tagSchemes: [.tokenType, .lexicalClass, .nameType])
    
    // 搜索历史和频率统计
    private var searchHistory: [String] = []
    private var searchFrequency: [String: Int] = [:]
    private var popularTerms: [String] = []
    
    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.context = context
        loadSearchHistory()
        loadPopularTerms()
    }
    
    // MARK: - 智能建议生成
    
    /// 生成智能搜索建议
    func generateSuggestions(for query: String) async -> [SearchSuggestion] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return getDefaultSuggestions()
        }
        
        isGeneratingSuggestions = true
        defer { isGeneratingSuggestions = false }
        
        var allSuggestions: [SearchSuggestion] = []
        
        // 1. 历史搜索建议
        let historySuggestions = generateHistorySuggestions(for: query)
        allSuggestions.append(contentsOf: historySuggestions)
        
        // 2. 自动完成建议
        let autocompleteSuggestions = await generateAutocompleteSuggestions(for: query)
        allSuggestions.append(contentsOf: autocompleteSuggestions)
        
        // 3. 语义相关建议
        let semanticSuggestions = await generateSemanticSuggestions(for: query)
        allSuggestions.append(contentsOf: semanticSuggestions)
        
        // 4. 热门搜索建议
        let popularSuggestions = generatePopularSuggestions(for: query)
        allSuggestions.append(contentsOf: popularSuggestions)
        
        // 5. 智能纠错建议
        let correctionSuggestions = generateCorrectionSuggestions(for: query)
        allSuggestions.append(contentsOf: correctionSuggestions)
        
        // 去重并排序
        let uniqueSuggestions = removeDuplicates(allSuggestions)
        let rankedSuggestions = rankSuggestions(uniqueSuggestions, for: query)
        
        await MainActor.run {
            self.suggestions = Array(rankedSuggestions.prefix(10))
        }
        
        return suggestions
    }
    
    // MARK: - 历史搜索建议
    
    private func generateHistorySuggestions(for query: String) -> [SearchSuggestion] {
        let lowercaseQuery = query.lowercased()
        
        return searchHistory
            .filter { $0.lowercased().contains(lowercaseQuery) }
            .prefix(3)
            .map { SearchSuggestion(
                text: $0,
                type: .history,
                score: Double(calculateHistoryRelevance($0, query: query))
            )}
    }
    
    // MARK: - 自动完成建议
    
    private func generateAutocompleteSuggestions(for query: String) async -> [SearchSuggestion] {
        return await withCheckedContinuation { continuation in
            context.perform {
                var suggestions: [SearchSuggestion] = []
                
                // 从产品名称生成建议
                let productSuggestions = self.generateProductNameSuggestions(for: query)
                suggestions.append(contentsOf: productSuggestions)
                
                // 从品牌生成建议
                let brandSuggestions = self.generateBrandSuggestions(for: query)
                suggestions.append(contentsOf: brandSuggestions)
                
                // 从分类生成建议
                let categorySuggestions = self.generateCategorySuggestions(for: query)
                suggestions.append(contentsOf: categorySuggestions)
                
                continuation.resume(returning: suggestions)
            }
        }
    }
    
    private func generateProductNameSuggestions(for query: String) -> [SearchSuggestion] {
        let request: NSFetchRequest<Product> = Product.fetchRequest()
        request.predicate = NSPredicate(format: "name CONTAINS[cd] %@", query)
        request.fetchLimit = 5
        
        do {
            let products = try context.fetch(request)
            return products.map { product in
                SearchSuggestion(
                    text: product.name ?? "",
                    type: .product,
                    score: 0.8
                )
            }
        } catch {
            return []
        }
    }
    
    private func generateBrandSuggestions(for query: String) -> [SearchSuggestion] {
        let request: NSFetchRequest<Product> = Product.fetchRequest()
        request.predicate = NSPredicate(format: "brand CONTAINS[cd] %@", query)
        request.fetchLimit = 5
        
        do {
            let products = try context.fetch(request)
            let uniqueBrands = Set(products.compactMap { $0.brand })
            
            return uniqueBrands.map { brand in
                SearchSuggestion(
                    text: brand,
                    type: .product,
                    score: 0.7
                )
            }
        } catch {
            return []
        }
    }
    
    private func generateCategorySuggestions(for query: String) -> [SearchSuggestion] {
        let request: NSFetchRequest<Category> = Category.fetchRequest()
        request.predicate = NSPredicate(format: "name CONTAINS[cd] %@", query)
        request.fetchLimit = 3
        
        do {
            let categories = try context.fetch(request)
            return categories.map { category in
                SearchSuggestion(
                    text: category.name ?? "",
                    type: .category,
                    score: 0.6
                )
            }
        } catch {
            return []
        }
    }
    
    // MARK: - 语义相关建议
    
    private func generateSemanticSuggestions(for query: String) async -> [SearchSuggestion] {
        // 使用NLP分析查询意图
        let tokens = tokenizeQuery(query)
        var suggestions: [SearchSuggestion] = []
        
        for token in tokens {
            // 查找语义相关的词汇
            let relatedTerms = findSemanticallySimilarTerms(token)
            
            for term in relatedTerms {
                suggestions.append(SearchSuggestion(
                    text: term,
                    type: .autocomplete,
                    score: 0.5
                ))
            }
        }
        
        return suggestions
    }
    
    private func tokenizeQuery(_ query: String) -> [String] {
        tagger.string = query
        var tokens: [String] = []
        
        tagger.enumerateTags(in: query.startIndex..<query.endIndex, unit: .word, scheme: .tokenType) { tag, tokenRange in
            let token = String(query[tokenRange])
            if token.count > 2 { // 过滤短词
                tokens.append(token)
            }
            return true
        }
        
        return tokens
    }
    
    private func findSemanticallySimilarTerms(_ term: String) -> [String] {
        // 简化的语义相似词查找
        let semanticMap: [String: [String]] = [
            "手机": ["电话", "移动电话", "智能手机", "iPhone", "Android"],
            "电脑": ["计算机", "笔记本", "台式机", "Mac", "PC"],
            "电视": ["电视机", "显示器", "屏幕", "TV"],
            "冰箱": ["冷藏箱", "制冷设备", "冰柜"],
            "洗衣机": ["洗衣设备", "洗涤机"],
            "空调": ["空气调节器", "制冷设备", "暖通设备"]
        ]
        
        let lowercaseTerm = term.lowercased()
        
        // 直接匹配
        if let similar = semanticMap[lowercaseTerm] {
            return similar
        }
        
        // 反向匹配
        for (key, values) in semanticMap {
            if values.contains(where: { $0.lowercased() == lowercaseTerm }) {
                var result = [key]
                result.append(contentsOf: values.filter { $0.lowercased() != lowercaseTerm })
                return result
            }
        }
        
        return []
    }
    
    // MARK: - 热门搜索建议
    
    private func generatePopularSuggestions(for query: String) -> [SearchSuggestion] {
        let lowercaseQuery = query.lowercased()
        
        return popularTerms
            .filter { $0.lowercased().contains(lowercaseQuery) }
            .prefix(2)
            .map { SearchSuggestion(
                text: $0,
                type: .autocomplete,
                score: 0.4
            )}
    }
    
    // MARK: - 智能纠错建议
    
    private func generateCorrectionSuggestions(for query: String) -> [SearchSuggestion] {
        var suggestions: [SearchSuggestion] = []
        
        // 检查常见拼写错误
        let corrections = findSpellingCorrections(query)
        
        for correction in corrections {
            suggestions.append(SearchSuggestion(
                text: correction,
                type: .autocomplete,
                score: 0.3
            ))
        }
        
        return suggestions
    }
    
    private func findSpellingCorrections(_ query: String) -> [String] {
        // 简化的拼写纠错
        let commonMistakes: [String: String] = [
            "shouji": "手机",
            "diannao": "电脑",
            "dianshi": "电视",
            "bingxiang": "冰箱",
            "xiyiji": "洗衣机",
            "kongtiao": "空调"
        ]
        
        let lowercaseQuery = query.lowercased()
        
        if let correction = commonMistakes[lowercaseQuery] {
            return [correction]
        }
        
        // 检查编辑距离
        var corrections: [String] = []
        for (mistake, correct) in commonMistakes {
            if editDistance(lowercaseQuery, mistake) <= 2 {
                corrections.append(correct)
            }
        }
        
        return corrections
    }
    
    private func editDistance(_ s1: String, _ s2: String) -> Int {
        let s1Array = Array(s1)
        let s2Array = Array(s2)
        let m = s1Array.count
        let n = s2Array.count
        
        var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        
        for i in 0...m {
            dp[i][0] = i
        }
        
        for j in 0...n {
            dp[0][j] = j
        }
        
        for i in 1...m {
            for j in 1...n {
                if s1Array[i-1] == s2Array[j-1] {
                    dp[i][j] = dp[i-1][j-1]
                } else {
                    dp[i][j] = min(dp[i-1][j], dp[i][j-1], dp[i-1][j-1]) + 1
                }
            }
        }
        
        return dp[m][n]
    }
    
    // MARK: - 辅助方法
    
    private func getDefaultSuggestions() -> [SearchSuggestion] {
        return popularTerms.prefix(5).map { term in
            SearchSuggestion(
                text: term,
                type: .autocomplete,
                score: 0.5
            )
        }
    }
    
    private func removeDuplicates(_ suggestions: [SearchSuggestion]) -> [SearchSuggestion] {
        var seen = Set<String>()
        return suggestions.filter { suggestion in
            let key = suggestion.text.lowercased()
            if seen.contains(key) {
                return false
            } else {
                seen.insert(key)
                return true
            }
        }
    }
    
    private func rankSuggestions(_ suggestions: [SearchSuggestion], for query: String) -> [SearchSuggestion] {
        return suggestions.sorted { lhs, rhs in
            // 首先按类型优先级排序
            let lhsPriority = getPriority(for: lhs.type)
            let rhsPriority = getPriority(for: rhs.type)

            if lhsPriority != rhsPriority {
                return lhsPriority > rhsPriority
            }

            // 然后按相关性评分排序
            return lhs.score > rhs.score
        }
    }
    
    private func getPriority(for type: SearchSuggestion.SuggestionType) -> Int {
        switch type {
        case .history: return 5
        case .product: return 4
        case .category: return 3
        case .tag: return 2
        case .manual: return 2
        case .autocomplete: return 1
        }
    }

    private func calculateHistoryRelevance(_ historyItem: String, query: String) -> Float {
        let frequency = Float(searchFrequency[historyItem] ?? 1)
        let similarity = calculateStringSimilarity(historyItem, query)
        return frequency * 0.3 + similarity * 0.7
    }
    
    private func calculateStringSimilarity(_ s1: String, _ s2: String) -> Float {
        let distance = editDistance(s1.lowercased(), s2.lowercased())
        let maxLength = max(s1.count, s2.count)
        return maxLength > 0 ? Float(maxLength - distance) / Float(maxLength) : 0
    }
    
    // MARK: - 数据持久化
    
    private func loadSearchHistory() {
        if let data = UserDefaults.standard.data(forKey: "SearchHistory"),
           let history = try? JSONDecoder().decode([String].self, from: data) {
            searchHistory = history
        }
        
        if let data = UserDefaults.standard.data(forKey: "SearchFrequency"),
           let frequency = try? JSONDecoder().decode([String: Int].self, from: data) {
            searchFrequency = frequency
        }
    }
    
    private func loadPopularTerms() {
        popularTerms = [
            "手机", "电脑", "电视", "冰箱", "洗衣机", "空调",
            "iPhone", "MacBook", "iPad", "Samsung", "华为",
            "说明书", "保修", "维修", "安装", "使用方法"
        ]
    }
    
    func addToSearchHistory(_ query: String) {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return }
        
        // 更新搜索历史
        if let index = searchHistory.firstIndex(of: trimmedQuery) {
            searchHistory.remove(at: index)
        }
        searchHistory.insert(trimmedQuery, at: 0)
        
        // 限制历史记录数量
        if searchHistory.count > 50 {
            searchHistory = Array(searchHistory.prefix(50))
        }
        
        // 更新搜索频率
        searchFrequency[trimmedQuery] = (searchFrequency[trimmedQuery] ?? 0) + 1
        
        // 保存到UserDefaults
        saveSearchHistory()
    }
    
    private func saveSearchHistory() {
        if let historyData = try? JSONEncoder().encode(searchHistory) {
            UserDefaults.standard.set(historyData, forKey: "SearchHistory")
        }
        
        if let frequencyData = try? JSONEncoder().encode(searchFrequency) {
            UserDefaults.standard.set(frequencyData, forKey: "SearchFrequency")
        }
    }
}


