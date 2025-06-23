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
            let systemLanguage = Locale.current.language.languageCode?.identifier ?? "zh-Hans"
            // 如果系统语言是中文相关，返回简体中文，否则返回英文
            if systemLanguage.hasPrefix("zh") {
                return "zh-Hans"
            } else {
                return systemLanguage == "en" ? "en" : "zh-Hans"
            }
        default:
            return "zh-Hans" // 默认使用中文
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
        return result == key ? (localizations["zh-Hans"]?[key] ?? localizations["en"]?[key] ?? key) : result
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
        // 主界面
        "ManualBox": "ManualBox",
        "设置": "Settings",
        "通知与提醒": "Notification & Reminders",
        "外观与主题": "Appearance & Theme",
        "数据与默认": "Data & Defaults",
        "关于与支持": "About & Support",
        "跟随系统": "Follow System",
        "中文": "Chinese",
        "英文": "English",
        "语言": "Language",
        "导出数据": "Export Data",
        "导入数据": "Import Data",
        "数据备份与恢复": "Data Backup & Restore",
        "重置应用数据": "Reset App Data",
        "隐私政策": "Privacy Policy",
        "用户协议": "User Agreement",
        "检查更新": "Check for Updates",
        "系统通知": "System Notification",
        "邮件": "Email",
        "日历事件": "Calendar Event",
        "开始": "Start",
        "结束": "End",
        "静默时段": "Silent Period",
        "保修到期提前提醒": "Warranty Advance Reminder",
        "维修进度推送": "Maintenance Progress Push",
        "资产定期巡检/保养": "Asset Inspection/Maintenance",
        "通知方式": "Notification Channel",

        // 维修记录
        "维修记录": "Repair Records",
        "添加维修记录": "Add Repair Record",
        "编辑维修记录": "Edit Repair Record",
        "维修详情": "Repair Details",
        "维修日期": "Repair Date",
        "维修费用": "Repair Cost",
        "删除此维修记录": "Delete Repair Record",
        "确认删除": "Confirm Delete",
        "此操作无法撤销": "This action cannot be undone",
        "保存修改": "Save Changes",
        "取消": "Cancel",
        "关联产品": "Related Product",
        "暂无维修记录": "No Repair Records",
        "搜索维修记录": "Search Repair Records",
        "请输入维修详情...": "Enter repair details...",

        // 主题设置
        "主题模式": "Theme Mode",
        "主题色": "Theme Color",
        "系统": "System",
        "浅色": "Light",
        "深色": "Dark",
        "蓝色": "Blue",
        "绿色": "Green",
        "橙色": "Orange",
        "粉色": "Pink",
        "紫色": "Purple",
        "红色": "Red",

        // 数据与默认设置
        "默认设置": "Default Settings",
        "数据管理": "Data Management",
        "导出商品、分类、标签等数据": "Export products, categories, and tags",
        "导入商品、分类、标签等数据": "Import products, categories, and tags",
        "本地或iCloud备份/恢复": "Local or iCloud backup/restore",
        "清除所有本地数据，无法恢复": "Clear all local data, cannot be recovered",

        // 关于与支持
        "法律与政策": "Legal & Policies",
        "更新与支持": "Updates & Support",
        "查看应用隐私政策": "View app privacy policy",
        "查看应用用户协议": "View app user agreement",
        "前往最新版本下载页": "Go to the latest version download page",
        "保修信息管理助手": "Warranty Information Assistant",

        // 搜索筛选
        "高级搜索": "Advanced Search",
        "搜索范围": "Search Scope",
        "分类筛选": "Category Filter",
        "标签筛选": "Tag Filter",
        "保修状态": "Warranty Status",
        "购买日期": "Purchase Date",
        "启用分类筛选": "Enable Category Filter",
        "启用标签筛选": "Enable Tag Filter",
        "启用保修状态筛选": "Enable Warranty Status Filter",
        "启用日期筛选": "Enable Date Filter",
        "选择分类": "Select Category",
        "所有分类": "All Categories",
        "所有状态": "All Statuses",
        "在保修期内": "In Warranty",
        "即将过期": "Expiring Soon",
        "已过期": "Expired",
        "开始日期": "Start Date",
        "结束日期": "End Date",
        "应用筛选": "Apply Filters",
        "重置所有筛选": "Reset All Filters",
        "筛选条件:": "Filter Conditions:",
        "清除": "Clear",

        // 产品
        "产品": "Products",
        "添加产品": "Add Product",
        "编辑产品": "Edit Product",
        "产品名称": "Product Name",
        "品牌": "Brand",
        "型号": "Model",
        "产品分类": "Category",
        "标签": "Tags",
        "备注": "Notes",
        "图片": "Image",
        "暂无产品": "No Products",
        "搜索产品": "Search Products",
        "删除产品": "Delete Product",
        "产品详情": "Product Details",

        // 分类
        "分类列表": "Categories",
        "添加分类": "Add Category",
        "编辑分类": "Edit Category",
        "分类名称": "Category Name",
        "分类图标": "Category Icon",
        "删除分类": "Delete Category",
        "暂无分类": "No Categories",

        // 标签
        "添加标签": "Add Tag",
        "编辑标签": "Edit Tag",
        "标签名称": "Tag Name",
        "标签颜色": "Tag Color",
        "删除标签": "Delete Tag",
        "暂无标签": "No Tags",

        // 订单
        "订单信息": "Order Information",
        "订单号": "Order Number",
        "购买平台": "Purchase Platform",
        "订单日期": "Order Date",
        "保修期": "Warranty Period",
        "发票": "Invoice",
        "上传发票": "Upload Invoice",

        // 说明书
        "说明书列表": "Manuals",
        "说明书文档": "Manual",
        "上传说明书": "Upload Manual",
        "选择说明书文件": "Select Manual Files",
        "OCR 文字识别": "OCR Text Recognition",
        "暂无说明书": "No Manuals",

        // 常用操作
        "保存": "Save",
        "删除": "Delete",
        "编辑": "Edit",
        "添加": "Add",
        "完成": "Done",
        "关闭": "Close",
        "确定": "OK",
        "是": "Yes",
        "否": "No",
        "确认": "Confirm",
        "加载中...": "Loading...",
        "错误": "Error",
        "成功": "Success",
        "警告": "Warning",

        // 验证消息
        "名称不能为空": "Name is required",
        "请输入有效的名称": "Please enter a valid name",
        "保存失败": "Save failed",
        "删除失败": "Delete failed",
        "操作成功完成": "Operation completed successfully"
    ]

    // MARK: - 中文本地化
    static let chinese: [String: String] = [
        // 主界面
        "ManualBox": "ManualBox",
        "设置": "设置",
        "通知与提醒": "通知与提醒",
        "外观与主题": "外观与主题",
        "数据与默认": "数据与默认",
        "关于与支持": "关于与支持",
        "跟随系统": "跟随系统",
        "中文": "中文",
        "英文": "英文",
        "语言": "语言",
        "导出数据": "导出数据",
        "导入数据": "导入数据",
        "数据备份与恢复": "数据备份与恢复",
        "重置应用数据": "重置应用数据",
        "隐私政策": "隐私政策",
        "用户协议": "用户协议",
        "检查更新": "检查更新",
        "系统通知": "系统通知",
        "邮件": "邮件",
        "日历事件": "日历事件",
        "开始": "开始",
        "结束": "结束",
        "静默时段": "静默时段",
        "保修到期提前提醒": "保修到期提前提醒",
        "维修进度推送": "维修进度推送",
        "资产定期巡检/保养": "资产定期巡检/保养",
        "通知方式": "通知方式",

        // 维修记录
        "维修记录": "维修记录",
        "添加维修记录": "添加维修记录",
        "编辑维修记录": "编辑维修记录",
        "维修详情": "维修详情",
        "维修日期": "维修日期",
        "维修费用": "维修费用",
        "删除此维修记录": "删除此维修记录",
        "确认删除": "确认删除",
        "此操作无法撤销": "此操作无法撤销",
        "保存修改": "保存修改",
        "取消": "取消",
        "关联产品": "关联产品",
        "暂无维修记录": "暂无维修记录",
        "搜索维修记录": "搜索维修记录",
        "请输入维修详情...": "请输入维修详情...",

        // 主题设置
        "主题模式": "主题模式",
        "主题色": "主题色",
        "系统": "系统",
        "浅色": "浅色",
        "深色": "深色",
        "蓝色": "蓝色",
        "绿色": "绿色",
        "橙色": "橙色",
        "粉色": "粉色",
        "紫色": "紫色",
        "红色": "红色",

        // 数据与默认设置
        "默认设置": "默认设置",
        "数据管理": "数据管理",
        "导出商品、分类、标签等数据": "导出商品、分类、标签等数据",
        "导入商品、分类、标签等数据": "导入商品、分类、标签等数据",
        "本地或iCloud备份/恢复": "本地或iCloud备份/恢复",
        "清除所有本地数据，无法恢复": "清除所有本地数据，无法恢复",

        // 关于与支持
        "法律与政策": "法律与政策",
        "更新与支持": "更新与支持",
        "查看应用隐私政策": "查看应用隐私政策",
        "查看应用用户协议": "查看应用用户协议",
        "前往最新版本下载页": "前往最新版本下载页",
        "保修信息管理助手": "保修信息管理助手",

        // 搜索筛选
        "高级搜索": "高级搜索",
        "搜索范围": "搜索范围",
        "分类筛选": "分类筛选",
        "标签筛选": "标签筛选",
        "保修状态": "保修状态",
        "购买日期": "购买日期",
        "启用分类筛选": "启用分类筛选",
        "启用标签筛选": "启用标签筛选",
        "启用保修状态筛选": "启用保修状态筛选",
        "启用日期筛选": "启用日期筛选",
        "选择分类": "选择分类",
        "所有分类": "所有分类",
        "所有状态": "所有状态",
        "在保修期内": "在保修期内",
        "即将过期": "即将过期",
        "已过期": "已过期",
        "开始日期": "开始日期",
        "结束日期": "结束日期",
        "应用筛选": "应用筛选",
        "重置所有筛选": "重置所有筛选",
        "筛选条件:": "筛选条件:",
        "清除": "清除",

        // 产品
        "产品": "产品",
        "添加产品": "添加产品",
        "编辑产品": "编辑产品",
        "产品名称": "产品名称",
        "品牌": "品牌",
        "型号": "型号",
        "产品分类": "产品分类",
        "标签": "标签",
        "备注": "备注",
        "图片": "图片",
        "暂无产品": "暂无产品",
        "搜索产品": "搜索产品",
        "删除产品": "删除产品",
        "产品详情": "产品详情",

        // 分类
        "分类列表": "分类列表",
        "添加分类": "添加分类",
        "编辑分类": "编辑分类",
        "分类名称": "分类名称",
        "分类图标": "分类图标",
        "删除分类": "删除分类",
        "暂无分类": "暂无分类",

        // 标签
        "添加标签": "添加标签",
        "编辑标签": "编辑标签",
        "标签名称": "标签名称",
        "标签颜色": "标签颜色",
        "删除标签": "删除标签",
        "暂无标签": "暂无标签",

        // 订单
        "订单信息": "订单信息",
        "订单号": "订单号",
        "购买平台": "购买平台",
        "订单日期": "订单日期",
        "保修期": "保修期",
        "发票": "发票",
        "上传发票": "上传发票",

        // 说明书
        "说明书列表": "说明书列表",
        "说明书文档": "说明书文档",
        "上传说明书": "上传说明书",
        "选择说明书文件": "选择说明书文件",
        "OCR 文字识别": "OCR 文字识别",
        "暂无说明书": "暂无说明书",

        // 常用操作
        "保存": "保存",
        "删除": "删除",
        "编辑": "编辑",
        "添加": "添加",
        "完成": "完成",
        "关闭": "关闭",
        "确定": "确定",
        "是": "是",
        "否": "否",
        "确认": "确认",
        "加载中...": "加载中...",
        "错误": "错误",
        "成功": "成功",
        "警告": "警告",

        // 验证消息
        "名称不能为空": "名称不能为空",
        "请输入有效的名称": "请输入有效的名称",
        "保存失败": "保存失败",
        "删除失败": "删除失败",
        "操作成功完成": "操作成功完成"
    ]
}

// MARK: - 便利的本地化字符串常量
struct LocalizedStrings {
    // 主界面
    static let manualBox = "ManualBox".localized
    static let settings = "设置".localized
    static let products = "产品".localized

    static let tags = "标签".localized

    // 操作
    static let save = "保存".localized
    static let cancel = "取消".localized
    static let delete = "删除".localized
    static let edit = "编辑".localized
    static let add = "添加".localized
    static let done = "完成".localized
    static let close = "关闭".localized
    static let confirm = "确认".localized

    // 状态
    static let loading = "加载中...".localized
    static let error = "错误".localized
    static let success = "成功".localized
    static let warning = "警告".localized

    // 产品相关
    static let addProduct = "添加产品".localized
    static let editProduct = "编辑产品".localized
    static let productName = "产品名称".localized
    static let brand = "品牌".localized
    static let model = "型号".localized
    static let noProducts = "暂无产品".localized

    // 分类相关
    static let categories = "分类列表".localized
    static let addCategory = "添加分类".localized
    static let editCategory = "编辑分类".localized
    static let categoryName = "分类名称".localized
    static let noCategories = "暂无分类".localized

    // 标签相关
    static let addTag = "添加标签".localized
    static let editTag = "编辑标签".localized
    static let tagName = "标签名称".localized
    static let noTags = "暂无标签".localized

    // 验证消息
    static let nameRequired = "名称不能为空".localized
    static let saveFailed = "保存失败".localized
    static let deleteFailed = "删除失败".localized
    static let operationSuccess = "操作成功完成".localized
}
