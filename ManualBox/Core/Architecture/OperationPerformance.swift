//
//  OperationPerformance.swift
//  ManualBox
//
//  Created by AI Assistant on 2025/7/29.
//

import Foundation

// MARK: - 操作性能数据
struct OperationPerformance: Identifiable, Codable {
    let id = UUID()
    let operationName: String
    let duration: TimeInterval
    let timestamp: Date
    let category: PerformanceCategory
    let success: Bool
    let memoryUsage: Int64?
    let cpuUsage: Double?
    let errorMessage: String?
    
    init(
        operationName: String,
        duration: TimeInterval,
        timestamp: Date = Date(),
        category: PerformanceCategory,
        success: Bool = true,
        memoryUsage: Int64? = nil,
        cpuUsage: Double? = nil,
        errorMessage: String? = nil
    ) {
        self.operationName = operationName
        self.duration = duration
        self.timestamp = timestamp
        self.category = category
        self.success = success
        self.memoryUsage = memoryUsage
        self.cpuUsage = cpuUsage
        self.errorMessage = errorMessage
    }
}

// MARK: - 操作性能统计
struct OperationPerformanceStats {
    let totalOperations: Int
    let averageDuration: TimeInterval
    let successRate: Double
    let slowestOperation: OperationPerformance?
    let fastestOperation: OperationPerformance?
    let recentOperations: [OperationPerformance]
}