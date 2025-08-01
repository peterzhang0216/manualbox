//
//  SyncProgressView.swift
//  ManualBox
//
//  Created by Assistant on 2024/12/19.
//  详细的同步进度显示界面
//

import SwiftUI

struct SyncProgressView: View {
    @StateObject private var syncCoordinator = EnhancedSyncCoordinator()
    @StateObject private var statusMonitor: SyncStatusMonitor
    @State private var showingDetails = false
    @State private var showingHistory = false
    
    init() {
        let coordinator = EnhancedSyncCoordinator()
        self._syncCoordinator = StateObject(wrappedValue: coordinator)
        self._statusMonitor = StateObject(wrappedValue: SyncStatusMonitor(syncCoordinator: coordinator))
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // 主要同步状态卡片
            syncStatusCard
            
            // 详细进度信息
            if syncCoordinator.syncStatus == .syncing {
                detailedProgressSection
            }
            
            // 控制按钮
            controlButtonsSection
            
            // 同步历史和详情
            additionalInfoSection
            
            Spacer()
        }
        .padding()
        .navigationTitle("同步状态")
        .onAppear {
            statusMonitor.startMonitoring()
        }
        .onDisappear {
            statusMonitor.stopMonitoring()
        }
        .sheet(isPresented: $showingDetails) {
            SyncDetailsSheet(statusMonitor: statusMonitor)
        }
        .sheet(isPresented: $showingHistory) {
            SyncHistorySheet(statusMonitor: statusMonitor)
        }
    }
    
    // MARK: - 同步状态卡片
    
    private var syncStatusCard: some View {
        VStack(spacing: 16) {
            // 状态图标和标题
            HStack {
                statusIcon
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(statusTitle)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(statusSubtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if syncCoordinator.syncStatus == .syncing {
                    Button("暂停") {
                        syncCoordinator.pauseSync()
                    }
                    .buttonStyle(.bordered)
                }
            }
            
            // 进度条
            if syncCoordinator.syncStatus == .syncing {
                VStack(alignment: .leading, spacing: 8) {
                    ProgressView(value: syncCoordinator.syncProgress)
                        .progressViewStyle(LinearProgressViewStyle())
                    
                    HStack {
                        Text("\(Int(syncCoordinator.syncProgress * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        if let timeRemaining = syncCoordinator.estimatedTimeRemaining {
                            Text("剩余 \(formatTimeInterval(timeRemaining))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - 详细进度部分
    
    private var detailedProgressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("同步详情")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(spacing: 8) {
                // 当前阶段
                HStack {
                    Text("当前阶段:")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(syncCoordinator.currentPhase.description)
                        .fontWeight(.medium)
                }
                
                // 网络状态
                HStack {
                    Text("网络状态:")
                        .foregroundColor(.secondary)
                    Spacer()
                    HStack(spacing: 4) {
                        Circle()
                            .fill(networkStatusColor)
                            .frame(width: 8, height: 8)
                        Text(statusMonitor.networkStatus.description)
                            .fontWeight(.medium)
                    }
                }
                
                // 吞吐量信息
                if let metrics = syncCoordinator.throughputMetrics {
                    HStack {
                        Text("处理速度:")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(String(format: "%.1f", metrics.recordsPerSecond)) 记录/秒")
                            .fontWeight(.medium)
                    }
                }
                
                // 详细进度
                if let detailedProgress = statusMonitor.detailedProgress {
                    HStack {
                        Text("当前操作:")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(detailedProgress.currentOperation)
                            .fontWeight(.medium)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(8)
        }
    }
    
    // MARK: - 控制按钮部分
    
    private var controlButtonsSection: some View {
        VStack(spacing: 12) {
            // 主要操作按钮
            HStack(spacing: 12) {
                Button(action: startSync) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("开始同步")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(syncCoordinator.syncStatus == .syncing)
                
                Button(action: resolveConflicts) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                        Text("解决冲突")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(syncCoordinator.syncStatus == .syncing)
            }
            
            // 次要操作按钮
            HStack(spacing: 12) {
                Button("查看详情") {
                    showingDetails = true
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
                
                Button("同步历史") {
                    showingHistory = true
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
            }
        }
    }
    
    // MARK: - 附加信息部分
    
    private var additionalInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("同步信息")
                .font(.headline)
            
            VStack(spacing: 8) {
                if let lastSync = syncCoordinator.lastSyncDate {
                    HStack {
                        Text("上次同步:")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(formatDate(lastSync))
                            .fontWeight(.medium)
                    }
                }
                
                HStack {
                    Text("待上传:")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(syncCoordinator.pendingUploads)")
                        .fontWeight(.medium)
                }
                
                HStack {
                    Text("待下载:")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(syncCoordinator.pendingDownloads)")
                        .fontWeight(.medium)
                }
                
                if syncCoordinator.conflictCount > 0 {
                    HStack {
                        Text("冲突数量:")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(syncCoordinator.conflictCount)")
                            .fontWeight(.medium)
                            .foregroundColor(.orange)
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(8)
        }
    }
    
    // MARK: - 计算属性
    
    private var statusIcon: some View {
        Group {
            switch syncCoordinator.syncStatus {
            case .idle:
                Image(systemName: "cloud")
                    .foregroundColor(.gray)
            case .syncing:
                Image(systemName: "arrow.clockwise")
                    .foregroundColor(.blue)
                    .rotationEffect(.degrees(syncCoordinator.syncProgress * 360))
                    .animation(.linear(duration: 2).repeatForever(autoreverses: false), value: syncCoordinator.syncProgress)
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
        switch syncCoordinator.syncStatus {
        case .idle:
            return "空闲"
        case .syncing:
            return "同步中"
        case .completed:
            return "同步完成"
        case .failed:
            return "同步失败"
        }
    }
    
    private var statusSubtitle: String {
        switch syncCoordinator.syncStatus {
        case .idle:
            return "点击开始同步按钮开始同步"
        case .syncing:
            return syncCoordinator.currentPhase.description
        case .completed:
            if let lastSync = syncCoordinator.lastSyncDate {
                return "完成于 \(formatTime(lastSync))"
            } else {
                return "同步已完成"
            }
        case .failed(let error):
            return error.localizedDescription
        }
    }
    
    private var networkStatusColor: Color {
        switch statusMonitor.networkStatus {
        case .connected:
            return .green
        case .limited:
            return .orange
        case .disconnected:
            return .red
        case .unknown:
            return .gray
        }
    }
    
    // MARK: - 操作方法
    
    private func startSync() {
        Task {
            _ = await syncCoordinator.startSync()
        }
    }
    
    private func resolveConflicts() {
        Task {
            let conflicts = syncCoordinator.pendingConflictsPublic
            _ = await syncCoordinator.resolveConflicts(conflicts)
        }
    }
    
    // MARK: - 辅助方法
    
    private func formatTimeInterval(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        
        if minutes > 0 {
            return "\(minutes)分\(seconds)秒"
        } else {
            return "\(seconds)秒"
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - 同步详情弹窗
struct SyncDetailsSheet: View {
    @ObservedObject var statusMonitor: SyncStatusMonitor
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 详细状态信息
                    detailedStatusSection
                    
                    // 性能指标
                    performanceMetricsSection
                    
                    // 网络信息
                    networkInfoSection
                }
                .padding()
            }
            .navigationTitle("同步详情")
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
    
    private var detailedStatusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("状态详情")
                .font(.headline)
            
            let detailedStatus = statusMonitor.getDetailedStatus()
            
            VStack(spacing: 8) {
                DetailRow(title: "当前状态", value: "\(detailedStatus.status)")
                DetailRow(title: "进度", value: "\(Int(detailedStatus.progress * 100))%")
                DetailRow(title: "阶段", value: detailedStatus.phase.description)
                DetailRow(title: "最后更新", value: formatDate(detailedStatus.lastUpdateTime))
                
                if let timeRemaining = detailedStatus.estimatedTimeRemaining {
                    DetailRow(title: "预计剩余时间", value: formatTimeInterval(timeRemaining))
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(8)
        }
    }
    
    private var performanceMetricsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("性能指标")
                .font(.headline)
            
            if let metrics = statusMonitor.throughputMetrics {
                VStack(spacing: 8) {
                    DetailRow(title: "处理速度", value: "\(String(format: "%.2f", metrics.recordsPerSecond)) 记录/秒")
                    DetailRow(title: "平均延迟", value: "\(String(format: "%.2f", metrics.averageLatency))秒")
                    
                    if let detailedProgress = statusMonitor.detailedProgress {
                        DetailRow(title: "已处理记录", value: "\(detailedProgress.recordsProcessed)")
                        DetailRow(title: "总记录数", value: "\(detailedProgress.totalRecords)")
                        DetailRow(title: "当前操作", value: detailedProgress.currentOperation)
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)
            } else {
                Text("暂无性能数据")
                    .foregroundColor(.secondary)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
            }
        }
    }
    
    private var networkInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("网络信息")
                .font(.headline)
            
            VStack(spacing: 8) {
                DetailRow(title: "网络状态", value: statusMonitor.networkStatus.description)
                // 这里可以添加更多网络相关信息
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(8)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
    
    private func formatTimeInterval(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        
        if minutes > 0 {
            return "\(minutes)分\(seconds)秒"
        } else {
            return "\(seconds)秒"
        }
    }
}

// MARK: - 同步历史弹窗
struct SyncHistorySheet: View {
    @ObservedObject var statusMonitor: SyncStatusMonitor
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(statusMonitor.syncHistory.reversed(), id: \.id) { entry in
                    SyncHistoryRow(entry: entry)
                }
            }
            .navigationTitle("同步历史")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("导出") {
                        exportHistory()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func exportHistory() {
        if let data = statusMonitor.exportSyncHistory() {
            // 这里可以实现导出功能
            print("导出同步历史数据: \(data.count) bytes")
        }
    }
}

// MARK: - 辅助视图组件

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
    }
}

// 注意：SyncHistoryRow 已移动到 SharedUIComponents.swift 以避免重复定义

#Preview {
    SyncProgressView()
}