//
//  EnhancedBatchOperationsView.swift
//  ManualBox
//
//  Created by Assistant on 2024/12/19.
//  增强的批量操作视图 - 支持批量编辑、导出等操作
//

import SwiftUI
import CoreData

struct EnhancedBatchOperationsView: View {
    @StateObject private var batchManager = BatchOperationManager.shared
    @Environment(\.managedObjectContext) private var viewContext
    
    // 选中的项目
    let selectedItems: [NSManagedObject]
    let onDismiss: () -> Void
    
    // 状态管理
    @State private var selectedOperation: BatchOperationType = .export
    @State private var showingOperationSheet = false
    @State private var showingProgressView = false
    @State private var showingHistoryView = false
    @State private var showingConfirmation = false
    
    // 操作参数
    @State private var exportFormat: ExportFormat = .csv
    @State private var selectedCategory: Category?
    @State private var selectedTags: [Tag] = []
    @State private var editFields: [String: Any] = [:]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 顶部信息栏
                topInfoSection
                
                // 操作选择区域
                operationSelectionSection
                
                // 操作参数配置
                operationParametersSection
                
                Spacer()
                
                // 底部操作按钮
                bottomActionSection
            }
            .navigationTitle("批量操作")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        onDismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingHistoryView = true
                    }) {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                }
            }
            .sheet(isPresented: $showingProgressView) {
                BatchOperationProgressView()
            }
            .sheet(isPresented: $showingHistoryView) {
                BatchOperationHistoryView()
            }
            .alert("确认操作", isPresented: $showingConfirmation) {
                Button("取消", role: .cancel) { }
                Button("确认", role: .destructive) {
                    performSelectedOperation()
                }
            } message: {
                Text(confirmationMessage)
            }
        }
    }
    
    // MARK: - 顶部信息栏
    
    private var topInfoSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
                
                Text("已选择 \(selectedItems.count) 个项目")
                    .font(.headline)
                
                Spacer()
                
                if batchManager.operationStatus.isRunning {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            // 选中项目类型统计
            if !selectedItems.isEmpty {
                itemTypeStatistics
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
    }
    
    private var itemTypeStatistics: some View {
        HStack {
            ForEach(itemTypeCounts.keys.sorted(), id: \.self) { type in
                HStack(spacing: 4) {
                    Image(systemName: iconForItemType(type))
                        .foregroundColor(.secondary)
                    
                    Text("\(itemTypeCounts[type] ?? 0)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
    }
    
    // MARK: - 操作选择区域
    
    private var operationSelectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("选择操作")
                .font(.headline)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(BatchOperationType.allCases, id: \.self) { operation in
                        OperationButton(
                            operation: operation,
                            isSelected: selectedOperation == operation,
                            isEnabled: isOperationEnabled(operation)
                        ) {
                            selectedOperation = operation
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
    }
    
    // MARK: - 操作参数配置
    
    private var operationParametersSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if needsParameterConfiguration {
                Text("操作设置")
                    .font(.headline)
                    .padding(.horizontal)
                
                Group {
                    switch selectedOperation {
                    case .export:
                        exportParametersView
                    case .edit:
                        editParametersView
                    case .categorize:
                        categorizeParametersView
                    case .tag:
                        tagParametersView
                    default:
                        EmptyView()
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    private var exportParametersView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("导出格式")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Picker("格式", selection: $exportFormat) {
                ForEach(ExportFormat.allCases, id: \.self) { format in
                    Text(format.displayName)
                        .tag(format)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
        }
    }
    
    private var editParametersView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("编辑字段")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // 这里应该根据选中项目的类型显示可编辑的字段
            Text("选择要批量修改的字段...")
                .foregroundColor(.secondary)
                .italic()
        }
    }
    
    private var categorizeParametersView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("目标分类")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // 分类选择器
            Text("选择分类...")
                .foregroundColor(.secondary)
                .italic()
        }
    }
    
    private var tagParametersView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("标签")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // 标签选择器
            Text("选择标签...")
                .foregroundColor(.secondary)
                .italic()
        }
    }
    
    // MARK: - 底部操作按钮
    
    private var bottomActionSection: some View {
        VStack(spacing: 12) {
            // 操作预览
            if !batchManager.operationStatus.isRunning {
                operationPreview
            }
            
            // 执行按钮
            Button(action: {
                if selectedOperation == .delete {
                    showingConfirmation = true
                } else {
                    performSelectedOperation()
                }
            }) {
                HStack {
                    Image(systemName: selectedOperation.icon)
                    Text("执行\(selectedOperation.displayName)")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canPerformOperation || batchManager.operationStatus.isRunning)
            
            // 取消按钮（仅在操作进行中显示）
            if batchManager.operationStatus.isRunning {
                Button("取消操作") {
                    batchManager.cancelCurrentOperation()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    private var operationPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("操作预览")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text(operationDescription)
                .font(.body)
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)
        }
    }
    
    // MARK: - 计算属性
    
    private var itemTypeCounts: [String: Int] {
        Dictionary(grouping: selectedItems) { item in
            String(describing: type(of: item))
        }.mapValues { $0.count }
    }
    
    private var needsParameterConfiguration: Bool {
        switch selectedOperation {
        case .export, .edit, .categorize, .tag:
            return true
        default:
            return false
        }
    }
    
    private var canPerformOperation: Bool {
        guard !selectedItems.isEmpty else { return false }
        
        switch selectedOperation {
        case .export:
            return true
        case .edit:
            return !editFields.isEmpty
        case .categorize:
            return selectedCategory != nil
        case .tag:
            return !selectedTags.isEmpty
        default:
            return true
        }
    }
    
    private var operationDescription: String {
        switch selectedOperation {
        case .export:
            return "将 \(selectedItems.count) 个项目导出为 \(exportFormat.displayName) 格式"
        case .edit:
            return "批量编辑 \(selectedItems.count) 个项目的指定字段"
        case .delete:
            return "永久删除 \(selectedItems.count) 个项目"
        case .duplicate:
            return "复制 \(selectedItems.count) 个项目"
        case .categorize:
            return "将 \(selectedItems.count) 个项目移动到指定分类"
        case .tag:
            return "为 \(selectedItems.count) 个项目添加标签"
        }
    }
    
    private var confirmationMessage: String {
        switch selectedOperation {
        case .delete:
            return "确定要删除这 \(selectedItems.count) 个项目吗？此操作无法撤销。"
        default:
            return "确定要执行此批量操作吗？"
        }
    }
    
    // MARK: - 辅助方法
    
    private func isOperationEnabled(_ operation: BatchOperationType) -> Bool {
        // 根据选中项目类型判断操作是否可用
        return true
    }
    
    private func iconForItemType(_ type: String) -> String {
        switch type {
        case "Product":
            return "cube.box"
        case "Manual":
            return "doc.text"
        case "Category":
            return "folder"
        case "Tag":
            return "tag"
        default:
            return "doc"
        }
    }
    
    private func performSelectedOperation() {
        showingProgressView = true
        
        Task {
            do {
                switch selectedOperation {
                case .export:
                    _ = try await batchManager.performBatchExport(
                        items: selectedItems,
                        format: exportFormat,
                        destination: getExportDestination()
                    )
                case .edit:
                    _ = try await batchManager.performBatchEdit(
                        items: selectedItems
                    ) { item in
                        // 应用编辑操作
                        applyEditFields(to: item)
                    }
                case .delete:
                    _ = try await batchManager.performBatchDelete(
                        items: selectedItems,
                        context: viewContext
                    )
                    try viewContext.save()
                case .duplicate:
                    _ = try await batchManager.performBatchDuplicate(
                        items: selectedItems,
                        context: viewContext
                    ) { item, context in
                        return try duplicateItem(item, in: context)
                    }
                    try viewContext.save()
                case .categorize:
                    if let category = selectedCategory {
                        _ = try await batchManager.performBatchCategorize(
                            items: selectedItems,
                            category: category
                        ) { item, category in
                            assignCategory(category, to: item)
                        }
                        try viewContext.save()
                    }
                case .tag:
                    _ = try await batchManager.performBatchTag(
                        items: selectedItems,
                        tags: selectedTags
                    ) { item, tags in
                        assignTags(tags, to: item)
                    }
                    try viewContext.save()
                }
                
                // 操作完成后关闭视图
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    onDismiss()
                }
                
            } catch {
                print("批量操作失败: \(error.localizedDescription)")
            }
        }
    }
    
    private func getExportDestination() -> URL {
        // 返回导出目标URL
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("batch_export.\(exportFormat.fileExtension)")
    }
    
    private func applyEditFields(to item: NSManagedObject) {
        // 应用编辑字段到项目
        for (key, value) in editFields {
            item.setValue(value, forKey: key)
        }
    }
    
    private func duplicateItem(_ item: NSManagedObject, in context: NSManagedObjectContext) throws -> NSManagedObject {
        // 复制项目的实现
        // 这里应该根据具体的数据模型实现复制逻辑
        let entityName = item.entity.name!
        let newItem = NSEntityDescription.insertNewObject(forEntityName: entityName, into: context)
        
        // 复制属性
        for (key, value) in item.dictionaryWithValues(forKeys: Array(item.entity.attributesByName.keys)) {
            if key != "id" && key != "createdAt" { // 跳过唯一标识符和时间戳
                newItem.setValue(value, forKey: key)
            }
        }
        
        return newItem
    }
    
    private func assignCategory(_ category: Category, to item: NSManagedObject) {
        // 分配分类到项目
        if let product = item as? Product {
            product.category = category
        }
    }
    
    private func assignTags(_ tags: [Tag], to item: NSManagedObject) {
        // 分配标签到项目
        if let product = item as? Product {
            for tag in tags {
                product.addToTags(tag)
            }
        }
    }
}

// MARK: - 操作按钮
struct OperationButton: View {
    let operation: BatchOperationType
    let isSelected: Bool
    let isEnabled: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: operation.icon)
                    .font(.title2)
                
                Text(operation.displayName)
                    .font(.caption)
            }
            .frame(width: 80, height: 80)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue : Color(.secondarySystemBackground))
            )
            .foregroundColor(isSelected ? .white : (isEnabled ? .primary : .secondary))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .disabled(!isEnabled)
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    EnhancedBatchOperationsView(
        selectedItems: [],
        onDismiss: {}
    )
}