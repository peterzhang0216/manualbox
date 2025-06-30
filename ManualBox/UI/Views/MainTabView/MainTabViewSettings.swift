//
//  MainTabViewSettings.swift
//  ManualBox
//
//  Created by Peter's Mac on 2025/5/10.
//

import SwiftUI
import CoreData

// MARK: - Main Tab View Settings

extension MainTabView {
    
    // MARK: - 设置视图
    
    // 设置详情视图（中间栏）- 使用三栏设置系统
    @ViewBuilder
    func settingsDetailView(for panel: SettingsPanel) -> some View {
        // 使用三栏设置系统
        ThreeColumnSettingsView()
            .environmentObject(SettingsManager.shared)
            .id(panel.rawValue) // 确保面板切换时视图刷新
    }
    
    // 设置详情面板视图（右侧栏）- 使用新的重构设置系统
    @ViewBuilder
    func settingsDetailPanelView(for panel: SettingsPanel) -> some View {
        // 在新的重构设置系统中，详情已经集成在主视图中
        // 这里可以显示设置概览或者空视图
        SettingsOverviewPanel(panel: panel)
            .environmentObject(SettingsManager.shared)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(settingsDetailBackgroundColor)
    }
    
    // MARK: - 设置面板摘要视图
    
    @ViewBuilder
    func settingsNotificationSummary() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("通知设置概览")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("管理应用通知偏好，包括保修提醒、维修通知等。")
                .font(.body)
                .foregroundColor(.secondary)
            
            HStack {
                Image(systemName: "bell.badge")
                    .foregroundColor(.orange)
                Text("通知状态: \(settingsViewModel.enableNotifications ? "已启用" : "已禁用")")
                    .font(.subheadline)
                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
        }
    }
    
    @ViewBuilder
    func settingsThemeSummary() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("外观设置概览")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("自定义应用外观，包括主题模式、强调色等。")
                .font(.body)
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "circle.lefthalf.filled")
                        .foregroundColor(.purple)
                    Text("主题: \(themeDisplayName)")
                        .font(.subheadline)
                    Spacer()
                }
                
                HStack {
                    Image(systemName: "paintbrush.pointed")
                        .foregroundColor(.accentColor)
                    Text("强调色: \(accentColorDisplayName)")
                        .font(.subheadline)
                    Spacer()
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
        }
    }
    
    @ViewBuilder
    func settingsDataSummary() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("数据设置概览")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("管理默认设置和数据，包括保修期、OCR等。")
                .font(.body)
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.blue)
                    Text("默认保修期: \(settingsViewModel.defaultWarrantyPeriod)个月")
                        .font(.subheadline)
                    Spacer()
                }
                
                HStack {
                    Image(systemName: "doc.text.viewfinder")
                        .foregroundColor(.green)
                    Text("OCR识别: \(settingsViewModel.enableOCRByDefault ? "默认启用" : "默认禁用")")
                        .font(.subheadline)
                    Spacer()
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
        }
    }
    
    @ViewBuilder
    func settingsAboutSummary() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("关于应用")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("查看应用信息、版本号、隐私政策等。")
                .font(.body)
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                    Text("ManualBox")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Text("v1.0.0")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Image(systemName: "shield.checkered")
                        .foregroundColor(.green)
                    Text("隐私保护")
                        .font(.subheadline)
                    Spacer()
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
        }
    }
}