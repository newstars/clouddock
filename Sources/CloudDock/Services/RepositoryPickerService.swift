import AppKit
import Foundation

@MainActor
enum RepositoryPickerService {
    static func chooseRepositories() -> [String]? {
        let panel = NSOpenPanel()
        panel.title = "Choose Git Repositories"
        panel.prompt = "Choose"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true

        guard panel.runModal() == .OK else {
            return nil
        }

        return validRepositoryPaths(panel.urls.map(\.path))
    }

    static func validRepositoryPaths(_ paths: [String]) -> [String] {
        paths.filter { path in
            guard FileManager.default.fileExists(atPath: path) else {
                return false
            }

            return CommandRunner.run(
                "/usr/bin/git",
                arguments: ["-C", path, "rev-parse", "--is-inside-work-tree"],
                timeout: 0.8
            )?.output.trimmingCharacters(in: .whitespacesAndNewlines) == "true"
        }
    }
}
