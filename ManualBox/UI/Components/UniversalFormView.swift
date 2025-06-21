import SwiftUI
import Combine

// MARK: - 通用表单状态协议
protocol FormStateProtocol: ObservableObject {
    var isLoading: Bool { get set }
    var isSaving: Bool { get set }
    var errorMessage: String? { get set }
    var isValid: Bool { get }
    
    func validate() -> Bool
    func reset()
}

// MARK: - 通用表单动作协议
protocol FormActionProtocol {
    func save() async throws
    func cancel()
}

// MARK: - 通用表单配置
struct FormConfiguration {
    let title: String
    let saveButtonTitle: String
    let cancelButtonTitle: String
    let showCancelButton: Bool
    let enableAutoSave: Bool
    let validationMode: ValidationMode
    
    enum ValidationMode {
        case onSubmit
        case onChange
        case onBlur
    }
    
    static let `default` = FormConfiguration(
        title: "表单",
        saveButtonTitle: "保存",
        cancelButtonTitle: "取消",
        showCancelButton: true,
        enableAutoSave: false,
        validationMode: .onSubmit
    )
}

// MARK: - 通用表单视图
struct UniversalFormView<Content: View, State: FormStateProtocol>: View {
    @ObservedObject var state: State
    let configuration: FormConfiguration
    let content: () -> Content
    let onSave: () async throws -> Void
    let onCancel: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    init(
        state: State,
        configuration: FormConfiguration = .default,
        onSave: @escaping () async throws -> Void,
        onCancel: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.state = state
        self.configuration = configuration
        self.content = content
        self.onSave = onSave
        self.onCancel = onCancel
    }
    
    var body: some View {
        NavigationView {
            Form {
                content()
                
                // 错误信息显示
                if let errorMessage = state.errorMessage {
                    Section {
                        ErrorMessageView(message: errorMessage)
                    }
                }
            }
            .navigationTitle(configuration.title)
            .disabled(state.isSaving)
            .overlay {
                if state.isSaving {
                    LoadingOverlay(message: "正在保存...")
                }
            }
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItemGroup(placement: .navigationBarLeading) {
                    if configuration.showCancelButton {
                        Button(configuration.cancelButtonTitle) {
                            handleCancel()
                        }
                        .disabled(state.isSaving)
                    }
                }

                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button(configuration.saveButtonTitle) {
                        handleSave()
                    }
                    .disabled(!state.isValid || state.isSaving)
                }
                #else
                ToolbarItemGroup(placement: .automatic) {
                    if configuration.showCancelButton {
                        Button(configuration.cancelButtonTitle) {
                            handleCancel()
                        }
                        .disabled(state.isSaving)
                    }

                    Button(configuration.saveButtonTitle) {
                        handleSave()
                    }
                    .disabled(!state.isValid || state.isSaving)
                }
                #endif
            }
        }
    }
    
    // MARK: - 私有方法
    
    private func handleSave() {
        guard state.validate() else { return }
        
        Task {
            await MainActor.run {
                state.isSaving = true
                state.errorMessage = nil
            }
            
            do {
                try await onSave()
                await MainActor.run {
                    state.isSaving = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    state.isSaving = false
                    state.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func handleCancel() {
        onCancel()
        dismiss()
    }
}

// MARK: - 辅助视图组件

struct ErrorMessageView: View {
    let message: String
    
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            Text(message)
                .foregroundColor(.red)
                .font(.caption)
        }
        .padding(.vertical, 4)
    }
}

struct LoadingOverlay: View {
    let message: String
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.2)
                
                Text(message)
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.regularMaterial)
            )
        }
    }
}

// MARK: - 表单字段组件

struct FormSection<Content: View>: View {
    let title: String
    let content: () -> Content
    
    init(_ title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }
    
    var body: some View {
        Section(header: Text(title)) {
            content()
        }
    }
}

struct ValidatedTextField: View {
    let title: String
    @Binding var text: String
    let validation: (String) -> String?
    let placeholder: String
    
    @State private var errorMessage: String?
    
    init(
        _ title: String,
        text: Binding<String>,
        placeholder: String = "",
        validation: @escaping (String) -> String? = { _ in nil }
    ) {
        self.title = title
        self._text = text
        self.placeholder = placeholder
        self.validation = validation
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField(title, text: $text, prompt: Text(placeholder))
                .textFieldStyle(.roundedBorder)
                .onChange(of: text) { _, newValue in
                    errorMessage = validation(newValue)
                }
            
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }
}

// MARK: - 表单验证工具

struct FormValidator {
    static func required(_ value: String) -> String? {
        value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "此字段为必填项" : nil
    }
    
    static func minLength(_ minLength: Int) -> (String) -> String? {
        return { value in
            value.count < minLength ? "至少需要 \(minLength) 个字符" : nil
        }
    }
    
    static func maxLength(_ maxLength: Int) -> (String) -> String? {
        return { value in
            value.count > maxLength ? "最多 \(maxLength) 个字符" : nil
        }
    }
    
    static func email(_ value: String) -> String? {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format:"SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: value) ? nil : "请输入有效的邮箱地址"
    }
    
    static func combine(_ validators: (String) -> String?...) -> (String) -> String? {
        return { value in
            for validator in validators {
                if let error = validator(value) {
                    return error
                }
            }
            return nil
        }
    }
}
