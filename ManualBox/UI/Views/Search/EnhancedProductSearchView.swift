import SwiftUI
import Combine

// MARK: - 增强产品搜索视图
struct EnhancedProductSearchView: View {
    @StateObject private var searchService = EnhancedProductSearchService.shared
    @State private var searchText = ""
    @State private var searchFilters = ProductSearchFilters()
    @State private var sortBy: ProductSearchSort = .name
    @State private var showingFilters = false
    @State private var showingSavedSearches = false
    @State private var showingSaveSearch = false
    @State private var showingSuggestions = false
    @State private var selectedSuggestion: SearchSuggestion?
    @State private var searchCancellable: AnyCancellable?
    
    // 保存搜索相关状态
    @State private var saveSearchName = ""
    @State private var showingSaveSearchAlert = false
    @State private var searchTimer: Timer?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 搜索栏
                searchHeader
                
                // 过滤器指示器
                if searchFilters.hasActiveFilters {
                    filterIndicator
                }
                
                // 搜索建议
                if showingSuggestions && !searchService.searchSuggestions.isEmpty {
                    suggestionsView
                }
                
                Divider()
                
                // 搜索结果
                searchResultsView
            }
            .navigationTitle("产品搜索")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                SwiftUI.ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        showingSavedSearches = true
                    }) {
                        Image(systemName: "bookmark")
                    }
                }
                
                SwiftUI.ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button(action: {
                            showingFilters = true
                        }) {
                            Label("过滤器", systemImage: "line.3.horizontal.decrease.circle")
                        }
                        
                        if !searchText.isEmpty {
                            Button(action: {
                                showingSaveSearchAlert = true
                            }) {
                                Label("保存搜索", systemImage: "bookmark.badge.plus")
                            }
                        }
                        
                        Divider()
                        
                        Menu("排序方式") {
                            ForEach(ProductSearchSort.allCases, id: \.self) { sort in
                                Button(action: {
                                    sortBy = sort
                                    performSearch()
                                }) {
                                    HStack {
                                        Text(sort.displayName)
                                        if sortBy == sort {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showingFilters) {
            ProductSearchFiltersView(filters: $searchFilters) {
                performSearch()
            }
        }
        .sheet(isPresented: $showingSavedSearches) {
            SavedSearchesView { savedSearch in
                loadSavedSearch(savedSearch)
            }
        }
        .alert("保存搜索", isPresented: $showingSaveSearchAlert) {
            TextField("搜索名称", text: $saveSearchName)
            Button("保存") {
                saveCurrentSearch()
            }
            Button("取消", role: .cancel) { }
        } message: {
            Text("为当前搜索条件起一个名称")
        }
        .onAppear {
            setupSearchDebouncing()
        }
    }
    
    // MARK: - 搜索栏
    private var searchHeader: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("搜索产品...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        performSearch()
                        hideSuggestions()
                    }
                    .onChange(of: searchText) { _, newValue in
                        handleSearchTextChange(newValue)
                    }
                
                if !searchText.isEmpty {
                    Button("清除") {
                        clearSearch()
                    }
                    .foregroundColor(.secondary)
                }
            }
            
            // 快速搜索按钮
            if searchText.isEmpty && !searchService.searchHistory.isEmpty {
                quickSearchButtons
            }
        }
        .padding()
        #if os(macOS)
        .background(Color(nsColor: .windowBackgroundColor))
        #else
        .background(Color(.systemGray5))
        #endif
    }
    
    // MARK: - 过滤器指示器
    private var filterIndicator: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Text("已应用 \(searchFilters.filterCount) 个过滤器:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                ForEach(getActiveFilterDescriptions(), id: \.self) { description in
                    SearchFilterChip(text: description) {
                        // 点击移除特定过滤器的逻辑
                    }
                }
                
                Button("清除全部") {
                    searchFilters = ProductSearchFilters()
                    performSearch()
                }
                .font(.caption)
                .foregroundColor(.red)
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        #if os(macOS)
        .background(Color(nsColor: .windowBackgroundColor))
        #else
        .background(Color(.systemGray5))
        #endif
    }
    
    // MARK: - 搜索建议
    private var suggestionsView: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(searchService.searchSuggestions.prefix(6), id: \.id) { suggestion in
                SuggestionRow(suggestion: suggestion) {
                    selectSuggestion(suggestion)
                }
            }
        }
        #if os(macOS)
        .background(Color(nsColor: .windowBackgroundColor))
        #else
        .background(Color(.systemBackground))
        #endif
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        .padding(.horizontal)
    }
    
    // MARK: - 快速搜索按钮
    private var quickSearchButtons: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("最近搜索")
                .font(.caption)
                .foregroundColor(.secondary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(searchService.searchHistory.prefix(5), id: \.self) { query in
                        Button(query) {
                            searchText = query
                            performSearch()
                        }
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        #if os(macOS)
                        .background(Color(nsColor: .windowBackgroundColor))
                        #else
                        .background(Color(.systemGray5))
                        #endif
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - 搜索结果
    private var searchResultsView: some View {
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
            
            Text("搜索中...")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var noResultsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("未找到相关产品")
                .font(.title2)
                .fontWeight(.medium)
            
            Text("尝试使用不同的关键词或调整搜索过滤器")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("调整过滤器") {
                showingFilters = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "cube.box")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("开始搜索产品")
                .font(.title2)
                .fontWeight(.medium)
            
            Text("输入产品名称、品牌或型号来搜索您的产品")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var searchResultsList: some View {
        List {
            // 搜索结果统计
            Section {
                HStack {
                    Text("找到 \(searchService.searchResults.count) 个产品")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("按\(sortBy.displayName)排序")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // 搜索结果列表
            ForEach(searchService.searchResults, id: \.id) { result in
                ProductSearchResultRow(result: result, searchQuery: searchText)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
        }
        .listStyle(.plain)
    }
    
    // MARK: - 操作方法
    
    private func setupSearchDebouncing() {
        // 使用Timer来处理搜索延迟
        searchTimer?.invalidate()
        searchTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { _ in
            if searchText.count >= 2 {
                loadSuggestions(for: searchText)
                showingSuggestions = true
            } else {
                showingSuggestions = false
            }
        }
    }
    
    private func handleSearchTextChange(_ newValue: String) {
        if newValue.isEmpty {
            searchService.searchResults = []
            showingSuggestions = false
        }
    }
    
    private func performSearch() {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        hideSuggestions()
        
        Task {
            await searchService.searchProducts(
                query: searchText,
                filters: searchFilters,
                sortBy: sortBy
            )
        }
    }
    
    private func loadSuggestions(for query: String) {
        Task {
            let suggestions = await searchService.getSearchSuggestions(for: query)
            await MainActor.run {
                searchService.searchSuggestions = suggestions
            }
        }
    }
    
    private func selectSuggestion(_ suggestion: SearchSuggestion) {
        searchText = suggestion.text
        hideSuggestions()
        performSearch()
    }
    
    private func hideSuggestions() {
        showingSuggestions = false
    }
    
    private func clearSearch() {
        searchText = ""
        searchService.searchResults = []
        showingSuggestions = false
    }
    
    private func saveCurrentSearch() {
        guard !saveSearchName.isEmpty else { return }
        
        searchService.saveSearch(
            query: searchText,
            filters: searchFilters,
            name: saveSearchName
        )
        
        saveSearchName = ""
    }
    
    private func loadSavedSearch(_ savedSearch: SavedSearch) {
        searchText = savedSearch.query
        // 转换SavedSearchFilters到ProductSearchFilters
        let newFilters = ProductSearchFilters()
        // 这里需要根据实际的SavedSearchFilters结构进行转换
        // 暂时使用空的过滤器
        searchFilters = newFilters
        performSearch()
        showingSavedSearches = false
    }
    
    private func getActiveFilterDescriptions() -> [String] {
        var descriptions: [String] = []
        
        if searchFilters.categoryId != nil {
            descriptions.append("分类")
        }
        
        if !searchFilters.tagIds.isEmpty {
            descriptions.append("标签(\(searchFilters.tagIds.count))")
        }
        
        if searchFilters.minPrice != nil || searchFilters.maxPrice != nil {
            descriptions.append("价格")
        }
        
        if searchFilters.startDate != nil || searchFilters.endDate != nil {
            descriptions.append("日期")
        }
        
        if searchFilters.warrantyStatus != nil {
            descriptions.append("保修状态")
        }
        
        return descriptions
    }
}

// MARK: - 过滤器芯片
struct SearchFilterChip: View {
    let text: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.caption)
                .fontWeight(.medium)
            
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.caption2)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.accentColor.opacity(0.1))
        .foregroundColor(.accentColor)
        .cornerRadius(8)
    }
}

// MARK: - 搜索建议行
struct SuggestionRow: View {
    let suggestion: SearchSuggestion
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: suggestion.type.iconName)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .frame(width: 20)
                
                Text(suggestion.text)
                    .font(.body)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "arrow.up.left")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 产品搜索结果行
struct ProductSearchResultRow: View {
    let result: ProductSearchResult
    let searchQuery: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 产品基本信息
            HStack(spacing: 12) {
                // 产品图片占位符
                RoundedRectangle(cornerRadius: 8)
                    #if os(macOS)
                    .fill(Color(nsColor: .windowBackgroundColor))
                    #else
                    .fill(Color(.systemGray5))
                    #endif
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: "cube.box")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    // 产品名称（高亮匹配）
                    Text(highlightedText(result.product.productName, query: searchQuery))
                        .font(.headline)
                        .fontWeight(.medium)
                        .lineLimit(2)

                    // 品牌和型号
                    HStack(spacing: 8) {
                        if !result.product.productBrand.isEmpty {
                            Text(result.product.productBrand)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        if !result.product.productModel.isEmpty {
                            Text("•")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Text(result.product.productModel)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    // 分类和标签
                    HStack(spacing: 8) {
                        if let category = result.product.category {
                            HStack(spacing: 4) {
                                Image(systemName: category.categoryIcon)
                                    .font(.caption2)
                                    .foregroundColor(Color(category.categoryColor))

                                Text(category.categoryName)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        if let tags = result.product.tags as? Set<Tag>, !tags.isEmpty {
                            ForEach(Array(tags.prefix(2)), id: \.id) { tag in
                                Text(tag.tagName)
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color(tag.tagColor).opacity(0.2))
                                    .foregroundColor(Color(tag.tagColor))
                                    .cornerRadius(4)
                            }
                        }
                    }
                }

                Spacer()

                // 相关性评分和价格
                VStack(alignment: .trailing, spacing: 4) {
                    // 相关性评分
                    HStack(spacing: 2) {
                        ForEach(0..<5) { index in
                            Image(systemName: index < Int(result.relevanceScore) ? "star.fill" : "star")
                                .font(.caption2)
                                .foregroundColor(.yellow)
                        }
                    }

                    // 价格
                    if let price = result.product.order?.price?.doubleValue {
                        Text("¥\(price, specifier: "%.2f")")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.green)
                    }
                }
            }

            // 匹配字段指示器
            if !result.matchedFields.isEmpty {
                HStack {
                    Text("匹配:")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    ForEach(result.matchedFields.prefix(3), id: \.self) { field in
                        Text(field)
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.accentColor.opacity(0.1))
                            .foregroundColor(.accentColor)
                            .cornerRadius(3)
                    }

                    if result.matchedFields.count > 3 {
                        Text("+\(result.matchedFields.count - 3)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
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
                            #if os(macOS)
                            .background(Color(nsColor: .controlBackgroundColor))
                            #else
                            .background(Color(.systemGray6))
                            #endif
                            .cornerRadius(4)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }

    private func highlightedText(_ text: String, query: String) -> AttributedString {
        var attributedString = AttributedString(text)

        // 简单的高亮实现
        if let range = text.range(of: query, options: .caseInsensitive) {
            let nsRange = NSRange(range, in: text)
            if let attributedRange = Range(nsRange, in: attributedString) {
                attributedString[attributedRange].backgroundColor = .yellow.opacity(0.3)
            }
        }

        return attributedString
    }
}

#Preview {
    EnhancedProductSearchView()
}
