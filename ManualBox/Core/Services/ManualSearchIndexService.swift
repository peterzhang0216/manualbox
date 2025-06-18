import Foundation
import CoreData
import NaturalLanguage

// MARK: - 说明书搜索索引服务
class ManualSearchIndexService: ObservableObject {
    static let shared = ManualSearchIndexService()
    
    @Published var isIndexing = false
    @Published var indexingProgress: Float = 0.0
    
    private var searchIndex: [String: [SearchIndexEntry]] = [:]
    private let indexQueue = DispatchQueue(label: "ManualSearchIndex", qos: .userInitiated)
    
    private init() {
        loadSearchIndex()
    }
    
    // MARK: - 索引管理
    
    /// 重建搜索索引
    func rebuildIndex() async {
        await MainActor.run {
            isIndexing = true
            indexingProgress = 0.0
        }
        
        let context = PersistenceController.shared.container.viewContext
        let request: NSFetchRequest<Manual> = Manual.fetchRequest()
        request.predicate = NSPredicate(format: "isOCRProcessed == YES AND content != nil")
        
        do {
            let manuals = try context.fetch(request)
            var newIndex: [String: [SearchIndexEntry]] = [:]
            
            for (index, manual) in manuals.enumerated() {
                let progress = Float(index) / Float(manuals.count)
                await MainActor.run {
                    indexingProgress = progress
                }
                
                if let content = manual.content, !content.isEmpty {
                    let entries = createIndexEntries(for: content, manual: manual)
                    
                    for entry in entries {
                        let keyword = entry.keyword.lowercased()
                        if newIndex[keyword] == nil {
                            newIndex[keyword] = []
                        }
                        newIndex[keyword]?.append(entry)
                    }
                }
            }
            
            await indexQueue.async {
                self.searchIndex = newIndex
                self.saveSearchIndex()
            }
            
            await MainActor.run {
                isIndexing = false
                indexingProgress = 1.0
            }
            
        } catch {
            print("重建搜索索引失败: \(error.localizedDescription)")
            await MainActor.run {
                isIndexing = false
                indexingProgress = 0.0
            }
        }
    }
    
    /// 为单个说明书创建索引条目
    private func createIndexEntries(for content: String, manual: Manual) -> [SearchIndexEntry] {
        var entries: [SearchIndexEntry] = []
        
        // 分词处理
        let tokens = tokenizeText(content)
        
        // 创建索引条目
        for (index, token) in tokens.enumerated() {
            let entry = SearchIndexEntry(
                manualId: manual.id ?? UUID(),
                keyword: token,
                position: index,
                context: getContext(for: token, in: content, position: index),
                relevance: calculateRelevance(for: token, in: content)
            )
            entries.append(entry)
        }
        
        return entries
    }
    
    /// 文本分词
    private func tokenizeText(_ text: String) -> [String] {
        var tokens: [String] = []
        
        // 使用Natural Language框架进行分词
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, attributes in
            let token = String(text[range])
            
            // 过滤掉太短的词和纯数字
            if token.count >= 2 && !token.allSatisfy({ $0.isNumber }) {
                tokens.append(token)
            }
            
            return true
        }
        
        return tokens
    }
    
    /// 获取关键词上下文
    private func getContext(for keyword: String, in text: String, position: Int) -> String {
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        let start = max(0, position - 5)
        let end = min(words.count, position + 6)
        
        let contextWords = Array(words[start..<end])
        return contextWords.joined(separator: " ")
    }
    
    /// 计算关键词相关性
    private func calculateRelevance(for keyword: String, in text: String) -> Float {
        var relevance: Float = 1.0
        
        // 标题中的关键词权重更高
        if text.hasPrefix(keyword) {
            relevance += 2.0
        }
        
        // 频繁出现的词权重降低
        let occurrences = text.components(separatedBy: keyword).count - 1
        if occurrences > 5 {
            relevance -= Float(occurrences - 5) * 0.1
        }
        
        // 长词权重更高
        relevance += Float(keyword.count) * 0.1
        
        return max(0.1, relevance)
    }
    
    // MARK: - 搜索功能
    
    /// 搜索说明书
    func searchManuals(query: String, filters: ManualSearchFilters? = nil) async -> [ManualSearchResult] {
        let keywords = tokenizeText(query)
        var results: [ManualSearchResult] = []
        
        await indexQueue.async {
            for keyword in keywords {
                let lowercasedKeyword = keyword.lowercased()
                if let entries = self.searchIndex[lowercasedKeyword] {
                    for entry in entries {
                        // 应用过滤器
                        if let filters = filters {
                            if !self.matchesFilters(entry, filters: filters) {
                                continue
                            }
                        }
                        
                        // 查找或更新结果
                        if let existingIndex = results.firstIndex(where: { $0.manual.id == entry.manualId }) {
                            // 更新现有结果的相关性分数
                            let updatedResult = ManualSearchResult(
                                manual: results[existingIndex].manual,
                                relevanceScore: results[existingIndex].relevanceScore + entry.relevance,
                                matchedFields: results[existingIndex].matchedFields + [
                                    ManualSearchResult.MatchedField(
                                        fieldName: "content",
                                        content: entry.context,
                                        matchRanges: [NSRange(location: entry.position, length: keyword.count)]
                                    )
                                ],
                                highlightedSnippets: results[existingIndex].highlightedSnippets + [entry.context]
                            )
                            results[existingIndex] = updatedResult
                        } else {
                            // 创建新结果
                            // 这里需要从Core Data获取Manual对象
                            let context = PersistenceController.shared.container.viewContext
                            let fetchRequest: NSFetchRequest<Manual> = Manual.fetchRequest()
                            fetchRequest.predicate = NSPredicate(format: "id == %@", entry.manualId as CVarArg)
                            
                            if let manual = try? context.fetch(fetchRequest).first {
                                let result = ManualSearchResult(
                                    manual: manual,
                                    relevanceScore: entry.relevance,
                                    matchedFields: [
                                        ManualSearchResult.MatchedField(
                                            fieldName: "content",
                                            content: entry.context,
                                            matchRanges: [NSRange(location: entry.position, length: keyword.count)]
                                        )
                                    ],
                                    highlightedSnippets: [entry.context]
                                )
                                results.append(result)
                            }
                        }
                    }
                }
            }
        }
        
        // 按相关性排序
        results.sort { $0.relevanceScore > $1.relevanceScore }
        
        return results
    }
    
    /// 检查条目是否匹配过滤器
    private func matchesFilters(_ entry: SearchIndexEntry, filters: ManualSearchFilters) -> Bool {
        // 这里可以根据需要添加更多过滤条件
        return true
    }
    
    /// 获取搜索建议
    func getSearchSuggestions(for query: String) async -> [String] {
        let suggestions = await indexQueue.sync {
            let lowercasedQuery = query.lowercased()
            return searchIndex.keys
                .filter { $0.hasPrefix(lowercasedQuery) }
                .prefix(10)
                .map { $0 }
        }
        
        return Array(suggestions)
    }
    
    // MARK: - 索引持久化
    
    /// 保存搜索索引
    private func saveSearchIndex() {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(searchIndex) {
            let url = getIndexFileURL()
            try? data.write(to: url)
        }
    }
    
    /// 加载搜索索引
    private func loadSearchIndex() {
        let url = getIndexFileURL()
        if let data = try? Data(contentsOf: url),
           let index = try? JSONDecoder().decode([String: [SearchIndexEntry]].self, from: data) {
            searchIndex = index
        }
    }
    
    /// 获取索引文件URL
    private func getIndexFileURL() -> URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsDirectory.appendingPathComponent("manual_search_index.json")
    }
    
    // MARK: - 索引更新
    
    /// 更新单个说明书的索引
    func updateIndex(for manual: Manual) async {
        guard let content = manual.content, !content.isEmpty else {
            await removeFromIndex(manualId: manual.id ?? UUID())
            return
        }
        
        // 先移除旧索引
        await removeFromIndex(manualId: manual.id ?? UUID())
        
        // 添加新索引
        let entries = createIndexEntries(for: content, manual: manual)
        
        await indexQueue.async {
            for entry in entries {
                let keyword = entry.keyword.lowercased()
                if self.searchIndex[keyword] == nil {
                    self.searchIndex[keyword] = []
                }
                self.searchIndex[keyword]?.append(entry)
            }
            self.saveSearchIndex()
        }
    }
    
    /// 从索引中移除说明书
    func removeFromIndex(manualId: UUID) async {
        await indexQueue.async {
            for (keyword, entries) in self.searchIndex {
                self.searchIndex[keyword] = entries.filter { $0.manualId != manualId }
            }
            self.saveSearchIndex()
        }
    }
}

// MARK: - 搜索索引条目
struct SearchIndexEntry: Codable {
    let manualId: UUID
    let keyword: String
    let position: Int
    let context: String
    let relevance: Float
}

// MARK: - 搜索过滤器
struct ManualSearchFilters {
    let productId: UUID?
    let categoryId: UUID?
    let dateRange: ClosedRange<Date>?
    let fileType: String?
    
    static let empty = ManualSearchFilters(
        productId: nil,
        categoryId: nil,
        dateRange: nil,
        fileType: nil
    )
} 