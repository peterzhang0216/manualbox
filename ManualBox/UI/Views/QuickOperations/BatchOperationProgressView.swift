//
//  BatchOperationProgressView.swift
//  ManualBox
//
//  Created by Assistant on 2024/12/19.
//  批量操作进度视图 - 显示批量操作的详细进度
//

import SwiftUI

struct BatchOperationProgressView: View {
    @StateObject private var batchManager = BatchOperationManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingDetails = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // 操作图标和标题
                operationHeader
                
                // 进度指示器
                progressSection
                
                // 详细信息
                detailsSection
                
                // 时间信息
                timeSection
                
                Spacer()
                
                // 操作按钮
                actionButtons
            }
            .padding()
            .navigationTitle("操作进度")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("详情") {
                        showingDetails.toggle()
                    }
                }
            }
        }
        .interactiveDismissDisabled(batchManager.operationStatus.isRunning)
    }
    
    // MARK: - 操作头部
    
    private var operationHeader: some View {
        VStack(spacing: 16) {
            // 操作图标
            ZStack {
                Circle()
                    .fill(operationColor.opacity(0.2))
                    .frame(width: 80, height: 80)
                
                Image(systemName: operationIcon)
                    .font(.system(size: 32))
                    .foregroundColor(operationColor)
            }
            
            // 操作标题
            Text(operationTitle)
                .font(.title2)
                .fontWeight(.semibold)
            
            // 状态描述
            Text(statusDescription)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - 进度区域
    
    private var progressSection: some View {
        VStack(spacing: 16) {
            // 主进度条
            VStack(spacing: 8) {
                HStack {
                    Text("总体进度")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(Int(batchManager.operationProgress * 100))%")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                ProgressView(value: batchManager.operationProgress)
                    .progressViewStyle(LinearProgressViewStyle(tint: operationColor))
                    .scaleEffect(y: 2)
            }
            
            // 项目计数
            HStack {
                Text("已处理")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(batchManager.currentItemIndex) / \(batchManager.totalItems)")
                    .font(.caption)
                    .fontWeight(.medium)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - 详细信息
    
    private var detailsSection: some View {
        VStack(spacing: 12) {
            if showingDetails {
                VStack(spacing: 8) {
                    detailRow("操作类型", batchManager.currentOperation?.displayName ?? "未知")
                    detailRow("总项目数", "\(batchManager.totalItems)")
                    detailRow("当前项目", "\(batchManager.currentItemIndex)")
                    
                    if case .completed(let success, let failed) = batchManager.operationStatus {
                        detailRow("成功", "\(success)")
                        detailRow("失败", "\(failed)")
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
            }
        }
    }
    
    private func detailRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
    
    // MARK: - 时间信息
    
    private var timeSection: some View {
        VStack(spacing: 8) {
            if batchManager.estimatedTimeRemaining > 0 {
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.secondary)
                    
                    Text("预计剩余时间: \(formatTimeInterval(batchManager.estimatedTimeRemaining))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
            }
            
            if case .completed = batchManager.operationStatus {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    
                    Text("操作已完成")
                        .font(.subheadline)
                        .foregroundColor(.green)
                    
                    Spacer()
                }
            }
        }
    }
    
    // MARK: - 操作按钮
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            if batchManager.operationStatus.isRunning {
                Button("取消操作") {
                    batchManager.cancelCurrentOperation()
                }
                .buttonStyle(.bordered)
                .foregroundColor(.red)
            } else {
                Button("完成") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
            }
        }
    }
    
    // MARK: - 计算属性
    
    private var operationIcon: String {
        switch batchManager.operationStatus {
        case .preparing:
            return "gear"
        case .running:
            return batchManager.currentOperation?.icon ?? "arrow.clockwise"
        case .completed:
            return "checkmark.circle.fill"
        case .cancelled:
            return "xmark.circle.fill"
        case .failed:
            return "exclamationmark.triangle.fill"
        case .idle:
            return "circle"
        }
    }
    
    private var operationColor: Color {
        switch batchManager.operationStatus {
        case .preparing, .running:
            return .blue
        case .completed:
            return .green
        case .cancelled:
            return .orange
        case .failed:
            return .red
        case .idle:
            return .gray
        }
    }
    
    private var operationTitle: String {
        if let operation = batchManager.currentOperation {
            return "批量\(operation.displayName)"
        } else {
            return "批量操作"
        }
    }
    
    private var statusDescription: String {
        switch batchManager.operationStatus {
        case .idle:
            return "等待开始"
        case .preparing:
            return "正在准备操作..."
        case .running:
            return "正在处理项目..."
        case .completed(let success, let failed):
            if failed == 0 {
                return "成功处理了 \(success) 个项目"
            } else {
                return "成功处理 \(success) 个项目，\(failed) 个失败"
            }
        case .cancelled:
            return "操作已取消"
        case .failed(let error):
            return "操作失败: \(error.localizedDescription)"
        }
    }
    
    // MARK: - 辅助方法
    
    private func formatTimeInterval(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        
        if minutes > 0 {
            return "\(minutes)分\(seconds)秒"
        } else {
            return "\(seconds)秒"
        }
    }
}

#Preview {
    BatchOperationProgressView()
}