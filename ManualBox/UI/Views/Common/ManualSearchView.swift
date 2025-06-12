import SwiftUI
import CoreData
import PDFKit

#if os(iOS)
import UIKit
#else
import AppKit
#endif

struct ManualSearchView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var searchService = ManualSearchService.shared
    @State private var searchText = ""
    @State private var showSearchSuggestions = false
    @State private var selectedSearchResult: ManualSearchService.ManualSearchResult?
    
    var body: some View {
        VStack(spacing: 0) {
            // 增强版搜索栏
            enhancedSearchBar
            
            // 搜索建议下拉列表
            if showSearchSuggestions && !searchService.searchSuggestions.isEmpty {
                searchSuggestionsView
            }
            
            // 搜索结果内容
            searchResultsContent
        }
        .navigationTitle("说明书搜索")
        .sheet(item: $selectedSearchResult) { result in
            ManualDetailSheet(searchResult: result)
        }
    }
    
    // MARK: - 增强版搜索栏
    private var enhancedSearchBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // 搜索图标
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 16, weight: .medium))
                
                // 搜索输入框
                TextField("搜索说明书内容、产品信息...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .onSubmit {
                        performSearch()
                        hideSearchSuggestions()
                    }
                    .onChange(of: searchText) { oldValue, newValue in
                        if newValue.count >= 2 {
                            showSearchSuggestions(for: newValue)
                        } else {
                            hideSearchSuggestions()
                        }
                    }
                
                // 清除按钮
                if !searchText.isEmpty {
                    Button(action: clearSearch) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 16))
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity)
                }
                
                // 高级搜索按钮
                Button(action: {
                    // TODO: 实现高级搜索设置
                }) {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundColor(.accentColor)
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.systemSecondaryBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(searchText.isEmpty ? Color.clear : Color.accentColor.opacity(0.3), lineWidth: 1)
            )
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - 搜索建议视图
    private var searchSuggestionsView: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(searchService.searchSuggestions, id: \.self) { suggestion in
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    
                    Text(suggestion)
                        .font(.body)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "arrow.up.left")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
                .onTapGesture {
                    searchText = suggestion
                    performSearch()
                    hideSearchSuggestions()
                }
                .background(Color.systemTertiaryBackground)
                
                if suggestion != searchService.searchSuggestions.last {
                    Divider()
                        .padding(.leading, 40)
                }
            }
        }
        .background(Color.systemSecondaryBackground)
        .cornerRadius(12)
        .padding(.horizontal)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
    }
    
    // MARK: - 搜索结果内容
    private var searchResultsContent: some View {
        Group {
            if searchService.isSearching {
                searchingView
            } else if searchService.searchResults.isEmpty && !searchText.isEmpty {
                emptyResultsView
            } else if !searchService.searchResults.isEmpty {
                searchResultsList
            } else {
                searchPlaceholderView
            }
        }
    }
    
    // MARK: - 搜索状态视图
    private var searchingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("正在搜索...")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyResultsView: some View {
        ContentUnavailableView(
            "未找到相关结果",
            systemImage: "doc.text.magnifyingglass",
            description: Text("请尝试其他关键词或检查拼写")
        )
    }
    
    private var searchPlaceholderView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 64))
                .foregroundColor(.secondary.opacity(0.6))
            
            VStack(spacing: 8) {
                Text("搜索说明书")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("输入关键词搜索产品说明书内容")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // 搜索提示
            VStack(alignment: .leading, spacing: 8) {
                searchTipRow(icon: "doc.text", text: "文件名和说明书内容")
                searchTipRow(icon: "cube.box", text: "产品名称、品牌和型号")
                searchTipRow(icon: "folder", text: "分类和标签")
            }
            .padding()
            .background(Color(.tertiarySystemFill))
            .cornerRadius(12)
        }
        .padding()
    }
    
    private func searchTipRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.accentColor)
                .frame(width: 20)
            
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
    
    // MARK: - 搜索结果列表
    private var searchResultsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(searchService.searchResults) { result in
                    SearchResultCard(result: result)
                        .onTapGesture {
                            selectedSearchResult = result
                        }
                }
            }
            .padding()
        }
    }
    
    // MARK: - 搜索操作方法
    private func performSearch() {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        Task {
            await searchService.performSearch(query: searchText)
        }
    }
    
    private func showSearchSuggestions(for query: String) {
        Task {
            _ = await searchService.generateSearchSuggestions(for: query)
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showSearchSuggestions = true
                }
            }
        }
    }
    
    private func hideSearchSuggestions() {
        withAnimation(.easeInOut(duration: 0.2)) {
            showSearchSuggestions = false
        }
    }
    
    private func clearSearch() {
        withAnimation {
            searchText = ""
            hideSearchSuggestions()
            searchService.searchResults = []
        }
    }
}

// MARK: - 搜索结果卡片
struct SearchResultCard: View {
    let result: ManualSearchService.ManualSearchResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 头部信息
            HStack {
                // 文件类型图标
                Image(systemName: result.manual.isPDF ? "doc.fill" : "photo.fill")
                    .font(.system(size: 16))
                    .foregroundColor(result.manual.isPDF ? .red : .blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.manual.manualFileName)
                        .font(.headline)
                        .lineLimit(1)
                    
                    if let product = result.manual.product {
                        Text(product.productName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // 相关性评分
                relevanceScoreBadge
            }
            
            // 匹配字段信息
            if !result.matchedFields.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(result.matchedFields.prefix(3), id: \.fieldName) { field in
                        HStack(spacing: 6) {
                            Text(field.fieldName)
                                .font(.caption2)
                                .fontWeight(.medium)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.2))
                                .cornerRadius(4)
                            
                            Text(String(field.content.prefix(50)))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            }
            
            // 高亮片段
            if !result.highlightedSnippets.isEmpty,
               let snippet = result.highlightedSnippets.first {
                Text(snippet)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.quaternarySystemFill))
                    .cornerRadius(8)
                    .lineLimit(3)
            }
        }
        .padding()
        .background(Color(.secondarySystemFill))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    private var relevanceScoreBadge: some View {
        Text("\(Int(result.relevanceScore * 100))%")
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(relevanceColor)
            )
    }
    
    private var relevanceColor: Color {
        let score = result.relevanceScore
        if score >= 0.8 {
            return .green
        } else if score >= 0.5 {
            return .orange
        } else {
            return .gray
        }
    }
}

// MARK: - 说明书详情弹窗
struct ManualDetailSheet: View {
    let searchResult: ManualSearchService.ManualSearchResult
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Group {
                if searchResult.manual.isPDF {
                    if let document = searchResult.manual.getPDFDocument() {
                        PDFKitView(document: document)
                    } else {
                        ContentUnavailableView(
                            "无法加载PDF",
                            systemImage: "doc.text.fill",
                            description: Text("文件可能已损坏或不存在")
                        )
                    }
                } else if searchResult.manual.isImage {
                    if let image = searchResult.manual.getPreviewImage() {
                        ImageView(image: image)
                    } else {
                        ContentUnavailableView(
                            "无法加载图像",
                            systemImage: "photo.fill",
                            description: Text("文件可能已损坏或不存在")
                        )
                    }
                } else {
                    ContentUnavailableView(
                        "不支持的文件格式",
                        systemImage: "questionmark.folder.fill"
                    )
                }
            }
            .navigationTitle(searchResult.manual.manualFileName)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            #endif
            .toolbar(content: {
                #if os(iOS)
                SwiftUI.ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
                #else
                SwiftUI.ToolbarItem(placement: .primaryAction) {
                    Button("完成") {
                        dismiss()
                    }
                }
                #endif
            })
        }
    }
}

// MARK: - 辅助视图组件
struct ImageView: View {
    let image: PlatformImage
    
    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            Image(platformImage: image)
                .resizable()
                .scaledToFit()
        }
    }
}

#if os(iOS)
struct PDFKitView: UIViewRepresentable {
    let document: PDFKit.PDFDocument
    
    func makeUIView(context: Context) -> PDFKit.PDFView {
        let pdfView = PDFKit.PDFView()
        pdfView.document = document
        pdfView.autoScales = true
        pdfView.displayMode = .singlePage
        return pdfView
    }
    
    func updateUIView(_ uiView: PDFKit.PDFView, context: Context) {
        uiView.document = document
    }
}
#else
struct PDFKitView: NSViewRepresentable {
    let document: PDFKit.PDFDocument
    
    func makeNSView(context: Context) -> PDFKit.PDFView {
        let pdfView = PDFKit.PDFView()
        pdfView.document = document
        pdfView.autoScales = true
        pdfView.displayMode = .singlePage
        return pdfView
    }
    
    func updateNSView(_ nsView: PDFKit.PDFView, context: Context) {
        nsView.document = document
    }
}
#endif

#Preview {
    NavigationView {
        ManualSearchView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}