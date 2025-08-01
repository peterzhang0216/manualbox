//
//  ComprehensiveSearchView.swift
//  ManualBox
//
//  Created by Assistant on 2024/12/19.
//  全面搜索视图 - 集成高级搜索、历史记录和收藏功能
//

import SwiftUI

struct ComprehensiveSearchView: View {
    @StateObject private var searchService = AdvancedSearchService.shared
    @State private var searchText = ""
    @State private var searchFilters = AdvancedSearchFilters()
    @State private var sortOptions = SearchSortOptions()
    @State private var showingFilters = false
    @State private var showingHistory = false
    @State private var showingSavedSearches = false
    @State private var showingSaveDialog = false
    @State private var saveSearchName = ""
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 搜索头部
                searchHeader
                
                // 标签页选择器
                tabSelector
                
                // 主要内容区域
                TabView(selection: $selectedTab) {
                    // 搜索结果
                    searchResultsTab
                        .tag(0)
                    
                    // 搜索历史
                    searchHistoryTab
                        .tag(1)
                    
                    // 保存的搜索
                    savedSearchesTab
                        .tag(2)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationTitle("高级搜索")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showingFilters = true
                    }) {
                        Image(systemName: "slider.horizontal.3")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: {
                            showingSaveDialog = true
                        }) {
                            Label("保存搜索", systemImage: "bookmark")
                        }
                        .disabled(searchText.isEmpty)
                        
                        Button(action: {
                            clearAllResults()
                        }) {
                            Label("清除结果", systemImage: "trash")
                        }
                        
                        Button(action: {
                            showingHistory = true
                        }) {
                            Label("搜索历史", systemImage: "clock")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingFilters) {
                SearchFiltersSheet(filters: $searchFilters, sortOptions: $sortOptions)
            }
            .sheet(isPresented: $showingSaveDialog) {
                SaveSearchDialog(
                    searchName: $saveSearchName,
                    onSave: {
                        saveCurrentSearch()
                    }
                )
            }
        }
        .onAppear {
            loadSuggestions()
        }
    }
    
    // MARK: - 搜索头部
    
    private var searchHeader: some View {
        VStack(spacing: 12) {
            // 主搜索栏
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("搜索产品、说明书、分类...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onSubmit {
                        performSearch()
                    }
                    .onChange(of: searchText) { newValue in
                        if newValue.count >= 2 {
                            loadSuggestions()
                        }
                    }
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                        searchService.searchResults = []
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
                
                Button(action: {
                    performSearch()
                }) {
                    Text("搜索")
                        .fontWeight(.medium)
                }
                .buttonStyle(.borderedProminent)
                .disabled(searchText.isEmpty)
            }
            
            // 搜索建议
            if !searchService.searchSuggestions.isEmpty && !searchText.isEmpty {
                searchSuggestions
            }
            
            // 快速过滤器
            quickFilters
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    private var searchSuggestions: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(searchService.searchSuggestions.prefix(8), id: \.id) { suggestion in
                    Button(action: {
                        searchText = suggestion.text
                        performSearch()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: suggestion.type.icon)
                                .font(.caption2)
                                .foregroundColor(suggestion.type.color)
                            
                            Text(suggestion.text)
                                .font(.caption)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(suggestion.type.color.opacity(0.1))
                        .foregroundColor(suggestion.type.color)
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var quickFilters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // 内容类型快速过滤
                ForEach(ContentType.allCases.prefix(4), id: \.self) { type in
                    Button(action: {
                        toggleContentType(type)
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: type.icon)
                                .font(.caption2)
                            
                            Text(type.displayName)
                                .font(.caption)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            searchFilters.contentTypes.contains(type) ? 
                            type.color : Color(.systemGray5)
                        )
                        .foregroundColor(
                            searchFilters.contentTypes.contains(type) ? 
                            .white : .primary
                        )
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                
                // 排序选项
                Menu {
                    ForEach(SearchSortOptions.SortType.allCases, id: \.self) { sortType in
                        Button(action: {
                            sortOptions.primarySort = sortType
                            if !searchService.searchResults.isEmpty {
                                sortResults()
                            }
                        }) {
                            HStack {
                                Image(systemName: sortType.icon)
                                Text(sortType.displayName)
                                
                                if sortOptions.primarySort == sortType {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                    
                    Divider()
                    
                    Button(action: {
                        sortOptions.ascending.toggle()
                        if !searchService.searchResults.isEmpty {
                            sortResults()
                        }
                    }) {
                        HStack {
                            Image(systemName: sortOptions.ascending ? "arrow.up" : "arrow.down")
                            Text(sortOptions.ascending ? "升序" : "降序")
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.caption2)
                        
                        Text("排序")
                            .font(.caption)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemGray5))
                    .foregroundColor(.primary)
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - 标签页选择器
    
    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(0..<3) { index in
                Button(action: {
                    selectedTab = index
                }) {
                    VStack(spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: tabIcon(for: index))
                                .font(.caption)
                            
                            Text(tabTitle(for: index))
                                .font(.caption)
                                .fontWeight(selectedTab == index ? .semibold : .regular)
                        }
                        
                        if selectedTab == index {
                            Rectangle()
                                .fill(Color.accentColor)
                                .frame(height: 2)
                        } else {
                            Rectangle()
                                .fill(Color.clear)
                                .frame(height: 2)
                        }
                    }
                    .foregroundColor(selectedTab == index ? .accentColor : .secondary)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal)
        .background(Color(.systemBackground))
    }
    
    // MARK: - 搜索结果标签页
    
    private var searchResultsTab: some View {
        Group {
            if searchService.isSearching {
                searchingView
            } else if searchService.searchResults.isEmpty && !searchText.isEmpty {
                noResultsView
            } else if searchService.searchResults.isEmpty {
                emptyStateView
            } else {
                searchResultsList
            }
        }
    }
    
    private var searchingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("正在搜索...")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("搜索范围: \(searchFilters.searchScopes.count) 个类型")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var noResultsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("未找到相关结果")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("尝试调整搜索条件或使用不同的关键词")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("调整筛选条件") {
                showingFilters = true
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("开始搜索")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("输入关键词搜索产品、说明书、分类和标签")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            // 最近搜索
            if !searchService.recentSearches.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("最近搜索")
                        .font(.headline)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 8) {
                        ForEach(searchService.recentSearches.prefix(4), id: \.self) { query in
                            Button(action: {
                                searchText = query
                                performSearch()
                            }) {
                                Text(query)
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color(.systemGray5))
                                    .cornerRadius(12)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var searchResultsList: some View {
        List {
            // 结果统计
            Section {
                HStack {
                    Text("找到 \(searchService.searchResults.count) 个结果")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("按\(sortOptions.primarySort.displayName)排序")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
            
            // 搜索结果
            ForEach(searchService.searchResults, id: \.id) { result in
                SearchResultRow(result: result)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
        }
        .listStyle(.plain)
        .refreshable {
            await performSearchAsync()
        }
    }
    
    // MARK: - 搜索历史标签页
    
    private var searchHistoryTab: some View {
        Group {
            if searchService.searchHistory.isEmpty {
                emptyHistoryView
            } else {
                historyList
            }
        }
    }
    
    private var emptyHistoryView: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("暂无搜索历史")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("您的搜索历史将显示在这里")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var historyList: some View {
        List {
            Section {
                Button("清空历史记录") {
                    searchService.clearSearchHistory()
                }
                .foregroundColor(.red)
            }
            
            ForEach(searchService.searchHistory, id: \.id) { item in
                HistoryItemRow(item: item) {
                    searchText = item.query
                    searchFilters = item.filters
                    selectedTab = 0
                    performSearch()
                }
            }
            .onDelete(perform: deleteHistoryItems)
        }
        .listStyle(.plain)
    }
    
    // MARK: - 保存的搜索标签页
    
    private var savedSearchesTab: some View {
        Group {
            if searchService.savedSearches.isEmpty {
                emptySavedSearchesView
            } else {
                savedSearchesList
            }
        }
    }
    
    private var emptySavedSearchesView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bookmark")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("暂无保存的搜索")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("保存常用的搜索条件以便快速访问")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var savedSearchesList: some View {
        List {
            ForEach(searchService.savedSearches, id: \.id) { savedSearch in
                SavedSearchRow(savedSearch: savedSearch) {
                    searchText = savedSearch.query
                    searchFilters = savedSearch.filters
                    selectedTab = 0
                    searchService.useSavedSearch(savedSearch)
                }
            }
            .onDelete(perform: deleteSavedSearches)
        }
        .listStyle(.plain)
    }
    
    // MARK: - 辅助方法
    
    private func tabIcon(for index: Int) -> String {
        switch index {
        case 0: return "magnifyingglass"
        case 1: return "clock"
        case 2: return "bookmark"
        default: return "questionmark"
        }
    }
    
    private func tabTitle(for index: Int) -> String {
        switch index {
        case 0: return "搜索结果"
        case 1: return "历史记录"
        case 2: return "保存的搜索"
        default: return "未知"
        }
    }
    
    private func toggleContentType(_ type: ContentType) {
        if searchFilters.contentTypes.contains(type) {
            searchFilters.contentTypes.remove(type)
        } else {
            searchFilters.contentTypes.insert(type)
        }
        
        if !searchText.isEmpty {
            performSearch()
        }
    }
    
    private func performSearch() {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        Task {
            await performSearchAsync()
        }
    }
    
    private func performSearchAsync() async {
        await searchService.performAdvancedSearch(
            query: searchText,
            filters: searchFilters,
            sortOptions: sortOptions
        )
    }
    
    private func sortResults() {
        searchService.searchResults = searchService.sortResults(
            searchService.searchResults,
            by: sortOptions
        )
    }
    
    private func loadSuggestions() {
        Task {
            await searchService.getSearchSuggestions(for: searchText)
        }
    }
    
    private func saveCurrentSearch() {
        guard !saveSearchName.isEmpty && !searchText.isEmpty else { return }
        
        searchService.saveSearch(
            name: saveSearchName,
            query: searchText,
            filters: searchFilters
        )
        
        saveSearchName = ""
        showingSaveDialog = false
    }
    
    private func clearAllResults() {
        searchText = ""
        searchService.searchResults = []
        searchFilters = AdvancedSearchFilters()
        sortOptions = SearchSortOptions()
    }
    
    private func deleteHistoryItems(offsets: IndexSet) {
        for index in offsets {
            let item = searchService.searchHistory[index]
            searchService.deleteHistoryItem(item)
        }
    }
    
    private func deleteSavedSearches(offsets: IndexSet) {
        for index in offsets {
            let savedSearch = searchService.savedSearches[index]
            searchService.deleteSavedSearch(savedSearch)
        }
    }
}

// MARK: - 搜索结果行
struct SearchResultRow: View {
    let result: AdvancedSearchResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 头部信息
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.entity.displayName)
                        .font(.headline)
                        .lineLimit(2)
                    
                    if let subtitle = result.entity.subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: entityIcon(for: result.entity.entityType))
                            .font(.caption)
                            .foregroundColor(entityColor(for: result.entity.entityType))
                        
                        Text(result.entity.entityType.rawValue.capitalized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("相关度: \(String(format: "%.1f", result.relevanceScore * 100))%")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
            }
            
            // 匹配字段
            if !result.matchedFields.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(result.matchedFields, id: \.self) { field in
                            Text(fieldDisplayName(field))
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.2))
                                .foregroundColor(.green)
                                .cornerRadius(4)
                        }
                    }
                    .padding(.horizontal, 1)
                }
            }
            
            // 高亮片段
            if !result.highlights.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(result.highlights.prefix(2), id: \.self) { highlight in
                        Text(highlight)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(.systemGray6))
                            .cornerRadius(6)
                    }
                }
            }
            
            // 元数据
            if let createdAt = result.entity.createdAt {
                HStack {
                    Image(systemName: "calendar")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text(createdAt, style: .date)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    if let fileSize = result.entity.fileSize {
                        Spacer()
                        
                        Image(systemName: "doc")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text(ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func entityIcon(for type: SearchableEntity.EntityType) -> String {
        switch type {
        case .product: return "cube.box"
        case .manual: return "doc.text"
        case .category: return "folder"
        case .tag: return "tag"
        }
    }
    
    private func entityColor(for type: SearchableEntity.EntityType) -> Color {
        switch type {
        case .product: return .blue
        case .manual: return .green
        case .category: return .orange
        case .tag: return .purple
        }
    }
    
    private func fieldDisplayName(_ field: String) -> String {
        switch field {
        case "name": return "名称"
        case "brand": return "品牌"
        case "model": return "型号"
        case "fileName": return "文件名"
        case "content": return "内容"
        default: return field
        }
    }
}

// MARK: - 历史记录行
struct HistoryItemRow: View {
    let item: SearchHistoryItem
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.query)
                        .font(.body)
                        .foregroundColor(.primary)
                    
                    HStack {
                        Text(item.timestamp, style: .relative)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("\(item.resultCount) 个结果")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 保存的搜索行
struct SavedSearchRow: View {
    let savedSearch: SavedSearchItem
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(savedSearch.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(savedSearch.query)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    HStack {
                        Text("创建于 \(savedSearch.createdAt, style: .date)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if let lastUsed = savedSearch.lastUsed {
                            Text("•")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("上次使用 \(lastUsed, style: .relative)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("使用 \(savedSearch.useCount) 次")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "bookmark.fill")
                    .font(.caption)
                    .foregroundColor(.accentColor)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 搜索过滤器弹窗
struct SearchFiltersSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var filters: AdvancedSearchFilters
    @Binding var sortOptions: SearchSortOptions
    
    var body: some View {
        NavigationView {
            AdvancedSearchFiltersView(filters: $filters)
                .navigationTitle("搜索筛选")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("取消") {
                            dismiss()
                        }
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("完成") {
                            dismiss()
                        }
                    }
                }
        }
    }
}

// MARK: - 保存搜索对话框
struct SaveSearchDialog: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var searchName: String
    let onSave: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("保存搜索")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                TextField("搜索名称", text: $searchName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                HStack(spacing: 12) {
                    Button("取消") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("保存") {
                        onSave()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(searchName.isEmpty)
                }
            }
            .padding()
            .navigationBarHidden(true)
        }
        .presentationDetents([.height(200)])
    }
}

#Preview {
    ComprehensiveSearchView()
}