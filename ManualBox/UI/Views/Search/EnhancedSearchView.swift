//
//  EnhancedSearchView.swift
//  ManualBox
//
//  Created by Assistant on 2025/6/24.
//

import SwiftUI

// MARK: - 增强搜索界面
struct EnhancedSearchView: View {
    @State private var searchText = ""
    @State private var searchResults: [EnhancedSearchResult] = []
    @State private var isSearching = false
    @State private var showingFilters = false
    @State private var showingAdvancedFilters = false
    @State private var searchOptions = SearchOptions.default
    @State private var advancedFilters = AdvancedSearchFilters()
    @State private var searchSuggestions: [SearchSuggestion] = []
    @State private var showingSuggestions = false

    @ObservedObject private var searchIndexService = ManualSearchIndexService.shared
    @StateObject private var suggestionService = IntelligentSearchSuggestionService.shared
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                searchHeader
                
                if showingSuggestions && !searchSuggestions.isEmpty {
                    suggestionsView
                }
                
                if isSearching {
                    searchingView
                } else if searchResults.isEmpty && !searchText.isEmpty {
                    noResultsView
                } else {
                    OptimizedSearchResultsView(
                        searchResults: searchResults,
                        searchQuery: searchText
                    )
                }
                
                Spacer()
            }
            .navigationTitle("智能搜索")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                SwiftUI.ToolbarItem(placement: .topBarLeading) {
                    Button("高级筛选") {
                        showingAdvancedFilters.toggle()
                    }
                }

                SwiftUI.ToolbarItem(placement: .topBarTrailing) {
                    Button("筛选") {
                        showingFilters.toggle()
                    }
                }
            }
            .sheet(isPresented: $showingFilters) {
                searchFiltersView
            }
            .sheet(isPresented: $showingAdvancedFilters) {
                AdvancedSearchFiltersView(filters: $advancedFilters)
            }
        }
        .onAppear {
            loadIntelligentSuggestions()
        }
    }
    
    // MARK: - 搜索头部
    private var searchHeader: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("搜索说明书内容...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        performSearch()
                    }
                    .onChange(of: searchText) { newValue in
                        if newValue.count > 2 {
                            loadIntelligentSuggestions(for: newValue)
                            showingSuggestions = true
                        } else {
                            showingSuggestions = false
                        }
                    }
                
                if !searchText.isEmpty {
                    Button("清除") {
                        searchText = ""
                        searchResults = []
                        showingSuggestions = false
                    }
                    .foregroundColor(.secondary)
                }
            }
            
            // 搜索选项
            HStack {
                Toggle("模糊搜索", isOn: $searchOptions.fuzzySearch)
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                
                Spacer()
                
                Toggle("短语搜索", isOn: $searchOptions.phraseSearch)
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                
                Spacer()
                
                Toggle("高亮匹配", isOn: $searchOptions.highlightMatches)
                    .toggleStyle(.switch)
                    .controlSize(.mini)
            }
            .font(.caption)
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    // MARK: - 智能搜索建议
    private var suggestionsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(searchSuggestions, id: \.id) { suggestion in
                    Button(action: {
                        searchText = suggestion.text
                        showingSuggestions = false
                        suggestionService.addToSearchHistory(suggestion.text)
                        performSearch()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: suggestion.type.icon)
                                .font(.caption2)
                                .foregroundColor(suggestion.type == .history ? .orange : .blue)

                            Text(suggestion.text)
                                .font(.caption)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            suggestion.type == .history ?
                            Color.orange.opacity(0.1) :
                            Color.blue.opacity(0.1)
                        )
                        .foregroundColor(
                            suggestion.type == .history ? .orange : .blue
                        )
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }
    
    // MARK: - 搜索中视图
    private var searchingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("正在搜索...")
                .font(.headline)
                .foregroundColor(.secondary)
            
            if searchIndexService.isIndexing {
                VStack(spacing: 8) {
                    Text("正在建立索引...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ProgressView(value: searchIndexService.indexingProgress)
                        .frame(width: 200)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - 无结果视图
    private var noResultsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("未找到相关内容")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("尝试使用不同的关键词或检查拼写")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("重建搜索索引") {
                Task {
                    await searchIndexService.rebuildIndex()
                }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - 搜索结果列表
    private var searchResultsList: some View {
        List(searchResults, id: \.manual.id) { result in
            SearchResultRow(result: result, searchOptions: searchOptions)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        }
        .listStyle(.plain)
    }
    
    // MARK: - 搜索筛选视图
    private var searchFiltersView: some View {
        NavigationView {
            Form {
                Section("搜索选项") {
                    Stepper("最大结果数: \(searchOptions.maxResults)", 
                           value: $searchOptions.maxResults, 
                           in: 10...100, 
                           step: 10)
                    
                    Toggle("包含摘要", isOn: $searchOptions.includeSnippets)
                    Toggle("模糊搜索", isOn: $searchOptions.fuzzySearch)
                    Toggle("短语搜索", isOn: $searchOptions.phraseSearch)
                    Toggle("高亮匹配", isOn: $searchOptions.highlightMatches)
                }
                
                Section("索引信息") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(searchIndexService.indexStats.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("索引管理") {
                    Button("重建索引") {
                        Task {
                            await searchIndexService.rebuildIndex()
                        }
                    }
                    .disabled(searchIndexService.isIndexing)
                    
                    if searchIndexService.isIndexing {
                        HStack {
                            Text("索引构建中...")
                            Spacer()
                            ProgressView(value: searchIndexService.indexingProgress)
                                .frame(width: 100)
                        }
                    }
                }
            }
            .navigationTitle("搜索设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                SwiftUI.ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        showingFilters = false
                    }
                }
            }
        }
    }
    
    // MARK: - 搜索方法
    
    private func performSearch() {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        isSearching = true
        showingSuggestions = false

        // 添加到搜索历史
        suggestionService.addToSearchHistory(searchText)

        Task {
            let results = await searchIndexService.performEnhancedSearch(
                query: searchText,
                options: searchOptions
            )

            await MainActor.run {
                self.searchResults = results
                self.isSearching = false
            }
        }
    }

    private func loadIntelligentSuggestions(for query: String = "") {
        Task {
            let suggestions = await suggestionService.generateSuggestions(for: query)
            await MainActor.run {
                self.searchSuggestions = suggestions
            }
        }
    }
}

// MARK: - 搜索结果行
struct SearchResultRow: View {
    let result: EnhancedSearchResult
    let searchOptions: SearchOptions
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 头部信息
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.manual.fileName ?? "未知文件")
                        .font(.headline)
                        .lineLimit(1)
                    
                    if let productName = result.manual.product?.name {
                        Text(productName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("相关度: \(String(format: "%.2f", result.relevanceScore))")
                        .font(.caption)
                        .foregroundColor(.blue)
                    
                    Text("TF-IDF: \(String(format: "%.2f", result.tfIdfScore))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            // 匹配的词汇
            if !result.matchedTerms.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(result.matchedTerms.prefix(5), id: \.term) { term in
                            Text(term.term)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.green.opacity(0.2))
                                .foregroundColor(.green)
                                .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal, 1)
                }
            }
            
            // 高亮片段
            if searchOptions.includeSnippets && !result.highlightedSnippets.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(result.highlightedSnippets.prefix(2), id: \.text) { snippet in
                        Text(snippet.text)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 预览
struct EnhancedSearchView_Previews: PreviewProvider {
    static var previews: some View {
        EnhancedSearchView()
    }
}
