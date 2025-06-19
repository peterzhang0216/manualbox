import Foundation
import SwiftUI

// MARK: - 统一本地化管理器
class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()

    @Published var currentLanguage: String = "auto"

    // 统一的本地化字典
    private let localizations: [String: [String: String]] = [
        "en": LocalizationData.english,
        "zh-Hans": LocalizationData.chinese
    ]

    private init() {
        // 从 UserDefaults 读取用户设置的语言
        currentLanguage = UserDefaults.standard.string(forKey: "app_language") ?? "auto"
    }

    // 设置语言
    func setLanguage(_ language: String) {
        currentLanguage = language
        UserDefaults.standard.set(language, forKey: "app_language")

        // 通知应用重新加载
        NotificationCenter.default.post(name: .languageChanged, object: nil)
    }

    // 获取当前语言代码
    var currentLanguageCode: String {
        switch currentLanguage {
        case "zh-Hans":
            return "zh-Hans"
        case "en":
            return "en"
        case "auto":
            return Locale.current.language.languageCode?.identifier ?? "en"
        default:
            return "en"
        }
    }

    // 获取本地化字符串 - 优先使用内置字典
    func localizedString(for key: String, comment: String = "") -> String {
        let languageCode = currentLanguageCode

        // 首先尝试从内置字典获取
        if let translation = localizations[languageCode]?[key] {
            return translation
        }

        // 如果内置字典没有，回退到系统本地化
        let bundle: Bundle
        if currentLanguage == "auto" {
            bundle = Bundle.main
        } else {
            guard let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
                  let languageBundle = Bundle(path: path) else {
                return key // 如果都找不到，返回key本身
            }
            bundle = languageBundle
        }

        let result = NSLocalizedString(key, bundle: bundle, comment: comment)
        return result == key ? (localizations["en"]?[key] ?? key) : result
    }
}

// MARK: - 通知扩展
extension Notification.Name {
    static let languageChanged = Notification.Name("LanguageChanged")
}

// MARK: - String 扩展
extension String {
    // 便利方法获取本地化字符串
    var localized: String {
        return LocalizationManager.shared.localizedString(for: self)
    }
    
    // 带参数的本地化字符串
    func localized(with arguments: CVarArg...) -> String {
        let localizedString = LocalizationManager.shared.localizedString(for: self)
        return String(format: localizedString, arguments: arguments)
    }
}

// MARK: - SwiftUI 本地化支持
struct LocalizedText: View {
    let key: String
    let arguments: [CVarArg]
    
    init(_ key: String, arguments: CVarArg...) {
        self.key = key
        self.arguments = arguments
    }
    
    var body: some View {
        Text(arguments.isEmpty ? key.localized : key.localized(with: arguments))
    }
}

// MARK: - 语言选项
enum SupportedLanguage: String, CaseIterable {
    case auto = "auto"
    case chinese = "zh-Hans"
    case english = "en"
    
    var displayName: String {
        switch self {
        case .auto:
            return "Follow System".localized
        case .chinese:
            return "Chinese".localized
        case .english:
            return "English".localized
        }
    }
    
    var nativeName: String {
        switch self {
        case .auto:
            return "跟随系统"
        case .chinese:
            return "中文"
        case .english:
            return "English"
        }
    }
}

// MARK: - 本地化环境修饰符
struct LocalizationEnvironment: ViewModifier {
    @StateObject private var localizationManager = LocalizationManager.shared
    
    func body(content: Content) -> some View {
        content
            .environmentObject(localizationManager)
            .onReceive(NotificationCenter.default.publisher(for: .languageChanged)) { _ in
                // 强制刷新视图
                localizationManager.objectWillChange.send()
            }
    }
}

extension View {
    func withLocalization() -> some View {
        modifier(LocalizationEnvironment())
    }
}

// MARK: - 统一本地化数据
struct LocalizationData {

    // MARK: - 英文本地化
    static let english: [String: String] = [
        // Main UI
        "ManualBox": "ManualBox",
        "Settings": "Settings",
        "Notification & Reminders": "Notification & Reminders",
        "Appearance & Theme": "Appearance & Theme",
        "Data & Defaults": "Data & Defaults",
        "About & Support": "About & Support",
        "Follow System": "Follow System",
        "Chinese": "Chinese",
        "English": "English",
        "Language": "Language",
        "Export Data": "Export Data",
        "Import Data": "Import Data",
        "Data Backup & Restore": "Data Backup & Restore",
        "Reset App Data": "Reset App Data",
        "Privacy Policy": "Privacy Policy",
        "User Agreement": "User Agreement",
        "Check for Updates": "Check for Updates",
        "System Notification": "System Notification",
        "Email": "Email",
        "Calendar Event": "Calendar Event",
        "Start": "Start",
        "End": "End",
        "Silent Period": "Silent Period",
        "Warranty Advance Reminder": "Warranty Advance Reminder",
        "Maintenance Progress Push": "Maintenance Progress Push",
        "Asset Inspection/Maintenance": "Asset Inspection/Maintenance",
        "Notification Channel": "Notification Channel",

        // Repair Records
        "Repair Records": "Repair Records",
        "Add Repair Record": "Add Repair Record",
        "Edit Repair Record": "Edit Repair Record",
        "Repair Details": "Repair Details",
        "Repair Date": "Repair Date",
        "Repair Cost": "Repair Cost",
        "Delete Repair Record": "Delete Repair Record",
        "Confirm Delete": "Confirm Delete",
        "This action cannot be undone": "This action cannot be undone",
        "Save Changes": "Save Changes",
        "Cancel": "Cancel",
        "Related Product": "Related Product",
        "No Repair Records": "No Repair Records",
        "Search Repair Records": "Search Repair Records",
        "Enter repair details...": "Enter repair details...",

        // Theme Settings
        "Theme Mode": "Theme Mode",
        "Theme Color": "Theme Color",
        "System": "System",
        "Light": "Light",
        "Dark": "Dark",
        "Blue": "Blue",
        "Green": "Green",
        "Orange": "Orange",
        "Pink": "Pink",
        "Purple": "Purple",
        "Red": "Red",

        // Data & Default Settings
        "Default Settings": "Default Settings",
        "Data Management": "Data Management",
        "Export products, categories, and tags": "Export products, categories, and tags",
        "Import products, categories, and tags": "Import products, categories, and tags",
        "Local or iCloud backup/restore": "Local or iCloud backup/restore",
        "Clear all local data, cannot be recovered": "Clear all local data, cannot be recovered",

        // About & Support
        "Legal & Policies": "Legal & Policies",
        "Updates & Support": "Updates & Support",
        "View app privacy policy": "View app privacy policy",
        "View app user agreement": "View app user agreement",
        "Go to the latest version download page": "Go to the latest version download page",
        "Warranty Information Assistant": "Warranty Information Assistant",

        // Search & Filter
        "Advanced Search": "Advanced Search",
        "Search Scope": "Search Scope",
        "Category Filter": "Category Filter",
        "Tag Filter": "Tag Filter",
        "Warranty Status": "Warranty Status",
        "Purchase Date": "Purchase Date",
        "Enable Category Filter": "Enable Category Filter",
        "Enable Tag Filter": "Enable Tag Filter",
        "Enable Warranty Status Filter": "Enable Warranty Status Filter",
        "Enable Date Filter": "Enable Date Filter",
        "Select Category": "Select Category",
        "All Categories": "All Categories",
        "All Statuses": "All Statuses",
        "In Warranty": "In Warranty",
        "Expiring Soon": "Expiring Soon",
        "Expired": "Expired",
        "Start Date": "Start Date",
        "End Date": "End Date",
        "Apply Filters": "Apply Filters",
        "Reset All Filters": "Reset All Filters",
        "Filter Conditions:": "Filter Conditions:",
        "Clear": "Clear",

        // Products
        "Products": "Products",
        "Add Product": "Add Product",
        "Edit Product": "Edit Product",
        "Product Name": "Product Name",
        "Brand": "Brand",
        "Model": "Model",
        "Category": "Category",
        "Tags": "Tags",
        "Notes": "Notes",
        "Image": "Image",
        "No Products": "No Products",
        "Search Products": "Search Products",
        "Delete Product": "Delete Product",
        "Product Details": "Product Details",

        // Categories
        "Categories": "Categories",
        "Add Category": "Add Category",
        "Edit Category": "Edit Category",
        "Category Name": "Category Name",
        "Category Icon": "Category Icon",
        "Delete Category": "Delete Category",
        "No Categories": "No Categories",

        // Tags
        "Add Tag": "Add Tag",
        "Edit Tag": "Edit Tag",
        "Tag Name": "Tag Name",
        "Tag Color": "Tag Color",
        "Delete Tag": "Delete Tag",
        "No Tags": "No Tags",

        // Orders
        "Order Information": "Order Information",
        "Order Number": "Order Number",
        "Purchase Platform": "Purchase Platform",
        "Order Date": "Order Date",
        "Warranty Period": "Warranty Period",
        "Invoice": "Invoice",
        "Upload Invoice": "Upload Invoice",

        // Manuals
        "Manuals": "Manuals",
        "Manual": "Manual",
        "Upload Manual": "Upload Manual",
        "Select Manual Files": "Select Manual Files",
        "OCR Text Recognition": "OCR Text Recognition",
        "No Manuals": "No Manuals",

        // Common Actions
        "Save": "Save",
        "Delete": "Delete",
        "Edit": "Edit",
        "Add": "Add",
        "Done": "Done",
        "Close": "Close",
        "OK": "OK",
        "Yes": "Yes",
        "No": "No",
        "Confirm": "Confirm",
        "Loading...": "Loading...",
        "Error": "Error",
        "Success": "Success",
        "Warning": "Warning",

        // Validation Messages
        "Name is required": "Name is required",
        "Please enter a valid name": "Please enter a valid name",
        "Save failed": "Save failed",
        "Delete failed": "Delete failed",
        "Operation completed successfully": "Operation completed successfully"
    ]

    // MARK: - 中文本地化
    static let chinese: [String: String] = [
        // 主界面
        "ManualBox": "ManualBox",
        "Settings": "设置",
        "Notification & Reminders": "通知与提醒",
        "Appearance & Theme": "外观与主题",
        "Data & Defaults": "数据与默认",
        "About & Support": "关于与支持",
        "Follow System": "跟随系统",
        "Chinese": "中文",
        "English": "英文",
        "Language": "语言",
        "Export Data": "导出数据",
        "Import Data": "导入数据",
        "Data Backup & Restore": "数据备份与恢复",
        "Reset App Data": "重置应用数据",
        "Privacy Policy": "隐私政策",
        "User Agreement": "用户协议",
        "Check for Updates": "检查更新",
        "System Notification": "系统通知",
        "Email": "邮件",
        "Calendar Event": "日历事件",
        "Start": "开始",
        "End": "结束",
        "Silent Period": "静默时段",
        "Warranty Advance Reminder": "保修到期提前提醒",
        "Maintenance Progress Push": "维修进度推送",
        "Asset Inspection/Maintenance": "资产定期巡检/保养",
        "Notification Channel": "通知方式",

        // 维修记录
        "Repair Records": "维修记录",
        "Add Repair Record": "添加维修记录",
        "Edit Repair Record": "编辑维修记录",
        "Repair Details": "维修详情",
        "Repair Date": "维修日期",
        "Repair Cost": "维修费用",
        "Delete Repair Record": "删除此维修记录",
        "Confirm Delete": "确认删除",
        "This action cannot be undone": "此操作无法撤销",
        "Save Changes": "保存修改",
        "Cancel": "取消",
        "Related Product": "关联产品",
        "No Repair Records": "暂无维修记录",
        "Search Repair Records": "搜索维修记录",
        "Enter repair details...": "请输入维修详情...",

        // 主题设置
        "Theme Mode": "主题模式",
        "Theme Color": "主题色",
        "System": "系统",
        "Light": "浅色",
        "Dark": "深色",
        "Blue": "蓝色",
        "Green": "绿色",
        "Orange": "橙色",
        "Pink": "粉色",
        "Purple": "紫色",
        "Red": "红色",

        // 数据与默认设置
        "Default Settings": "默认设置",
        "Data Management": "数据管理",
        "Export products, categories, and tags": "导出商品、分类、标签等数据",
        "Import products, categories, and tags": "导入商品、分类、标签等数据",
        "Local or iCloud backup/restore": "本地或iCloud备份/恢复",
        "Clear all local data, cannot be recovered": "清除所有本地数据，无法恢复",

        // 关于与支持
        "Legal & Policies": "法律与政策",
        "Updates & Support": "更新与支持",
        "View app privacy policy": "查看应用隐私政策",
        "View app user agreement": "查看应用用户协议",
        "Go to the latest version download page": "前往最新版本下载页",
        "Warranty Information Assistant": "保修信息管理助手",

        // 搜索筛选
        "Advanced Search": "高级搜索",
        "Search Scope": "搜索范围",
        "Category Filter": "分类筛选",
        "Tag Filter": "标签筛选",
        "Warranty Status": "保修状态",
        "Purchase Date": "购买日期",
        "Enable Category Filter": "启用分类筛选",
        "Enable Tag Filter": "启用标签筛选",
        "Enable Warranty Status Filter": "启用保修状态筛选",
        "Enable Date Filter": "启用日期筛选",
        "Select Category": "选择分类",
        "All Categories": "所有分类",
        "All Statuses": "所有状态",
        "In Warranty": "在保修期内",
        "Expiring Soon": "即将过期",
        "Expired": "已过期",
        "Start Date": "开始日期",
        "End Date": "结束日期",
        "Apply Filters": "应用筛选",
        "Reset All Filters": "重置所有筛选",
        "Filter Conditions:": "筛选条件:",
        "Clear": "清除",

        // 产品
        "Products": "产品",
        "Add Product": "添加产品",
        "Edit Product": "编辑产品",
        "Product Name": "产品名称",
        "Brand": "品牌",
        "Model": "型号",
        "Category": "分类",
        "Tags": "标签",
        "Notes": "备注",
        "Image": "图片",
        "No Products": "暂无产品",
        "Search Products": "搜索产品",
        "Delete Product": "删除产品",
        "Product Details": "产品详情",

        // 分类
        "Categories": "分类",
        "Add Category": "添加分类",
        "Edit Category": "编辑分类",
        "Category Name": "分类名称",
        "Category Icon": "分类图标",
        "Delete Category": "删除分类",
        "No Categories": "暂无分类",

        // 标签
        "Add Tag": "添加标签",
        "Edit Tag": "编辑标签",
        "Tag Name": "标签名称",
        "Tag Color": "标签颜色",
        "Delete Tag": "删除标签",
        "No Tags": "暂无标签",

        // 订单
        "Order Information": "订单信息",
        "Order Number": "订单号",
        "Purchase Platform": "购买平台",
        "Order Date": "订单日期",
        "Warranty Period": "保修期",
        "Invoice": "发票",
        "Upload Invoice": "上传发票",

        // 说明书
        "Manuals": "说明书",
        "Manual": "说明书",
        "Upload Manual": "上传说明书",
        "Select Manual Files": "选择说明书文件",
        "OCR Text Recognition": "OCR 文字识别",
        "No Manuals": "暂无说明书",

        // 常用操作
        "Save": "保存",
        "Delete": "删除",
        "Edit": "编辑",
        "Add": "添加",
        "Done": "完成",
        "Close": "关闭",
        "OK": "确定",
        "Yes": "是",
        "No": "否",
        "Confirm": "确认",
        "Loading...": "加载中...",
        "Error": "错误",
        "Success": "成功",
        "Warning": "警告",

        // 验证消息
        "Name is required": "名称不能为空",
        "Please enter a valid name": "请输入有效的名称",
        "Save failed": "保存失败",
        "Delete failed": "删除失败",
        "Operation completed successfully": "操作成功完成"
    ]
}

// MARK: - 便利的本地化字符串常量
struct LocalizedStrings {
    // 主界面
    static let manualBox = "ManualBox".localized
    static let settings = "Settings".localized
    static let products = "Products".localized
    static let categories = "Categories".localized
    static let tags = "Tags".localized

    // 操作
    static let save = "Save".localized
    static let cancel = "Cancel".localized
    static let delete = "Delete".localized
    static let edit = "Edit".localized
    static let add = "Add".localized
    static let done = "Done".localized
    static let close = "Close".localized
    static let confirm = "Confirm".localized

    // 状态
    static let loading = "Loading...".localized
    static let error = "Error".localized
    static let success = "Success".localized
    static let warning = "Warning".localized

    // 产品相关
    static let addProduct = "Add Product".localized
    static let editProduct = "Edit Product".localized
    static let productName = "Product Name".localized
    static let brand = "Brand".localized
    static let model = "Model".localized
    static let noProducts = "No Products".localized

    // 分类相关
    static let addCategory = "Add Category".localized
    static let editCategory = "Edit Category".localized
    static let categoryName = "Category Name".localized
    static let noCategories = "No Categories".localized

    // 标签相关
    static let addTag = "Add Tag".localized
    static let editTag = "Edit Tag".localized
    static let tagName = "Tag Name".localized
    static let noTags = "No Tags".localized

    // 验证消息
    static let nameRequired = "Name is required".localized
    static let saveFailed = "Save failed".localized
    static let deleteFailed = "Delete failed".localized
    static let operationSuccess = "Operation completed successfully".localized
}
