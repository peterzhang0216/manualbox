import SwiftUI

// MARK: - 数据与默认设置面板
struct DataSettingsPanel: View {
    @Binding var defaultWarrantyPeriod: Int
    @Binding var enableOCRByDefault: Bool
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(NSLocalizedString("Data & Defaults", comment: ""))
                    .font(.title2).bold()
                    .padding(.top, 24)
                    .foregroundColor(.accentColor)
                
                Divider().background(Color.accentColor.opacity(0.3))
                
                // 默认值设置卡片
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.accentColor)
                            .frame(width: 36, height: 36)
                            .background(Color.accentColor.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        
                        Text(NSLocalizedString("Default Settings", comment: ""))
                            .font(.headline)
                        
                        Spacer()
                    }
                    
                    // 保修期默认设置卡片
                    VStack(alignment: .leading, spacing: 12) {
                        WarrantyDefaultView(period: $defaultWarrantyPeriod)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(Color.secondary.opacity(0.03))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    
                    // OCR默认设置卡片
                    VStack(alignment: .leading, spacing: 12) {
                        OCRDefaultView(enabled: $enableOCRByDefault)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(Color.secondary.opacity(0.03))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .padding()
                .background(Color.secondary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // 数据管理卡片
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "externaldrive.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.accentColor)
                            .frame(width: 36, height: 36)
                            .background(Color.accentColor.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        
                        Text(NSLocalizedString("Data Management", comment: ""))
                            .font(.headline)
                        
                        Spacer()
                    }
                    
                    NavigationLink(destination: DataExportView()) {
                        SettingRow(
                            icon: "arrow.up.doc.fill",
                            iconColor: .green,
                            title: NSLocalizedString("Export Data", comment: ""),
                            subtitle: NSLocalizedString("Export products, categories, and tags", comment: "")
                        )
                    }
                    .buttonStyle(.plain)
                    
                    NavigationLink(destination: DataImportView()) {
                        SettingRow(
                            icon: "arrow.down.doc.fill",
                            iconColor: .blue,
                            title: NSLocalizedString("Import Data", comment: ""),
                            subtitle: NSLocalizedString("Import products, categories, and tags", comment: "")
                        )
                    }
                    .buttonStyle(.plain)
                    
                    NavigationLink(destination: DataBackupView()) {
                        SettingRow(
                            icon: "externaldrive.fill",
                            iconColor: .purple,
                            title: NSLocalizedString("Data Backup & Restore", comment: ""),
                            subtitle: NSLocalizedString("Local or iCloud backup/restore", comment: "")
                        )
                    }
                    .buttonStyle(.plain)
                    
                    Button(role: .destructive) {
                        // showResetAlert = true
                    } label: {
                        SettingRow(
                            icon: "trash.fill",
                            iconColor: .red,
                            title: NSLocalizedString("Reset App Data", comment: ""),
                            subtitle: NSLocalizedString("Clear all local data, cannot be recovered", comment: ""),
                            warning: true
                        )
                    }
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
    @Previewable @State var warrantyPeriod = 12
    @Previewable @State var enableOCR = true
    
    return DataSettingsPanel(
        defaultWarrantyPeriod: $warrantyPeriod,
        enableOCRByDefault: $enableOCR
    )
}