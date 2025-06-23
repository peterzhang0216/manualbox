import SwiftUI
import CoreData

struct TagsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Tag.name, ascending: true)],
        animation: .default)
    private var tags: FetchedResults<Tag>
    
    var body: some View {
        Group {
            if tags.isEmpty {
                ContentUnavailableView {
                    Label("暂无标签", systemImage: "tag")
                } description: {
                    Text("请从左侧导航选择标签管理来添加新标签")
                }
            } else {
                List {
                    ForEach(tags) { tagItem in
                        NavigationLink(destination: TagDetailView(tag: tagItem)) {
                            TagRow(tag: tagItem)
                        }
                    }
                    .onDelete(perform: deleteTags)
                }
            }
        }
        .navigationTitle("标签管理")
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
