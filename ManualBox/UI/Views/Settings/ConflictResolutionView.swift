import SwiftUI
import Foundation
import CloudKit

// MARK: - 本地类型定义
enum LocalConflictResolutionStrategy {
    case serverWins
    case clientWins
    case lastModifiedWins
    case merge
    case manual
}

// 本地SyncConflict定义
struct LocalSyncConflict: Identifiable {
    let id = UUID()
    let recordID: String
    let entityType: String
    let localRecord: [String: Any]?
    let serverRecord: [String: Any]
    let conflictType: ConflictType
    let timestamp: Date
    let description: String
    
    enum ConflictType {
        case dataConflict
        case deleteConflict
        case insertConflict
        case typeConflict
        case versionConflict
    }
}

// MARK: - 冲突解决视图
struct ConflictResolutionView: View {
    // @StateObject private var syncService = CloudKitSyncService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedConflict: LocalSyncConflict?
    @State private var showingConflictDetail = false
    @State private var resolutionStrategy: LocalConflictResolutionStrategy = .lastModifiedWins
    @State private var isResolving = false
    
    private var conflicts: [LocalSyncConflict] {
        // 返回空数组，因为我们使用的是本地类型
        []
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if conflicts.isEmpty {
                    ContentUnavailableView(
                        "无冲突",
                        systemImage: "checkmark.circle",
                        description: Text("当前没有需要解决的同步冲突")
                    )
                } else {
                    List {
                        ForEach(conflicts) { conflict in
                            ConflictRow(
                                conflict: conflict,
                                onTap: {
                                    selectedConflict = conflict
                                    showingConflictDetail = true
                                },
                                onResolve: { strategy in
                                    resolveConflict(conflict, with: strategy)
                                }
                            )
                        }
                    }
                }
            }
            .navigationTitle("冲突解决")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button("全部解决") {
                        resolveAllConflicts()
                    }
                    .disabled(conflicts.isEmpty || isResolving)
                }
            }
        }
        .sheet(isPresented: $showingConflictDetail) {
            if let conflict = selectedConflict {
                ConflictDetailView(
                    conflict: conflict,
                    onResolve: { strategy in
                        resolveConflict(conflict, with: strategy)
                        showingConflictDetail = false
                    }
                )
            }
        }
    }
    
    // MARK: - 操作方法
    
    private func resolveConflict(_ conflict: LocalSyncConflict, with strategy: LocalConflictResolutionStrategy) {
        isResolving = true
        
        // 模拟异步操作
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isResolving = false
        }
    }
    
    private func resolveAllConflicts() {
        for conflict in conflicts {
            resolveConflict(conflict, with: resolutionStrategy)
        }
    }
}

// MARK: - 冲突行组件
struct ConflictRow: View {
    let conflict: LocalSyncConflict
    let onTap: () -> Void
    let onResolve: (LocalConflictResolutionStrategy) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: conflictTypeIcon)
                    .foregroundColor(.orange)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(conflict.entityType)
                        .font(.headline)
                        .fontWeight(.medium)
                    
                    Text(conflict.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                Button("查看详情") {
                    onTap()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
            HStack(spacing: 12) {
                Button("使用本地") {
                    onResolve(.clientWins)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Button("使用云端") {
                    onResolve(.serverWins)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Button("使用最新") {
                    onResolve(.lastModifiedWins)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var conflictTypeIcon: String {
        switch conflict.conflictType {
        case .dataConflict:
            return "exclamationmark.triangle"
        case .deleteConflict:
            return "trash.circle"
        case .insertConflict:
            return "plus.circle"
        case .typeConflict:
            return "questionmark.circle"
        case .versionConflict:
            return "clock.arrow.circlepath"
        }
    }
}

// MARK: - 冲突详情视图
struct ConflictDetailView: View {
    let conflict: LocalSyncConflict
    let onResolve: (LocalConflictResolutionStrategy) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 冲突基本信息
                    conflictInfoSection
                    
                    // 本地版本
                    if let localRecord = conflict.localRecord {
                        dataVersionSection(
                            title: "本地版本",
                            data: localRecord,
                            icon: "iphone",
                            color: .blue
                        )
                    }
                    
                    // 远程版本
                    dataVersionSection(
                        title: "云端版本",
                        data: conflict.serverRecord,
                        icon: "icloud",
                        color: .green
                    )
                    
                    // 解决方案
                    resolutionSection
                }
                .padding()
            }
            .navigationTitle("冲突详情")

            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var resolutionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("解决方案")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                ResolutionButton(
                    title: "使用本地版本",
                    description: "保留本地数据，丢弃云端修改",
                    icon: "iphone.fill",
                    color: .blue
                ) {
                    onResolve(.clientWins)
                    dismiss()
                }
                
                ResolutionButton(
                    title: "使用云端版本",
                    description: "保留云端数据，丢弃本地修改",
                    icon: "icloud.fill",
                    color: .green
                ) {
                    onResolve(.serverWins)
                    dismiss()
                }
                
                ResolutionButton(
                    title: "使用最新修改",
                    description: "根据修改时间自动选择最新版本",
                    icon: "clock.fill",
                    color: .orange
                ) {
                    onResolve(.lastModifiedWins)
                    dismiss()
                }
            }
        }
    }
    
    private var conflictInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("冲突信息")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                InfoRow(label: "实体类型", value: conflict.entityType)
                InfoRow(label: "冲突类型", value: conflict.conflictType.description)
                InfoRow(label: "发生时间", value: formatDate(conflict.timestamp))
                InfoRow(label: "描述", value: conflict.description)
            }
        }
    }
    
    private func dataVersionSection(title: String, data: [String: Any], icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            VStack(spacing: 8) {
                ForEach(data.keys.sorted(), id: \.self) { key in
                    InfoRow(label: key, value: "\(data[key] ?? "N/A")")
                }
            }
        }
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - InfoRow 组件
struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.body)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            
            Text(value)
                .font(.body)
                .foregroundColor(.primary)
            
            Spacer()
        }
    }
}

// MARK: - ResolutionButton 组件
struct ResolutionButton: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(color.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 冲突类型扩展
extension LocalSyncConflict.ConflictType {
    var description: String {
        switch self {
        case .dataConflict:
            return "数据冲突"
        case .deleteConflict:
            return "删除冲突"
        case .insertConflict:
            return "插入冲突"
        case .typeConflict:
            return "类型冲突"
        case .versionConflict:
            return "版本冲突"
        }
    }
}

#Preview {
    ConflictResolutionView()
}