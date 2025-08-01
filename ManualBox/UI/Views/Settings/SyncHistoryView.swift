import SwiftUI

// 导入共享UI组件以使用统一的同步历史行组件
// 注意：SyncHistoryRow 现在从 SharedUIComponents 导入

// MARK: - 同步历史视图
struct SyncHistoryView: View {
    @StateObject private var syncService = CloudKitSyncService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedHistoryItem: SyncHistoryItem?
    @State private var showingHistoryDetail = false
    @State private var searchText = ""
    @State private var filterType: SyncHistoryFilter = .all
    
    private var filteredHistory: [SyncHistoryItem] {
        var history = syncService.syncHistory
        
        // 搜索过滤
        if !searchText.isEmpty {
            history = history.filter { item in
                item.description.localizedCaseInsensitiveContains(searchText) ||
                item.syncType.description.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // 类型过滤
        switch filterType {
        case .all:
            break
        case .successful:
            history = history.filter { $0.status == .completed }
        case .failed:
            history = history.filter { 
                if case .failed = $0.status { return true }
                return false
            }
        case .conflicts:
            history = history.filter { $0.conflictCount > 0 }
        }
        
        return history.sorted { $0.timestamp > $1.timestamp }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 搜索和筛选
                searchAndFilterSection
                
                Divider()
                
                // 历史列表
                historyList
            }
            .navigationTitle("同步历史")
            #if os(macOS)
            .platformNavigationBarTitleDisplayMode(0)
            .platformToolbar(trailing: {
                Button("刷新") {
                    // syncService.refreshSyncHistory()
                }
            })
            #else
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(content: {
                SwiftUI.ToolbarItem(placement: .navigationBarTrailing) {
                    Button("刷新") {
                        // syncService.refreshSyncHistory()
                    }
                }
            })
            #endif
        }
        .sheet(isPresented: $showingHistoryDetail) {
            if let item = selectedHistoryItem {
                SyncHistoryDetailView(historyItem: item)
            }
        }
    }
    
    // MARK: - 搜索和筛选部分
    private var searchAndFilterSection: some View {
        VStack(spacing: 12) {
            // 搜索框
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("搜索同步记录...", text: $searchText)
                    .textFieldStyle(.plain)
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(ModernColors.System.gray6)
            .cornerRadius(8)
            
            // 筛选器
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(SyncHistoryFilter.allCases, id: \.self) { filter in
                        FilterChip(
                            title: filter.title,
                            isSelected: filterType == filter,
                            count: getFilterCount(filter)
                        ) {
                            filterType = filter
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding()
        .background(ModernColors.System.gray6)
    }
    
    // MARK: - 历史列表
    private var historyList: some View {
        Group {
            if filteredHistory.isEmpty {
                emptyStateView
            } else {
                List {
                    ForEach(filteredHistory, id: \.id) { item in
                        SyncHistoryRow(
                            item: item,
                            onTap: {
                                selectedHistoryItem = item
                                showingHistoryDetail = true
                            }
                        )
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }
                }
                .listStyle(.plain)
            }
        }
    }
    
    // MARK: - 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("暂无同步历史")
                .font(.title2)
                .fontWeight(.medium)
            
            Text(emptyStateMessage)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ModernColors.Background.primary)
    }
    
    private var emptyStateMessage: String {
        switch filterType {
        case .all:
            return "还没有同步记录"
        case .successful:
            return "没有成功的同步记录"
        case .failed:
            return "没有失败的同步记录"
        case .conflicts:
            return "没有包含冲突的同步记录"
        }
    }
    
    // MARK: - 辅助方法
    
    private func getFilterCount(_ filter: SyncHistoryFilter) -> Int {
        switch filter {
        case .all:
            return syncService.syncHistory.count
        case .successful:
            return syncService.syncHistory.filter { $0.status == .completed }.count
        case .failed:
            return syncService.syncHistory.filter { 
                if case .failed = $0.status { return true }
                return false
            }.count
        case .conflicts:
            return syncService.syncHistory.filter { $0.conflictCount > 0 }.count
        }
    }
    
    private func exportHistory() {
        // 实现导出历史的逻辑
        print("导出同步历史")
    }
    
    private func clearHistory() {
        // 实现清空历史的逻辑
        print("清空同步历史")
    }
}

// MARK: - 筛选器芯片
// 注意：SyncHistoryRow 已移动到 SharedUIComponents.swift 以避免重复定义

// MARK: - 筛选器芯片
struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let count: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                
                if count > 0 {
                    Text("\(count)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(isSelected ? .white : .secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isSelected ? Color.white.opacity(0.3) : ModernColors.System.gray5)
                        .cornerRadius(8)
                }
            }
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor : ModernColors.System.gray5)
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 同步历史详情视图
struct SyncHistoryDetailView: View {
    let historyItem: SyncHistoryItem
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 基本信息
                    basicInfoSection
                    
                    // 统计信息
                    statisticsSection
                    
                    // 错误信息
                    if !historyItem.errors.isEmpty {
                        errorsSection
                    }
                    
                    // 详细日志
                    if !historyItem.detailLog.isEmpty {
                        logSection
                    }
                }
                .padding()
            }
            .navigationTitle("同步详情")
            #if os(macOS)
            .platformNavigationBarTitleDisplayMode(0)
            .platformToolbar(trailing: {
                Button("关闭") {
                    dismiss()
                }
            })
            #else
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(content: {
                SwiftUI.ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            })
            #endif
        }
    }
    
    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("基本信息")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                InfoRow(label: "同步类型", value: historyItem.syncType.description)
                InfoRow(label: "开始时间", value: formatDate(historyItem.timestamp))
                InfoRow(label: "状态", value: historyItem.status.description)
                
                if let duration = historyItem.duration {
                    InfoRow(label: "耗时", value: formatDuration(duration))
                }
                
                InfoRow(label: "描述", value: historyItem.description)
            }
        }
    }
    
    private var statisticsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("统计信息")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                StatCard(
                    title: "处理记录",
                    value: "\(historyItem.recordCount)",
                    icon: "doc",
                    color: .blue
                )
                
                StatCard(
                    title: "冲突数量",
                    value: "\(historyItem.conflictCount)",
                    icon: "exclamationmark.triangle",
                    color: .orange
                )
                
                StatCard(
                    title: "错误数量",
                    value: "\(historyItem.errorCount)",
                    icon: "xmark.circle",
                    color: .red
                )
                
                StatCard(
                    title: "数据传输",
                    value: formatBytes(historyItem.dataTransferred),
                    icon: "arrow.up.arrow.down",
                    color: .green
                )
            }
        }
    }
    
    private var errorsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("错误信息")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                ForEach(historyItem.errors.indices, id: \.self) { index in
                    let error = historyItem.errors[index]
                    ErrorRow(error: error)
                }
            }
        }
    }
    
    private var logSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("详细日志")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text(historyItem.detailLog)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding()
                .background(ModernColors.System.gray6)
                .cornerRadius(8)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
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
    
    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

// MARK: - 错误行组件
struct ErrorRow: View {
    let error: SyncErrorRecord
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(.red)
                .font(.caption)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(error.message)
                    .font(.caption)
                    .foregroundColor(.primary)
                
                if let details = error.details {
                    Text(details)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.red.opacity(0.1))
        .cornerRadius(6)
    }
}

// MARK: - 筛选器枚举
enum SyncHistoryFilter: CaseIterable {
    case all
    case successful
    case failed
    case conflicts
    
    var title: String {
        switch self {
        case .all: return "全部"
        case .successful: return "成功"
        case .failed: return "失败"
        case .conflicts: return "冲突"
        }
    }
}

#Preview {
    SyncHistoryView()
}
