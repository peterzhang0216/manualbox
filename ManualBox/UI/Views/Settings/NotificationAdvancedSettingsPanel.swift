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
                Text(NSLocalizedString("Notification Settings", comment: ""))
                    .font(.title2).bold()
                    .padding(.top, 24)
                    .foregroundColor(.accentColor)
                
                Divider().background(Color.accentColor.opacity(0.3))
                
                // 免打扰时段设置
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        Image(systemName: "moon.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.accentColor)
                            .frame(width: 36, height: 36)
                            .background(Color.accentColor.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        
                        Text(NSLocalizedString("Silent Period", comment: ""))
                            .font(.headline)
                        
                        Spacer()
                        
                        Toggle("", isOn: Binding(
                            get: { settingsViewModel.enableSilentPeriod },
                            set: { enabled in
                                Task {
                                    await settingsViewModel.send(.updateSilentPeriod(enabled))
                                }
                            }
                        ))
                            .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                    }
                    
                    if settingsViewModel.enableSilentPeriod {
                        VStack(spacing: 12) {
                            HStack {
                                Text(NSLocalizedString("Start Time", comment: ""))
                                    .foregroundColor(.secondary)
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
                                Text(NSLocalizedString("End Time", comment: ""))
                                    .foregroundColor(.secondary)
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
                        .padding()
                        .background(Color.secondary.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    
                    Text(NSLocalizedString("Notifications will be silenced during this period", comment: ""))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.secondary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                Spacer()
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
            .frame(maxWidth: 600, alignment: .leading)
        }
    }
}

#Preview {
    NotificationAdvancedSettingsPanel()
        .environmentObject(SettingsViewModel(viewContext: PersistenceController.preview.container.viewContext))
}