import Foundation

@MainActor
final class CloudDockRuntime: ObservableObject {
    static let shared = CloudDockRuntime()

    @Published var viewModel: DockViewModel?

    private init() {}
}
