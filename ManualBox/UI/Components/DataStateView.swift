import SwiftUI

// MARK: - 数据状态枚举
enum DataState<T> {
    case idle
    case loading
    case loaded(T)
    case empty
    case error(Error)
    
    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }
    
    var data: T? {
        if case .loaded(let data) = self { return data }
        return nil
    }
    
    var error: Error? {
        if case .error(let error) = self { return error }
        return nil
    }
}

// MARK: - 数据状态视图配置
struct DataStateConfiguration {
    let loadingMessage: String
    let emptyTitle: String
    let emptyMessage: String
    let emptyIcon: String
    let errorTitle: String
    let retryButtonTitle: String
    let showRetryButton: Bool
    
    static let `default` = DataStateConfiguration(
        loadingMessage: "加载中...",
        emptyTitle: "暂无数据",
        emptyMessage: "还没有任何内容",
        emptyIcon: "tray",
        errorTitle: "加载失败",
        retryButtonTitle: "重试",
        showRetryButton: true
    )
}

// MARK: - 通用数据状态视图
struct DataStateView<Data, Content: View>: View {
    let state: DataState<Data>
    let configuration: DataStateConfiguration
    let onRetry: (() -> Void)?
    let content: (Data) -> Content
    
    init(
        state: DataState<Data>,
        configuration: DataStateConfiguration = .default,
        onRetry: (() -> Void)? = nil,
        @ViewBuilder content: @escaping (Data) -> Content
    ) {
        self.state = state
        self.configuration = configuration
        self.onRetry = onRetry
        self.content = content
    }
    
    var body: some View {
        Group {
            switch state {
            case .idle:
                EmptyView()
                
            case .loading:
                LoadingStateView(message: configuration.loadingMessage)
                
            case .loaded(let data):
                content(data)
                
            case .empty:
                EmptyStateView(configuration: configuration)
                
            case .error(let error):
                ErrorStateView(
                    error: error,
                    configuration: configuration,
                    onRetry: onRetry
                )
            }
        }
    }
}

// MARK: - 加载状态视图
struct LoadingStateView: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text(message)
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
    }
}

// MARK: - 空状态视图
struct EmptyStateView: View {
    let configuration: DataStateConfiguration
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: configuration.emptyIcon)
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text(configuration.emptyTitle)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(configuration.emptyMessage)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 32)
    }
}

// MARK: - 错误状态视图
struct ErrorStateView: View {
    let error: Error
    let configuration: DataStateConfiguration
    let onRetry: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.red)
            
            VStack(spacing: 8) {
                Text(configuration.errorTitle)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(error.localizedDescription)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            if configuration.showRetryButton, let onRetry = onRetry {
                Button(action: onRetry) {
                    Label(configuration.retryButtonTitle, systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 32)
    }
}

// MARK: - 数据状态管理器
@MainActor
class DataStateManager<T>: ObservableObject {
    @Published var state: DataState<T> = .idle
    
    func setLoading() {
        state = .loading
    }
    
    func setLoaded(_ data: T) {
        state = .loaded(data)
    }
    
    func setEmpty() {
        state = .empty
    }
    
    func setError(_ error: Error) {
        state = .error(error)
    }
    
    func reset() {
        state = .idle
    }
    
    // 便捷方法：从数组数据设置状态
    func setArrayData<U>(_ data: [U]) where T == [U] {
        if data.isEmpty {
            state = .empty
        } else {
            state = .loaded(data as! T)
        }
    }

    // 便捷方法：从可选数据设置状态
    func setOptionalData<U>(_ data: U?) where T == Optional<U> {
        if let data = data {
            state = .loaded(data as! T)
        } else {
            state = .empty
        }
    }
}

// MARK: - 异步数据加载视图
struct AsyncDataView<Data, Content: View>: View {
    @StateObject private var stateManager = DataStateManager<Data>()
    
    let loadData: () async throws -> Data
    let configuration: DataStateConfiguration
    let content: (Data) -> Content
    
    init(
        configuration: DataStateConfiguration = .default,
        loadData: @escaping () async throws -> Data,
        @ViewBuilder content: @escaping (Data) -> Content
    ) {
        self.loadData = loadData
        self.configuration = configuration
        self.content = content
    }
    
    var body: some View {
        DataStateView(
            state: stateManager.state,
            configuration: configuration,
            onRetry: {
                Task {
                    await loadDataAsync()
                }
            },
            content: content
        )
        .task {
            await loadDataAsync()
        }
    }
    
    private func loadDataAsync() async {
        stateManager.setLoading()
        
        do {
            let data = try await loadData()
            stateManager.setLoaded(data)
        } catch {
            stateManager.setError(error)
        }
    }
}

// MARK: - 便捷扩展
extension View {
    func dataState<T>(
        _ state: DataState<T>,
        configuration: DataStateConfiguration = .default,
        onRetry: (() -> Void)? = nil
    ) -> some View where Self == DataStateView<T, AnyView> {
        DataStateView(
            state: state,
            configuration: configuration,
            onRetry: onRetry
        ) { _ in
            AnyView(self)
        }
    }
}
