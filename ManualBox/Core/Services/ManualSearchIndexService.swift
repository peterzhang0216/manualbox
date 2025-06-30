import Foundation
import CoreData
import NaturalLanguage

// MARK: - 说明书搜索索引服务
class ManualSearchIndexService: ObservableObject {
    static let shared = ManualSearchIndexService()

    @Published var isIndexing = false
    @Published var indexingProgress: Float = 0.0
    @Published var indexStats: IndexStatistics = IndexStatistics()

    private var searchIndex: [String: [SearchIndexEntry]] = [:]
    private var invertedIndex: [String: Set<UUID>] = [:]
    private var documentFrequency: [String: Int] = [:]
    private var termFrequency: [UUID: [String: Int]] = [:]

    private let indexQueue = DispatchQueue(label: "ManualSearchIndex", qos: .userInitiated)
    private let nlProcessor = NLProcessor()

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
            var newInvertedIndex: [String: Set<UUID>] = [:]
            var newDocumentFrequency: [String: Int] = [:]
            var newTermFrequency: [UUID: [String: Int]] = [:]

            var totalTerms = 0
            var totalDocumentLength = 0

            for (index, manual) in manuals.enumerated() {
                let progress = Float(index) / Float(manuals.count)
                await MainActor.run {
                    indexingProgress = progress
                }

                guard let content = manual.content, !content.isEmpty,
                      let manualId = manual.id else { continue }

                // 使用自然语言处理
                let processedText = nlProcessor.processText(content)

                // 创建索引条目
                let entries = createEnhancedIndexEntries(
                    for: processedText,
                    manual: manual,
                    manualId: manualId
                )

                // 计算词频
                var termFreq: [String: Int] = [:]

                for entry in entries {
                    let keyword = entry.keyword.lowercased()

                    // 更新主索引
                    if newIndex[keyword] == nil {
                        newIndex[keyword] = []
                    }
                    newIndex[keyword]?.append(entry)

                    // 更新倒排索引
                    if newInvertedIndex[keyword] == nil {
                        newInvertedIndex[keyword] = Set<UUID>()
                    }
                    newInvertedIndex[keyword]?.insert(manualId)

                    // 更新词频
                    termFreq[keyword] = (termFreq[keyword] ?? 0) + 1
                    totalTerms += 1
                }

                // 更新文档频率
                for term in Set(termFreq.keys) {
                    newDocumentFrequency[term] = (newDocumentFrequency[term] ?? 0) + 1
                }

                // 保存词频
                newTermFrequency[manualId] = termFreq
                totalDocumentLength += termFreq.values.reduce(0, +)
            }

            // 计算统计信息
            let stats = IndexStatistics(
                totalDocuments: manuals.count,
                totalTerms: newDocumentFrequency.count,
                averageDocumentLength: manuals.count > 0 ? Double(totalDocumentLength) / Double(manuals.count) : 0.0,
                indexSize: calculateIndexSize(newIndex),
                lastUpdateTime: Date()
            )

            indexQueue.async { [weak self] in
                guard let self = self else { return }
                self.searchIndex = newIndex
                self.invertedIndex = newInvertedIndex
                self.documentFrequency = newDocumentFrequency
                self.termFrequency = newTermFrequency
                self.saveSearchIndex()
            }

            await MainActor.run {
                self.indexStats = stats
                self.isIndexing = false
                self.indexingProgress = 1.0
            }
            
            print("✅ 搜索索引重建完成: \(stats.description)")

        } catch {
            print("❌ 重建搜索索引失败: \(error.localizedDescription)")
            await MainActor.run {
                isIndexing = false
                indexingProgress = 0.0
            }
        }
    }

    // MARK: - 增强的索引创建方法

    private func createEnhancedIndexEntries(
        for processedText: ProcessedText,
        manual: Manual,
        manualId: UUID
    ) -> [SearchIndexEntry] {
        var entries: [SearchIndexEntry] = []
        let content = processedText.originalText

        // 1. 基于关键词创建索引
        for keyword in processedText.keywords {
            let positions = findPositions(of: keyword, in: content)
            if !positions.isEmpty {
                let entry = SearchIndexEntry(
                    manualId: manualId,
                    keyword: keyword,
                    positions: positions,
                    frequency: positions.count,
                    context: extractContext(for: keyword, in: content, positions: positions),
                    relevance: calculateRelevance(for: keyword, in: content)
                )
                entries.append(entry)
            }
        }

        // 2. 基于所有词汇创建索引（用于完整搜索）
        for token in processedText.tokens {
            if token.count > 1 && !processedText.keywords.contains(token) {
                let positions = findPositions(of: token, in: content)
                if !positions.isEmpty {
                    let entry = SearchIndexEntry(
                        manualId: manualId,
                        keyword: token,
                        positions: positions,
                        frequency: positions.count,
                        context: extractContext(for: token, in: content, positions: positions),
                        relevance: calculateRelevance(for: token, in: content)
                    )
                    entries.append(entry)
                }
            }
        }

        // 3. 创建N-gram索引（用于短语搜索）
        let ngrams = createNGrams(from: processedText.tokens, n: 2)
        for ngram in ngrams {
            let phrase = ngram.joined(separator: " ")
            let positions = findPositions(of: phrase, in: content)
            if !positions.isEmpty {
                let entry = SearchIndexEntry(
                    manualId: manualId,
                    keyword: phrase,
                    positions: positions,
                    frequency: positions.count,
                    context: extractContext(for: phrase, in: content, positions: positions),
                    relevance: calculateRelevance(for: phrase, in: content)
                )
                entries.append(entry)
            }
        }

        return entries
    }

    private func createNGrams(from tokens: [String], n: Int) -> [[String]] {
        guard tokens.count >= n else { return [] }

        var ngrams: [[String]] = []
        for i in 0...(tokens.count - n) {
            let ngram = Array(tokens[i..<(i + n)])
            ngrams.append(ngram)
        }

        return ngrams
    }

    private func calculateIndexSize(_ index: [String: [SearchIndexEntry]]) -> Int {
        // 简单估算索引大小
        var size = 0
        for (key, entries) in index {
            size += key.utf8.count
            for entry in entries {
                size += entry.keyword.utf8.count
                size += entry.positions.count * MemoryLayout<Int>.size
                size += entry.context.utf8.count
            }
        }
        return size
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
                positions: [index],
                frequency: 1,
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
    
    // MARK: - 增强的搜索功能

    /// 执行增强的全文搜索
    func performEnhancedSearch(query: String, options: SearchOptions = .default) async -> [EnhancedSearchResult] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }

        return await withCheckedContinuation { continuation in
            indexQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: [])
                    return
                }

                let results = self.performEnhancedSearchInternal(query: query, options: options)
                continuation.resume(returning: results)
            }
        }
    }

    private func performEnhancedSearchInternal(query: String, options: SearchOptions) -> [EnhancedSearchResult] {
        let processedQuery = nlProcessor.processText(query)
        var candidateDocuments: Set<UUID> = Set()
        var termMatches: [UUID: [EnhancedSearchResult.MatchedTerm]] = [:]

        // 1. 基于关键词查找候选文档
        for keyword in processedQuery.keywords {
            if let entries = searchIndex[keyword.lowercased()] {
                for entry in entries {
                    candidateDocuments.insert(entry.manualId)

                    let matchedTerm = EnhancedSearchResult.MatchedTerm(
                        term: keyword,
                        frequency: entry.frequency,
                        positions: entry.positions,
                        fieldName: "content"
                    )

                    if termMatches[entry.manualId] == nil {
                        termMatches[entry.manualId] = []
                    }
                    termMatches[entry.manualId]?.append(matchedTerm)
                }
            }
        }

        // 2. 如果关键词搜索结果不足，使用所有词汇搜索
        if candidateDocuments.count < options.minResults {
            for token in processedQuery.tokens {
                if let entries = searchIndex[token.lowercased()] {
                    for entry in entries {
                        candidateDocuments.insert(entry.manualId)

                        let matchedTerm = EnhancedSearchResult.MatchedTerm(
                            term: token,
                            frequency: entry.frequency,
                            positions: entry.positions,
                            fieldName: "content"
                        )

                        if termMatches[entry.manualId] == nil {
                            termMatches[entry.manualId] = []
                        }
                        termMatches[entry.manualId]?.append(matchedTerm)
                    }
                }
            }
        }

        // 3. 计算相关性评分并创建结果
        var results: [EnhancedSearchResult] = []
        let context = PersistenceController.shared.container.viewContext

        for documentId in candidateDocuments {
            guard let manual = fetchManual(by: documentId, in: context),
                  let matches = termMatches[documentId] else { continue }

            // 计算TF-IDF评分
            let tfIdfScore = calculateTFIDF(for: documentId, terms: matches.map { $0.term })

            // 计算相关性评分
            let relevanceScore = calculateRelevanceScore(
                matches: matches,
                queryTerms: processedQuery.keywords + processedQuery.tokens,
                tfIdfScore: tfIdfScore
            )

            // 生成高亮片段
            let snippets = generateHighlightedSnippets(
                for: manual,
                matches: matches,
                query: query
            )

            let result = EnhancedSearchResult(
                manual: manual,
                relevanceScore: relevanceScore,
                matchedTerms: matches,
                highlightedSnippets: snippets,
                tfIdfScore: tfIdfScore
            )

            results.append(result)
        }

        // 4. 按相关性排序并限制结果数量
        results.sort { $0.relevanceScore > $1.relevanceScore }

        if results.count > options.maxResults {
            results = Array(results.prefix(options.maxResults))
        }

        return results
    }

    // MARK: - 搜索功能

    /// 搜索说明书
    func searchManuals(query: String, filters: ManualSearchFilters? = nil) async -> [ManualSearchResult] {
        let keywords = tokenizeText(query)
        var results: [ManualSearchResult] = []
        
        indexQueue.sync {
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
                                        matchRanges: entry.positions.map { NSRange(location: $0, length: keyword.count) }
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
                                            matchRanges: entry.positions.map { NSRange(location: $0, length: keyword.count) }
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
        let suggestions = indexQueue.sync {
            let lowercasedQuery = query.lowercased()
            return searchIndex.keys
                .filter { $0.hasPrefix(lowercasedQuery) }
                .prefix(10)
                .map { $0 }
        }

        return Array(suggestions)
    }

    // MARK: - 搜索辅助方法

    private func fetchManual(by id: UUID, in context: NSManagedObjectContext) -> Manual? {
        let fetchRequest: NSFetchRequest<Manual> = Manual.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        fetchRequest.fetchLimit = 1

        return try? context.fetch(fetchRequest).first
    }

    private func calculateTFIDF(for documentId: UUID, terms: [String]) -> Double {
        guard let docTermFreq = termFrequency[documentId] else { return 0.0 }

        var tfIdfScore: Double = 0.0
        let totalDocs = Double(indexStats.totalDocuments)

        for term in terms {
            let tf = Double(docTermFreq[term] ?? 0)
            let df = Double(documentFrequency[term] ?? 1)

            // TF-IDF = TF * log(N/DF)
            let idf = log(totalDocs / df)
            tfIdfScore += tf * idf
        }

        return tfIdfScore
    }

    private func calculateRelevanceScore(
        matches: [EnhancedSearchResult.MatchedTerm],
        queryTerms: [String],
        tfIdfScore: Double
    ) -> Double {
        var score: Double = 0.0

        // 基础匹配分数
        let matchRatio = Double(matches.count) / Double(queryTerms.count)
        score += matchRatio * 0.4

        // TF-IDF分数权重
        score += tfIdfScore * 0.3

        // 词频分数
        let totalFrequency = matches.reduce(0) { $0 + $1.frequency }
        score += Double(totalFrequency) * 0.2

        // 位置分数（早期出现的词权重更高）
        let avgPosition = matches.reduce(0) { $0 + ($1.positions.first ?? 0) } / (matches.count > 0 ? matches.count : 1)
        let positionScore = max(0, 1.0 - Double(avgPosition) / 1000.0)
        score += positionScore * 0.1

        return score
    }

    private func generateHighlightedSnippets(
        for manual: Manual,
        matches: [EnhancedSearchResult.MatchedTerm],
        query: String
    ) -> [EnhancedSearchResult.HighlightedSnippet] {
        guard let content = manual.content else { return [] }

        var snippets: [EnhancedSearchResult.HighlightedSnippet] = []

        for match in matches.prefix(3) { // 最多3个片段
            guard let firstPosition = match.positions.first else { continue }

            let snippetRange = extractSnippetRange(
                from: content,
                around: firstPosition,
                term: match.term
            )

            let snippet = String(content[snippetRange])
            let highlightRanges = findHighlightRanges(
                in: snippet,
                for: match.term
            )

            let contextBefore = extractContext(
                from: content,
                before: snippetRange.lowerBound,
                maxLength: 50
            )

            let contextAfter = extractContext(
                from: content,
                after: snippetRange.upperBound,
                maxLength: 50
            )

            let highlightedSnippet = EnhancedSearchResult.HighlightedSnippet(
                text: snippet,
                highlightRanges: highlightRanges,
                contextBefore: contextBefore,
                contextAfter: contextAfter
            )

            snippets.append(highlightedSnippet)
        }

        return snippets
    }

    private func extractSnippetRange(
        from content: String,
        around position: Int,
        term: String
    ) -> Range<String.Index> {
        let words = content.components(separatedBy: .whitespacesAndNewlines)
        let start = max(0, position - 10)
        let end = min(words.count, position + 10)

        let snippetWords = Array(words[start..<end])
        let snippetText = snippetWords.joined(separator: " ")

        let startIndex = content.startIndex
        let endIndex = content.index(startIndex, offsetBy: min(snippetText.count, content.count))

        return startIndex..<endIndex
    }

    private func findHighlightRanges(in text: String, for term: String) -> [NSRange] {
        var ranges: [NSRange] = []
        let nsText = text as NSString
        let searchRange = NSRange(location: 0, length: nsText.length)

        var currentRange = searchRange
        while currentRange.location < nsText.length {
            let foundRange = nsText.range(
                of: term,
                options: [.caseInsensitive],
                range: currentRange
            )

            if foundRange.location == NSNotFound {
                break
            }

            ranges.append(foundRange)
            currentRange = NSRange(
                location: foundRange.location + foundRange.length,
                length: nsText.length - (foundRange.location + foundRange.length)
            )
        }

        return ranges
    }

    private func extractContext(
        from content: String,
        before index: String.Index,
        maxLength: Int
    ) -> String {
        let startIndex = content.index(
            index,
            offsetBy: -min(maxLength, content.distance(from: content.startIndex, to: index)),
            limitedBy: content.startIndex
        ) ?? content.startIndex

        return String(content[startIndex..<index])
    }

    private func extractContext(
        from content: String,
        after index: String.Index,
        maxLength: Int
    ) -> String {
        let endIndex = content.index(
            index,
            offsetBy: min(maxLength, content.distance(from: index, to: content.endIndex)),
            limitedBy: content.endIndex
        ) ?? content.endIndex

        return String(content[index..<endIndex])
    }

    private func findPositions(of term: String, in text: String) -> [Int] {
        var positions: [Int] = []
        let words = text.components(separatedBy: .whitespacesAndNewlines)

        for (index, word) in words.enumerated() {
            if word.lowercased().contains(term.lowercased()) {
                positions.append(index)
            }
        }

        return positions
    }

    private func extractContext(
        for term: String,
        in text: String,
        positions: [Int]
    ) -> String {
        guard let firstPosition = positions.first else { return "" }

        let words = text.components(separatedBy: .whitespacesAndNewlines)
        let start = max(0, firstPosition - 5)
        let end = min(words.count, firstPosition + 6)

        let contextWords = Array(words[start..<end])
        return contextWords.joined(separator: " ")
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
        
        indexQueue.async { [weak self] in
            guard let self = self else { return }
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
        indexQueue.async { [weak self] in
            guard let self = self else { return }
            for (keyword, entries) in self.searchIndex {
                self.searchIndex[keyword] = entries.filter { $0.manualId != manualId }
            }
            self.saveSearchIndex()
        }
    }
}

// MARK: - 索引统计信息
struct IndexStatistics {
    var totalDocuments: Int = 0
    var totalTerms: Int = 0
    var averageDocumentLength: Double = 0.0
    var indexSize: Int = 0
    var lastUpdateTime: Date?

    var description: String {
        return """
        索引统计:
        - 文档总数: \(totalDocuments)
        - 词汇总数: \(totalTerms)
        - 平均文档长度: \(String(format: "%.1f", averageDocumentLength))
        - 索引大小: \(ByteCountFormatter.string(fromByteCount: Int64(indexSize), countStyle: .file))
        - 最后更新: \(lastUpdateTime?.formatted() ?? "未知")
        """
    }
}

// MARK: - 自然语言处理器
class NLProcessor {
    private let tokenizer = NLTokenizer(unit: .word)
    private let tagger = NLTagger(tagSchemes: [.language, .lexicalClass])

    func processText(_ text: String) -> ProcessedText {
        // 语言检测
        let language = detectLanguage(text)

        // 分词
        let tokens = tokenizeText(text, language: language)

        // 词性标注
        let taggedTokens = tagTokens(tokens, in: text)

        // 提取关键词
        let keywords = extractKeywords(from: taggedTokens)

        return ProcessedText(
            originalText: text,
            language: language,
            tokens: tokens,
            taggedTokens: taggedTokens,
            keywords: keywords
        )
    }

    private func detectLanguage(_ text: String) -> NLLanguage? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        return recognizer.dominantLanguage
    }

    private func tokenizeText(_ text: String, language: NLLanguage?) -> [String] {
        tokenizer.string = text
        if let language = language {
            tokenizer.setLanguage(language)
        }

        var tokens: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { tokenRange, _ in
            let token = String(text[tokenRange])
            if !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                tokens.append(token.lowercased())
            }
            return true
        }

        return tokens
    }

    private func tagTokens(_ tokens: [String], in text: String) -> [TaggedToken] {
        tagger.string = text
        var taggedTokens: [TaggedToken] = []

        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass, options: []) { tag, tokenRange in
            let token = String(text[tokenRange])
            let taggedToken = TaggedToken(
                token: token.lowercased(),
                tag: tag,
                range: tokenRange
            )
            taggedTokens.append(taggedToken)
            return true
        }

        return taggedTokens
    }

    private func extractKeywords(from taggedTokens: [TaggedToken]) -> [String] {
        // 提取名词、动词、形容词作为关键词
        let keywordTags: Set<NLTag> = [.noun, .verb, .adjective, .other]

        return taggedTokens
            .filter { token in
                guard let tag = token.tag else { return false }
                return keywordTags.contains(tag) && token.token.count > 2
            }
            .map { $0.token }
            .removingDuplicates()
    }
}

// MARK: - 处理后的文本
struct ProcessedText {
    let originalText: String
    let language: NLLanguage?
    let tokens: [String]
    let taggedTokens: [TaggedToken]
    let keywords: [String]
}

// MARK: - 标记的词汇
struct TaggedToken {
    let token: String
    let tag: NLTag?
    let range: Range<String.Index>
}

// MARK: - 搜索结果增强
struct EnhancedSearchResult {
    let manual: Manual
    let relevanceScore: Double
    let matchedTerms: [MatchedTerm]
    let highlightedSnippets: [HighlightedSnippet]
    let tfIdfScore: Double

    struct MatchedTerm {
        let term: String
        let frequency: Int
        let positions: [Int]
        let fieldName: String
    }

    struct HighlightedSnippet {
        let text: String
        let highlightRanges: [NSRange]
        let contextBefore: String
        let contextAfter: String
    }
}

// MARK: - 数组扩展
extension Array where Element: Hashable {
    func removingDuplicates() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

// MARK: - 搜索索引条目
struct SearchIndexEntry: Codable {
    let manualId: UUID
    let keyword: String
    let positions: [Int]      // 支持多个位置
    let frequency: Int        // 词频
    let context: String
    let relevance: Float
    // 兼容旧用法
    var position: Int { positions.first ?? 0 }
}

// MARK: - 搜索选项
struct SearchOptions {
    let maxResults: Int
    let minResults: Int
    let includeSnippets: Bool
    let highlightMatches: Bool
    let fuzzySearch: Bool
    let phraseSearch: Bool

    static let `default` = SearchOptions(
        maxResults: 50,
        minResults: 5,
        includeSnippets: true,
        highlightMatches: true,
        fuzzySearch: true,
        phraseSearch: true
    )
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