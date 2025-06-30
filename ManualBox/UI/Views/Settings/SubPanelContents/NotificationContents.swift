import SwiftUI

// MARK: - 通知权限内容（旧版本）
struct LegacyNotificationPermissionsContent: View {
    @EnvironmentObject private var settingsViewModel: SettingsViewModel
    
    var body: some View {
        SettingsCard(
            title: "通知权限管理",
            icon: "bell.circle.fill",
            iconColor: .orange,
            description: "管理应用的通知权限和基本设置"
        ) {
            LegacySettingsGroup {
                SettingsToggle(
                    title: "启用通知",
                    description: "允许应用发送通知提醒",
                    icon: "bell.fill",
                    iconColor: .orange,
                    isOn: Binding(
                        get: { settingsViewModel.enableNotifications },
                        set: { enabled in
                            settingsViewModel.send(.updateEnableNotifications(enabled))
                        }
                    )
                )
                
                if settingsViewModel.enableNotifications {
                    Divider()
                        .padding(.vertical, 8)
                    
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.blue)
                        
                        Text("通知权限已启用，您将收到保修到期提醒和其他重要通知。")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
}

// MARK: - 提醒计划内容（旧版本）
struct LegacyNotificationScheduleContent: View {
    @EnvironmentObject private var settingsViewModel: SettingsViewModel
    
    var body: some View {
        SettingsCard(
            title: "提醒计划设置",
            icon: "clock.fill",
            iconColor: .blue,
            description: "设置默认提醒时间和通知计划"
        ) {
            LegacySettingsGroup {
                HStack {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.blue)
                        .frame(width: 28, height: 28)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("默认提醒时间")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                        Text("设置新产品的默认提醒时间")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    DatePicker(
                        "",
                        selection: Binding(
                            get: { settingsViewModel.notificationTime },
                            set: { time in
                                settingsViewModel.send(.updateNotificationTime(time))
                            }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                }
                .padding(.vertical, 4)
            }
        }
    }
}

// MARK: - 免打扰时段内容（旧版本）
struct LegacySilentPeriodContent: View {
    @EnvironmentObject private var settingsViewModel: SettingsViewModel
    
    var body: some View {
        SettingsCard(
            title: "免打扰时段",
            icon: "moon.fill",
            iconColor: .purple,
            description: "在指定时间段内静音所有通知"
        ) {
            LegacySettingsGroup {
                SettingsToggle(
                    title: "启用免打扰",
                    description: "在指定时间段内不发送通知",
                    icon: "moon.fill",
                    iconColor: .purple,
                    isOn: Binding(
                        get: { settingsViewModel.enableSilentPeriod },
                        set: { enabled in
                            settingsViewModel.send(.updateSilentPeriod(enabled))
                        }
                    )
                )

                if settingsViewModel.enableSilentPeriod {
                    Divider()
                        .padding(.vertical, 8)

                    VStack(spacing: 12) {
                        // 开始时间
                        HStack {
                            Image(systemName: "moon.stars.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.purple)
                                .frame(width: 28, height: 28)
                                .background(Color.purple.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                            VStack(alignment: .leading, spacing: 2) {
                                Text("开始时间")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.primary)
                                Text("免打扰时段开始时间")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Text(formatTime(settingsViewModel.silentStartTime))
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.purple)
                        }

                        // 结束时间
                        HStack {
                            Image(systemName: "sun.max.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.orange)
                                .frame(width: 28, height: 28)
                                .background(Color.orange.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                            VStack(alignment: .leading, spacing: 2) {
                                Text("结束时间")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.primary)
                                Text("免打扰时段结束时间")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Text(formatTime(settingsViewModel.silentEndTime))
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.orange)
                        }
                    }
                }
            }
        }
    }
    
    private func formatTime(_ timeInterval: Double) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = (Int(timeInterval) % 3600) / 60
        return String(format: "%02d:%02d", hours, minutes)
    }
}

#Preview {
    VStack(spacing: 20) {
        LegacyNotificationPermissionsContent()
        LegacyNotificationScheduleContent()
        LegacySilentPeriodContent()
    }
    .environmentObject(SettingsManager.shared)
    .padding()
}
