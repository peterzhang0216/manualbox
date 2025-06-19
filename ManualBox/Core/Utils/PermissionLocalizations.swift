import Foundation

// MARK: - 权限描述本地化
struct PermissionLocalizations {
    
    // MARK: - 英文权限描述
    static let english: [String: String] = [
        "NSUserNotificationsUsageDescription": "We need notification permission to remind you of product warranty expiration.",
        "NSPhotoLibraryUsageDescription": "Access to your photos is required for uploading product images and manuals.",
        "NSCameraUsageDescription": "Camera access is needed to take product and invoice photos.",
        "NSMicrophoneUsageDescription": "Microphone access is required for recording features."
    ]
    
    // MARK: - 中文权限描述
    static let chinese: [String: String] = [
        "NSUserNotificationsUsageDescription": "我们需要通知权限来提醒您商品保修期的到期时间。",
        "NSPhotoLibraryUsageDescription": "需要访问您的照片用于商品图片和说明书上传。",
        "NSCameraUsageDescription": "需要使用相机拍摄商品图片和发票。",
        "NSMicrophoneUsageDescription": "如需录音功能，请授权麦克风访问。"
    ]
    
    // MARK: - 获取权限描述
    static func getPermissionDescription(for key: String, language: String = "auto") -> String {
        let languageCode = language == "auto" ? 
            (Locale.current.language.languageCode?.identifier ?? "en") : language
        
        switch languageCode {
        case "zh-Hans", "zh":
            return chinese[key] ?? english[key] ?? key
        default:
            return english[key] ?? key
        }
    }
}
