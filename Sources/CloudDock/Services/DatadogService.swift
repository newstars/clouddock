import Foundation
import Security

struct DatadogCredentials: Codable {
    let site: String
    let apiKey: String
    let applicationKey: String
}

enum DatadogKeychain {
    private static var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: "dev.clouddock.Datadog",
         kSecAttrAccount as String: "credentials"]
    }

    static func load() -> DatadogCredentials? {
        var request = query
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(request as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(DatadogCredentials.self, from: data)
    }

    static func save(_ credentials: DatadogCredentials) throws {
        let data = try JSONEncoder().encode(credentials)
        let update = [kSecValueData as String: data]
        var status = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        if status == errSecItemNotFound {
            var item = query
            item[kSecValueData as String] = data
            item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            status = SecItemAdd(item as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(status)) }
    }

    static func remove() throws {
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
    }
}

@MainActor
final class DatadogService: ObservableObject {
    struct Monitor: Decodable, Identifiable {
        let id: Int
        let name: String
        let overall_state: String?
    }

    static let sites = ["datadoghq.com", "us3.datadoghq.com", "us5.datadoghq.com", "datadoghq.eu", "ap1.datadoghq.com", "ap2.datadoghq.com", "uk1.datadoghq.com"]
    @Published var monitors: [Monitor] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var connected = false
    @Published var updatedAt: Date?
    @Published var hasMore = false
    private var credentials: DatadogCredentials?
    private var page = 0

    func restore() {
        guard credentials == nil else { return }
        credentials = DatadogKeychain.load()
        connected = credentials != nil
    }

    func connect(site: String, apiKey: String, applicationKey: String) async {
        let value = DatadogCredentials(site: site, apiKey: apiKey.trimmingCharacters(in: .whitespacesAndNewlines), applicationKey: applicationKey.trimmingCharacters(in: .whitespacesAndNewlines))
        guard Self.sites.contains(site), !value.apiKey.isEmpty, !value.applicationKey.isEmpty else {
            error = "Enter both API and application keys."; return
        }
        do {
            try DatadogKeychain.save(value)
            credentials = value
            connected = true
            await refresh()
        } catch { self.error = "Could not save credentials to Keychain." }
    }

    func disconnect() {
        guard !isLoading else { return }
        do {
            try DatadogKeychain.remove()
            credentials = nil; connected = false; monitors = []; updatedAt = nil; error = nil
        } catch { self.error = "Could not remove credentials from Keychain." }
    }

    func refresh(more: Bool = false) async {
        guard !isLoading, let credentials, Self.sites.contains(credentials.site) else { return }
        isLoading = true; error = nil
        defer { isLoading = false }
        let requestedPage = more ? page + 1 : 0
        let url = URL(string: "https://api.\(credentials.site)/api/v1/monitor?page=\(requestedPage)&page_size=100")!
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue(credentials.apiKey, forHTTPHeaderField: "DD-API-KEY")
        request.setValue(credentials.applicationKey, forHTTPHeaderField: "DD-APPLICATION-KEY")
        let session = URLSession(configuration: .ephemeral, delegate: NoDatadogRedirects(), delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                error = code == 403 || code == 401 ? "Check site, keys, and monitors_read permission." : "Datadog request failed (HTTP \(code))."
                return
            }
            let result = try JSONDecoder().decode([Monitor].self, from: data)
            let existing = more ? monitors : []
            let ids = Set(existing.map(\.id))
            monitors = existing + result.filter { !ids.contains($0.id) }
            page = requestedPage; hasMore = result.count == 100; updatedAt = .now
        } catch { self.error = "Datadog unavailable. Check your connection and retry." }
    }

    func monitorURL(_ id: Int) -> URL? {
        guard let site = credentials?.site, Self.sites.contains(site) else { return nil }
        let host = site == "datadoghq.com" || site == "datadoghq.eu" ? "app.\(site)" : site
        return URL(string: "https://\(host)/monitors/\(id)")
    }
}

private final class NoDatadogRedirects: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}
