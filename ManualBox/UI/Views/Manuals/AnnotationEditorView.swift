import SwiftUI

// MARK: - 标注编辑器视图
struct AnnotationEditorView: View {
    let text: String
    @Binding var note: String
    @Binding var type: AnnotationType
    @Binding var color: AnnotationColor
    let onSave: () -> Void
    let onCancel: () -> Void
    
    @State private var tempNote: String = ""
    @State private var tempType: AnnotationType = .highlight
    @State private var tempColor: AnnotationColor = .yellow
    
    var body: some View {
        NavigationView {
            Form {
                // 选中的文本
                Section("选中文本") {
                    Text(text)
                        .padding()
                        #if os(iOS)
                        .background(Color(UIColor.systemGray6))
                        #else
                        .background(Color(NSColor.windowBackgroundColor))
                        #endif
                        .cornerRadius(8)
                        .lineLimit(nil)
                }
                
                // 标注类型
                Section("标注类型") {
                    VStack(spacing: 12) {
                        ForEach(AnnotationType.allCases, id: \.self) { annotationType in
                            AnnotationTypeRow(
                                type: annotationType,
                                isSelected: tempType == annotationType,
                                onSelect: {
                                    tempType = annotationType
                                }
                            )
                        }
                    }
                }
                
                // 颜色选择
                Section("标注颜色") {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ForEach(AnnotationColor.allCases, id: \.self) { annotationColor in
                            ColorSelectionButton(
                                color: annotationColor,
                                isSelected: tempColor == annotationColor,
                                onSelect: {
                                    tempColor = annotationColor
                                }
                            )
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                // 笔记
                Section("笔记（可选）") {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("添加笔记...", text: $tempNote, axis: .vertical)
                            .lineLimit(3...6)
                            .textFieldStyle(.roundedBorder)
                        
                        Text("为这个标注添加详细说明或个人想法")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // 预览
                Section("预览") {
                    AnnotationPreview(
                        text: text,
                        type: tempType,
                        color: tempColor,
                        note: tempNote
                    )
                }
            }
            .navigationTitle("编辑标注")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                SwiftUI.ToolbarItem(placement: .topBarLeading) {
                    Button("取消") {
                        onCancel()
                    }
                }
                SwiftUI.ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
                        saveAnnotation()
                    }
                    .disabled(text.isEmpty)
                }
            }
            #else
            .toolbar {
                SwiftUI.ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        onCancel()
                    }
                }
                SwiftUI.ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveAnnotation()
                    }
                    .disabled(text.isEmpty)
                }
            }
            #endif
        }
        .onAppear {
            tempNote = note
            tempType = type
            tempColor = color
        }
    }
    
    private func saveAnnotation() {
        note = tempNote
        type = tempType
        color = tempColor
        onSave()
    }
}

// MARK: - 标注类型行
struct AnnotationTypeRow: View {
    let type: AnnotationType
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: type.icon)
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? .white : .accentColor)
                    .frame(width: 32, height: 32)
                    .background(isSelected ? Color.accentColor : Color.accentColor.opacity(0.1))
                    .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(type.displayName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Text(type.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 颜色选择按钮
struct ColorSelectionButton: View {
    let color: AnnotationColor
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 6) {
                Circle()
                    .fill(Color(color.swiftUIColor))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Circle()
                            .stroke(isSelected ? Color.primary : Color.clear, lineWidth: 3)
                    )
                    .overlay(
                        Circle()
                            #if os(iOS)
                            .stroke(Color(UIColor.systemGray4), lineWidth: 1)
                            #else
                            .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                            #endif
                    )
                
                Text(color.displayName)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 标注预览
struct AnnotationPreview: View {
    let text: String
    let type: AnnotationType
    let color: AnnotationColor
    let note: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标注效果预览
            VStack(alignment: .leading, spacing: 8) {
                Text("标注效果:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(text)
                    .modifier(AnnotationStyleModifier(type: type, color: color))
                    .padding()
                    #if os(iOS)
                    .background(Color(UIColor.systemGray6))
                    #else
                    .background(Color(NSColor.windowBackgroundColor))
                    #endif
                    .cornerRadius(8)
            }
            
            // 笔记预览
            if !note.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("笔记:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "note.text")
                            .font(.caption)
                            .foregroundColor(.blue)
                        
                        Text(note)
                            .font(.caption)
                            .foregroundColor(.primary)
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            
            // 标注信息
            VStack(alignment: .leading, spacing: 4) {
                Text("标注信息:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    Label(type.displayName, systemImage: type.icon)
                        .font(.caption)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color(color.swiftUIColor))
                            .frame(width: 12, height: 12)
                        
                        Text(color.displayName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - 标注样式修饰符
struct AnnotationStyleModifier: ViewModifier {
    let type: AnnotationType
    let color: AnnotationColor
    
    func body(content: Content) -> some View {
        switch type {
        case .highlight:
            content
                .background(Color(color.swiftUIColor).opacity(0.3))
                .cornerRadius(4)
                
        case .underline:
            content
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(Color(color.swiftUIColor)),
                    alignment: .bottom
                )
                
        case .note:
            content
                .background(Color.blue.opacity(0.2))
                .cornerRadius(4)
                .overlay(
                    Image(systemName: "note.text")
                        .font(.caption2)
                        .foregroundColor(.blue),
                    alignment: .topTrailing
                )
                
        case .bookmark:
            content
                .background(Color.orange.opacity(0.2))
                .cornerRadius(4)
                .overlay(
                    Image(systemName: "bookmark.fill")
                        .font(.caption2)
                        .foregroundColor(.orange),
                    alignment: .topTrailing
                )
                
        case .important:
            content
                .fontWeight(.bold)
                .background(Color.red.opacity(0.2))
                .cornerRadius(4)
                .overlay(
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundColor(.red),
                    alignment: .topTrailing
                )
        }
    }
}

// MARK: - 扩展标注类型描述
extension AnnotationType {
    var description: String {
        switch self {
        case .highlight:
            return "高亮显示重要内容"
        case .underline:
            return "在文本下方添加下划线"
        case .note:
            return "添加详细笔记和说明"
        case .bookmark:
            return "标记为书签便于查找"
        case .important:
            return "标记为重要内容"
        }
    }
}

#Preview {
    AnnotationEditorView(
        text: "这是一段示例文本，用于演示标注功能的效果。",
        note: .constant(""),
        type: .constant(.highlight),
        color: .constant(.yellow),
        onSave: {},
        onCancel: {}
    )
}
