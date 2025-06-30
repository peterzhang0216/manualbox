import Foundation
import SwiftUI

// MARK: - 统一本地化管理器
class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()

    @Published var currentLanguage: String = "auto"

    // 统一的本地化字典
    private let localizations: [String: [String: String]] = [
        "en": LocalizationData.english,
        "zh-Hans": LocalizationData.chinese,
        "ja": LocalizationData.japanese,
        "ko": LocalizationData.korean,
        "fr": LocalizationData.french,
        "de": LocalizationData.german,
        "es": LocalizationData.spanish,
        "pt": LocalizationData.portuguese,
        "ru": LocalizationData.russian,
        "ar": LocalizationData.arabic
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
        case "ja":
            return "ja"
        case "ko":
            return "ko"
        case "fr":
            return "fr"
        case "de":
            return "de"
        case "es":
            return "es"
        case "pt":
            return "pt"
        case "ru":
            return "ru"
        case "ar":
            return "ar"
        case "auto":
            let systemLanguage = Locale.current.language.languageCode?.identifier ?? "zh-Hans"
            // 根据系统语言返回对应的语言代码
            switch systemLanguage {
            case "zh", "zh-Hans", "zh-Hant":
                return "zh-Hans"
            case "en":
                return "en"
            case "ja":
                return "ja"
            case "ko":
                return "ko"
            case "fr":
                return "fr"
            case "de":
                return "de"
            case "es":
                return "es"
            case "pt":
                return "pt"
            case "ru":
                return "ru"
            case "ar":
                return "ar"
            default:
                return "en" // 默认使用英文
            }
        default:
            return "en" // 默认使用英文
        }
    }

    // 获取支持的语言列表
    var supportedLanguages: [LanguageInfo] {
        return [
            LanguageInfo(code: "auto", name: "跟随系统", nativeName: "Follow System"),
            LanguageInfo(code: "zh-Hans", name: "简体中文", nativeName: "简体中文"),
            LanguageInfo(code: "en", name: "English", nativeName: "English"),
            LanguageInfo(code: "ja", name: "日本語", nativeName: "日本語"),
            LanguageInfo(code: "ko", name: "한국어", nativeName: "한국어"),
            LanguageInfo(code: "fr", name: "Français", nativeName: "Français"),
            LanguageInfo(code: "de", name: "Deutsch", nativeName: "Deutsch"),
            LanguageInfo(code: "es", name: "Español", nativeName: "Español"),
            LanguageInfo(code: "pt", name: "Português", nativeName: "Português"),
            LanguageInfo(code: "ru", name: "Русский", nativeName: "Русский"),
            LanguageInfo(code: "ar", name: "العربية", nativeName: "العربية")
        ]
    }

    // 获取本地化字符串 - 优先使用内置字典
    func localizedString(for key: String, comment: String = "") -> String {
        let languageCode = currentLanguageCode

        // 首先尝试从内置字典获取
        if let translation = localizations[languageCode]?[key] {
            return translation
        }

        // 如果当前语言没有，尝试回退到英文
        if languageCode != "en", let englishTranslation = localizations["en"]?[key] {
            return englishTranslation
        }

        // 如果英文也没有，尝试回退到中文
        if languageCode != "zh-Hans", let chineseTranslation = localizations["zh-Hans"]?[key] {
            return chineseTranslation
        }

        // 如果内置字典都没有，回退到系统本地化
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
        return result == key ? key : result
    }

    // 检查语言是否支持RTL（从右到左）
    var isRTL: Bool {
        return currentLanguageCode == "ar"
    }

    // 获取语言的显示名称
    func getLanguageDisplayName(for code: String) -> String {
        return supportedLanguages.first { $0.code == code }?.nativeName ?? code
    }
}

// MARK: - 语言信息结构
struct LanguageInfo: Identifiable, Codable {
    let id = UUID()
    let code: String
    let name: String
    let nativeName: String

    var flag: String {
        switch code {
        case "zh-Hans":
            return "🇨🇳"
        case "en":
            return "🇺🇸"
        case "ja":
            return "🇯🇵"
        case "ko":
            return "🇰🇷"
        case "fr":
            return "🇫🇷"
        case "de":
            return "🇩🇪"
        case "es":
            return "🇪🇸"
        case "pt":
            return "🇵🇹"
        case "ru":
            return "🇷🇺"
        case "ar":
            return "🇸🇦"
        case "auto":
            return "🌐"
        default:
            return "🌍"
        }
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
    ]

    // MARK: - 日文本地化
    static let japanese: [String: String] = [
        // 主界面
        "ManualBox": "ManualBox",
        "设置": "設定",
        "通知与提醒": "通知とリマインダー",
        "外观与主题": "外観とテーマ",
        "数据与默认": "データとデフォルト",
        "关于与支持": "情報とサポート",
        "跟随系统": "システムに従う",
        "中文": "中国語",
        "英文": "英語",
        "语言": "言語",
        "导出数据": "データエクスポート",
        "导入数据": "データインポート",
        "数据备份与恢复": "データバックアップと復元",
        "重置应用数据": "アプリデータリセット",
        "隐私政策": "プライバシーポリシー",
        "用户协议": "利用規約",
        "检查更新": "アップデート確認",

        // 操作按钮
        "保存": "保存",
        "取消": "キャンセル",
        "删除": "削除",
        "编辑": "編集",
        "添加": "追加",
        "完成": "完了",
        "关闭": "閉じる",
        "确认": "確認",

        // 状态消息
        "加载中": "読み込み中",
        "错误": "エラー",
        "成功": "成功",
        "警告": "警告",

        // 产品管理
        "添加产品": "製品追加",
        "产品名称": "製品名",
        "品牌": "ブランド",
        "型号": "モデル",
        "备注": "備考",
        "产品图片": "製品画像",
        "选择图片": "画像選択",
        "拍照": "写真撮影",
        "从相册选择": "アルバムから選択",
        "产品详情": "製品詳細",

        // 分类管理
        "添加分类": "カテゴリ追加",
        "分类名称": "カテゴリ名",
        "分类图标": "カテゴリアイコン",
        "删除分类": "カテゴリ削除",
        "编辑分类": "カテゴリ編集",
        "分类": "カテゴリ",

        // 标签管理
        "添加标签": "タグ追加",
        "标签名称": "タグ名",
        "标签颜色": "タグ色",
        "删除标签": "タグ削除",
        "编辑标签": "タグ編集",
        "标签": "タグ",
    ]

    // MARK: - 韩文本地化
    static let korean: [String: String] = [
        // 主界面
        "ManualBox": "ManualBox",
        "设置": "설정",
        "通知与提醒": "알림 및 리마인더",
        "外观与主题": "외관 및 테마",
        "数据与默认": "데이터 및 기본값",
        "关于与支持": "정보 및 지원",
        "跟随系统": "시스템 따르기",
        "中文": "중국어",
        "英文": "영어",
        "语言": "언어",
        "导出数据": "데이터 내보내기",
        "导入数据": "데이터 가져오기",
        "数据备份与恢复": "데이터 백업 및 복원",
        "重置应用数据": "앱 데이터 재설정",
        "隐私政策": "개인정보 처리방침",
        "用户协议": "이용약관",
        "检查更新": "업데이트 확인",

        // 操作按钮
        "保存": "저장",
        "取消": "취소",
        "删除": "삭제",
        "编辑": "편집",
        "添加": "추가",
        "完成": "완료",
        "关闭": "닫기",
        "确认": "확인",

        // 状态消息
        "加载中": "로딩 중",
        "错误": "오류",
        "成功": "성공",
        "警告": "경고",

        // 产品管理
        "添加产品": "제품 추가",
        "产品名称": "제품명",
        "品牌": "브랜드",
        "型号": "모델",
        "备注": "비고",
        "产品图片": "제품 이미지",
        "选择图片": "이미지 선택",
        "拍照": "사진 촬영",
        "从相册选择": "앨범에서 선택",
        "产品详情": "제품 상세",

        // 分类管理
        "添加分类": "카테고리 추가",
        "分类名称": "카테고리명",
        "分类图标": "카테고리 아이콘",
        "删除分类": "카테고리 삭제",
        "编辑分类": "카테고리 편집",
        "分类": "카테고리",

        // 标签管理
        "添加标签": "태그 추가",
        "标签名称": "태그명",
        "标签颜色": "태그 색상",
        "删除标签": "태그 삭제",
        "编辑标签": "태그 편집",
        "标签": "태그",
    ]

    // MARK: - 法文本地化
    static let french: [String: String] = [
        // 主界面
        "ManualBox": "ManualBox",
        "设置": "Paramètres",
        "通知与提醒": "Notifications et Rappels",
        "外观与主题": "Apparence et Thème",
        "数据与默认": "Données et Défauts",
        "关于与支持": "À propos et Support",
        "跟随系统": "Suivre le Système",
        "中文": "Chinois",
        "英文": "Anglais",
        "语言": "Langue",
        "导出数据": "Exporter les Données",
        "导入数据": "Importer les Données",
        "数据备份与恢复": "Sauvegarde et Restauration",
        "重置应用数据": "Réinitialiser les Données",
        "隐私政策": "Politique de Confidentialité",
        "用户协议": "Accord Utilisateur",
        "检查更新": "Vérifier les Mises à Jour",

        // 操作按钮
        "保存": "Enregistrer",
        "取消": "Annuler",
        "删除": "Supprimer",
        "编辑": "Modifier",
        "添加": "Ajouter",
        "完成": "Terminé",
        "关闭": "Fermer",
        "确认": "Confirmer",

        // 状态消息
        "加载中": "Chargement",
        "错误": "Erreur",
        "成功": "Succès",
        "警告": "Avertissement",

        // 产品管理
        "添加产品": "Ajouter un Produit",
        "产品名称": "Nom du Produit",
        "品牌": "Marque",
        "型号": "Modèle",
        "备注": "Remarques",
        "产品图片": "Image du Produit",
        "选择图片": "Choisir une Image",
        "拍照": "Prendre une Photo",
        "从相册选择": "Choisir dans l'Album",
        "产品详情": "Détails du Produit",

        // 分类管理
        "添加分类": "Ajouter une Catégorie",
        "分类名称": "Nom de la Catégorie",
        "分类图标": "Icône de la Catégorie",
        "删除分类": "Supprimer la Catégorie",
        "编辑分类": "Modifier la Catégorie",
        "分类": "Catégorie",

        // 标签管理
        "添加标签": "Ajouter un Tag",
        "标签名称": "Nom du Tag",
        "标签颜色": "Couleur du Tag",
        "删除标签": "Supprimer le Tag",
        "编辑标签": "Modifier le Tag",
        "标签": "Tag",
    ]

    // MARK: - 德文本地化
    static let german: [String: String] = [
        // 主界面
        "ManualBox": "ManualBox",
        "设置": "Einstellungen",
        "通知与提醒": "Benachrichtigungen und Erinnerungen",
        "外观与主题": "Aussehen und Thema",
        "数据与默认": "Daten und Standards",
        "关于与支持": "Über und Support",
        "跟随系统": "System folgen",
        "中文": "Chinesisch",
        "英文": "Englisch",
        "语言": "Sprache",
        "导出数据": "Daten exportieren",
        "导入数据": "Daten importieren",
        "数据备份与恢复": "Datensicherung und Wiederherstellung",
        "重置应用数据": "App-Daten zurücksetzen",
        "隐私政策": "Datenschutzrichtlinie",
        "用户协议": "Nutzungsvereinbarung",
        "检查更新": "Nach Updates suchen",

        // 操作按钮
        "保存": "Speichern",
        "取消": "Abbrechen",
        "删除": "Löschen",
        "编辑": "Bearbeiten",
        "添加": "Hinzufügen",
        "完成": "Fertig",
        "关闭": "Schließen",
        "确认": "Bestätigen",

        // 状态消息
        "加载中": "Wird geladen",
        "错误": "Fehler",
        "成功": "Erfolg",
        "警告": "Warnung",

        // 产品管理
        "添加产品": "Produkt hinzufügen",
        "产品名称": "Produktname",
        "品牌": "Marke",
        "型号": "Modell",
        "备注": "Notizen",
        "产品图片": "Produktbild",
        "选择图片": "Bild auswählen",
        "拍照": "Foto aufnehmen",
        "从相册选择": "Aus Album auswählen",
        "产品详情": "Produktdetails",

        // 分类管理
        "添加分类": "Kategorie hinzufügen",
        "分类名称": "Kategoriename",
        "分类图标": "Kategorie-Symbol",
        "删除分类": "Kategorie löschen",
        "编辑分类": "Kategorie bearbeiten",
        "分类": "Kategorie",

        // 标签管理
        "添加标签": "Tag hinzufügen",
        "标签名称": "Tag-Name",
        "标签颜色": "Tag-Farbe",
        "删除标签": "Tag löschen",
        "编辑标签": "Tag bearbeiten",
        "标签": "Tag",
    ]

    // MARK: - 西班牙文本地化
    static let spanish: [String: String] = [
        // 主界面
        "ManualBox": "ManualBox",
        "设置": "Configuración",
        "通知与提醒": "Notificaciones y Recordatorios",
        "外观与主题": "Apariencia y Tema",
        "数据与默认": "Datos y Predeterminados",
        "关于与支持": "Acerca de y Soporte",
        "跟随系统": "Seguir Sistema",
        "中文": "Chino",
        "英文": "Inglés",
        "语言": "Idioma",
        "导出数据": "Exportar Datos",
        "导入数据": "Importar Datos",
        "数据备份与恢复": "Copia de Seguridad y Restauración",
        "重置应用数据": "Restablecer Datos de la App",
        "隐私政策": "Política de Privacidad",
        "用户协议": "Acuerdo de Usuario",
        "检查更新": "Buscar Actualizaciones",

        // 操作按钮
        "保存": "Guardar",
        "取消": "Cancelar",
        "删除": "Eliminar",
        "编辑": "Editar",
        "添加": "Agregar",
        "完成": "Completado",
        "关闭": "Cerrar",
        "确认": "Confirmar",

        // 状态消息
        "加载中": "Cargando",
        "错误": "Error",
        "成功": "Éxito",
        "警告": "Advertencia",

        // 产品管理
        "添加产品": "Agregar Producto",
        "产品名称": "Nombre del Producto",
        "品牌": "Marca",
        "型号": "Modelo",
        "备注": "Notas",
        "产品图片": "Imagen del Producto",
        "选择图片": "Seleccionar Imagen",
        "拍照": "Tomar Foto",
        "从相册选择": "Seleccionar del Álbum",
        "产品详情": "Detalles del Producto",

        // 分类管理
        "添加分类": "Agregar Categoría",
        "分类名称": "Nombre de la Categoría",
        "分类图标": "Icono de la Categoría",
        "删除分类": "Eliminar Categoría",
        "编辑分类": "Editar Categoría",
        "分类": "Categoría",

        // 标签管理
        "添加标签": "Agregar Etiqueta",
        "标签名称": "Nombre de la Etiqueta",
        "标签颜色": "Color de la Etiqueta",
        "删除标签": "Eliminar Etiqueta",
        "编辑标签": "Editar Etiqueta",
        "标签": "Etiqueta",
    ]

    // MARK: - 葡萄牙文本地化
    static let portuguese: [String: String] = [
        // 主界面
        "ManualBox": "ManualBox",
        "设置": "Configurações",
        "通知与提醒": "Notificações e Lembretes",
        "外观与主题": "Aparência e Tema",
        "数据与默认": "Dados e Padrões",
        "关于与支持": "Sobre e Suporte",
        "跟随系统": "Seguir Sistema",
        "中文": "Chinês",
        "英文": "Inglês",
        "语言": "Idioma",
        "导出数据": "Exportar Dados",
        "导入数据": "Importar Dados",
        "数据备份与恢复": "Backup e Restauração de Dados",
        "重置应用数据": "Redefinir Dados do App",
        "隐私政策": "Política de Privacidade",
        "用户协议": "Acordo do Usuário",
        "检查更新": "Verificar Atualizações",

        // 操作按钮
        "保存": "Salvar",
        "取消": "Cancelar",
        "删除": "Excluir",
        "编辑": "Editar",
        "添加": "Adicionar",
        "完成": "Concluído",
        "关闭": "Fechar",
        "确认": "Confirmar",

        // 状态消息
        "加载中": "Carregando",
        "错误": "Erro",
        "成功": "Sucesso",
        "警告": "Aviso",

        // 产品管理
        "添加产品": "Adicionar Produto",
        "产品名称": "Nome do Produto",
        "品牌": "Marca",
        "型号": "Modelo",
        "备注": "Observações",
        "产品图片": "Imagem do Produto",
        "选择图片": "Selecionar Imagem",
        "拍照": "Tirar Foto",
        "从相册选择": "Selecionar do Álbum",
        "产品详情": "Detalhes do Produto",

        // 分类管理
        "添加分类": "Adicionar Categoria",
        "分类名称": "Nome da Categoria",
        "分类图标": "Ícone da Categoria",
        "删除分类": "Excluir Categoria",
        "编辑分类": "Editar Categoria",
        "分类": "Categoria",

        // 标签管理
        "添加标签": "Adicionar Tag",
        "标签名称": "Nome da Tag",
        "标签颜色": "Cor da Tag",
        "删除标签": "Excluir Tag",
        "编辑标签": "Editar Tag",
        "标签": "Tag",
    ]

    // MARK: - 俄文本地化
    static let russian: [String: String] = [
        // 主界面
        "ManualBox": "ManualBox",
        "设置": "Настройки",
        "通知与提醒": "Уведомления и Напоминания",
        "外观与主题": "Внешний вид и Тема",
        "数据与默认": "Данные и Настройки по умолчанию",
        "关于与支持": "О программе и Поддержка",
        "跟随系统": "Следовать системе",
        "中文": "Китайский",
        "英文": "Английский",
        "语言": "Язык",
        "导出数据": "Экспорт данных",
        "导入数据": "Импорт данных",
        "数据备份与恢复": "Резервное копирование и восстановление",
        "重置应用数据": "Сброс данных приложения",
        "隐私政策": "Политика конфиденциальности",
        "用户协议": "Пользовательское соглашение",
        "检查更新": "Проверить обновления",

        // 操作按钮
        "保存": "Сохранить",
        "取消": "Отмена",
        "删除": "Удалить",
        "编辑": "Редактировать",
        "添加": "Добавить",
        "完成": "Готово",
        "关闭": "Закрыть",
        "确认": "Подтвердить",

        // 状态消息
        "加载中": "Загрузка",
        "错误": "Ошибка",
        "成功": "Успех",
        "警告": "Предупреждение",

        // 产品管理
        "添加产品": "Добавить продукт",
        "产品名称": "Название продукта",
        "品牌": "Бренд",
        "型号": "Модель",
        "备注": "Заметки",
        "产品图片": "Изображение продукта",
        "选择图片": "Выбрать изображение",
        "拍照": "Сделать фото",
        "从相册选择": "Выбрать из альбома",
        "产品详情": "Детали продукта",

        // 分类管理
        "添加分类": "Добавить категорию",
        "分类名称": "Название категории",
        "分类图标": "Иконка категории",
        "删除分类": "Удалить категорию",
        "编辑分类": "Редактировать категорию",
        "分类": "Категория",

        // 标签管理
        "添加标签": "Добавить тег",
        "标签名称": "Название тега",
        "标签颜色": "Цвет тега",
        "删除标签": "Удалить тег",
        "编辑标签": "Редактировать тег",
        "标签": "Тег",
    ]

    // MARK: - 阿拉伯文本地化 (暂时禁用以避免重复键)
    static let arabic: [String: String] = [:]

    /*
    static let arabic_disabled: [String: String] = [
        // 主界面
        "ManualBox": "ManualBox",
        "设置": "الإعدادات",
        "通知与提醒": "الإشعارات والتذكيرات",
        "外观与主题": "المظهر والموضوع",
        "数据与默认": "البيانات والافتراضيات",
        "关于与支持": "حول والدعم",
        "跟随系统": "اتباع النظام",
        "中文": "الصينية",
        "英文": "الإنجليزية",
        "语言": "اللغة",
        "导出数据": "تصدير البيانات",
        "导入数据": "استيراد البيانات",
        "数据备份与恢复": "النسخ الاحتياطي واستعادة البيانات",
        "重置应用数据": "إعادة تعيين بيانات التطبيق",
        "隐私政策": "سياسة الخصوصية",
        "用户协议": "اتفاقية المستخدم",
        "检查更新": "التحقق من التحديثات",

        // 操作按钮
        "保存": "حفظ",
        "取消": "إلغاء",
        "删除": "حذف",
        "编辑": "تحرير",
        "添加": "إضافة",
        "完成": "تم",
        "关闭": "إغلاق",
        "确认": "تأكيد",

        // 状态消息
        "加载中": "جاري التحميل",
        "错误": "خطأ",
        "成功": "نجح",
        "警告": "تحذير",

        // 产品管理
        "添加产品": "إضافة منتج",
        "产品名称": "اسم المنتج",
        "品牌": "العلامة التجارية",
        "型号": "الطراز",
        "备注": "ملاحظات",
        "产品图片": "صورة المنتج",
        "选择图片": "اختيار صورة",
        "拍照": "التقاط صورة",
        "从相册选择": "اختيار من الألبوم",
        "产品详情": "تفاصيل المنتج",

        // 分类管理
        "添加分类": "إضافة فئة",
        "分类名称": "اسم الفئة",
        "分类图标": "أيقونة الفئة",
        "删除分类": "حذف الفئة",
        "编辑分类": "تحرير الفئة",
        "分类": "الفئة",

        // 标签管理
        "添加标签": "إضافة علامة",
        "标签名称": "اسم العلامة",
        "标签颜色": "لون العلامة",
        "删除标签": "حذف العلامة",
        "编辑标签": "تحرير العلامة",
        "标签": "العلامة",

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
    */
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
