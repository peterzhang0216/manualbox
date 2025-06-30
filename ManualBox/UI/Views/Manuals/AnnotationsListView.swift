import SwiftUI

// MARK: - 标注列表视图
struct AnnotationsListView: View {
    let manual: Manual
    let annotations: [ManualAnnotation]
    @StateObject private var annotationService = ManualAnnotationService.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedAnnotation: ManualAnnotation?
    @State private var showingEditAnnotation = false
    @State private var showingDeleteAlert = false
    @State private var annotationToDelete: ManualAnnotation?
    @State private var searchText = ""
    @State private var selectedFilter: AnnotationFilter = .all
    @State private var sortOption: AnnotationSortOption = .dateCreated
    
    enum AnnotationFilter: String, CaseIterable {
        case all = "全部"
        case highlight = "高亮"
        case underline = "下划线"
        case note = "笔记"
        case bookmark = "书签"
        case important = "重要"
        
        var annotationType: AnnotationType? {
            switch self {
            case .all: return nil
            case .highlight: return .highlight
            case .underline: return .underline
            case .note: return .note
            case .bookmark: return .bookmark
            case .important: return .important
            }
        }
    }
    
    enum AnnotationSortOption: String, CaseIterable {
        case dateCreated = "创建时间"
        case dateUpdated = "更新时间"
        case textLength = "文本长度"
        case type = "标注类型"
        
        var displayName: String { rawValue }
    }
    
    var filteredAndSortedAnnotations: [ManualAnnotation] {
        var filtered = annotations
        
        // 应用搜索过滤
        if !searchText.isEmpty {
            filtered = filtered.filter { annotation in
                annotation.text.localizedCaseInsensitiveContains(searchText) ||
                (annotation.note?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        
        // 应用类型过滤
        if let filterType = selectedFilter.annotationType {
            filtered = filtered.filter { $0.type == filterType }
        }
        
        // 应用排序
        switch sortOption {
        case .dateCreated:
            filtered.sort { $0.createdAt > $1.createdAt }
        case .dateUpdated:
            filtered.sort { ($0.updatedAt ?? $0.createdAt) > ($1.updatedAt ?? $1.createdAt) }
        case .textLength:
            filtered.sort { $0.text.count > $1.text.count }
        case .type:
            filtered.sort { $0.type.displayName < $1.type.displayName }
        }
        
        return filtered
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 搜索和筛选栏
                searchAndFilterBar
                
                // 统计信息
                statisticsBar
                
                Divider()
                
                // 标注列表
                annotationsList
            }
            .navigationTitle("标注列表")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                SwiftUI.ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }
                
                SwiftUI.ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(action: exportAnnotations) {
                            Label("导出标注", systemImage: "square.and.arrow.up")
                        }
                        
                        Button(action: shareAnnotations) {
                            Label("分享标注", systemImage: "square.and.arrow.up.on.square")
                        }
                        
                        Divider()
                        
                        Button(role: .destructive, action: {
                            showingDeleteAlert = true
                        }) {
                            Label("删除所有标注", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            #else
            .toolbar {
                SwiftUI.ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }
                
                SwiftUI.ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: exportAnnotations) {
                            Label("导出标注", systemImage: "square.and.arrow.up")
                        }
                        
                        Button(action: shareAnnotations) {
                            Label("分享标注", systemImage: "square.and.arrow.up.on.square")
                        }
                        
                        Divider()
                        
                        Button(role: .destructive, action: {
                            showingDeleteAlert = true
                        }) {
                            Label("删除所有标注", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            #endif
        }
        .sheet(item: $selectedAnnotation) { annotation in
            EditAnnotationSheet(annotation: annotation)
        }
        .alert("删除所有标注", isPresented: $showingDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                deleteAllAnnotations()
            }
        } message: {
            Text("此操作将删除该说明书的所有标注，且无法撤销。")
        }
    }
    
    // MARK: - 搜索和筛选栏
    private var searchAndFilterBar: some View {
        VStack(spacing: 12) {
            // 搜索框
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("搜索标注内容...", text: $searchText)
                    .textFieldStyle(.plain)
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            #if os(macOS)
            .background(Color(nsColor: .windowBackgroundColor))
            #else
            .background(Color(.systemGray5))
            #endif
            .cornerRadius(8)
            
            // 筛选和排序
            HStack {
                // 类型筛选
                Menu {
                    ForEach(AnnotationFilter.allCases, id: \.self) { filter in
                        Button(action: {
                            selectedFilter = filter
                        }) {
                            HStack {
                                Text(filter.rawValue)
                                if selectedFilter == filter {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                        Text(selectedFilter.rawValue)
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
                
                Spacer()
                
                // 排序选择
                Menu {
                    ForEach(AnnotationSortOption.allCases, id: \.self) { option in
                        Button(action: {
                            sortOption = option
                        }) {
                            HStack {
                                Text(option.displayName)
                                if sortOption == option {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.arrow.down")
                        Text(sortOption.displayName)
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
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            #if os(iOS)
            Color(.systemGroupedBackground)
            #else
            Color(nsColor: .windowBackgroundColor)
            #endif
        )
    }
    
    // MARK: - 统计信息栏
    private var statisticsBar: some View {
        HStack {
            StatisticItem(
                title: "高亮",
                value: "\(annotations.filter { $0.type == .highlight }.count)",
                subtitle: "高亮标注",
                color: .yellow,
                icon: "highlighter"
            )
            
            StatisticItem(
                title: "下划线",
                value: "\(annotations.filter { $0.type == .underline }.count)",
                subtitle: "下划线标注",
                color: .blue,
                icon: "underline"
            )
            
            StatisticItem(
                title: "笔记",
                value: "\(annotations.filter { $0.type == .note }.count)",
                subtitle: "笔记标注",
                color: .green,
                icon: "note.text"
            )
            
            StatisticItem(
                title: "书签",
                value: "\(annotations.filter { $0.type == .bookmark }.count)",
                subtitle: "书签标注",
                color: .orange,
                icon: "bookmark"
            )
            
            StatisticItem(
                title: "重要",
                value: "\(annotations.filter { $0.type == .important }.count)",
                subtitle: "重要标注",
                color: .red,
                icon: "exclamationmark.triangle"
            )
            
            Spacer()
            
            Text("共 \(filteredAndSortedAnnotations.count) 条")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        #if os(macOS)
        .background(Color(nsColor: .windowBackgroundColor))
        #else
        .background(Color(.systemGray5))
        #endif
    }
    
    // MARK: - 标注列表
    private var annotationsList: some View {
        Group {
            if filteredAndSortedAnnotations.isEmpty {
                emptyStateView
            } else {
                List {
                    ForEach(filteredAndSortedAnnotations, id: \.id) { annotation in
                        AnnotationRow(
                            annotation: annotation,
                            onTap: {
                                selectedAnnotation = annotation
                            },
                            onDelete: {
                                annotationToDelete = annotation
                                deleteAnnotation(annotation)
                            }
                        )
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }
                    .onDelete(perform: deleteAnnotations)
                }
                .listStyle(.plain)
            }
        }
    }
    
    // MARK: - 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: searchText.isEmpty ? "highlighter" : "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text(searchText.isEmpty ? "暂无标注" : "未找到匹配的标注")
                .font(.headline)
                .foregroundColor(.secondary)
            
            if !searchText.isEmpty {
                Text("尝试调整搜索条件或筛选选项")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            #if os(iOS)
            Color(.systemGroupedBackground)
            #else
            Color(nsColor: .windowBackgroundColor)
            #endif
        )
    }
    
    // MARK: - 操作方法
    
    private func deleteAnnotations(at offsets: IndexSet) {
        for index in offsets {
            let annotation = filteredAndSortedAnnotations[index]
            deleteAnnotation(annotation)
        }
    }
    
    private func deleteAnnotation(_ annotation: ManualAnnotation) {
        Task {
            await annotationService.deleteAnnotation(annotation)
        }
    }
    
    private func deleteAllAnnotations() {
        Task {
            for annotation in annotations {
                await annotationService.deleteAnnotation(annotation)
            }
        }
    }
    
    private func exportAnnotations() {
        guard let data = annotationService.exportAnnotationsAsJSON(for: manual.id ?? UUID()) else {
            return
        }
        
        let fileName = "\(manual.fileName ?? "manual")_annotations.json"
        
        #if os(iOS)
        let activityVC = UIActivityViewController(activityItems: [data], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityVC, animated: true)
        }
        #else
        let savePanel = NSSavePanel()
        savePanel.nameFieldStringValue = fileName
        savePanel.allowedContentTypes = [.json]
        
        if savePanel.runModal() == .OK {
            if let url = savePanel.url {
                try? data.write(to: url)
            }
        }
        #endif
    }
    
    private func shareAnnotations() {
        // 实现分享功能
        let annotationsText = filteredAndSortedAnnotations.map { annotation in
            var text = "【\(annotation.type.displayName)】\(annotation.text)"
            if let note = annotation.note, !note.isEmpty {
                text += "\n笔记: \(note)"
            }
            return text
        }.joined(separator: "\n\n")
        
        #if os(iOS)
        let activityVC = UIActivityViewController(activityItems: [annotationsText], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityVC, animated: true)
        }
        #endif
    }
}

// MARK: - 统计项组件 (使用 OptimizedSearchResultsView.swift 中的定义)

// MARK: - 标注行组件
struct AnnotationRow: View {
    let annotation: ManualAnnotation
    let onTap: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // 标注头部
                HStack {
                    Image(systemName: annotation.type.icon)
                        .font(.system(size: 14))
                        .foregroundColor(annotation.color.swiftUIColor)
                        .frame(width: 20)
                    
                    Text(annotation.type.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(formatDate(annotation.createdAt))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                }
                
                // 标注文本
                Text(annotation.text)
                    .font(.system(size: 14))
                    .foregroundColor(.primary)
                    .lineLimit(3)
                    .modifier(AnnotationStyleModifier(type: annotation.type, color: annotation.color))
                
                // 笔记
                if let note = annotation.note, !note.isEmpty {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "note.text")
                            .font(.caption2)
                            .foregroundColor(.blue)
                        
                        Text(note)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(6)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                #if os(iOS)
                Color(.systemBackground)
                #else
                Color(nsColor: .windowBackgroundColor)
                #endif
            )
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        #if os(iOS)
                        Color(.systemGray4), lineWidth: 0.5
                        #else
                        Color(nsColor: .separatorColor), lineWidth: 0.5
                        #endif
                    )
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

// MARK: - 编辑标注表单
struct EditAnnotationSheet: View {
    let annotation: ManualAnnotation
    @StateObject private var annotationService = ManualAnnotationService.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var note: String = ""
    @State private var type: AnnotationType = .highlight
    @State private var color: AnnotationColor = .yellow
    
    var body: some View {
        AnnotationEditorView(
            text: annotation.text,
            note: $note,
            type: $type,
            color: $color,
            onSave: {
                Task {
                    await annotationService.updateAnnotation(
                        annotation,
                        note: note,
                        color: color
                    )
                }
                dismiss()
            },
            onCancel: {
                dismiss()
            }
        )
        .onAppear {
            note = annotation.note ?? ""
            type = annotation.type
            color = annotation.color
        }
    }
}

#Preview {
    AnnotationsListView(
        manual: Manual.preview,
        annotations: []
    )
}
