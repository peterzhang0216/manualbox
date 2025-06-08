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
            viewModel.send(.updateWarrantyPeriod(defaultWarrantyPeriod))
            viewModel.send(.updatePerformOCR(enableOCRByDefault))
        }
        .onChange(of: viewModel.selectedImage) { oldValue, newValue in
            viewModel.loadImage(from: newValue)
        }
    }
    
    private var productInfoSection: some View {
        Section {
            TextField("名称", text: Binding(
                get: { viewModel.name },
                set: { viewModel.send(.updateName($0)) }
            ))
            TextField("品牌", text: Binding(
                get: { viewModel.brand },
                set: { viewModel.send(.updateBrand($0)) }
            ))
            TextField("型号", text: Binding(
                get: { viewModel.model },
                set: { viewModel.send(.updateModel($0)) }
            ))
            
            Picker("分类", selection: Binding(
                get: { viewModel.selectedCategory },
                set: { viewModel.send(.updateSelectedCategory($0)) }
            )) {
                Text("未分类").tag(nil as Category?)
                ForEach(categories) { category in
                    Text(category.categoryName).tag(category as Category?)
                }
            }
            
            PhotosPicker(selection: Binding(
                get: { viewModel.selectedImage },
                set: { viewModel.send(.updateSelectedImage($0)) }
            ),
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
            TextField("订单号", text: Binding(
                get: { viewModel.orderNumber },
                set: { viewModel.send(.updateOrderNumber($0)) }
            ))
            TextField("购买平台", text: Binding(
                get: { viewModel.platform },
                set: { viewModel.send(.updatePlatform($0)) }
            ))
            DatePicker("购买日期", selection: Binding(
                get: { viewModel.orderDate },
                set: { viewModel.send(.updateOrderDate($0)) }
            ), displayedComponents: .date)
            Stepper("保修期：\(viewModel.warrantyPeriod) 个月",
                    value: Binding(
                        get: { viewModel.warrantyPeriod },
                        set: { viewModel.send(.updateWarrantyPeriod($0)) }
                    ),
                    in: 0...60)
            
            PhotosPicker(selection: Binding(
                get: { viewModel.invoiceImage },
                set: { viewModel.send(.updateInvoiceImage($0)) }
            ),
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
            PhotosPicker(selection: Binding(
                get: { viewModel.selectedManuals },
                set: { viewModel.send(.updateSelectedManuals($0)) }
            ),
                        matching: .any(of: [.images, .not(.livePhotos)]),
                        photoLibrary: .shared()) {
                Label("选择说明书文件", systemImage: "doc.badge.plus")
            }
            
            if !viewModel.selectedManuals.isEmpty {
                Toggle("OCR 文字识别", isOn: Binding(
                    get: { viewModel.performOCR },
                    set: { viewModel.send(.updatePerformOCR($0)) }
                ))
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
