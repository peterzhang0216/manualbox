import Foundation
import Combine
import SwiftUI
import CoreData

// MARK: - 基础视图模型协议
@MainActor
protocol ViewModelProtocol: ObservableObject {
    associatedtype State
    associatedtype Action
    
    var state: State { get }
    func send(_ action: Action)
    func cleanup()
}

// MARK: - 基础状态协议
protocol StateProtocol {
    var isLoading: Bool { get set }
    var errorMessage: String? { get set }
}

// MARK: - 基础动作协议
protocol ActionProtocol {}

// MARK: - 默认基础状态实现
struct BaseState: StateProtocol {
    var isLoading: Bool = false
    var errorMessage: String? = nil
}

// MARK: - 基础视图模型实现
@MainActor
class BaseViewModel<State: StateProtocol, Action: ActionProtocol>: ViewModelProtocol {
    @Published var state: State
    private var cancellables = Set<AnyCancellable>()
    private var tasks = Set<Task<Void, Never>>()
    
    init(initialState: State) {
        self.state = initialState
    }
    
    func send(_ action: Action) {
        let task = Task { [weak self] in
            await self?.handle(action)
            return ()
        }
        tasks.insert(task)
    }
    
    // 子类需要重写此方法来处理具体的动作
    func handle(_ action: Action) async {
        fatalError("子类必须实现 handle(_:) 方法")
    }
    
    func cleanup() {
        // 取消所有正在执行的任务
        for task in tasks {
            task.cancel()
        }
        tasks.removeAll()
        
        // 清理所有订阅
        cancellables.removeAll()
    }
    
    // 准备销毁时的清理方法
    func prepareForDeallocation() {
        cleanup()
    }

    deinit {
        // 在 Swift 6 中，避免在 deinit 中使用 Task 捕获 self
        // cleanup() 不能在 deinit 中调用，因为它是 MainActor 隔离的
        // 依赖于 ARC 自动清理 cancellables 和 tasks
    }
    
    // MARK: - 便利方法
    func updateState(_ update: @escaping (inout State) -> Void) {
        var newState = state
        update(&newState)
        state = newState

        // 记录状态变化到监控器
        StateMonitor.shared.recordStateChange(newState, viewModel: String(describing: type(of: self)))
    }

    func setLoading(_ isLoading: Bool) {
        updateState { state in
            state.isLoading = isLoading
        }
    }

    func setError(_ error: Error?) {
        updateState { state in
            state.errorMessage = error?.localizedDescription
        }
    }

    func setError(_ errorMessage: String?) {
        updateState { state in
            state.errorMessage = errorMessage
        }
    }

    // MARK: - 任务管理增强
    func performTask<T>(_ task: @escaping () async throws -> T) async -> T? {
        setLoading(true)
        defer { setLoading(false) }

        do {
            let result = try await task()
            setError(nil as String?)
            return result
        } catch {
            handleError(error, context: String(describing: type(of: self)))
            return nil
        }
    }

    func performTaskWithResult<T>(_ task: @escaping () async throws -> T) async -> Result<T, Error> {
        setLoading(true)
        defer { setLoading(false) }

        do {
            let result = try await task()
            setError(nil as String?)
            return .success(result)
        } catch {
            handleError(error, context: String(describing: type(of: self)))
            return .failure(error)
        }
    }
    
    // MARK: - 异步任务管理
    func performTask(_ operation: @escaping () async throws -> Void) async {
        setLoading(true)
        setError(nil as String?)
        
        do {
            try await operation()
        } catch {
            setError(error)
        }
        
        setLoading(false)
    }
    
    // MARK: - 订阅管理
    func addSubscription<P: Publisher>(
        _ publisher: P,
        receiveCompletion: @escaping ((Subscribers.Completion<P.Failure>) -> Void) = { _ in },
        receiveValue: @escaping ((P.Output) -> Void)
    ) {
        publisher
            .sink(receiveCompletion: receiveCompletion, receiveValue: receiveValue)
            .store(in: &cancellables)
    }
    
    // MARK: - 任务完成处理
    func taskCompleted(_ task: Task<Void, Never>) {
        tasks.remove(task)
    }
}