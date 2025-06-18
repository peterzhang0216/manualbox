import Foundation
import ManualBox

// MARK: - 文件处理任务
struct FileProcessingTask: Identifiable {
    let id = UUID()
    let fileURL: URL
    let targetProduct: Product?
    let processingOptions: FileProcessingOptions
    let createdAt = Date()
    
    init(
        fileURL: URL,
        targetProduct: Product? = nil,
        processingOptions: FileProcessingOptions = .default
    ) {
        self.fileURL = fileURL
        self.targetProduct = targetProduct
        self.processingOptions = processingOptions
    }
} 