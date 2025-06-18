import Foundation
import UniformTypeIdentifiers

class FileValidationService {
    func validateFile(at url: URL, options: FileProcessingOptions) throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw FileProcessingError.fileNotFound
        }
        let fileSize = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? UInt64 ?? 0
        let fileSizeMB = Int(fileSize / 1024 / 1024)
        guard fileSizeMB <= options.maxFileSize else {
            throw FileProcessingError.fileTooLarge(maxSize: options.maxFileSize, actualSize: fileSizeMB)
        }
        let fileType = UTType(filenameExtension: url.pathExtension) ?? .data
        guard isValidFileType(fileType) else {
            throw FileProcessingError.unsupportedFileType(url.pathExtension)
        }
    }
    private func isValidFileType(_ type: UTType) -> Bool {
        return type.conforms(to: .pdf) || 
               type.conforms(to: .image) ||
               type.conforms(to: .text) ||
               type.conforms(to: .rtf)
    }
} 