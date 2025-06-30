import SwiftUI
import CoreData

// MARK: - EnhancedSearchResult 扩展
extension EnhancedSearchResult: Identifiable {
    var id: UUID {
        return manual.id ?? UUID()
    }

    var title: String {
        return manual.fileName ?? "未知文件"
    }

    var subtitle: String {
        return manual.product?.name ?? ""
    }

    var lastModified: Date {
        return manual.product?.createdAt ?? Date()
    }

    var fileSize: Int64 {
        return Int64(manual.fileData?.count ?? 0)
    }

    var snippet: String {
        return highlightedSnippets.first?.text ?? ""
    }

    var type: SearchResultType {
        return .manual
    }
}



// MARK: - 优化的搜索结果视图
struct OptimizedSearchResultsView: View {
    let searchResults: [EnhancedSearchResult]
    let searchQuery: String
    @State private var selectedSortOption: SearchSortOption = .relevance
    @State private var selectedViewMode: SearchViewMode = .list
    @State private var showingResultDetails = false
    @State private var selectedResult: EnhancedSearchResult?
    
    var sortedResults: [EnhancedSearchResult] {
        switch selectedSortOption {
        case .relevance:
            return searchResults.sorted { $0.relevanceScore > $1.relevanceScore }
        case .date:
            return searchResults.sorted { ($0.lastModified) > ($1.lastModified) }
        case .name:
            return searchResults.sorted { ($0.manual.fileName ?? "").localizedCompare($1.manual.fileName ?? "") == .orderedAscending }
        case .fileSize:
            return searchResults.sorted { ($0.fileSize) > ($1.fileSize) }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 搜索结果头部
            searchResultsHeader
            
            Divider()
            
            // 搜索结果内容
            if sortedResults.isEmpty {
                emptyResultsView
            } else {
                searchResultsContent
            }
        }
        .sheet(item: $selectedResult) { result in
            SearchResultDetailView(result: result, searchQuery: searchQuery)
        }
    }
    
    // MARK: - 搜索结果头部
    private var searchResultsHeader: some View {
        VStack(spacing: 12) {
            // 结果统计和排序
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("找到 \(searchResults.count) 个结果")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if !searchQuery.isEmpty {
                        Text("搜索: \"\(searchQuery)\"")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                HStack(spacing: 12) {
                    // 视图模式切换
                    Picker("视图模式", selection: $selectedViewMode) {
                        ForEach(SearchViewMode.allCases, id: \.self) { mode in
                            Image(systemName: mode.icon)
                                .tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 100)
                    
                    // 排序选择
                    Menu {
                        ForEach(SearchSortOption.allCases, id: \.self) { option in
                            Button(action: {
                                selectedSortOption = option
                            }) {
                                HStack {
                                    Text(option.displayName)
                                    if selectedSortOption == option {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.arrow.down")
                            Text(selectedSortOption.displayName)
                        }
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        #if os(macOS)
                        .background(Color(nsColor: .windowBackgroundColor))
                        #else
                        .background(Color(.systemGray5))
                        #endif
                        .cornerRadius(6)
                    }
                }
            }
            
            // 搜索统计信息
            if !searchResults.isEmpty {
                searchStatisticsView
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }
    
    // MARK: - 搜索统计信息
    private var searchStatisticsView: some View {
        HStack(spacing: 16) {
            StatisticItem(
                title: "说明书",
                value: "\(searchResults.filter { $0.type == .manual }.count)",
                subtitle: "",
                color: .blue,
                icon: "doc.text"
            )
            
            StatisticItem(
                title: "产品",
                value: "\(Set(searchResults.compactMap { $0.manual.product?.id }).count)",
                subtitle: "",
                color: .green,
                icon: "cube.box"
            )
            
            StatisticItem(
                title: "分类",
                value: "\(Set(searchResults.compactMap { $0.manual.product?.category?.id }).count)",
                subtitle: "",
                color: .orange,
                icon: "folder"
            )
            
            StatisticItem(
                title: "标签",
                value: "\(tagCount)",
                subtitle: "",
                color: .purple,
                icon: "tag"
            )
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    // MARK: - 计算属性
    private var tagCount: Int {
        return searchResults.flatMap { result in
            if let tags = result.manual.product?.tags as? Set<Tag> {
                return tags.compactMap { $0.name }
            }
            return []
        }.count
    }
    
    // MARK: - 搜索结果内容
    private var searchResultsContent: some View {
        Group {
            switch selectedViewMode {
            case .list:
                searchResultsList
            case .grid:
                searchResultsGrid
            case .compact:
                searchResultsCompact
            }
        }
    }
    
    // MARK: - 列表视图
    private var searchResultsList: some View {
        List {
            ForEach(sortedResults, id: \.id) { result in
                SearchResultListRow(
                    result: result,
                    searchQuery: searchQuery,
                    onTap: {
                        selectedResult = result
                        showingResultDetails = true
                    }
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
    }
    
    // MARK: - 网格视图
    private var searchResultsGrid: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                ForEach(sortedResults, id: \.id) { result in
                    SearchResultGridCard(
                        result: result,
                        searchQuery: searchQuery,
                        onTap: {
                            selectedResult = result
                            showingResultDetails = true
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
    
    // MARK: - 紧凑视图
    private var searchResultsCompact: some View {
        List {
            ForEach(sortedResults, id: \.id) { result in
                SearchResultCompactRow(
                    result: result,
                    searchQuery: searchQuery,
                    onTap: {
                        selectedResult = result
                        showingResultDetails = true
                    }
                )
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
    }
    
    // MARK: - 空结果视图
    private var emptyResultsView: some View {
        VStack(spacing: 20) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("未找到相关结果")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                if !searchQuery.isEmpty {
                    Text("尝试使用不同的关键词或调整搜索条件")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            // 搜索建议
            VStack(alignment: .leading, spacing: 8) {
                Text("搜索建议:")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("• 检查拼写是否正确")
                    Text("• 尝试使用更通用的关键词")
                    Text("• 减少搜索条件的限制")
                    Text("• 使用同义词或相关词汇")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - 统计项组件 (使用 WarrantyManagementView.swift 中的定义)

// MARK: - 搜索结果列表行
struct SearchResultListRow: View {
    let result: EnhancedSearchResult
    let searchQuery: String
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // 标题和相关性评分
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(highlightedText(result.manual.fileName ?? "未知文件", query: searchQuery))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                            .lineLimit(2)

                        if let productName = result.manual.product?.name {
                            Text(productName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        RelevanceScoreView(score: Float(result.relevanceScore))
                        
                        Text(formatDate(result.manual.product?.updatedAt ?? Date()))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                // 摘要 - 使用高亮片段
                if !result.highlightedSnippets.isEmpty {
                    Text(highlightedText(result.highlightedSnippets.first?.text ?? "", query: searchQuery))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                        .padding(.leading, 8)
                }
                
                // 标签和元数据
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: result.type.icon)
                            .font(.caption2)
                            .foregroundColor(result.type.color)
                        
                        Text(result.type.displayName)
                            .font(.caption2)
                            .foregroundColor(result.type.color)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(result.type.color.opacity(0.1))
                    .cornerRadius(4)
                    
                    if result.fileSize > 0 {
                        Text(formatFileSize(result.fileSize))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(.systemGray6))
                            .cornerRadius(4)
                    }
                    
                    Spacer()
                    
                    if let tags = result.manual.product?.tags as? Set<Tag>,
                       !tags.isEmpty {
                        let tagNames = tags.compactMap { $0.name }
                        Text(tagNames.prefix(2).joined(separator: ", "))
                            .font(.caption2)
                            .foregroundColor(.blue)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(3)
                    }
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color(.systemBackground))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(.systemGray4), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
    
    private func highlightedText(_ text: String, query: String) -> AttributedString {
        var attributedString = AttributedString(text)
        
        if !query.isEmpty {
            let range = text.range(of: query, options: .caseInsensitive)
            if let range = range {
                let nsRange = NSRange(range, in: text)
                if let attributedRange = Range(nsRange, in: attributedString) {
                    attributedString[attributedRange].backgroundColor = .yellow.opacity(0.3)
                    attributedString[attributedRange].foregroundColor = .primary
                }
            }
        }
        
        return attributedString
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    private func formatFileSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}

// MARK: - 相关性评分视图
struct RelevanceScoreView: View {
    let score: Float
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<5) { index in
                Circle()
                    .fill(index < Int(score * 5) ? Color.green : Color(.systemGray4))
                    .frame(width: 4, height: 4)
            }
        }
    }
}

// MARK: - 搜索结果网格卡片
struct SearchResultGridCard: View {
    let result: EnhancedSearchResult
    let searchQuery: String
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // 图标和类型
                HStack {
                    Image(systemName: result.type.icon)
                        .font(.title2)
                        .foregroundColor(result.type.color)
                    
                    Spacer()
                    
                    RelevanceScoreView(score: Float(result.relevanceScore))
                }
                
                // 标题
                Text(result.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                // 摘要
                if !result.snippet.isEmpty {
                    Text(result.snippet)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                // 底部信息
                VStack(alignment: .leading, spacing: 4) {
                    if let tags = result.manual.product?.tags as? Set<Tag>,
                       !tags.isEmpty {
                        let tagNames = tags.compactMap { $0.name }
                        Text(tagNames.prefix(2).joined(separator: ", "))
                            .font(.caption2)
                            .foregroundColor(.blue)
                            .lineLimit(1)
                    }
                    
                    Text(formatDate(result.manual.product?.updatedAt ?? Date()))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(12)
            .frame(height: 160)
            .background(Color(.systemBackground))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(.systemGray4), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - 搜索结果紧凑行
struct SearchResultCompactRow: View {
    let result: EnhancedSearchResult
    let searchQuery: String
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: result.type.icon)
                    .font(.system(size: 16))
                    .foregroundColor(result.type.color)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    if !result.subtitle.isEmpty {
                        Text(result.subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    RelevanceScoreView(score: Float(result.relevanceScore))
                    
                    Text(formatDate(result.manual.product?.updatedAt ?? Date()))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - 搜索排序选项
enum SearchSortOption: String, CaseIterable {
    case relevance = "relevance"
    case date = "date"
    case name = "name"
    case fileSize = "fileSize"
    
    var displayName: String {
        switch self {
        case .relevance: return "相关性"
        case .date: return "日期"
        case .name: return "名称"
        case .fileSize: return "大小"
        }
    }
}

// MARK: - 搜索视图模式
enum SearchViewMode: String, CaseIterable {
    case list = "list"
    case grid = "grid"
    case compact = "compact"
    
    var icon: String {
        switch self {
        case .list: return "list.bullet"
        case .grid: return "square.grid.2x2"
        case .compact: return "list.dash"
        }
    }
}

// MARK: - 搜索结果详情视图
struct SearchResultDetailView: View {
    let result: EnhancedSearchResult
    let searchQuery: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 头部信息
                    resultHeaderView

                    // 内容预览
                    contentPreviewView

                    // 元数据
                    metadataView

                    // 相关操作
                    actionsView
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .navigationTitle("搜索结果详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                SwiftUI.ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var resultHeaderView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: result.type.icon)
                    .font(.title)
                    .foregroundColor(result.type.color)

                VStack(alignment: .leading, spacing: 4) {
                    Text(result.title)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    if !result.subtitle.isEmpty {
                        Text(result.subtitle)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()
            }

            HStack {
                RelevanceScoreView(score: Float(result.relevanceScore))

                Text("相关性: \(Int(result.relevanceScore * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text(result.type.displayName)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(result.type.color.opacity(0.1))
                    .foregroundColor(result.type.color)
                    .cornerRadius(8)
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var contentPreviewView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("内容预览")
                .font(.headline)
                .foregroundColor(.primary)

            if !result.snippet.isEmpty {
                Text(result.snippet)
                    .font(.body)
                    .foregroundColor(.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(.systemBackground))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
            } else {
                Text("暂无内容预览")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
    }

    private var metadataView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("详细信息")
                .font(.headline)
                .foregroundColor(.primary)

            VStack(spacing: 8) {
                MetadataRow(title: "最后修改", value: formatDate(result.manual.product?.updatedAt ?? Date()))

                if result.fileSize > 0 {
                    MetadataRow(title: "文件大小", value: formatFileSize(result.fileSize))
                }

                if let productId = result.manual.product?.id {
                    MetadataRow(title: "产品ID", value: productId.uuidString)
                }

                if let categoryId = result.manual.product?.category?.id {
                    MetadataRow(title: "分类ID", value: categoryId.uuidString)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
        }
    }

    private var actionsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("操作")
                .font(.headline)
                .foregroundColor(.primary)

            VStack(spacing: 8) {
                ActionButton(
                    title: "查看完整内容",
                    icon: "doc.text.magnifyingglass",
                    color: .blue
                ) {
                    // 查看完整内容的操作
                }

                ActionButton(
                    title: "查看相关产品",
                    icon: "cube.box",
                    color: .green
                ) {
                    // 查看相关产品的操作
                }

                ActionButton(
                    title: "分享结果",
                    icon: "square.and.arrow.up",
                    color: .orange
                ) {
                    // 分享结果的操作
                }
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formatFileSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}

// MARK: - 元数据行组件
struct MetadataRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)

            Text(value)
                .font(.subheadline)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)

            Spacer()
        }
    }
}

// MARK: - 操作按钮组件
struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(color)

                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    OptimizedSearchResultsView(
        searchResults: [],
        searchQuery: "iPhone"
    )
}
