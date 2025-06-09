import SwiftUI

// MARK: - 平台特定模态窗口组件
struct PlatformModal<Content: View>: View {
    let title: String
    let content: () -> Content
    let onDismiss: () -> Void
    
    @Binding var isPresented: Bool
    @State private var dragOffset = CGSize.zero
    
    private let modalStyle: ModalStyle
    
    enum ModalStyle {
        case sheet
        case fullScreen
        case popover
        case alert
        
        var backgroundColor: Color {
            switch self {
            case .sheet, .popover:
                return PlatformAdapter.backgroundColor
            case .fullScreen:
                return PlatformAdapter.backgroundColor
            case .alert:
                return PlatformAdapter.secondaryBackgroundColor
            }
        }
        
        var cornerRadius: CGFloat {
            switch self {
            case .sheet, .popover, .alert:
                #if os(macOS)
                return 12
                #else
                return 16
                #endif
            case .fullScreen:
                return 0
            }
        }
        
        var maxWidth: CGFloat? {
            switch self {
            case .sheet:
                #if os(macOS)
                return 600
                #else
                return nil
                #endif
            case .popover:
                return 400
            case .alert:
                return 350
            case .fullScreen:
                return nil
            }
        }
        
        var maxHeight: CGFloat? {
            switch self {
            case .sheet:
                #if os(macOS)
                return 500
                #else
                return nil
                #endif
            case .popover:
                return 300
            case .alert:
                return 200
            case .fullScreen:
                return nil
            }
        }
    }
    
    init(
        title: String,
        isPresented: Binding<Bool>,
        style: ModalStyle = .sheet,
        onDismiss: @escaping () -> Void = {},
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self._isPresented = isPresented
        self.modalStyle = style
        self.onDismiss = onDismiss
        self.content = content
    }
    
    var body: some View {
        ZStack {
            // 背景遮罩
            if isPresented {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        dismissModal()
                    }
                    .transition(.opacity)
            }
            
            // 模态内容
            if isPresented {
                modalContent
                    .transition(modalTransition)
            }
        }
        .animation(PlatformAdapter.defaultAnimation, value: isPresented)
    }
    
    @ViewBuilder
    private var modalContent: some View {
        VStack(spacing: 0) {
            // 标题栏
            modalHeader
            
            // 内容区域
            ScrollView {
                content()
                    .padding(PlatformAdapter.defaultPadding)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: modalStyle.cornerRadius)
                .fill(modalStyle.backgroundColor)
                .shadow(
                    color: .black.opacity(0.2),
                    radius: 20,
                    x: 0,
                    y: 10
                )
        )
        .frame(
            maxWidth: modalStyle.maxWidth,
            maxHeight: modalStyle.maxHeight
        )
        .offset(dragOffset)
        .platformDragGesture(dragOffset: $dragOffset, onDismiss: dismissModal)
    }
    
    @ViewBuilder
    private var modalHeader: some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            Spacer()
            
            Button(action: dismissModal) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(PlainButtonStyle())
            .platformHover()
        }
        .padding(PlatformAdapter.defaultPadding)
        .background(
            Rectangle()
                .fill(modalStyle.backgroundColor)
                .opacity(0.8)
        )
    }
    
    private var modalTransition: AnyTransition {
        switch modalStyle {
        case .sheet:
            #if os(macOS)
            return .scale.combined(with: .opacity)
            #else
            return .move(edge: .bottom).combined(with: .opacity)
            #endif
        case .fullScreen:
            return .move(edge: .trailing)
        case .popover:
            return .scale.combined(with: .opacity)
        case .alert:
            return .scale(scale: 0.8).combined(with: .opacity)
        }
    }
    
    private func dismissModal() {
        withAnimation(PlatformAdapter.defaultAnimation) {
            isPresented = false
            dragOffset = .zero
        }
        onDismiss()
    }
}

// MARK: - 拖拽手势扩展
private struct PlatformDragGesture: ViewModifier {
    @Binding var dragOffset: CGSize
    let onDismiss: () -> Void
    
    func body(content: Content) -> some View {
        #if os(iOS)
        content.gesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.y > 0 {
                        dragOffset = value.translation
                    }
                }
                .onEnded { value in
                    if value.translation.y > 100 {
                        onDismiss()
                    } else {
                        withAnimation(.spring()) {
                            dragOffset = .zero
                        }
                    }
                }
        )
        #else
        content // macOS 不支持拖拽关闭
        #endif
    }
}

extension View {
    func platformDragGesture(dragOffset: Binding<CGSize>, onDismiss: @escaping () -> Void) -> some View {
        self.modifier(PlatformDragGesture(dragOffset: dragOffset, onDismiss: onDismiss))
    }
}

// MARK: - 便捷方法
extension View {
    func platformSheet<Content: View>(
        title: String,
        isPresented: Binding<Bool>,
        onDismiss: @escaping () -> Void = {},
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        self.overlay(
            PlatformModal(
                title: title,
                isPresented: isPresented,
                style: .sheet,
                onDismiss: onDismiss,
                content: content
            )
        )
    }
    
    func platformPopover<Content: View>(
        title: String,
        isPresented: Binding<Bool>,
        onDismiss: @escaping () -> Void = {},
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        self.overlay(
            PlatformModal(
                title: title,
                isPresented: isPresented,
                style: .popover,
                onDismiss: onDismiss,
                content: content
            )
        )
    }
}

// MARK: - 预览
#Preview {
    struct ModalPreview: View {
        @State private var showSheet = false
        @State private var showPopover = false
        
        var body: some View {
            VStack(spacing: 20) {
                PlatformButton("Show Sheet", icon: "doc.text", style: .primary) {
                    showSheet = true
                }
                
                PlatformButton("Show Popover", icon: "info.circle", style: .secondary) {
                    showPopover = true
                }
            }
            .padding()
            .platformBackground()
            .platformSheet(
                title: "Sheet Modal",
                isPresented: $showSheet
            ) {
                VStack(spacing: 16) {
                    Text("This is a sheet modal")
                        .font(.title2)
                    
                    Text("It adapts to different platforms automatically.")
                        .foregroundColor(.secondary)
                    
                    PlatformButton("Close", style: .secondary) {
                        showSheet = false
                    }
                }
            }
            .platformPopover(
                title: "Popover",
                isPresented: $showPopover
            ) {
                VStack(spacing: 12) {
                    Text("Quick info")
                        .font(.headline)
                    
                    Text("This is a popover with platform-specific styling.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    return ModalPreview()
}