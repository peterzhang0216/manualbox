//
//  ConflictResolutionView.swift
//  ManualBox
//
//  Created by Assistant on 2024/12/19.
//  冲突解决界面 - 提供直观的冲突解决用户界面
//

import SwiftUI
import CloudKit

struct ConflictResolutionView: View {
    @StateObject private var conflictResolver = CloudKitConflictResolver(
        context: PersistenceController.shared.container.viewContext
    )
    @State private var selectedConflict: SyncConflict?
    @State private var showingResolutionSheet = false
    @State private var showingBatchResolution = false
    @State private var selectedStrategy: ConflictResolutionStrategy = .lastModifiedWins
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 顶部统计信息
                conflictSummaryHeader
                
                if conflictResolver.pendingConflicts.isEmpty {
                    // 无冲突状态
                    emptyStateView
                } else {
                    // 冲突列表
                    conflictListView
                }
            }
            .navigationTitle("冲突解决")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    if !conflictResolver.pendingConflicts.isEmpty {
                        Button("批量解决") {
                            showingBatchResolution = true
                        }
                    }
                    
                    Menu {
                        settingsMenuContent
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(item: $selectedConflict) { conflict in
            ConflictDetailSheet(
                conflict: conflict,
                resolver: conflictResolver
            )
        }
        .sheet(isPresented: $showingBatchResolution) {
            BatchResolutionSheet(
                conflicts: conflictResolver.pendingConflicts,
                resolver: conflictResolver
            )
        }
    }
    
    // MARK: - 冲突摘要头部
    
    private var conflictSummaryHeader: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("待解决冲突")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("\(conflictResolver.pendingConflicts.count) 个冲突需要处理")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("已解决")
                        .font(.headline)
                        .foregroundColor(.green)
                    
                    Text("\(conflictResolver.resolvedConflicts.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // 自动解决开关
            HStack {
                Text("自动解决轻微冲突")
                    .font(.subheadline)
                
                Spacer()
                
                Toggle("", isOn: Binding(
                    get: { conflictResolver.autoResolveEnabled },
                    set: { conflictResolver.setAutoResolveEnabled($0) }
                ))
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
    }
    
    // MARK: - 空状态视图
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text("没有冲突")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("所有数据同步正常，没有需要解决的冲突")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
        }
    }
    
    // MARK: - 冲突列表视图
    
    private var conflictListView: some View {
        List {
            ForEach(conflictResolver.pendingConflicts) { conflict in
                ConflictRowView(conflict: conflict) {
                    selectedConflict = conflict
                }
            }
        }
        .listStyle(PlainListStyle())
    }
    
    // MARK: - 设置菜单内容
    
    private var settingsMenuContent: some View {
        Group {
            Menu("默认策略") {
                ForEach(ConflictResolutionStrategy.allCases, id: \.self) { strategy in
                    Button(strategy.description) {
                        conflictResolver.setDefaultStrategy(strategy)
                    }
                }
            }
            
            Divider()
            
            Button("清除已解决记录") {
                conflictResolver.clearResolvedConflicts()
            }
            
            Button("刷新冲突列表") {
                // 这里可以添加刷新逻辑
            }
        }
    }
}

// MARK: - 冲突行视图
struct ConflictRowView: View {
    let conflict: SyncConflict
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // 冲突类型图标
                conflictTypeIcon
                
                // 冲突信息
                VStack(alignment: .leading, spacing: 4) {
                    Text(conflict.recordType)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(conflict.conflictType.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("检测时间: \(formatDate(conflict.detectedAt))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // 严重程度指示器
                severityIndicator
                
                // 箭头
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var conflictTypeIcon: some View {
        Group {
            switch conflict.conflictType {
            case .dataConflict:
                Image(systemName: "doc.text.fill")
                    .foregroundColor(.blue)
            case .deleteConflict:
                Image(systemName: "trash.fill")
                    .foregroundColor(.red)
            case .createConflict:
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(.green)
            case .versionConflict:
                Image(systemName: "clock.fill")
                    .foregroundColor(.orange)
            }
        }
        .font(.title2)
        .frame(width: 40, height: 40)
        .background(Color(.systemGray6))
        .clipShape(Circle())
    }
    
    private var severityIndicator: some View {
        let maxSeverity = conflict.fieldConflicts.map(\.conflictSeverity).max() ?? .low
        
        return Group {
            switch maxSeverity {
            case .low:
                Circle()
                    .fill(Color.green)
                    .frame(width: 12, height: 12)
            case .medium:
                Circle()
                    .fill(Color.orange)
                    .frame(width: 12, height: 12)
            case .high:
                Circle()
                    .fill(Color.red)
                    .frame(width: 12, height: 12)
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - 冲突详情弹窗
struct ConflictDetailSheet: View {
    let conflict: SyncConflict
    let resolver: CloudKitConflictResolver
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedStrategy: ConflictResolutionStrategy
    @State private var isResolving = false
    @State private var showingFieldComparison = false
    
    init(conflict: SyncConflict, resolver: CloudKitConflictResolver) {
        self.conflict = conflict
        self.resolver = resolver
        self._selectedStrategy = State(initialValue: resolver.suggestResolutionStrategy(for: conflict))
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 冲突基本信息
                    conflictInfoSection
                    
                    // 字段冲突详情
                    if !conflict.fieldConflicts.isEmpty {
                        fieldConflictsSection
                    }
                    
                    // 解决策略选择
                    strategySelectionSection
                    
                    // 记录预览
                    recordPreviewSection
                }
                .padding()
            }
            .navigationTitle("冲突详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("解决") {
                        resolveConflict()
                    }
                    .disabled(isResolving)
                }
            }
        }
    }
    
    // MARK: - 冲突信息部分
    
    private var conflictInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("冲突信息")
                .font(.headline)
            
            VStack(spacing: 8) {
                InfoRow(title: "记录类型", value: conflict.recordType)
                InfoRow(title: "冲突类型", value: conflict.conflictType.description)
                InfoRow(title: "记录ID", value: conflict.recordID.recordName)
                InfoRow(title: "检测时间", value: formatDate(conflict.detectedAt))
                InfoRow(title: "字段冲突数", value: "\(conflict.fieldConflicts.count)")
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(8)
        }
    }
    
    // MARK: - 字段冲突部分
    
    private var fieldConflictsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("字段冲突")
                    .font(.headline)
                
                Spacer()
                
                Button("详细对比") {
                    showingFieldComparison = true
                }
                .font(.caption)
            }
            
            LazyVStack(spacing: 8) {
                ForEach(conflict.fieldConflicts, id: \.fieldName) { fieldConflict in
                    FieldConflictRow(fieldConflict: fieldConflict)
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(8)
        }
        .sheet(isPresented: $showingFieldComparison) {
            FieldComparisonSheet(conflict: conflict)
        }
    }
    
    // MARK: - 策略选择部分
    
    private var strategySelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("解决策略")
                .font(.headline)
            
            VStack(spacing: 8) {
                ForEach(ConflictResolutionStrategy.allCases, id: \.self) { strategy in
                    StrategyOptionRow(
                        strategy: strategy,
                        isSelected: selectedStrategy == strategy,
                        isRecommended: strategy == resolver.suggestResolutionStrategy(for: conflict)
                    ) {
                        selectedStrategy = strategy
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(8)
        }
    }
    
    // MARK: - 记录预览部分
    
    private var recordPreviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("记录预览")
                .font(.headline)
            
            HStack(spacing: 12) {
                // 本地记录
                VStack(alignment: .leading, spacing: 8) {
                    Text("本地版本")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if let localRecord = conflict.localRecord {
                        RecordPreviewCard(record: localRecord, title: "本地")
                    } else {
                        Text("无本地记录")
                            .foregroundColor(.secondary)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color(.tertiarySystemBackground))
                            .cornerRadius(8)
                    }
                }
                
                // 服务器记录
                VStack(alignment: .leading, spacing: 8) {
                    Text("服务器版本")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if let serverRecord = conflict.serverRecord {
                        RecordPreviewCard(record: serverRecord, title: "服务器")
                    } else {
                        Text("无服务器记录")
                            .foregroundColor(.secondary)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color(.tertiarySystemBackground))
                            .cornerRadius(8)
                    }
                }
            }
        }
    }
    
    // MARK: - 操作方法
    
    private func resolveConflict() {
        isResolving = true
        
        Task {
            await resolver.resolveConflict(conflict, strategy: selectedStrategy)
            
            await MainActor.run {
                isResolving = false
                dismiss()
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - 批量解决弹窗
struct BatchResolutionSheet: View {
    let conflicts: [SyncConflict]
    let resolver: CloudKitConflictResolver
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedStrategy: ConflictResolutionStrategy = .lastModifiedWins
    @State private var isResolving = false
    @State private var resolutionProgress: Double = 0.0
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // 批量操作信息
                VStack(alignment: .leading, spacing: 12) {
                    Text("批量解决冲突")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("将对 \(conflicts.count) 个冲突应用相同的解决策略")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // 策略选择
                VStack(alignment: .leading, spacing: 12) {
                    Text("选择解决策略")
                        .font(.headline)
                    
                    ForEach(ConflictResolutionStrategy.allCases, id: \.self) { strategy in
                        StrategyOptionRow(
                            strategy: strategy,
                            isSelected: selectedStrategy == strategy,
                            isRecommended: false
                        ) {
                            selectedStrategy = strategy
                        }
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                
                // 进度指示器
                if isResolving {
                    VStack(spacing: 8) {
                        ProgressView(value: resolutionProgress)
                            .progressViewStyle(LinearProgressViewStyle())
                        
                        Text("正在解决冲突... \(Int(resolutionProgress * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // 操作按钮
                HStack(spacing: 12) {
                    Button("取消") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                    
                    Button("开始解决") {
                        resolveBatchConflicts()
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    .disabled(isResolving)
                }
            }
            .padding()
            .navigationTitle("批量解决")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func resolveBatchConflicts() {
        isResolving = true
        resolutionProgress = 0.0
        
        Task {
            let totalConflicts = conflicts.count
            
            for (index, conflict) in conflicts.enumerated() {
                await resolver.resolveConflict(conflict, strategy: selectedStrategy)
                
                await MainActor.run {
                    resolutionProgress = Double(index + 1) / Double(totalConflicts)
                }
            }
            
            await MainActor.run {
                isResolving = false
                dismiss()
            }
        }
    }
}

// MARK: - 辅助视图组件

// InfoRow moved to shared components to avoid conflicts

struct FieldConflictRow: View {
    let fieldConflict: FieldConflict
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(fieldConflict.fieldName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(fieldConflict.conflictSeverity.description)
                    .font(.caption)
                    .foregroundColor(severityColor)
            }
            
            Spacer()
            
            Circle()
                .fill(severityColor)
                .frame(width: 8, height: 8)
        }
        .padding(.vertical, 4)
    }
    
    private var severityColor: Color {
        switch fieldConflict.conflictSeverity {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        }
    }
}

struct StrategyOptionRow: View {
    let strategy: ConflictResolutionStrategy
    let isSelected: Bool
    let isRecommended: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .secondary)
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(strategy.description)
                            .fontWeight(.medium)
                        
                        if isRecommended {
                            Text("推荐")
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(4)
                        }
                    }
                    
                    Text(strategyDescription(strategy))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func strategyDescription(_ strategy: ConflictResolutionStrategy) -> String {
        switch strategy {
        case .clientWins:
            return "始终使用本地版本"
        case .serverWins:
            return "始终使用服务器版本"
        case .lastModifiedWins:
            return "使用最后修改的版本"
        case .merge:
            return "智能合并两个版本"
        case .manual:
            return "手动选择解决方案"
        case .fieldByField:
            return "逐字段智能解决"
        }
    }
}

struct RecordPreviewCard: View {
    let record: CKRecord
    let title: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 4) {
                if let modificationDate = record.modificationDate {
                    Text("修改时间: \(formatDate(modificationDate))")
                        .font(.caption)
                }
                
                Text("字段数: \(record.allKeys().count)")
                    .font(.caption)
                
                if let changeTag = record.recordChangeTag {
                    Text("版本: \(changeTag)")
                        .font(.caption)
                }
            }
            .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(8)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct FieldComparisonSheet: View {
    let conflict: SyncConflict
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(conflict.fieldConflicts, id: \.fieldName) { fieldConflict in
                    FieldComparisonRow(fieldConflict: fieldConflict)
                }
            }
            .navigationTitle("字段对比")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct FieldComparisonRow: View {
    let fieldConflict: FieldConflict
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(fieldConflict.fieldName)
                .font(.headline)
            
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("本地值")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                    
                    Text(formatValue(fieldConflict.localValue))
                        .font(.body)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(6)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("服务器值")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                    
                    Text(formatValue(fieldConflict.serverValue))
                        .font(.body)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(6)
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    private func formatValue(_ value: Any?) -> String {
        guard let value = value else { return "无值" }
        
        if let string = value as? String {
            return string.isEmpty ? "空字符串" : string
        } else if let date = value as? Date {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return formatter.string(from: date)
        } else {
            return String(describing: value)
        }
    }
}

// MARK: - 策略枚举扩展
extension ConflictResolutionStrategy: CaseIterable {
    public static var allCases: [ConflictResolutionStrategy] {
        return [.clientWins, .serverWins, .lastModifiedWins, .merge, .fieldByField, .manual]
    }
}

#Preview {
    ConflictResolutionView()
}