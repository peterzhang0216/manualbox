import SwiftUI
import PhotosUI
import CoreData
import UniformTypeIdentifiers

struct AddProductView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage("defaultWarrantyPeriod") private var defaultWarrantyPeriod = 12
    @AppStorage("enableOCRByDefault") private var enableOCRByDefault = true
    
    // 选择性地接受绑定，如果没有传入则使用环境变量
    var isPresented: Binding<Bool>?
    
    // 使用StateObject来处理数据
    @StateObject private var viewModel = AddProductViewModel()
    
    init(isPresented: Binding<Bool>? = nil) {
        self.isPresented = isPresented
    }
    
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
            tagSection
            orderInfoSection
            manualSection
            
            if let error = viewModel.saveError {
                Section {
                    Text(error)
                        .foregroundColor(.red)
                }
            }
        }
        .navigationTitle("添加商品")
        .disabled(viewModel.isSaving)
        .overlay {
            if viewModel.isSaving {
                ProgressView("正在保存...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.2))
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") {
                    closeView()
                }
                .disabled(viewModel.isSaving)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    saveProduct()
                }
                .disabled(viewModel.name.isEmpty || viewModel.isSaving)
            }
        }
        .onAppear {
            viewModel.warrantyPeriod = defaultWarrantyPeriod
            viewModel.performOCR = enableOCRByDefault
        }
        .onChange(of: viewModel.selectedImage) { oldValue, newValue in
            viewModel.loadImage(from: newValue)
        }
    }
    
    private var productInfoSection: some View {
        Section {
            TextField("名称", text: $viewModel.name)
            TextField("品牌", text: $viewModel.brand)
            TextField("型号", text: $viewModel.model)
            
            Picker("分类", selection: $viewModel.selectedCategory) {
                Text("未分类").tag(nil as Category?)
                ForEach(categories) { category in
                    Text(category.categoryName).tag(category as Category?)
                }
            }
            
            PhotosPicker(selection: $viewModel.selectedImage,
                        matching: .images,
                        photoLibrary: .shared()) {
                ProductImagePreview(image: viewModel.productImage)
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
                                isSelected: viewModel.selectedTags.contains(tag)) {
                            viewModel.toggleTag(tag)
                        }
                    }
                }
            }
        } header: {
            Text("标签")
        }
    }
    
    private var orderInfoSection: some View {
        Section {
            TextField("订单号", text: $viewModel.orderNumber)
            TextField("购买平台", text: $viewModel.platform)
            DatePicker("购买日期", selection: $viewModel.orderDate, displayedComponents: .date)
            Stepper("保修期：\(viewModel.warrantyPeriod) 个月",
                    value: $viewModel.warrantyPeriod,
                    in: 0...60)
            
            PhotosPicker(selection: $viewModel.invoiceImage,
                        matching: .images,
                        photoLibrary: .shared()) {
                Label("上传发票", systemImage: "doc.text.image")
            }
        } header: {
            Text("订单信息")
        }
    }
    
    private var manualSection: some View {
        Section {
            PhotosPicker(selection: $viewModel.selectedManuals,
                        matching: .any(of: [.images, .not(.livePhotos)]),
                        photoLibrary: .shared()) {
                Label("选择说明书文件", systemImage: "doc.badge.plus")
            }
            
            if !viewModel.selectedManuals.isEmpty {
                Toggle("OCR 文字识别", isOn: $viewModel.performOCR)
            }
        } header: {
            Text("说明书")
        }
    }
    
    private func saveProduct() {
        Task {
            let success = await viewModel.saveProduct(in: viewContext)
            if success {
                await MainActor.run {
                    closeView()
                }
            }
        }
    }
    
    private func closeView() {
        if let isPresented = isPresented {
            isPresented.wrappedValue = false
        } else {
            dismiss()
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
        if let image = image {
            Image(platformImage: image)
                .resizable()
                .scaledToFit()
                .frame(height: 200)
        } else {
            Label("选择商品图片", systemImage: "photo")
        }
    }
}