import SwiftUI
import Foundation

// 确保可以访问PlatformAdapter
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

// MARK: - 平台自适应网格布局
struct PlatformAdaptiveGrid<Content: View>: View {
    let items: [GridItem]
    let spacing: CGFloat
    let content: () -> Content
    
    init(
        columns: Int? = nil,
        spacing: CGFloat = PlatformAdapter.groupSpacing,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.spacing = spacing
        self.content = content
        
        // 根据平台和屏幕大小自动调整列数
        let columnCount = columns ?? PlatformAdapter.preferredColumnCount
        self.items = Array(repeating: GridItem(.flexible(), spacing: spacing), count: columnCount)
    }
    
    var body: some View {
        LazyVGrid(columns: items, spacing: spacing) {
            content()
        }
    }
}

// MARK: - 平台自适应列表
struct PlatformAdaptiveList<Data: RandomAccessCollection, Content: View>: View where Data.Element: Identifiable {
    let data: Data
    let content: (Data.Element) -> Content
    let onRefresh: (() async -> Void)?
    let onDelete: ((IndexSet) -> Void)?
    let onMove: ((IndexSet, Int) -> Void)?
    let searchText: String
    
    @State private var isRefreshing = false
    
    init(
        _ data: Data,
        searchText: String = "",
        onRefresh: (() async -> Void)? = nil,
        onDelete: ((IndexSet) -> Void)? = nil,
        onMove: ((IndexSet, Int) -> Void)? = nil,
        @ViewBuilder content: @escaping (Data.Element) -> Content
    ) {
        self.data = data
        self.content = content
        self.onRefresh = onRefresh
        self.onDelete = onDelete
        self.onMove = onMove
        self.searchText = searchText
    }
    
    var body: some View {
        #if os(macOS)
        List(data, id: \.id) { item in
            content(item)
                .platformListRow()
                .contextMenu {
                    contextMenuItems(for: item)
                }
        }
        .listStyle(.sidebar)
        .searchable(text: .constant(searchText))
        #else
        List {
            ForEach(data, id: \.id) { item in
                content(item)
                    .platformListRow()
            }
            .onDelete(perform: onDelete)
            .onMove(perform: onMove)
        }
        .listStyle(.plain)
        .refreshable {
            if let onRefresh = onRefresh {
                await onRefresh()
            }
        }
        .searchable(text: .constant(searchText))
        #endif
    }
    
    @ViewBuilder
    private func contextMenuItems(for item: Data.Element) -> some View {
        #if os(macOS)
        Button("Edit") {
            // 编辑操作
        }
        
        Button("Duplicate") {
            // 复制操作
        }
        
        Divider()
        
        Button("Delete", role: .destructive) {
            // 删除操作
        }
        #endif
    }
}

// MARK: - 平台自适应分割视图
struct PlatformSplitView<Sidebar: View, Detail: View>: View {
    let sidebar: () -> Sidebar
    let detail: () -> Detail
    
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    
    init(
        @ViewBuilder sidebar: @escaping () -> Sidebar,
        @ViewBuilder detail: @escaping () -> Detail
    ) {
        self.sidebar = sidebar
        self.detail = detail
    }
    
    var body: some View {
        #if os(macOS)
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar()
                .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 300)
        } detail: {
            detail()
        }
        .navigationSplitViewStyle(.balanced)
        #else
        NavigationStack {
            sidebar()
        }
        #endif
    }
}

// MARK: - 平台自适应卡片容器
struct PlatformCardContainer<Content: View>: View {
    let content: () -> Content
    let padding: CGFloat
    let cornerRadius: CGFloat
    
    init(
        padding: CGFloat = PlatformAdapter.defaultPadding,
        cornerRadius: CGFloat = PlatformAdapter.cardCornerRadius,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.content = content
        self.padding = padding
        self.cornerRadius = cornerRadius
    }
    
    var body: some View {
        content()
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(PlatformAdapter.secondaryBackgroundColor)
                    .shadow(
                        color: .black.opacity(0.1),
                        radius: PlatformAdapter.isCompact ? 2 : 4,
                        x: 0,
                        y: PlatformAdapter.isCompact ? 1 : 2
                    )
            )
    }
}

// MARK: - 平台自适应工具栏
struct PlatformAdaptiveToolbar<Content: View>: View {
    let content: () -> Content
    
    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }
    
    var body: some View {
        #if os(macOS)
        HStack(spacing: PlatformAdapter.groupSpacing) {
            content()
        }
        .padding(.horizontal, PlatformAdapter.defaultPadding)
        .padding(.vertical, PlatformAdapter.groupSpacing)
        .background(
            Rectangle()
                .fill(PlatformAdapter.backgroundColor)
                .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
        )
        #else
        HStack(spacing: PlatformAdapter.groupSpacing) {
            content()
        }
        .padding(.horizontal, PlatformAdapter.defaultPadding)
        .padding(.vertical, PlatformAdapter.groupSpacing)
        #endif
    }
}

// MARK: - 平台自适应搜索栏
struct PlatformSearchBar: View {
    @Binding var searchText: String
    let placeholder: String
    let onSearchCommit: (() -> Void)?
    
    init(
        searchText: Binding<String>,
        placeholder: String = "搜索...",
        onSearchCommit: (() -> Void)? = nil
    ) {
        self._searchText = searchText
        self.placeholder = placeholder
        self.onSearchCommit = onSearchCommit
    }
    
    var body: some View {
        #if os(macOS)
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField(placeholder, text: $searchText)
                .textFieldStyle(.plain)
                .onSubmit {
                    onSearchCommit?()
                }
            
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(PlatformAdapter.secondaryBackgroundColor)
        )
        #else
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField(placeholder, text: $searchText)
                .onSubmit {
                    onSearchCommit?()
                }
            
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemGray6))
        )
        #endif
    }
}

// MARK: - 平台自适应表单组件
struct PlatformFormSection<Content: View>: View {
    let title: String?
    let content: () -> Content
    
    init(title: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: PlatformAdapter.groupSpacing) {
            if let title = title {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            content()
        }
        .platformSectionSpacing()
    }
}

// MARK: - 平台自适应标签
struct PlatformLabel: View {
    let text: String
    let style: LabelStyle
    
    enum LabelStyle {
        case title
        case subtitle
        case body
        case caption
    }
    
    init(_ text: String, style: LabelStyle = .body) {
        self.text = text
        self.style = style
    }
    
    var body: some View {
        Text(text)
            .font(font)
            .foregroundColor(foregroundColor)
    }
    
    private var font: Font {
        switch style {
        case .title:
            return .system(size: PlatformAdapter.titleFontSize, weight: .bold)
        case .subtitle:
            return .system(size: PlatformAdapter.bodyFontSize + 2, weight: .semibold)
        case .body:
            return .system(size: PlatformAdapter.bodyFontSize)
        case .caption:
            return .system(size: PlatformAdapter.captionFontSize)
        }
    }
    
    private var foregroundColor: Color {
        switch style {
        case .title, .subtitle, .body:
            return .primary
        case .caption:
            return .secondary
        }
    }
}