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