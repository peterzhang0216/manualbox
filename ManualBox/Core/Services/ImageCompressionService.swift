import Foundation
import SwiftUI

class ImageCompressionService {
    func compressImage(data: Data, quality: Float) async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                guard let image = PlatformImage(data: data) else {
                    continuation.resume(throwing: FileProcessingError.invalidImageData)
                    return
                }
                #if os(macOS)
                guard let tiffData = image.tiffRepresentation,
                      let bitmap = NSBitmapImageRep(data: tiffData),
                      let compressedData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: quality]) else {
                    continuation.resume(throwing: FileProcessingError.compressionFailed)
                    return
                }
                continuation.resume(returning: compressedData)
                #else
                guard let compressedData = image.jpegData(compressionQuality: CGFloat(quality)) else {
                    continuation.resume(throwing: FileProcessingError.compressionFailed)
                    return
                }
                continuation.resume(returning: compressedData)
                #endif
            }
        }
    }
    
    func compressPDF(data: Data, quality: Float) async throws -> Data {
        // PDF压缩通常涉及重新编码图像内容
        // 这里返回原数据，实际应用中可以使用PDF压缩库
        return data
    }
} 