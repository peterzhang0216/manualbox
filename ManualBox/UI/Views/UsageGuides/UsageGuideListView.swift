//
//  UsageGuideListView.swift
//  ManualBox
//
//  Created by Assistant on 2025/6/24.
//

import SwiftUI

// MARK: - 使用指南列表视图
struct UsageGuideListView: View {
    @StateObject private var guideService = UsageGuideGenerationService.shared
    @State private var searchText = ""
    @State private var selectedDifficulty: DifficultyLevel?
    @State private var selectedGuide: ProductUsageGuide?
    @State private var showingGenerateGuide = false
    @State private var showingBatchGeneration = false
    
    private var filteredGuides: [ProductUsageGuide] {
        var guides = guideService.generatedGuides
        
        if !searchText.isEmpty {
            guides = guides.filter { guide in
                guide.title.localizedCaseInsensitiveContains(searchText) ||
                guide.productName.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        if let difficulty = selectedDifficulty {
            guides = guides.filter { $0.difficultyLevel == difficulty }
        }
        
        return guides.sorted { $0.generatedAt > $1.generatedAt }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 搜索和筛选栏
                searchAndFilterBar
                
                // 内容区域
                if filteredGuides.isEmpty {
                    emptyStateView
                } else {
                    guidesList
                }
            }
            #if os(macOS)
            .platformNavigationBarTitleDisplayMode(0)
            .platformToolbar(trailing: {
                Button("新建") {
                    showingGenerateGuide = true
                }
            })
            #else
            .navigationTitle("使用指南")
            #if os(iOS)
            .platformNavigationBarTitleDisplayMode(.large)
            #else
            .platformNavigationBarTitleDisplayMode(0)
            #endif
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button("新建") {
                        showingGenerateGuide = true
                    }
                }
            }
            #endif
            .sheet(isPresented: $showingGenerateGuide) {
                GuideGenerationView()
            }
            .sheet(isPresented: $showingBatchGeneration) {
                BatchGuideGenerationView()
            }
            .sheet(item: $selectedGuide) { guide in
                UsageGuideDetailView(guide: guide)
            }
        }
    }
    
    // MARK: - 搜索和筛选栏
    
    private var searchAndFilterBar: some View {
        VStack(spacing: 12) {
            // 搜索栏
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("搜索指南...", text: $searchText)
                    .textFieldStyle(.plain)
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(ModernColors.System.gray6))
            .cornerRadius(10)
            
            // 难度筛选
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    Button(action: {
                        selectedDifficulty = nil
                    }) {
                        Text("全部")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(selectedDifficulty == nil ? .white : .primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(selectedDifficulty == nil ? Color.blue : Color(ModernColors.System.gray6))
                            )
                    }
                    
                    ForEach(DifficultyLevel.allCases, id: \.self) { difficulty in
                        Button(action: {
                            selectedDifficulty = selectedDifficulty == difficulty ? nil : difficulty
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: difficulty.icon)
                                    .font(.caption2)
                                Text(difficulty.rawValue)
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(selectedDifficulty == difficulty ? .white : .primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(selectedDifficulty == difficulty ? Color(difficulty.color) : Color(ModernColors.System.gray6))
                            )
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding()
        .background(Color(ModernColors.Background.primary))
    }
    
    // MARK: - 指南列表
    
    private var guidesList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(filteredGuides) { guide in
                    UsageGuideCard(guide: guide) {
                        selectedGuide = guide
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - 空状态视图
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("暂无使用指南")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("为您的产品生成个性化的使用指南")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: {
                showingGenerateGuide = true
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("生成指南")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.blue)
                .cornerRadius(25)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(ModernColors.Background.secondary))
    }
}

// MARK: - 使用指南卡片
struct UsageGuideCard: View {
    let guide: ProductUsageGuide
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // 标题和产品信息
                VStack(alignment: .leading, spacing: 4) {
                    Text(guide.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    Text(guide.productName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // 指南信息
                HStack {
                    // 难度等级
                    HStack(spacing: 4) {
                        Image(systemName: guide.difficultyLevel.icon)
                            .font(.caption)
                        Text(guide.difficultyLevel.rawValue)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(Color(guide.difficultyLevel.color))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(guide.difficultyLevel.color).opacity(0.1))
                    .cornerRadius(8)
                    
                    Spacer()
                    
                    // 阅读时间
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption)
                        Text(guide.formattedReadingTime)
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                    
                    // 章节数量
                    HStack(spacing: 4) {
                        Image(systemName: "list.bullet")
                            .font(.caption)
                        Text("\(guide.sectionCount)章节")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
                
                // 生成时间
                HStack {
                    Text("生成于 \(DateFormatter.shortDateTime.string(from: guide.generatedAt))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("v\(guide.version)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(ModernColors.System.gray6))
                        .cornerRadius(4)
                }
            }
            .padding()
            .background(Color(ModernColors.Background.primary))
            .cornerRadius(12)
            .shadow(radius: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 预览
struct UsageGuideListView_Previews: PreviewProvider {
    static var previews: some View {
        UsageGuideListView()
    }
}
