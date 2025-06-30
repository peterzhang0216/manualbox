//
//  ThreeColumnSettingsViewComponents.swift
//  ManualBox
//
//  Created by Assistant on 2024/12/19.
//

import SwiftUI
import Foundation

// MARK: - 状态指示器组件
struct StatusIndicator: View {
    let title: String
    let status: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            Text(status)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(color)
        }
        .padding(12)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - 主题状态指示器
struct ThemeStatusIndicator: View {
    @AppStorage("appTheme") private var appTheme: String = "system"

    var body: some View {
        StatusIndicator(
            title: "主题模式",
            status: themeDisplayName,
            color: .blue
        )
    }

    private var themeDisplayName: String {
        switch appTheme {
        case "light": return "浅色"
        case "dark": return "深色"
        case "system": return "跟随系统"
        default: return "跟随系统"
        }
    }
}

// MARK: - 主题色状态指示器
struct AccentColorStatusIndicator: View {
    @AppStorage("accentColor") private var accentColorKey: String = "blue"

    var body: some View {
        StatusIndicator(
            title: "主题色",
            status: colorDisplayName,
            color: currentColor
        )
    }

    private var colorDisplayName: String {
        switch accentColorKey {
        case "accentColor": return "系统"
        case "blue": return "蓝色"
        case "green": return "绿色"
        case "orange": return "橙色"
        case "pink": return "粉色"
        case "purple": return "紫色"
        case "red": return "红色"
        case "teal": return "青色"
        case "yellow": return "黄色"
        case "indigo": return "靛蓝"
        case "mint": return "薄荷"
        case "cyan": return "青蓝"
        case "brown": return "棕色"
        default: return "蓝色"
        }
    }

    private var currentColor: Color {
        switch accentColorKey {
        case "accentColor": return .accentColor
        case "blue": return .blue
        case "green": return .green
        case "orange": return .orange
        case "pink": return .pink
        case "purple": return .purple
        case "red": return .red
        case "teal": return .teal
        case "yellow": return .yellow
        case "indigo": return .indigo
        case "mint": return .mint
        case "cyan": return .cyan
        case "brown": return .brown
        default: return .blue
        }
    }
}

// MARK: - 同步状态指示器
struct SyncStatusIndicator: View {
    @StateObject private var syncService = CloudKitSyncService.shared

    var body: some View {
        StatusIndicator(
            title: "数据同步",
            status: syncStatusText,
            color: syncStatusColor
        )
    }

    private var syncStatusText: String {
        switch syncService.syncStatus {
        case .idle:
            return "空闲"
        case .syncing:
            return "同步中"
        case .paused:
            return "已暂停"
        case .completed:
            return "已完成"
        case .failed:
            return "失败"
        }
    }

    private var syncStatusColor: Color {
        switch syncService.syncStatus {
        case .idle:
            return .gray
        case .syncing:
            return .blue
        case .paused:
            return .orange
        case .completed:
            return .green
        case .failed:
            return .red
        }
    }
}