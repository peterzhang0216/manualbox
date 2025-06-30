import Foundation
import UniformTypeIdentifiers
import CryptoKit
#if os(macOS)
import AppKit
import PDFKit
#elseif os(iOS)
import UIKit
#endif

// MARK: - 增强的文件验证器
/// 专门负责文件验证、安全检查和完整性验证
class FileValidator {
    
    // 支持的文件类型
    private let supportedTypes: Set<UTType> = [
        .pdf, .jpeg, .png, .gif, .bmp, .tiff, .heic, .heif,
        .text, .rtf, .html, .xml, .json
    ]
    
    // 危险文件扩展名
    private let dangerousExtensions: Set<String> = [
        "exe", "bat", "cmd", "com", "scr", "pif", "vbs", "js", "jar", "app", "dmg"
    ]
    
    // MARK: - 主要验证方法
    
    /// 全面文件验证
    func validateFile(at url: URL, options: FileProcessingOptions) throws {
        // 基础存在性检查
        try validateFileExists(at: url)
        
        // 文件大小检查
        try validateFileSize(at: url, maxSize: options.maxFileSize)
        
        // 文件类型检查
        try validateFileType(at: url)
        
        // 安全性检查
        try validateFileSecurity(at: url)
        
        // 文件完整性检查
        try validateFileIntegrity(at: url)
        
        // 内容验证
        try validateFileContent(at: url)
    }
    
    /// 批量文件验证
    func validateFiles(at urls: [URL], options: FileProcessingOptions) throws -> [URL: ValidationResult] {
        var results: [URL: ValidationResult] = [:]
        
        for url in urls {
            do {
                try validateFile(at: url, options: options)
                results[url] = ValidationResult(isValid: true, errors: [])
            } catch {
                let validationError = error as? FileProcessingError ?? .fileNotFound
                results[url] = ValidationResult(
                    isValid: false, 
                    errors: [validationError.localizedDescription]
                )
            }
        }
        
        return results
    }
    
    // MARK: - 具体验证方法
    
    private func validateFileExists(at url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw FileProcessingError.fileNotFound
        }
        
        // 检查是否为目录
        var isDirectory: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
        
        if isDirectory.boolValue {
            throw FileProcessingError.unsupportedFileType("目录")
        }
    }
    
    private func validateFileSize(at url: URL, maxSize: Int) throws {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let fileSize = attributes[.size] as? UInt64 ?? 0
        let fileSizeMB = Int(fileSize / 1024 / 1024)
        
        guard fileSizeMB <= maxSize else {
            throw FileProcessingError.fileTooLarge(maxSize: maxSize, actualSize: fileSizeMB)
        }
        
        // 检查文件是否为空
        guard fileSize > 0 else {
            throw FileProcessingError.invalidImageData
        }
    }
    
    private func validateFileType(at url: URL) throws {
        let fileExtension = url.pathExtension.lowercased()
        
        // 检查危险文件扩展名
        guard !dangerousExtensions.contains(fileExtension) else {
            throw FileProcessingError.unsupportedFileType("危险文件类型: \(fileExtension)")
        }
        
        let fileType = UTType(filenameExtension: fileExtension) ?? .data
        
        // 检查是否为支持的类型
        let isSupported = supportedTypes.contains { supportedType in
            fileType.conforms(to: supportedType)
        }
        
        guard isSupported else {
            throw FileProcessingError.unsupportedFileType(fileExtension)
        }
    }
    
    private func validateFileSecurity(at url: URL) throws {
        // 检查文件权限
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let permissions = attributes[.posixPermissions] as? NSNumber
        
        // 检查是否有执行权限（可能的安全风险）
        if let perms = permissions?.uint16Value {
            let hasExecutePermission = (perms & 0o111) != 0
            if hasExecutePermission {
                print("⚠️ 警告: 文件具有执行权限: \(url.lastPathComponent)")
            }
        }
        
        // 检查文件路径是否包含可疑字符
        let suspiciousCharacters = ["../", "..\\", "<", ">", "|", "&", ";"]
        let filePath = url.path
        
        for suspiciousChar in suspiciousCharacters {
            if filePath.contains(suspiciousChar) {
                throw FileProcessingError.unsupportedFileType("文件路径包含可疑字符")
            }
        }
    }
    
    private func validateFileIntegrity(at url: URL) throws {
        // 读取文件数据进行完整性检查
        let data = try Data(contentsOf: url)
        
        // 检查文件头部魔数
        try validateFileMagicNumbers(data: data, url: url)
        
        // 计算文件校验和
        let checksum = calculateChecksum(data: data)
        print("📋 文件校验和: \(checksum) - \(url.lastPathComponent)")
    }
    
    private func validateFileMagicNumbers(data: Data, url: URL) throws {
        guard data.count >= 4 else {
            throw FileProcessingError.invalidImageData
        }
        
        let fileExtension = url.pathExtension.lowercased()
        let header = data.prefix(8)
        
        // 检查常见文件格式的魔数
        switch fileExtension {
        case "pdf":
            if !header.starts(with: Data([0x25, 0x50, 0x44, 0x46])) { // %PDF
                throw FileProcessingError.invalidImageData
            }
        case "jpg", "jpeg":
            if !header.starts(with: Data([0xFF, 0xD8, 0xFF])) {
                throw FileProcessingError.invalidImageData
            }
        case "png":
            if !header.starts(with: Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) {
                throw FileProcessingError.invalidImageData
            }
        case "gif":
            if !header.starts(with: Data([0x47, 0x49, 0x46])) { // GIF
                throw FileProcessingError.invalidImageData
            }
        default:
            break // 其他格式暂不检查魔数
        }
    }
    
    private func validateFileContent(at url: URL) throws {
        let fileType = UTType(filenameExtension: url.pathExtension) ?? .data
        
        if fileType.conforms(to: .image) {
            try validateImageContent(at: url)
        } else if fileType.conforms(to: .pdf) {
            try validatePDFContent(at: url)
        } else if fileType.conforms(to: .text) {
            try validateTextContent(at: url)
        }
    }
    
    private func validateImageContent(at url: URL) throws {
        let data = try Data(contentsOf: url)
        
        #if os(macOS)
        guard NSImage(data: data) != nil else {
            throw FileProcessingError.invalidImageData
        }
        #else
        guard UIImage(data: data) != nil else {
            throw FileProcessingError.invalidImageData
        }
        #endif
    }
    
    private func validatePDFContent(at url: URL) throws {
        let data = try Data(contentsOf: url)
        
        #if os(macOS)
        guard let pdfDocument = PDFDocument(data: data) else {
            throw FileProcessingError.invalidImageData
        }
        
        // 检查PDF是否有页面
        guard pdfDocument.pageCount > 0 else {
            throw FileProcessingError.invalidImageData
        }
        
        // 检查PDF是否损坏
        guard let firstPage = pdfDocument.page(at: 0) else {
            throw FileProcessingError.invalidImageData
        }
        
        // 验证页面内容
        let pageRect = firstPage.bounds(for: .mediaBox)
        guard pageRect.width > 0 && pageRect.height > 0 else {
            throw FileProcessingError.invalidImageData
        }
        #else
        // iOS下简化PDF验证，只检查文件头部
        guard data.count >= 4 && data.prefix(4) == Data([0x25, 0x50, 0x44, 0x46]) else {
            throw FileProcessingError.invalidImageData
        }
        #endif
    }
    
    private func validateTextContent(at url: URL) throws {
        let data = try Data(contentsOf: url)
        
        // 尝试解码为UTF-8文本
        if String(data: data, encoding: .utf8) != nil {
            return // 成功解码UTF-8
        }
        
        // 尝试其他编码
        if String(data: data, encoding: .utf16) != nil ||
           String(data: data, encoding: .ascii) != nil {
            return // 成功解码其他编码
        }
        
        // 所有编码都失败
        throw FileProcessingError.invalidImageData
    }
    
    // MARK: - 辅助方法
    
    private func calculateChecksum(data: Data) -> String {
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    /// 获取文件详细信息
    func getFileInfo(at url: URL) throws -> FileInfo {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let fileSize = attributes[.size] as? UInt64 ?? 0
        let creationDate = attributes[.creationDate] as? Date
        let modificationDate = attributes[.modificationDate] as? Date
        let fileType = UTType(filenameExtension: url.pathExtension) ?? .data
        
        return FileInfo(
            url: url,
            fileName: url.lastPathComponent,
            fileExtension: url.pathExtension,
            fileSize: Int(fileSize),
            fileType: fileType,
            creationDate: creationDate,
            modificationDate: modificationDate,
            isSupported: isFileTypeSupported(fileType),
            checksum: try? calculateChecksum(data: Data(contentsOf: url))
        )
    }
    
    private func isFileTypeSupported(_ fileType: UTType) -> Bool {
        return supportedTypes.contains { supportedType in
            fileType.conforms(to: supportedType)
        }
    }
}

// MARK: - 验证结果结构
struct ValidationResult {
    let isValid: Bool
    let errors: [String]
    let warnings: [String]
    
    init(isValid: Bool, errors: [String], warnings: [String] = []) {
        self.isValid = isValid
        self.errors = errors
        self.warnings = warnings
    }
}

// MARK: - 文件信息结构
struct FileInfo {
    let url: URL
    let fileName: String
    let fileExtension: String
    let fileSize: Int
    let fileType: UTType
    let creationDate: Date?
    let modificationDate: Date?
    let isSupported: Bool
    let checksum: String?
}
