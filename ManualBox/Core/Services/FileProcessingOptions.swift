import Foundation

struct FileProcessingOptions {
    var shouldCompress: Bool
    var compressionQuality: Float
    var shouldExtractMetadata: Bool
    var shouldPerformOCR: Bool
    var shouldGenerateThumbnail: Bool
    var maxFileSize: Int // MB
    
    static let `default` = FileProcessingOptions(
        shouldCompress: true,
        compressionQuality: 0.8,
        shouldExtractMetadata: true,
        shouldPerformOCR: true,
        shouldGenerateThumbnail: true,
        maxFileSize: 50
    )
    
    static let highQuality = FileProcessingOptions(
        shouldCompress: false,
        compressionQuality: 1.0,
        shouldExtractMetadata: true,
        shouldPerformOCR: true,
        shouldGenerateThumbnail: true,
        maxFileSize: 100
    )
} 