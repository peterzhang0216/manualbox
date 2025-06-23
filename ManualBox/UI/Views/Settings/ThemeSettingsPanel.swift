import SwiftUI

// MARK: - 主题设置面板
struct ThemeSettingsPanel: View {
    @AppStorage("appTheme") private var appTheme: String = "system"
    @AppStorage("accentColor") private var accentColor: String = "accentColor"
    @EnvironmentObject private var settingsViewModel: SettingsViewModel
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(NSLocalizedString("Appearance & Theme", comment: ""))
                    .font(.title2).bold()
                    .padding(.top, 24)
                    .foregroundColor(.accentColor)
                
                Divider().background(Color.accentColor.opacity(0.3))
                
                // 主题设置卡片
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        Image(systemName: "circle.lefthalf.filled")
                            .font(.system(size: 22))
                            .foregroundColor(.accentColor)
                            .frame(width: 36, height: 36)
                            .background(Color.accentColor.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        
                        Text(NSLocalizedString("Theme Mode", comment: ""))
                            .font(.headline)
                        
                        Spacer()
                    }
                    
                    ThemePickerView()
                        .padding(.leading, 8)
                }
                .padding()
                .background(Color.secondary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // 主题色设置卡片
                AccentColorPickerView()
                
                // 语言设置卡片
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        Image(systemName: "globe")
                            .font(.system(size: 22))
                            .foregroundColor(.accentColor)
                            .frame(width: 36, height: 36)
                            .background(Color.accentColor.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        
                        Text(NSLocalizedString("Language", comment: ""))
                            .font(.headline)
                        
                        Spacer()
                    }
                    
                    LanguagePickerView()
                        .padding(.leading, 8)
                }
                .padding()
                .background(Color.secondary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                Spacer()
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
            .frame(maxWidth: 600, alignment: .leading)
        }
    }
}

#Preview {
    ThemeSettingsPanel()
        .environmentObject(SettingsViewModel(viewContext: PersistenceController.preview.container.viewContext))
}