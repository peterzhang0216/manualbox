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
            case .addCategory:
                InlineCategoryFormView(mode: .add)
            case .editCategory(let category):
                InlineCategoryFormView(mode: .edit(category))
            case .addTag:
                InlineTagFormView(mode: .add)
            case .editTag(let tag):
                InlineTagFormView(mode: .edit(tag))
            case .addProduct:
                InlineProductFormView(mode: .add)
            case .editProduct(let product):
                InlineProductFormView(mode: .edit(product))
            case .categoryList:
                CategoriesView()
            case .tagList:
                TagsView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(minWidth: 320) // 确保最小宽度
        .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
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

// MARK: - 表单模式枚举
enum FormMode<T> {
    case add
    case edit(T)
    
    var isEditing: Bool {
        switch self {
        case .add:
            return false
        case .edit:
            return true
        }
    }
}

// MARK: - 内联分类表单视图
struct InlineCategoryFormView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var stateManager: DetailPanelStateManager
    
    let mode: FormMode<Category>
    
    @State private var categoryName = ""
    @State private var selectedIcon = "folder"
    @State private var isSaving = false
    @State private var saveError: String?
    
    private let systemIcons = [
        "folder", "folder.fill", "archivebox", "archivebox.fill",
        "tray", "tray.fill", "externaldrive", "externaldrive.fill",
        "internaldrive", "internaldrive.fill", "opticaldiscdrive",
        "tv", "tv.fill", "desktopcomputer", "laptopcomputer",
        "iphone", "ipad", "applewatch", "airpods",
        "headphones", "speaker", "hifispeaker", "homepod",
        "gamecontroller", "gamecontroller.fill", "keyboard",
        "computermouse", "computermouse.fill", "trackpad",
        "printer", "printer.fill", "scanner", "scanner.fill",
        "camera", "camera.fill", "video", "video.fill"
    ]
    
    // 响应式图标网格列数
    private var adaptiveIconColumns: Int {
        // 根据可用宽度调整列数，确保在较小窗口中也能正常显示
        return 6 // 在 macOS 上使用固定的 6 列，适合大多数情况
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
                    saveCategory()
                }
                .buttonStyle(.borderedProminent)
                .disabled(categoryName.isEmpty || isSaving)
            }
            .padding(.horizontal)
            .padding(.top)
            
            Divider()
            
            // 表单内容
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 16) {
                    // 分类名称
                    VStack(alignment: .leading, spacing: 8) {
                        Text("分类名称")
                            .font(.headline)
                        TextField("请输入分类名称", text: $categoryName)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    // 图标选择
                    VStack(alignment: .leading, spacing: 8) {
                        Text("选择图标")
                            .font(.headline)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: adaptiveIconColumns), spacing: 12) {
                            ForEach(systemIcons, id: \.self) { icon in
                                Button(action: { selectedIcon = icon }) {
                                    Image(systemName: icon)
                                        .font(.title2)
                                        .foregroundColor(selectedIcon == icon ? .white : .primary)
                                        .frame(width: 40, height: 40)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(selectedIcon == icon ? Color.accentColor : Color.secondary.opacity(0.2))
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
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
            categoryName = ""
            selectedIcon = "folder"
        case .edit(let category):
            categoryName = category.categoryName
            selectedIcon = category.categoryIcon
        }
    }
    
    private func saveCategory() {
        guard !categoryName.isEmpty else {
            saveError = "分类名称不能为空"
            return
        }
        
        isSaving = true
        saveError = nil
        
        Task {
            do {
                switch mode {
                case .add:
                    let _ = Category.createCategoryIfNotExists(
                        in: viewContext,
                        name: categoryName,
                        icon: selectedIcon
                    )
                case .edit(let category):
                    category.name = categoryName
                    category.icon = selectedIcon
                }
                
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

// MARK: - 内联标签表单视图
struct InlineTagFormView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var stateManager: DetailPanelStateManager

    let mode: FormMode<Tag>

    @State private var tagName = ""
    @State private var selectedColor = TagColor.blue
    @State private var isSaving = false
    @State private var saveError: String?

    // 响应式颜色网格列数
    private var adaptiveColorColumns: Int {
        return 5 // 在 macOS 上使用 5 列，适合颜色选择
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
                    saveTag()
                }
                .buttonStyle(.borderedProminent)
                .disabled(tagName.isEmpty || isSaving)
            }
            .padding(.horizontal)
            .padding(.top)

            Divider()

            // 表单内容
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 16) {
                    // 标签名称
                    VStack(alignment: .leading, spacing: 8) {
                        Text("标签名称")
                            .font(.headline)
                        TextField("请输入标签名称", text: $tagName)
                            .textFieldStyle(.roundedBorder)
                    }

                    // 颜色选择
                    VStack(alignment: .leading, spacing: 8) {
                        Text("选择颜色")
                            .font(.headline)

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: adaptiveColorColumns), spacing: 12) {
                            ForEach(TagColor.allCases) { color in
                                Button(action: { selectedColor = color }) {
                                    Circle()
                                        .fill(color.color)
                                        .frame(width: 40, height: 40)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.primary, lineWidth: selectedColor == color ? 3 : 0)
                                        )
                                        .shadow(color: color.color.opacity(0.3), radius: 2, x: 0, y: 1)
                                }
                                .buttonStyle(.plain)
                            }
                        }
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
            tagName = ""
            selectedColor = .blue
        case .edit(let tag):
            tagName = tag.tagName
            selectedColor = TagColor(rawValue: tag.color ?? "blue") ?? .blue
        }
    }

    private func saveTag() {
        guard !tagName.isEmpty else {
            saveError = "标签名称不能为空"
            return
        }

        isSaving = true
        saveError = nil

        Task {
            do {
                switch mode {
                case .add:
                    let _ = Tag.createTagIfNotExists(
                        in: viewContext,
                        name: tagName,
                        color: selectedColor.rawValue
                    )
                case .edit(let tag):
                    tag.name = tagName
                    tag.color = selectedColor.rawValue
                }

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

// MARK: - 内联产品表单视图
struct InlineProductFormView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var stateManager: DetailPanelStateManager

    let mode: FormMode<Product>

    @State private var productName = ""
    @State private var brand = ""
    @State private var model = ""
    @State private var selectedCategory: Category?
    @State private var selectedTags: Set<Tag> = []
    @State private var notes = ""
    @State private var isSaving = false
    @State private var saveError: String?

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
        case .edit(let product):
            productName = product.name ?? ""
            brand = product.brand ?? ""
            model = product.model ?? ""
            selectedCategory = product.category
            selectedTags = Set(product.productTags)
            notes = product.notes ?? ""
        }
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
