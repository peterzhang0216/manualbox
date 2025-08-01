//
//  ExportFormat.swift
//  ManualBox
//
//  Created by AI Assistant on 2025/7/29.
//

import Foundation

// MARK: - 通用导出格式
enum ExportFormat: String, CaseIterable, Codable {
    case json = "json"
    case csv = "csv"
    case html = "html"
    case markdown = "md"
    case pdf = "pdf"
    case xml = "xml"
    
    var fileExtension: String {
        return rawValue
    }
    
    var mimeType: String {
        switch self {
        case .json: return "application/json"
        case .csv: return "text/csv"
        case .html: return "text/html"
        case .markdown: return "text/markdown"
        case .pdf: return "application/pdf"
        case .xml: return "application/xml"
        }
    }
    
    var displayName: String {
        switch self {
        case .json: return "JSON"
        case .csv: return "CSV"
        case .html: return "HTML"
        case .markdown: return "Markdown"
        case .pdf: return "PDF"
        case .xml: return "XML"
        }
    }
}