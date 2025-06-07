import SwiftUI
import CoreData


struct EditCategorySheet: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    let category: Category
    
    @State private var categoryName: String
    @State private var selectedIcon: String
    
    init(category: Category) {
        self.category = category
        _categoryName = State(initialValue: category.name ?? "")
        _selectedIcon = State(initialValue: category.icon ?? "folder")
    }
    
    var body: some View {
        Form {
            TextField("分类名称", text: $categoryName)
            
            Section("选择图标") {
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 60))
                ], spacing: 15) {
                    ForEach(categoryIcons, id: \.self) { icon in
                        IconSelectionButton(
                            icon: icon,
                            isSelected: selectedIcon == icon,
                            action: { selectedIcon = icon }
                        )
                    }
                }
                .padding(.vertical)
            }
        }
        .formStyle(.grouped)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    updateCategory()
                }
                .disabled(categoryName.isEmpty)
            }
        }
    }
    
    private func updateCategory() {
        category.name = categoryName
        category.icon = selectedIcon
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("更新分类失败: \(error.localizedDescription)")
        }
    }
}

struct IconSelectionButton: View {
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .frame(width: 44, height: 44)
                    .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
                    .foregroundColor(isSelected ? .accentColor : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                    )
            }
        }
        .buttonStyle(.plain)
    }
}

// 系统图标列表
let categoryIcons = [
    "folder",
    "laptopcomputer",
    "desktopcomputer",
    "tv",
    "phone",
    "headphones",
    "printer",
    "camera",
    "gamecontroller",
    "keyboard",
    "wifi",
    "car",
    "bicycle",
    "bed.double",
    "chair",
    "lamp.desk",
    "shower",
    "washer",
    "refrigerator",
    "oven",
    "microwave",
    "wineglass",
    "fork.knife",
    "cross",
    "leaf",
    "paintbrush",
    "hammer",
    "wrench",
    "scissors",
    "bag",
    "cart",
    "creditcard",
    "gift",
    "heart",
    "star",
    "flag"
]
