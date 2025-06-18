import Foundation
import UniformTypeIdentifiers
import PDFKit
import ImageIO

class FileMetadataExtractor {
    func extractMetadata(from url: URL, data: Data) async throws -> FileMetadata {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let fileType = UTType(filenameExtension: url.pathExtension) ?? .data
        var imageProperties: FileMetadata.ImageProperties?
        var pdfProperties: FileMetadata.PDFProperties?
        if fileType.conforms(to: .image) {
            imageProperties = try await extractImageProperties(from: data)
        } else if fileType.conforms(to: .pdf) {
            pdfProperties = try await extractPDFProperties(from: data)
        }
        return FileMetadata(
            fileName: url.lastPathComponent,
            fileExtension: url.pathExtension,
            mimeType: fileType.preferredMIMEType ?? "application/octet-stream",
            creationDate: attributes[.creationDate] as? Date,
            modificationDate: attributes[.modificationDate] as? Date,
            fileSize: data.count,
            imageProperties: imageProperties,
            pdfProperties: pdfProperties
        )
    }
    private func extractImageProperties(from data: Data) async throws -> FileMetadata.ImageProperties? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil),
                      let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] else {
                    continuation.resume(returning: nil)
                    return
                }
                let width = properties[kCGImagePropertyPixelWidth as String] as? Int ?? 0
                let height = properties[kCGImagePropertyPixelHeight as String] as? Int ?? 0
                let colorSpace = properties[kCGImagePropertyColorModel as String] as? String
                let dpi = properties[kCGImagePropertyDPIWidth as String] as? Float
                let hasAlpha = properties[kCGImagePropertyHasAlpha as String] as? Bool ?? false
                let imageProps = FileMetadata.ImageProperties(
                    width: width,
                    height: height,
                    colorSpace: colorSpace,
                    dpi: dpi,
                    hasAlpha: hasAlpha
                )
                continuation.resume(returning: imageProps)
            }
        }
    }
    private func extractPDFProperties(from data: Data) async throws -> FileMetadata.PDFProperties? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                guard let pdfDocument = PDFDocument(data: data) else {
                    continuation.resume(returning: nil)
                    return
                }
                let pdfProps = FileMetadata.PDFProperties(
                    pageCount: pdfDocument.pageCount,
                    title: pdfDocument.documentAttributes?[PDFDocumentAttribute.titleAttribute] as? String,
                    author: pdfDocument.documentAttributes?[PDFDocumentAttribute.authorAttribute] as? String,
                    subject: pdfDocument.documentAttributes?[PDFDocumentAttribute.subjectAttribute] as? String,
                    creator: pdfDocument.documentAttributes?[PDFDocumentAttribute.creatorAttribute] as? String,
                    isEncrypted: pdfDocument.isEncrypted
                )
                continuation.resume(returning: pdfProps)
            }
        }
    }
} 