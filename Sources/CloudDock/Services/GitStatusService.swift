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

@MainActor
final class GitStatusService: ObservableObject {
    @Published private(set) var snapshot = GitStatusSnapshot.empty
    private var isRefreshing = false

    var repositoryPaths: [String] = []

    func refresh() {
        guard !isRefreshing else { return }
        let requestedPaths = repositoryPaths
        let paths = repositoryPaths
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !paths.isEmpty else {
            snapshot = .empty
            return
        }

        isRefreshing = true
        Task { [weak self] in
            let results = await Task.detached(priority: .utility) {
                paths.map { path in
                    (path, CommandRunner.run("/usr/bin/git",
                        arguments: ["--no-optional-locks", "-C", path, "status", "--porcelain=v1", "-b"],
                        timeout: 1.5)?.output)
                }
            }.value
            guard let self else { return }
            self.isRefreshing = false
            guard self.repositoryPaths == requestedPaths else {
                self.refresh()
                return
            }
            let repositories = results.map { path, output in
                output.map { self.parseStatus($0, path: path) } ?? self.unavailableRepository(path: path)
            }
            self.snapshot = GitStatusSnapshot(repositories: repositories, message: "Ready")
        }
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
