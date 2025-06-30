import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif
import CoreData

// MARK: - 设置视图
struct SettingsView: View {
    @StateObject private var viewModel: SettingsViewModel
    @EnvironmentObject private var notificationManager: AppNotificationManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.managedObjectContext) private var viewContext

    init() {
        let context = PersistenceController.shared.container.viewContext
        self._viewModel = StateObject(wrappedValue: SettingsViewModel(viewContext: context))
    }
    

    
    var body: some View {
        // 使用三栏设置视图
        ThreeColumnSettingsView()
            .environmentObject(viewModel)
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppNotificationManager())
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
