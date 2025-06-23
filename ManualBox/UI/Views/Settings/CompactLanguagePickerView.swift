import SwiftUI

// MARK: - 紧凑型语言选择器
struct CompactLanguagePickerView: View {
    @StateObject private var localizationManager = LocalizationManager.shared
    @AppStorage("app_language") private var selectedLanguage: String = "auto"
    
    let languages: [(key: String, name: String, flag: String)] = [
        ("auto", "跟随系统", "🌐"),
        ("zh-Hans", "简体中文", "🇨🇳"),
        ("en", "English", "🇺🇸")
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 当前语言显示
            HStack(spacing: 12) {
                Image(systemName: "globe")
                    .font(.system(size: 20))
                    .foregroundColor(.green)
                    .frame(width: 32, height: 32)
                    .background(Color.green.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("显示语言")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(currentLanguageDisplayName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // 语言选择菜单
                Menu {
                    ForEach(languages, id: \.key) { language in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedLanguage = language.key
                                localizationManager.setLanguage(language.key)
                            }
                        } label: {
                            HStack {
                                Text(language.flag)
                                Text(language.name)
                                Spacer()
                                if selectedLanguage == language.key {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(currentLanguageFlag)
                            .font(.title3)
                        Text("更改")
                            .font(.subheadline)
                            .foregroundColor(.accentColor)
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.accentColor.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            .padding(.vertical, 4)
        }
        .onAppear {
            selectedLanguage = localizationManager.currentLanguage
        }
    }
    
    // MARK: - 计算属性
    private var currentLanguageDisplayName: String {
        languages.first { $0.key == selectedLanguage }?.name ?? "跟随系统"
    }
    
    private var currentLanguageFlag: String {
        languages.first { $0.key == selectedLanguage }?.flag ?? "🌐"
    }
}

#Preview {
    CompactLanguagePickerView()
        .padding()
}
