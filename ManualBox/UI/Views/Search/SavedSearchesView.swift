import SwiftUI

// MARK: - 保存的搜索视图
struct SavedSearchesView: View {
    let onSelectSearch: (SavedSearch) -> Void
    
    @StateObject private var searchService = EnhancedProductSearchService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteAlert = false
    @State private var searchToDelete: SavedSearch?
    @State private var isEditing = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if searchService.savedSearches.isEmpty {
                    emptyStateView
                } else {
                    savedSearchesList
                }
            }
            .navigationTitle("保存的搜索")
            #if os(iOS)
            .platformNavigationBarTitleDisplayMode(.inline)
            #else
            .platformNavigationBarTitleDisplayMode(0)
            #endif
            .platformToolbar(leading: {
                Button("关闭") {
                    dismiss()
                }
            }, trailing: {
                Button("编辑") {
                    isEditing.toggle()
                }
            })
            .listStyle(.plain)
        }
        .alert("删除搜索", isPresented: $showingDeleteAlert) {
            Button("删除", role: .destructive) {
                if let search = searchToDelete {
                    deleteSearch(search)
                }
            }
            Button("取消", role: .cancel) { }
        } message: {
            if let search = searchToDelete {
                Text("确定要删除搜索「\(search.name)」吗？")
            }
        }
    }
    
    // MARK: - 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bookmark.slash")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("暂无保存的搜索")
                .font(.title2)
                .fontWeight(.medium)
            
            Text("在搜索页面保存您常用的搜索条件，以便快速访问")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - 保存的搜索列表
    private var savedSearchesList: some View {
        List {
            ForEach(searchService.savedSearches, id: \.id) { savedSearch in
                SavedSearchRow(
                    savedSearch: savedSearch,
                    onSelect: {
                        onSelectSearch(savedSearch)
                    },
                    onDelete: {
                        searchToDelete = savedSearch
                        showingDeleteAlert = true
                    }
                )
            }
            .onDelete(perform: deleteSavedSearches)
        }
    }
    
    // MARK: - 操作方法
    
    private func deleteSearch(_ savedSearch: SavedSearch) {
        searchService.deleteSavedSearch(savedSearch)
    }
    
    private func deleteSavedSearches(offsets: IndexSet) {
        for index in offsets {
            let savedSearch = searchService.savedSearches[index]
            searchService.deleteSavedSearch(savedSearch)
        }
    }
}

// MARK: - 保存的搜索行
struct SavedSearchRow: View {
    let savedSearch: SavedSearch
    let onSelect: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                // 搜索名称
                HStack {
                    Text(savedSearch.name)
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text(formatDate(savedSearch.createdAt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // 搜索描述
                Text(savedSearch.query)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                // 过滤器详情
                if savedSearch.filters.hasActiveFilters {
                    savedSearchFilterDetailsView(savedSearch.filters)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(action: onSelect) {
                Label("使用搜索", systemImage: "magnifyingglass")
            }
            
            Button(action: onDelete) {
                Label("删除", systemImage: "trash")
            }
            .foregroundColor(.red)
        }
    }
    
    // MARK: - 保存的搜索过滤器详情视图
    private func savedSearchFilterDetailsView(_ filters: SavedSearch.SavedSearchFilters) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("过滤器:")
                .font(.caption2)
                .foregroundColor(.secondary)

            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 80))
            ], spacing: 4) {
                if filters.categoryName != nil {
                    FilterTag(text: "分类", color: .blue)
                }

                if !filters.tagNames.isEmpty {
                    FilterTag(text: "标签(\(filters.tagNames.count))", color: .green)
                }

                if filters.dateRange != nil {
                    FilterTag(text: "日期", color: .purple)
                }

                if !filters.fileTypes.isEmpty {
                    FilterTag(text: "文件类型(\(filters.fileTypes.count))", color: .orange)
                }
            }
        }
        .padding(.top, 4)
    }

    // MARK: - 过滤器详情视图
    private func filterDetailsView(_ filters: ProductSearchFilters) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("过滤器:")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 80))
            ], spacing: 4) {
                if filters.categoryId != nil {
                    FilterTag(text: "分类", color: .blue)
                }
                
                if !filters.tagIds.isEmpty {
                    FilterTag(text: "标签(\(filters.tagIds.count))", color: .green)
                }
                
                if filters.minPrice != nil || filters.maxPrice != nil {
                    FilterTag(text: "价格", color: .orange)
                }
                
                if filters.startDate != nil || filters.endDate != nil {
                    FilterTag(text: "日期", color: .purple)
                }
                
                if filters.warrantyStatus != nil {
                    FilterTag(text: "保修", color: .red)
                }
                
                if filters.hasManuals != nil {
                    FilterTag(text: "说明书", color: .indigo)
                }
                
                if filters.hasImages != nil {
                    FilterTag(text: "图片", color: .pink)
                }
            }
        }
        .padding(.top, 4)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - 过滤器标签
struct FilterTag: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.1))
            .cornerRadius(4)
    }
}

#Preview {
    SavedSearchesView { _ in
        // Preview action
    }
}
