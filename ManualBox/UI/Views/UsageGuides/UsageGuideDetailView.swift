//
//  UsageGuideDetailView.swift
//  ManualBox
//
//  Created by Assistant on 2025/6/24.
//

import SwiftUI

// MARK: - 使用指南详情视图
struct UsageGuideDetailView: View {
    let guide: ProductUsageGuide
    @Environment(\.dismiss) private var dismiss
    @State private var selectedSection: GuideSection?
    @State private var showingShareSheet = false
    @State private var showingPrintOptions = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 指南头部信息
                    guideHeader
                    
                    // 指南概览
                    guideOverview
                    
                    // 章节列表
                    sectionsView
                }
                .padding()
            }
            .navigationTitle(guide.title)
            #if os(iOS)
            .platformNavigationBarTitleDisplayMode(.inline)
            #else
            .platformNavigationBarTitleDisplayMode(0)
            #endif
            .platformToolbar(trailing: {
                HStack(spacing: 12) {
                    Button(action: { showingShareSheet = true }) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    Button(action: { showingPrintOptions = true }) {
                        Image(systemName: "printer")
                    }
                    Button("关闭") { dismiss() }
                }
            })
            .sheet(isPresented: $showingShareSheet) {
                ShareSheet(items: [generateShareContent()])
            }
            .sheet(isPresented: $showingPrintOptions) {
                PrintOptionsView(guide: guide)
            }
            .sheet(item: $selectedSection) { section in
                SectionDetailView(section: section, guide: guide)
            }
        }
    }
    
    // MARK: - 指南头部
    
    private var guideHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(guide.title)
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(guide.subtitle)
                .font(.title3)
                .foregroundColor(.secondary)
            
            HStack {
                // 难度等级
                HStack(spacing: 6) {
                    Image(systemName: guide.difficultyLevel.icon)
                        .font(.subheadline)
                    Text(guide.difficultyLevel.rawValue)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .foregroundColor(Color(guide.difficultyLevel.color))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(guide.difficultyLevel.color).opacity(0.1))
                .cornerRadius(12)
                
                Spacer()
                
                // 阅读时间
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.subheadline)
                    Text(guide.formattedReadingTime)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .foregroundColor(.blue)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
            }
        }
        .padding()
        .background(Color(ModernColors.Background.primary))
        .cornerRadius(16)
        .shadow(radius: 2)
    }
    
    // MARK: - 指南概览
    
    private var guideOverview: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("指南概览")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                OverviewCard(
                    title: "章节数量",
                    value: "\(guide.sectionCount)",
                    subtitle: "个章节",
                    color: .blue,
                    icon: "list.bullet"
                )
                OverviewCard(
                    title: "内容长度",
                    value: "\(guide.totalContentLength)字",
                    subtitle: "总字数",
                    color: .green,
                    icon: "doc.text"
                )
                OverviewCard(
                    title: "生成版本",
                    value: "v\(guide.version)",
                    subtitle: "版本号",
                    color: .orange,
                    icon: "number.circle"
                )
                OverviewCard(
                    title: "语言",
                    value: guide.language == "zh-CN" ? "中文" : guide.language,
                    subtitle: "显示语言",
                    color: .purple,
                    icon: "globe"
                )
            }
            
            // 生成信息
            VStack(alignment: .leading, spacing: 4) {
                Text("生成信息")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Text("生成时间：\(DateFormatter.longDateTime.string(from: guide.generatedAt))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("产品：\(guide.productName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(ModernColors.Background.primary))
        .cornerRadius(16)
        .shadow(radius: 2)
    }
    
    // MARK: - 章节视图
    
    private var sectionsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("指南内容")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVStack(spacing: 12) {
                ForEach(guide.sections) { section in
                    SectionCard(section: section) {
                        selectedSection = section
                    }
                }
            }
        }
    }
    
    // MARK: - 分享内容生成
    
    private func generateShareContent() -> String {
        var content = """
        \(guide.title)
        \(guide.subtitle)
        
        难度等级：\(guide.difficultyLevel.rawValue)
        预计阅读时间：\(guide.formattedReadingTime)
        章节数量：\(guide.sectionCount)
        
        """
        
        for section in guide.sections {
            content += """
            
            \(section.title)
            \(section.formattedContent)
            
            """
        }
        
        content += """
        
        ---
        由 ManualBox 自动生成
        生成时间：\(DateFormatter.longDateTime.string(from: guide.generatedAt))
        """
        
        return content
    }
}

// MARK: - 概览卡片 (使用 ProductValuationView.swift 中的定义)

// MARK: - 章节卡片
struct SectionCard: View {
    let section: GuideSection
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // 章节图标
                Image(systemName: section.type.icon)
                    .font(.title2)
                    .foregroundColor(Color(section.type.color))
                    .frame(width: 40, height: 40)
                    .background(Color(section.type.color).opacity(0.1))
                    .cornerRadius(10)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(section.title)
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(section.contentPreview)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    
                    Text("\(section.content.count) 项内容")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(ModernColors.Background.primary))
            .cornerRadius(12)
            .shadow(radius: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 分享表单
#if os(iOS)
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#else
struct ShareSheet: View {
    let items: [Any]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text("分享选项")
                .font(.headline)

            Text("macOS 分享功能")
                .foregroundColor(.secondary)

            Button("关闭") {
                dismiss()
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .frame(width: 300, height: 200)
    }
}
#endif

// MARK: - 打印选项视图
struct PrintOptionsView: View {
    let guide: ProductUsageGuide
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Text("打印功能将在后续版本中实现")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            .navigationTitle("打印选项")
            #if os(macOS)
            .platformToolbar(trailing: {
                Button("关闭") {
                    dismiss()
                }
            })
            #else
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(content: {
                SwiftUI.ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            })
            #endif
        }
    }
}

// MARK: - DateFormatter 扩展 (使用 StatisticsModels.swift 中的定义)

// MARK: - 预览
struct UsageGuideDetailView_Previews: PreviewProvider {
    static var previews: some View {
        UsageGuideDetailView(guide: sampleGuide)
    }
    
    static var sampleGuide: ProductUsageGuide {
        ProductUsageGuide(
            id: UUID(),
            productId: UUID(),
            productName: "iPhone 15 Pro",
            title: "iPhone 15 Pro 使用指南",
            subtitle: "Apple iPhone 15 Pro 快速上手指南",
            sections: [
                GuideSection(
                    id: UUID(),
                    title: "产品概述",
                    type: .overview,
                    priority: 1,
                    content: ["这是一款高端智能手机", "具有先进的摄影功能"]
                ),
                GuideSection(
                    id: UUID(),
                    title: "初始设置",
                    type: .setup,
                    priority: 2,
                    content: ["开机设置", "Apple ID 登录", "数据迁移"]
                )
            ],
            estimatedReadingTime: 15,
            difficultyLevel: .intermediate,
            generatedAt: Date(),
            version: "1.0",
            language: "zh-CN"
        )
    }
}
