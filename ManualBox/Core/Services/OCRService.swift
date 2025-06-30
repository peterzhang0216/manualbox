import Foundation
@preconcurrency import Vision
@preconcurrency import CoreData
#if os(macOS)
@preconcurrency import AppKit
#endif
import PDFKit
import SwiftUI
import NaturalLanguage

// MARK: - OCR协调器服务 (重构后的主服务)
@MainActor
class OCRService: ObservableObject {
    static let shared = OCRService()

    @Published var isProcessing = false
    @Published var currentProgress: Float = 0.0
    @Published var processingQueue: [UUID] = []
    @Published var batchProgress: BatchProgress?
    @Published var lastError: OCRError?
    @Published var processingStats: OCRProcessingStats = OCRProcessingStats()

    // 拆分后的专门组件
    private let coordinator: OCRCoordinator
    private let imageProcessor: OCRImageProcessor
    private let textProcessor: OCRTextProcessor
    private let performanceMonitor: OCRPerformanceMonitor

    private let maxConcurrentRequests = 3

    private init() {
        self.coordinator = OCRCoordinator()
        self.imageProcessor = OCRImageProcessor()
        self.textProcessor = OCRTextProcessor()
        self.performanceMonitor = OCRPerformanceMonitor()

        setupPerformanceMonitoring()
    }

    // MARK: - 主要OCR方法 (重构后使用组件架构)
    func performOCR(
        on manual: Manual,
        configuration: OCRConfiguration = .default,
        completion: @escaping (Result<OCRResult, OCRError>) -> Void
    ) {
        // 检查队列容量
        guard processingQueue.count < maxConcurrentRequests else {
            lastError = .queueFull
            Task {
                await performanceMonitor.recordError(.queueFull, context: "队列已满")
            }
            completion(.failure(.queueFull))
            return
        }

        let requestId = UUID()
        processingQueue.append(requestId)
        isProcessing = true

        Task {
            do {
                let result = try await coordinator.coordinateOCR(
                    on: manual,
                    configuration: configuration,
                    imageProcessor: imageProcessor,
                    textProcessor: textProcessor,
                    performanceMonitor: performanceMonitor
                ) { [weak self] progress in
                    Task { @MainActor in
                        self?.currentProgress = progress
                        configuration.progressCallback?(progress)
                    }
                }

                await MainActor.run {
                    self.processingQueue.removeAll { $0 == requestId }
                    self.isProcessing = self.processingQueue.isEmpty ? false : true
                    self.currentProgress = 0.0
                }

                completion(.success(result))

            } catch {
                let ocrError = error as? OCRError ?? .processingFailed(error.localizedDescription)

                await MainActor.run {
                    self.lastError = ocrError
                    self.processingQueue.removeAll { $0 == requestId }
                    self.isProcessing = self.processingQueue.isEmpty ? false : true
                    self.currentProgress = 0.0
                }

                await performanceMonitor.recordError(ocrError, context: "单个OCR处理")
                completion(.failure(ocrError))
            }
        }

    }

    // MARK: - 批量OCR处理
    func performBatchOCR(
        on manuals: [Manual],
        configuration: OCRConfiguration = .default,
        progressCallback: @escaping (Int, Int) -> Void
    ) async -> [UUID: Result<OCRResult, OCRError>] {

        batchProgress = BatchProgress(
            totalItems: manuals.count,
            completedItems: 0,
            currentItem: nil,
            overallProgress: 0.0,
            estimatedTimeRemaining: nil
        )

        let results = await coordinator.coordinateBatchOCR(
            manuals: manuals,
            configuration: configuration,
            imageProcessor: imageProcessor,
            textProcessor: textProcessor,
            performanceMonitor: performanceMonitor,
            progressCallback: progressCallback
        )

        await MainActor.run {
            self.batchProgress = nil
        }

        // 记录批量处理统计
        let successCount = results.values.compactMap { result in
            if case .success = result { return 1 } else { return nil }
        }.count

        await performanceMonitor.recordBatchProcessing(
            totalItems: manuals.count,
            successCount: successCount,
            totalDuration: 0 // 这里需要实际计算总时间
        )

        return results
    }

    // MARK: - 智能重试OCR
    func performOCRWithRetry(
        on manual: Manual,
        maxRetries: Int = 3,
        configuration: OCRConfiguration = .default,
        completion: @escaping (Result<OCRResult, OCRError>) -> Void
    ) {
        Task {
            let result = await coordinator.coordinateOCRWithRetry(
                on: manual,
                maxRetries: maxRetries,
                configuration: configuration,
                imageProcessor: imageProcessor,
                textProcessor: textProcessor,
                performanceMonitor: performanceMonitor
            )

            await MainActor.run {
                completion(result)
            }
        }
    }

    // MARK: - 性能监控和统计
    func getPerformanceReport() -> OCRPerformanceReport {
        return performanceMonitor.getPerformanceReport()
    }

    func getRealtimeMetrics() -> OCRRealtimeMetrics {
        return performanceMonitor.getRealtimeMetrics()
    }

    func resetPerformanceStats() {
        Task {
            await performanceMonitor.resetStats()
        }
    }

    func resetStatistics() {
        processingStats = OCRProcessingStats()
        Task {
            await performanceMonitor.resetStats()
        }
    }

    // MARK: - 性能监控设置
    private func setupPerformanceMonitoring() {
        // 监控内存使用情况
        #if os(iOS)
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMemoryWarning()
        }
        #endif
    }

    private func handleMemoryWarning() {
        // 通知性能监控器
        Task {
            await performanceMonitor.recordError(.insufficientMemory, context: "内存警告")
        }

        // 重置处理队列
        processingQueue.removeAll()
        // 更新状态
        isProcessing = false
        currentProgress = 0.0
        lastError = .insufficientMemory
    }

    // MARK: - 取消处理
    func cancelProcessing(for requestId: UUID) {
        processingQueue.removeAll { $0 == requestId }
    }

    func cancelAllProcessing() {
        processingQueue.removeAll()
        isProcessing = false
        currentProgress = 0.0
        batchProgress = nil
    }
}