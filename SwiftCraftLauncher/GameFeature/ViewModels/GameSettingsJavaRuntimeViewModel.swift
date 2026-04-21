import Foundation

@MainActor
final class GameSettingsJavaRuntimeViewModel: ObservableObject {

    /// `nil` 表示正在扫描；非空数组为已安装的运行时组件名
    @Published private(set) var installedRuntimeComponents: [String]?
    @Published var selectedRuntimeComponent: String = ""

    @Published private(set) var javaVersionInfo: String = ""
    @Published private(set) var javaExecutablePath: String = ""

    private var loadTask: Task<Void, Never>?
    private var loadGeneration: Int = 0
    private let javaManager: JavaManager

    init(javaManager: JavaManager = AppServices.javaManager) {
        self.javaManager = javaManager
    }

    /// Java 详细信息说明，用于 InfoIconWithPopover 展示
    var javaDetailsDescription: String {
        JavaDetailsFormatting.description(
            javaExecutablePath: javaExecutablePath,
            versionOutput: javaVersionInfo
        )
    }

    func loadDetails(forRuntimeComponent component: String) {
        loadTask?.cancel()
        guard !component.isEmpty else {
            javaVersionInfo = ""
            javaExecutablePath = ""
            return
        }

        loadGeneration += 1
        let generation = loadGeneration

        let path = javaManager.getJavaExecutablePath(version: component)
        javaExecutablePath = path

        guard FileManager.default.isExecutableFile(atPath: path) else {
            javaVersionInfo = ""
            return
        }

        loadTask = Task { [weak self, javaManager] in
            guard let self else { return }
            let info = await Task.detached {
                javaManager.getJavaVersionInfo(at: path) ?? ""
            }.value
            guard generation == self.loadGeneration else { return }
            self.javaVersionInfo = info
        }
    }

    func refreshInstalledRuntimes(showScanningIndicator: Bool) {
        if showScanningIndicator {
            installedRuntimeComponents = nil
        }
        Task { [weak self, javaManager] in
            guard let self else { return }
            let list = await Task.detached(priority: .utility) {
                javaManager.listInstalledRuntimeComponents()
            }.value
            installedRuntimeComponents = list
            if list.isEmpty {
                selectedRuntimeComponent = ""
            } else if !list.contains(selectedRuntimeComponent) {
                selectedRuntimeComponent = list[0]
            }
        }
    }
}
