# 📘 ManualBox 技术开发文档

> 说明书盒子｜一款聚焦数字化说明书与订单管理的多平台 App（iOS + macOS）

## 🧭 产品愿景

ManualBox 致力于帮助用户集中管理商品说明书、订单信息与保修记录，通过本地加密与 iCloud 同步确保数据私密可靠，打造轻量高效的家庭数字收纳中心。

## 🧩 功能结构与模块划分

```
ManualBox
├── AppDelegate / SceneDelegate
├── Modules/
│   ├── ProductModule/
│   ├── OrderModule/
│   ├── WarrantyModule/
│   ├── SearchModule/
│   ├── SyncExportModule/
├── Shared/
│   ├── Models/
│   ├── Services/
│   └── Utilities/
├── UI/
│   ├── Views/
│   └── Components/
```

## 🛠 技术选型与架构说明

| 模块 | 技术方案 | 描述 |
|------|----------|------|
| 前端架构 | SwiftUI + MVVM | 使用数据驱动架构 |
| 本地数据 | CoreData（加密） | 加密存储所有商品与订单信息 |
| 云同步 | iCloudKit | 多设备间同步 |
| 文件处理 | QuickLook + PDFKit | 支持 PDF/图片预览 |
| OCR 识别 | VisionKit / Tesseract | OCR 优化搜索 |
| 通知提醒 | UNUserNotificationCenter | 本地推送 |
| 导出服务 |  PDF 生成器 | 支持导出商品记录 |
