# ManualBox 状态管理系统指南

## 概述

ManualBox 项目采用了现代化的状态管理架构，基于以下核心组件：

- **AppStateManager**: 统一的应用状态管理中心
- **EventBus**: 事件总线系统，用于组件间通信
- **StateMonitor**: 状态监控和诊断工具
- **ErrorHandling**: 统一的错误处理机制
- **BaseViewModel**: 基础ViewModel实现

## 核心组件

### 1. AppStateManager

统一管理应用的全局状态，包括：

```swift
// 使用示例
let appStateManager = AppStateManager.shared

// 更新选择状态
appStateManager.updateSelection(product)

// 更新同步状态
appStateManager.updateSyncStatus(.syncing, progress: 0.5)

// 处理错误
appStateManager.handleError(error, context: "数据保存")
```

**主要功能：**
- 产品选择状态管理
- 同步状态跟踪
- 错误状态管理
- 网络连接状态
- 性能指标收集

### 2. EventBus

提供类型安全的事件发布和订阅机制：

```swift
// 发布事件
EventBus.shared.publishProductSelection(product)
EventBus.shared.publishDataChange(entityType: "Product", changeType: .created)
EventBus.shared.publishError(error, context: "同步")

// 订阅事件
class MyViewModel: EventSubscriber {
    let subscriberId = UUID()
    
    init() {
        EventBus.shared.subscribe(to: ProductSelectionEvent.self, subscriber: self) { event in
            // 处理产品选择事件
        }
    }
    
    func handleEvent<T: AppEvent>(_ event: T) {
        // 处理事件
    }
}
```

**支持的事件类型：**
- ProductSelectionEvent: 产品选择事件
- DataChangeEvent: 数据变更事件
- SyncEvent: 同步事件
- ErrorEvent: 错误事件
- PerformanceEvent: 性能指标事件
- NavigationEvent: 导航事件

### 3. StateMonitor

实时监控应用状态和性能：

```swift
// 启动监控
StateMonitor.shared.startMonitoring()

// 注册ViewModel
StateMonitor.shared.registerViewModel(viewModel, name: "ProductListViewModel")

// 获取性能数据
let performance = StateMonitor.shared.currentPerformance
let history = StateMonitor.shared.performanceHistory
```

**监控内容：**
- 内存使用情况
- CPU使用率
- 磁盘使用量
- 活跃ViewModel数量
- 状态变化历史

### 4. 错误处理系统

统一的错误处理和用户友好的错误消息：

```swift
// 在ViewModel中处理错误
class MyViewModel: BaseViewModel<MyState, MyAction> {
    override func handle(_ action: MyAction) async {
        let result = await performTaskWithResult {
            // 执行可能失败的操作
            try await someOperation()
        }
        
        switch result {
        case .success(let data):
            // 处理成功结果
        case .failure(let error):
            // 错误已自动处理和记录
        }
    }
}
```

**错误处理特性：**
- 自动错误映射和本地化
- 错误日志记录
- 错误恢复策略
- 用户友好的错误消息

### 5. BaseViewModel

提供统一的ViewModel基础实现：

```swift
// 定义状态
struct MyState: StateProtocol {
    var isLoading: Bool = false
    var errorMessage: String? = nil
    var data: [Item] = []
}

// 定义动作
enum MyAction: ActionProtocol {
    case loadData
    case addItem(Item)
    case deleteItem(UUID)
}

// 实现ViewModel
class MyViewModel: BaseViewModel<MyState, MyAction> {
    init() {
        super.init(initialState: MyState())
        StateMonitor.shared.registerViewModel(self, name: "MyViewModel")
    }
    
    override func handle(_ action: MyAction) async {
        switch action {
        case .loadData:
            await loadData()
        case .addItem(let item):
            await addItem(item)
        case .deleteItem(let id):
            await deleteItem(id)
        }
    }
    
    private func loadData() async {
        await performTask {
            let data = try await dataService.fetchData()
            updateState { $0.data = data }
        }
    }
}
```

## 最佳实践

### 1. ViewModel设计

- 继承自`BaseViewModel`
- 使用`StateProtocol`定义状态
- 使用`ActionProtocol`定义动作
- 注册到`StateMonitor`进行监控

### 2. 错误处理

- 使用`performTask`或`performTaskWithResult`处理异步操作
- 通过`handleError`方法处理错误
- 提供用户友好的错误消息

### 3. 事件通信

- 使用`EventBus`进行组件间通信
- 实现`EventSubscriber`协议订阅事件
- 及时取消订阅避免内存泄漏

### 4. 状态监控

- 在开发和调试时启用`StateMonitor`
- 定期检查性能指标
- 使用状态历史进行问题诊断

### 5. 内存管理

- 在视图消失时调用`prepareForDeallocation()`
- 使用弱引用避免循环引用
- 及时清理订阅和任务

## 调试工具

### StateMonitorView

提供可视化的状态监控界面：

```swift
// 在调试时显示监控面板
.sheet(isPresented: $showDebug) {
    StateMonitorView()
}
```

### 演示应用

使用`StateManagementDemoView`测试状态管理功能：

```swift
// 运行演示
StateManagementDemoView()
    .environmentObject(AppStateManager.shared)
    .environmentObject(EventBus.shared)
    .environmentObject(StateMonitor.shared)
```

## 性能考虑

1. **状态更新频率**: 避免过于频繁的状态更新
2. **事件发布**: 合理控制事件发布频率
3. **监控开销**: 在生产环境中可选择性启用监控
4. **内存使用**: 定期清理历史数据和缓存

## 平台差异

### iOS vs macOS

- **内存管理**: iOS更保守的内存使用策略
- **性能监控**: 不同的监控频率和指标
- **通知处理**: 平台特定的生命周期事件
- **错误恢复**: 平台相关的恢复策略

## 扩展指南

### 添加新的事件类型

1. 定义事件结构体，实现`AppEvent`协议
2. 在`EventBus`中添加便利发布方法
3. 在相关组件中订阅和处理事件

### 添加新的状态监控指标

1. 在`PerformanceSnapshot`中添加新字段
2. 在`StateMonitor`中实现指标收集
3. 在监控界面中显示新指标

### 自定义错误处理

1. 在`ErrorMessageMapper`中添加错误映射
2. 实现特定的错误恢复策略
3. 添加用户友好的错误消息

## 总结

新的状态管理系统提供了：

- ✅ 统一的状态管理模式
- ✅ 类型安全的事件系统
- ✅ 实时性能监控
- ✅ 智能错误处理
- ✅ 平台适配支持
- ✅ 调试和诊断工具

这个系统大大提升了代码的可维护性、可测试性和用户体验。
