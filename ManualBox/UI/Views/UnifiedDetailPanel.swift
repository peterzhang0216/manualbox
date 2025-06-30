//
//  UnifiedDetailPanel.swift
//  ManualBox
//
//  Created by Peter's Mac on 2025/6/20.
//

import SwiftUI
import CoreData

struct UnifiedDetailPanel: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var stateManager: DetailPanelStateManager
    
    var body: some View {
        Group {
            switch stateManager.currentState {
            case .empty:
                emptyStateView
            case .productDetail(let product):
                ProductDetailView(product: product)
                    .id(product.id?.uuidString ?? "unknown")
            case .categoryDetail(let category):
                CategoryDetailView(category: category)
                    .id(category.id?.uuidString ?? "unknown")
            case .tagDetail(let tag):
                TagDetailView(tag: tag)
                    .id(tag.id?.uuidString ?? "unknown")
            case .addCategory, .editCategory:
                // 添加/编辑分类现在在第二栏显示，第三栏显示空状态
                emptyStateView
            case .addTag, .editTag:
                // 添加/编辑标签现在在第二栏显示，第三栏显示空状态
                emptyStateView
            case .addProduct(let defaultCategory, let defaultTag):
                InlineProductFormView(mode: .add, defaultCategory: defaultCategory, defaultTag: defaultTag)
            case .editProduct(let product):
                InlineProductFormView(mode: .edit(product))
            case .categoryList:
                CategoriesView()
            case .tagList:
                TagsView()
            case .dataExport:
                DataExportView()
            case .dataImport:
                DataImportView()
            case .dataBackup:
                DataBackupView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(minWidth: 320) // 确保最小宽度
        #if os(macOS)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
        #else
        .background(Color(.systemGroupedBackground).opacity(0.3))
        #endif
        .animation(.easeInOut(duration: 0.25), value: stateManager.currentState)
    }
    
    @ViewBuilder
    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("暂无选中内容", systemImage: "square.3.layers.3d")
        } description: {
            Text("请从左侧选择要查看的内容")
        }
        .padding(.top, 20)
    }
}



// MARK: - 内联产品表单视图
struct InlineProductFormView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var stateManager: DetailPanelStateManager

    let mode: FormMode<Product>
    let defaultCategory: Category?
    let defaultTag: Tag?

    init(mode: FormMode<Product>, defaultCategory: Category? = nil, defaultTag: Tag? = nil) {
        self.mode = mode
        self.defaultCategory = defaultCategory
        self.defaultTag = defaultTag
    }

    @State private var productName = ""
    @State private var brand = ""
    @State private var model = ""
    @State private var selectedCategory: Category?
    @State private var selectedTags: Set<Tag> = []
    @State private var notes = ""
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var hasInitializedDefaults = false

    @FetchRequest(
        entity: Category.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Category.name, ascending: true)]
    ) private var categories: FetchedResults<Category>

    @FetchRequest(
        entity: Tag.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Tag.name, ascending: true)]
    ) private var tags: FetchedResults<Tag>

    // 响应式标签网格列数
    private var adaptiveTagColumns: Int {
        return 2 // 在 macOS 上使用 2 列，适合标签选择按钮
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 标题栏
            HStack {
                Image(systemName: stateManager.currentState.icon)
                    .font(.title2)
                    .foregroundColor(.accentColor)
                Text(stateManager.currentState.title)
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()

                Button("取消") {
                    stateManager.reset()
                }
                .buttonStyle(.bordered)

                Button("保存") {
                    saveProduct()
                }
                .buttonStyle(.borderedProminent)
                .disabled(productName.isEmpty || isSaving)
            }
            .padding(.horizontal)
            .padding(.top)

            Divider()

            // 表单内容
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 16) {
                    // 基本信息
                    VStack(alignment: .leading, spacing: 8) {
                        Text("基本信息")
                            .font(.headline)

                        TextField("产品名称", text: $productName)
                            .textFieldStyle(.roundedBorder)

                        TextField("品牌", text: $brand)
                            .textFieldStyle(.roundedBorder)

                        TextField("型号", text: $model)
                            .textFieldStyle(.roundedBorder)
                    }

                    // 分类选择
                    VStack(alignment: .leading, spacing: 8) {
                        Text("分类")
                            .font(.headline)

                        Picker("选择分类", selection: $selectedCategory) {
                            Text("未分类").tag(nil as Category?)
                            ForEach(categories) { category in
                                Text(category.categoryName).tag(category as Category?)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    // 标签选择
                    VStack(alignment: .leading, spacing: 8) {
                        Text("标签")
                            .font(.headline)

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: adaptiveTagColumns), spacing: 8) {
                            ForEach(tags) { tag in
                                TagSelectionButton(
                                    tag: tag,
                                    isSelected: selectedTags.contains(tag)
                                ) {
                                    if selectedTags.contains(tag) {
                                        selectedTags.remove(tag)
                                    } else {
                                        selectedTags.insert(tag)
                                    }
                                }
                            }
                        }
                    }

                    // 备注
                    VStack(alignment: .leading, spacing: 8) {
                        Text("备注")
                            .font(.headline)

                        TextField("添加产品备注信息...", text: $notes, axis: .vertical)
                            .lineLimit(3...6)
                            .textFieldStyle(.roundedBorder)
                    }

                    // 错误信息
                    if let error = saveError {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }

            Spacer()
        }
        .disabled(isSaving)
        .overlay {
            if isSaving {
                ProgressView("保存中...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.2))
            }
        }
        .onAppear {
            setupInitialValues()
        }
    }

    private func setupInitialValues() {
        switch mode {
        case .add:
            productName = ""
            brand = ""
            model = ""
            selectedCategory = nil
            selectedTags = []
            notes = ""

            // 初始化默认值
            initializeDefaults()
        case .edit(let product):
            productName = product.name ?? ""
            brand = product.brand ?? ""
            model = product.model ?? ""
            selectedCategory = product.category
            selectedTags = Set(product.productTags)
            notes = product.notes ?? ""
        }
    }

    // MARK: - 默认值初始化
    private func initializeDefaults() {
        guard !hasInitializedDefaults else { return }

        // 设置默认分类
        if let defaultCategory = defaultCategory {
            // 如果提供了特定分类，使用该分类
            selectedCategory = defaultCategory
        } else {
            // 否则不设置任何默认分类，让用户自己选择
            selectedCategory = nil
        }

        // 设置默认标签
        if let defaultTag = defaultTag {
            // 如果提供了特定标签，使用该标签
            selectedTags.insert(defaultTag)
        } else {
            // 否则不设置任何默认标签，让用户自己选择
            selectedTags = []
        }

        hasInitializedDefaults = true
    }

    private func saveProduct() {
        guard !productName.isEmpty else {
            saveError = "产品名称不能为空"
            return
        }

        isSaving = true
        saveError = nil

        Task {
            do {
                let product: Product
                switch mode {
                case .add:
                    product = Product(context: viewContext)
                    product.id = UUID()
                    product.createdAt = Date()
                case .edit(let existingProduct):
                    product = existingProduct
                }

                product.name = productName
                product.brand = brand.isEmpty ? nil : brand
                product.model = model.isEmpty ? nil : model
                product.category = selectedCategory
                product.tags = NSSet(set: selectedTags)
                product.notes = notes.isEmpty ? nil : notes
                product.updatedAt = Date()

                try viewContext.save()

                await MainActor.run {
                    stateManager.reset()
                }
            } catch {
                await MainActor.run {
                    saveError = "保存失败: \(error.localizedDescription)"
                    isSaving = false
                }
            }
        }
    }
}

// MARK: - 标签选择按钮组件
struct TagSelectionButton: View {
    let tag: Tag
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                // 标签颜色指示器
                Circle()
                    .fill(tag.uiColor)
                    .frame(width: 10, height: 10)
                    .shadow(color: tag.uiColor.opacity(0.3), radius: 2, x: 0, y: 1)

                // 标签名称
                Text(tag.tagName)
                    .font(.caption)
                    .fontWeight(isSelected ? .medium : .regular)
                    .lineLimit(1)
                    .foregroundColor(isSelected ? tag.uiColor : .primary)

                // 选中状态指示器
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundColor(tag.uiColor)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(minHeight: 32) // 确保最小高度
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(isSelected ? tag.uiColor.opacity(0.15) : Color.secondary.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(isSelected ? tag.uiColor : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

#Preview {
    UnifiedDetailPanel()
        .environmentObject(DetailPanelStateManager())
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
