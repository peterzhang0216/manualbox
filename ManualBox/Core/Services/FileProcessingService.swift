import Foundation
import UniformTypeIdentifiers
import PDFKit
import ImageIO
import CoreImage
import SwiftUI

// MARK: - 文件处理服务 (重构后使用组件架构)
@MainActor
class FileProcessingService: ObservableObject {
    static let shared = FileProcessingService()

    @Published var isProcessing = false
    @Published var processingProgress: Float = 0.0
    @Published var processingQueue: [FileProcessingTask] = []

    // 使用新的组件架构
    private let fileProcessor: FileProcessor

    private init() {
        self.fileProcessor = FileProcessor()

        // 绑定处理器的状态到服务
        setupStateBinding()
    }

    // MARK: - 主要处理方法 (重构后使用组件架构)
    func processFile(
        from url: URL,
        for product: Product? = nil,
        options: FileProcessingOptions = .default
    ) async throws -> FileProcessingResult {

        return try await fileProcessor.processFile(
            from: url,
            for: product,
            options: options
        )
    }

    // MARK: - 批量处理
    func processBatchFiles(
        urls: [URL],
        for product: Product? = nil,
        options: FileProcessingOptions = .default,
        progressCallback: @escaping (Int, Int) -> Void
    ) async throws -> [URL: Result<FileProcessingResult, Error>] {

        return try await fileProcessor.processBatchFiles(
            urls: urls,
            for: product,
            options: options,
            progressCallback: progressCallback
        )
    }

    // MARK: - 状态管理
    func cancelProcessing(for taskId: UUID) {
        fileProcessor.cancelProcessing(for: taskId)
    }

    func cancelAllProcessing() {
        fileProcessor.cancelAllProcessing()
    }

    // MARK: - 私有方法

    private func setupStateBinding() {
        // 这里可以设置状态绑定，但由于都是@MainActor，直接访问即可
        // 如果需要更复杂的状态同步，可以使用Combine
    }
} 