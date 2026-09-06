import SwiftUI

struct AppGroupsSettingsView: View {
    @ObservedObject var service: AppGroupsService
    @State private var name = ""

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                TextField("New group name", text: $name).onSubmit(create)
                Button(action: create) { Image(systemName: "plus") }
                    .help("Create group")
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            List {
                ForEach(service.groups) { group in
                    HStack(spacing: 10) {
                        AppGroupPreview(group: group, service: service)
                        VStack(alignment: .leading) {
                            TextField("Group name", text: Binding(get: { group.name }, set: { service.rename(group.id, name: $0) }))
                            Text("\(group.paths.count) apps").font(.caption).foregroundStyle(.secondary)
                        }
                        Button { service.chooseApps(for: group.id) } label: { Image(systemName: "plus.app") }
                            .help("Choose apps").buttonStyle(.borderless)
                        Button { service.remove(group.id) } label: { Image(systemName: "trash") }
                            .help("Delete group").buttonStyle(.borderless)
                        Image(systemName: "line.3.horizontal").foregroundStyle(.secondary)
                    }.padding(.vertical, 6)
                }.onMove { service.move(from: $0, to: $1) }
            }.listStyle(.inset)
            if let error = service.error { Text(error).foregroundStyle(.red).font(.caption) }
        }
    }

    private func create() {
        service.create(name: name)
        name = ""
    }
}
