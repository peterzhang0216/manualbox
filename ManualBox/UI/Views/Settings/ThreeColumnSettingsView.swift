//
//  ThreeColumnSettingsView.swift
//  ManualBox
//
//  Created by Assistant on 2024/12/19.
//

import SwiftUI
import CoreData

// MARK: - 三栏设置视图
struct ThreeColumnSettingsView: View {
    @StateObject private var viewModel: SettingsViewModel
    @StateObject private var viewState = ThreeColumnSettingsViewState()
    @Environment(\.managedObjectContext) private var viewContext
    
    init() {
        let context = PersistenceController.shared.container.viewContext
        self._viewModel = StateObject(wrappedValue: SettingsViewModel(viewContext: context))
    }
    
    var body: some View {
        NavigationSplitView {
            // 第一栏：主要分类
            List {
                Section("设置") {
                    ForEach(SettingsPanel.allCases, id: \.self) { panel in
                        NavigationLink(value: panel) {
                            Label(panel.title, systemImage: panel.icon)
                                .foregroundColor(panel.color)
                        }
                        .tag(panel)
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("设置")
        } content: {
            // 第二栏：子分类
            List {
                Section(viewState.selectedPanel.title) {
                    ForEach(viewState.subPanelsForCurrentPanel, id: \.self) { subPanel in
                        NavigationLink(value: subPanel) {
                            Label(subPanel.title, systemImage: subPanel.icon)
                                .foregroundColor(subPanel.color)
                        }
                        .tag(subPanel)
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle(viewState.selectedPanel.title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        } detail: {
            // 第三栏：详细内容
            Group {
                if let subPanel = viewState.selectedSubPanel {
                    subPanelDetailView(for: subPanel)
                } else {
                    // 默认显示面板概览
                    panelOverviewView(for: viewState.selectedPanel)
                }
            }
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
        .onChange(of: viewState.selectedPanel) { _, newPanel in
            viewState.updateSelectedPanel(newPanel)
        }
        .onAppear {
            viewState.initializeSubPanel()
        }
    }
    
    // MARK: - 视图构建器
    @ViewBuilder
    private func panelOverviewView(for panel: SettingsPanel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 面板标题
                HStack {
                    Image(systemName: panel.icon)
                        .font(.title2)
                        .foregroundColor(panel.color)
                    Text(panel.title)
                        .font(.title2)
                        .fontWeight(.semibold)
                    Spacer()
                }
                .padding(.top, 24)
                
                // 面板概览内容
                switch panel {
                case .notification:
                    notificationOverview()
                case .appearance:
                    themeOverview()
                case .appSettings:
                    appSettingsOverview()
                case .dataManagement:
                    dataOverview()
                case .about:
                    aboutOverview()
                }
                
                Spacer()
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
            .frame(maxWidth: 700, alignment: .leading)
        }
    }
    
    @ViewBuilder
    private func subPanelDetailView(for subPanel: SettingsSubPanel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 子面板标题
                HStack {
                    Image(systemName: subPanel.icon)
                        .font(.title2)
                        .foregroundColor(subPanel.color)
                    Text(subPanel.title)
                        .font(.title2)
                        .fontWeight(.semibold)
                    Spacer()
                }
                .padding(.top, 24)
                
                // 子面板具体内容
                subPanelContent(for: subPanel)
                
                Spacer()
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
            .frame(maxWidth: 700, alignment: .leading)
        }
    }
}

#Preview {
    ThreeColumnSettingsView()
        .environmentObject(AppNotificationManager())
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}