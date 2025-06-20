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

    private var backgroundGradient: LinearGradient {
        #if os(iOS)
        return LinearGradient(
            colors: [
                Color(UIColor.systemBackground),
                Color(UIColor.systemGroupedBackground)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        #else
        return LinearGradient(
            colors: [
                Color(NSColor.controlBackgroundColor),
                Color(NSColor.controlBackgroundColor).opacity(0.8)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        #endif
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // 基本信息区域
                Section {
                    VStack(spacing: 12) {
                        TextField("产品名称", text: $productName)
                            .textFieldStyle(.roundedBorder)

                        HStack(spacing: 12) {
                            TextField("品牌", text: $brand)
                                .textFieldStyle(.roundedBorder)
                            TextField("型号", text: $model)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                        Text("基本信息")
                    }
                }
                .listRowBackground(Color.clear)

                // 分类选择区域
                Section {
                    Picker("分类", selection: $selectedCategory) {
                        Text("未分类").tag(Category?.none)
                        ForEach(categories, id: \.self) { category in
                            Label(category.categoryName, systemImage: category.categoryIcon)
                                .tag(Category?.some(category))
                        }
                    }
                    .pickerStyle(.menu)
                    .padding(.vertical, 4)
                } header: {
                    HStack {
                        Image(systemName: "folder")
                            .foregroundColor(.orange)
                        Text("分类")
                    }
                }

                // 标签选择区域
                if !tags.isEmpty {
                    Section {
                        LazyVGrid(columns: [
                            GridItem(.adaptive(minimum: 90), spacing: 8)
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
                        .padding(.vertical, 8)
                    } header: {
                        HStack {
                            Image(systemName: "tag")
                                .foregroundColor(.green)
                            Text("标签")
                            Spacer()
                            if !selectedTags.isEmpty {
                                Text("已选择 \(selectedTags.count) 个")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .listRowBackground(Color.clear)
                }

                // 产品图片区域
                Section {
                    VStack(spacing: 12) {
                        if let selectedImage = selectedImage {
                            VStack(spacing: 8) {
                                #if os(iOS)
                                Image(uiImage: selectedImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxHeight: 120)
                                    .cornerRadius(12)
                                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                                #else
                                Image(nsImage: selectedImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxHeight: 120)
                                    .cornerRadius(12)
                                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                                #endif

                                Button("重新选择图片") {
                                    showingImagePicker = true
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        } else {
                            Button(action: { showingImagePicker = true }) {
                                VStack(spacing: 8) {
                                    Image(systemName: "camera.fill")
                                        .font(.title2)
                                        .foregroundColor(.blue)
                                    Text("添加产品图片")
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 80)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.blue.opacity(0.1))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.blue.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [5]))
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    HStack {
                        Image(systemName: "photo")
                            .foregroundColor(.purple)
                        Text("产品图片")
                    }
                }
                .listRowBackground(Color.clear)

                // 备注区域
                Section {
                    TextField("添加产品备注信息...", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                        .textFieldStyle(.roundedBorder)
                        .padding(.vertical, 4)
                } header: {
                    HStack {
                        Image(systemName: "note.text")
                            .foregroundColor(.gray)
                        Text("备注")
                    }
                }
                .listRowBackground(Color.clear)
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(backgroundGradient)
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
                    .foregroundColor(.secondary)
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("保存") {
                        saveProduct()
                    }
                    .disabled(productName.isEmpty)
                    .foregroundColor(productName.isEmpty ? .secondary : .blue)
                    .fontWeight(.medium)
                }
                #else
                ToolbarItemGroup(placement: .navigation) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(.secondary)

                    Spacer()

                    Button("保存") {
                        saveProduct()
                    }
                    .disabled(productName.isEmpty)
                    .foregroundColor(productName.isEmpty ? .secondary : .blue)
                    .fontWeight(.medium)
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
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(isSelected ? tag.uiColor.opacity(0.15) : Color.secondary.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(isSelected ? tag.uiColor.opacity(0.6) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
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
