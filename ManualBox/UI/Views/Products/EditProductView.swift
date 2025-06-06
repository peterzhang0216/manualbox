import SwiftUI
import PhotosUI
import CoreData

struct EditProductView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    let product: Product
    
    @State private var name: String
    @State private var brand: String
    @State private var model: String
    @State private var selectedCategory: Category?
    @State private var selectedTags: Set<Tag> = []
    @State private var selectedImage: PhotosPickerItem?
    @State private var productImage: PlatformImage?
    @State private var notes: String
    
    @State private var isSaving = false
    @State private var saveError: String?
    
    init(product: Product) {
        self.product = product
        
        // 初始化状态变量
        _name = State(initialValue: product.name ?? "")
        _brand = State(initialValue: product.brand ?? "")
        _model = State(initialValue: product.model ?? "")
        _selectedCategory = State(initialValue: product.category)
        _notes = State(initialValue: product.notes ?? "")
        
        if let imageData = product.imageData,
           let image = PlatformImage(data: imageData) {
            _productImage = State(initialValue: image)
        }
        
        if let tags = product.tags {
            let tagSet = (tags as NSSet).allObjects as? [Tag] ?? []
            _selectedTags = State(initialValue: Set(tagSet))
        }
    }
    
    var body: some View {
        Form {
            productInfoSection
            tagSection
            notesSection
            
            if let error = saveError {
                Section {
                    Text(error)
                        .foregroundColor(.red)
                }
            }
        }
        .navigationTitle("编辑产品")
        .disabled(isSaving)
        .overlay {
            if isSaving {
                ProgressView("保存中...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.2))
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") {
                    dismiss()
                }
                .disabled(isSaving)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    saveChanges()
                }
                .disabled(name.isEmpty || isSaving)
            }
        }
        .onChange(of: selectedImage) { oldValue, newValue in
            loadImage(from: newValue)
        }
    }
    
    private var productInfoSection: some View {
        Section {
            TextField("名称", text: $name)
            TextField("品牌", text: $brand)
            TextField("型号", text: $model)
            
            Picker("分类", selection: $selectedCategory) {
                Text("未分类").tag(nil as Category?)
                ForEach(categories) { category in
                    Text(category.categoryName).tag(category as Category?)
                }
            }
            
            PhotosPicker(selection: $selectedImage,
                       matching: .images,
                       photoLibrary: .shared()) {
                Group {
                    if let productImage = productImage {
                        Image(platformImage: productImage)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 200)
                    } else {
                        Label("选择产品图片", systemImage: "photo")
                            .frame(height: 200)
                            .frame(maxWidth: .infinity)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
            }
        } header: {
            Text("基本信息")
        }
    }
    
    private var tagSection: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(tags) { tag in
                        TagButton(tag: tag,
                                isSelected: selectedTags.contains(tag)) {
                            toggleTag(tag)
                        }
                    }
                }
            }
        } header: {
            Text("标签")
        }
    }
    
    private var notesSection: some View {
        Section {
            TextEditor(text: $notes)
                .frame(minHeight: 100)
        } header: {
            Text("备注")
        }
    }
    
    private func toggleTag(_ tag: Tag) {
        if selectedTags.contains(tag) {
            selectedTags.remove(tag)
        } else {
            selectedTags.insert(tag)
        }
    }
    
    private func loadImage(from item: PhotosPickerItem?) {
        guard let item = item else { return }
        
        Task {
            if let data = try? await item.loadTransferable(type: Data.self) {
                await MainActor.run {
                    self.productImage = PlatformImage(data: data)
                }
            }
        }
    }
    
    private func saveChanges() {
        isSaving = true
        saveError = nil
        
        // 保存更改
        viewContext.perform {
            // 更新基本信息
            product.name = name
            product.brand = brand
            product.model = model
            product.notes = notes
            product.updatedAt = Date()
            
            // 更新分类
            product.category = selectedCategory
            
            // 更新标签
            let currentTags = product.tags as? Set<Tag> ?? []
            let tagsToRemove = currentTags.subtracting(selectedTags)
            let tagsToAdd = selectedTags.subtracting(currentTags)
            
            for tag in tagsToRemove {
                product.removeFromTags(tag)
            }
            
            for tag in tagsToAdd {
                product.addToTags(tag)
            }
            
            // 更新图片
            if let image = productImage, let imageData = image.jpegData(compressionQuality: 0.8) {
                product.imageData = imageData
            }
            
            // 保存上下文
            do {
                try viewContext.save()
                
                // 在主线程更新 UI
                DispatchQueue.main.async {
                    isSaving = false
                    dismiss()
                }
            } catch {
                DispatchQueue.main.async {
                    isSaving = false
                    saveError = error.localizedDescription
                }
            }
        }
    }
    
    // MARK: - Environment Objects
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Category.name, ascending: true)])
    private var categories: FetchedResults<Category>
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Tag.name, ascending: true)])
    private var tags: FetchedResults<Tag>
}

struct EditProductView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            EditProductView(product: PersistenceController.preview.previewProduct())
                .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        }
    }
}
