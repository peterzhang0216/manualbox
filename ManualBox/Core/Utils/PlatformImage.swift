import SwiftUI
import Foundation

#if os(macOS)
import AppKit
typealias PlatformImage = NSImage
#else
import UIKit
typealias PlatformImage = UIImage
#endif

// MARK: - PlatformImage Extensions
#if os(macOS)
extension PlatformImage {
    func jpegData(compressionQuality: CGFloat) -> Data? {
        guard let tiffData = self.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        
        let properties: [NSBitmapImageRep.PropertyKey: Any] = [
            .compressionFactor: compressionQuality
        ]
        
        return bitmapImage.representation(using: .jpeg, properties: properties)
    }
}
#endif

// MARK: - 平台图像处理器
struct PlatformImageProcessor {
    
    // MARK: - 图像压缩
    static func compressImage(_ image: PlatformImage, quality: CGFloat = 0.8) -> Data? {
        #if os(macOS)
        guard let tiffData = image.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        
        let properties: [NSBitmapImageRep.PropertyKey: Any] = [
            .compressionFactor: quality
        ]
        
        return bitmapImage.representation(using: .jpeg, properties: properties)
        #else
        return image.jpegData(compressionQuality: quality)
        #endif
    }
    
    // MARK: - 图像缩放
    static func resizeImage(_ image: PlatformImage, to size: CGSize) -> PlatformImage? {
        #if os(macOS)
        let newImage = NSImage(size: size)
        newImage.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: size))
        newImage.unlockFocus()
        return newImage
        #else
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        #endif
    }
    
    // MARK: - 缩略图生成
    static func generateThumbnail(from image: PlatformImage, size: CGSize = CGSize(width: 200, height: 200)) -> PlatformImage? {
        let aspectRatio = image.size.width / image.size.height
        let thumbnailSize: CGSize
        
        if aspectRatio > 1 {
            // 宽图
            thumbnailSize = CGSize(width: size.width, height: size.width / aspectRatio)
        } else {
            // 高图或正方形
            thumbnailSize = CGSize(width: size.height * aspectRatio, height: size.height)
        }
        
        return resizeImage(image, to: thumbnailSize)
    }
    
    // MARK: - 图像格式转换
    static func convertToFormat(_ image: PlatformImage, format: ImageFormat) -> Data? {
        switch format {
        case .jpeg(let quality):
            return compressImage(image, quality: quality)
        case .png:
            #if os(macOS)
            guard let tiffData = image.tiffRepresentation,
                  let bitmapImage = NSBitmapImageRep(data: tiffData) else {
                return nil
            }
            return bitmapImage.representation(using: .png, properties: [:])
            #else
            return image.pngData()
            #endif
        }
    }
    
    // MARK: - 从文件加载图像
    static func loadImage(from url: URL) -> PlatformImage? {
        #if os(macOS)
        return NSImage(contentsOf: url)
        #else
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
        #endif
    }
    
    // MARK: - 保存图像到文件
    static func saveImage(_ image: PlatformImage, to url: URL, format: ImageFormat = .jpeg(0.8)) -> Bool {
        guard let data = convertToFormat(image, format: format) else {
            return false
        }
        
        do {
            try data.write(to: url)
            return true
        } catch {
            print("保存图像失败: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - 图像元数据提取
    static func extractMetadata(from image: PlatformImage) -> ImageMetadata {
        let size = image.size
        
        #if os(macOS)
        let colorSpace = "sRGB" // NSImage doesn't provide direct colorSpace access
        let hasAlpha = image.representations.first?.hasAlpha ?? false
        #else
        let colorSpace = image.cgImage?.colorSpace?.name ?? "Unknown" as CFString
        let hasAlpha = image.cgImage?.alphaInfo != CGImageAlphaInfo.none
        #endif
        
        return ImageMetadata(
            width: Int(size.width),
            height: Int(size.height),
            colorSpace: String(colorSpace),
            hasAlpha: hasAlpha
        )
    }
}

// MARK: - 图像格式枚举
enum ImageFormat {
    case jpeg(CGFloat) // 质量参数 0.0-1.0
    case png
}

// MARK: - 图像元数据结构
struct ImageMetadata {
    let width: Int
    let height: Int
    let colorSpace: String
    let hasAlpha: Bool
    
    var aspectRatio: Double {
        return Double(width) / Double(height)
    }
    
    var isLandscape: Bool {
        return width > height
    }
    
    var isPortrait: Bool {
        return height > width
    }
    
    var isSquare: Bool {
        return width == height
    }
}

// MARK: - SwiftUI 图像扩展
extension Image {
    init(platformImage: PlatformImage) {
        #if os(macOS)
        self.init(nsImage: platformImage)
        #else
        self.init(uiImage: platformImage)
        #endif
    }
}

// MARK: - 平台图像视图组件
struct PlatformImageView: View {
    let image: PlatformImage?
    let placeholder: String
    let contentMode: ContentMode
    
    init(image: PlatformImage?, placeholder: String = "photo", contentMode: ContentMode = .fit) {
        self.image = image
        self.placeholder = placeholder
        self.contentMode = contentMode
    }
    
    var body: some View {
        Group {
            if let image = image {
                Image(platformImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                Image(systemName: placeholder)
                    .foregroundColor(.secondary)
                    .font(.largeTitle)
            }
        }
    }
}

// MARK: - 异步图像加载器
@MainActor
class PlatformImageLoader: ObservableObject {
    @Published var image: PlatformImage?
    @Published var isLoading = false
    @Published var error: Error?
    
    func loadImage(from url: URL) {
        isLoading = true
        error = nil
        
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                
                #if os(macOS)
                if let loadedImage = NSImage(data: data) {
                    await MainActor.run {
                        self.image = loadedImage
                        self.isLoading = false
                    }
                }
                #else
                if let loadedImage = UIImage(data: data) {
                    await MainActor.run {
                        self.image = loadedImage
                        self.isLoading = false
                    }
                }
                #endif
            } catch {
                await MainActor.run {
                    self.error = error
                    self.isLoading = false
                }
            }
        }
    }
    
    func loadImage(from path: String) {
        let url = URL(fileURLWithPath: path)
        
        Task {
            await MainActor.run {
                self.isLoading = true
                self.error = nil
                self.image = PlatformImageProcessor.loadImage(from: url)
                self.isLoading = false
            }
        }
    }
}

// MARK: - 异步图像视图
struct AsyncPlatformImageView: View {
    let url: URL?
    let placeholder: String
    let contentMode: ContentMode
    
    @StateObject private var loader = PlatformImageLoader()
    
    init(url: URL?, placeholder: String = "photo", contentMode: ContentMode = .fit) {
        self.url = url
        self.placeholder = placeholder
        self.contentMode = contentMode
    }
    
    var body: some View {
        Group {
            if loader.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let image = loader.image {
                PlatformImageView(image: image, contentMode: contentMode)
            } else {
                Image(systemName: placeholder)
                    .foregroundColor(.secondary)
                    .font(.largeTitle)
            }
        }
        .onAppear {
            if let url = url {
                loader.loadImage(from: url)
            }
        }
        .onChange(of: url) {
            if let url = url {
                loader.loadImage(from: url)
            }
        }
    }
}