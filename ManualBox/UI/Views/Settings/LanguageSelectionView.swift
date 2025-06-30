//
//  LanguageSelectionView.swift
//  ManualBox
//
//  Created by Assistant on 2025/6/25.
//

import SwiftUI

// MARK: - 语言选择视图
struct LanguageSelectionView: View {
    @StateObject private var localizationManager = LocalizationManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    
    private var filteredLanguages: [LanguageInfo] {
        if searchText.isEmpty {
            return localizationManager.supportedLanguages
        } else {
            return localizationManager.supportedLanguages.filter { language in
                language.name.localizedCaseInsensitiveContains(searchText) ||
                language.nativeName.localizedCaseInsensitiveContains(searchText) ||
                language.code.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 搜索栏
                searchBar
                
                // 语言列表
                languageList
            }
            .navigationTitle("语言".localized)
            #if os(macOS)
            .platformToolbar(trailing: {
                Button("完成".localized) {
                    dismiss()
                }
            })
            #else
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(content: {
                SwiftUI.ToolbarItem(placement: .topBarTrailing) {
                    Button("完成".localized) {
                        dismiss()
                    }
                }
            })
            #endif
        }
    }
    
    // MARK: - 搜索栏
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("搜索语言".localized, text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
            
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
        #if os(macOS)
        .background(Color(nsColor: .windowBackgroundColor))
        #else
        .background(Color(.systemGray5))
        #endif
        .cornerRadius(10)
        .padding()
    }
    
    // MARK: - 语言列表
    
    private var languageList: some View {
        List {
            ForEach(filteredLanguages) { language in
                LanguageRow(
                    language: language,
                    isSelected: localizationManager.currentLanguage == language.code,
                    onSelect: {
                        selectLanguage(language)
                    }
                )
            }
        }
        .listStyle(PlainListStyle())
    }
    
    // MARK: - 语言选择
    
    private func selectLanguage(_ language: LanguageInfo) {
        withAnimation(.easeInOut(duration: 0.3)) {
            localizationManager.setLanguage(language.code)
        }
        
        // 提供触觉反馈
        #if os(iOS)
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        #endif
        
        // 延迟关闭以显示选择效果
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            dismiss()
        }
    }
}

// MARK: - 语言行
struct LanguageRow: View {
    let language: LanguageInfo
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                // 国旗
                Text(language.flag)
                    .font(.title2)
                
                // 语言信息
                VStack(alignment: .leading, spacing: 4) {
                    Text(language.nativeName)
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    if language.name != language.nativeName {
                        Text(language.name)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    if language.code != "auto" {
                        Text(language.code.uppercased())
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            #if os(macOS)
                            .background(Color(nsColor: .windowBackgroundColor))
                            #else
                            .background(Color(.systemGray5))
                            #endif
                            .cornerRadius(4)
                    }
                }
                
                Spacer()
                
                // 选择指示器
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title3)
                } else {
                    Image(systemName: "circle")
                        .foregroundColor(.secondary)
                        .font(.title3)
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 1)
        )
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - 语言设置卡片
struct LanguageSettingsCard: View {
    @StateObject private var localizationManager = LocalizationManager.shared
    @State private var showingLanguageSelection = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("语言设置".localized)
                .font(.headline)
                .fontWeight(.semibold)
            
            Button(action: {
                showingLanguageSelection = true
            }) {
                HStack {
                    // 当前语言信息
                    let currentLanguage = localizationManager.supportedLanguages.first { $0.code == localizationManager.currentLanguage }
                    
                    HStack(spacing: 12) {
                        Text(currentLanguage?.flag ?? "🌐")
                            .font(.title2)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(currentLanguage?.nativeName ?? "跟随系统")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            Text("当前语言".localized)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .padding()
                #if os(macOS)
                .background(Color(NSColor.controlBackgroundColor))
                #else
                .background(Color(.systemGray6))
                #endif
                .cornerRadius(12)
            }
            .buttonStyle(PlainButtonStyle())
            
            // RTL 支持提示
            if localizationManager.isRTL {
                HStack {
                    Image(systemName: "text.alignright")
                        .foregroundColor(.blue)
                    
                    Text("当前语言支持从右到左显示".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 4)
            }
        }
        .padding()
        #if os(macOS)
        .background(Color(NSColor.windowBackgroundColor))
        #else
        .background(Color(.systemBackground))
        #endif
        .cornerRadius(16)
        .shadow(radius: 2)
        .sheet(isPresented: $showingLanguageSelection) {
            LanguageSelectionView()
        }
    }
}

// MARK: - 语言切换动画视图
struct LanguageSwitchAnimationView: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "globe")
                    .font(.system(size: 40))
                    .foregroundColor(.blue)
                    .rotationEffect(.degrees(isAnimating ? 360 : 0))
                    .animation(.easeInOut(duration: 1.0).repeatCount(3, autoreverses: false), value: isAnimating)
            }
            
            Text("正在切换语言...".localized)
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("请稍候".localized)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - 预览
struct LanguageSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            LanguageSelectionView()
            
            LanguageSettingsCard()
                .padding()
            
            LanguageSwitchAnimationView()
        }
    }
}
