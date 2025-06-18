import Foundation

struct FileMetadata {
    let fileName: String
    let fileExtension: String
    let mimeType: String
    let creationDate: Date?
    let modificationDate: Date?
    let fileSize: Int
    let imageProperties: ImageProperties?
    let pdfProperties: PDFProperties?
    
    struct ImageProperties {
        let width: Int
        let height: Int
        let colorSpace: String?
        let dpi: Float?
        let hasAlpha: Bool
    }
    
    struct PDFProperties {
        let pageCount: Int
        let title: String?
        let author: String?
        let subject: String?
        let creator: String?
        let isEncrypted: Bool
    }
} 