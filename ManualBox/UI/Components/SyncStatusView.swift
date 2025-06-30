//
//  SyncStatusView.swift
//  ManualBox
//
//  Created by Assistant on 2025/6/24.
//

import SwiftUI

// MARK: - 同步状态显示组件
struct SyncStatusView: View {
    @ObservedObject var syncService: CloudKitSyncService
    @State private var showingDetails = false
    @State private var showingConflictResolution = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 16) {
            // 状态头部
            statusHeader
            
            // 进度部分（仅在同步时显示）
            if syncService.syncStatus == .syncing {
                progressSection
            }
            
            if let details = syncService.syncDetails {
                detailsSection(details)
            }
            
            // 冲突部分（如果有冲突）
            if syncService.conflictCount > 0 {
                conflictSection
            }
            
            // 操作按钮
            actionButtons
            
            Spacer()
        }
        .padding()
        .background(ModernColors.Background.primary)
        .cornerRadius(12)
        .shadow(radius: 2)
        .sheet(isPresented: $showingDetails) {
            syncDetailsView
        }
        .sheet(isPresented: $showingConflictResolution) {
            conflictResolutionView
        }
        #if os(macOS)
        .platformNavigationBarTitleDisplayMode(0)
        .platformToolbar(trailing: {
            Button("关闭") {
                dismiss()
            }
        })
        #else
        .platformNavigationBarTitleDisplayMode(.inline)
        .toolbar(content: {
            SwiftUI.ToolbarItem(placement: .navigationBarTrailing) {
                Button("关闭") {
                    dismiss()
                }
            }
        })
        #endif
    }
    
    // MARK: - 状态头部
    private var statusHeader: some View {
        HStack {
            statusIcon
            
            VStack(alignment: .leading, spacing: 4) {
                Text(statusTitle)
                    .font(.headline)
                    .foregroundColor(statusColor)
                
                if let subtitle = statusSubtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if let lastSync = syncService.lastSyncDate {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("上次同步")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text(formatSyncTime(lastSync))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - 进度部分
    private var progressSection: some View {
        VStack(spacing: 8) {
            ProgressView(value: syncService.syncProgress)
                .progressViewStyle(LinearProgressViewStyle())
            
            HStack {
                Text("进度: \(Int(syncService.syncProgress * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if let details = syncService.syncDetails {
                    Text("\(details.processedRecords)/\(details.totalRecords)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - 详情部分
    private func detailsSection(_ details: SyncDetails) -> some View {
        VStack(spacing: 8) {
            HStack {
                Label(details.syncType == .full ? "完整同步" : "增量同步", 
                      systemImage: details.syncType == .full ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                    .font(.caption)
                    .foregroundColor(.blue)
                
                Spacer()
                
                Text(details.phase.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if details.totalRecords > 0 {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("总记录")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("\(details.totalRecords)")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .center, spacing: 2) {
                        Text("已处理")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("\(details.processedRecords)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.green)
                    }
                    
                    Spacer()
                    
                    if details.failedRecords > 0 {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("失败")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("\(details.failedRecords)")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            
            if let duration = details.duration {
                HStack {
                    Text("耗时: \(formatDuration(duration))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
            }
        }
    }
    
    // MARK: - 冲突部分
    private var conflictSection: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                
                Text("发现 \(syncService.conflictCount) 个数据冲突")
                    .font(.subheadline)
                    .foregroundColor(.orange)
                
                Spacer()
                
                Button("解决") {
                    showingConflictResolution = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
            Text("数据冲突需要手动解决以确保数据一致性")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
    }
    
    // MARK: - 操作按钮
    private var actionButtons: some View {
        HStack {
            if syncService.syncStatus == .syncing {
                Button("取消同步") {
                    // 实现取消同步逻辑
                }
                .buttonStyle(.bordered)
                .foregroundColor(.red)
            } else {
                Button("立即同步") {
                    Task {
                        do {
                            try await syncService.syncFromCloud()
                        } catch {
                            print("同步失败: \(error)")
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(syncService.syncStatus == .syncing)
            }
            
            Spacer()
            
            Button("详情") {
                showingDetails = true
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }
    
    // MARK: - 计算属性
    
    private var statusIcon: some View {
        Group {
            switch syncService.syncStatus {
            case .idle:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case .syncing:
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundColor(.blue)
                    .rotationEffect(.degrees(syncService.syncProgress * 360))
                    .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: syncService.syncProgress)
            case .paused:
                Image(systemName: "pause.circle.fill")
                    .foregroundColor(.orange)
            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case .failed:
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(.red)
            }
        }
        .font(.title2)
    }
    
    private var statusTitle: String {
        switch syncService.syncStatus {
        case .idle:
            return "同步就绪"
        case .syncing:
            return "正在同步..."
        case .paused:
            return "同步已暂停"
        case .completed:
            return "同步完成"
        case .failed:
            return "同步失败"
        }
    }
    
    private var statusSubtitle: String? {
        switch syncService.syncStatus {
        case .syncing:
            return syncService.syncDetails?.phase.description
        case .failed(let error):
            return error
        default:
            return nil
        }
    }
    
    private var statusColor: Color {
        switch syncService.syncStatus {
        case .idle, .completed:
            return .green
        case .syncing:
            return .blue
        case .paused:
            return .orange
        case .failed:
            return .red
        }
    }
    
    // MARK: - 详情视图
    private var syncDetailsView: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let details = syncService.syncDetails {
                        syncDetailsContent(details)
                    } else {
                        Text("暂无同步详情")
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
            }
            .navigationTitle("同步详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(content: {
                SwiftUI.ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        showingDetails = false
                    }
                }
            })
        }
    }
    
    private func syncDetailsContent(_ details: SyncDetails) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("同步信息")
                .font(.headline)
            
            DetailRow(title: "同步类型", value: details.syncType == .full ? "完整同步" : "增量同步")
            DetailRow(title: "当前阶段", value: details.phase.description)
            DetailRow(title: "开始时间", value: formatFullTime(details.startTime))
            
            if let endTime = details.endTime {
                DetailRow(title: "结束时间", value: formatFullTime(endTime))
                DetailRow(title: "总耗时", value: formatDuration(endTime.timeIntervalSince(details.startTime)))
            }
            
            Divider()
            
            Text("处理统计")
                .font(.headline)
            
            DetailRow(title: "总记录数", value: "\(details.totalRecords)")
            DetailRow(title: "已处理", value: "\(details.processedRecords)")
            DetailRow(title: "失败记录", value: "\(details.failedRecords)")
            DetailRow(title: "冲突记录", value: "\(details.conflictedRecords)")
            
            if details.totalRecords > 0 {
                DetailRow(title: "成功率", value: String(format: "%.1f%%", Double(details.processedRecords - details.failedRecords) / Double(details.totalRecords) * 100))
            }
        }
    }
    
    // MARK: - 冲突解决视图
    private var conflictResolutionView: some View {
        NavigationView {
            Text("冲突解决界面")
                .navigationTitle("解决冲突")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar(content: {
                    SwiftUI.ToolbarItem(placement: .navigationBarTrailing) {
                        Button("完成") {
                            showingConflictResolution = false
                        }
                    }
                })
        }
    }
    
    // MARK: - 辅助方法
    
    private func formatSyncTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    private func formatFullTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        
        if minutes > 0 {
            return "\(minutes)分\(seconds)秒"
        } else {
            return "\(seconds)秒"
        }
    }
}

// MARK: - 详情行组件
struct DetailRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .font(.subheadline)
    }
}

// MARK: - 同步阶段扩展
extension SyncDetails.SyncPhase {
    var description: String {
        switch self {
        case .preparing:
            return "准备中"
        case .uploading:
            return "上传中"
        case .downloading:
            return "下载中"
        case .processing:
            return "处理中"
        case .resolving:
            return "解决冲突"
        case .completed:
            return "已完成"
        case .failed:
            return "失败"
        }
    }
}

// MARK: - 预览
struct SyncStatusView_Previews: PreviewProvider {
    static var previews: some View {
        // 这里需要创建一个模拟的CloudKitSyncService实例
        Text("SyncStatusView Preview")
    }
}
