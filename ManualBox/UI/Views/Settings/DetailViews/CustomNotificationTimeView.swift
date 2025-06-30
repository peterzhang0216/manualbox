import SwiftUI

// MARK: - 自定义通知时间视图
struct CustomNotificationTimeView: View {
    @StateObject private var notificationService = EnhancedNotificationService.shared
    @State private var customTimes: [String: Date] = [:]
    @State private var showingAddTimeAlert = false
    @State private var newTimeName = ""
    @State private var newTime = Date()
    
    var body: some View {
        List {
            Section {
                ForEach(notificationService.notificationCategories) { category in
                    CustomTimeRow(
                        category: category,
                        customTime: customTimes[category.id],
                        onTimeChanged: { newTime in
                            customTimes[category.id] = newTime
                            saveCustomTimes()
                        }
                    )
                }
            } header: {
                Text("分类通知时间")
            } footer: {
                Text("为每个通知分类设置不同的默认提醒时间")
            }
            
            Section {
                ForEach(Array(customTimes.keys.filter { !isSystemCategory($0) }), id: \.self) { timeId in
                    if let time = customTimes[timeId] {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(timeId)
                                    .font(.system(size: 16, weight: .medium))
                                Text(formatTime(time))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            DatePicker(
                                "",
                                selection: Binding(
                                    get: { time },
                                    set: { newTime in
                                        customTimes[timeId] = newTime
                                        saveCustomTimes()
                                    }
                                ),
                                displayedComponents: .hourAndMinute
                            )
                            .labelsHidden()
                        }
                    }
                }
                .onDelete(perform: deleteCustomTimes)
                
                Button(action: {
                    showingAddTimeAlert = true
                }) {
                    Label("添加自定义时间", systemImage: "plus.circle.fill")
                        .foregroundColor(.accentColor)
                }
            } header: {
                Text("自定义时间")
            } footer: {
                Text("创建可重复使用的自定义通知时间")
            }
            
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    CustomTimeInfoRow(
                        icon: "clock.fill",
                        title: "默认时间",
                        description: "如果分类没有设置自定义时间，将使用系统默认时间"
                    )

                    CustomTimeInfoRow(
                        icon: "bell.badge",
                        title: "智能提醒",
                        description: "系统会根据产品类型和重要性自动调整提醒时间"
                    )

                    CustomTimeInfoRow(
                        icon: "moon.fill",
                        title: "免打扰时段",
                        description: "在免打扰时段内的通知将延迟到时段结束后发送"
                    )
                }
            } header: {
                Text("说明")
            }
        }
        .navigationTitle("自定义通知时间")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .alert("添加自定义时间", isPresented: $showingAddTimeAlert) {
            TextField("时间名称", text: $newTimeName)
            Button("取消", role: .cancel) {
                newTimeName = ""
            }
            Button("添加") {
                addCustomTime()
            }
            .disabled(newTimeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } message: {
            Text("为这个自定义时间输入一个名称")
        }
        .onAppear {
            loadCustomTimes()
        }
    }
    
    // MARK: - 私有方法
    
    private func isSystemCategory(_ categoryId: String) -> Bool {
        return notificationService.notificationCategories.contains { $0.id == categoryId }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func addCustomTime() {
        let trimmedName = newTimeName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedName.isEmpty {
            customTimes[trimmedName] = newTime
            saveCustomTimes()
            newTimeName = ""
            newTime = Date()
        }
    }
    
    private func deleteCustomTimes(at offsets: IndexSet) {
        let customTimeKeys = Array(customTimes.keys.filter { !isSystemCategory($0) })
        for index in offsets {
            if index < customTimeKeys.count {
                customTimes.removeValue(forKey: customTimeKeys[index])
            }
        }
        saveCustomTimes()
    }
    
    private func saveCustomTimes() {
        if let data = try? JSONEncoder().encode(customTimes) {
            UserDefaults.standard.set(data, forKey: "CustomNotificationTimes")
        }
    }
    
    private func loadCustomTimes() {
        if let data = UserDefaults.standard.data(forKey: "CustomNotificationTimes"),
           let times = try? JSONDecoder().decode([String: Date].self, from: data) {
            customTimes = times
        }
    }
}

// MARK: - 自定义时间行组件
struct CustomTimeRow: View {
    let category: NotificationCategory
    let customTime: Date?
    let onTimeChanged: (Date?) -> Void
    
    @State private var hasCustomTime: Bool
    @State private var selectedTime: Date
    
    init(category: NotificationCategory, customTime: Date?, onTimeChanged: @escaping (Date?) -> Void) {
        self.category = category
        self.customTime = customTime
        self.onTimeChanged = onTimeChanged
        
        _hasCustomTime = State(initialValue: customTime != nil)
        _selectedTime = State(initialValue: customTime ?? Date())
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(category.name)
                        .font(.system(size: 16, weight: .medium))
                    
                    if !category.description.isEmpty {
                        Text(category.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Toggle("", isOn: $hasCustomTime)
                    .labelsHidden()
                    .onChange(of: hasCustomTime) { enabled in
                        if enabled {
                            onTimeChanged(selectedTime)
                        } else {
                            onTimeChanged(nil)
                        }
                    }
            }
            
            if hasCustomTime {
                HStack {
                    Text("提醒时间")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    DatePicker(
                        "",
                        selection: $selectedTime,
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                    .onChange(of: selectedTime) { newTime in
                        onTimeChanged(newTime)
                    }
                }
                .padding(.leading, 16)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 信息行组件（如果不存在的话）
struct CustomTimeInfoRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.blue)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
    }
}

#Preview {
    NavigationStack {
        CustomNotificationTimeView()
    }
}
