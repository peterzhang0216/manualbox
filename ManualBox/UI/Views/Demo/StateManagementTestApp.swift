//
//  StateManagementTestApp.swift
//  ManualBox
//
//  Created by Assistant on 2025/6/21.
//

import SwiftUI

// MARK: - 状态管理测试应用
struct StateManagementTestApp: App {
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
            StateManagementDemoView()
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
    }
}

// MARK: - 简化的演示ViewModel
@MainActor
class DemoViewModel: BaseViewModel<DemoState, DemoAction>, EventSubscriber {
    let subscriberId = UUID()
    
    init() {
        super.init(initialState: DemoState())
        
        // 注册到状态监控器
        StateMonitor.shared.registerViewModel(self, name: "DemoViewModel")
        
        // 订阅事件
        setupEventSubscriptions()
    }
    
    override func handle(_ action: DemoAction) async {
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
            handleError(error, context: "DemoViewModel")
            
        case .simulateLoading:
            await performTask {
                try await Task.sleep(nanoseconds: 2_000_000_000) // 2秒
                self.updateState { $0.message = "加载完成！" }
            }
        }
    }
    
    // MARK: - EventSubscriber 实现
    func handleEvent<T: AppEvent>(_ event: T) {
        switch event {
        case let perfEvent as PerformanceEvent:
            if perfEvent.metricName == "memory_usage" && perfEvent.value > 100 {
                updateState { $0.message = "内存使用较高: \(perfEvent.value) MB" }
            }
        default:
            break
        }
    }
    
    private func setupEventSubscriptions() {
        EventBus.shared.subscribe(to: PerformanceEvent.self, subscriber: self) { [weak self] event in
            self?.handleEvent(event)
        }
    }
}

// MARK: - 演示状态
struct DemoState: StateProtocol {
    var isLoading: Bool = false
    var errorMessage: String? = nil
    
    var counter: Int = 0
    var message: String = "欢迎使用状态管理演示"
}

// MARK: - 演示动作
enum DemoAction: ActionProtocol {
    case increment
    case decrement
    case reset
    case simulateError
    case simulateLoading
}

// MARK: - 演示视图
struct DemoViewModelTestView: View {
    @StateObject private var viewModel = DemoViewModel()
    
    var body: some View {
        VStack(spacing: 20) {
            Text("ViewModel 演示")
                .font(.title)
                .fontWeight(.bold)
            
            Text(viewModel.state.message)
                .font(.body)
                .multilineTextAlignment(.center)
                .padding()
            
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
            }
            
            Spacer()
        }
        .padding()
        .onDisappear {
            viewModel.prepareForDeallocation()
        }
    }
}

// MARK: - 预览
#Preview("状态管理演示") {
    StateManagementDemoView()
        .environmentObject(AppStateManager.shared)
        .environmentObject(EventBus.shared)
        .environmentObject(StateMonitor.shared)
}

#Preview("ViewModel演示") {
    DemoViewModelTestView()
        .environmentObject(AppStateManager.shared)
        .environmentObject(EventBus.shared)
        .environmentObject(StateMonitor.shared)
}
