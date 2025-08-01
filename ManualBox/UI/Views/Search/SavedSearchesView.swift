//
//  SavedSearchesView.swift
//  ManualBox
//
//  Created by Assistant on 2024/12/19.
//  保存的搜索管理视图 - 管理和使用保存的搜索
//

import SwiftUI

struct SavedSearchesView: View {
    @StateObject private var searchService = AdvancedSearchService.shared
    @State private var showingAddSearch = false
    @State private var editingSearch: SavedSearchItem?
    @State private var searchToRename: SavedSearchItem?
    @State private var newSearchName = ""
    @State private var selectedSortOption = SavedSearchSortOption.lastUsed
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 顶部控制栏
                topControlBar
                
                // 搜索列表
                if searchService.savedSearches.isEmpty {
                    emptyStateView
                } else {
                    savedSearchesList
                }
            }
            .navigationTitle("保存的搜索")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddSearch = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSearch) {
                AddSavedSearchSheet()
            }
            .sheet(item: $searchToRename) { search in
                RenameSearchSheet(
                    search: search,
                    newName: $newSearchName
                ) {
                    searchService.renameSavedSearch(search, newName: newSearchName)
                    searchToRename = nil
                    newSearchName = ""
                }
            }
        }
    }
    
    // MARK: - 顶部控制栏
    
    private var topControlBar: some View {
        VStack(spacing: 12) {
            // 统计信息
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("共 \(searchService.savedSearches.count) 个保存的搜索")
                        .font(.headline)
                    
                    if !searchService.savedSearches.isEmpty {
                        let totalUses = searchService.savedSearches.reduce(0) { $0 + $1.useCount }
                        Text("总使用次数: \(totalUses)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // 排序选项
                Menu {
                    ForEach(SavedSearchSortOption.allCases, id: \.self) { option in
                        Button(action: {
                            selectedSortOption = option
                        }) {
                            HStack {
                                Text(option.displayName)
                                
                                if selectedSortOption == option {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.caption)
                        
                        Text(selectedSortOption.displayName)
                            .font(.caption)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemGray5))
                    .cornerRadius(6)
                }
            }
            
            // 快速操作
            if !searchService.savedSearches.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        // 最常用的搜索
                        if let mostUsed = searchService.savedSearches.max(by: { $0.useCount < $1.useCount }) {
                            QuickActionButton(
                                title: "最常用",
                                subtitle: mostUsed.name,
                                icon: "star.fill",
                                color: .yellow
                            ) {
                                searchService.useSavedSearch(mostUsed)
                            }
                        }
                        
                        // 最近使用的搜索
                        if let recentlyUsed = searchService.savedSearches
                            .filter({ $0.lastUsed != nil })
                            .max(by: { $0.lastUsed! < $1.lastUsed! }) {
                            QuickActionButton(
                                title: "最近使用",
                                subtitle: recentlyUsed.name,
                                icon: "clock.fill",
                                color: .blue
                            ) {
                                searchService.useSavedSearch(recentlyUsed)
                            }
                        }
                        
                        // 最新创建的搜索
                        if let newest = searchService.savedSearches.max(by: { $0.createdAt < $1.createdAt }) {
                            QuickActionButton(
                                title: "最新创建",
                                subtitle: newest.name,
                                icon: "plus.circle.fill",
                                color: .green
                            ) {
                                searchService.useSavedSearch(newest)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    // MARK: - 空状态视图
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "bookmark.slash")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("暂无保存的搜索")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("保存常用的搜索条件，以便快速访问和重复使用")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: {
                showingAddSearch = true
            }) {
                HStack {
                    Image(systemName: "plus")
                    Text("创建保存的搜索")
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - 保存的搜索列表
    
    private var savedSearchesList: some View {
        List {
            ForEach(sortedSavedSearches, id: \.id) { savedSearch in
                SavedSearchItemRow(
                    savedSearch: savedSearch,
                    onUse: {
                        searchService.useSavedSearch(savedSearch)
                    },
                    onEdit: {
                        editingSearch = savedSearch
                    },
                    onRename: {
                        searchToRename = savedSearch
                        newSearchName = savedSearch.name
                    },
                    onDelete: {
                        searchService.deleteSavedSearch(savedSearch)
                    }
                )
            }
            .onDelete(perform: deleteSavedSearches)
        }
        .listStyle(.plain)
        .refreshable {
            // 刷新搜索列表
        }
    }
    
    // MARK: - 计算属性
    
    private var sortedSavedSearches: [SavedSearchItem] {
        switch selectedSortOption {
        case .name:
            return searchService.savedSearches.sorted { $0.name < $1.name }
        case .createdDate:
            return searchService.savedSearches.sorted { $0.createdAt > $1.createdAt }
        case .lastUsed:
            return searchService.savedSearches.sorted { search1, search2 in
                guard let date1 = search1.lastUsed else { return false }
                guard let date2 = search2.lastUsed else { return true }
                return date1 > date2
            }
        case .useCount:
            return searchService.savedSearches.sorted { $0.useCount > $1.useCount }
        }
    }
    
    // MARK: - 辅助方法
    
    private func deleteSavedSearches(offsets: IndexSet) {
        for index in offsets {
            let savedSearch = sortedSavedSearches[index]
            searchService.deleteSavedSearch(savedSearch)
        }
    }
}

// MARK: - 保存的搜索项行
struct SavedSearchItemRow: View {
    let savedSearch: SavedSearchItem
    let onUse: () -> Void
    let onEdit: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 头部信息
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(savedSearch.name)
                        .font(.headline)
                        .lineLimit(1)
                    
                    Text(savedSearch.query)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                // 使用按钮
                Button(action: onUse) {
                    HStack(spacing: 4) {
                        Image(systemName: "magnifyingglass")
                            .font(.caption)
                        
                        Text("使用")
                            .font(.caption)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            
            // 过滤器信息
            if hasActiveFilters {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(activeFilterDescriptions, id: \.self) { description in
                            Text(description)
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.2))
                                .foregroundColor(.blue)
                                .cornerRadius(4)
                        }
                    }
                    .padding(.horizontal, 1)
                }
            }
            
            // 统计信息
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text("创建于 \(savedSearch.createdAt, style: .date)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                if let lastUsed = savedSearch.lastUsed {
                    Text("•")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text("上次使用 \(lastUsed, style: .relative)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Text("•")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 4) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text("使用 \(savedSearch.useCount) 次")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
        }
        .padding(.vertical, 4)
        .contextMenu {
            Button(action: onUse) {
                Label("使用搜索", systemImage: "magnifyingglass")
            }
            
            Button(action: onRename) {
                Label("重命名", systemImage: "pencil")
            }
            
            Button(action: onEdit) {
                Label("编辑", systemImage: "slider.horizontal.3")
            }
            
            Divider()
            
            Button(action: onDelete) {
                Label("删除", systemImage: "trash")
            }
            .foregroundColor(.red)
        }
    }
    
    // MARK: - 计算属性
    
    private var hasActiveFilters: Bool {
        return !savedSearch.filters.selectedCategories.isEmpty ||
               !savedSearch.filters.selectedTags.isEmpty ||
               savedSearch.filters.enableDateFilter ||
               savedSearch.filters.enableFileSizeFilter ||
               savedSearch.filters.searchScopes.count < AdvancedSearchScope.allCases.count
    }
    
    private var activeFilterDescriptions: [String] {
        var descriptions: [String] = []
        
        if !savedSearch.filters.selectedCategories.isEmpty {
            descriptions.append("分类筛选")
        }
        
        if !savedSearch.filters.selectedTags.isEmpty {
            descriptions.append("标签筛选")
        }
        
        if savedSearch.filters.enableDateFilter {
            descriptions.append("时间范围")
        }
        
        if savedSearch.filters.enableFileSizeFilter {
            descriptions.append("文件大小")
        }
        
        if savedSearch.filters.searchScopes.count < AdvancedSearchScope.allCases.count {
            descriptions.append("搜索范围")
        }
        
        if savedSearch.filters.enableFuzzySearch {
            descriptions.append("模糊搜索")
        }
        
        if savedSearch.filters.caseSensitive {
            descriptions.append("区分大小写")
        }
        
        return descriptions
    }
}

// MARK: - 快速操作按钮
struct QuickActionButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                
                VStack(spacing: 2) {
                    Text(title)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 添加保存的搜索弹窗
struct AddSavedSearchSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var searchService = AdvancedSearchService.shared
    @State private var searchName = ""
    @State private var searchQuery = ""
    @State private var searchFilters = AdvancedSearchFilters()
    
    var body: some View {
        NavigationView {
            Form {
                Section("基本信息") {
                    TextField("搜索名称", text: $searchName)
                    TextField("搜索查询", text: $searchQuery)
                }
                
                Section("搜索范围") {
                    ForEach(AdvancedSearchScope.allCases, id: \.self) { scope in
                        HStack {
                            Image(systemName: scope.icon)
                                .foregroundColor(scope.color)
                                .frame(width: 20)
                            
                            Text(scope.displayName)
                            
                            Spacer()
                            
                            Toggle("", isOn: Binding(
                                get: { searchFilters.searchScopes.contains(scope) },
                                set: { isOn in
                                    if isOn {
                                        searchFilters.searchScopes.insert(scope)
                                    } else {
                                        searchFilters.searchScopes.remove(scope)
                                    }
                                }
                            ))
                            .labelsHidden()
                        }
                    }
                }
                
                Section("高级选项") {
                    Toggle("模糊搜索", isOn: $searchFilters.enableFuzzySearch)
                    Toggle("同义词搜索", isOn: $searchFilters.enableSynonymSearch)
                    Toggle("区分大小写", isOn: $searchFilters.caseSensitive)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("最大结果数")
                            Spacer()
                            Text("\(searchFilters.maxResults)")
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(
                            value: Binding(
                                get: { Double(searchFilters.maxResults) },
                                set: { searchFilters.maxResults = Int($0) }
                            ),
                            in: 10...200,
                            step: 10
                        )
                    }
                }
            }
            .navigationTitle("新建保存的搜索")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveSearch()
                    }
                    .disabled(searchName.isEmpty || searchQuery.isEmpty)
                }
            }
        }
    }
    
    private func saveSearch() {
        searchService.saveSearch(
            name: searchName,
            query: searchQuery,
            filters: searchFilters
        )
        dismiss()
    }
}

// MARK: - 重命名搜索弹窗
struct RenameSearchSheet: View {
    @Environment(\.dismiss) private var dismiss
    let search: SavedSearchItem
    @Binding var newName: String
    let onSave: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("重命名搜索")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                TextField("搜索名称", text: $newName)
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
                    .disabled(newName.isEmpty || newName == search.name)
                }
            }
            .padding()
            .navigationBarHidden(true)
        }
        .presentationDetents([.height(200)])
    }
}

// MARK: - 排序选项枚举
enum SavedSearchSortOption: String, CaseIterable {
    case name = "name"
    case createdDate = "created_date"
    case lastUsed = "last_used"
    case useCount = "use_count"
    
    var displayName: String {
        switch self {
        case .name: return "名称"
        case .createdDate: return "创建时间"
        case .lastUsed: return "最近使用"
        case .useCount: return "使用次数"
        }
    }
}

#Preview {
    SavedSearchesView()
}