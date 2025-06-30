import SwiftUI

// MARK: - 同步设置视图
struct SyncSettingsView: View {
    @StateObject private var syncService = CloudKitSyncService.shared
    @Environment(\.dismiss) private var dismiss
    @AppStorage("enableAutoSync") private var enableAutoSync = true
    @AppStorage("syncInterval") private var syncInterval = 300.0 // 5分钟
    @AppStorage("enableBackgroundSync") private var enableBackgroundSync = true
    @AppStorage("conflictResolutionStrategy") private var conflictResolutionStrategy = "useLatest"
    
    var body: some View {
        NavigationView {
            Form {
                // 基本同步设置
                Section {
                    Toggle("启用自动同步", isOn: $enableAutoSync)
                        .onChange(of: enableAutoSync) { _, newValue in
                            // 更新同步服务配置
                            updateSyncConfiguration()
                        }
                    
                    if enableAutoSync {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("同步间隔")
                                Spacer()
                                Text(formatInterval(syncInterval))
                                    .foregroundColor(.secondary)
                            }
                            
                            Slider(value: $syncInterval, in: 60...3600, step: 60) {
                                Text("同步间隔")
                            }
                            .onChange(of: syncInterval) { _, _ in
                                updateSyncConfiguration()
                            }
                        }
                    }
                    
                    Toggle("启用后台同步", isOn: $enableBackgroundSync)
                        .onChange(of: enableBackgroundSync) { _, _ in
                            updateSyncConfiguration()
                        }
                } header: {
                    Text("自动同步")
                } footer: {
                    Text("启用自动同步后，应用会定期将数据同步到iCloud")
                }
                
                // 冲突解决策略
                Section {
                    Picker("冲突解决策略", selection: $conflictResolutionStrategy) {
                        Text("使用最新版本").tag("useLatest")
                        Text("使用本地版本").tag("useLocal")
                        Text("使用云端版本").tag("useRemote")
                        Text("手动解决").tag("manual")
                    }
                    .pickerStyle(.menu)
                    .onChange(of: conflictResolutionStrategy) { _, _ in
                        updateSyncConfiguration()
                    }
                } header: {
                    Text("冲突解决")
                } footer: {
                    Text("当本地和云端数据发生冲突时的处理方式")
                }
                
                // 网络设置
                Section {
                    HStack {
                        Text("仅在WiFi下同步")
                        Spacer()
                        Toggle("", isOn: .constant(false))
                            .disabled(true)
                    }
                    
                    HStack {
                        Text("低电量模式下暂停同步")
                        Spacer()
                        Toggle("", isOn: .constant(true))
                            .disabled(true)
                    }
                } header: {
                    Text("网络与电源")
                } footer: {
                    Text("这些设置将在未来版本中提供")
                }
                
                // 同步状态信息
                Section {
                    HStack {
                        Text("当前状态")
                        Spacer()
                        Text(syncStatusText)
                            .foregroundColor(syncStatusColor)
                    }
                    
                    if let lastSync = syncService.lastSyncDate {
                        HStack {
                            Text("最后同步")
                            Spacer()
                            Text(formatDate(lastSync))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    HStack {
                        Text("待上传记录")
                        Spacer()
                        Text("\(syncService.pendingUploads)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("待下载记录")
                        Spacer()
                        Text("\(syncService.pendingDownloads)")
                            .foregroundColor(.secondary)
                    }
                    
                    if syncService.conflictCount > 0 {
                        HStack {
                            Text("冲突数量")
                            Spacer()
                            Text("\(syncService.conflictCount)")
                                .foregroundColor(.red)
                        }
                    }
                } header: {
                    Text("同步状态")
                }
                
                // 高级操作
                Section {
                    Button("立即同步") {
                        performManualSync()
                    }
                    .disabled(syncService.syncStatus == .syncing)
                    
                    Button("重置同步状态") {
                        resetSyncState()
                    }
                    .foregroundColor(.orange)
                    
                    Button("清除同步缓存") {
                        clearSyncCache()
                    }
                    .foregroundColor(.red)
                } header: {
                    Text("高级操作")
                } footer: {
                    Text("重置同步状态将清除所有同步令牌，下次同步将执行完整同步")
                }
            }
            .navigationTitle("同步设置")
            #if os(macOS)
            .platformNavigationBarTitleDisplayMode(0)
            #else
            .platformNavigationBarTitleDisplayMode(.inline)
            #endif
            .platformToolbar(trailing: {
                Button("完成") {
                    dismiss()
                }
            })
        }
    }
    
    // MARK: - 辅助方法
    
    private var syncStatusText: String {
        switch syncService.syncStatus {
        case .idle: return "空闲"
        case .syncing: return "同步中"
        case .paused: return "已暂停"
        case .completed: return "已完成"
        case .failed: return "失败"
        }
    }
    
    private var syncStatusColor: Color {
        switch syncService.syncStatus {
        case .idle: return .gray
        case .syncing: return .blue
        case .paused: return .orange
        case .completed: return .green
        case .failed: return .red
        }
    }
    
    private func formatInterval(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        if minutes < 60 {
            return "\(minutes)分钟"
        } else {
            let hours = minutes / 60
            return "\(hours)小时"
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    private func updateSyncConfiguration() {
        // 更新同步服务配置
        print("更新同步配置")
    }
    
    private func performManualSync() {
        Task {
            do {
                try await syncService.syncFromCloud()
            } catch {
                print("手动同步失败: \(error)")
            }
        }
    }
    
    private func resetSyncState() {
        // 重置同步状态
        print("重置同步状态")
    }
    
    private func clearSyncCache() {
        // 清除同步缓存
        print("清除同步缓存")
    }
}

#Preview {
    SyncSettingsView()
}
