//
//  StateManagementDemoView.swift
//  ManualBox
//
//  Created by Assistant on 2025/6/21.
//

import SwiftUI

// MARK: - 状态管理演示视图
struct StateManagementDemoView: View {
    @StateObject private var appStateManager = AppStateManager.shared
    @StateObject private var eventBus = EventBus.shared
    @StateObject private var stateMonitor = StateMonitor.shared
    @State private var demoCounter = 0
    @State private var showStateMonitor = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 应用状态演示
                    AppStateSection()
                    
                    // 事件系统演示
                    EventSystemSection()
                    
                    // 错误处理演示
                    ErrorHandlingSection()
                    
                    // 性能监控演示
                    PerformanceSection()
                    
                    // 计数器演示
                    CounterSection(counter: $demoCounter)
                }
                .padding()
            }
            .navigationTitle("状态管理演示")
            .toolbar(content: {
                SwiftUI.ToolbarItem(placement: .primaryAction) {
                    Button("监控面板") {
                        showStateMonitor = true
                    }
                }
            })
            .sheet(isPresented: $showStateMonitor) {
                StateMonitorView()
            }
        }
        .environmentObject(appStateManager)
        .environmentObject(eventBus)
        .environmentObject(stateMonitor)
        .onAppear {
            // 启动监控
            if !stateMonitor.isMonitoring {
                stateMonitor.startMonitoring()
            }
        }
    }
}

// MARK: - 应用状态部分
struct AppStateSection: View {
    @EnvironmentObject private var appStateManager: AppStateManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("应用状态管理")
                .font(.headline)
            
            VStack(spacing: 8) {
                StateInfoRow(title: "初始化状态", value: "\(appStateManager.state.isInitialized)")
                StateInfoRow(title: "网络连接", value: "\(appStateManager.state.hasNetworkConnection)")
                StateInfoRow(title: "同步状态", value: "\(appStateManager.state.syncStatus)")
                StateInfoRow(title: "内存警告次数", value: "\(appStateManager.state.memoryWarningCount)")
            }
            
            HStack(spacing: 12) {
                Button("模拟网络断开") {
                    appStateManager.updateNetworkConnection(false)
                }
                .buttonStyle(.bordered)
                
                Button("模拟网络恢复") {
                    appStateManager.updateNetworkConnection(true)
                }
                .buttonStyle(.bordered)
                
                Button("模拟内存警告") {
                    appStateManager.recordMemoryWarning()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color(red: 0.95, green: 0.95, blue: 0.97))
        .cornerRadius(12)
    }
}

// MARK: - 事件系统部分
struct EventSystemSection: View {
    @EnvironmentObject private var eventBus: EventBus
    @State private var lastEventDescription = "无事件"
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("事件系统")
                .font(.headline)
            
            Text("最新事件: \(lastEventDescription)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(spacing: 12) {
                Button("发布导航事件") {
                    eventBus.publishNavigation(from: "演示页面", to: "目标页面")
                }
                .buttonStyle(.bordered)
                
                Button("发布性能事件") {
                    eventBus.publishPerformanceMetric(
                        name: "demo_metric",
                        value: Double.random(in: 0...100),
                        unit: "%"
                    )
                }
                .buttonStyle(.bordered)
                
                Button("发布同步事件") {
                    // 同步事件发布功能已移至CloudKit服务中
                    eventBus.publishPerformanceMetric(name: "sync_demo", value: 1.0, unit: "count")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color(red: 0.95, green: 0.95, blue: 0.97))
        .cornerRadius(12)
        .onReceive(eventBus.$lastEvent) { event in
            if let event = event {
                lastEventDescription = "\(type(of: event)) - \(event.timestamp.formatted(date: .omitted, time: .shortened))"
            }
        }
    }
}

// MARK: - 错误处理部分
struct ErrorHandlingSection: View {
    @EnvironmentObject private var appStateManager: AppStateManager
    @EnvironmentObject private var eventBus: EventBus
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("错误处理")
                .font(.headline)
            
            if let globalError = appStateManager.state.globalError {
                VStack(alignment: .leading, spacing: 4) {
                    Text("当前错误:")
                        .font(.caption)
                        .foregroundColor(.red)
                    Text(globalError.message)
                        .font(.body)
                    Text("上下文: \(globalError.context)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(8)
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            } else {
                Text("无错误")
                    .font(.caption)
                    .foregroundColor(.green)
            }
            
            HStack(spacing: 12) {
                Button("模拟警告") {
                    appStateManager.handleError(
                        message: "这是一个警告消息",
                        context: "演示",
                        severity: .warning
                    )
                }
                .buttonStyle(.bordered)
                
                Button("模拟错误") {
                    let error = NSError(domain: "DemoError", code: 1001, userInfo: [
                        NSLocalizedDescriptionKey: "这是一个演示错误"
                    ])
                    appStateManager.handleError(error, context: "演示")
                }
                .buttonStyle(.bordered)
                
                Button("清除错误") {
                    appStateManager.clearGlobalError()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color(red: 0.95, green: 0.95, blue: 0.97))
        .cornerRadius(12)
    }
}

// MARK: - 性能监控部分
struct PerformanceSection: View {
    @EnvironmentObject private var stateMonitor: StateMonitor
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("性能监控")
                .font(.headline)
            
            if let performance = stateMonitor.currentPerformance {
                VStack(spacing: 8) {
                    StateInfoRow(title: "内存使用", value: "\(String(format: "%.1f", performance.memoryUsage)) MB")
                    StateInfoRow(title: "CPU使用", value: "\(String(format: "%.1f", performance.cpuUsage))%")
                    StateInfoRow(title: "磁盘使用", value: "\(String(format: "%.1f", performance.diskUsage)) MB")
                    StateInfoRow(title: "活跃ViewModels", value: "\(performance.activeViewModels)")
                }
            } else {
                Text("性能数据加载中...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 12) {
                Button(stateMonitor.isMonitoring ? "停止监控" : "开始监控") {
                    if stateMonitor.isMonitoring {
                        stateMonitor.stopMonitoring()
                    } else {
                        stateMonitor.startMonitoring()
                    }
                }
                .buttonStyle(.bordered)
                
                Button("清空历史") {
                    stateMonitor.clearHistory()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color(red: 0.95, green: 0.95, blue: 0.97))
        .cornerRadius(12)
    }
}

// MARK: - 计数器部分
struct CounterSection: View {
    @Binding var counter: Int
    @EnvironmentObject private var eventBus: EventBus
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("计数器演示")
                .font(.headline)
            
            Text("当前值: \(counter)")
                .font(.title2)
                .fontWeight(.semibold)
            
            HStack(spacing: 12) {
                Button("增加") {
                    counter += 1
                    eventBus.publishPerformanceMetric(
                        name: "counter_value",
                        value: Double(counter),
                        unit: "count"
                    )
                }
                .buttonStyle(.borderedProminent)
                
                Button("减少") {
                    counter -= 1
                    eventBus.publishPerformanceMetric(
                        name: "counter_value",
                        value: Double(counter),
                        unit: "count"
                    )
                }
                .buttonStyle(.bordered)
                
                Button("重置") {
                    counter = 0
                    eventBus.publishPerformanceMetric(
                        name: "counter_reset",
                        value: 0,
                        unit: "count"
                    )
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color(red: 0.95, green: 0.95, blue: 0.97))
        .cornerRadius(12)
    }
}

// MARK: - 状态信息行
struct StateInfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

#Preview {
    StateManagementDemoView()
}
