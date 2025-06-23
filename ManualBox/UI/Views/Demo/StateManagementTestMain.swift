//
//  StateManagementTestMain.swift
//  ManualBox
//
//  Created by Assistant on 2025/6/21.
//

import SwiftUI

// MARK: - 独立的状态管理测试应用
// @main // 注释掉以避免多个入口点冲突
struct StateManagementTestMain: App {
    @StateObject private var appStateManager = AppStateManager.shared
    @StateObject private var eventBus = EventBus.shared
    @StateObject private var stateMonitor = StateMonitor.shared
    
    init() {
        // 启动状态监控
        Task { @MainActor in
            StateMonitor.shared.startMonitoring()
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appStateManager)
                .environmentObject(eventBus)
                .environmentObject(stateMonitor)
                .onAppear {
                    // 初始化应用状态
                    appStateManager.setInitialized(true)
                    appStateManager.updateNetworkConnection(true)
                    
                    // 发布初始化完成事件
                    eventBus.publishNavigation(from: "启动", to: "主界面")
                    
                    print("✅ 状态管理测试应用启动完成")
                }
        }
        #if os(macOS)
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)
        #endif
    }
}

// MARK: - 主内容视图
struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            StateManagementDemoView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("状态演示")
                }
                .tag(0)
            
            DemoViewModelTestView()
                .tabItem {
                    Image(systemName: "square.and.pencil")
                    Text("ViewModel演示")
                }
                .tag(1)
            
            StateMonitorView()
                .tabItem {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                    Text("监控面板")
                }
                .tag(2)
        }
        #if os(macOS)
        .frame(minWidth: 800, minHeight: 600)
        #endif
    }
}

// MARK: - 简化的演示ViewModel
@MainActor
class SimpleDemoViewModel: BaseViewModel<SimpleDemoState, SimpleDemoAction>, EventSubscriber {
    let subscriberId = UUID()
    
    init() {
        super.init(initialState: SimpleDemoState())
        
        // 注册到状态监控器
        StateMonitor.shared.registerViewModel(self, name: "SimpleDemoViewModel")
        
        // 订阅事件
        setupEventSubscriptions()
    }
    
    override func handle(_ action: SimpleDemoAction) async {
        switch action {
        case .increment:
            updateState { $0.counter += 1 }
            EventBus.shared.publishPerformanceMetric(
                name: "demo_counter",
                value: Double(state.counter),
                unit: "count"
            )
            
        case .decrement:
            updateState { $0.counter -= 1 }
            EventBus.shared.publishPerformanceMetric(
                name: "demo_counter",
                value: Double(state.counter),
                unit: "count"
            )
            
        case .reset:
            updateState { $0.counter = 0 }
            EventBus.shared.publishPerformanceMetric(
                name: "demo_counter_reset",
                value: 0,
                unit: "count"
            )
            
        case .simulateError:
            let error = NSError(domain: "DemoError", code: 1001, userInfo: [
                NSLocalizedDescriptionKey: "这是一个演示错误"
            ])
            handleError(error, context: "SimpleDemoViewModel")
            
        case .simulateLoading:
            await performTask {
                try await Task.sleep(nanoseconds: 2_000_000_000) // 2秒
                self.updateState { $0.message = "加载完成！时间: \(Date().formatted(date: .omitted, time: .shortened))" }
            }
            
        case .updateMessage(let message):
            updateState { $0.message = message }
        }
    }
    
    // MARK: - EventSubscriber 实现
    func handleEvent<T: AppEvent>(_ event: T) {
        switch event {
        case let perfEvent as PerformanceEvent:
            if perfEvent.metricName == "memory_usage" && perfEvent.value > 100 {
                updateState { $0.message = "内存使用较高: \(String(format: "%.1f", perfEvent.value)) MB" }
            }
        case let errorEvent as ErrorEvent:
            updateState { $0.message = "收到错误事件: \(errorEvent.error.localizedDescription)" }
        default:
            break
        }
    }
    
    private func setupEventSubscriptions() {
        EventBus.shared.subscribe(to: PerformanceEvent.self, subscriber: self) { [weak self] event in
            self?.handleEvent(event)
        }
        
        EventBus.shared.subscribe(to: ErrorEvent.self, subscriber: self) { [weak self] event in
            self?.handleEvent(event)
        }
    }
}

// MARK: - 简化的演示状态
struct SimpleDemoState: StateProtocol {
    var isLoading: Bool = false
    var errorMessage: String? = nil
    
    var counter: Int = 0
    var message: String = "欢迎使用状态管理演示"
}

// MARK: - 简化的演示动作
enum SimpleDemoAction: ActionProtocol {
    case increment
    case decrement
    case reset
    case simulateError
    case simulateLoading
    case updateMessage(String)
}

// MARK: - 简化的演示视图
struct SimpleDemoView: View {
    @StateObject private var viewModel = SimpleDemoViewModel()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("ViewModel 演示")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text(viewModel.state.message)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(Color(red: 0.95, green: 0.95, blue: 0.97))
                    .cornerRadius(8)
                
                Text("计数器: \(viewModel.state.counter)")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                if viewModel.state.isLoading {
                    ProgressView("加载中...")
                        .padding()
                }
                
                if let errorMessage = viewModel.state.errorMessage {
                    Text("错误: \(errorMessage)")
                        .foregroundColor(.red)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                }
                
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Button("增加") {
                            viewModel.send(.increment)
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button("减少") {
                            viewModel.send(.decrement)
                        }
                        .buttonStyle(.bordered)
                        
                        Button("重置") {
                            viewModel.send(.reset)
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    HStack(spacing: 12) {
                        Button("模拟错误") {
                            viewModel.send(.simulateError)
                        }
                        .buttonStyle(.bordered)
                        
                        Button("模拟加载") {
                            viewModel.send(.simulateLoading)
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    Button("更新消息") {
                        viewModel.send(.updateMessage("消息已更新: \(Date().formatted(date: .omitted, time: .shortened))"))
                    }
                    .buttonStyle(.bordered)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("ViewModel 测试")
        }
        .onDisappear {
            viewModel.prepareForDeallocation()
        }
    }
}

// MARK: - 预览
#Preview("主界面") {
    ContentView()
        .environmentObject(AppStateManager.shared)
        .environmentObject(EventBus.shared)
        .environmentObject(StateMonitor.shared)
}

#Preview("简化演示") {
    SimpleDemoView()
        .environmentObject(AppStateManager.shared)
        .environmentObject(EventBus.shared)
        .environmentObject(StateMonitor.shared)
}
