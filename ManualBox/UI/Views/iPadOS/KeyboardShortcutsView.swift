import SwiftUI

// MARK: - 键盘快捷键帮助视图
struct KeyboardShortcutsView: View {
    @Environment(\.dismiss) private var dismiss

    private var backgroundColorForPlatform: Color {
        #if os(iOS)
        return Color(.systemGray6)
        #else
        return Color(NSColor.controlColor)
        #endif
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // 标题和说明
                    VStack(alignment: .leading, spacing: 8) {
                        Text("键盘快捷键")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("使用外接键盘时，您可以使用以下快捷键来提高操作效率。")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 20)
                    
                    // 快捷键分组
                    LazyVStack(spacing: 16) {
                        // 基本操作
                        ShortcutGroup(
                            title: "基本操作",
                            icon: "command",
                            shortcuts: [
                                ShortcutItem(keys: ["⌘", "N"], description: "新建产品"),
                                ShortcutItem(keys: ["⌘", "F"], description: "搜索"),
                                ShortcutItem(keys: ["⌘", "R"], description: "刷新"),
                                ShortcutItem(keys: ["⌘", "S"], description: "保存"),
                                ShortcutItem(keys: ["⌘", "W"], description: "关闭"),
                                ShortcutItem(keys: ["⌘", ","], description: "打开设置")
                            ]
                        )
                        
                        // 导航
                        ShortcutGroup(
                            title: "导航",
                            icon: "arrow.left.arrow.right",
                            shortcuts: [
                                ShortcutItem(keys: ["⌘", "1"], description: "产品列表"),
                                ShortcutItem(keys: ["⌘", "2"], description: "分类管理"),
                                ShortcutItem(keys: ["⌘", "3"], description: "标签管理"),
                                ShortcutItem(keys: ["⌘", "4"], description: "维修记录"),
                                ShortcutItem(keys: ["⌘", "⌥", "S"], description: "切换侧边栏")
                            ]
                        )
                        
                        // 编辑操作
                        ShortcutGroup(
                            title: "编辑",
                            icon: "pencil",
                            shortcuts: [
                                ShortcutItem(keys: ["⌘", "Z"], description: "撤销"),
                                ShortcutItem(keys: ["⌘", "⇧", "Z"], description: "重做"),
                                ShortcutItem(keys: ["⌘", "C"], description: "复制"),
                                ShortcutItem(keys: ["⌘", "V"], description: "粘贴"),
                                ShortcutItem(keys: ["⌘", "A"], description: "全选"),
                                ShortcutItem(keys: ["⌫"], description: "删除选中项")
                            ]
                        )
                        
                        // 视图控制
                        ShortcutGroup(
                            title: "视图",
                            icon: "rectangle.3.group",
                            shortcuts: [
                                ShortcutItem(keys: ["⌘", "+"], description: "放大"),
                                ShortcutItem(keys: ["⌘", "-"], description: "缩小"),
                                ShortcutItem(keys: ["⌘", "0"], description: "重置缩放"),
                                ShortcutItem(keys: ["⌘", "⌥", "1"], description: "列表视图"),
                                ShortcutItem(keys: ["⌘", "⌥", "2"], description: "网格视图")
                            ]
                        )
                        
                        // 高级功能
                        ShortcutGroup(
                            title: "高级功能",
                            icon: "gearshape.2",
                            shortcuts: [
                                ShortcutItem(keys: ["⌘", "E"], description: "导出数据"),
                                ShortcutItem(keys: ["⌘", "I"], description: "导入数据"),
                                ShortcutItem(keys: ["⌘", "⌥", "R"], description: "重置应用"),
                                ShortcutItem(keys: ["⌘", "?"], description: "显示帮助"),
                                ShortcutItem(keys: ["⌘", "K"], description: "快速操作")
                            ]
                        )
                    }
                    .padding(.horizontal, 20)
                    
                    // 底部说明
                    VStack(alignment: .leading, spacing: 12) {
                        Text("提示")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "lightbulb.fill")
                                    .foregroundColor(.yellow)
                                    .frame(width: 16)
                                
                                Text("长按 ⌘ 键可以在任何界面查看可用的快捷键")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "keyboard")
                                    .foregroundColor(.blue)
                                    .frame(width: 16)
                                
                                Text("这些快捷键仅在连接外接键盘时可用")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "hand.tap")
                                    .foregroundColor(.green)
                                    .frame(width: 16)
                                
                                Text("您也可以使用触摸手势进行相同的操作")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(16)
                    .background(backgroundColorForPlatform)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 20)
                    
                    Spacer(minLength: 20)
                }
                .padding(.vertical, 20)
            }
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar(content: {
                #if os(iOS)
                SwiftUI.SwiftUI.ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
                #else
                SwiftUI.ToolbarItem(placement: .primaryAction) {
                    Button("完成") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
                #endif
            })
        }
    }
}

// MARK: - 快捷键分组
struct ShortcutGroup: View {
    let title: String
    let icon: String
    let shortcuts: [ShortcutItem]

    private var backgroundColorForPlatform: Color {
        #if os(iOS)
        return Color(.systemGray6)
        #else
        return Color(NSColor.controlColor)
        #endif
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 分组标题
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.accentColor)
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            // 快捷键列表
            VStack(spacing: 8) {
                ForEach(shortcuts, id: \.description) { shortcut in
                    ShortcutRow(shortcut: shortcut)
                }
            }
        }
        .padding(16)
        .background(backgroundColorForPlatform)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// MARK: - 快捷键行
struct ShortcutRow: View {
    let shortcut: ShortcutItem

    private var backgroundColorForPlatform: Color {
        #if os(macOS)
        return Color(nsColor: .windowBackgroundColor)
        #else
        return Color(.systemGray5)
        #endif
    }
    
    var body: some View {
        HStack {
            // 快捷键组合
            HStack(spacing: 4) {
                ForEach(shortcut.keys, id: \.self) { key in
                    Text(key)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(backgroundColorForPlatform)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            
            Spacer()
            
            // 描述
            Text(shortcut.description)
                .font(.system(size: 15))
                .foregroundColor(.primary)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - 快捷键项目
struct ShortcutItem {
    let keys: [String]
    let description: String
}

// MARK: - 预览
#Preview {
    KeyboardShortcutsView()
}
