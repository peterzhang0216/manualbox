//
//  SharedUIComponents.swift
//  ManualBox
//
//  Created by Assistant on 2025/7/29.
//

import SwiftUI

// MARK: - 共享UI组件定义

/// 同步历史记录行组件 - 统一定义，避免重复
struct SharedSyncHistoryRow: View {
    let record: SyncHistoryRecord
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(record.operation)
                    .font(.headline)
                Text(formatDate(record.timestamp))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack {
                statusIcon
                Text(record.status.displayName)
                    .font(.caption)
                    .foregroundColor(statusColor)
            }
        }
        .padding(.vertical, 8)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .cornerRadius(8)
        .onTapGesture(perform: onSelect)
    }
    
    private var statusIcon: some View {
        Image(systemName: record.status.iconName)
            .foregroundColor(statusColor)
    }
    
    private var statusColor: Color {
        switch record.status {
        case .success:
            return .green
        case .failed:
            return .red
        case .inProgress:
            return .orange
        case .cancelled:
            return .gray
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

/// 推荐行组件 - 统一定义，避免重复
struct SharedRecommendationRow: View {
    let recommendation: Recommendation
    let onApply: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(recommendation.title)
                    .font(.headline)
                Text(recommendation.description)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("应用", action: onApply)
                .buttonStyle(.bordered)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(radius: 1)
    }
}

// MARK: - 支持数据结构

struct SyncHistoryRecord {
    let id: UUID
    let operation: String
    let timestamp: Date
    let status: SyncStatus
    let details: String?
    
    enum SyncStatus {
        case success
        case failed
        case inProgress
        case cancelled
        
        var displayName: String {
            switch self {
            case .success: return "成功"
            case .failed: return "失败"
            case .inProgress: return "进行中"
            case .cancelled: return "已取消"
            }
        }
        
        var iconName: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .failed: return "xmark.circle.fill"
            case .inProgress: return "clock.fill"
            case .cancelled: return "minus.circle.fill"
            }
        }
    }
}

struct Recommendation {
    let id: UUID
    let title: String
    let description: String
    let category: RecommendationCategory
    let impact: ImpactLevel
    
    enum RecommendationCategory {
        case performance
        case dataIntegrity
        case userExperience
        case security
    }
    
    enum ImpactLevel {
        case low
        case medium
        case high
        case critical
    }
}
