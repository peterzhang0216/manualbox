import SwiftUI

// MARK: - 批量操作界面
struct BatchOperationsSheet: View {
    let selectedCategories: [Category]
    @StateObject private var categoryService = CategoryManagementService.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedOperation: BatchOperation = .move
    @State private var targetCategory: Category?
    @State private var newIcon: String = "folder"
    @State private var newColor: String = "blue"
    @State private var isProcessing = false
    @State private var showingConfirmation = false
    @State private var operationResult: BatchOperationResult?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 选中的分类预览
                selectedCategoriesPreview
                
                Divider()
                
                // 操作选择
                operationSelection
                
                Divider()
                
                // 操作配置
                operationConfiguration
                
                Spacer()
                
                // 执行按钮
                executeButton
            }
            .navigationTitle("批量操作")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar(content: {
                #if os(iOS)
                SwiftUI.ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                #else
                SwiftUI.ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                #endif
            })
        }
        .alert("确认操作", isPresented: $showingConfirmation) {
            Button("确认", role: .destructive) {
                performBatchOperation()
            }
            Button("取消", role: .cancel) { }
        } message: {
            Text(confirmationMessage)
        }
        .alert("操作结果", isPresented: .constant(operationResult != nil)) {
            Button("确定") {
                operationResult = nil
                if operationResult?.isSuccess == true {
                    dismiss()
                }
            }
        } message: {
            if let result = operationResult {
                Text(result.message)
            }
        }
    }
    
    // MARK: - 选中分类预览
    private var selectedCategoriesPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("选中的分类 (\(selectedCategories.count))")
                .font(.headline)
                .fontWeight(.semibold)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(selectedCategories, id: \.id) { category in
                        CategoryChip(category: category)
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding()
        #if os(iOS)
        .background(Color(uiColor: .systemGray6))
        #else
        .background(Color(nsColor: .windowBackgroundColor))
        #endif
    }
    
    // MARK: - 操作选择
    private var operationSelection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("选择操作")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                ForEach(BatchOperation.allCases, id: \.self) { operation in
                    OperationOptionRow(
                        operation: operation,
                        isSelected: selectedOperation == operation,
                        onSelect: {
                            selectedOperation = operation
                        }
                    )
                }
            }
        }
        .padding()
    }
    
    // MARK: - 操作配置
    private var operationConfiguration: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("操作配置")
                .font(.headline)
                .fontWeight(.semibold)
            
            switch selectedOperation {
            case .move:
                moveConfiguration
            case .changeIcon:
                iconConfiguration
            case .changeColor:
                colorConfiguration
            case .delete:
                deleteConfiguration
            }
        }
        .padding()
    }
    
    // MARK: - 移动配置
    private var moveConfiguration: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("选择目标分类")
                .font(.body)
                .fontWeight(.medium)
            
            Menu {
                Button("移动到根级") {
                    targetCategory = nil
                }
                
                Divider()
                
                ForEach(availableTargetCategories, id: \.id) { category in
                    Button(category.fullPath) {
                        targetCategory = category
                    }
                }
            } label: {
                HStack {
                    Text(targetCategory?.fullPath ?? "根级")
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .foregroundColor(.secondary)
                }
                .padding()
                #if os(iOS)
                .background(Color(uiColor: .systemGray6))
                #else
                .background(Color(nsColor: .windowBackgroundColor))
                #endif
                .cornerRadius(8)
            }
            
            Text("将选中的分类移动到指定的父分类下")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - 图标配置
    private var iconConfiguration: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("选择新图标")
                .font(.body)
                .fontWeight(.medium)
            
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 50))
            ], spacing: 12) {
                ForEach(CategoryManagementService.availableIcons, id: \.self) { icon in
                    Button(action: {
                        newIcon = icon
                    }) {
                        Image(systemName: icon)
                            .font(.title2)
                            .foregroundColor(newIcon == icon ? .white : .primary)
                            .frame(width: 40, height: 40)
                            .background(
                                newIcon == icon ? Color.accentColor : (
                                    {
                                        #if os(iOS)
                                        return Color(uiColor: .systemGray6)
                                        #else
                                        return Color(nsColor: .windowBackgroundColor)
                                        #endif
                                    }()
                                )
                            )
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            Text("为所有选中的分类设置相同的图标")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - 颜色配置
    private var colorConfiguration: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("选择新颜色")
                .font(.body)
                .fontWeight(.medium)
            
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 50))
            ], spacing: 12) {
                ForEach(CategoryManagementService.availableColors, id: \.self) { color in
                    Button(action: {
                        newColor = color
                    }) {
                        Circle()
                            .fill(Color(color))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Circle()
                                    .stroke(newColor == color ? Color.primary : Color.clear, lineWidth: 3)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            
            Text("为所有选中的分类设置相同的颜色")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - 删除配置
    private var deleteConfiguration: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                
                Text("危险操作")
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.red)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("• 删除的分类无法恢复")
                Text("• 子分类将移动到父分类下")
                Text("• 分类中的产品将移动到\"其他\"分类")
            }
            .font(.caption)
            .foregroundColor(.secondary)
            
            Text("请确认您要删除这些分类")
                .font(.body)
                .foregroundColor(.red)
        }
        .padding()
        #if os(iOS)
        .background(Color(uiColor: .systemGray6))
        #else
        .background(Color(nsColor: .windowBackgroundColor))
        #endif
        .cornerRadius(8)
    }
    
    // MARK: - 执行按钮
    private var executeButton: some View {
        VStack(spacing: 12) {
            Button(action: {
                showingConfirmation = true
            }) {
                HStack {
                    if isProcessing {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                    
                    Text(selectedOperation.actionTitle)
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isProcessing || !canExecuteOperation)
            .padding(.horizontal)
            
            if !canExecuteOperation {
                Text(validationMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .padding(.bottom)
    }
    
    // MARK: - 计算属性
    
    private var availableTargetCategories: [Category] {
        return categoryService.categories.filter { category in
            // 排除选中的分类和它们的后代
            !selectedCategories.contains(category) &&
            !selectedCategories.contains { $0.isAncestor(of: category) }
        }
    }
    
    private var canExecuteOperation: Bool {
        switch selectedOperation {
        case .move:
            return true // 可以移动到根级
        case .changeIcon, .changeColor:
            return true
        case .delete:
            return !selectedCategories.isEmpty
        }
    }
    
    private var validationMessage: String {
        switch selectedOperation {
        case .move:
            return ""
        case .changeIcon, .changeColor:
            return ""
        case .delete:
            return selectedCategories.isEmpty ? "请选择要删除的分类" : ""
        }
    }
    
    private var confirmationMessage: String {
        switch selectedOperation {
        case .move:
            let target = targetCategory?.categoryName ?? "根级"
            return "确定要将 \(selectedCategories.count) 个分类移动到\"\(target)\"吗？"
        case .changeIcon:
            return "确定要为 \(selectedCategories.count) 个分类设置新图标吗？"
        case .changeColor:
            return "确定要为 \(selectedCategories.count) 个分类设置新颜色吗？"
        case .delete:
            return "确定要删除这 \(selectedCategories.count) 个分类吗？此操作无法撤销。"
        }
    }
    
    // MARK: - 操作方法
    
    private func performBatchOperation() {
        isProcessing = true
        
        Task {
            do {
                switch selectedOperation {
                case .move:
                    try await categoryService.moveCategories(selectedCategories, to: targetCategory)
                    await MainActor.run {
                        operationResult = BatchOperationResult(
                            isSuccess: true,
                            message: "成功移动了 \(selectedCategories.count) 个分类",
                            processedCount: selectedCategories.count,
                            totalCount: selectedCategories.count
                        )
                    }
                    
                case .changeIcon:
                    for category in selectedCategories {
                        try await categoryService.updateCategory(category, icon: newIcon)
                    }
                    await MainActor.run {
                        operationResult = BatchOperationResult(
                            isSuccess: true,
                            message: "成功更新了 \(selectedCategories.count) 个分类的图标",
                            processedCount: selectedCategories.count,
                            totalCount: selectedCategories.count
                        )
                    }
                    
                case .changeColor:
                    for category in selectedCategories {
                        try await categoryService.updateCategory(category, color: newColor)
                    }
                    await MainActor.run {
                        operationResult = BatchOperationResult(
                            isSuccess: true,
                            message: "成功更新了 \(selectedCategories.count) 个分类的颜色",
                            processedCount: selectedCategories.count,
                            totalCount: selectedCategories.count
                        )
                    }
                    
                case .delete:
                    try await categoryService.deleteCategories(selectedCategories)
                    await MainActor.run {
                        operationResult = BatchOperationResult(
                            isSuccess: true,
                            message: "成功删除了 \(selectedCategories.count) 个分类",
                            processedCount: selectedCategories.count,
                            totalCount: selectedCategories.count
                        )
                    }
                }
            } catch {
                await MainActor.run {
                    operationResult = BatchOperationResult(
                        isSuccess: false,
                        message: "操作失败：\(error.localizedDescription)",
                        processedCount: 0,
                        totalCount: selectedCategories.count
                    )
                }
            }
            
            await MainActor.run {
                isProcessing = false
            }
        }
    }
}

// MARK: - 批量操作类型
enum BatchOperation: String, CaseIterable {
    case move = "move"
    case changeIcon = "changeIcon"
    case changeColor = "changeColor"
    case delete = "delete"
    
    var title: String {
        switch self {
        case .move: return "移动分类"
        case .changeIcon: return "更改图标"
        case .changeColor: return "更改颜色"
        case .delete: return "删除分类"
        }
    }
    
    var icon: String {
        switch self {
        case .move: return "arrow.up.and.down.and.arrow.left.and.right"
        case .changeIcon: return "photo"
        case .changeColor: return "paintpalette"
        case .delete: return "trash"
        }
    }
    
    var actionTitle: String {
        switch self {
        case .move: return "移动"
        case .changeIcon: return "更改图标"
        case .changeColor: return "更改颜色"
        case .delete: return "删除"
        }
    }
    
    var color: Color {
        switch self {
        case .move: return .blue
        case .changeIcon: return .green
        case .changeColor: return .orange
        case .delete: return .red
        }
    }
}

// MARK: - 分类芯片
struct CategoryChip: View {
    let category: Category
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: category.categoryIcon)
                .font(.caption)
                .foregroundColor(Color(category.categoryColor))
            
            Text(category.categoryName)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        #if os(iOS)
        .background(Color(uiColor: .systemBackground))
        #else
        .background(Color(nsColor: .windowBackgroundColor))
        #endif
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
    }
}

// MARK: - 操作选项行
struct OperationOptionRow: View {
    let operation: BatchOperation
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: operation.icon)
                    .font(.title3)
                    .foregroundColor(operation.color)
                    .frame(width: 24)
                
                Text(operation.title)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                }
            }
            .padding()
            #if os(iOS)
            .background(Color(uiColor: .systemGray6))
            #else
            .background(Color(nsColor: .windowBackgroundColor))
            #endif
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 批量操作结果
struct CategoryBatchOperationResult {
    let isSuccess: Bool
    let message: String
}

#Preview {
    BatchOperationsSheet(selectedCategories: [])
}
