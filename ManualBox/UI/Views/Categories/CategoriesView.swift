import SwiftUI
import CoreData



struct AddCategorySheet: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Binding var isPresented: Bool
    @State private var categoryName = ""
    @State private var selectedIcon = "folder"
    
    var body: some View {
        Form {
            TextField("分类名称", text: $categoryName)
            
            Picker("图标", selection: $selectedIcon) {
                ForEach(systemIcons, id: \.self) { icon in
                    Label("", systemImage: icon)
                }
            }
        }
        .formStyle(.grouped)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") {
                    isPresented = false
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    addCategory()
                }
                .disabled(categoryName.isEmpty)
            }
        }
    }
    
    private func addCategory() {
        let category = Category(context: viewContext)
        category.id = UUID()
        category.name = categoryName
        category.icon = selectedIcon
        
        do {
            try viewContext.save()
            isPresented = false
        } catch {
            print("保存分类失败: \(error.localizedDescription)")
        }
    }
}

struct CategoriesView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Category.name, ascending: true)],
        animation: .default)
    private var categories: FetchedResults<Category>
    
    @State private var showingAddSheet = false
    
    var body: some View {
        Group {
            if categories.isEmpty {
                ContentUnavailableView {
                    Label("暂无分类", systemImage: "folder")
                } description: {
                    Text("点击右上角的 + 按钮添加新分类")
                } actions: {
                    Button(action: { showingAddSheet = true }) {
                        Text("添加分类")
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                List {
                    ForEach(categories) { category in
                        NavigationLink(destination: ProductListView(category: category)) {
                            CategoryRow(category: category)
                        }
                    }
                    .onDelete(perform: deleteCategories)
                }
            }
        }
        .navigationTitle("分类管理")
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingAddSheet = true }) {
                    Label("添加分类", systemImage: "plus")
                }
            }
            #else
            ToolbarItem {
                Button(action: { showingAddSheet = true }) {
                    Label("添加分类", systemImage: "plus")
                }
            }
            #endif
        }
        #if os(macOS)
        .sheet(isPresented: $showingAddSheet) {
            AddCategorySheet(isPresented: $showingAddSheet)
                .frame(minWidth: 400, minHeight: 200)
                .environment(\.managedObjectContext, viewContext)
        }
        #else
        .sheet(isPresented: $showingAddSheet) {
            NavigationView {
                AddCategorySheet(isPresented: $showingAddSheet)
                    .navigationTitle("新建分类")
            }
        }
        #endif
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
