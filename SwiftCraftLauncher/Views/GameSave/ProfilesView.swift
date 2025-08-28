import MinecraftNBT
import SwiftUI

struct ProfileSummary: Identifiable {
    let id: String  // 存档文件夹名
    let levelName: String
    let seed: String
    let gameType: String
    let difficulty: String
    let allowCommands: String
    let lastPlayed: String
}

struct ProfilesView: View {
    let gameName: String
    @State private var saveFolders: [String] = []
    @State private var selectedFolder: String = ""

    var savesRoot: String? {
        AppPaths.savesDirectory(gameName: gameName)?.path
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if saveFolders.isEmpty {

                Text("no.saves".localized()).foregroundColor(.secondary)
            } else {
                HStack {
                    Text("save.info".localized())
                        .font(.headline)
                    Spacer()
                    Picker("", selection: $selectedFolder) {
                        ForEach(saveFolders, id: \.self) { folder in
                            Text(folder)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .tag(folder)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                    .pickerStyle(MenuPickerStyle())
                }

                if !selectedFolder.isEmpty, let savesRoot = savesRoot {
                    GameSaveInfoView(
                        levelDatPath: "\(savesRoot)/\(selectedFolder)/level.dat"
                    )
                    .padding(.top, 12)
                    .id(selectedFolder)
                }
            }
        }
        .onAppear(perform: loadSaveFolders)
    }

    private func loadSaveFolders() {
        guard let savesRoot = self.savesRoot else {
            self.saveFolders = []
            self.selectedFolder = ""
            return
        }
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                atPath: savesRoot
            )
            let folders = contents.compactMap { name -> (String, Date)? in
                let fullPath = "\(savesRoot)/\(name)"
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(
                    atPath: fullPath,
                    isDirectory: &isDir
                ), isDir.boolValue {
                    if let attrs = try? FileManager.default.attributesOfItem(
                        atPath: fullPath
                    ), let date = attrs[.modificationDate] as? Date {
                        return (name, date)
                    }
                }
                return nil
            }
            .sorted { $0.1 > $1.1 }
            .map { $0.0 }
            self.saveFolders = folders
            self.selectedFolder = folders.first ?? ""
        } catch {
            Logger.shared.error("读取存档文件夹失败: \(error.localizedDescription)")
            self.saveFolders = []
            self.selectedFolder = ""
        }
    }
}
