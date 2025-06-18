import Foundation

enum FileProcessingError: LocalizedError {
    case fileNotFound
    case fileTooLarge(maxSize: Int, actualSize: Int)
    case unsupportedFileType(String)
    case invalidImageData
    case compressionFailed
    case metadataExtractionFailed
    case ocrProcessingFailed
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "文件不存在"
        case .fileTooLarge(let maxSize, let actualSize):
            return "文件过大：\(actualSize)MB，最大允许：\(maxSize)MB"
        case .unsupportedFileType(let type):
            return "不支持的文件类型：\(type)"
        case .invalidImageData:
            return "无效的图像数据"
        case .compressionFailed:
            return "文件压缩失败"
        case .metadataExtractionFailed:
            return "元数据提取失败"
        case .ocrProcessingFailed:
            return "OCR处理失败"
        }
    }
} 