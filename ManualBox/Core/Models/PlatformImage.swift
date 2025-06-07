import SwiftUI

#if os(macOS)
typealias PlatformImage = NSImage
#else
typealias PlatformImage = UIImage
#endif

extension PlatformImage {
    func jpegData(compressionQuality: CGFloat) -> Data? {
        #if os(macOS)
        guard let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        return bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: compressionQuality])
        #else
        // 在iOS上不扩展这个方法，因为UIImage已经有这个方法
        // 这避免了编译器警告，并确保在iOS上使用原生实现
        return nil // 这行代码在iOS上不会被调用，因为整个扩展方法不会被编译
        #endif
    }
}

// 为UIImage单独添加便利初始化方法
#if !os(macOS)
extension UIImage {
    // 覆盖原有的初始化方法，确保不会递归调用
    convenience init?(platformData data: Data) {
        self.init(data: data, scale: UIScreen.main.scale)
    }
}
#endif

// 为NSImage添加相同接口以保持API一致性
#if os(macOS)
extension NSImage {
    convenience init?(platformData data: Data) {
        self.init(data: data)
    }
}
#endif

// SwiftUI 扩展，方便在视图中使用
extension Image {
    init(platformImage: PlatformImage) {
        #if os(macOS)
        self.init(nsImage: platformImage)
        #else
        self.init(uiImage: platformImage)
        #endif
    }
}
