import SwiftUI

// MARK: - 自定义步进器组件
/// 替代 SwiftUI 原生 Stepper 以避免 AppKit 约束警告
/// 提供更好的视觉设计和用户体验
struct CustomStepper: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int
    let onIncrement: (() -> Void)?
    let onDecrement: (() -> Void)?
    
    // MARK: - 初始化方法
    
    /// 基础初始化方法
    init(
        _ title: String,
        value: Binding<Int>,
        in range: ClosedRange<Int>,
        step: Int = 1,
        onIncrement: (() -> Void)? = nil,
        onDecrement: (() -> Void)? = nil
    ) {
        self.title = title
        self._value = value
        self.range = range
        self.step = step
        self.onIncrement = onIncrement
        self.onDecrement = onDecrement
    }
    
    /// 便捷初始化方法（无回调）
    init(
        _ title: String,
        value: Binding<Int>,
        in range: ClosedRange<Int>,
        step: Int = 1
    ) {
        self.init(title, value: value, in: range, step: step, onIncrement: nil, onDecrement: nil)
    }
    
    var body: some View {
        HStack {
            Text(title)
            
            Spacer()
            
            HStack(spacing: 8) {
                // 减少按钮
                Button(action: decrementValue) {
                    Image(systemName: "minus.circle.fill")
                        .foregroundColor(canDecrement ? .accentColor : .gray)
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .disabled(!canDecrement)
                .help("减少")
                
                // 增加按钮
                Button(action: incrementValue) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(canIncrement ? .accentColor : .gray)
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .disabled(!canIncrement)
                .help("增加")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue("\(value)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                incrementValue()
            case .decrement:
                decrementValue()
            @unknown default:
                break
            }
        }
    }
    
    // MARK: - 计算属性
    
    private var canIncrement: Bool {
        value + step <= range.upperBound
    }
    
    private var canDecrement: Bool {
        value - step >= range.lowerBound
    }
    
    // MARK: - 私有方法
    
    private func incrementValue() {
        guard canIncrement else { return }
        value += step
        onIncrement?()
    }
    
    private func decrementValue() {
        guard canDecrement else { return }
        value -= step
        onDecrement?()
    }
}

// MARK: - 紧凑型步进器
/// 更紧凑的步进器样式，适用于空间有限的场景
struct CompactStepper: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int
    let unit: String
    
    init(
        _ title: String,
        value: Binding<Int>,
        in range: ClosedRange<Int>,
        step: Int = 1,
        unit: String = ""
    ) {
        self.title = title
        self._value = value
        self.range = range
        self.step = step
        self.unit = unit
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.accentColor)
            
            HStack(alignment: .center) {
                Text("\(value)")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.accentColor)
                    .frame(minWidth: 30, alignment: .trailing)
                
                if !unit.isEmpty {
                    Text(unit)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    Button(action: decrementValue) {
                        Image(systemName: "minus.circle.fill")
                            .foregroundColor(canDecrement ? .accentColor : .gray)
                    }
                    .buttonStyle(.plain)
                    .disabled(!canDecrement)
                    
                    Button(action: incrementValue) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(canIncrement ? .accentColor : .gray)
                    }
                    .buttonStyle(.plain)
                    .disabled(!canIncrement)
                }
                .font(.title2)
            }
        }
    }
    
    private var canIncrement: Bool {
        value + step <= range.upperBound
    }
    
    private var canDecrement: Bool {
        value - step >= range.lowerBound
    }
    
    private func incrementValue() {
        guard canIncrement else { return }
        value += step
    }
    
    private func decrementValue() {
        guard canDecrement else { return }
        value -= step
    }
}

// MARK: - 内联步进器
/// 内联样式的步进器，适用于表单中的数值输入
struct InlineStepper: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int
    
    init(
        _ title: String,
        value: Binding<Int>,
        in range: ClosedRange<Int>,
        step: Int = 1
    ) {
        self.title = title
        self._value = value
        self.range = range
        self.step = step
    }
    
    var body: some View {
        HStack {
            Text(title)
            
            Spacer()
            
            HStack(spacing: 12) {
                Button(action: decrementValue) {
                    Image(systemName: "minus.circle")
                        .foregroundColor(canDecrement ? .accentColor : .gray)
                }
                .buttonStyle(.plain)
                .disabled(!canDecrement)
                
                Text("\(value)")
                    .font(.body.monospacedDigit())
                    .frame(minWidth: 30)
                
                Button(action: incrementValue) {
                    Image(systemName: "plus.circle")
                        .foregroundColor(canIncrement ? .accentColor : .gray)
                }
                .buttonStyle(.plain)
                .disabled(!canIncrement)
            }
        }
    }
    
    private var canIncrement: Bool {
        value + step <= range.upperBound
    }
    
    private var canDecrement: Bool {
        value - step >= range.lowerBound
    }
    
    private func incrementValue() {
        guard canIncrement else { return }
        value += step
    }
    
    private func decrementValue() {
        guard canDecrement else { return }
        value -= step
    }
}

// MARK: - 预览
#Preview("Custom Stepper") {
    @Previewable @State var value1 = 12
    @Previewable @State var value2 = 5
    @Previewable @State var value3 = 30
    
    VStack(spacing: 20) {
        CustomStepper("保修期：\(value1) 个月", value: $value1, in: 0...60)
        
        CompactStepper("默认保修期", value: $value2, in: 0...60, unit: "个月")
        
        InlineStepper("提前 \(value3) 天提醒", value: $value3, in: 1...90)
    }
    .padding()
}
