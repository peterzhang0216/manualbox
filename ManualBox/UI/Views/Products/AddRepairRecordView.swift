import SwiftUI
import CoreData

struct AddRepairRecordView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    let order: Order
    
    @State private var repairDate = Date()
    @State private var details = ""
    @State private var cost = ""
    
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
                    .overlay(
                        Group {
                            if details.isEmpty {
                                Text("请输入维修详情...")
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 8)
                                    .allowsHitTesting(false)
                            }
                        },
                        alignment: .topLeading
                    )
            }
            
            Section {
                Button(action: saveRecord) {
                    Text("添加维修记录")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isValid)
            }
        }
        .navigationTitle("添加维修记录")
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
        guard !cost.isEmpty else { return false }
        return Decimal(string: cost.replacingOccurrences(of: ",", with: "")) != nil
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
        
        // 创建新记录
        _ = RepairRecord.createRepairRecord(
            in: viewContext,
            date: repairDate,
            details: details,
            cost: costValue,
            order: order
        )
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("保存维修记录失败: \(error.localizedDescription)")
        }
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let order = try! context.fetch(NSFetchRequest<Order>(entityName: "Order")).first!
    
    return NavigationStack {
        AddRepairRecordView(order: order)
            .environment(\.managedObjectContext, context)
    }
}
