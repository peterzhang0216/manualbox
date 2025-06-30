//
//  OCRSettingsView.swift
//  ManualBox
//
//  Created by Assistant on 2025/6/24.
//

import SwiftUI

// MARK: - OCR设置视图
struct OCRSettingsView: View {
    @AppStorage("ocrRecognitionLevel") private var recognitionLevel: Int = 0 // 0: accurate, 1: fast
    @AppStorage("ocrLanguageCorrection") private var languageCorrection: Bool = true
    @AppStorage("ocrMinimumTextHeight") private var minimumTextHeight: Double = 0.02
    @AppStorage("ocrAutoRetry") private var autoRetry: Bool = true
    @AppStorage("ocrMaxRetries") private var maxRetries: Int = 3
    @AppStorage("ocrBatchSize") private var batchSize: Int = 5
    
    @State private var showingAdvancedSettings = false
    @State private var showingPerformanceReport = false
    @State private var customWords: String = ""
    
    @ObservedObject private var ocrService = OCRService.shared
    
    var body: some View {
        Form {
            basicSettingsSection
            
            advancedSettingsSection
            
            performanceSection
            
            statisticsSection
        }
        .navigationTitle("OCR设置")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .sheet(isPresented: $showingPerformanceReport) {
            performanceReportView
        }
        #if os(macOS)
        .platformToolbar(trailing: {
            Button("完成") {
                showingPerformanceReport = false
            }
        })
        #else
        .toolbar(content: {
            SwiftUI.ToolbarItem(placement: .navigationBarTrailing) {
                Button("完成") {
                    showingPerformanceReport = false
                }
            }
        })
        #endif
    }
    
    // MARK: - 基础设置
    private var basicSettingsSection: some View {
        Section("基础设置") {
            // 识别精度
            Picker("识别精度", selection: $recognitionLevel) {
                Text("高精度（推荐）").tag(0)
                Text("快速识别").tag(1)
            }
            .pickerStyle(.segmented)
            
            // 语言校正
            Toggle("启用语言校正", isOn: $languageCorrection)
            
            // 自动重试
            Toggle("失败时自动重试", isOn: $autoRetry)
            
            if autoRetry {
                Stepper("最大重试次数: \(maxRetries)", value: $maxRetries, in: 1...5)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - 高级设置
    private var advancedSettingsSection: some View {
        Section("高级设置") {
            DisclosureGroup("高级选项", isExpanded: $showingAdvancedSettings) {
                VStack(alignment: .leading, spacing: 12) {
                    // 最小文字高度
                    VStack(alignment: .leading, spacing: 4) {
                        Text("最小文字高度: \(String(format: "%.3f", minimumTextHeight))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Slider(value: $minimumTextHeight, in: 0.01...0.1, step: 0.001) {
                            Text("最小文字高度")
                        }
                    }
                    
                    // 批处理大小
                    Stepper("批处理大小: \(batchSize)", value: $batchSize, in: 1...10)
                    
                    // 自定义词汇
                    VStack(alignment: .leading, spacing: 4) {
                        Text("自定义词汇（用逗号分隔）")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        TextField("输入自定义词汇", text: $customWords, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(3...6)
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }
    
    // MARK: - 性能监控
    private var performanceSection: some View {
        Section("性能监控") {
            // 当前状态
            HStack {
                Image(systemName: ocrService.isProcessing ? "gearshape.fill" : "checkmark.circle.fill")
                    .foregroundColor(ocrService.isProcessing ? .orange : .green)
                
                Text(ocrService.isProcessing ? "处理中..." : "就绪")
                    .font(.headline)
                
                Spacer()
                
                if ocrService.processingQueue.count > 0 {
                    Text("队列: \(ocrService.processingQueue.count)")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.2))
                        .cornerRadius(8)
                }
            }
            
            // 进度显示
            if ocrService.isProcessing {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("进度")
                        Spacer()
                        Text("\(Int(ocrService.currentProgress * 100))%")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    
                    ProgressView(value: ocrService.currentProgress)
                        .progressViewStyle(LinearProgressViewStyle())
                }
            }
            
            // 批量处理进度
            if let batchProgress = ocrService.batchProgress {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("批量处理")
                        Spacer()
                        Text("\(batchProgress.completedItems)/\(batchProgress.totalItems)")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    
                    ProgressView(value: batchProgress.overallProgress)
                        .progressViewStyle(LinearProgressViewStyle())
                    
                    if let currentItem = batchProgress.currentItem {
                        Text("当前: \(currentItem)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            
            // 错误显示
            if let error = ocrService.lastError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("最近错误")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(error.localizedDescription)
                            .font(.caption)
                            .foregroundColor(.red)
                            .lineLimit(2)
                    }
                    
                    Spacer()
                    
                    Button("清除") {
                        ocrService.lastError = nil
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }
            }
        }
    }
    
    // MARK: - 统计信息
    private var statisticsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("统计信息")
                .font(.headline)
                .fontWeight(.semibold)

            let stats = ocrService.processingStats

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("总请求")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(stats.totalRequests)")
                        .font(.headline)
                }

                Spacer()

                VStack(alignment: .center, spacing: 4) {
                    Text("成功率")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(String(format: "%.1f", stats.successRate * 100))%")
                        .font(.headline)
                        .foregroundColor(stats.successRate > 0.8 ? .green : .orange)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("平均时间")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(String(format: "%.2f", stats.averageProcessingTime))s")
                        .font(.headline)
                }
            }

            // 操作按钮
            HStack {
                Button("查看详细报告") {
                    showingPerformanceReport = true
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("重置统计") {
                    ocrService.resetStatistics()
                }
                .buttonStyle(.bordered)
                .foregroundColor(.red)
            }

            // 取消所有处理
            if ocrService.isProcessing || !ocrService.processingQueue.isEmpty {
                Button("取消所有处理") {
                    ocrService.cancelAllProcessing()
                }
                .buttonStyle(.borderedProminent)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(ModernColors.System.gray6)
        .cornerRadius(12)
    }
    
    // MARK: - 性能报告视图
    private var performanceReportView: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(ocrService.getPerformanceReport().formattedReport)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                        #if os(macOS)
                        .background(Color(NSColor.controlBackgroundColor))
                        #else
                        .background(Color(.systemGray6))
                        #endif
                        .cornerRadius(8)
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("性能报告")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }
}

// MARK: - 预览
struct OCRSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            OCRSettingsView()
        }
    }
}
