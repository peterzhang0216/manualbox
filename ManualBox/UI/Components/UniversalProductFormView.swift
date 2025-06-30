import SwiftUI
import PhotosUI
import CoreData
import UniformTypeIdentifiers

#if os(macOS)
import AppKit
#else
import UIKit
#endif

// MARK: - 通用产品表单组件
/// 统一的产品表单组件，支持添加和编辑模式
struct UniversalProductFormView: View {
    
    // MARK: - 表单模式
    enum FormMode {
        case add
        case edit(Product)
        
        var title: String {
            switch self {
            case .add:
                return "添加商品"
            case .edit:
                return "编辑商品"
            }
        }
        
        var saveButtonTitle: String {
            switch self {
            case .add:
                return "保存"
            case .edit:
                return "更新"
            }
        }
    }
    
    // MARK: - 环境和状态
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage("defaultWarrantyPeriod") private var defaultWarrantyPeriod = 12
    @AppStorage("enableOCRByDefault") private var enableOCRByDefault = true
    
    // MARK: - 配置
    let mode: FormMode
    let defaultCategory: Category?
    let defaultTag: Tag?
    var onSave: ((Product) -> Void)?
    var onCancel: (() -> Void)?
    
    // MARK: - 表单状态
    @StateObject private var formState: ProductFormState
    
    // MARK: - 初始化
    init(
        mode: FormMode,
        defaultCategory: Category? = nil,
        defaultTag: Tag? = nil,
        onSave: ((Product) -> Void)? = nil,
        onCancel: (() -> Void)? = nil
    ) {
        self.mode = mode
        self.defaultCategory = defaultCategory
        self.defaultTag = defaultTag
        self.onSave = onSave
        self.onCancel = onCancel
        
        // 根据模式初始化状态
        switch mode {
        case .add:
            self._formState = StateObject(wrappedValue: ProductFormState(
                defaultCategory: defaultCategory,
                defaultTag: defaultTag
            ))
        case .edit(let product):
            self._formState = StateObject(wrappedValue: ProductFormState(
                existingProduct: product
            ))
        }
    }
    
    // MARK: - 主视图
    var body: some View {
        #if os(macOS)
        content
            .formStyle(.grouped)
            .frame(minWidth: 600, minHeight: 500)
        #else
        content
        #endif
    }
    
    private var content: some View {
        Form {
            productInfoSection
            categorySection
            tagSection
            
            // 只在添加模式显示订单和说明书信息
            if case .add = mode {
                orderInfoSection
                manualSection
            }
            
            // 只在编辑模式显示备注
            if case .edit = mode {
                notesSection
            }
            
            // 错误显示
            if let error = formState.saveError {
                Section {
                    Text(error)
                        .foregroundColor(.red)
                }
            }
        }
        .navigationTitle(mode.title)
        .disabled(formState.isSaving)
        .overlay {
            if formState.isSaving {
                ProgressView(formState.isSaving ? "正在保存..." : "")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.2))
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") {
                    handleCancel()
                }
                .disabled(formState.isSaving)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(mode.saveButtonTitle) {
                    handleSave()
                }
                .disabled(formState.name.isEmpty || formState.isSaving)
            }
        }
        .onChange(of: formState.selectedImage) { _, newValue in
            formState.loadImage(from: newValue)
        }
        .onChange(of: formState.invoiceImage) { _, newValue in
            formState.loadInvoiceImage(from: newValue)
        }
    }
    
    // MARK: - 表单区段
    
    private var productInfoSection: some View {
        Section {
            TextField("名称", text: $formState.name)
            TextField("品牌", text: $formState.brand)
            TextField("型号", text: $formState.model)
            
            PhotosPicker(
                selection: $formState.selectedImage,
                matching: .images,
                photoLibrary: .shared()
            ) {
                ProductImagePreview(image: formState.productImage)
            }
        } header: {
            Text("基本信息")
        }
    }
    
    private var categorySection: some View {
        Section {
            Picker("分类", selection: $formState.selectedCategory) {
                Text("未分类").tag(nil as Category?)
                ForEach(categories) { category in
                    Text(category.categoryName).tag(category as Category?)
                }
            }
        } header: {
            Text("分类")
        }
    }
    
    private var tagSection: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(tags) { tag in
                        TagButton(
                            tag: tag,
                            isSelected: formState.selectedTags.contains(tag)
                        ) {
                            formState.toggleTag(tag)
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        } header: {
            Text("标签")
        }
    }
    
    private var orderInfoSection: some View {
        Section {
            TextField("订单号", text: $formState.orderNumber)
            TextField("购买平台", text: $formState.platform)
            DatePicker("购买日期", selection: $formState.orderDate, displayedComponents: .date)
            
            CustomStepper(
                "保修期：\(formState.warrantyPeriod) 个月",
                value: $formState.warrantyPeriod,
                in: 0...60
            )
            
            PhotosPicker(
                selection: $formState.invoiceImage,
                matching: .images,
                photoLibrary: .shared()
            ) {
                Label("上传发票", systemImage: "doc.text.image")
            }
        } header: {
            Text("订单信息")
        }
    }
    
    private var manualSection: some View {
        Section {
            PhotosPicker(
                selection: $formState.selectedManuals,
                matching: .any(of: [.images, .not(.livePhotos)]),
                photoLibrary: .shared()
            ) {
                Label("选择说明书文件", systemImage: "doc.badge.plus")
            }
            
            if !formState.selectedManuals.isEmpty {
                Toggle("OCR 文字识别", isOn: $formState.performOCR)
            }
        } header: {
            Text("说明书")
        }
    }
    
    private var notesSection: some View {
        Section {
            TextEditor(text: $formState.notes)
                .frame(minHeight: 100)
        } header: {
            Text("备注")
        }
    }
    
    // MARK: - 事件处理
    
    private func handleSave() {
        Task {
            let success = await formState.saveProduct(in: viewContext, mode: mode)
            if success {
                await MainActor.run {
                    if let product = formState.savedProduct {
                        onSave?(product)
                    }
                    dismiss()
                }
            }
        }
    }
    
    private func handleCancel() {
        onCancel?()
        dismiss()
    }
    
    // MARK: - 数据获取
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Category.name, ascending: true)]
    )
    private var categories: FetchedResults<Category>
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Tag.name, ascending: true)]
    )
    private var tags: FetchedResults<Tag>
}

// MARK: - 产品表单状态管理
@MainActor
class ProductFormState: ObservableObject {
    
    // MARK: - 基本信息
    @Published var name = ""
    @Published var brand = ""
    @Published var model = ""
    @Published var selectedCategory: Category?
    @Published var selectedTags: Set<Tag> = []
    @Published var selectedImage: PhotosPickerItem?
    @Published var productImage: PlatformImage?
    @Published var notes = ""
    
    // MARK: - 订单信息
    @Published var orderNumber = ""
    @Published var platform = ""
    @Published var orderDate = Date()
    @Published var warrantyPeriod = 12
    @Published var invoiceImage: PhotosPickerItem?
    @Published var invoiceImageData: Data?
    
    // MARK: - 说明书信息
    @Published var selectedManuals: [PhotosPickerItem] = []
    @Published var performOCR = true
    
    // MARK: - 状态
    @Published var isSaving = false
    @Published var saveError: String?
    @Published var savedProduct: Product?
    
    // MARK: - 初始化
    
    /// 添加模式初始化
    init(defaultCategory: Category? = nil, defaultTag: Tag? = nil) {
        self.selectedCategory = defaultCategory
        if let defaultTag = defaultTag {
            self.selectedTags.insert(defaultTag)
        }
        self.warrantyPeriod = UserDefaults.standard.integer(forKey: "defaultWarrantyPeriod")
        if self.warrantyPeriod == 0 {
            self.warrantyPeriod = 12
        }
        self.performOCR = UserDefaults.standard.bool(forKey: "enableOCRByDefault")
    }
    
    /// 编辑模式初始化
    init(existingProduct: Product) {
        self.name = existingProduct.name ?? ""
        self.brand = existingProduct.brand ?? ""
        self.model = existingProduct.model ?? ""
        self.selectedCategory = existingProduct.category
        self.notes = existingProduct.notes ?? ""
        
        // 加载标签
        if let tags = existingProduct.tags as? Set<Tag> {
            self.selectedTags = tags
        }
        
        // 加载图片
        if let imageData = existingProduct.imageData,
           let image = PlatformImage(data: imageData) {
            self.productImage = image
        }
    }
    
    // MARK: - 方法
    
    func toggleTag(_ tag: Tag) {
        if selectedTags.contains(tag) {
            selectedTags.remove(tag)
        } else {
            selectedTags.insert(tag)
        }
    }
    
    func loadImage(from item: PhotosPickerItem?) {
        guard let item = item else { return }
        
        Task {
            if let data = try? await item.loadTransferable(type: Data.self) {
                await MainActor.run {
                    self.productImage = PlatformImage(data: data)
                }
            }
        }
    }
    
    func loadInvoiceImage(from item: PhotosPickerItem?) {
        guard let item = item else { return }
        
        Task {
            if let data = try? await item.loadTransferable(type: Data.self) {
                await MainActor.run {
                    self.invoiceImageData = data
                }
            }
        }
    }
    
    func saveProduct(in context: NSManagedObjectContext, mode: UniversalProductFormView.FormMode) async -> Bool {
        isSaving = true
        saveError = nil
        
        return await withCheckedContinuation { continuation in
            context.perform {
                do {
                    let product: Product
                    
                    switch mode {
                    case .add:
                        product = Product(context: context)
                        product.createdAt = Date()
                    case .edit(let existingProduct):
                        product = existingProduct
                    }
                    
                    // 更新基本信息
                    product.name = self.name
                    product.brand = self.brand
                    product.model = self.model
                    product.notes = self.notes
                    product.updatedAt = Date()
                    product.category = self.selectedCategory
                    
                    // 更新标签
                    let currentTags = product.tags as? Set<Tag> ?? []
                    let tagsToRemove = currentTags.subtracting(self.selectedTags)
                    let tagsToAdd = self.selectedTags.subtracting(currentTags)
                    
                    for tag in tagsToRemove {
                        product.removeFromTags(tag)
                    }
                    
                    for tag in tagsToAdd {
                        product.addToTags(tag)
                    }
                    
                    // 更新图片
                    if let image = self.productImage {
                        #if os(macOS)
                        if let tiffData = image.tiffRepresentation,
                           let bitmapRep = NSBitmapImageRep(data: tiffData),
                           let imageData = bitmapRep.representation(using: .jpeg, properties: [:]) {
                            product.imageData = imageData
                        }
                        #else
                        if let imageData = image.jpegData(compressionQuality: 0.8) {
                            product.imageData = imageData
                        }
                        #endif
                    }
                    
                    try context.save()
                    
                    DispatchQueue.main.async {
                        self.savedProduct = product
                        self.isSaving = false
                        continuation.resume(returning: true)
                    }
                    
                } catch {
                    DispatchQueue.main.async {
                        self.isSaving = false
                        self.saveError = error.localizedDescription
                        continuation.resume(returning: false)
                    }
                }
            }
        }
    }
}

// MARK: - 辅助组件

struct TagButton: View {
    let tag: Tag
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Circle()
                    .fill(tag.uiColor)
                    .frame(width: 8, height: 8)
                Text(tag.tagName)
                    .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? tag.uiColor.opacity(0.2) : Color.clear)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(tag.uiColor, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

@MainActor
struct ProductImagePreview: View {
    let image: PlatformImage?

    var body: some View {
        Group {
            if let image = image {
                Image(platformImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 200)
                    .cornerRadius(8)
            } else {
                Label("选择商品图片", systemImage: "photo")
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
            }
        }
    }
}

// MARK: - 预览
struct UniversalProductFormView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            UniversalProductFormView(mode: .add)
                .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        }
    }
}
