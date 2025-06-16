import SwiftUI
import CoreData

#if os(iOS)
import UIKit
#else
import AppKit
#endif

struct QuickAddProductView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    
    @Binding var isPresented: Bool
    
    @State private var productName = ""
    @State private var brand = ""
    @State private var model = ""
    @State private var selectedCategory: Category?
    @State private var selectedTags: Set<Tag> = []
    @State private var notes = ""
    #if os(iOS)
    @State private var selectedImage: UIImage?
    #else
    @State private var selectedImage: NSImage?
    #endif
    @State private var showingImagePicker = false
    @State private var imageSource: ImageSource = .camera
    
    @FetchRequest(
        entity: Category.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Category.name, ascending: true)]
    ) private var categories: FetchedResults<Category>
    
    @FetchRequest(
        entity: Tag.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Tag.name, ascending: true)]
    ) private var tags: FetchedResults<Tag>
    
    enum ImageSource {
        case camera, photoLibrary
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("产品名称", text: $productName)
                    TextField("品牌", text: $brand)
                    TextField("型号", text: $model)
                } header: {
                    Text("基本信息")
                }
                
                Section(header: Text("分类")) {
                    Picker("分类", selection: $selectedCategory) {
                        Text("未分类").tag(Category?.none)
                        ForEach(categories, id: \.self) { category in
                            Label(category.categoryName, systemImage: category.categoryIcon)
                                .tag(Category?.some(category))
                        }
                    }
                }
                
                if !tags.isEmpty {
                    Section(header: Text("标签")) {
                        LazyVGrid(columns: [
                            GridItem(.adaptive(minimum: 100), spacing: 8)
                        ], spacing: 8) {
                            ForEach(tags, id: \.self) { tag in
                                QuickAddTagChip(
                                    tag: tag,
                                    isSelected: selectedTags.contains(tag)
                                ) {
                                    toggleTag(tag)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                Section(header: Text("产品图片")) {
                    if let selectedImage = selectedImage {
                        HStack {
                            #if os(iOS)
                            Image(uiImage: selectedImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(height: 100)
                                .cornerRadius(8)
                            #else
                            Image(nsImage: selectedImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(height: 100)
                                .cornerRadius(8)
                            #endif
                            
                            Spacer()
                            
                            Button("重新选择") {
                                showingImagePicker = true
                            }
                        }
                    } else {
                        Button(action: { showingImagePicker = true }) {
                            Label("添加图片", systemImage: "camera")
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
                .listRowBackground(Color.clear)
                
                Section(header: Text("产品图片")) {
                    EmptyView()
                }
                
                Section(header: Text("备注")) {
                    TextField("备注", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("快速添加产品")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .navigationBarBackButtonHidden(true)
            .toolbar {
                #if os(iOS)
                ToolbarItemGroup(placement: .topBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("保存") {
                        saveProduct()
                    }
                    .disabled(productName.isEmpty)
                }
                #else
                ToolbarItemGroup(placement: .navigation) {
                    Button("取消") {
                        dismiss()
                    }
                    
                    Spacer()
                    
                    Button("保存") {
                        saveProduct()
                    }
                    .disabled(productName.isEmpty)
                }
                #endif
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            #if os(iOS)
            ImagePickerView(
                selectedImage: $selectedImage,
                sourceType: imageSource == .camera ? .camera : .photoLibrary
            )
            #else
            ImagePickerView(
                selectedImage: $selectedImage,
                sourceType: "file" // macOS上不使用这个参数
            )
            #endif
        }
    }
    
    private func toggleTag(_ tag: Tag) {
        if selectedTags.contains(tag) {
            selectedTags.remove(tag)
        } else {
            selectedTags.insert(tag)
        }
    }
    
    private func saveProduct() {
        let product = Product(context: viewContext)
        product.name = productName
        product.brand = brand.isEmpty ? nil : brand
        product.model = model.isEmpty ? nil : model
        product.category = selectedCategory
        product.tags = NSSet(set: selectedTags)
        product.notes = notes.isEmpty ? nil : notes
        product.createdAt = Date()
        product.updatedAt = Date()
        product.id = UUID()
        
        if let selectedImage = selectedImage {
            // 保存图片数据到 CoreData
            #if os(iOS)
            if let imageData = selectedImage.jpegData(compressionQuality: 0.8) {
                product.imageData = imageData
            }
            #else
            if let imageData = selectedImage.tiffRepresentation,
               let bitmapRep = NSBitmapImageRep(data: imageData),
               let jpegData = bitmapRep.representation(using: .jpeg, properties: [:]) {
                product.imageData = jpegData
            }
            #endif
        }
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("保存产品失败: \(error)")
        }
    }
}

// MARK: - 快速添加标签芯片
struct QuickAddTagChip: View {
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

#if os(iOS)
struct ImagePickerView: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    let sourceType: UIImagePickerController.SourceType
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePickerView
        
        init(_ parent: ImagePickerView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
#else
// macOS 版本的图片选择器
struct ImagePickerView: View {
    @Binding var selectedImage: NSImage?
    let sourceType: String // 在 macOS 上这个参数不使用
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack {
            Text("图片选择功能在 macOS 上暂不可用")
                .foregroundColor(.secondary)
            
            Button("取消") {
                dismiss()
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
}
#endif

#Preview {
    QuickAddProductView(isPresented: .constant(true))
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
