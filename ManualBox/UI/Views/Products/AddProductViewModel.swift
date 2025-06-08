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
    case updateSelectedCategory(Category?)
    case selectCategory(Category?)
    case toggleTag(Tag)
    case updateSelectedImage(PhotosPickerItem?)
    case selectImage(PhotosPickerItem?)
    case updateOrderNumber(String)
    case updatePlatform(String)
    case updateOrderDate(Date)
    case updateWarrantyPeriod(Int)
    case updateInvoiceImage(PhotosPickerItem?)
    case selectInvoiceImage(PhotosPickerItem?)
    case updateSelectedManuals([PhotosPickerItem])
    case updatePerformOCR(Bool)
    case toggleOCR
    case startSaving
    case finishSaving(Result<Void, Error>)
    case loadImage(PhotosPickerItem?)
}

@MainActor
final class AddProductViewModel: BaseViewModel<AddProductState, AddProductAction> {
    // 便利属性，直接从state获取
    var name: String { state.name }
    var brand: String { state.brand }
    var model: String { state.model }
    var selectedCategory: Category? { state.selectedCategory }
    var selectedTags: Set<Tag> { state.selectedTags }
    var selectedImage: PhotosPickerItem? { state.selectedImage }
    var productImage: PlatformImage? { state.productImage }
    var orderNumber: String { state.orderNumber }
    var platform: String { state.platform }
    var orderDate: Date { state.orderDate }
    var warrantyPeriod: Int { state.warrantyPeriod }
    var invoiceImage: PhotosPickerItem? { state.invoiceImage }
    var invoiceImageData: Data? { state.invoiceImageData }
    var selectedManuals: [PhotosPickerItem] { state.selectedManuals }
    var performOCR: Bool { state.performOCR }
    var isSaving: Bool { state.isSaving }
    var saveError: String? { state.saveError }
    
    override init(initialState: AddProductState) {
        super.init(initialState: initialState)
    }
    
    convenience init() {
        self.init(initialState: AddProductState())
    }
    
    // MARK: - Action Handler
    override func handle(_ action: AddProductAction) async {
        switch action {
        case .updateName(let newName):
            updateState { $0.name = newName }
            
        case .updateBrand(let newBrand):
            updateState { $0.brand = newBrand }
            
        case .updateModel(let newModel):
            updateState { $0.model = newModel }
            
        case .updateSelectedCategory(let category):
            updateState { $0.selectedCategory = category }
            
        case .selectCategory(let category):
            updateState { $0.selectedCategory = category }
            
        case .toggleTag(let tag):
            updateState { 
                if $0.selectedTags.contains(tag) {
                    $0.selectedTags.remove(tag)
                } else {
                    $0.selectedTags.insert(tag)
                }
            }
            
        case .updateSelectedImage(let image):
            updateState { $0.selectedImage = image }
            
        case .selectImage(let image):
            updateState { $0.selectedImage = image }
            
        case .updateOrderNumber(let number):
            updateState { $0.orderNumber = number }
            
        case .updatePlatform(let newPlatform):
            updateState { $0.platform = newPlatform }
            
        case .updateOrderDate(let date):
            updateState { $0.orderDate = date }
            
        case .updateWarrantyPeriod(let period):
            updateState { $0.warrantyPeriod = period }
            
        case .updateInvoiceImage(let image):
            updateState { $0.invoiceImage = image }
            
        case .selectInvoiceImage(let image):
            updateState { $0.invoiceImage = image }
            
        case .updateSelectedManuals(let manuals):
            updateState { $0.selectedManuals = manuals }
            
        case .updatePerformOCR(let perform):
            updateState { $0.performOCR = perform }
            
        case .toggleOCR:
            updateState { $0.performOCR.toggle() }
            
        case .startSaving:
            updateState { 
                $0.isSaving = true
                $0.saveError = nil
            }
            
        case .finishSaving(let result):
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
        send(AddProductAction.toggleTag(tag))
    }
    
    func loadImage(from item: PhotosPickerItem?) {
        send(AddProductAction.loadImage(item))
    }
    
    private func loadImageFromItem(_ item: PhotosPickerItem?) async {
        guard let item = item else { return }
        
        do {
            if let data = try await item.loadTransferable(type: Data.self) {
                #if os(macOS)
                if let image = NSImage(data: data) {
                    await MainActor.run {
                        self.updateState { $0.productImage = image }
                    }
                }
                #else
                if let image = UIImage(data: data) {
                    await MainActor.run {
                        self.updateState { $0.productImage = image }
                    }
                }
                #endif
            }
        } catch {
            await MainActor.run {
                self.updateState { $0.saveError = "加载图片失败: \(error.localizedDescription)" }
            }
        }
    }

    func loadInvoiceImage() async -> Data? {
        guard let invoiceImage = invoiceImage else { return nil }
        
        if let data = try? await invoiceImage.loadTransferable(type: Data.self) {
            await MainActor.run {
                self.updateState { $0.invoiceImageData = data }
            }
            return data
        }
        
        return nil
    }
    
    // 改进的异步保存方法
    func saveProduct(in context: NSManagedObjectContext) async -> Bool {
        // 标记正在保存
        send(AddProductAction.startSaving)
        
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
            send(AddProductAction.finishSaving(Result<Void, Error>.success(())))
            return true
            
        } catch {
            // 保存失败，更新错误状态
            send(AddProductAction.finishSaving(Result<Void, Error>.failure(error)))
            print("保存产品失败: \(error.localizedDescription)")
            return false
        }
    }
}
