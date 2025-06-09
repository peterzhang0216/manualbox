//
//  ViewModelProtocolTests.swift
//  ManualBoxTests
//
//  Created by Assistant on 2025/1/27.
//

import XCTest
import Combine
@testable import ManualBox

// MARK: - Test State and Actions
struct TestState: StateProtocol {
    var isLoading: Bool = false
    var errorMessage: String? = nil
    var counter: Int = 0
    var text: String = ""
}

enum TestAction: ActionProtocol {
    case increment
    case decrement
    case setText(String)
    case simulateError
    case simulateLoading
    case reset
}

// MARK: - Test ViewModel
@MainActor
class TestViewModel: BaseViewModel<TestState, TestAction> {
    override func handle(_ action: TestAction) async {
        switch action {
        case .increment:
            updateState { $0.counter += 1 }
            
        case .decrement:
            updateState { $0.counter -= 1 }
            
        case .setText(let text):
            updateState { $0.text = text }
            
        case .simulateError:
            setError("测试错误")
            
        case .simulateLoading:
            setLoading(true)
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
            setLoading(false)
            
        case .reset:
            updateState {
                $0.counter = 0
                $0.text = ""
                $0.isLoading = false
                $0.errorMessage = nil
            }
        }
    }
}

// MARK: - ViewModelProtocol Tests
class ViewModelProtocolTests: XCTestCase {
    var viewModel: TestViewModel!
    var cancellables: Set<AnyCancellable>!
    
    @MainActor
    override func setUp() {
        super.setUp()
        viewModel = TestViewModel(initialState: TestState())
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        cancellables = nil
        viewModel = nil
        super.tearDown()
    }
    
    // MARK: - Basic Functionality Tests
    
    @MainActor
    func testInitialState() {
        XCTAssertEqual(viewModel.state.counter, 0)
        XCTAssertEqual(viewModel.state.text, "")
        XCTAssertFalse(viewModel.state.isLoading)
        XCTAssertNil(viewModel.state.errorMessage)
    }
    
    @MainActor
    func testSendAction() async {
        viewModel.send(.increment)
        
        // 等待动作处理完成
        try? await Task.sleep(nanoseconds: 50_000_000) // 0.05秒
        
        XCTAssertEqual(viewModel.state.counter, 1)
    }
    
    @MainActor
    func testMultipleActions() async {
        viewModel.send(.increment)
        viewModel.send(.increment)
        viewModel.send(.decrement)
        
        // 等待所有动作处理完成
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
        
        XCTAssertEqual(viewModel.state.counter, 1)
    }
    
    @MainActor
    func testSetText() async {
        let testText = "Hello, World!"
        viewModel.send(.setText(testText))
        
        try? await Task.sleep(nanoseconds: 50_000_000)
        
        XCTAssertEqual(viewModel.state.text, testText)
    }
    
    // MARK: - Error Handling Tests
    
    @MainActor
    func testErrorHandling() async {
        viewModel.send(.simulateError)
        
        try? await Task.sleep(nanoseconds: 50_000_000)
        
        XCTAssertEqual(viewModel.state.errorMessage, "测试错误")
    }
    
    @MainActor
    func testSetErrorWithString() {
        viewModel.setError("自定义错误")
        XCTAssertEqual(viewModel.state.errorMessage, "自定义错误")
    }
    
    @MainActor
    func testSetErrorWithNSError() {
        let error = NSError(domain: "TestDomain", code: 123, userInfo: [NSLocalizedDescriptionKey: "NSError测试"])
        viewModel.setError(error)
        XCTAssertEqual(viewModel.state.errorMessage, "NSError测试")
    }
    
    // MARK: - Loading State Tests
    
    @MainActor
    func testLoadingState() async {
        viewModel.send(.simulateLoading)
        
        // 立即检查加载状态
        try? await Task.sleep(nanoseconds: 10_000_000) // 0.01秒
        XCTAssertTrue(viewModel.state.isLoading)
        
        // 等待加载完成
        try? await Task.sleep(nanoseconds: 150_000_000) // 0.15秒
        XCTAssertFalse(viewModel.state.isLoading)
    }
    
    @MainActor
    func testSetLoadingDirectly() {
        viewModel.setLoading(true)
        XCTAssertTrue(viewModel.state.isLoading)
        
        viewModel.setLoading(false)
        XCTAssertFalse(viewModel.state.isLoading)
    }
    
    // MARK: - State Update Tests
    
    @MainActor
    func testUpdateState() {
        viewModel.updateState { state in
            state.counter = 42
            state.text = "Updated"
        }
        
        XCTAssertEqual(viewModel.state.counter, 42)
        XCTAssertEqual(viewModel.state.text, "Updated")
    }
    
    // MARK: - Cleanup Tests
    
    @MainActor
    func testCleanup() {
        viewModel.cleanup()
        // 测试清理后ViewModel仍然可以正常工作
        viewModel.send(.increment)
    }
    
    // MARK: - Extension Tests
    
    @MainActor
    func testStateProtocolExtensions() {
        // 测试初始状态
        XCTAssertFalse(viewModel.state.hasError)
        XCTAssertTrue(viewModel.state.isIdle)
        
        // 设置错误状态
        viewModel.setError("测试错误")
        XCTAssertTrue(viewModel.state.hasError)
        XCTAssertFalse(viewModel.state.isIdle)
        
        // 设置加载状态
        viewModel.setError(nil as String?)
        viewModel.setLoading(true)
        XCTAssertFalse(viewModel.state.hasError)
        XCTAssertFalse(viewModel.state.isIdle)
    }
    
    @MainActor
    func testBaseStateFactoryMethods() {
        let errorState = BaseState.withError("工厂错误")
        XCTAssertEqual(errorState.errorMessage, "工厂错误")
        XCTAssertFalse(errorState.isLoading)
        
        let loadingState = BaseState.loading
        XCTAssertTrue(loadingState.isLoading)
        XCTAssertNil(loadingState.errorMessage)
        
        let successState = BaseState.success
        XCTAssertFalse(successState.isLoading)
        XCTAssertNil(successState.errorMessage)
    }
    
    @MainActor
    func testValidationHelpers() {
        // 测试非空验证
        XCTAssertFalse(viewModel.validateNonEmpty("", fieldName: "测试字段"))
        XCTAssertEqual(viewModel.state.errorMessage, "测试字段不能为空")
        
        viewModel.setError(nil as String?)
        XCTAssertTrue(viewModel.validateNonEmpty("有内容", fieldName: "测试字段"))
        XCTAssertNil(viewModel.state.errorMessage)
        
        // 测试长度验证
        XCTAssertFalse(viewModel.validateLength("短", fieldName: "测试字段", min: 3))
        XCTAssertEqual(viewModel.state.errorMessage, "测试字段至少需要3个字符")
        
        viewModel.setError(nil as String?)
        XCTAssertFalse(viewModel.validateLength("这是一个很长的字符串", fieldName: "测试字段", max: 5))
        XCTAssertEqual(viewModel.state.errorMessage, "测试字段不能超过5个字符")
        
        viewModel.setError(nil as String?)
        XCTAssertTrue(viewModel.validateLength("合适", fieldName: "测试字段", min: 1, max: 5))
        XCTAssertNil(viewModel.state.errorMessage)
    }
    
    @MainActor
    func testEmailValidation() {
        XCTAssertFalse(viewModel.validateEmail("无效邮箱"))
        XCTAssertEqual(viewModel.state.errorMessage, "邮箱格式不正确")
        
        viewModel.setError(nil as String?)
        XCTAssertTrue(viewModel.validateEmail("test@example.com"))
        XCTAssertNil(viewModel.state.errorMessage)
    }
    
    // MARK: - Async Task Tests
    
    @MainActor
    func testPerformTask() async {
        var taskExecuted = false
        
        await viewModel.performTask {
            taskExecuted = true
        }
        
        XCTAssertTrue(taskExecuted)
        XCTAssertFalse(viewModel.state.isLoading)
        XCTAssertNil(viewModel.state.errorMessage)
    }
    
    @MainActor
    func testPerformTaskWithError() async {
        struct TestError: Error {
            let message = "测试任务错误"
        }
        
        await viewModel.performTask {
            throw TestError()
        }
        
        XCTAssertFalse(viewModel.state.isLoading)
        XCTAssertNotNil(viewModel.state.errorMessage)
    }
    
    // MARK: - Binding Tests
    
    @MainActor
    func testBinding() {
        let counterBinding = viewModel.binding(
            get: { $0.counter },
            set: { .setText("\($0)") } // 这里只是为了测试，实际使用中应该有对应的action
        )
        
        XCTAssertEqual(counterBinding.wrappedValue, 0)
        
        // 测试设置值
        counterBinding.wrappedValue = 5
        
        // 等待动作处理
        let expectation = XCTestExpectation(description: "Binding update")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertEqual(viewModel.state.text, "5")
    }
    
    @MainActor
    func testReadOnlyBinding() {
        let readOnlyBinding = viewModel.readOnlyBinding { $0.counter }
        
        XCTAssertEqual(readOnlyBinding.wrappedValue, 0)
        
        // 设置值不应该有任何效果
        readOnlyBinding.wrappedValue = 10
        XCTAssertEqual(viewModel.state.counter, 0)
    }
}

// MARK: - ViewModelFactory Tests
class ViewModelFactoryTests: XCTestCase {
    var factory: DefaultViewModelFactory!
    var viewContext: NSManagedObjectContext!
    
    override func setUp() {
        super.setUp()
        factory = DefaultViewModelFactory()
        viewContext = PersistenceController.preview.container.viewContext
    }
    
    override func tearDown() {
        factory = nil
        viewContext = nil
        super.tearDown()
    }
    
    @MainActor
    func testMakeProductListViewModel() {
        let viewModel = factory.makeProductListViewModel(viewContext: viewContext)
        XCTAssertNotNil(viewModel)
        XCTAssertTrue(viewModel is ProductListViewModel)
    }
    
    @MainActor
    func testMakeAddProductViewModel() {
        let viewModel = factory.makeAddProductViewModel()
        XCTAssertNotNil(viewModel)
        XCTAssertTrue(viewModel is AddProductViewModel)
    }
    
    @MainActor
    func testMakeCategoriesViewModel() {
        let viewModel = factory.makeCategoriesViewModel(viewContext: viewContext)
        XCTAssertNotNil(viewModel)
        XCTAssertTrue(viewModel is CategoriesViewModel)
    }
    
    @MainActor
    func testMakeTagsViewModel() {
        let viewModel = factory.makeTagsViewModel(viewContext: viewContext)
        XCTAssertNotNil(viewModel)
        XCTAssertTrue(viewModel is TagsViewModel)
    }
    
    @MainActor
    func testMakeSettingsViewModel() {
        let viewModel = factory.makeSettingsViewModel(viewContext: viewContext)
        XCTAssertNotNil(viewModel)
        XCTAssertTrue(viewModel is SettingsViewModel)
    }
}