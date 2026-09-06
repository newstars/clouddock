import Foundation

struct GitRepositorySnapshot: Equatable, Identifiable {
    var id: String { path }

    var path: String
    var name: String
    var branch: String
    var changedFiles: Int
    var ahead: Int
    var behind: Int
    var isAvailable: Bool
}

struct GitStatusSnapshot: Equatable {
    var repositories: [GitRepositorySnapshot]
    var message: String

    static let empty = GitStatusSnapshot(repositories: [], message: "Choose repos")

    var availableRepositories: [GitRepositorySnapshot] {
        repositories.filter(\.isAvailable)
    }

    var changedFiles: Int {
        availableRepositories.reduce(0) { $0 + $1.changedFiles }
    }

    var ahead: Int {
        availableRepositories.reduce(0) { $0 + $1.ahead }
    }

    var behind: Int {
        availableRepositories.reduce(0) { $0 + $1.behind }
    }

    var isRepository: Bool {
        !availableRepositories.isEmpty
    }

    var compactText: String {
        guard isRepository else {
            return "Git --"
        }

        if changedFiles == 0 && ahead == 0 && behind == 0 {
            return availableRepositories.count == 1 ? "Git clean" : "Git \(availableRepositories.count) clean"
        }

        return availableRepositories.count == 1 ? "Git \(changedFiles)" : "Git \(availableRepositories.count)/\(changedFiles)"
    }
}

final class GitStatusService: ObservableObject {
    @Published private(set) var snapshot = GitStatusSnapshot.empty

    var repositoryPaths: [String] = []

    func refresh() {
        let paths = repositoryPaths
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !paths.isEmpty else {
            snapshot = .empty
            return
        }

        let repositories = paths.map(readRepositoryStatus)
        snapshot = GitStatusSnapshot(repositories: repositories, message: repositories.isEmpty ? "Choose repos" : "Ready")
    }

    private func readRepositoryStatus(path: String) -> GitRepositorySnapshot {
        guard let result = CommandRunner.run(
            "/usr/bin/git",
            arguments: ["-C", path, "status", "--porcelain=v1", "-b"],
            timeout: 1.5
        ) else {
            return unavailableRepository(path: path)
        }

        return parseStatus(result.output, path: path)
    }

    private func unavailableRepository(path: String) -> GitRepositorySnapshot {
        GitRepositorySnapshot(
            path: path,
            name: URL(fileURLWithPath: path).lastPathComponent,
            branch: "--",
            changedFiles: 0,
            ahead: 0,
            behind: 0,
            isAvailable: false
        )
    }

    private func parseStatus(_ output: String, path: String) -> GitRepositorySnapshot {
        let lines = output.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
        guard let branchLine = lines.first, branchLine.hasPrefix("## ") else {
            return unavailableRepository(path: path)
        }

        return GitRepositorySnapshot(
            path: path,
            name: URL(fileURLWithPath: path).lastPathComponent,
            branch: parseBranch(from: branchLine),
            changedFiles: lines.dropFirst().count,
            ahead: parseCount(named: "ahead", in: branchLine),
            behind: parseCount(named: "behind", in: branchLine),
            isAvailable: true
        )
    }

    private func parseBranch(from line: String) -> String {
        let trimmed = line.replacingOccurrences(of: "## ", with: "")
        let beforeTracking = trimmed.components(separatedBy: "...").first ?? trimmed
        let beforeState = beforeTracking.components(separatedBy: " [").first ?? beforeTracking
        return beforeState.isEmpty ? "--" : beforeState
    }

    private func parseCount(named key: String, in line: String) -> Int {
        guard let range = line.range(of: "\(key) ") else {
            return 0
        }

        let suffix = line[range.upperBound...]
        let digits = suffix.prefix { $0.isNumber }
        return Int(digits) ?? 0
    }
}
