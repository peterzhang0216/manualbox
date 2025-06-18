import Foundation
import UniformTypeIdentifiers
import SwiftUI

struct FileProcessingResult {
    let processedFileData: Data
    let originalFileSize: Int
    let processedFileSize: Int
    let compressionRatio: Float
    let fileMetadata: FileMetadata?
    let thumbnailImage: PlatformImage?
    let ocrText: String?
    let processingTime: TimeInterval
    let fileType: UTType
} 