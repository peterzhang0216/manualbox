import SwiftUI
import CoreData

/// 批量操作工具栏组件
struct BatchOperationsToolbar: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    let selectedProducts: Set<Product>
    let onOperationCompleted: () -> Void
    
    @State private var showingDeleteAlert = false
    @State private var showingCategoryPicker = false
    @State private var showingTagPicker = false
    @State private var showingExportOptions = false
    
    @FetchRequest(
        entity: Category.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Category.name, ascending: true)]
    ) private var categories: FetchedResults<Category>
    
    @FetchRequest(
        entity: Tag.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Tag.name, ascending: true)]
    ) private var tags: FetchedResults<Tag>
    
    var body: some View {
        if !selectedProducts.isEmpty {
            HStack(spacing: 16) {
                // 选中数量显示
                Text("已选择 \(selectedProducts.count) 个产品")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // 批量操作按钮组
                HStack(spacing: 12) {
                    // 批量分配分类
                    Button(action: { showingCategoryPicker = true }) {
                        Label("分类", systemImage: "folder")
                    }
                    .buttonStyle(.bordered)
                    .disabled(categories.isEmpty)
                    
                    // 批量分配标签
                    Button(action: { showingTagPicker = true }) {
                        Label("标签", systemImage: "tag")
                    }
                    .buttonStyle(.bordered)
                    .disabled(tags.isEmpty)
                    
                    // 批量导出
                    Button(action: { showingExportOptions = true }) {
                        Label("导出", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.bordered)
                    
                    // 批量删除
                    Button(action: { showingDeleteAlert = true }) {
                        Label("删除", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(Color.secondary.opacity(0.1))
            .sheet(isPresented: $showingCategoryPicker) {
                BatchCategoryAssignmentView(
                    selectedProducts: selectedProducts,
                    categories: Array(categories),
                    onCompleted: onOperationCompleted
                )
            }
            .sheet(isPresented: $showingTagPicker) {
                BatchTagAssignmentView(
                    selectedProducts: selectedProducts,
                    tags: Array(tags),
                    onCompleted: onOperationCompleted
                )
            }
            .sheet(isPresented: $showingExportOptions) {
                BatchExportView(
                    selectedProducts: selectedProducts
                )
            }
            .alert("确认删除", isPresented: $showingDeleteAlert) {
                Button("取消", role: .cancel) {}
                Button("删除", role: .destructive) {
                    deleteSelectedProducts()
                }
            } message: {
                Text("确定要删除选中的 \(selectedProducts.count) 个产品吗？此操作无法撤销。")
            }
        }
    }
    
    private func deleteSelectedProducts() {
        withAnimation {
            for product in selectedProducts {
                viewContext.delete(product)
            }
            
            do {
                try viewContext.save()
                onOperationCompleted()
            } catch {
                print("批量删除失败: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - 批量分类分配视图
struct BatchCategoryAssignmentView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    
    let selectedProducts: Set<Product>
    let categories: [Category]
    let onCompleted: () -> Void
    
    @State private var selectedCategory: Category?
    @State private var replaceExisting = true
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("将为 \(selectedProducts.count) 个产品分配分类")
                        .foregroundColor(.secondary)
                } header: {
                    Text("批量分配分类")
                }
                
                Section {
                    Picker("选择分类", selection: $selectedCategory) {
                        Text("移除分类").tag(Category?.none)
                        ForEach(categories, id: \.self) { category in
                            HStack {
                                Image(systemName: category.categoryIcon)
                                Text(category.categoryName)
                            }
                            .tag(Category?.some(category))
                        }
                    }
                    #if iOS
                    .pickerStyle(.wheel)
                    #else
                    .pickerStyle(.menu)
                    #endif
                } header: {
                    Text("目标分类")
                }
                
                Section {
                    Toggle("替换现有分类", isOn: $replaceExisting)
                } header: {
                    Text("分配选项")
                } footer: {
                    Text(replaceExisting ? 
                         "将替换所有选中产品的现有分类" : 
                         "只为未分类的产品分配分类")
                }
                
                Section {
                    Button(action: assignCategory) {
                        Text("确认分配")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .navigationTitle("批量分配分类")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar(content: {
                SwiftUI.ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
            })
        }
    }
    
    private func assignCategory() {
        for product in selectedProducts {
            if replaceExisting || product.category == nil {
                product.category = selectedCategory
            }
        }
        
        do {
            try viewContext.save()
            onCompleted()
            dismiss()
        } catch {
            print("批量分配分类失败: \(error.localizedDescription)")
        }
    }
}

// MARK: - 批量标签分配视图
struct BatchTagAssignmentView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    
    let selectedProducts: Set<Product>
    let tags: [Tag]
    let onCompleted: () -> Void
    
    @State private var selectedTags: Set<Tag> = []
    @State private var operationMode: TagOperationMode = .add
    
    enum TagOperationMode: String, CaseIterable {
        case add = "添加标签"
        case remove = "移除标签"
        case replace = "替换标签"
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("将为 \(selectedProducts.count) 个产品操作标签")
                        .foregroundColor(.secondary)
                } header: {
                    Text("批量标签操作")
                }
                
                Section {
                    Picker("操作类型", selection: $operationMode) {
                        ForEach(TagOperationMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("操作类型")
                }
                
                Section {
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 100), spacing: 8)
                    ], spacing: 8) {
                        ForEach(tags, id: \.self) { tag in
                            TagSelectionChip(
                                tag: tag,
                                isSelected: selectedTags.contains(tag)
                            ) {
                                toggleTagSelection(tag)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("选择标签")
                } footer: {
                    Text("已选择 \(selectedTags.count) 个标签")
                }
                
                Section {
                    Button(action: performTagOperation) {
                        Text("确认操作")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedTags.isEmpty && operationMode != .replace)
                }
            }
            .navigationTitle("批量标签操作")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar(content: {
                SwiftUI.ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
            })
        }
    }
    
    private func toggleTagSelection(_ tag: Tag) {
        if selectedTags.contains(tag) {
            selectedTags.remove(tag)
        } else {
            selectedTags.insert(tag)
        }
    }
    
    private func performTagOperation() {
        for product in selectedProducts {
            let currentTags = product.tags as? Set<Tag> ?? []
            var newTags = currentTags
            
            switch operationMode {
            case .add:
                newTags.formUnion(selectedTags)
            case .remove:
                newTags.subtract(selectedTags)
            case .replace:
                newTags = selectedTags
            }
            
            product.tags = NSSet(set: newTags)
        }
        
        do {
            try viewContext.save()
            onCompleted()
            dismiss()
        } catch {
            print("批量标签操作失败: \(error.localizedDescription)")
        }
    }
}

// MARK: - 标签选择芯片组件
struct TagSelectionChip: View {
    let tag: Tag
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Circle()
                    .fill(tag.uiColor)
                    .frame(width: 8, height: 8)
                Text(tag.tagName)
                    .font(.caption)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? tag.uiColor.opacity(0.2) : Color.secondary.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? tag.uiColor : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - 批量导出视图
struct BatchExportView: View {
    @Environment(\.dismiss) private var dismiss
    
    let selectedProducts: Set<Product>
    
    @State private var exportFormat: ExportFormat = .csv
    @State private var includeImages = false
    @State private var includeManuals = false
    @State private var isExporting = false
    
    enum ExportFormat: String, CaseIterable {
        case csv = "CSV"
        case json = "JSON"
        case pdf = "PDF"
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("将导出 \(selectedProducts.count) 个产品的信息")
                        .foregroundColor(.secondary)
                } header: {
                    Text("批量导出")
                }
                
                Section {
                    Picker("导出格式", selection: $exportFormat) {
                        ForEach(ExportFormat.allCases, id: \.self) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("导出格式")
                }
                
                Section {
                    Toggle("包含产品图片", isOn: $includeImages)
                    Toggle("包含说明书文件", isOn: $includeManuals)
                } header: {
                    Text("导出选项")
                } footer: {
                    Text("注意：包含图片和说明书会增加导出文件大小")
                }
                
                Section {
                    Button(action: exportProducts) {
                        HStack {
                            if isExporting {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text(isExporting ? "导出中..." : "开始导出")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isExporting)
                }
            }
            .navigationTitle("批量导出")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar(content: {
                SwiftUI.ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
            })
        }
    }
    
    private func exportProducts() {
        isExporting = true
        
        Task {
            // TODO: 实现实际的导出功能
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 模拟导出过程
            
            await MainActor.run {
                isExporting = false
                dismiss()
            }
        }
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let products = Set<Product>()
    
    return BatchOperationsToolbar(
        selectedProducts: products,
        onOperationCompleted: {}
    )
    .environment(\.managedObjectContext, context)
}
