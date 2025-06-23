import SwiftUI

// MARK: - 本地化演示视图
struct LocalizationDemoView: View {
    @StateObject private var localizationManager = LocalizationManager.shared
    @State private var selectedLanguage: String = "auto"
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    
                    // 语言选择器
                    languageSelector
                    
                    Divider()
                    
                    // 基本文本演示
                    basicTextDemo
                    
                    Divider()
                    
                    // 操作按钮演示
                    actionButtonsDemo
                    
                    Divider()
                    
                    // 状态消息演示
                    statusMessagesDemo
                    
                    Divider()
                    
                    // 产品相关演示
                    productRelatedDemo
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("本地化演示")
            .onAppear {
                selectedLanguage = localizationManager.currentLanguage
            }
        }
    }
    
    // MARK: - 语言选择器
    private var languageSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("选择语言 / Select Language")
                .font(.headline)
                .foregroundColor(.primary)
            
            Picker("Language", selection: $selectedLanguage) {
                Text("跟随系统 / Follow System").tag("auto")
                Text("中文").tag("zh-Hans")
                Text("English").tag("en")
            }
            .pickerStyle(SegmentedPickerStyle())
            .onChange(of: selectedLanguage) { _, newLanguage in
                localizationManager.setLanguage(newLanguage)
            }
        }
    }
    
    // MARK: - 基本文本演示
    private var basicTextDemo: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("基本界面文本 / Basic UI Text")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: 4) {
                demoRow(key: "Settings", value: "Settings".localized)
                demoRow(key: "Products", value: "Products".localized)
                demoRow(key: "Categories", value: "Categories".localized)
                demoRow(key: "Tags", value: "Tags".localized)
            }
        }
    }
    
    // MARK: - 操作按钮演示
    private var actionButtonsDemo: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("操作按钮 / Action Buttons")
                .font(.headline)
                .foregroundColor(.primary)
            
            HStack(spacing: 12) {
                Button("保存".localized) { }
                    .buttonStyle(.borderedProminent)

                Button("取消".localized) { }
                    .buttonStyle(.bordered)

                Button("删除".localized) { }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)
            }
        }
    }
    
    // MARK: - 状态消息演示
    private var statusMessagesDemo: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("状态消息 / Status Messages")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: 4) {
                statusRow(message: "Loading...".localized, color: .blue)
                statusRow(message: "Success".localized, color: .green)
                statusRow(message: "Error".localized, color: .red)
                statusRow(message: "Warning".localized, color: .orange)
            }
        }
    }
    
    // MARK: - 产品相关演示
    private var productRelatedDemo: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("产品管理 / Product Management")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: 4) {
                demoRow(key: "Add Product", value: "Add Product".localized)
                demoRow(key: "Product Name", value: "Product Name".localized)
                demoRow(key: "Brand", value: "Brand".localized)
                demoRow(key: "Model", value: "Model".localized)
                demoRow(key: "No Products", value: "No Products".localized)
            }
        }
    }
    
    // MARK: - 辅助视图
    private func demoRow(key: String, value: String) -> some View {
        HStack {
            Text(key)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .leading)
            
            Text("→")
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.body)
                .foregroundColor(.primary)
            
            Spacer()
        }
        .padding(.vertical, 2)
    }
    
    private func statusRow(message: String, color: Color) -> some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            
            Text(message)
                .foregroundColor(color)
            
            Spacer()
        }
        .padding(.vertical, 2)
    }
}

// MARK: - 预览
struct LocalizationDemoView_Previews: PreviewProvider {
    static var previews: some View {
        LocalizationDemoView()
    }
}
