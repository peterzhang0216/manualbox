import SwiftUI
#if os(iOS)
import UIKit
import CoreData
#endif


// 导入自定义组件
import WebKit

// 由于独立文件组件已创建，此处确保导入它们
// SettingRow, ThemePickerView 和 AppInfoView 已被移到单独的文件中

struct SettingsView: View {
    @AppStorage("defaultWarrantyPeriod") private var defaultWarrantyPeriod = 12
    @AppStorage("enableOCRByDefault") private var enableOCRByDefault = true
    @EnvironmentObject private var notificationManager: AppNotificationManager
    @Environment(\.colorScheme) private var colorScheme
    @State private var showResetAlert = false
    @State private var showPrivacySheet = false
    @State private var showAgreementSheet = false
    @State private var selectedPanel: SettingsPanel = .notification
    
    enum SettingsPanel: Hashable {
        case notification
        case theme
        case data
        case about
    }
    
    var body: some View {
        #if os(macOS)
        NavigationSplitView {
            List(selection: $selectedPanel) {
                Section(header: Text("设置")) {
                    NavigationLink(value: SettingsPanel.notification) {
                        Label("通知与提醒", systemImage: "bell.badge.fill")
                    }
                    NavigationLink(value: SettingsPanel.theme) {
                        Label("外观与主题", systemImage: "paintbrush")
                    }
                    NavigationLink(value: SettingsPanel.data) {
                        Label("数据与默认", systemImage: "tray.full")
                    }
                    NavigationLink(value: SettingsPanel.about) {
                        Label("关于与支持", systemImage: "info.circle")
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("设置")
        } detail: {
            switch selectedPanel {
            case .notification:
                NotificationAdvancedSettingsPanel()
            case .theme:
                ThemeSettingsPanel()
            case .data:
                DataSettingsPanel(
                    defaultWarrantyPeriod: $defaultWarrantyPeriod,
                    enableOCRByDefault: $enableOCRByDefault
                )
            case .about:
                AboutSettingsPanel(
                    showPrivacySheet: $showPrivacySheet,
                    showAgreementSheet: $showAgreementSheet
                )
            }
        }
        #else
        NavigationStack {
            List {
                Section(header: Text("设置")) {
                    NavigationLink(destination: NotificationSettingsView()) {
                        Label("通知与提醒", systemImage: "bell.badge.fill")
                    }
                    NavigationLink(destination: ThemeSettingsView()) {
                        Label("外观与主题", systemImage: "paintbrush")
                    }
                    NavigationLink(destination: DataSettingsView()) {
                        Label("数据与默认", systemImage: "tray.full")
                    }
                    NavigationLink(destination: AboutSettingsPanel(
                        showPrivacySheet: $showPrivacySheet,
                        showAgreementSheet: $showAgreementSheet
                    )) {
                        Label("关于与支持", systemImage: "info.circle")
                    }
                }
            }
            .navigationTitle("设置")
        }
        #endif
    }
}

// MARK: - 主题设置面板
private struct ThemeSettingsPanel: View {
    @AppStorage("appTheme") private var appTheme: String = "system"
    @AppStorage("accentColor") private var accentColor: String = "accentColor"
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(NSLocalizedString("Appearance & Theme", comment: ""))
                    .font(.title2).bold()
                    .padding(.top, 24)
                    .foregroundColor(.accentColor)
                
                Divider().background(Color.accentColor.opacity(0.3))
                
                // 主题设置卡片
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        Image(systemName: "circle.lefthalf.filled")
                            .font(.system(size: 22))
                            .foregroundColor(.accentColor)
                            .frame(width: 36, height: 36)
                            .background(Color.accentColor.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        
                        Text(NSLocalizedString("Theme Mode", comment: ""))
                            .font(.headline)
                        
                        Spacer()
                    }
                    
                    ThemePickerView()
                        .padding(.leading, 8)
                }
                .padding()
                .background(Color.secondary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // 主题色设置卡片
                AccentColorPickerView()
                
                // 语言设置卡片
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        Image(systemName: "globe")
                            .font(.system(size: 22))
                            .foregroundColor(.accentColor)
                            .frame(width: 36, height: 36)
                            .background(Color.accentColor.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        
                        Text(NSLocalizedString("Language", comment: ""))
                            .font(.headline)
                        
                        Spacer()
                    }
                    
                    LanguagePickerView()
                        .padding(.leading, 8)
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

// MARK: - 数据与默认设置面板
private struct DataSettingsPanel: View {
    @Binding var defaultWarrantyPeriod: Int
    @Binding var enableOCRByDefault: Bool
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(NSLocalizedString("Data & Defaults", comment: ""))
                    .font(.title2).bold()
                    .padding(.top, 24)
                    .foregroundColor(.accentColor)
                
                Divider().background(Color.accentColor.opacity(0.3))
                
                // 默认值设置卡片
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.accentColor)
                            .frame(width: 36, height: 36)
                            .background(Color.accentColor.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        
                        Text(NSLocalizedString("Default Settings", comment: ""))
                            .font(.headline)
                        
                        Spacer()
                    }
                    
                    // 保修期默认设置卡片
                    VStack(alignment: .leading, spacing: 12) {
                        WarrantyDefaultView(period: $defaultWarrantyPeriod)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(Color.secondary.opacity(0.03))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    
                    // OCR默认设置卡片
                    VStack(alignment: .leading, spacing: 12) {
                        OCRDefaultView(enabled: $enableOCRByDefault)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(Color.secondary.opacity(0.03))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .padding()
                .background(Color.secondary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // 数据管理卡片
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "externaldrive.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.accentColor)
                            .frame(width: 36, height: 36)
                            .background(Color.accentColor.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        
                        Text(NSLocalizedString("Data Management", comment: ""))
                            .font(.headline)
                        
                        Spacer()
                    }
                    
                    NavigationLink(destination: DataExportView()) {
                        SettingRow(
                            icon: "arrow.up.doc.fill",
                            iconColor: .green,
                            title: NSLocalizedString("Export Data", comment: ""),
                            subtitle: NSLocalizedString("Export products, categories, and tags", comment: "")
                        )
                    }
                    .buttonStyle(.plain)
                    
                    NavigationLink(destination: DataImportView()) {
                        SettingRow(
                            icon: "arrow.down.doc.fill",
                            iconColor: .blue,
                            title: NSLocalizedString("Import Data", comment: ""),
                            subtitle: NSLocalizedString("Import products, categories, and tags", comment: "")
                        )
                    }
                    .buttonStyle(.plain)
                    
                    NavigationLink(destination: DataBackupView()) {
                        SettingRow(
                            icon: "externaldrive.fill",
                            iconColor: .purple,
                            title: NSLocalizedString("Data Backup & Restore", comment: ""),
                            subtitle: NSLocalizedString("Local or iCloud backup/restore", comment: "")
                        )
                    }
                    .buttonStyle(.plain)
                    
                    Button(role: .destructive) {
                        // showResetAlert = true
                    } label: {
                        SettingRow(
                            icon: "trash.fill",
                            iconColor: .red,
                            title: NSLocalizedString("Reset App Data", comment: ""),
                            subtitle: NSLocalizedString("Clear all local data, cannot be recovered", comment: ""),
                            warning: true
                        )
                    }
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

// MARK: - 关于与支持面板
private struct AboutSettingsPanel: View {
    @Binding var showPrivacySheet: Bool
    @Binding var showAgreementSheet: Bool
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(NSLocalizedString("About & Support", comment: ""))
                    .font(.title2).bold()
                    .padding(.top, 24)
                    .foregroundColor(.accentColor)
                
                Divider().background(Color.accentColor.opacity(0.3))
                
                // 应用信息卡片
                VStack(alignment: .leading, spacing: 16) {
                    AppInfoView()
                }
                .padding()
                .background(Color.secondary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // 法律与政策卡片
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.accentColor)
                            .frame(width: 36, height: 36)
                            .background(Color.accentColor.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        
                        Text(NSLocalizedString("Legal & Policies", comment: ""))
                            .font(.headline)
                        
                        Spacer()
                    }
                    
                    Button { showPrivacySheet = true } label: {
                        SettingRow(
                            icon: "lock.shield.fill",
                            iconColor: .purple,
                            title: NSLocalizedString("Privacy Policy", comment: ""),
                            subtitle: NSLocalizedString("View app privacy policy", comment: "")
                        )
                    }
                    .buttonStyle(.plain)
                    .sheet(isPresented: $showPrivacySheet) {
                        PolicySheetView(title: NSLocalizedString("Privacy Policy", comment: ""), url: URL(string: "https://yourdomain.com/privacy")!)
                    }
                    
                    Button { showAgreementSheet = true } label: {
                        SettingRow(
                            icon: "doc.text.fill",
                            iconColor: .blue,
                            title: NSLocalizedString("User Agreement", comment: ""),
                            subtitle: NSLocalizedString("View app user agreement", comment: "")
                        )
                    }
                    .buttonStyle(.plain)
                    .sheet(isPresented: $showAgreementSheet) {
                        PolicySheetView(title: NSLocalizedString("User Agreement", comment: ""), url: URL(string: "https://yourdomain.com/agreement")!)
                    }
                }
                .padding()
                .background(Color.secondary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // 更新与支持卡片
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 22))
                            .foregroundColor(.accentColor)
                            .frame(width: 36, height: 36)
                            .background(Color.accentColor.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        
                        Text(NSLocalizedString("Updates & Support", comment: ""))
                            .font(.headline)
                        
                        Spacer()
                    }
                    
                    Button { checkForUpdate() } label: {
                        SettingRow(
                            icon: "arrow.triangle.2.circlepath",
                            iconColor: .green,
                            title: NSLocalizedString("Check for Updates", comment: ""),
                            subtitle: NSLocalizedString("Go to the latest version download page", comment: "")
                        )
                    }
                    .buttonStyle(.plain)
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

// 保修期默认设置视图
private struct WarrantyDefaultView: View {
    @Binding var period: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 标题部分使用更明显的设计
            Label("默认保修期", systemImage: "clock.fill")
                .foregroundColor(.accentColor)
                .font(.headline)
            
            // 数值展示部分
            HStack(alignment: .center) {
                Text("\(period)")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.accentColor)
                    .frame(minWidth: 30, alignment: .trailing)
                
                Text("个月")
                    .font(.body)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // 修复 Stepper 组件，明确显示文本
                Stepper(
                    value: $period, 
                    in: 0...60,
                    label: { Text("设置保修期").foregroundColor(.clear).frame(width: 0) }
                )
            }
            
            // 说明文字
            Text("新增商品时的默认保修期限")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// OCR 默认设置视图
private struct OCRDefaultView: View {
    @Binding var enabled: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 标题部分
            Label("OCR 文字识别", systemImage: "doc.text.viewfinder")
                .foregroundColor(.orange)
                .font(.headline)
            
            // 开关组件，更明确的显示
            HStack {
                Toggle(isOn: $enabled) {
                    Text("默认开启文字识别")
                        .font(.body)
                }
                .toggleStyle(SwitchToggleStyle(tint: .orange))
            }
            
            // 说明文字
            Text("添加说明书时自动识别文字内容")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// 使用已经抽离出去的 SettingRow 组件，删除了重复定义

// 使用已经抽离出去的 ThemePickerView 组件，删除了重复定义

// ThemeButton 组件已移至 ThemePickerView.swift 文件中
// 主题色自定义
private struct AccentColorPickerView: View {
    @AppStorage("accentColor") private var accentColor: String = "accentColor"
    
    // 添加完整的颜色数组，确保包含所有常用系统颜色
    let colors: [(key: String, color: Color, name: String)] = [
        ("accentColor", .accentColor, "系统"),
        ("blue", .blue, "蓝色"),
        ("green", .green, "绿色"),
        ("orange", .orange, "橙色"),
        ("pink", .pink, "粉色"),
        ("purple", .purple, "紫色"),
        ("red", .red, "红色"),
        ("teal", .teal, "青色"),
        ("yellow", .yellow, "黄色"),
        ("indigo", .indigo, "靛蓝")
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "paintpalette.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.accentColor)
                    .frame(width: 36, height: 36)
                    .background(Color.accentColor.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                
                Text(NSLocalizedString("Theme Color", comment: ""))
                    .font(.headline)
                
                Spacer()
            }
            
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 60, maximum: 80))], spacing: 12) {
                ForEach(colors, id: \.key) { item in
                    VStack(spacing: 4) {
                        ZStack {
                            Circle()
                                .fill(item.color)
                                .frame(width: 32, height: 32)
                                .shadow(color: item.color.opacity(0.3), radius: 2, x: 0, y: 1)
                            
                            if accentColor == item.key {
                                Circle()
                                    .strokeBorder(Color.white, lineWidth: 2)
                                    .frame(width: 16, height: 16)
                            }
                        }
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(item.color.opacity(0.15))
                                .frame(width: 44, height: 44)
                        )
                        .overlay(
                            Circle()
                                .stroke(accentColor == item.key ? item.color : Color.clear, lineWidth: 2)
                                .frame(width: 44, height: 44)
                        )
                        
                        Text(NSLocalizedString(item.name, comment: ""))
                            .font(.caption2)
                            .foregroundColor(accentColor == item.key ? item.color : .secondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            accentColor = item.key
                        }
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .padding()
        .background(Color.secondary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
// 语言切换视图
private struct LanguagePickerView: View {
    @AppStorage("appLanguage") private var appLanguage: String = "system"
    @Environment(\.scenePhase) private var scenePhase
    
    let languages = [
        ("system", "跟随系统", "globe"),
        ("zh-Hans", "中文", "character.textbox"),
        ("en", "English", "textformat.abc")
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(NSLocalizedString("Language", comment: ""))
                .font(.headline)
                .foregroundColor(.accentColor)
            
            VStack(spacing: 8) {
                ForEach(languages, id: \.0) { lang in
                    LanguageRow(
                        id: lang.0,
                        title: NSLocalizedString(lang.0 == "system" ? "Follow System" : (lang.0 == "zh-Hans" ? "Chinese" : "English"), comment: ""),
                        icon: lang.2,
                        isSelected: appLanguage == lang.0
                    )
                    .onTapGesture {
                        if appLanguage != lang.0 {
                            appLanguage = lang.0
                            setAppLanguage(lang.0)
                            
                            // 应用语言变更并强制刷新界面
                            #if os(iOS)
                            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                                windowScene.windows.forEach { 
                                    $0.rootViewController = UIHostingController(
                                        rootView: MainTabView().environmentObject(AppNotificationManager())
                                    )
                                }
                            }
                            #endif
                        }
                    }
                    
                    if lang.0 != languages.last?.0 {
                        Divider()
                            .padding(.leading, 32)
                    }
                }
            }
            .padding(.vertical, 4)
            .background(Color.secondary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(.vertical, 8)
    }
}

// 语言行视图
private struct LanguageRow: View {
    let id: String
    let title: String
    let icon: String
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(isSelected ? .accentColor : .secondary)
                .frame(width: 24, height: 24)
            
            Text(title)
                .foregroundColor(isSelected ? .primary : .secondary)
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundColor(.accentColor)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .contentShape(Rectangle())
    }
}
#if os(macOS)
private func setAppLanguage(_ code: String) {
    guard code != "system" else {
        UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        NSApp.windows.forEach { $0.contentView?.needsLayout = true; $0.contentView?.setNeedsDisplay($0.contentView?.bounds ?? .zero) }
        return
    }
    UserDefaults.standard.set([code], forKey: "AppleLanguages")
    NSApp.windows.forEach { $0.contentView?.needsLayout = true; $0.contentView?.setNeedsDisplay($0.contentView?.bounds ?? .zero) }
}
#else
private func setAppLanguage(_ code: String) {
    guard code != "system" else {
        UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        return
    }
    UserDefaults.standard.set([code], forKey: "AppleLanguages")
}
#endif

// 数据导入视图现已实现，已移至 DataImportView.swift 文件
// private struct DataImportView: View {
//     var body: some View {
//         VStack(spacing: 24) {
//             Image(systemName: "arrow.down.doc.fill")
//                 .font(.system(size: 48))
//                 .foregroundColor(.blue)
//             Text("数据导入功能开发中…")
//                 .font(.title3)
//                 .foregroundColor(.secondary)
//         }
//         .frame(maxWidth: .infinity, maxHeight: .infinity)
//     }
// }
// 数据备份与恢复视图占位
private struct DataBackupView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "externaldrive.fill")
                .font(.system(size: 48))
                .foregroundColor(.purple)
            Text("数据备份与恢复功能开发中…")
                .font(.title3)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
// 通知设置行美化与交互
private struct NotificationSettingsRowView: View {
    @EnvironmentObject private var notificationManager: AppNotificationManager
    var body: some View {
        // 只用 NavigationLink，且 chevron 只出现一次
        NavigationLink(destination: NotificationAdvancedSettingsPanel()) {
            HStack(spacing: 16) {
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.blue)
                    .frame(width: 36, height: 36)
                    .background(Color.blue.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 2) {
                    Text("保修与资产提醒")
                        .font(.body)
                    Text("多渠道、静默时段、定制提醒")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                // 不再手动加 chevron，系统自动加
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }
}

private struct NotificationAdvancedSettingsPanel: View {
    @AppStorage("warrantyAdvanceDays") private var warrantyAdvanceDays: Int = 7
    @AppStorage("maintenanceIntervalMonths") private var maintenanceIntervalMonths: Int = 12
    @AppStorage("notificationChannel") private var notificationChannel: String = "system"
    @AppStorage("notificationQuietStart") private var quietStart: Int = 22
    @AppStorage("notificationQuietEnd") private var quietEnd: Int = 8
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(NSLocalizedString("Notification Settings", comment: ""))
                    .font(.title2).bold()
                    .padding(.top, 24)
                    .foregroundColor(.accentColor)
                
                Divider().background(Color.accentColor.opacity(0.3))
                
                // 保修到期提醒卡片
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        Image(systemName: "bell.badge.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.blue)
                            .frame(width: 36, height: 36)
                            .background(Color.blue.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        
                        Text("保修到期提醒")
                            .font(.headline)
                        
                        Spacer()
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("提前")
                                .foregroundColor(.secondary)
                            Text("\(warrantyAdvanceDays)")
                                .font(.title3)
                                .foregroundColor(.blue)
                                .frame(width: 40)
                            Text("天推送通知")
                                .foregroundColor(.secondary)
                            Spacer()
                            // 修复 Stepper 组件
                            Stepper(
                                value: $warrantyAdvanceDays, 
                                in: 1...90,
                                label: { Text("调整提醒天数").foregroundColor(.clear).frame(width: 0) }
                            )
                        }
                        
                        Text("设置保修到期前多少天收到提醒")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                }
                .padding()
                .background(Color.secondary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // 维修进度推送卡片
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        Image(systemName: "wrench.and.screwdriver.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.orange)
                            .frame(width: 36, height: 36)
                            .background(Color.orange.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        
                        Text("维修进度推送")
                            .font(.headline)
                        
                        Spacer()
                    }
                    
                    Toggle("开启维修进度推送", isOn: .constant(true))
                        .disabled(true)
                        .padding(.horizontal, 8)
                    
                    Text("如有维修记录，自动推送进度/完成通知")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                }
                .padding()
                .background(Color.secondary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // 资产巡检卡片
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 22))
                            .foregroundColor(.purple)
                            .frame(width: 36, height: 36)
                            .background(Color.purple.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        
                        Text("资产定期巡检/保养")
                            .font(.headline)
                        
                        Spacer()
                    }
                    
                    Picker("巡检/保养周期", selection: $maintenanceIntervalMonths) {
                        Text("每年").tag(12)
                        Text("每半年").tag(6)
                        Text("每季度").tag(3)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 8)
                }
                .padding()
                .background(Color.secondary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // 通知方式卡片
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.teal)
                            .frame(width: 36, height: 36)
                            .background(Color.teal.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        
                        Text("通知方式")
                            .font(.headline)
                        
                        Spacer()
                    }
                    
                    Picker("推送渠道", selection: $notificationChannel) {
                        Text("系统通知").tag("system")
                        Text("邮件").tag("email")
                        Text("日历事件").tag("calendar")
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 8)
                }
                .padding()
                .background(Color.secondary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // 静默时段卡片
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        Image(systemName: "moon.stars.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.indigo)
                            .frame(width: 36, height: 36)
                            .background(Color.indigo.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        
                        Text("静默时段")
                            .font(.headline)
                        
                        Spacer()
                    }
                    
                    HStack {
                        Text("从")
                            .foregroundColor(.secondary)
                        Picker("开始", selection: $quietStart) {
                            ForEach(0..<24) { Text(String(format: "%02d:00", $0)) }
                        }
                        .frame(width: 80)
                        Text("到")
                            .foregroundColor(.secondary)
                        Picker("结束", selection: $quietEnd) {
                            ForEach(0..<24) { Text(String(format: "%02d:00", $0)) }
                        }
                        .frame(width: 80)
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    
                    Text("静默时段内不推送通知")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
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

// 数据重置实现
private func resetAllData() {
    // TODO: 实现数据重置逻辑，如清空 CoreData、UserDefaults 等
}

private func checkForUpdate() {
    #if os(macOS)
    if let url = URL(string: "https://github.com/yourusername/ManualBox/releases") {
        NSWorkspace.shared.open(url)
    }
    #else
    if let url = URL(string: "https://github.com/yourusername/ManualBox/releases") {
        UIApplication.shared.open(url)
    }
    #endif
}

// MARK: - 隐私政策/用户协议弹窗
private struct PolicySheetView: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let url: URL
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 22))
                }
            }
            .padding()
            
            Divider()
            
            if #available(macOS 13.0, iOS 16.0, *) {
                WebView(url: url)
                    .overlay(alignment: .topTrailing) {
                        Button {
                            #if os(macOS)
                            NSWorkspace.shared.open(url)
                            #else
                            UIApplication.shared.open(url)
                            #endif
                        } label: {
                            Label("在浏览器中打开", systemImage: "safari.fill")
                                .labelStyle(.iconOnly)
                                .font(.system(size: 20))
                                .foregroundColor(.accentColor)
                        }
                        .buttonStyle(.plain)
                        .padding(12)
                    }
            } else {
                VStack(spacing: 16) {
                    Text("请在浏览器中查看：")
                        .foregroundColor(.secondary)
                    
                    Text(url.absoluteString)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.accentColor)
                        .textSelection(.enabled)
                        .multilineTextAlignment(.center)
                    
                    #if os(macOS)
                    Button("在浏览器中打开") {
                        NSWorkspace.shared.open(url)
                    }
                    .buttonStyle(.borderedProminent)
                    #else
                    Button("在浏览器中打开") {
                        UIApplication.shared.open(url)
                    }
                    .buttonStyle(.borderedProminent)
                    #endif
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 400, minHeight: 500)
    }
}

#if canImport(WebKit) && os(macOS)
import WebKit
struct WebView: NSViewRepresentable {
    let url: URL
    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.load(URLRequest(url: url))
        return webView
    }
    func updateNSView(_ nsView: WKWebView, context: Context) {}
}
#elseif canImport(WebKit) && os(iOS)
import WebKit
struct WebView: UIViewRepresentable {
    let url: URL
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.load(URLRequest(url: url))
        return webView
    }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
#endif

#Preview {
    NavigationView {
        SettingsView()
            .environmentObject(AppNotificationManager())
    }
}

// iOS 平台适配的设置视图
#if os(iOS)
struct ThemeSettingsView: View {
    var body: some View {
        Form {
            Section(header: Text("主题设置")) {
                ThemePickerView()
                AccentColorPickerView()
            }
        }
        .navigationTitle("外观与主题")
    }
}

struct DataSettingsView: View {
    @AppStorage("defaultWarrantyPeriod") private var defaultWarrantyPeriod = 12
    @AppStorage("enableOCRByDefault") private var enableOCRByDefault = true
    @State private var showResetAlert = false
    
    var body: some View {
        Form {
            Section(header: Text("默认设置")) {
                Stepper("默认保修期: \(defaultWarrantyPeriod) 个月", value: $defaultWarrantyPeriod, in: 0...120, step: 1)
                Toggle("自动识别说明书文字", isOn: $enableOCRByDefault)
                    .toggleStyle(SwitchToggleStyle())
            }
            
            Section(header: Text("数据管理")) {
                NavigationLink(destination: DataExportView()) {
                    Label("导出数据", systemImage: "arrow.up.doc")
                }
                
                NavigationLink(destination: DataImportView()) {
                    Label("导入数据", systemImage: "arrow.down.doc")
                }
                
                Button(action: { showResetAlert = true }) {
                    Label("重置所有数据", systemImage: "trash")
                        .foregroundColor(.red)
                }
            }
        }
        .navigationTitle("数据与默认")
        .alert(isPresented: $showResetAlert) {
            Alert(
                title: Text("确定要重置所有数据吗？"),
                message: Text("此操作将删除所有商品、分类、标签和维修记录，且无法恢复。"),
                primaryButton: .destructive(Text("重置")) {
                    resetAllData()
                },
                secondaryButton: .cancel(Text("取消"))
            )
        }
    }
    
    private func resetAllData() {
        let context = PersistenceController.shared.container.viewContext
        
        // 删除所有产品
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = Product.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        
        // 删除所有标签
        let tagFetchRequest: NSFetchRequest<NSFetchRequestResult> = Tag.fetchRequest()
        let tagDeleteRequest = NSBatchDeleteRequest(fetchRequest: tagFetchRequest)
        
        // 删除所有分类
        let categoryFetchRequest: NSFetchRequest<NSFetchRequestResult> = Category.fetchRequest()
        let categoryDeleteRequest = NSBatchDeleteRequest(fetchRequest: categoryFetchRequest)
        
        do {
            try context.execute(deleteRequest)
            try context.execute(tagDeleteRequest)
            try context.execute(categoryDeleteRequest)
            try context.save()
        } catch {
            print("重置数据失败: \(error.localizedDescription)")
        }
    }
}
#endif
