import SwiftUI

// MARK: - 通知权限详细视图
struct NotificationPermissionsDetailView: View {
    @EnvironmentObject private var viewModel: SettingsViewModel
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 通知权限状态卡片
                SettingsCard(
                    title: "通知权限管理",
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
                                get: { viewModel.enableNotifications },
                                set: { enabled in
                                    Task {
                                        viewModel.send(.updateEnableNotifications(enabled))
                                    }
                                }
                            )
                        )
                        
                        if viewModel.enableNotifications {
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
                
                // 系统设置快捷方式
                if !viewModel.enableNotifications {
                    SettingsCard(
                        title: "系统设置",
                        icon: "gear",
                        iconColor: .gray,
                        description: "在系统设置中管理通知权限"
                    ) {
                        SettingsGroup {
                            Button(action: {
                                openSystemNotificationSettings()
                            }) {
                                HStack {
                                    Image(systemName: "arrow.up.right.square.fill")
                                        .foregroundColor(.blue)
                                    Text("打开系统通知设置")
                                        .foregroundColor(.primary)
                                    Spacer()
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .navigationTitle("通知权限")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
    
    private func openSystemNotificationSettings() {
        #if os(iOS)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
        #endif
    }
}

// MARK: - 提醒时间详细视图
struct NotificationScheduleDetailView: View {
    @EnvironmentObject private var viewModel: SettingsViewModel
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 默认提醒时间设置
                SettingsCard(
                    title: "默认提醒时间",
                    icon: "clock.fill",
                    iconColor: .blue,
                    description: "设置新产品的默认提醒时间"
                ) {
                    SettingsGroup {
                        HStack {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.blue)
                                .frame(width: 28, height: 28)
                                .background(Color.blue.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("提醒时间")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.primary)
                                Text("新产品的默认提醒时间")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            DatePicker(
                                "",
                                selection: Binding(
                                    get: { viewModel.notificationTime },
                                    set: { time in
                                        Task {
                                            viewModel.send(.updateNotificationTime(time))
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
                
                // 提醒说明
                SettingsCard(
                    title: "提醒说明",
                    icon: "info.circle.fill",
                    iconColor: .blue,
                    description: "了解提醒功能的工作方式"
                ) {
                    SettingsGroup {
                        VStack(alignment: .leading, spacing: 12) {
                            NotificationInfoRow(
                                icon: "calendar.badge.clock",
                                title: "保修到期提醒",
                                description: "在产品保修期即将到期时发送提醒"
                            )

                            Divider()

                            NotificationInfoRow(
                                icon: "bell.badge",
                                title: "重要事件通知",
                                description: "接收产品相关的重要更新和提醒"
                            )

                            Divider()

                            NotificationInfoRow(
                                icon: "clock.arrow.circlepath",
                                title: "定期检查",
                                description: "系统会定期检查并发送相关提醒"
                            )
                        }
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .navigationTitle("提醒时间")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

// MARK: - 免打扰时段详细视图
struct SilentPeriodDetailView: View {
    @EnvironmentObject private var viewModel: SettingsViewModel
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 免打扰开关
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
                                get: { viewModel.enableSilentPeriod },
                                set: { enabled in
                                    Task {
                                        viewModel.send(.updateSilentPeriod(enabled))
                                    }
                                }
                            )
                        )
                    }
                }
                
                // 时间段设置
                if viewModel.enableSilentPeriod {
                    SettingsCard(
                        title: "时间段设置",
                        icon: "clock.circle.fill",
                        iconColor: .blue,
                        description: "设置免打扰的开始和结束时间"
                    ) {
                        SettingsGroup {
                            // 开始时间
                            HStack {
                                Image(systemName: "moon.stars.fill")
                                    .foregroundColor(.purple)
                                    .frame(width: 24)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("开始时间")
                                        .font(.system(size: 16, weight: .medium))
                                    Text("免打扰开始时间")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Text(formatTime(viewModel.silentStartTime))
                                    .foregroundColor(.secondary)
                            }
                            
                            Divider()
                            
                            // 结束时间
                            HStack {
                                Image(systemName: "sun.max.fill")
                                    .foregroundColor(.orange)
                                    .frame(width: 24)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("结束时间")
                                        .font(.system(size: 16, weight: .medium))
                                    Text("免打扰结束时间")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Text(formatTime(viewModel.silentEndTime))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .navigationTitle("免打扰时段")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
    
    private func formatTime(_ timeInterval: Double) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = (Int(timeInterval) % 3600) / 60
        return String(format: "%02d:%02d", hours, minutes)
    }
}

// MARK: - 信息行组件
struct NotificationInfoRow: View {
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

// MARK: - 通知历史详情视图
struct NotificationHistoryDetailView: View {
    @StateObject private var notificationService = EnhancedNotificationService.shared
    @State private var selectedCategory: String = "all"
    @State private var searchText = ""
    @State private var showingClearAlert = false

    var filteredNotifications: [NotificationRecord] {
        var notifications = notificationService.notificationHistory

        // 按分类筛选
        if selectedCategory != "all" {
            notifications = notifications.filter { $0.categoryId == selectedCategory }
        }

        // 按搜索文本筛选
        if !searchText.isEmpty {
            notifications = notifications.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.body.localizedCaseInsensitiveContains(searchText)
            }
        }

        return notifications.sorted { ($0.sentDate ?? Date.distantPast) > ($1.sentDate ?? Date.distantPast) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 搜索和筛选栏
            VStack(spacing: 12) {
                // 搜索框
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)

                    TextField("搜索通知...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .cornerRadius(8)

                // 分类筛选
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        NotificationFilterChip(
                            title: "全部",
                            isSelected: selectedCategory == "all"
                        ) {
                            selectedCategory = "all"
                        }

                        ForEach(notificationService.notificationCategories, id: \.id) { category in
                            NotificationFilterChip(
                                title: category.name,
                                isSelected: selectedCategory == category.id
                            ) {
                                selectedCategory = category.id
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))

            Divider()

            // 通知列表
            if filteredNotifications.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "bell.slash")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)

                    Text(searchText.isEmpty ? "暂无通知记录" : "未找到匹配的通知")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    if !searchText.isEmpty {
                        Text("尝试调整搜索条件或选择不同的分类")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemGroupedBackground))
            } else {
                List {
                    ForEach(filteredNotifications) { notification in
                        NotificationHistoryRow(notification: notification)
                    }
                    .onDelete(perform: deleteNotifications)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("通知历史")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            SwiftUI.ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(action: {
                        showingClearAlert = true
                    }) {
                        Label("清空历史", systemImage: "trash")
                    }
                    .disabled(notificationService.notificationHistory.isEmpty)

                    Button(action: {
                        Task {
                            await notificationService.refreshNotificationHistory()
                        }
                    }) {
                        Label("刷新", systemImage: "arrow.clockwise")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .alert("清空通知历史", isPresented: $showingClearAlert) {
            Button("取消", role: .cancel) { }
            Button("清空", role: .destructive) {
                Task {
                    await notificationService.clearNotificationHistory()
                }
            }
        } message: {
            Text("此操作将删除所有通知历史记录，且无法撤销。")
        }
        .task {
            await notificationService.loadNotificationHistoryAsync()
        }
    }

    private func deleteNotifications(at offsets: IndexSet) {
        let notificationsToDelete = offsets.map { filteredNotifications[$0] }
        Task {
            await notificationService.deleteNotifications(notificationsToDelete)
        }
    }
}

// MARK: - 通知历史行组件
struct NotificationHistoryRow: View {
    let notification: NotificationRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // 通知图标
                Image(systemName: iconForCategory(notification.categoryId))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(colorForCategory(notification.categoryId))
                    .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(notification.title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Text(notification.body)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(formatDate(notification.sentDate))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if notification.isRead {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    } else {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 8, height: 8)
                    }
                }
            }

            // 状态指示器
            HStack(spacing: 8) {
                StatusBadge(
                    text: categoryName(notification.categoryId),
                    color: colorForCategory(notification.categoryId)
                )

                if notification.actionTaken {
                    StatusBadge(text: "已处理", color: .green)
                }

                Spacer()
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    private func iconForCategory(_ categoryId: String) -> String {
        switch categoryId {
        case "warranty": return "shield.checkered"
        case "maintenance": return "wrench.and.screwdriver"
        case "ocr": return "doc.text.viewfinder"
        case "sync": return "icloud.and.arrow.up"
        default: return "bell"
        }
    }

    private func colorForCategory(_ categoryId: String) -> Color {
        switch categoryId {
        case "warranty": return .orange
        case "maintenance": return .blue
        case "ocr": return .purple
        case "sync": return .green
        default: return .gray
        }
    }

    private func categoryName(_ categoryId: String) -> String {
        switch categoryId {
        case "warranty": return "保修"
        case "maintenance": return "维护"
        case "ocr": return "OCR"
        case "sync": return "同步"
        default: return "通知"
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - 状态徽章组件
struct StatusBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(4)
    }
}

// MARK: - 通知分类管理视图
struct NotificationCategoryManagementView: View {
    @StateObject private var notificationService = EnhancedNotificationService.shared
    @State private var showingAddCategory = false
    @State private var editingCategory: NotificationCategory?

    var body: some View {
        List {
            Section {
                ForEach(notificationService.notificationCategories) { category in
                    NotificationCategoryRow(
                        category: category,
                        onEdit: { editingCategory = category },
                        onToggle: { isEnabled in
                            Task {
                                await notificationService.updateCategoryEnabled(category.id, enabled: isEnabled)
                            }
                        }
                    )
                }
                .onDelete(perform: deleteCategories)
            } header: {
                Text("通知分类")
            } footer: {
                Text("管理不同类型的通知分类，可以为每个分类设置不同的提醒方式。")
            }

            Section {
                Button(action: {
                    showingAddCategory = true
                }) {
                    Label("添加新分类", systemImage: "plus.circle.fill")
                        .foregroundColor(.accentColor)
                }
            }
        }
        .navigationTitle("通知分类")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .sheet(isPresented: $showingAddCategory) {
            NotificationCategoryEditView(category: nil) { newCategory in
                Task {
                    await notificationService.addNotificationCategory(newCategory)
                }
            }
        }
        .sheet(item: $editingCategory) { category in
            NotificationCategoryEditView(category: category) { updatedCategory in
                Task {
                    await notificationService.updateNotificationCategory(updatedCategory)
                }
            }
        }
    }

    private func deleteCategories(at offsets: IndexSet) {
        let categoriesToDelete = offsets.map { notificationService.notificationCategories[$0] }
        Task {
            await notificationService.deleteNotificationCategories(categoriesToDelete)
        }
    }
}

// MARK: - 通知分类行组件 (使用 NotificationStatisticsView.swift 中的定义)

// MARK: - 筛选芯片组件
struct NotificationFilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                #if os(macOS)
                .background(isSelected ? Color.accentColor : Color(nsColor: .windowBackgroundColor))
                #else
                .background(isSelected ? Color.accentColor : Color(.systemGray5))
                #endif
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 通知分类编辑视图
struct NotificationCategoryEditView: View {
    let category: NotificationCategory?
    let onSave: (NotificationCategory) -> Void

    @State private var name: String
    @State private var description: String
    @State private var isEnabled: Bool
    @State private var soundEnabled: Bool
    @State private var badgeEnabled: Bool
    @State private var alertEnabled: Bool

    @Environment(\.dismiss) private var dismiss

    init(category: NotificationCategory?, onSave: @escaping (NotificationCategory) -> Void) {
        self.category = category
        self.onSave = onSave

        _name = State(initialValue: category?.name ?? "")
        _description = State(initialValue: category?.description ?? "")
        _isEnabled = State(initialValue: category?.isEnabled ?? true)
        _soundEnabled = State(initialValue: category?.soundEnabled ?? true)
        _badgeEnabled = State(initialValue: category?.badgeEnabled ?? true)
        _alertEnabled = State(initialValue: category?.alertEnabled ?? true)
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("分类名称", text: $name)
                    TextField("描述（可选）", text: $description, axis: .vertical)
                        .lineLimit(2...4)
                } header: {
                    Text("基本信息")
                }

                Section {
                    Toggle("启用此分类", isOn: $isEnabled)

                    if isEnabled {
                        Toggle("声音提醒", isOn: $soundEnabled)
                        Toggle("角标显示", isOn: $badgeEnabled)
                        Toggle("横幅通知", isOn: $alertEnabled)
                    }
                } header: {
                    Text("通知设置")
                } footer: {
                    Text("选择此分类通知的显示方式")
                }
            }
            .navigationTitle(category == nil ? "新建分类" : "编辑分类")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                SwiftUI.ToolbarItem(placement: .topBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }

                SwiftUI.ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
                        saveCategory()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func saveCategory() {
        let newCategory = NotificationCategory(
            id: category?.id ?? UUID().uuidString,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
            isEnabled: isEnabled,
            soundEnabled: soundEnabled,
            badgeEnabled: badgeEnabled,
            alertEnabled: alertEnabled
        )

        onSave(newCategory)
        dismiss()
    }
}

#Preview {
    NavigationStack {
        NotificationPermissionsDetailView()
            .environmentObject(SettingsViewModel(viewContext: PersistenceController.preview.container.viewContext))
    }
}
