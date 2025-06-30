import SwiftUI
import CloudKit

// MARK: - 同步状态仪表板
struct SyncDashboardView: View {
    @StateObject private var syncService = CloudKitSyncService.shared
    @StateObject private var appStateManager = AppStateManager.shared
    @State private var showingConflictResolution = false
    @State private var showingSyncHistory = false
    @State private var showingSyncSettings = false
    @State private var refreshTimer: Timer?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 同步状态概览
                    syncStatusOverview
                    
                    // 同步进度详情
                    if syncService.syncStatus == .syncing {
                        syncProgressDetails
                    }
                    
                    // 同步统计
                    syncStatistics
                    
                    // 冲突管理
                    if syncService.conflictCount > 0 {
                        conflictManagement
                    }
                    
                    // 网络状态
                    networkStatus
                    
                    // 快速操作
                    quickActions
                }
                .padding()
            }
            .navigationTitle("数据同步")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            #if os(iOS)
            .toolbar {
                ToolbarItem(icon: "ellipsis.circle") {
                    Menu {
                        Button(action: { showingSyncHistory = true }) {
                            Label("同步历史", systemImage: "clock.arrow.circlepath")
                        }
                        Button(action: { showingSyncSettings = true }) {
                            Label("同步设置", systemImage: "gear")
                        }
                        Divider()
                        Button("刷新") { refreshSyncStatus() }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            #else
            .toolbar {
                ToolbarItem(icon: "ellipsis.circle") {
                    Menu {
                        Button(action: { showingSyncHistory = true }) {
                            Label("同步历史", systemImage: "clock.arrow.circlepath")
                        }
                        Button(action: { showingSyncSettings = true }) {
                            Label("同步设置", systemImage: "gear")
                        }
                        Divider()
                        Button("刷新") { refreshSyncStatus() }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            #endif
        }
        .sheet(isPresented: $showingConflictResolution) {
            ConflictResolutionView()
        }
        .sheet(isPresented: $showingSyncHistory) {
            SyncHistoryView()
        }
        .sheet(isPresented: $showingSyncSettings) {
            SyncSettingsView()
        }
        .onAppear {
            startRefreshTimer()
        }
        .onDisappear {
            stopRefreshTimer()
        }
    }
    
    // MARK: - 同步状态概览
    private var syncStatusOverview: some View {
        VStack(spacing: 16) {
            HStack {
                Text("同步状态")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                syncStatusBadge
            }
            
            HStack(spacing: 20) {
                // 状态图标和描述
                VStack(spacing: 8) {
                    syncStatusIcon
                        .font(.system(size: 48))
                    
                    Text(syncStatusDescription)
                        .font(.body)
                        .fontWeight(.medium)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                
                Divider()
                    .frame(height: 80)
                
                // 最后同步时间
                VStack(spacing: 8) {
                    Image(systemName: "clock")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    
                    Text("最后同步")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(lastSyncText)
                        .font(.body)
                        .fontWeight(.medium)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(Color(ModernColors.System.gray6))
        .cornerRadius(12)
    }
    
    // MARK: - 同步进度详情
    private var syncProgressDetails: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("同步进度")
                .font(.headline)
                .fontWeight(.semibold)
            
            // 总体进度
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("总体进度")
                        .font(.body)
                    
                    Spacer()
                    
                    Text("\(Int(syncService.syncProgress * 100))%")
                        .font(.body)
                        .fontWeight(.medium)
                }
                
                ProgressView(value: syncService.syncProgress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
            }
            
            // 详细进度信息
            if let details = syncService.syncDetails {
                syncDetailsSection(details)
            }
        }
        .padding()
        .background(Color(ModernColors.Background.primary))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - 同步统计
    private var syncStatistics: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("同步统计")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                SyncStatCard(
                    title: "待上传",
                    value: "\(syncService.pendingUploads)",
                    icon: "arrow.up.circle",
                    color: .blue
                )

                SyncStatCard(
                    title: "待下载",
                    value: "\(syncService.pendingDownloads)",
                    icon: "arrow.down.circle",
                    color: .green
                )

                SyncStatCard(
                    title: "冲突数量",
                    value: "\(syncService.conflictCount)",
                    icon: "exclamationmark.triangle",
                    color: syncService.conflictCount > 0 ? .red : .gray
                )

                SyncStatCard(
                    title: "失败记录",
                    value: "\(syncService.failedRecords)",
                    icon: "xmark.circle",
                    color: syncService.failedRecords > 0 ? .orange : .gray
                )
            }
        }
        .padding()
        .background(Color(ModernColors.Background.primary))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - 冲突管理
    private var conflictManagement: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                
                Text("发现数据冲突")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            Text("检测到 \(syncService.conflictCount) 个数据冲突需要解决")
                .font(.body)
                .foregroundColor(.secondary)
            
            Button(action: {
                showingConflictResolution = true
            }) {
                HStack {
                    Image(systemName: "wrench.and.screwdriver")
                    Text("解决冲突")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.red.opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - 网络状态
    private var networkStatus: some View {
        HStack {
            Image(systemName: appStateManager.state.hasNetworkConnection ? "wifi" : "wifi.slash")
                .foregroundColor(appStateManager.state.hasNetworkConnection ? .green : .red)
            
            Text(appStateManager.state.hasNetworkConnection ? "网络连接正常" : "网络连接异常")
                .font(.body)
            
            Spacer()
            
            if !appStateManager.state.hasNetworkConnection {
                Text("离线模式")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange)
                    .cornerRadius(4)
            }
        }
        .padding()
        .background(Color(ModernColors.System.gray6))
        .cornerRadius(8)
    }
    
    // MARK: - 快速操作
    private var quickActions: some View {
        VStack(spacing: 12) {
            Text("快速操作")
                .font(.headline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 12) {
                Button(action: performManualSync) {
                    VStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.title2)
                        Text("立即同步")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
                .disabled(syncService.syncStatus == .syncing)
                
                Button(action: clearSyncCache) {
                    VStack(spacing: 4) {
                        Image(systemName: "trash")
                            .font(.title2)
                        Text("清理缓存")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }
                
                Button(action: resetSyncState) {
                    VStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.title2)
                        Text("重置状态")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                }
            }
        }
    }
    
    // MARK: - 辅助视图和方法
    
    private var syncStatusBadge: some View {
        Text(syncStatusText)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(syncStatusColor)
            .cornerRadius(4)
    }
    
    private var syncStatusIcon: some View {
        Group {
            switch syncService.syncStatus {
            case .idle:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case .syncing:
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundColor(.blue)
                    .rotationEffect(.degrees(syncService.syncProgress * 360))
                    .animation(.linear(duration: 2).repeatForever(autoreverses: false), value: syncService.syncProgress)
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
    }
    
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
    
    private var syncStatusDescription: String {
        switch syncService.syncStatus {
        case .idle:
            return "系统空闲，等待同步"
        case .syncing:
            return "正在同步数据..."
        case .paused:
            return "同步已暂停"
        case .completed:
            return "同步完成"
        case .failed(let error):
            return "同步失败：\(String(describing: error))"
        }
    }
    
    private var lastSyncText: String {
        guard let lastSync = syncService.lastSyncDate else {
            return "从未同步"
        }
        
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: lastSync, relativeTo: Date())
    }
    
    private func syncDetailsSection(_ details: SyncDetails) -> some View {
        VStack(spacing: 8) {
            HStack {
                Text("当前阶段")
                Spacer()
                Text(details.phase.description)
                    .fontWeight(.medium)
            }
            
            if details.totalRecords > 0 {
                HStack {
                    Text("记录进度")
                    Spacer()
                    Text("\(details.processedRecords)/\(details.totalRecords)")
                        .fontWeight(.medium)
                }
            }
            
            if details.failedRecords > 0 {
                HStack {
                    Text("失败记录")
                    Spacer()
                    Text("\(details.failedRecords)")
                        .fontWeight(.medium)
                        .foregroundColor(.red)
                }
            }
        }
        .font(.caption)
    }
    
    // MARK: - 操作方法
    
    private func performManualSync() {
        Task {
            do {
                try await syncService.syncFromCloud()
            } catch {
                print("手动同步失败: \(error)")
            }
        }
    }
    
    private func clearSyncCache() {
        // 实现清理同步缓存的逻辑
        print("清理同步缓存")
    }
    
    private func resetSyncState() {
        // 实现重置同步状态的逻辑
        print("重置同步状态")
    }
    
    private func refreshSyncStatus() {
        // 刷新同步状态
        // objectWillChange.send() // 如需响应式刷新请用 @ObservableObject
    }
    
    private func startRefreshTimer() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            refreshSyncStatus()
        }
    }
    
    private func stopRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}

// MARK: - 统计卡片
struct SyncStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(ModernColors.System.gray6))
        .cornerRadius(8)
    }
}



#Preview {
    SyncDashboardView()
}
