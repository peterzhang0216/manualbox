import SwiftUI

/// 应用信息视图
struct AppInfoView: View {
    var body: some View {
        VStack(spacing: 20) {
            // 应用图标和基本信息 - 更优雅的布局
            HStack(spacing: 20) {
                // 更大更美观的图标
                Image(systemName: "shippingbox.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64, height: 64)
                    .foregroundColor(.accentColor)
                    .padding(14)
                    .background(
                        ZStack {
                            Color.accentColor.opacity(0.1)
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
                        }
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .shadow(color: Color.accentColor.opacity(0.1), radius: 10, x: 0, y: 4)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("ManualBox")
                        .font(.title2)
                        .bold()
                        .foregroundColor(.primary)
                    
                    Text("保修信息管理助手")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    // 版本信息更加美观
                    HStack(spacing: 10) {
                        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
                        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
                        
                        Text("v\(version) (\(build))")
                            .font(.subheadline)
                            .foregroundColor(.accentColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .fill(Color.accentColor.opacity(0.1))
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
                                    )
                            )
                        
                        Text(formatBuildDate())
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .fill(Color.secondary.opacity(0.1))
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                                    )
                            )
                    }
                }
                
                Spacer()
            }
            
            Divider()
                .background(Color.accentColor.opacity(0.1))
                .padding(.vertical, 10)
            
            // 版权信息 - 更精美的设计
            VStack(spacing: 6) {
                Text("© 2025 ManualBox 团队")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text("保留所有权利")
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.8))
            }
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.secondary.opacity(0.03))
            )
        }
    }
    
    private func formatBuildDate() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        // 如果有构建日期使用，否则使用当前日期
        return "构建: \(dateFormatter.string(from: Date()))"
    }
}

// 预览
#Preview {
    AppInfoView()
        .padding()
}
