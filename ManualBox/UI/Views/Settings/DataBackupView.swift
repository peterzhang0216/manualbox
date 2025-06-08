import SwiftUI

// MARK: - 数据备份与恢复视图
struct DataBackupView: View {
    @State private var isBackingUp = false
    @State private var isRestoring = false
    @State private var showBackupAlert = false
    @State private var showRestoreAlert = false
    @State private var backupMessage = ""
    @State private var restoreMessage = ""
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(NSLocalizedString("Data Backup & Restore", comment: ""))
                    .font(.title2).bold()
                    .padding(.top, 24)
                    .foregroundColor(.accentColor)
                
                // 本地备份部分
                VStack(alignment: .leading, spacing: 16) {
                    Text(NSLocalizedString("Local Backup", comment: ""))
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(NSLocalizedString("Create a backup file of your data that can be saved locally.", comment: ""))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button(action: {
                        performLocalBackup()
                    }) {
                        HStack {
                            Image(systemName: "externaldrive.fill")
                            Text(NSLocalizedString("Create Local Backup", comment: ""))
                            Spacer()
                            if isBackingUp {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(8)
                    }
                    .disabled(isBackingUp)
                }
                
                Divider()
                
                // iCloud备份部分
                VStack(alignment: .leading, spacing: 16) {
                    Text(NSLocalizedString("iCloud Backup", comment: ""))
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(NSLocalizedString("Automatically sync your data with iCloud for seamless access across devices.", comment: ""))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button(action: {
                        performiCloudBackup()
                    }) {
                        HStack {
                            Image(systemName: "icloud.fill")
                            Text(NSLocalizedString("Sync with iCloud", comment: ""))
                            Spacer()
                            if isBackingUp {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .foregroundColor(.green)
                        .cornerRadius(8)
                    }
                    .disabled(isBackingUp)
                }
                
                Divider()
                
                // 恢复数据部分
                VStack(alignment: .leading, spacing: 16) {
                    Text(NSLocalizedString("Restore Data", comment: ""))
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(NSLocalizedString("Restore your data from a previously created backup file.", comment: ""))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button(action: {
                        performRestore()
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text(NSLocalizedString("Restore from Backup", comment: ""))
                            Spacer()
                            if isRestoring {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .foregroundColor(.orange)
                        .cornerRadius(8)
                    }
                    .disabled(isRestoring)
                }
                
                Spacer(minLength: 50)
            }
            .padding(.horizontal, 24)
        }
        .navigationTitle(NSLocalizedString("Data Backup & Restore", comment: ""))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .alert(NSLocalizedString("Backup", comment: ""), isPresented: $showBackupAlert) {
            Button(NSLocalizedString("OK", comment: "")) { }
        } message: {
            Text(backupMessage)
        }
        .alert(NSLocalizedString("Restore", comment: ""), isPresented: $showRestoreAlert) {
            Button(NSLocalizedString("OK", comment: "")) { }
        } message: {
            Text(restoreMessage)
        }
    }
    
    private func performLocalBackup() {
        isBackingUp = true
        
        // 模拟备份过程
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isBackingUp = false
            backupMessage = NSLocalizedString("Local backup completed successfully.", comment: "")
            showBackupAlert = true
        }
    }
    
    private func performiCloudBackup() {
        isBackingUp = true
        
        // 模拟iCloud同步过程
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            isBackingUp = false
            backupMessage = NSLocalizedString("iCloud sync completed successfully.", comment: "")
            showBackupAlert = true
        }
    }
    
    private func performRestore() {
        isRestoring = true
        
        // 模拟恢复过程
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isRestoring = false
            restoreMessage = NSLocalizedString("Data restored successfully.", comment: "")
            showRestoreAlert = true
        }
    }
}

#Preview {
    NavigationView {
        DataBackupView()
    }
}