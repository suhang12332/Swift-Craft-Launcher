import SwiftUI
//import MarkdownUI

// MARK: - Constants


// MARK: - ViewModel
class ModrinthDependencyViewModel: ObservableObject {
    @Published var dependencies: ModrinthProjectDependency?
    @Published var isLoading = false
    @Published var error: Error?

//    func loadDependencies(for projectId: String) {
//        isLoading = true
//        error = nil
//        Task {
//            do {
//                let deps = try await ModrinthService.fetchProjectDependencies(id: projectId)
//                await MainActor.run {
//                    self.dependencies = deps
//                    self.isLoading = false
//                }
//            } catch {
//                await MainActor.run {
//                    self.error = error
//                    self.isLoading = false
//                }
//            }
//        }
//    }
}

// MARK: - ModrinthProjectDetailDependencyView
struct ModrinthProjectDetailDependencyView: View {
    let projectId: String
    @StateObject private var viewModel = ModrinthDependencyViewModel()
    // 你可以根据需要传递这些参数
    var selectedVersions: [String] = []
    var selectedLoaders: [String] = []
    var gameInfo: GameVersionInfo? = nil
    let query: String
    var type: Bool = false
    @State private var selectedItem: SidebarItem = .resource(.mod) // 你可以根据实际情况调整

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("依赖列表")
                .font(.headline)
            if viewModel.isLoading {
                ProgressView("加载依赖中…")
            } else if let error = viewModel.error {
                Text("加载失败: \(error.localizedDescription)")
                    .foregroundColor(.red)
            } else if let dependencies = viewModel.dependencies {
                if dependencies.projects.isEmpty {
                    Text("无依赖")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(dependencies.projects, id: \.id) { projectDetail in
                        ModrinthDetailCardView(
                            project: ModrinthProject.from(detail: projectDetail),
                            selectedVersions: selectedVersions,
                            selectedLoaders: selectedLoaders,
                            gameInfo: gameInfo,
                            query: query,
                            type: type,
                            selectedItem: $selectedItem
                        )
                        .padding(.vertical, 4)
                    }
                    .listStyle(PlainListStyle())
                }
            }
        }
        .padding()
        .onAppear {
//            viewModel.loadDependencies(for: projectId,gameInfo?.gameVersion,gameInfo?.modLoader)
        }
    }
}
 

