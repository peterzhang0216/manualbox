//
//  ThreeColumnSettingsViewOverviews.swift
//  ManualBox
//
//  Created by Assistant on 2024/12/19.
//

import SwiftUI
import Foundation

// MARK: - 面板概览视图扩展
extension ThreeColumnSettingsView {
    
    // MARK: - 通知概览
    @ViewBuilder
    func notificationOverview() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("通知与提醒设置")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("管理应用的通知权限、提醒计划和免打扰时段设置。")
                .font(.body)
                .foregroundColor(.secondary)
            
            // 快速状态显示
            HStack {
                StatusIndicator(
                    title: "通知权限",
                    status: viewModel.enableNotifications ? "已启用" : "已禁用",
                    color: viewModel.enableNotifications ? .green : .red
                )
                
                StatusIndicator(
                    title: "免打扰",
                    status: viewModel.enableSilentPeriod ? "已启用" : "已禁用",
                    color: viewModel.enableSilentPeriod ? .orange : .gray
                )
            }
        }
    }
    
    // MARK: - 主题概览
    @ViewBuilder
    func themeOverview() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("外观与主题设置")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("自定义应用的外观、主题模式和显示效果。")
                .font(.body)
                .foregroundColor(.secondary)

            // 快速状态显示
            HStack {
                ThemeStatusIndicator()
                AccentColorStatusIndicator()
            }
        }
    }

    // MARK: - 应用设置概览
    @ViewBuilder
    func appSettingsOverview() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("应用设置")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("配置默认参数、OCR设置和高级选项。")
                .font(.body)
                .foregroundColor(.secondary)

            // 快速状态显示
            HStack {
                StatusIndicator(
                    title: "默认保修期",
                    status: "\(viewModel.defaultWarrantyPeriod)个月",
                    color: .blue
                )

                StatusIndicator(
                    title: "OCR识别",
                    status: viewModel.enableOCRByDefault ? "默认启用" : "默认关闭",
                    color: viewModel.enableOCRByDefault ? .green : .gray
                )
            }
        }
    }

    // MARK: - 数据管理概览
    @ViewBuilder
    func dataOverview() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("数据管理")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("管理数据同步、备份恢复、导入导出和数据清理操作。")
                .font(.body)
                .foregroundColor(.secondary)

            // 快速状态显示
            HStack {
                SyncStatusIndicator()

                StatusIndicator(
                    title: "数据备份",
                    status: "可用",
                    color: .green
                )

                StatusIndicator(
                    title: "数据清理",
                    status: "维护工具",
                    color: .orange
                )
            }
        }
    }
    
    // MARK: - 关于概览
    @ViewBuilder
    func aboutOverview() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("关于与支持")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("查看应用信息、管理语言设置、访问法律文档和获取技术支持。")
                .font(.body)
                .foregroundColor(.secondary)
        }
    }
}