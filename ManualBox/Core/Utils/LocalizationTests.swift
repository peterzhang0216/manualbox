import Foundation

// MARK: - 本地化系统测试
struct LocalizationTests {
    
    // MARK: - 测试基本功能
    static func runBasicTests() {
        print("🧪 开始本地化系统测试...")
        
        // 测试英文本地化
        LocalizationManager.shared.setLanguage("en")
        let englishSave = "保存".localized
        let englishCancel = "取消".localized
        print("✅ 英文测试: 保存 = '\(englishSave)', 取消 = '\(englishCancel)'")

        // 测试中文本地化
        LocalizationManager.shared.setLanguage("zh-Hans")
        let chineseSave = "保存".localized
        let chineseCancel = "取消".localized
        print("✅ 中文测试: 保存 = '\(chineseSave)', 取消 = '\(chineseCancel)'")

        // 测试预定义常量
        let constantSave = LocalizedStrings.save
        let constantCancel = LocalizedStrings.cancel
        print("✅ 常量测试: 保存 = '\(constantSave)', 取消 = '\(constantCancel)'")

        // 测试权限描述
        let notificationPermission = PermissionLocalizations.getPermissionDescription(
            for: "NSUserNotificationsUsageDescription",
            language: "zh-Hans"
        )
        print("✅ 权限测试: 通知权限 = '\(notificationPermission)'")

        // 测试不存在的键
        let unknownKey = "未知键".localized
        print("✅ 未知键测试: '未知键' = '\(unknownKey)'")
        
        print("🎉 本地化系统测试完成！")
    }
    
    // MARK: - 测试所有支持的语言
    static func testAllLanguages() {
        print("\n🌍 测试所有支持的语言...")
        
        let testKeys = ["保存", "取消", "设置", "产品"]
        let languages = ["en", "zh-Hans", "auto"]
        
        for language in languages {
            print("\n📍 测试语言: \(language)")
            LocalizationManager.shared.setLanguage(language)
            
            for key in testKeys {
                let translation = key.localized
                print("  \(key) -> \(translation)")
            }
        }
    }
    
    // MARK: - 验证数据完整性
    static func validateDataIntegrity() {
        print("\n🔍 验证本地化数据完整性...")
        
        let englishKeys = Set(LocalizationData.english.keys)
        let chineseKeys = Set(LocalizationData.chinese.keys)
        
        // 检查缺失的中文翻译
        let missingChinese = englishKeys.subtracting(chineseKeys)
        if !missingChinese.isEmpty {
            print("⚠️  缺失中文翻译的键: \(missingChinese)")
        } else {
            print("✅ 所有英文键都有对应的中文翻译")
        }
        
        // 检查多余的中文翻译
        let extraChinese = chineseKeys.subtracting(englishKeys)
        if !extraChinese.isEmpty {
            print("⚠️  多余的中文翻译键: \(extraChinese)")
        } else {
            print("✅ 没有多余的中文翻译键")
        }
        
        print("📊 统计: 英文键 \(englishKeys.count) 个, 中文键 \(chineseKeys.count) 个")
    }
}

// MARK: - 便利的测试运行器
extension LocalizationTests {
    static func runAllTests() {
        runBasicTests()
        testAllLanguages()
        validateDataIntegrity()
        
        print("\n🏁 所有测试完成！")
    }
}
