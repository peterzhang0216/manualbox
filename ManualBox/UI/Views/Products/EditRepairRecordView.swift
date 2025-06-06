import SwiftUI
import CoreData

struct EditRepairRecordView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    let record: RepairRecord
    
    @State private var repairDate: Date
    @State private var details: String
    @State private var cost: String
    
    // 初始化函数来设置状态变量的初始值
    init(record: RepairRecord) {
        self.record = record
        _repairDate = State(initialValue: record.recordDate)
        _details = State(initialValue: record.recordDetails)
        
        // 格式化成本为字符串
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        _cost = State(initialValue: formatter.string(from: record.cost ?? NSDecimalNumber.zero) ?? "0")
    }
    
    var body: some View {
        Form {
            Section(header: Text("维修基本信息")) {
                DatePicker("维修日期", selection: $repairDate, displayedComponents: .date)
                
                TextField("维修费用", text: $cost)
#if os(iOS)
                    .keyboardType(.decimalPad)
#endif
            }
            
            Section(header: Text("维修详情")) {
                TextEditor(text: $details)
                    .frame(minHeight: 150)
                    .cornerRadius(8)
            }
            
            Section {
                Button(action: saveRecord) {
                    Text("保存修改")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isValid)
            }
        }
        .navigationTitle("编辑维修记录")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") {
                    dismiss()
                }
            }
        }
    }
    
    // 验证输入是否有效
    private var isValid: Bool {
        !details.isEmpty && isValidCost
    }
    
    // 验证费用输入是否有效
    private var isValidCost: Bool {
        guard let _ = Decimal(string: cost.replacingOccurrences(of: ",", with: "")) else {
            return false
        }
        return true
    }
    
    // 保存记录
    private func saveRecord() {
        // 解析维修费用
        let costValue: Decimal
        if let value = Decimal(string: cost.replacingOccurrences(of: ",", with: "")) {
            costValue = value
        } else {
            costValue = 0
        }
        
        // 更新记录
        record.date = repairDate
        record.details = details
        record.cost = NSDecimalNumber(decimal: costValue)
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("保存维修记录失败: \(error.localizedDescription)")
        }
    }
}

#Preview {
    NavigationStack {
        EditRepairRecordView(record: RepairRecord.preview)
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
