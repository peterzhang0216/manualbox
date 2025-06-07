import SwiftUI
import CoreData


struct EditTagSheet: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    let tag: Tag
    
    @State private var tagName: String
    @State private var selectedColor: TagColor
    
    init(tag: Tag) {
        self.tag = tag
        _tagName = State(initialValue: tag.name ?? "")
        _selectedColor = State(initialValue: TagColor(rawValue: tag.color ?? "blue") ?? .blue)
    }
    
    var body: some View {
        Form {
            TextField("标签名称", text: $tagName)
            
            Section("选择颜色") {
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 60))
                ], spacing: 15) {
                    ForEach(TagColor.allCases) { color in
                        ColorSelectionButton(
                            color: color,
                            isSelected: selectedColor == color,
                            action: { selectedColor = color }
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
                    updateTag()
                }
                .disabled(tagName.isEmpty)
            }
        }
    }
    
    private func updateTag() {
        tag.name = tagName
        tag.color = selectedColor.rawValue
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("更新标签失败: \(error.localizedDescription)")
        }
    }
}

struct ColorSelectionButton: View {
    let color: TagColor
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack {
                Circle()
                    .fill(color.color)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Circle()
                            .strokeBorder(isSelected ? Color.primary : Color.clear, lineWidth: 2)
                    )
                    .padding(4)
                
                Text(color.displayName)
                    .font(.caption)
                    .foregroundColor(isSelected ? .primary : .secondary)
            }
        }
        .buttonStyle(.plain)
    }
}
