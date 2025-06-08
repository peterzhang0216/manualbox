import SwiftUI
import Foundation

#if os(macOS)
import AppKit
#else
import UIKit
#endif

// MARK: - 平台通知管理器
class PlatformNotificationManager: ObservableObject {
    static let shared = PlatformNotificationManager()
    
    @Published var notifications: [PlatformNotification] = []
    
    private init() {}
    
    func showNotification(
        title: String,
        message: String,
        type: PlatformNotification.NotificationType = .info,
        duration: TimeInterval = 3.0,
        action: (() -> Void)? = nil
    ) {
        let notification = PlatformNotification(
            title: title,
            message: message,
            type: type,
            action: action
        )
        
        withAnimation(PlatformAdapter.defaultAnimation) {
            notifications.append(notification)
        }
        
        // 自动移除通知
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            self.removeNotification(notification)
        }
    }
    
    func removeNotification(_ notification: PlatformNotification) {
        withAnimation(PlatformAdapter.defaultAnimation) {
            notifications.removeAll { $0.id == notification.id }
        }
    }
    
    func clearAllNotifications() {
        withAnimation(PlatformAdapter.defaultAnimation) {
            notifications.removeAll()
        }
    }
}

// MARK: - 平台通知模型
struct PlatformNotification: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String
    let type: NotificationType
    let timestamp = Date()
    let action: (() -> Void)?
    
    enum NotificationType {
        case success
        case warning
        case error
        case info
        
        var color: Color {
            switch self {
            case .success:
                return .green
            case .warning:
                return .orange
            case .error:
                return .red
            case .info:
                return .blue
            }
        }
        
        var icon: String {
            switch self {
            case .success:
                return "checkmark.circle.fill"
            case .warning:
                return "exclamationmark.triangle.fill"
            case .error:
                return "xmark.circle.fill"
            case .info:
                return "info.circle.fill"
            }
        }
    }
    
    static func == (lhs: PlatformNotification, rhs: PlatformNotification) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - 平台通知视图
struct PlatformNotificationView: View {
    let notification: PlatformNotification
    let onDismiss: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: notification.type.icon)
                .foregroundColor(notification.type.color)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(notification.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(notification.message)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            }
            
            Spacer()
            
            if notification.action != nil {
                Button("操作") {
                    notification.action?()
                    onDismiss()
                }
                .buttonStyle(.bordered)
            }
            
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(PlatformAdapter.secondaryBackgroundColor)
                .shadow(
                    color: .black.opacity(0.1),
                    radius: 8,
                    x: 0,
                    y: 4
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(notification.type.color.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - 平台通知容器
struct PlatformNotificationContainer: View {
    @StateObject private var notificationManager = PlatformNotificationManager.shared
    
    var body: some View {
        VStack(spacing: 8) {
            ForEach(notificationManager.notifications) { notification in
                PlatformNotificationView(notification: notification) {
                    notificationManager.removeNotification(notification)
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .trailing).combined(with: .opacity)
                ))
            }
        }
        .padding()
    }
}

// MARK: - 平台触觉反馈
struct PlatformHapticFeedback {
    enum FeedbackType {
        case success
        case warning
        case error
        case selection
        case impact(intensity: CGFloat)
    }
    
    static func trigger(_ type: FeedbackType) {
        #if os(iOS)
        switch type {
        case .success:
            let feedback = UINotificationFeedbackGenerator()
            feedback.notificationOccurred(.success)
        case .warning:
            let feedback = UINotificationFeedbackGenerator()
            feedback.notificationOccurred(.warning)
        case .error:
            let feedback = UINotificationFeedbackGenerator()
            feedback.notificationOccurred(.error)
        case .selection:
            let feedback = UISelectionFeedbackGenerator()
            feedback.selectionChanged()
        case .impact(let intensity):
            let style: UIImpactFeedbackGenerator.FeedbackStyle
            if intensity < 0.3 {
                style = .light
            } else if intensity < 0.7 {
                style = .medium
            } else {
                style = .heavy
            }
            let feedback = UIImpactFeedbackGenerator(style: style)
            feedback.impactOccurred()
        }
        #endif
        // macOS 不支持触觉反馈
    }
}

// MARK: - 平台加载指示器
struct PlatformLoadingIndicator: View {
    let message: String?
    let style: LoadingStyle
    
    enum LoadingStyle {
        case circular
        case linear
        case dots
    }
    
    init(message: String? = nil, style: LoadingStyle = .circular) {
        self.message = message
        self.style = style
    }
    
    var body: some View {
        VStack(spacing: 16) {
            switch style {
            case .circular:
                ProgressView()
                    .scaleEffect(1.2)
            case .linear:
                ProgressView()
                    .progressViewStyle(.linear)
            case .dots:
                DotsLoadingView()
            }
            
            if let message = message {
                Text(message)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(PlatformAdapter.backgroundColor)
                .shadow(
                    color: .black.opacity(0.1),
                    radius: 8,
                    x: 0,
                    y: 4
                )
        )
    }
}

// MARK: - 点状加载动画
struct DotsLoadingView: View {
    @State private var animationOffset: CGFloat = 0
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 8, height: 8)
                    .scaleEffect(scale(for: index))
                    .animation(
                        Animation.easeInOut(duration: 0.6)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.2),
                        value: animationOffset
                    )
            }
        }
        .onAppear {
            animationOffset = 1
        }
    }
    
    private func scale(for index: Int) -> CGFloat {
        let phase = (animationOffset + Double(index) * 0.2).truncatingRemainder(dividingBy: 1.0)
        return 0.5 + 0.5 * sin(phase * 2 * .pi)
    }
}

// MARK: - 平台确认对话框
struct PlatformConfirmationDialog {
    static func show(
        title: String,
        message: String,
        confirmTitle: String = "确认",
        cancelTitle: String = "取消",
        isDestructive: Bool = false,
        onConfirm: @escaping () -> Void,
        onCancel: (() -> Void)? = nil
    ) {
        #if os(macOS)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: confirmTitle)
        alert.addButton(withTitle: cancelTitle)
        
        if isDestructive {
            alert.alertStyle = .critical
        }
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            onConfirm()
        } else {
            onCancel?()
        }
        #else
        // iOS 需要在 SwiftUI 视图中使用 .confirmationDialog 修饰符
        // 这里提供一个通用的实现思路
        DispatchQueue.main.async {
            onConfirm() // 简化实现，实际应该显示对话框
        }
        #endif
    }
}

// MARK: - 平台错误显示
struct PlatformErrorView: View {
    let error: Error
    let onRetry: (() -> Void)?
    let onDismiss: (() -> Void)?
    
    init(
        error: Error,
        onRetry: (() -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        self.error = error
        self.onRetry = onRetry
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundColor(.red)
            
            VStack(spacing: 8) {
                Text("出现错误")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(error.localizedDescription)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            HStack(spacing: 12) {
                if let onRetry = onRetry {
                    Button("重试") {
                        onRetry()
                    }
                    .buttonStyle(PlatformButtonStyle(style: .primary))
                }
                
                if let onDismiss = onDismiss {
                    Button("关闭") {
                        onDismiss()
                    }
                    .buttonStyle(PlatformButtonStyle(style: .secondary))
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(PlatformAdapter.backgroundColor)
                .shadow(
                    color: .black.opacity(0.1),
                    radius: 8,
                    x: 0,
                    y: 4
                )
        )
    }
}

// MARK: - 平台成功视图
struct PlatformSuccessView: View {
    let message: String
    let onDismiss: (() -> Void)?
    
    init(message: String, onDismiss: (() -> Void)? = nil) {
        self.message = message
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.largeTitle)
                .foregroundColor(.green)
            
            Text(message)
                .font(.headline)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
            
            if let onDismiss = onDismiss {
                Button("确定") {
                    onDismiss()
                }
                .buttonStyle(PlatformButtonStyle(style: .primary))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(PlatformAdapter.backgroundColor)
                .shadow(
                    color: .black.opacity(0.1),
                    radius: 8,
                    x: 0,
                    y: 4
                )
        )
    }
}

// MARK: - 视图扩展
extension View {
    func platformNotification() -> some View {
        self.overlay(
            PlatformNotificationContainer(),
            alignment: .top
        )
    }
    
    func platformLoading(_ isLoading: Bool, message: String? = nil) -> some View {
        self.overlay(
            Group {
                if isLoading {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                        
                        PlatformLoadingIndicator(message: message)
                    }
                }
            }
        )
    }
    
    func platformHapticFeedback(_ type: PlatformHapticFeedback.FeedbackType, trigger: Bool) -> some View {
        self.onChange(of: trigger) {
            if trigger {
                PlatformHapticFeedback.trigger(type)
            }
        }
    }
}