//
//  OCRProgressView.swift
//  ManualBox
//
//  Created by Assistant on 2025/6/24.
//

import SwiftUI

// MARK: - OCR进度显示组件
struct OCRProgressView: View {
    @ObservedObject var ocrService = OCRService.shared
    @State private var showingStats = false
    
    var body: some View {
        VStack(spacing: 16) {
            if ocrService.isProcessing {
                processingView
            } else if let batchProgress = ocrService.batchProgress {
                batchProgressView(batchProgress)
            } else if let error = ocrService.lastError {
                errorView(error)
            } else {
                idleView
            }
        }
        .padding()
        .background(ModernColors.Background.primary)
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    // MARK: - 处理中视图
    private var processingView: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "doc.text.viewfinder")
                    .foregroundColor(.blue)
                    .font(.title2)
                
                Text("正在识别文字...")
                    .font(.headline)
                
                Spacer()
                
                Button("取消") {
                    ocrService.cancelAllProcessing()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
            ProgressView(value: ocrService.currentProgress)
                .progressViewStyle(LinearProgressViewStyle())
            
            HStack {
                Text("进度: \(Int(ocrService.currentProgress * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if ocrService.processingQueue.count > 1 {
                    Text("队列中: \(ocrService.processingQueue.count - 1)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - 批量处理进度视图
    private func batchProgressView(_ progress: BatchProgress) -> some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "doc.on.doc")
                    .foregroundColor(.blue)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("批量处理中")
                        .font(.headline)
                    
                    if let currentItem = progress.currentItem {
                        Text("当前: \(currentItem)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                Button("取消") {
                    ocrService.cancelAllProcessing()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
            ProgressView(value: progress.overallProgress)
                .progressViewStyle(LinearProgressViewStyle())
            
            HStack {
                Text(progress.progressText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if let timeRemaining = progress.estimatedTimeRemaining {
                    Text("剩余: \(formatTime(timeRemaining))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - 错误视图
    private func errorView(_ error: OCRError) -> some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.red)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("处理失败")
                        .font(.headline)
                        .foregroundColor(.red)
                    
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
            }
            
            if let suggestion = error.recoverySuggestion {
                HStack {
                    Image(systemName: "lightbulb")
                        .foregroundColor(.orange)
                        .font(.caption)
                    
                    Text(suggestion)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                    
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }
            
            HStack {
                Button("重试") {
                    // 这里需要传入具体的Manual对象，暂时清除错误状态
                    ocrService.lastError = nil
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                
                Button("忽略") {
                    ocrService.lastError = nil
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Spacer()
            }
        }
    }
    
    // MARK: - 空闲状态视图
    private var idleView: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "doc.text")
                    .foregroundColor(.green)
                    .font(.title2)
                
                Text("OCR服务就绪")
                    .font(.headline)
                    .foregroundColor(.green)
                
                Spacer()
                
                Button("统计") {
                    showingStats.toggle()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
            if showingStats {
                statsView
            }
        }
    }
    
    // MARK: - 统计信息视图
    private var statsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            
            Text("性能统计")
                .font(.subheadline)
                .fontWeight(.medium)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("总请求: \(ocrService.processingStats.totalRequests)")
                    Text("成功率: \(String(format: "%.1f", ocrService.processingStats.successRate * 100))%")
                }
                .font(.caption)
                .foregroundColor(.secondary)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("平均时间: \(String(format: "%.2f", ocrService.processingStats.averageProcessingTime))s")
                    Text("失败: \(ocrService.processingStats.failedRequests)")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            HStack {
                Button("重置统计") {
                    ocrService.resetStatistics()
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
                
                Spacer()
                
                Button("详细报告") {
                    let report = ocrService.getPerformanceReport()
                    print(report)
                    // 这里可以添加分享或导出功能
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }
        }
        .padding(.top, 8)
    }
    
    // MARK: - 辅助方法
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        
        if minutes > 0 {
            return "\(minutes)分\(seconds)秒"
        } else {
            return "\(seconds)秒"
        }
    }
}

// MARK: - 预览
struct OCRProgressView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            OCRProgressView()
            
            // 模拟处理中状态
            OCRProgressView()
                .onAppear {
                    OCRService.shared.isProcessing = true
                    OCRService.shared.currentProgress = 0.6
                }
        }
        .padding()
    }
}
