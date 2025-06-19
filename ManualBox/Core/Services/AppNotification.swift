import Foundation
import Combine
import SwiftUI

// MARK: - AppNotification
/// 集中管理应用内通知定义
enum AppNotification: String {
    // 导航通知
    case createNewProduct
    case showProduct
    case showCategory
    case showTag
    
    // 数据变更通知
    case productAdded
    case productUpdated
    case productDeleted
    
    // OCR相关通知
    case ocrStarted
    case ocrCompleted
    case ocrFailed
    
    // 设置通知
    case settingsChanged
    
    // 通知名称
    var name: Notification.Name {
        return Notification.Name(rawValue)
    }
    
    // 发送通知
    func post(object: Any? = nil, userInfo: [AnyHashable: Any]? = nil) {
        NotificationCenter.default.post(
            name: name,
            object: object,
            userInfo: userInfo
        )
    }
    
    // 发送并附带数据
    func post<T: Encodable>(with data: T) {
        if let encoded = try? JSONEncoder().encode(data),
           let dict = try? JSONSerialization.jsonObject(with: encoded) as? [String: Any] {
            post(userInfo: dict)
        }
    }
}

// MARK: - NotificationObserver
/// 可用于在SwiftUI视图中订阅通知的结构
class NotificationObserver: ObservableObject {
    private var cancellables = Set<AnyCancellable>()
    
    @Published var lastNotification: (name: Notification.Name, object: Any?)?
    
    init() {}
    
    func observe(_ notification: AppNotification, perform action: @escaping (Any?) -> Void) {
        NotificationCenter.default.publisher(for: notification.name)
            .sink { [weak self] notification in
                self?.lastNotification = (notification.name, notification.object)
                action(notification.object)
            }
            .store(in: &cancellables)
    }
    
    deinit {
        cancellables.forEach { $0.cancel() }
    }
    
    // 解码通知中的数据
    static func decode<T: Decodable>(_ type: T.Type, from notification: Notification) -> T? {
        guard let userInfo = notification.userInfo,
              let data = try? JSONSerialization.data(withJSONObject: userInfo),
              let decoded = try? JSONDecoder().decode(type, from: data) else {
            return nil
        }
        return decoded
    }
}

// MARK: - SwiftUI扩展
extension View {
    /// 订阅应用通知并在收到时执行操作
    func onAppNotification(_ notification: AppNotification, perform action: @escaping (Notification) -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: notification.name)) { notification in
            action(notification)
        }
    }
    
    /// 监听通知并解码其中的数据
    func onAppNotification<T: Decodable>(_ notification: AppNotification, type: T.Type, perform action: @escaping (T) -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: notification.name)) { notification in
            if let decoded = NotificationObserver.decode(type, from: notification) {
                action(decoded)
            }
        }
    }
}