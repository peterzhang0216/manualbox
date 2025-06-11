//
//  ProductDeletionLogic.swift
//  ManualBox
//
//  Created by Peter's Mac on 2025/4/27.
//

import SwiftUI
import CoreData

#if os(iOS)
import UIKit
#else
import AppKit
#endif

struct ProductDeletionLogic {
    static func deleteProducts(
        offsets: IndexSet,
        filteredProducts: [Product],
        viewContext: NSManagedObjectContext
    ) {
        withAnimation {
            let productsToDelete = offsets.map { filteredProducts[$0] }
            // 显示删除确认对话框
#if os(iOS)
            let alert = UIAlertController(
                title: "确认删除",
                message: "确定要删除选中的\(productsToDelete.count)个产品吗？此操作不可恢复。",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "取消", style: .cancel))
            alert.addAction(UIAlertAction(title: "删除", style: .destructive) { _ in
                deleteConfirmed(products: productsToDelete, viewContext: viewContext)
            })
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let viewController = windowScene.windows.first?.rootViewController {
                viewController.present(alert, animated: true)
            }
#else
            let alert = NSAlert()
            alert.messageText = "确认删除"
            alert.informativeText = "确定要删除选中的\(productsToDelete.count)个产品吗？此操作不可恢复。"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "删除")
            alert.addButton(withTitle: "取消")
            if alert.runModal() == .alertFirstButtonReturn {
                deleteConfirmed(products: productsToDelete, viewContext: viewContext)
            }
#endif
        }
    }
    
    static func deleteConfirmed(products: [Product], viewContext: NSManagedObjectContext) {
        for product in products {
            viewContext.delete(product)
        }
        do {
            try viewContext.save()
        } catch {
            // 显示错误提示
#if os(iOS)
            let alert = UIAlertController(
                title: "删除失败",
                message: error.localizedDescription,
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "确定", style: .default))
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let viewController = windowScene.windows.first?.rootViewController {
                viewController.present(alert, animated: true)
            }
#else
            let alert = NSAlert(error: error)
            alert.alertStyle = .critical
            alert.runModal()
#endif
        }
    }
}