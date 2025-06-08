import SwiftUI
import PhotosUI
import CoreData
import Combine
import Vision

// MARK: - AddProduct State
struct AddProductState: StateProtocol {
    var isLoading: Bool = false
    var errorMessage: String? = nil
    
    // 产品基本信息
    var name = ""
    var brand = ""
    var model = ""
    var selectedCategory: Category?
    var selectedTags: Set<Tag> = []
    var selectedImage: PhotosPickerItem?
    var productImage: PlatformImage?
    
    // 订单信息
    var orderNumber = ""
    var platform = ""
    var orderDate = Date()
    var warrantyPeriod = 12
    var invoiceImage: PhotosPickerItem?
    var invoiceImageData: Data?
    
    // 说明书信息
    var selectedManuals: [PhotosPickerItem] = []
    var performOCR = true
    
    // 保存状态
    var isSaving = false
    var saveError: String?
}

// MARK: - AddProduct Actions
enum AddProductAction: ActionProtocol {
    case updateName(String)
    case updateBrand(String)
    case updateModel(String)
    case selectCategory(Category?)
    case toggleTag(Tag)
    case selectImage(PhotosPickerItem?)
    case updateOrderNumber(String)
    case updatePlatform(String)
    case updateOrderDate(Date)
    case updateWarrantyPeriod(Int)
    case selectInvoiceImage(PhotosPickerItem?)
    case updateSelectedManuals([PhotosPickerItem])
    case toggleOCR
    case startSaving
    case finishSaving(Result<Void, Error>)
    case loadImage(PhotosPickerItem?)
}

@MainActor
final class AddProductViewModel: BaseViewModel<AddProductState, AddProductAction> {
    // 为了保持向后兼容，保留Published属性
    @Published var name = ""
    @Published var brand = ""
    @Published var model = ""
    @Published var selectedCategory: Category?
    @Published var selectedTags: Set<Tag> = []
    @Published var selectedImage: PhotosPickerItem?
    @Published var productImage: PlatformImage?
    @Published var orderNumber = ""
    @Published var platform = ""
    @Published var orderDate = Date()
    @Published var warrantyPeriod = 12
    @Published var invoiceImage: PhotosPickerItem?
    @Published var invoiceImageData: Data?
    @Published var selectedManuals: [PhotosPickerItem] = []
    @Published var performOCR = true
    @Published var isSaving = false
    @Published var saveError: String?
    
    // 取消订阅存储
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        super.init(initialState: AddProductState())
    }
    
    // MARK: - Action Handler
    override func handle(_ action: AddProductAction) async {
        switch action {
        case .updateName(let newName):
            name = newName
            updateState { $0.name = newName }
            
        case .updateBrand(let newBrand):
            brand = newBrand
            updateState { $0.brand = newBrand }
            
        case .updateModel(let newModel):
            model = newModel
            updateState { $0.model = newModel }
            
        case .selectCategory(let category):
            selectedCategory = category
            updateState { $0.selectedCategory = category }
            
        case .toggleTag(let tag):
            if selectedTags.contains(tag) {
                selectedTags.remove(tag)
            } else {
                selectedTags.insert(tag)
            }
            updateState { 
                if $0.selectedTags.contains(tag) {
                    $0.selectedTags.remove(tag)
                } else {
                    $0.selectedTags.insert(tag)
                }
            }
            
        case .selectImage(let image):
            selectedImage = image
            updateState { $0.selectedImage = image }
            
        case .updateOrderNumber(let number):
            orderNumber = number
            updateState { $0.orderNumber = number }
            
        case .updatePlatform(let newPlatform):
            platform = newPlatform
            updateState { $0.platform = newPlatform }
            
        case .updateOrderDate(let date):
            orderDate = date
            updateState { $0.orderDate = date }
            
        case .updateWarrantyPeriod(let period):
            warrantyPeriod = period
            updateState { $0.warrantyPeriod = period }
            
        case .selectInvoiceImage(let image):
            invoiceImage = image
            updateState { $0.invoiceImage = image }
            
        case .updateSelectedManuals(let manuals):
            selectedManuals = manuals
            updateState { $0.selectedManuals = manuals }
            
        case .toggleOCR:
            performOCR.toggle()
            updateState { $0.performOCR.toggle() }
            
        case .startSaving:
            isSaving = true
            saveError = nil
            updateState { 
                $0.isSaving = true
                $0.saveError = nil
            }
            
        case .finishSaving(let result):
            isSaving = false
            switch result {
            case .success:
                saveError = nil
            case .failure(let error):
                saveError = error.localizedDescription
            }
            updateState {
                $0.isSaving = false
                switch result {
                case .success:
                    $0.saveError = nil
                case .failure(let error):
                    $0.saveError = error.localizedDescription
                }
            }
            
        case .loadImage(let item):
            await loadImageFromItem(item)
        }
    }
    
    // MARK: - 业务方法
    
    func toggleTag(_ tag: Tag) {
        send(.toggleTag(tag))
    }
    
    func loadImage(from item: PhotosPickerItem?) {
        send(.loadImage(item))
    }
    
    private func loadImageFromItem(_ item: PhotosPickerItem?) async {
        guard let item = item else { return }
        
        do {
            if let data = try await item.loadTransferable(type: Data.self) {
                #if os(macOS)
                if let image = NSImage(data: data) {
                    await MainActor.run {
                        self.productImage = image
                        self.updateState { $0.productImage = image }
                    }
                }
                #else
                if let image = UIImage(data: data) {
                    await MainActor.run {
                        self.productImage = image
                        self.updateState { $0.productImage = image }
                    }
                }
                #endif
            }
        } catch {
            await MainActor.run {
                self.saveError = "加载图片失败: \(error.localizedDescription)"
                self.updateState { $0.saveError = "加载图片失败: \(error.localizedDescription)" }
            }
        }
    }

    func loadInvoiceImage() async -> Data? {
        guard let invoiceImage = invoiceImage else { return nil }
        
        if let data = try? await invoiceImage.loadTransferable(type: Data.self) {
            await MainActor.run {
                self.invoiceImageData = data
            }
            return data
        }
        
        return nil
    }
    
    // 改进的异步保存方法
    func saveProduct(in context: NSManagedObjectContext) async -> Bool {
        // 标记正在保存
        self.isSaving = true
        self.saveError = nil
        
        do {
            // 创建一个任务组来等待所有异步操作完成
            let product = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Product, Error>) in
                // 在CoreData上下文中操作
                context.perform {
                    // 1. 创建产品
                    let product = Product.createProduct(
                        in: context,
                        name: self.name,
                        brand: self.brand,
                        model: self.model,
                        category: self.selectedCategory,
                        image: self.productImage
                    )
                    
                    // 2. 添加标签
                    for tag in self.selectedTags {
                        product.addTag(tag)
                    }
                    
                    continuation.resume(returning: product)
                }
            }
            
            // 3. 加载发票图片（如果有）
            let invoiceImageData = await loadInvoiceImage()
            
            // 4. 创建订单（如果有订单信息）
            if !orderNumber.isEmpty || !platform.isEmpty {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    context.perform {
                        let order = Order.createOrder(
                            in: context,
                            orderNumber: self.orderNumber,
                            platform: self.platform,
                            orderDate: self.orderDate,
                            warrantyPeriod: self.warrantyPeriod,
                            invoiceImage: nil,
                            product: product
                        )
                        
                        // 处理发票图片
                        if let imageData = invoiceImageData {
                            order.updateInvoiceImage(PlatformImage(data: imageData))
                        }
                        
                        continuation.resume()
                    }
                }
            }
            
            // 5. 处理说明书文件
            if !selectedManuals.isEmpty {
                await withTaskGroup(of: Void.self) { group in
                    for manualItem in selectedManuals {
                        group.addTask {
                            if let data = try? await manualItem.loadTransferable(type: Data.self) {
                                await MainActor.run {
                                    context.perform {
                                        let fileName = manualItem.itemIdentifier ?? "未命名文件"
                                        let fileType = (fileName as NSString).pathExtension.lowercased()
                                        
                                        let manual = Manual.createManual(
                                            in: context,
                                            fileName: fileName,
                                            fileData: data,
                                            fileType: fileType,
                                            product: product
                                        )
                                        
                                        // 如果需要OCR且是图片或PDF，标记为待处理
                                        if self.performOCR {
                                            manual.isOCRPending = true
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            // 6. 最终保存上下文
            try await context.perform {
                if context.hasChanges {
                    try context.save()
                }
            }
            
            // 7. 成功后的OCR处理（不阻塞保存流程）
            if self.performOCR {
                Task {
                    // 获取刚保存的产品的说明书
                    let request: NSFetchRequest<Manual> = Manual.fetchRequest()
                    request.predicate = NSPredicate(format: "product.id == %@ AND isOCRPending == YES", product.id! as CVarArg)
                    
                    let manuals = try? context.fetch(request)
                    for manual in manuals ?? [] {
                        manual.performOCR { _ in }
                    }
                }
            }
            
            // 8. 保存成功
            self.isSaving = false
            return true
            
        } catch {
            // 保存失败，更新错误状态
            self.isSaving = false
            self.saveError = error.localizedDescription
            print("保存产品失败: \(error.localizedDescription)")
            return false
        }
    }
}
