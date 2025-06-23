//
//  Swift6CompatibleTestApp.swift
//  ManualBox
//
//  Created by Assistant on 2025/6/21.
//

import SwiftUI

// MARK: - Swift 6 兼容的测试应用
// @main // 注释掉以避免多个入口点冲突
struct Swift6CompatibleTestApp: App {
    
    var body: some Scene {
        WindowGroup {
            Swift6TestContentView()
                .onAppear {
                    print("✅ Swift 6 兼容测试应用启动完成")
                }
        }
        #if os(macOS)
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)
        #endif
    }
}

// MARK: - 主内容视图
struct Swift6TestContentView: View {
    @StateObject private var appStateManager = AppStateManager.shared
    @StateObject private var eventBus = EventBus.shared
    @StateObject private var stateMonitor = StateMonitor.shared
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            BasicStateTestView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("基础测试")
                }
                .tag(0)
            
            EventTestView()
                .tabItem {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                    Text("事件测试")
                }
                .tag(1)
            
            MonitorTestView()
                .tabItem {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                    Text("监控测试")
                }
                .tag(2)
        }
        .environmentObject(appStateManager)
        .environmentObject(eventBus)
        .environmentObject(stateMonitor)
        .onAppear {
            // 启动监控
            stateMonitor.startMonitoring()
            
            // 初始化应用状态
            appStateManager.setInitialized(true)
            appStateManager.updateNetworkConnection(true)
            
            // 发布初始化完成事件
            eventBus.publishNavigation(from: "启动", to: "主界面")
        }
        #if os(macOS)
        .frame(minWidth: 800, minHeight: 600)
        #endif
    }
}

// MARK: - 基础状态测试视图
struct BasicStateTestView: View {
    @EnvironmentObject private var appStateManager: AppStateManager
    @State private var counter = 0
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("基础状态管理测试")
                    .font(.title)
                    .fontWeight(.bold)
                
                // 应用状态显示
                VStack(alignment: .leading, spacing: 8) {
                    Text("应用状态:")
                        .font(.headline)
                    
                    HStack {
                        Text("已初始化:")
                        Spacer()
                        Text("\(appStateManager.state.isInitialized ? "是" : "否")")
                            .foregroundColor(appStateManager.state.isInitialized ? .green : .red)
                    }
                    
                    HStack {
                        Text("网络连接:")
                        Spacer()
                        Text("\(appStateManager.state.hasNetworkConnection ? "已连接" : "未连接")")
                            .foregroundColor(appStateManager.state.hasNetworkConnection ? .green : .red)
                    }
                    
                    HStack {
                        Text("同步状态:")
                        Spacer()
                        Text("\(syncStatusText)")
                            .foregroundColor(.blue)
                    }
                }
                .padding()
                .background(Color(red: 0.95, green: 0.95, blue: 0.97))
                .cornerRadius(12)
                
                // 计数器测试
                VStack(spacing: 12) {
                    Text("计数器: \(counter)")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    HStack(spacing: 12) {
                        Button("增加") {
                            counter += 1
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button("减少") {
                            counter -= 1
                        }
                        .buttonStyle(.bordered)
                        
                        Button("重置") {
                            counter = 0
                        }
                        .buttonStyle(.bordered)
                    }
                }
                
                // 状态控制按钮
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Button("模拟网络断开") {
                            appStateManager.updateNetworkConnection(false)
                        }
                        .buttonStyle(.bordered)
                        
                        Button("恢复网络") {
                            appStateManager.updateNetworkConnection(true)
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    HStack(spacing: 12) {
                        Button("模拟同步") {
                            Task {
                                appStateManager.updateSyncStatus(.syncing, progress: 0.0)
                                try? await Task.sleep(nanoseconds: 2_000_000_000)
                                appStateManager.updateSyncStatus(.completed, progress: 1.0)
                            }
                        }
                        .buttonStyle(.bordered)
                        
                        Button("模拟错误") {
                            let error = NSError(domain: "TestError", code: 1001, userInfo: [
                                NSLocalizedDescriptionKey: "这是一个测试错误"
                            ])
                            appStateManager.handleError(error, context: "基础测试")
                        }
                        .buttonStyle(.bordered)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("基础状态测试")
        }
    }
    
    private var syncStatusText: String {
        switch appStateManager.state.syncStatus {
        case .idle:
            return "空闲"
        case .syncing:
            return "同步中"
        case .completed:
            return "已完成"
        case .failed(_):
            return "失败"
        case .paused:
            return "已暂停"
        }
    }
}

// MARK: - 事件测试视图
struct EventTestView: View {
    @EnvironmentObject private var eventBus: EventBus
    @State private var lastEventDescription = "无事件"
    @State private var eventCount = 0
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("事件系统测试")
                    .font(.title)
                    .fontWeight(.bold)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("事件状态:")
                        .font(.headline)
                    
                    Text("最新事件: \(lastEventDescription)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("事件总数: \(eventCount)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(red: 0.95, green: 0.95, blue: 0.97))
                .cornerRadius(12)
                
                VStack(spacing: 12) {
                    Button("发布导航事件") {
                        eventBus.publishNavigation(from: "测试页面", to: "目标页面")
                        eventCount += 1
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("发布性能事件") {
                        eventBus.publishPerformanceMetric(
                            name: "test_metric",
                            value: Double.random(in: 0...100),
                            unit: "%"
                        )
                        eventCount += 1
                    }
                    .buttonStyle(.bordered)
                    
                    Button("发布数据变更事件") {
                        eventBus.publishDataChange(
                            entityType: "TestEntity",
                            changeType: .created,
                            entityId: UUID()
                        )
                        eventCount += 1
                    }
                    .buttonStyle(.bordered)
                    
                    Button("清空事件历史") {
                        eventBus.clearEventHistory()
                        eventCount = 0
                        lastEventDescription = "历史已清空"
                    }
                    .buttonStyle(.bordered)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("事件测试")
            .onReceive(eventBus.$lastEvent) { event in
                if let event = event {
                    lastEventDescription = "\(type(of: event)) - \(event.timestamp.formatted(date: .omitted, time: .shortened))"
                }
            }
        }
    }
}

// MARK: - 监控测试视图
struct MonitorTestView: View {
    @EnvironmentObject private var stateMonitor: StateMonitor
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("状态监控测试")
                    .font(.title)
                    .fontWeight(.bold)
                
                if let performance = stateMonitor.currentPerformance {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("性能指标:")
                            .font(.headline)
                        
                        HStack {
                            Text("内存使用:")
                            Spacer()
                            Text("\(String(format: "%.1f", performance.memoryUsage)) MB")
                        }
                        
                        HStack {
                            Text("CPU使用:")
                            Spacer()
                            Text("\(String(format: "%.1f", performance.cpuUsage))%")
                        }
                        
                        HStack {
                            Text("活跃ViewModels:")
                            Spacer()
                            Text("\(performance.activeViewModels)")
                        }
                        
                        HStack {
                            Text("监控状态:")
                            Spacer()
                            Text(stateMonitor.isMonitoring ? "运行中" : "已停止")
                                .foregroundColor(stateMonitor.isMonitoring ? .green : .red)
                        }
                    }
                    .padding()
                    .background(Color(red: 0.95, green: 0.95, blue: 0.97))
                    .cornerRadius(12)
                } else {
                    Text("性能数据加载中...")
                        .foregroundColor(.secondary)
                }
                
                VStack(spacing: 12) {
                    Button(stateMonitor.isMonitoring ? "停止监控" : "开始监控") {
                        if stateMonitor.isMonitoring {
                            stateMonitor.stopMonitoring()
                        } else {
                            stateMonitor.startMonitoring()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("清空监控历史") {
                        stateMonitor.clearHistory()
                    }
                    .buttonStyle(.bordered)
                }
                
                Text("状态历史记录: \(stateMonitor.stateHistory.count) 条")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("性能历史记录: \(stateMonitor.performanceHistory.count) 条")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .padding()
            .navigationTitle("监控测试")
        }
    }
}

// MARK: - 预览
#Preview("Swift 6 测试应用") {
    Swift6TestContentView()
}
