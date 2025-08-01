//
//  SyncPerformanceView.swift
//  ManualBox
//
//  Created by Assistant on 2024/12/19.
//  同步性能监控和优化界面
//

import SwiftUI
import Charts

struct SyncPerformanceView: View {
    @StateObject private var incrementalSyncManager = IncrementalSyncManager(
        context: PersistenceController.shared.container.viewContext
    )
    @StateObject private var priorityManager = SyncPriorityManager()
    @State private var selectedTab = 0
    @State private var showingSettings = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 顶部标签选择器
                Picker("视图", selection: $selectedTab) {
                    Text("增量同步").tag(0)
                    Text("任务队列").tag(1)
                    Text("性能分析").tag(2)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                // 内容区域
                TabView(selection: $selectedTab) {
                    incrementalSyncView
                        .tag(0)
                    
                    taskQueueView
                        .tag(1)
                    
                    performanceAnalysisView
                        .tag(2)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationTitle("同步性能")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("设置") {
                        showingSettings = true
                    }
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            SyncPerformanceSettingsSheet(
                incrementalManager: incrementalSyncManager,
                priorityManager: priorityManager
            )
        }
    }
    
    // MARK: - 增量同步视图
    
    private var incrementalSyncView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 增量同步状态卡片
                incrementalSyncStatusCard
                
                // 同步效率图表
                if let efficiency = incrementalSyncManager.syncEfficiency {
                    syncEfficiencyChart(efficiency)
                }
                
                // 待处理变更
                pendingChangesSection
                
                // 控制按钮
                incrementalSyncControls
            }
            .padding()
        }
    }
    
    private var incrementalSyncStatusCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("增量同步")
                        .font(.headline)
                    
                    Text(incrementalSyncManager.changeTrackingEnabled ? "已启用" : "已禁用")
                        .font(.caption)
                        .foregroundColor(incrementalSyncManager.changeTrackingEnabled ? .green : .red)
                }
                
                Spacer()
                
                Toggle("", isOn: Binding(
                    get: { incrementalSyncManager.changeTrackingEnabled },
                    set: { incrementalSyncManager.enableChangeTracking($0) }
                ))
            }
            
            if let lastSync = incrementalSyncManager.lastIncrementalSync {
                HStack {
                    Text("上次增量同步:")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(formatDate(lastSync))
                        .fontWeight(.medium)
                }
            }
            
            if let efficiency = incrementalSyncManager.syncEfficiency {
                VStack(spacing: 8) {
                    HStack {
                        Text("同步效率:")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(efficiency.efficiencyPercentage)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                    }
                    
                    HStack {
                        Text("节省数据:")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(efficiency.dataSavedPercentage)
                            .fontWeight(.medium)
                            .foregroundColor(.green)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private func syncEfficiencyChart(_ efficiency: SyncEfficiency) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("同步效率分析")
                .font(.headline)
            
            Chart {
                SectorMark(
                    angle: .value("变更记录", efficiency.changedRecords),
                    innerRadius: .ratio(0.5),
                    angularInset: 2
                )
                .foregroundStyle(.blue)
                .opacity(0.8)
                
                SectorMark(
                    angle: .value("未变更记录", efficiency.totalRecords - efficiency.changedRecords),
                    innerRadius: .ratio(0.5),
                    angularInset: 2
                )
                .foregroundStyle(.gray)
                .opacity(0.3)
            }
            .frame(height: 200)
            
            HStack {
                Label("\(efficiency.changedRecords) 变更", systemImage: "circle.fill")
                    .foregroundColor(.blue)
                
                Spacer()
                
                Label("\(efficiency.totalRecords - efficiency.changedRecords) 未变更", systemImage: "circle.fill")
                    .foregroundColor(.gray)
            }
            .font(.caption)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private var pendingChangesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("待处理变更")
                .font(.headline)
            
            if incrementalSyncManager.pendingChanges.isEmpty {
                Text("没有待处理的变更")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(Array(incrementalSyncManager.pendingChanges.keys.sorted()), id: \.self) { entityType in
                        HStack {
                            Text(entityType)
                                .fontWeight(.medium)
                            
                            Spacer()
                            
                            Text("\(incrementalSyncManager.pendingChanges[entityType] ?? 0)")
                                .foregroundColor(.blue)
                                .fontWeight(.semibold)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private var incrementalSyncControls: some View {
        VStack(spacing: 12) {
            Button("立即执行增量同步") {
                performIncrementalSync()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!incrementalSyncManager.shouldPerformIncrementalSync())
            
            Button("重置增量同步") {
                incrementalSyncManager.resetIncrementalSync()
            }
            .buttonStyle(.bordered)
        }
    }
    
    // MARK: - 任务队列视图
    
    private var taskQueueView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 队列统计
                if let stats = priorityManager.queueStatistics {
                    queueStatisticsCard(stats)
                }
                
                // 优先级分布
                priorityDistributionSection
                
                // 任务列表
                taskListSection
            }
            .padding()
        }
    }
    
    private func queueStatisticsCard(_ stats: QueueStatistics) -> some View {
        VStack(spacing: 16) {
            Text("队列统计")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                StatCard(title: "总任务", value: "\(stats.totalTasks)", color: .blue)
                StatCard(title: "队列中", value: "\(stats.queuedTasks)", color: .orange)
                StatCard(title: "执行中", value: "\(stats.activeTasks)", color: .green)
                StatCard(title: "已完成", value: "\(stats.completedTasks)", color: .purple)
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("完成率")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(String(format: "%.1f%%", stats.completionRate * 100))")
                        .font(.headline)
                        .foregroundColor(.green)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("预计完成时间")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatDuration(stats.estimatedCompletionTime))
                        .font(.headline)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private var priorityDistributionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("优先级分布")
                .font(.headline)
            
            if let stats = priorityManager.queueStatistics {
                Chart {
                    ForEach(SyncPriority.allCases, id: \.self) { priority in
                        let count = stats.priorityDistribution[priority] ?? 0
                        BarMark(
                            x: .value("优先级", priority.description),
                            y: .value("数量", count)
                        )
                        .foregroundStyle(colorForPriority(priority))
                    }
                }
                .frame(height: 200)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private var taskListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("任务队列")
                    .font(.headline)
                
                Spacer()
                
                Menu {
                    Button("清除已完成") {
                        priorityManager.clearCompletedTasks()
                    }
                    
                    Button("重试失败任务") {
                        priorityManager.retryFailedTasks()
                    }
                    
                    Divider()
                    
                    Button("暂停调度") {
                        priorityManager.pauseScheduling()
                    }
                    
                    Button("恢复调度") {
                        priorityManager.resumeScheduling()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
            
            LazyVStack(spacing: 8) {
                // 活跃任务
                if !priorityManager.activeTasks.isEmpty {
                    Text("执行中")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    ForEach(priorityManager.activeTasks) { task in
                        TaskRowView(task: task, status: .active)
                    }
                }
                
                // 队列任务
                if !priorityManager.taskQueue.isEmpty {
                    Text("队列中")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    ForEach(priorityManager.taskQueue.prefix(10)) { task in
                        TaskRowView(task: task, status: .queued)
                    }
                    
                    if priorityManager.taskQueue.count > 10 {
                        Text("还有 \(priorityManager.taskQueue.count - 10) 个任务...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                
                // 失败任务
                if !priorityManager.failedTasks.isEmpty {
                    Text("失败")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    ForEach(priorityManager.failedTasks.prefix(5)) { task in
                        TaskRowView(task: task, status: .failed)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - 性能分析视图
    
    private var performanceAnalysisView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 性能概览
                performanceOverviewCard
                
                // 网络质量监控
                networkQualitySection
                
                // 优化建议
                optimizationSuggestionsSection
            }
            .padding()
        }
    }
    
    private var performanceOverviewCard: some View {
        VStack(spacing: 16) {
            Text("性能概览")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if let stats = priorityManager.queueStatistics {
                VStack(spacing: 12) {
                    HStack {
                        Text("平均任务时长:")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(formatDuration(stats.averageTaskDuration))
                            .fontWeight(.medium)
                    }
                    
                    HStack {
                        Text("失败率:")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(String(format: "%.1f%%", stats.failureRate * 100))")
                            .fontWeight(.medium)
                            .foregroundColor(stats.failureRate > 0.1 ? .red : .green)
                    }
                    
                    HStack {
                        Text("并发任务数:")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(priorityManager.maxConcurrentTasks)")
                            .fontWeight(.medium)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private var networkQualitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("网络质量")
                .font(.headline)
            
            // 这里可以添加网络质量监控图表
            Text("网络质量监控功能开发中...")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private var optimizationSuggestionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("优化建议")
                .font(.headline)
            
            LazyVStack(alignment: .leading, spacing: 8) {
                if incrementalSyncManager.pendingChanges.values.reduce(0, +) > 100 {
                    OptimizationSuggestion(
                        icon: "arrow.clockwise.circle",
                        title: "执行增量同步",
                        description: "有大量待处理变更，建议执行增量同步",
                        priority: .high
                    )
                }
                
                if let stats = priorityManager.queueStatistics, stats.failureRate > 0.1 {
                    OptimizationSuggestion(
                        icon: "exclamationmark.triangle",
                        title: "检查失败任务",
                        description: "失败率较高，建议检查失败原因",
                        priority: .medium
                    )
                }
                
                OptimizationSuggestion(
                    icon: "gear",
                    title: "调整并发数",
                    description: "根据网络状况调整并发任务数",
                    priority: .low
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - 辅助方法
    
    private func performIncrementalSync() {
        Task {
            do {
                let changes = try await incrementalSyncManager.getIncrementalChanges()
                // 这里应该执行实际的同步操作
                incrementalSyncManager.markSyncCompleted(with: changes)
            } catch {
                print("增量同步失败: \(error)")
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
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
    
    private func colorForPriority(_ priority: SyncPriority) -> Color {
        switch priority {
        case .critical: return .red
        case .high: return .orange
        case .normal: return .blue
        case .low: return .gray
        case .background: return .secondary
        }
    }
}

// MARK: - 辅助视图组件

struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
}

enum TaskStatus {
    case queued, active, completed, failed
    
    var color: Color {
        switch self {
        case .queued: return .orange
        case .active: return .green
        case .completed: return .blue
        case .failed: return .red
        }
    }
    
    var icon: String {
        switch self {
        case .queued: return "clock"
        case .active: return "arrow.clockwise"
        case .completed: return "checkmark.circle"
        case .failed: return "xmark.circle"
        }
    }
}

struct TaskRowView: View {
    let task: SyncTask
    let status: TaskStatus
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: status.icon)
                .foregroundColor(status.color)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(task.recordType)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(task.operation.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(task.priority.description)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(colorForPriority(task.priority).opacity(0.2))
                    .foregroundColor(colorForPriority(task.priority))
                    .cornerRadius(4)
                
                Text(formatTime(task.createdAt))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
    
    private func colorForPriority(_ priority: SyncPriority) -> Color {
        switch priority {
        case .critical: return .red
        case .high: return .orange
        case .normal: return .blue
        case .low: return .gray
        case .background: return .secondary
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// OptimizationSuggestion is defined in PerformanceOptimizationService.swift

// MARK: - 设置弹窗
struct SyncPerformanceSettingsSheet: View {
    let incrementalManager: IncrementalSyncManager
    let priorityManager: SyncPriorityManager
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("增量同步设置") {
                    Toggle("启用变更跟踪", isOn: Binding(
                        get: { incrementalManager.changeTrackingEnabled },
                        set: { incrementalManager.enableChangeTracking($0) }
                    ))
                }
                
                Section("任务调度设置") {
                    Stepper("最大并发任务: \(priorityManager.maxConcurrentTasks)",
                           value: Binding(
                               get: { priorityManager.maxConcurrentTasks },
                               set: { priorityManager.maxConcurrentTasks = $0 }
                           ),
                           in: 1...10)
                    
                    Toggle("启用优先级提升", isOn: Binding(
                        get: { priorityManager.priorityBoostEnabled },
                        set: { priorityManager.priorityBoostEnabled = $0 }
                    ))
                    
                    Toggle("启用自适应调度", isOn: Binding(
                        get: { priorityManager.adaptiveSchedulingEnabled },
                        set: { priorityManager.adaptiveSchedulingEnabled = $0 }
                    ))
                }
            }
            .navigationTitle("性能设置")
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

#Preview {
    SyncPerformanceView()
}