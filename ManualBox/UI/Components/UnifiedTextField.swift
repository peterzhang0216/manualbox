import SwiftUI

// MARK: - 统一文本输入框
struct UnifiedTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let icon: String?
    let style: UnifiedTextFieldStyle
    let validation: TextFieldValidation?
    
    @State private var isFocused = false
    @State private var isHovered = false
    @FocusState private var fieldIsFocused: Bool
    
    init(
        _ title: String,
        text: Binding<String>,
        placeholder: String = "",
        icon: String? = nil,
        style: UnifiedTextFieldStyle = .default,
        validation: TextFieldValidation? = nil
    ) {
        self.title = title
        self._text = text
        self.placeholder = placeholder
        self.icon = icon
        self.style = style
        self.validation = validation
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: UnifiedDesignSystem.Spacing.sm) {
            // 标题
            if !title.isEmpty {
                Text(title)
                    .unifiedBody(.callout)
                    .foregroundColor(titleColor)
            }
            
            // 输入框
            HStack(spacing: UnifiedDesignSystem.Spacing.md) {
                // 图标
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: UnifiedDesignSystem.Sizes.iconMD, weight: .medium))
                        .foregroundColor(iconColor)
                        .frame(width: UnifiedDesignSystem.Sizes.iconLG)
                }
                
                // 文本输入
                TextField(placeholder, text: $text)
                    .font(UnifiedDesignSystem.Typography.body)
                    .foregroundColor(UnifiedDesignSystem.Colors.primaryText)
                    .focused($fieldIsFocused)
                    .textFieldStyle(.plain)
                    .onTapGesture {
                        fieldIsFocused = true
                    }
                
                // 清除按钮
                if !text.isEmpty && isFocused {
                    Button(action: {
                        text = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: UnifiedDesignSystem.Sizes.iconMD))
                            .foregroundColor(UnifiedDesignSystem.Colors.tertiaryText)
                    }
                    .buttonStyle(.plain)
                    .unifiedAnimation(.quick)
                }
            }
            .padding(.horizontal, UnifiedDesignSystem.Spacing.md)
            .padding(.vertical, style.verticalPadding)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: style.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: style.cornerRadius)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHovered = hovering
                }
            }
            .onChange(of: fieldIsFocused) { _, focused in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isFocused = focused
                }
            }
            
            // 验证信息
            if let validation = validation {
                validationView(validation)
            }
        }
    }
    
    // MARK: - 验证视图
    @ViewBuilder
    private func validationView(_ validation: TextFieldValidation) -> some View {
        let result = validation.validate(text)
        
        if case .invalid(let message) = result {
            HStack(spacing: UnifiedDesignSystem.Spacing.xs) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(UnifiedDesignSystem.Colors.error)
                
                Text(message)
                    .unifiedBody(.caption1)
                    .foregroundColor(UnifiedDesignSystem.Colors.error)
            }
            .unifiedAnimation(.quick)
        }
    }
    
    // MARK: - 计算属性
    private var titleColor: Color {
        if let validation = validation, case .invalid = validation.validate(text) {
            return UnifiedDesignSystem.Colors.error
        }
        return isFocused ? UnifiedDesignSystem.Colors.primary : UnifiedDesignSystem.Colors.secondaryText
    }
    
    private var iconColor: Color {
        if let validation = validation, case .invalid = validation.validate(text) {
            return UnifiedDesignSystem.Colors.error
        }
        return isFocused ? UnifiedDesignSystem.Colors.primary : UnifiedDesignSystem.Colors.tertiaryText
    }
    
    private var backgroundColor: Color {
        switch style {
        case .default:
            return UnifiedDesignSystem.Colors.secondaryBackground
        case .bordered:
            return UnifiedDesignSystem.Colors.background
        case .filled:
            return UnifiedDesignSystem.Colors.tertiaryBackground
        }
    }
    
    private var borderColor: Color {
        if let validation = validation, case .invalid = validation.validate(text) {
            return UnifiedDesignSystem.Colors.error
        }
        
        if isFocused {
            return UnifiedDesignSystem.Colors.primary
        }
        
        if isHovered {
            return UnifiedDesignSystem.Colors.primary.opacity(0.5)
        }
        
        switch style {
        case .default:
            return Color.clear
        case .bordered, .filled:
            return UnifiedDesignSystem.Colors.separator
        }
    }
    
    private var borderWidth: CGFloat {
        if let validation = validation, case .invalid = validation.validate(text) {
            return 2
        }
        
        if isFocused {
            return 2
        }
        
        switch style {
        case .default:
            return 0
        case .bordered, .filled:
            return 1
        }
    }
}

// MARK: - 文本框样式
enum UnifiedTextFieldStyle {
    case `default`
    case bordered
    case filled
    
    var cornerRadius: CGFloat {
        switch self {
        case .default, .filled:
            return UnifiedDesignSystem.CornerRadius.md
        case .bordered:
            return UnifiedDesignSystem.CornerRadius.sm
        }
    }
    
    var verticalPadding: CGFloat {
        switch self {
        case .default, .filled:
            return UnifiedDesignSystem.Spacing.md
        case .bordered:
            return UnifiedDesignSystem.Spacing.sm
        }
    }
}

// MARK: - 文本验证
struct TextFieldValidation {
    let validate: (String) -> TextFieldValidationResult
    
    static func required(message: String = "此字段为必填项") -> TextFieldValidation {
        TextFieldValidation { text in
            text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .invalid(message) : .valid
        }
    }
    
    static func minLength(_ length: Int, message: String? = nil) -> TextFieldValidation {
        TextFieldValidation { text in
            let msg = message ?? "至少需要 \(length) 个字符"
            return text.count >= length ? .valid : .invalid(msg)
        }
    }
    
    static func maxLength(_ length: Int, message: String? = nil) -> TextFieldValidation {
        TextFieldValidation { text in
            let msg = message ?? "最多 \(length) 个字符"
            return text.count <= length ? .valid : .invalid(msg)
        }
    }
    
    static func email(message: String = "请输入有效的邮箱地址") -> TextFieldValidation {
        TextFieldValidation { text in
            let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
            let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
            return emailPredicate.evaluate(with: text) ? .valid : .invalid(message)
        }
    }
    
    static func custom(_ validator: @escaping (String) -> TextFieldValidationResult) -> TextFieldValidation {
        TextFieldValidation(validate: validator)
    }
    
    static func combine(_ validations: [TextFieldValidation]) -> TextFieldValidation {
        TextFieldValidation { text in
            for validation in validations {
                let result = validation.validate(text)
                if case .invalid = result {
                    return result
                }
            }
            return .valid
        }
    }
}

// MARK: - 验证结果
enum TextFieldValidationResult {
    case valid
    case invalid(String)
}

// MARK: - 统一文本区域
struct UnifiedTextEditor: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let minHeight: CGFloat
    let maxHeight: CGFloat?
    
    @State private var isFocused = false
    @FocusState private var editorIsFocused: Bool
    
    init(
        _ title: String,
        text: Binding<String>,
        placeholder: String = "",
        minHeight: CGFloat = 100,
        maxHeight: CGFloat? = nil
    ) {
        self.title = title
        self._text = text
        self.placeholder = placeholder
        self.minHeight = minHeight
        self.maxHeight = maxHeight
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: UnifiedDesignSystem.Spacing.sm) {
            // 标题
            if !title.isEmpty {
                Text(title)
                    .unifiedBody(.callout)
                    .foregroundColor(isFocused ? UnifiedDesignSystem.Colors.primary : UnifiedDesignSystem.Colors.secondaryText)
            }
            
            // 文本编辑器
            ZStack(alignment: .topLeading) {
                // 占位符
                if text.isEmpty {
                    Text(placeholder)
                        .unifiedBody(.body)
                        .foregroundColor(UnifiedDesignSystem.Colors.tertiaryText)
                        .padding(.horizontal, UnifiedDesignSystem.Spacing.md)
                        .padding(.vertical, UnifiedDesignSystem.Spacing.md + 2)
                        .allowsHitTesting(false)
                }
                
                // 文本编辑器
                TextEditor(text: $text)
                    .font(UnifiedDesignSystem.Typography.body)
                    .foregroundColor(UnifiedDesignSystem.Colors.primaryText)
                    .focused($editorIsFocused)
                    .padding(.horizontal, UnifiedDesignSystem.Spacing.md)
                    .padding(.vertical, UnifiedDesignSystem.Spacing.md)
                    .scrollContentBackground(.hidden)
            }
            .frame(minHeight: minHeight, maxHeight: maxHeight)
            .background(UnifiedDesignSystem.Colors.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: UnifiedDesignSystem.CornerRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: UnifiedDesignSystem.CornerRadius.md)
                    .stroke(
                        isFocused ? UnifiedDesignSystem.Colors.primary : UnifiedDesignSystem.Colors.separator,
                        lineWidth: isFocused ? 2 : 1
                    )
            )
            .onChange(of: editorIsFocused) { _, focused in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isFocused = focused
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: 24) {
        UnifiedTextField(
            "产品名称",
            text: .constant(""),
            placeholder: "请输入产品名称",
            icon: "shippingbox",
            validation: .required()
        )
        
        UnifiedTextField(
            "品牌",
            text: .constant("Apple"),
            placeholder: "请输入品牌",
            icon: "building.2",
            style: .bordered
        )
        
        UnifiedTextField(
            "邮箱",
            text: .constant("invalid-email"),
            placeholder: "请输入邮箱地址",
            icon: "envelope",
            style: .filled,
            validation: .email()
        )
        
        UnifiedTextEditor(
            "产品描述",
            text: .constant(""),
            placeholder: "请输入产品的详细描述...",
            minHeight: 80
        )
    }
    .padding()
}
