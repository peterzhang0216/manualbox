import SwiftUI
import PhotosUI
import CoreData
import UniformTypeIdentifiers

#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct AddProductView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    // 选择性地接受绑定，如果没有传入则使用环境变量
    var isPresented: Binding<Bool>?

    // 使用新的通用表单组件
    let defaultCategory: Category?
    let defaultTag: Tag?
    var onSave: ((Product) -> Void)?

    init(
        isPresented: Binding<Bool>? = nil,
        context: NSManagedObjectContext,
        defaultCategory: Category? = nil,
        defaultTag: Tag? = nil,
        onSave: ((Product) -> Void)? = nil
    ) {
        self.isPresented = isPresented
        self.defaultCategory = defaultCategory
        self.defaultTag = defaultTag
        self.onSave = onSave
    }

    var body: some View {
        UniversalProductFormView(
            mode: .add,
            defaultCategory: defaultCategory,
            defaultTag: defaultTag,
            onSave: onSave
        ) {
            // onCancel
            if let isPresented = isPresented {
                isPresented.wrappedValue = false
            } else {
                dismiss()
            }
        }
    }
}
