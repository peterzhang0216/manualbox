import Foundation
import Combine
import SwiftUI

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
    var isLoading: Bool { get }
    var errorMessage: String? { get }
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
    
    init(initialState: State) {
        self.state = initialState
    }
    
    func send(_ action: Action) {
        Task {
            await handle(action)
        }
    }
    
    // 子类需要重写此方法来处理具体的动作
    func handle(_ action: Action) async {
        fatalError("子类必须实现 handle(_:) 方法")
    }
    
    func cleanup() {
        cancellables.removeAll()
    }
    
    deinit {
        // 在 Swift 6 中，避免在 deinit 中使用 Task 捕获 self
        cancellables.removeAll()
    }
    
    // MARK: - 便利方法
    func updateState(_ update: @escaping (inout State) -> Void) {
        var newState = state
        update(&newState)
        state = newState
    }
    
    func setLoading(_ isLoading: Bool) {
        updateState { state in
            if var mutableState = state as? BaseState {
                mutableState.isLoading = isLoading
                state = mutableState as! State
            }
        }
    }
    
    func setError(_ error: Error?) {
        updateState { state in
            if var mutableState = state as? BaseState {
                mutableState.errorMessage = error?.localizedDescription
                state = mutableState as! State
            }
        }
    }
}

// MARK: - 视图模型工厂协议
protocol ViewModelFactory {
    func makeProductListViewModel() -> any ViewModelProtocol
    func makeAddProductViewModel() -> any ViewModelProtocol
    func makeCategoryViewModel() -> any ViewModelProtocol
    func makeTagViewModel() -> any ViewModelProtocol
    func makeSettingsViewModel() -> any ViewModelProtocol
}