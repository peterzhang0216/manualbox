import SwiftUI
import UserNotifications

struct NotificationSettingsView: View {
    @EnvironmentObject private var notificationManager: AppNotificationManager
    @State private var isCheckingStatus = false
    
    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("通知权限状态")
                        .font(.headline)
                    
                    HStack {
                        statusView
                        Spacer()
                        if isCheckingStatus {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }
                    
                    Button {
                        refreshStatus()
                    } label: {
                        Label("刷新状态", systemImage: "arrow.clockwise")
                    }
                    .controlSize(.large)
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 8)
                }
                .padding(.vertical, 8)
            }
            
            if notificationManager.notificationAuthorizationStatus == .denied {
                Section {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("通知权限已被拒绝")
                            .font(.headline)
                            .foregroundColor(.red)
                        
                        Text("您需要在系统设置中手动开启通知权限：")
                        
                        #if os(macOS)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("1. 打开系统设置")
                            Text("2. 点击\"通知与焦点\"")
                            Text("3. 在应用列表中找到\"ManualBox\"")
                            Text("4. 开启\"允许通知\"选项")
                        }
                        #else
                        VStack(alignment: .leading, spacing: 8) {
                            Text("1. 打开设置应用")
                            Text("2. 点击\"通知\"")
                            Text("3. 在应用列表中找到\"ManualBox\"")
                            Text("4. 开启\"允许通知\"选项")
                        }
                        #endif
                        
                        Button {
                            notificationManager.openNotificationSettings()
                        } label: {
                            Label("打开系统设置", systemImage: "gear")
                        }
                        .controlSize(.large)
                        .buttonStyle(.borderedProminent)
                        .padding(.top, 8)
                    }
                    .padding(.vertical, 8)
                }
            } else if notificationManager.notificationAuthorizationStatus == .notDetermined {
                Section {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("请求通知权限")
                            .font(.headline)
                        
                        Text("保修提醒功能需要通知权限来提醒您产品保修期即将到期。")
                        
                        Button {
                            notificationManager.registerForNotifications()
                        } label: {
                            Label("请求通知权限", systemImage: "bell.badge")
                        }
                        .controlSize(.large)
                        .buttonStyle(.borderedProminent)
                        .padding(.top, 8)
                    }
                    .padding(.vertical, 8)
                }
            }
            
            if notificationManager.notificationAuthorizationStatus == .authorized {
                Section {
                    Toggle("启用保修到期提醒", isOn: $notificationManager.enableWarrantyReminders)
                    
                    if notificationManager.enableWarrantyReminders {
                        InlineStepper(
                            "提前 \(notificationManager.warrantyReminderDays) 天提醒",
                            value: $notificationManager.warrantyReminderDays,
                            in: 1...90
                        )
                    }
                }
            }
        }
        .navigationTitle("通知设置")
        .onAppear {
            refreshStatus()
        }
    }
    
    private var statusView: some View {
        HStack {
            switch notificationManager.notificationAuthorizationStatus {
            case .authorized:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("已授权")
                    .foregroundColor(.green)
            case .denied:
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
                Text("已拒绝")
                    .foregroundColor(.red)
            case .notDetermined:
                Image(systemName: "questionmark.circle.fill")
                    .foregroundColor(.orange)
                Text("未设置")
                    .foregroundColor(.orange)
            case .provisional, .ephemeral:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.yellow)
                Text("临时授权")
                    .foregroundColor(.yellow)
            @unknown default:
                Image(systemName: "questionmark.circle.fill")
                    .foregroundColor(.gray)
                Text("未知状态")
                    .foregroundColor(.gray)
            }
        }
        .font(.headline)
    }
    
    private func refreshStatus() {
        isCheckingStatus = true
        notificationManager.checkNotificationAuthorizationStatus()
        
        // 简单延迟以显示进度指示器
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isCheckingStatus = false
        }
    }
}

#Preview {
    NavigationView {
        NotificationSettingsView()
            .environmentObject(AppNotificationManager())
    }
}