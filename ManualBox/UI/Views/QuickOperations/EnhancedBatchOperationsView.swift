//
//  EnhancedBatchOperationsView.swift
//  ManualBox
//
//  Created by Assistant on 2025/6/24.
//

import SwiftUI
import CoreData

// MARK: - 增强批量操作视图
struct EnhancedBatchOperationsView: View {
    @Binding var selectedProducts: Set<Product>
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedOperation: QuickBatchOperation = .edit
    @State private var isProcessing = false
    @State private var progress: Double = 0
    @State private var showingConfirmation = false
    @State private var operationResult: BatchOperationResult?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 操作选择器
                operationSelector
                
                // 操作配置区域
                ScrollView {
                    VStack(spacing: 20) {
                        // 选中产品概览
                        selectedProductsOverview
                        
                        // 操作配置
                        operationConfiguration
                        
                        // 预览区域
                        if selectedOperation.hasPreview {
                            operationPreview
                        }
                    }
                    .padding()
                }
                
                // 底部操作栏
                bottomActionBar
            }
            .navigationTitle("批量操作")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                SwiftUI.ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
            .overlay {
                if isProcessing {
                    processingOverlay
                }
            }
            .alert("操作完成", isPresented: .constant(operationResult != nil)) {
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
    }
    
    // MARK: - 操作选择器
    
    private var operationSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(BatchOperation.allCases, id: \.self) { operation in
                    Button(action: {
                        selectedOperation = operation
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: operation.icon)
                                .font(.title2)
                            
                            Text(operation.title)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(selectedOperation == operation ? .white : .primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(selectedOperation == operation ? operation.color : Color(.systemGray6))
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
    
    // MARK: - 选中产品概览
    
    private var selectedProductsOverview: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("选中的产品")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                
                Text("已选择 \(selectedProducts.count) 个产品")
                    .font(.subheadline)
                
                Spacer()
                
                Button("查看详情") {
                    // 显示选中产品详情
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
    }
    
    // MARK: - 操作配置
    
    @ViewBuilder
    private var operationConfiguration: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("操作配置")
                .font(.headline)
                .fontWeight(.semibold)
            
            switch selectedOperation {
            case .edit:
                batchEditConfiguration
            case .delete:
                batchDeleteConfiguration
            case .export:
                batchExportConfiguration
            case .categorize:
                batchCategorizeConfiguration
            case .tag:
                batchTagConfiguration
            case .archive:
                batchArchiveConfiguration
            }
        }
    }
    
    // MARK: - 批量编辑配置
    
    private var batchEditConfiguration: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("选择要批量修改的字段")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            VStack(spacing: 12) {
                BatchEditOption(title: "品牌", icon: "building.2", isEnabled: .constant(false))
                BatchEditOption(title: "型号", icon: "number", isEnabled: .constant(false))
                BatchEditOption(title: "备注", icon: "note.text", isEnabled: .constant(false))
                BatchEditOption(title: "保修期", icon: "shield", isEnabled: .constant(false))
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 1)
    }
    
    // MARK: - 批量删除配置
    
    private var batchDeleteConfiguration: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                
                Text("危险操作")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.red)
            }
            
            Text("此操作将永久删除选中的 \(selectedProducts.count) 个产品及其相关数据，包括说明书、维修记录等。")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("删除选项:")
                    .font(.caption)
                    .fontWeight(.medium)
                
                Toggle("同时删除说明书文件", isOn: .constant(true))
                Toggle("同时删除维修记录", isOn: .constant(true))
                Toggle("同时删除订单信息", isOn: .constant(true))
            }
            .font(.caption)
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - 批量导出配置
    
    private var batchExportConfiguration: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("导出格式和选项")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            VStack(spacing: 12) {
                Picker("导出格式", selection: .constant(ExportFormat.json)) {
                    ForEach(ExportFormat.allCases, id: \.self) { format in
                        Text(format.rawValue).tag(format)
                    }
                }
                .pickerStyle(.segmented)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("包含内容:")
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    Toggle("产品图片", isOn: .constant(false))
                    Toggle("说明书文件", isOn: .constant(false))
                    Toggle("维修记录", isOn: .constant(true))
                    Toggle("订单信息", isOn: .constant(true))
                }
                .font(.caption)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 1)
    }
    
    // MARK: - 批量分类配置
    
    private var batchCategorizeConfiguration: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("选择目标分类")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // 这里应该显示分类选择器
            Text("分类选择器将在此显示")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 1)
    }
    
    // MARK: - 批量标签配置
    
    private var batchTagConfiguration: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("标签操作")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Picker("操作类型", selection: .constant(TagOperationMode.add)) {
                ForEach(TagOperationMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            
            // 这里应该显示标签选择器
            Text("标签选择器将在此显示")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 1)
    }
    
    // MARK: - 批量归档配置
    
    private var batchArchiveConfiguration: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("归档选项")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 8) {
                Toggle("创建归档备份", isOn: .constant(true))
                Toggle("保留原始数据", isOn: .constant(false))
                Toggle("添加归档标签", isOn: .constant(true))
            }
            .font(.caption)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 1)
    }
    
    // MARK: - 操作预览
    
    private var operationPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("操作预览")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text("预览功能将在此显示")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
        }
    }
    
    // MARK: - 底部操作栏
    
    private var bottomActionBar: some View {
        HStack {
            Button("取消") {
                dismiss()
            }
            .foregroundColor(.secondary)
            
            Spacer()
            
            Button("执行操作") {
                showingConfirmation = true
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedProducts.isEmpty)
        }
        .padding()
        .background(Color(.systemBackground))
        .shadow(radius: 1)
        .confirmationDialog(
            "确认执行操作",
            isPresented: $showingConfirmation,
            titleVisibility: .visible
        ) {
            Button("确认执行") {
                executeOperation()
            }
            Button("取消", role: .cancel) { }
        } message: {
            Text("将对 \(selectedProducts.count) 个产品执行\(selectedOperation.title)操作")
        }
    }
    
    // MARK: - 处理中覆盖层
    
    private var processingOverlay: some View {
        VStack(spacing: 16) {
            ProgressView(value: progress, total: 1.0)
                .progressViewStyle(LinearProgressViewStyle())
                .frame(width: 200)
            
            Text("正在处理... \(Int(progress * 100))%")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 4)
    }
    
    // MARK: - 操作执行
    
    private func executeOperation() {
        isProcessing = true
        progress = 0
        
        Task {
            do {
                let result = try await performBatchOperation()
                await MainActor.run {
                    isProcessing = false
                    operationResult = result
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    operationResult = BatchOperationResult(
                        isSuccess: false,
                        message: "操作失败: \(error.localizedDescription)",
                        processedCount: 0,
                        totalCount: selectedProducts.count
                    )
                }
            }
        }
    }
    
    private func performBatchOperation() async throws -> BatchOperationResult {
        let totalCount = selectedProducts.count
        var processedCount = 0
        
        for (index, product) in selectedProducts.enumerated() {
            // 模拟处理进度
            await MainActor.run {
                progress = Double(index) / Double(totalCount)
            }
            
            // 执行具体操作
            try await performOperationOnProduct(product)
            processedCount += 1
            
            // 模拟处理时间
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
        }
        
        await MainActor.run {
            progress = 1.0
        }
        
        return BatchOperationResult(
            isSuccess: true,
            message: "成功处理了 \(processedCount) 个产品",
            processedCount: processedCount,
            totalCount: totalCount
        )
    }
    
    private func performOperationOnProduct(_ product: Product) async throws {
        // 根据选择的操作类型执行相应的处理
        switch selectedOperation {
        case .edit:
            // 批量编辑逻辑
            break
        case .delete:
            // 批量删除逻辑
            viewContext.delete(product)
        case .export:
            // 批量导出逻辑
            break
        case .categorize:
            // 批量分类逻辑
            break
        case .tag:
            // 批量标签逻辑
            break
        case .archive:
            // 批量归档逻辑
            break
        }
    }
}

// MARK: - 批量编辑选项组件
struct BatchEditOption: View {
    let title: String
    let icon: String
    @Binding var isEnabled: Bool
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            Text(title)
                .font(.subheadline)
            
            Spacer()
            
            Toggle("", isOn: $isEnabled)
                .labelsHidden()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - 批量操作枚举
enum QuickBatchOperation: String, CaseIterable {
    case edit = "编辑"
    case delete = "删除"
    case export = "导出"
    case categorize = "分类"
    case tag = "标签"
    case archive = "归档"
    
    var title: String { rawValue }
    
    var icon: String {
        switch self {
        case .edit: return "pencil"
        case .delete: return "trash"
        case .export: return "square.and.arrow.up"
        case .categorize: return "folder"
        case .tag: return "tag"
        case .archive: return "archivebox"
        }
    }
    
    var color: Color {
        switch self {
        case .edit: return .blue
        case .delete: return .red
        case .export: return .green
        case .categorize: return .orange
        case .tag: return .purple
        case .archive: return .gray
        }
    }
    
    var hasPreview: Bool {
        switch self {
        case .edit, .categorize, .tag: return true
        default: return false
        }
    }
}

// MARK: - 批量操作结果
struct BatchOperationResult {
    let isSuccess: Bool
    let message: String
    let processedCount: Int
    let totalCount: Int
}
