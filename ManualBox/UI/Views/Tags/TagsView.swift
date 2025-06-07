import SwiftUI
import CoreData

struct AddTagSheet: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Binding var isPresented: Bool
    @State private var tagName = ""
    @State private var selectedColor = TagColor.blue
    
    var body: some View {
        Form {
            TextField("标签名称", text: $tagName)
            
            Picker("颜色", selection: $selectedColor) {
                ForEach(TagColor.allCases) { color in
                    HStack {
                        Circle()
                            .fill(color.color)
                            .frame(width: 20, height: 20)
                        Text(color.displayName)
                    }
                    .tag(color)
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
                    addTag()
                }
                .disabled(tagName.isEmpty)
            }
        }
    }
    
    private func addTag() {
        let tag = Tag(context: viewContext)
        tag.id = UUID()
        tag.name = tagName
        tag.color = selectedColor.rawValue
        
        do {
            try viewContext.save()
            isPresented = false
        } catch {
            print("保存标签失败: \(error.localizedDescription)")
        }
    }
}

struct TagsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Tag.name, ascending: true)],
        animation: .default)
    private var tags: FetchedResults<Tag>
    
    @State private var showingAddSheet = false
    
    var body: some View {
        Group {
            if tags.isEmpty {
                ContentUnavailableView {
                    Label("暂无标签", systemImage: "tag")
                } description: {
                    Text("点击右上角的 + 按钮添加新标签")
                } actions: {
                    Button(action: { showingAddSheet = true }) {
                        Text("添加标签")
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                List {
                    ForEach(tags) { tag in
                        NavigationLink(destination: ProductListView(tag: tag)) {
                            TagRow(tag: tag)
                        }
                    }
                    .onDelete(perform: deleteTags)
                }
            }
        }
        .navigationTitle("标签管理")
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingAddSheet = true }) {
                    Label("添加标签", systemImage: "plus")
                }
            }
            #else
            ToolbarItem {
                Button(action: { showingAddSheet = true }) {
                    Label("添加标签", systemImage: "plus")
                }
            }
            #endif
        }
        #if os(macOS)
        .sheet(isPresented: $showingAddSheet) {
            AddTagSheet(isPresented: $showingAddSheet)
                .frame(minWidth: 400, minHeight: 200)
                .environment(\.managedObjectContext, viewContext)
        }
        #else
        .sheet(isPresented: $showingAddSheet) {
            NavigationView {
                AddTagSheet(isPresented: $showingAddSheet)
                    .navigationTitle("新建标签")
            }
        }
        #endif
    }
    
    private func deleteTags(offsets: IndexSet) {
        withAnimation {
            offsets.map { tags[$0] }.forEach(viewContext.delete)
            
            do {
                try viewContext.save()
            } catch {
                print("删除标签失败: \(error.localizedDescription)")
            }
        }
    }
}

struct TagRow: View {
    let tag: Tag
    
    var body: some View {
        HStack {
            Circle()
                .fill(tag.uiColor)
                .frame(width: 12, height: 12)
            
            Text(tag.tagName)
            
            Spacer()
            
            Text("\(tag.productCount)")
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    NavigationView {
        TagsView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
