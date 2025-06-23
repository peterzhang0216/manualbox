import SwiftUI

// MARK: - 通知高级设置面板
struct NotificationAdvancedSettingsPanel: View {
    @AppStorage("silentStartTime") private var silentStartTime: Double = 22 * 3600 // 22:00
    @AppStorage("silentEndTime") private var silentEndTime: Double = 8 * 3600 // 08:00
    @AppStorage("enableSilentPeriod") private var enableSilentPeriod: Bool = false
    @EnvironmentObject private var settingsViewModel: SettingsViewModel
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 页面标题
                HStack {
                    Image(systemName: "bell.badge.fill")
                        .font(.title2)
                        .foregroundColor(.orange)
                    Text("通知设置")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Spacer()
                }
                .padding(.top, 24)

                // 通知权限状态卡片
                SettingsCard(
                    title: "通知权限",
                    icon: "bell.circle.fill",
                    iconColor: .orange,
                    description: "管理应用的通知权限和基本设置"
                ) {
                    SettingsGroup {
                        SettingsToggle(
                            title: "启用通知",
                            description: "允许应用发送通知提醒",
                            icon: "bell.fill",
                            iconColor: .orange,
                            isOn: Binding(
                                get: { settingsViewModel.enableNotifications },
                                set: { enabled in
                                    Task {
                                        await settingsViewModel.send(.updateEnableNotifications(enabled))
                                    }
                                }
                            )
                        )

                        if settingsViewModel.enableNotifications {
                            Divider()
                                .padding(.vertical, 8)

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
                                            Task {
                                                await settingsViewModel.send(.updateNotificationTime(time))
                                            }
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

                // 免打扰时段设置卡片
                SettingsCard(
                    title: "免打扰时段",
                    icon: "moon.fill",
                    iconColor: .purple,
                    description: "在指定时间段内静音所有通知"
                ) {
                    SettingsGroup {
                        SettingsToggle(
                            title: "启用免打扰",
                            description: "在指定时间段内不发送通知",
                            icon: "moon.fill",
                            iconColor: .purple,
                            isOn: Binding(
                                get: { settingsViewModel.enableSilentPeriod },
                                set: { enabled in
                                    Task {
                                        await settingsViewModel.send(.updateSilentPeriod(enabled))
                                    }
                                }
                            )
                        )

                        if settingsViewModel.enableSilentPeriod {
                            Divider()
                                .padding(.vertical, 8)

                            VStack(spacing: 16) {
                                HStack {
                                    Image(systemName: "sunrise.fill")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.orange)
                                        .frame(width: 28, height: 28)
                                        .background(Color.orange.opacity(0.1))
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

                                    DatePicker(
                                        "",
                                        selection: Binding(
                                            get: { Date(timeIntervalSince1970: settingsViewModel.silentStartTime) },
                                            set: { time in
                                                Task {
                                                    await settingsViewModel.send(.updateSilentStartTime(time.timeIntervalSince1970))
                                                }
                                            }
                                        ),
                                        displayedComponents: .hourAndMinute
                                    )
                                    .labelsHidden()
                                }

                                HStack {
                                    Image(systemName: "sunset.fill")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.red)
                                        .frame(width: 28, height: 28)
                                        .background(Color.red.opacity(0.1))
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

                                    DatePicker(
                                        "",
                                        selection: Binding(
                                            get: { Date(timeIntervalSince1970: settingsViewModel.silentEndTime) },
                                            set: { time in
                                                Task {
                                                    await settingsViewModel.send(.updateSilentEndTime(time.timeIntervalSince1970))
                                                }
                                            }
                                        ),
                                        displayedComponents: .hourAndMinute
                                    )
                                    .labelsHidden()
                                }
                            }

                            // 提示信息
                            HStack {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(.blue)
                                Text("在此时间段内，应用将不会发送任何通知提醒")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 8)
                        }
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
            .frame(maxWidth: 700, alignment: .leading)
        }
    }
}

#Preview {
    NotificationAdvancedSettingsPanel()
        .environmentObject(SettingsViewModel(viewContext: PersistenceController.preview.container.viewContext))
}