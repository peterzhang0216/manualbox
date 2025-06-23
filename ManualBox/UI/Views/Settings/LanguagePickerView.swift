import SwiftUI

// MARK: - 语言选择器
struct LanguagePickerView: View {
    @AppStorage("selectedLanguage") private var selectedLanguage: String = "auto"
    
    let languages: [(key: String, name: String, flag: String)] = [
        ("auto", "跟随系统", "🌐"),
        ("zh-Hans", "简体中文", "🇨🇳"),
        ("zh-Hant", "繁體中文", "🇹🇼"),
        ("en", "英文", "🇺🇸"),
        ("ja", "日本語", "🇯🇵"),
        ("ko", "한국어", "🇰🇷")
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "globe")
                    .font(.system(size: 22))
                    .foregroundColor(.accentColor)
                    .frame(width: 36, height: 36)
                    .background(Color.accentColor.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                
                Text("语言".localized)
                    .font(.headline)
                
                Spacer()
            }
            
            VStack(spacing: 8) {
                ForEach(languages, id: \.key) { language in
                    HStack(spacing: 12) {
                        Text(language.flag)
                            .font(.title2)
                        
                        Text(language.name)
                            .font(.body)
                        
                        Spacer()
                        
                        if selectedLanguage == language.key {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.accentColor)
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(selectedLanguage == language.key ? Color.accentColor.opacity(0.1) : Color.clear)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedLanguage = language.key
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    LanguagePickerView()
        .padding()
}