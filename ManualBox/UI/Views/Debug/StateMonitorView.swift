//
//  StateMonitorView.swift
//  ManualBox
//
//  Created by Assistant on 2025/6/21.
//

import SwiftUI

// MARK: - 状态监控调试视图
struct StateMonitorView: View {
    @EnvironmentObject private var stateMonitor: StateMonitor
    @EnvironmentObject private var appStateManager: AppStateManager
    @EnvironmentObject private var eventBus: EventBus
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationView {
            VStack {
                Picker("监控类型", selection: $selectedTab) {
                    Text("状态历史").tag(0)
                    Text("性能指标").tag(1)
                    Text("事件历史").tag(2)
                    Text("全局状态").tag(3)
                }
                .pickerStyle(.segmented)
                .padding()
                
                TabView(selection: $selectedTab) {
                    StateHistoryView()
                        .tag(0)
                    
                    PerformanceView()
                        .tag(1)
                    
                    EventHistoryView()
                        .tag(2)
                    
                    GlobalStateView()
                        .tag(3)
                }
                #if os(iOS)
                .tabViewStyle(.page(indexDisplayMode: .never))
                #endif
            }
            .navigationTitle("状态监控")
            .toolbar(content: {
                SwiftUI.ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("清空历史") {
                            stateMonitor.clearHistory()
                            eventBus.clearEventHistory()
                            appStateManager.clearErrorHistory()
                        }

                        Button("导出数据") {
                            exportMonitoringData()
                        }

                        Button(stateMonitor.isMonitoring ? "停止监控" : "开始监控") {
                            if stateMonitor.isMonitoring {
                                stateMonitor.stopMonitoring()
                            } else {
                                stateMonitor.startMonitoring()
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            })
        }
    }
    
    private func exportMonitoringData() {
        // 导出监控数据的实现
        print("导出监控数据...")
    }
}

// MARK: - 状态历史视图
struct StateHistoryView: View {
    @EnvironmentObject private var stateMonitor: StateMonitor
    
    var body: some View {
        List(stateMonitor.stateHistory) { snapshot in
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(snapshot.viewModel)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text(snapshot.timestamp, style: .time)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(snapshot.state)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                
                if let memoryUsage = snapshot.memoryUsage {
                    Text("内存: \(String(format: "%.1f", memoryUsage)) MB")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
            }
            .padding(.vertical, 2)
        }
        .refreshable {
            // 刷新状态历史
        }
    }
}

// MARK: - 性能指标视图
struct PerformanceView: View {
    @EnvironmentObject private var stateMonitor: StateMonitor
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if let currentPerformance = stateMonitor.currentPerformance {
                    CurrentPerformanceCard(performance: currentPerformance)
                }
                
                PerformanceChartView()
                
                PerformanceHistoryList()
            }
            .padding()
        }
    }
}

// MARK: - 当前性能卡片
struct CurrentPerformanceCard: View {
    let performance: PerformanceSnapshot
    
    var body: some View {
        VStack(spacing: 12) {
            Text("当前性能指标")
                .font(.headline)
            
            HStack(spacing: 20) {
                MetricView(title: "内存", value: performance.memoryUsage, unit: "MB", color: .blue)
                MetricView(title: "CPU", value: performance.cpuUsage, unit: "%", color: .orange)
                MetricView(title: "磁盘", value: performance.diskUsage, unit: "MB", color: .green)
            }
            
            HStack(spacing: 20) {
                Text("活跃ViewModels: \(performance.activeViewModels)")
                    .font(.caption)
                Text("待处理任务: \(performance.pendingTasks)")
                    .font(.caption)
            }
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(red: 0.95, green: 0.95, blue: 0.97))
        .cornerRadius(12)
    }
}

// MARK: - 指标视图
struct MetricView: View {
    let title: String
    let value: Double
    let unit: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("\(String(format: "%.1f", value))")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(color)
            
            Text(unit)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - 性能图表视图
struct PerformanceChartView: View {
    @EnvironmentObject private var stateMonitor: StateMonitor
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("性能趋势")
                .font(.headline)
                .padding(.bottom, 8)
            
            // 简化的图表实现
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: 120)
                .overlay(
                    Text("性能图表\n(需要图表库实现)")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                )
                .cornerRadius(8)
        }
        .padding()
        .background(Color(red: 0.95, green: 0.95, blue: 0.97))
        .cornerRadius(12)
    }
}

// MARK: - 性能历史列表
struct PerformanceHistoryList: View {
    @EnvironmentObject private var stateMonitor: StateMonitor
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("性能历史")
                .font(.headline)
                .padding(.bottom, 8)
            
            LazyVStack(spacing: 8) {
                ForEach(stateMonitor.performanceHistory.suffix(10).reversed(), id: \.id) { snapshot in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(snapshot.timestamp, style: .time)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            HStack(spacing: 12) {
                                Text("内存: \(String(format: "%.1f", snapshot.memoryUsage))MB")
                                    .font(.caption2)
                                Text("CPU: \(String(format: "%.1f", snapshot.cpuUsage))%")
                                    .font(.caption2)
                            }
                        }
                        
                        Spacer()
                        
                        Circle()
                            .fill(performanceColor(snapshot))
                            .frame(width: 8, height: 8)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(red: 0.95, green: 0.95, blue: 0.97))
                    .cornerRadius(8)
                }
            }
        }
    }
    
    private func performanceColor(_ snapshot: PerformanceSnapshot) -> Color {
        if snapshot.memoryUsage > 500 || snapshot.cpuUsage > 80 {
            return .red
        } else if snapshot.memoryUsage > 200 || snapshot.cpuUsage > 50 {
            return .orange
        } else {
            return .green
        }
    }
}

// MARK: - 事件历史视图
struct EventHistoryView: View {
    @EnvironmentObject private var eventBus: EventBus
    @State private var allEvents: [AppEvent] = []

    var body: some View {
        List {
            ForEach(allEvents, id: \.eventId) { event in
                EventRowView(event: event)
            }
        }
        .refreshable {
            loadAllEvents()
        }
        .onAppear {
            loadAllEvents()
        }
    }

    private func loadAllEvents() {
        // 收集所有类型的事件
        var events: [AppEvent] = []

        // 获取各种具体类型的事件
        events.append(contentsOf: eventBus.getEventHistory(ofType: ProductSelectionEvent.self, limit: 20))
        events.append(contentsOf: eventBus.getEventHistory(ofType: DataChangeEvent.self, limit: 20))
        events.append(contentsOf: eventBus.getEventHistory(ofType: SyncEvent.self, limit: 20))
        events.append(contentsOf: eventBus.getEventHistory(ofType: ErrorEvent.self, limit: 20))
        events.append(contentsOf: eventBus.getEventHistory(ofType: PerformanceEvent.self, limit: 20))
        events.append(contentsOf: eventBus.getEventHistory(ofType: NavigationEvent.self, limit: 20))

        // 按时间戳排序
        allEvents = events.sorted { $0.timestamp > $1.timestamp }
            .prefix(100)
            .map { $0 }
    }
}

// MARK: - 事件行视图
struct EventRowView: View {
    let event: AppEvent
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(eventTypeName)
                    .font(.headline)
                    .foregroundColor(eventColor)
                
                Spacer()
                
                Text(event.timestamp, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(eventDescription)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 2)
    }
    
    private var eventTypeName: String {
        switch event {
        case is ProductSelectionEvent:
            return "产品选择"
        case is DataChangeEvent:
            return "数据变更"
        case is SyncEvent:
            return "同步事件"
        case is ErrorEvent:
            return "错误事件"
        case is PerformanceEvent:
            return "性能指标"
        case is NavigationEvent:
            return "导航事件"
        default:
            return "未知事件"
        }
    }
    
    private var eventColor: Color {
        switch event {
        case is ErrorEvent:
            return .red
        case is SyncEvent:
            return .blue
        case is PerformanceEvent:
            return .orange
        default:
            return .primary
        }
    }
    
    private var eventDescription: String {
        switch event {
        case let productEvent as ProductSelectionEvent:
            return "选择产品: \(productEvent.product?.name ?? "无")"
        case let dataEvent as DataChangeEvent:
            return "\(dataEvent.entityType) \(dataEvent.changeType)"
        case let syncEvent as SyncEvent:
            switch syncEvent {
            case .started(let type):
                return "同步开始: \(type)"
            case .progressUpdated(let progress, let phase):
                return "同步进度: \(Int(progress * 100))% - \(phase)"
            case .conflictDetected(let conflict):
                return "检测到冲突: \(conflict.id)"
            case .conflictResolved(let conflictID):
                return "冲突已解决: \(conflictID)"
            case .completed(let statistics):
                return "同步完成: \(statistics.totalRecords) 条记录"
            case .failed(let error):
                return "同步失败: \(error.localizedDescription)"
            case .paused:
                return "同步已暂停"
            case .resumed:
                return "同步已恢复"
            }
        case let errorEvent as ErrorEvent:
            return errorEvent.error.localizedDescription
        case let perfEvent as PerformanceEvent:
            return "\(perfEvent.metricName): \(perfEvent.value) \(perfEvent.unit)"
        case let navEvent as NavigationEvent:
            return "\(navEvent.from) → \(navEvent.to)"
        default:
            return "事件详情"
        }
    }
}

// MARK: - 全局状态视图
struct GlobalStateView: View {
    @EnvironmentObject private var appStateManager: AppStateManager
    
    var body: some View {
        List {
            Section("应用状态") {
                StateRowView(title: "已初始化", value: "\(appStateManager.state.isInitialized)")
                StateRowView(title: "网络连接", value: "\(appStateManager.state.hasNetworkConnection)")
                StateRowView(title: "内存警告次数", value: "\(appStateManager.state.memoryWarningCount)")
            }
            
            Section("选择状态") {
                StateRowView(title: "选中产品", value: appStateManager.state.selectedProduct?.name ?? "无")
                StateRowView(title: "详情面板", value: "\(appStateManager.state.detailPanelState)")
            }
            
            Section("同步状态") {
                StateRowView(title: "同步状态", value: "\(appStateManager.state.syncStatus)")
                StateRowView(title: "同步进度", value: "\(String(format: "%.1f", appStateManager.state.syncProgress * 100))%")
                if let lastSync = appStateManager.state.lastSyncDate {
                    StateRowView(title: "最后同步", value: lastSync.formatted(date: .abbreviated, time: .shortened))
                }
            }
            
            if let globalError = appStateManager.state.globalError {
                Section("当前错误") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(globalError.severity.rawValue)
                            .font(.caption)
                            .foregroundColor(.red)
                        Text(globalError.message)
                            .font(.body)
                        Text(globalError.context)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            if !appStateManager.state.errorHistory.isEmpty {
                Section("错误历史") {
                    ForEach(appStateManager.state.errorHistory.suffix(5).reversed(), id: \.id) { error in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(error.severity.rawValue)
                                    .font(.caption)
                                    .foregroundColor(.red)
                                Spacer()
                                Text(error.timestamp, style: .time)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Text(error.message)
                                .font(.caption)
                                .lineLimit(2)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - 状态行视图
struct StateRowView: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.primary)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }
}

#Preview {
    StateMonitorView()
        .environmentObject(StateMonitor.shared)
        .environmentObject(AppStateManager.shared)
        .environmentObject(EventBus.shared)
}
