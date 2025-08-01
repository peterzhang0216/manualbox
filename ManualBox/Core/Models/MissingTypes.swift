//
//  MissingTypes.swift
//  ManualBox
//
//  Created by Assistant on 2025/7/29.
//

import Foundation

// MARK: - 缺失的类型定义

/// OCR文档类型
public enum OCRDocumentType: String, CaseIterable {
    case manual = "manual"
    case receipt = "receipt"
    case warranty = "warranty"
    case specification = "specification"
    case other = "other"
    
    var displayName: String {
        switch self {
        case .manual: return "使用手册"
        case .receipt: return "收据"
        case .warranty: return "保修卡"
        case .specification: return "规格说明"
        case .other: return "其他"
        }
    }
}

/// 同步错误类型
public enum SyncError: Error, LocalizedError {
    case networkUnavailable
    case authenticationFailed
    case quotaExceeded
    case conflictResolutionFailed
    case dataCorruption
    case serverUnavailable
    case unknownError(Error)
    
    public var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            return "网络不可用"
        case .authenticationFailed:
            return "身份验证失败"
        case .quotaExceeded:
            return "存储配额已满"
        case .conflictResolutionFailed:
            return "冲突解决失败"
        case .dataCorruption:
            return "数据损坏"
        case .serverUnavailable:
            return "服务器不可用"
        case .unknownError(let error):
            return "未知错误: \(error.localizedDescription)"
        }
    }
}

/// 增强的产品搜索服务
public class EnhancedProductSearchService: ObservableObject {
    public static let shared = EnhancedProductSearchService()
    
    @Published public var searchResults: [Product] = []
    @Published public var isSearching = false
    @Published public var searchError: Error?
    
    private init() {}
    
    func search(query: String, filters: SearchFilters? = nil) async {
        await MainActor.run {
            isSearching = true
            searchError = nil
        }
        
        // 实现搜索逻辑
        // 这里应该调用UnifiedSearchService
        
        await MainActor.run {
            isSearching = false
        }
    }
    
    public func clearResults() {
        searchResults.removeAll()
        searchError = nil
    }
}
