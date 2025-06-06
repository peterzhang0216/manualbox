import SwiftUI
import PhotosUI
import CoreData
import Combine

@MainActor
final class AddProductViewModel: ObservableObject {
    // 产品基本信息
    @Published var name = ""
    @Published var brand = ""
    @Published var model = ""
    @Published var selectedCategory: Category?
    @Published var selectedTags: Set<Tag> = []
    @Published var selectedImage: PhotosPickerItem?
    @Published var productImage: PlatformImage?
    
    // 订单信息
    @Published var orderNumber = ""
    @Published var platform = ""
    @Published var orderDate = Date()
    @Published var warrantyPeriod = 12
    @Published var invoiceImage: PhotosPickerItem?
    @Published var invoiceImageData: Data?
    
    // 说明书信息
    @Published var selectedManuals: [PhotosPickerItem] = []
    @Published var performOCR = true
    
    // 保存状态
    @Published var isSaving = false
    @Published var saveError: String?
    
    // 取消订阅存储
    private var cancellables = Set<AnyCancellable>()
    
    func toggleTag(_ tag: Tag) {
        if selectedTags.contains(tag) {
            selectedTags.remove(tag)
        } else {
            selectedTags.insert(tag)
        }
    }
    
    func loadImage(from item: PhotosPickerItem?) {
        guard let item = item else { return }
        
        Task { 
            if let data = try? await item.loadTransferable(type: Data.self) {
                // 使用 MainActor.run 确保在主线程上更新 UI
                await MainActor.run {
                    self.productImage = PlatformImage(data: data)
                }
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