import SwiftUI

// MARK: - 依赖相关状态
struct DependencyState {
    var dependencies: [ModrinthProjectDetail] = []
    var versions: [String: [ModrinthProjectDetailVersion]] = [:]
    var selected: [String: ModrinthProjectDetailVersion?] = [:]
    var isLoading = false
}

// MARK: - 依赖区块
struct DependencySectionView: View {
    @Binding var state: DependencyState

    var body: some View {
        if state.isLoading {
            ProgressView().controlSize(.small)
        } else if !state.dependencies.isEmpty {
            spacerView()
            VStack(alignment: .leading, spacing: 12) {
                ForEach(state.dependencies, id: \.id) { dep in
                    VStack {
                        Text(dep.title)
                            .font(.headline)
                            .bold()
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if let versions = state.versions[dep.id],
                            !versions.isEmpty {
                            CommonMenuPicker(
                                selection:
                                    Binding(
                                    get: {
                                        state.selected[dep.id] ?? versions.first
                                    },
                                    set: { state.selected[dep.id] = $0 }
                                )
                            ) {
                                Text("global_resource.dependency_version".localized())
                            } content: {
                                ForEach(versions, id: \.id) { v in
                                    Text(v.name).tag(Optional(v))
                                }
                            }
                        } else {
                            Text("global_resource.no_version".localized())
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }
}
