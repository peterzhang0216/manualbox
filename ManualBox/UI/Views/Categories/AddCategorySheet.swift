import SwiftUI

// MARK: - 添加分类界面
struct AddCategorySheet: View {
    let parentCategory: Category?
    @StateObject private var categoryService = CategoryManagementService.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var categoryName = ""
    @State private var selectedIcon = "folder"
    @State private var selectedColor = "blue"
    @State private var isSaving = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            Form {
                // 基本信息
                Section {
                    TextField("分类名称", text: $categoryName)
                        .textFieldStyle(.roundedBorder)
                    
                    if let parent = parentCategory {
                        HStack {
                            Text("父分类")
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            HStack(spacing: 6) {
                                Image(systemName: parent.categoryIcon)
                                    .foregroundColor(Color(parent.categoryColor))
                                
                                Text(parent.categoryName)
                                    .fontWeight(.medium)
                            }
                        }
                    }
                } header: {
                    Text("基本信息")
                } footer: {
                    if let parent = parentCategory {
                        Text("新分类将创建在「\(parent.categoryName)」下")
                    } else {
                        Text("新分类将创建为根级分类")
                    }
                }
                
                // 图标选择
                Section {
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 50))
                    ], spacing: 12) {
                        ForEach(CategoryManagementService.availableIcons, id: \.self) { icon in
                            Button(action: {
                                selectedIcon = icon
                            }) {
                                Image(systemName: icon)
                                    .font(.title2)
                                    .foregroundColor(selectedIcon == icon ? .white : .primary)
                                    .frame(width: 44, height: 44)
                                    .background(selectedIcon == icon ? Color.accentColor : Color(.systemGray6))
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("选择图标")
                }
                
                // 颜色选择
                Section {
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 50))
                    ], spacing: 12) {
                        ForEach(CategoryManagementService.availableColors, id: \.self) { color in
                            Button(action: {
                                selectedColor = color
                            }) {
                                Circle()
                                    .fill(Color(color))
                                    .frame(width: 44, height: 44)
                                    .overlay(
                                        Circle()
                                            .stroke(selectedColor == color ? Color.primary : Color.clear, lineWidth: 3)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("选择颜色")
                }
                
                // 预览
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: selectedIcon)
                            .font(.title)
                            .foregroundColor(Color(selectedColor))
                            .frame(width: 40, height: 40)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(categoryName.isEmpty ? "分类名称" : categoryName)
                                .font(.headline)
                                .fontWeight(.medium)
                                .foregroundColor(categoryName.isEmpty ? .secondary : .primary)
                            
                            if let parent = parentCategory {
                                Text("\(parent.fullPath) > \(categoryName.isEmpty ? "新分类" : categoryName)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            } else {
                                Text("根级分类")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                } header: {
                    Text("预览")
                }
                
                // 错误信息
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("添加分类")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                SwiftUI.ToolbarItem(placement: .topBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                SwiftUI.ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
                        saveCategory()
                    }
                    .disabled(categoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                }
            }
        }
    }
    
    // MARK: - 操作方法
    
    private func saveCategory() {
        let trimmedName = categoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedName.isEmpty else {
            errorMessage = "请输入分类名称"
            return
        }
        
        isSaving = true
        errorMessage = nil
        
        Task {
            do {
                _ = try await categoryService.createCategory(
                    name: trimmedName,
                    icon: selectedIcon,
                    color: selectedColor,
                    parent: parentCategory
                )
                
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "创建分类失败：\(error.localizedDescription)"
                    isSaving = false
                }
            }
        }
    }
}

#Preview {
    AddCategorySheet(parentCategory: nil)
}
