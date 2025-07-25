import SwiftUI
import CoreData
import PhotosUI

#if os(iOS)
import UIKit
#else
import AppKit
#endif

struct QuickAddProductView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext

    @Binding var isPresented: Bool
    let defaultCategory: Category?
    let defaultTag: Tag?

    init(isPresented: Binding<Bool>, defaultCategory: Category? = nil, defaultTag: Tag? = nil) {
        self._isPresented = isPresented
        self.defaultCategory = defaultCategory
        self.defaultTag = defaultTag
    }
    
    @State private var productName = ""
    @State private var brand = ""
    @State private var model = ""
    @State private var selectedCategory: Category?
    @State private var selectedTags: Set<Tag> = []
    @State private var notes = ""
    @State private var hasInitializedDefaults = false
    #if os(iOS)
    @State private var selectedImage: UIImage?
    #else
    @State private var selectedImage: NSImage?
    #endif
    @State private var selectedPhotoItem: PhotosPickerItem?
    
    @FetchRequest(
        entity: Category.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Category.name, ascending: true)]
    ) private var categories: FetchedResults<Category>
    
    @FetchRequest(
        entity: Tag.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Tag.name, ascending: true)]
    ) private var tags: FetchedResults<Tag>
    


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
                basicInfoSection
                categorySection
                tagsSection
                imageSection
                notesSection
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(backgroundGradient)
            .navigationTitle("快速添加产品")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .navigationBarBackButtonHidden(true)
            .toolbar(content: {
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
                SwiftUI.ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                }

                SwiftUI.ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveProduct()
                    }
                    .disabled(productName.isEmpty)
                    .foregroundColor(productName.isEmpty ? .secondary : .blue)
                    .fontWeight(.medium)
                }
                #endif
            })
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task {
                if let newItem = newItem {
                    await loadImageFromPhotoItem(newItem)
                }
            }
        }
        .onAppear {
            initializeDefaults()
        }
    }
    
    private func toggleTag(_ tag: Tag) {
        if selectedTags.contains(tag) {
            selectedTags.remove(tag)
        } else {
            selectedTags.insert(tag)
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

    // MARK: - 图片加载
    private func loadImageFromPhotoItem(_ item: PhotosPickerItem) async {
        do {
            if let data = try await item.loadTransferable(type: Data.self) {
                #if os(iOS)
                if let uiImage = UIImage(data: data) {
                    await MainActor.run {
                        selectedImage = uiImage
                    }
                }
                #else
                if let nsImage = NSImage(data: data) {
                    await MainActor.run {
                        selectedImage = nsImage
                    }
                }
                #endif
            }
        } catch {
            print("加载图片失败: \(error)")
        }
    }
    
    // MARK: - 视图组件
    private var basicInfoSection: some View {
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
    }

    private var categorySection: some View {
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
    }

    @ViewBuilder
    private var tagsSection: some View {
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
    }

    private var imageSection: some View {
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

                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            Text("重新选择图片")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                } else {
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        VStack(spacing: 8) {
                            Image(systemName: "photo.fill")
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
    }

    private var notesSection: some View {
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



#Preview {
    QuickAddProductView(isPresented: .constant(true))
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
