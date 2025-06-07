import Foundation
import SwiftUI

// MARK: - 服务容器协议
protocol ServiceContainerProtocol {
    func register<T>(_ type: T.Type, factory: @escaping () -> T)
    func register<T>(_ type: T.Type, instance: T)
    func resolve<T>(_ type: T.Type) -> T?
    func resolveRequired<T>(_ type: T.Type) -> T
    func unregister<T>(_ type: T.Type)
    func clear()
}

// MARK: - 服务生命周期
enum ServiceLifetime {
    case singleton  // 单例，整个应用生命周期内只创建一次
    case transient  // 瞬时，每次请求都创建新实例
    case scoped     // 作用域，在特定作用域内为单例
}

// MARK: - 服务注册信息结构体
struct ServiceRegistrationInfo {
    let lifetime: ServiceLifetime
    let factory: () -> Any
    var instance: Any?
    
    init(lifetime: ServiceLifetime, factory: @escaping () -> Any) {
        self.lifetime = lifetime
        self.factory = factory
        self.instance = nil
    }
}

// MARK: - 主服务容器实现
class ServiceContainer: ServiceContainerProtocol, ObservableObject {
    static let shared = ServiceContainer()
    
    private var services: [String: ServiceRegistrationInfo] = [:]
    private let queue = DispatchQueue(label: "ServiceContainer", attributes: .concurrent)
    
    private init() {}
    
    // MARK: - 注册服务
    func register<T>(_ type: T.Type, factory: @escaping () -> T) {
        register(type, lifetime: .transient, factory: factory)
    }
    
    func register<T>(_ type: T.Type, lifetime: ServiceLifetime = .singleton, factory: @escaping () -> T) {
        let key = String(describing: type)
        queue.async(flags: .barrier) {
            self.services[key] = ServiceRegistrationInfo(lifetime: lifetime) {
                factory()
            }
        }
    }
    
    func register<T>(_ type: T.Type, instance: T) {
        let key = String(describing: type)
        queue.async(flags: .barrier) {
            var registration = ServiceRegistrationInfo(lifetime: .singleton) { instance }
            registration.instance = instance
            self.services[key] = registration
        }
    }
    
    // MARK: - 解析服务
    func resolve<T>(_ type: T.Type) -> T? {
        let key = String(describing: type)
        return queue.sync {
            guard var registration = services[key] else {
                return nil
            }
            
            switch registration.lifetime {
            case .singleton:
                if let instance = registration.instance as? T {
                    return instance
                } else {
                    guard let newInstance = registration.factory() as? T else {
                        print("⚠️ 服务工厂返回的类型与预期类型不匹配: \(type)")
                        return nil
                    }
                    registration.instance = newInstance
                    services[key] = registration
                    return newInstance
                }
            case .transient:
                guard let instance = registration.factory() as? T else {
                    print("⚠️ 服务工厂返回的类型与预期类型不匹配: \(type)")
                    return nil
                }
                return instance
            case .scoped:
                // 简化实现，作用域服务当作单例处理
                if let instance = registration.instance as? T {
                    return instance
                } else {
                    guard let newInstance = registration.factory() as? T else {
                        print("⚠️ 服务工厂返回的类型与预期类型不匹配: \(type)")
                        return nil
                    }
                    registration.instance = newInstance
                    services[key] = registration
                    return newInstance
                }
            }
        }
    }
    
    func resolveRequired<T>(_ type: T.Type) -> T {
        guard let service: T = resolve(type) else {
            fatalError("无法解析服务: \(type)")
        }
        return service
    }
    
    // MARK: - 管理服务
    func unregister<T>(_ type: T.Type) {
        let key = String(describing: type)
        queue.async(flags: .barrier) {
            self.services.removeValue(forKey: key)
        }
    }
    
    func clear() {
        queue.async(flags: .barrier) {
            self.services.removeAll()
        }
    }
    
    // MARK: - 调试辅助
    func listRegisteredServices() -> [String] {
        return queue.sync {
            Array(services.keys)
        }
    }
    
    func isRegistered<T>(_ type: T.Type) -> Bool {
        let key = String(describing: type)
        return queue.sync {
            services[key] != nil
        }
    }
}

// MARK: - SwiftUI 环境键
struct ServiceContainerKey: EnvironmentKey {
    static let defaultValue: ServiceContainer = ServiceContainer.shared
}

extension EnvironmentValues {
    var serviceContainer: ServiceContainer {
        get { self[ServiceContainerKey.self] }
        set { self[ServiceContainerKey.self] = newValue }
    }
}

// MARK: - SwiftUI 视图扩展
extension View {
    func serviceContainer(_ container: ServiceContainer) -> some View {
        environment(\.serviceContainer, container)
    }
}

// MARK: - 属性包装器用于依赖注入
@propertyWrapper
struct Injected<T> {
    private let keyPath: KeyPath<ServiceContainer, T>?
    private let type: T.Type
    
    init(_ type: T.Type) {
        self.type = type
        self.keyPath = nil
    }
    
    var wrappedValue: T {
        ServiceContainer.shared.resolveRequired(type)
    }
}

@propertyWrapper
struct LazyInjected<T> {
    private let type: T.Type
    private var _value: T?
    
    init(_ type: T.Type) {
        self.type = type
    }
    
    var wrappedValue: T {
        mutating get {
            if let value = _value {
                return value
            }
            let resolved = ServiceContainer.shared.resolveRequired(type)
            _value = resolved
            return resolved
        }
    }
}

// MARK: - 便利扩展
extension ServiceContainer {
    // 批量注册服务
    func registerServices(_ registrations: [(any Any.Type, ServiceLifetime, () -> Any)]) {
        for (type, lifetime, factory) in registrations {
            let key = String(describing: type)
            queue.async(flags: .barrier) {
                self.services[key] = ServiceRegistrationInfo(lifetime: lifetime, factory: factory)
            }
        }
    }
}