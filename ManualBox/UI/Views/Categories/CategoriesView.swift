import SwiftUI
import CoreData

struct CategoriesView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Category.name, ascending: true)],
        animation: .default)
    private var categories: FetchedResults<Category>
    
    var body: some View {
        Group {
            if categories.isEmpty {
                ContentUnavailableView {
                    Label("暂无分类", systemImage: "folder")
                } description: {
                    Text("请从左侧导航选择分类管理来添加新分类")
                }
                .padding(.top, 20)
            } else {
                List {
                    ForEach(categories) { category in
                        NavigationLink(destination: CategoryDetailView(category: category)) {
                            CategoryRow(category: category)
                        }
                    }
                    .onDelete(perform: deleteCategories)
                }
            }
        }
        .navigationTitle("分类管理")
    }
    
    private func deleteCategories(offsets: IndexSet) {
        withAnimation {
            offsets.map { categories[$0] }.forEach(viewContext.delete)
            
            do {
                try viewContext.save()
            } catch {
                print("删除分类失败: \(error.localizedDescription)")
            }
        }
    }
}

struct CategoryRow: View {
    let category: Category
    
    var body: some View {
        HStack {
            Image(systemName: category.categoryIcon)
                .foregroundColor(.accentColor)
                .frame(width: 30)
            
            Text(category.categoryName)
            
            Spacer()
            
            Text("\(category.productCount)")
                .foregroundColor(.secondary)
        }
    }
}
