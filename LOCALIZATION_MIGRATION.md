# 多语言本地化整合迁移指南

## 📋 概述

本次更新将原本分散在 `en.lproj` 和 `zh-Hans.lproj` 目录中的本地化文件整合到了一个统一的 Swift 文件中，使多语言管理更加简洁和高效。

## 🔄 变更内容

### 1. 新增文件
- `ManualBox/Core/Utils/LocalizationManager.swift` - 统一的本地化管理器（已更新）
- `ManualBox/Core/Utils/PermissionLocalizations.swift` - 权限描述本地化
- `backup_localizations/` - 原本地化文件备份

### 2. 整合的本地化内容
- ✅ 主界面文本（设置、产品、分类、标签等）
- ✅ 操作按钮（保存、删除、编辑、添加等）
- ✅ 状态消息（加载中、错误、成功、警告等）
- ✅ 产品管理相关文本
- ✅ 分类管理相关文本
- ✅ 标签管理相关文本
- ✅ 维修记录相关文本
- ✅ 主题设置相关文本
- ✅ 搜索筛选相关文本
- ✅ 订单信息相关文本
- ✅ 说明书相关文本
- ✅ 验证消息
- ✅ 权限描述文本

## 🚀 使用方法

### 1. 基本用法
```swift
// 使用扩展方法（推荐）
let text = "保存".localized

// 使用本地化管理器
let text = LocalizationManager.shared.localizedString(for: "保存")

// 使用预定义常量
let text = LocalizedStrings.save
```

### 2. 在 SwiftUI 中使用
```swift
struct MyView: View {
    var body: some View {
        VStack {
            Text("Save".localized)
            Button("Cancel".localized) {
                // 取消操作
            }
        }
    }
}
```

### 3. 动态语言切换
```swift
// 切换到中文
LocalizationManager.shared.setLanguage("zh-Hans")

// 切换到英文
LocalizationManager.shared.setLanguage("en")

// 跟随系统
LocalizationManager.shared.setLanguage("auto")
```

## 📁 文件结构对比

### 之前的结构
```
ManualBox/
├── en.lproj/
│   ├── Localizable.strings
│   └── InfoPlist.strings
└── zh-Hans.lproj/
    ├── Localizable.strings
    └── InfoPlist.strings
```

### 现在的结构
```
ManualBox/
├── Core/Utils/
│   ├── LocalizationManager.swift      # 统一本地化管理
│   └── PermissionLocalizations.swift  # 权限描述本地化
├── en.lproj/                          # 保留作为备用
└── zh-Hans.lproj/                     # 保留作为备用
```

## ✨ 优势

1. **集中管理**: 所有本地化文本在一个文件中，便于维护
2. **类型安全**: 使用 Swift 字典，编译时检查键值
3. **智能回退**: 自动回退到英文或系统本地化
4. **便利访问**: 提供多种访问方式，适应不同使用场景
5. **动态切换**: 支持运行时语言切换
6. **扩展性强**: 易于添加新语言支持

## 🔧 迁移步骤

### 1. 立即可用
新的本地化系统已经包含了所有现有的本地化文本，可以立即使用。

### 2. 更新代码（可选）
将现有的 `NSLocalizedString` 调用替换为新的方法：

```swift
// 旧方法
NSLocalizedString("保存", comment: "")

// 新方法（推荐）
"保存".localized
```

### 3. 添加新的本地化文本
在 `LocalizationData` 结构中添加新的键值对：

```swift
// 在 english 字典中添加
"New Key": "New English Text",

// 在 chinese 字典中添加
"New Key": "新的中文文本",
```

## 🛡️ 备份与回滚

### 备份位置
原本地化文件已备份到 `backup_localizations/` 目录。

### 回滚方法
如果需要回滚到原系统：
1. 恢复 `backup_localizations/` 中的文件
2. 移除新增的本地化管理文件
3. 更新代码中的本地化调用

## 📝 注意事项

1. **兼容性**: 新系统与现有的 `.lproj` 文件兼容，作为备用方案
2. **性能**: 内存中的字典访问比文件系统访问更快
3. **维护**: 添加新文本时需要同时更新英文和中文版本
4. **测试**: 建议测试所有语言切换功能

## 🎯 下一步

1. 测试新的本地化系统
2. 逐步将代码中的本地化调用迁移到新方法
3. 根据需要添加更多语言支持
4. 考虑移除旧的 `.lproj` 文件（在充分测试后）

---

如有任何问题或需要帮助，请随时联系开发团队。
