import SwiftUI
import PhotosUI
import CoreData

struct EditProductView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    let product: Product
    var onSave: ((Product) -> Void)?

    init(product: Product, onSave: ((Product) -> Void)? = nil) {
        self.product = product
        self.onSave = onSave
    }

    var body: some View {
        UniversalProductFormView(
            mode: .edit(product),
            onSave: onSave
        ) {
            dismiss()
        }
    }
}
