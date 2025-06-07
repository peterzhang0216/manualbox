# ManualBox 项目引用更新指南

## 1. ManualBoxApp.swift 更新

### 1.1 导入语句更新
```swift
import SwiftUI
import UserNotifications
import CoreData

// 添加以下导入
import Core.Services.PersistenceController
import Core.Services.NotificationManager
import Core.Services.NotificationScheduler
```

### 1.2 类引用更新
```swift
@main
struct ManualBoxApp: App {
    // 更新引用路径
    let persistenceController = PersistenceController.shared
    @StateObject private var notificationManager = AppNotificationManager()
    // ...
}
```

## 2. ContentView.swift 更新

### 2.1 导入语句更新
```swift
import SwiftUI
import CoreData

// 添加以下导入
import Core.Models.Product
import Core.Models.Tag
import Core.Models.Order
import Core.Utils.Calendar+Extension
import UI.Components.ProductRowView
import UI.Components.ProductDetailView
```

### 2.2 视图引用更新
```swift
struct ContentView: View {
    // 更新视图引用
    @Environment(\.managedObjectContext) private var viewContext
    // ...
}
```

## 3. 模型文件更新

### 3.1 Core/Models 目录下的文件
- 检查并更新所有模型文件中的相互引用
- 确保所有扩展文件都正确引用了其扩展的类型

### 3.2 示例：Product+Extensions.swift
```swift
import Foundation
import CoreData

// 添加必要的导入
import Core.Models.Order
import Core.Models.Tag
```

## 4. 服务文件更新

### 4.1 Core/Services 目录下的文件
- 更新所有服务文件中的模型引用
- 确保服务之间的相互引用正确

### 4.2 示例：PersistenceController.swift
```swift
import CoreData
import Foundation

// 添加必要的导入
import Core.Models.Product
import Core.Models.Category
import Core.Models.Tag
```

## 5. 工具类更新

### 5.1 Core/Utils 目录下的文件
- 更新所有工具类中的引用
- 确保扩展文件正确引用了其扩展的类型

### 5.2 示例：Calendar+Extension.swift
```swift
import Foundation

extension Calendar {
    // 确保所有使用到的类型都已正确导入
}
```

## 6. 验证步骤

1. 打开 Xcode 项目
2. 选择 Product > Clean Build Folder
3. 选择 Product > Build
4. 检查是否有任何编译错误
5. 运行项目，验证功能是否正常

## 7. 常见问题解决

### 7.1 找不到类型
- 检查导入语句是否正确
- 确保文件在正确的目录中
- 验证文件名是否正确

### 7.2 循环引用
- 检查模型之间的相互引用
- 使用适当的访问控制级别
- 考虑使用协议来解耦

### 7.3 编译错误
- 检查所有导入语句
- 验证文件路径
- 确保所有必要的文件都已移动

## 8. 注意事项

1. 每次更新后都要验证项目可以编译
2. 保持文件组织的一致性
3. 确保所有引用都使用正确的路径
4. 记录所有更改
5. 在更新过程中保持代码的可维护性 