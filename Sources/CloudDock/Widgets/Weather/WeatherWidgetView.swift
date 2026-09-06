import Combine
import Foundation
import SwiftUI

@MainActor
struct WeatherWidgetView: View {
    @StateObject private var model = DockWeatherModel()
    @State private var isPresented = false
    @State private var query = ""
    @State private var searchRevision = 0
    @State private var forecastRevision = 0

    var body: some View {
        Button { isPresented.toggle() } label: {
            SystemApplicationIcon(bundleIdentifier: "com.apple.weather", fallback: "cloud.sun")
        }
        .buttonStyle(.plain)
        .help("Weather")
        .accessibilityLabel("Weather")
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Weather").font(.headline)
                    Spacer()
                    Button { forecastRevision += 1 } label: { Image(systemName: "arrow.clockwise") }
                        .help("Refresh weather")
                        .disabled(model.city == nil || model.isLoading)
                }
                TextField("Search city", text: $query)
                    .textFieldStyle(.roundedBorder)
                if model.isSearching { ProgressView("Searching...") }
                if let error = model.searchError {
                    Text(error).font(.caption).foregroundStyle(.red)
                    Button("Retry search") { searchRevision += 1 }
                } else if model.didSearch && model.results.isEmpty && !model.isSearching {
                    Text("No cities found.").foregroundStyle(.secondary)
                }
                if !model.results.isEmpty {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(model.results) { city in
                                Button {
                                    model.select(city)
                                    query = ""
                                } label: {
                                    Text(city.label).frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .frame(maxHeight: 150)
                }
                Divider()
                if !model.cities.isEmpty {
                    HStack {
                        Picker("City", selection: Binding(
                            get: { model.city?.id ?? -1 },
                            set: { id in
                                if let city = model.cities.first(where: { $0.id == id }) { model.select(city) }
                            }
                        )) {
                            ForEach(model.cities) { city in Text(city.label).tag(city.id) }
                        }
                        Button { model.removeSelectedCity() } label: { Image(systemName: "minus.circle") }
                            .help("Remove selected city")
                    }
                }
                if let city = model.city {
                    Text(city.label).font(.subheadline.weight(.semibold))
                    if model.isLoading {
                        ProgressView("Loading weather...")
                    } else if let error = model.forecastError {
                        Text(error).font(.caption).foregroundStyle(.red)
                        Button("Retry weather") { forecastRevision += 1 }
                    } else if let current = model.current {
                        Label(current.condition, systemImage: current.symbol)
                        Text("\(current.temperature_2m, specifier: "%.1f") °C")
                            .font(.system(size: 28, weight: .medium))
                        Text("Feels like \(current.apparent_temperature, specifier: "%.1f") °C")
                        Text("Humidity \(current.relative_humidity_2m)% · Wind \(current.wind_speed_10m, specifier: "%.1f") km/h")
                            .font(.caption)
                        Text("As of \(model.observationTime(current.time))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                } else {
                    Text("No city selected.").foregroundStyle(.secondary)
                }
                HStack {
                    Link("Weather: Open-Meteo", destination: URL(string: "https://open-meteo.com/")!)
                    Link("Cities: GeoNames", destination: URL(string: "https://www.geonames.org/")!)
                }
                .font(.caption)
            }
            .dockPopoverPanel(width: 340)
            .task(id: "\(query)|\(searchRevision)") { await model.search(query) }
            .task(id: "\(model.city?.id ?? -1)|\(forecastRevision)") { await model.loadForecast() }
        }
    }
}

@MainActor
private final class DockWeatherModel: ObservableObject {
    struct City: Codable, Identifiable, Sendable {
        let id: Int
        let name: String
        let latitude: Double
        let longitude: Double
        let admin1: String?
        let country: String?
        let timezone: String?
        var label: String { [name, admin1, country].compactMap { $0 }.joined(separator: ", ") }
        var isValid: Bool {
            !name.isEmpty && latitude.isFinite && longitude.isFinite
                && (-90...90).contains(latitude) && (-180...180).contains(longitude)
        }
    }

    struct Current: Decodable, Sendable {
        let time: Double
        let temperature_2m: Double
        let apparent_temperature: Double
        let relative_humidity_2m: Int
        let weather_code: Int
        let wind_speed_10m: Double
        let is_day: Int

        var condition: String {
            switch weather_code {
            case 0: "Clear sky"
            case 1: "Mainly clear"
            case 2: "Partly cloudy"
            case 3: "Overcast"
            case 45, 48: "Fog"
            case 51, 53, 55: "Drizzle"
            case 56, 57: "Freezing drizzle"
            case 61, 63, 65: "Rain"
            case 66, 67: "Freezing rain"
            case 71, 73, 75, 77: "Snow"
            case 80, 81, 82: "Rain showers"
            case 85, 86: "Snow showers"
            case 95: "Thunderstorm"
            case 96, 99: "Thunderstorm with hail"
            default: "Unknown condition (\(weather_code))"
            }
        }

        var symbol: String {
            switch weather_code {
            case 0, 1: is_day == 1 ? "sun.max" : "moon.stars"
            case 2: is_day == 1 ? "cloud.sun" : "cloud.moon"
            case 3: "cloud"
            case 45, 48: "cloud.fog"
            case 51...67, 80...82: "cloud.rain"
            case 71...77, 85, 86: "cloud.snow"
            case 95, 96, 99: "cloud.bolt.rain"
            default: "questionmark.circle"
            }
        }
    }

    private struct SearchResponse: Decodable, Sendable { let results: [City]? }
    private struct ForecastResponse: Decodable, Sendable { let current: Current }
    private static let cityKey = "CloudDock.weather.selectedCity.v1"
    private static let citiesKey = "CloudDock.weather.cities.v2"
    @Published private(set) var cities: [City] = []
    @Published private(set) var city: City?
    @Published private(set) var results: [City] = []
    @Published private(set) var current: Current?
    @Published private(set) var isSearching = false
    @Published private(set) var isLoading = false
    @Published private(set) var didSearch = false
    @Published private(set) var searchError: String?
    @Published private(set) var forecastError: String?
    private var searchID = UUID()
    private var forecastID = UUID()

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.citiesKey),
           let saved = try? JSONDecoder().decode([City].self, from: data) {
            var seen = Set<Int>()
            cities = saved.filter { $0.isValid && seen.insert($0.id).inserted }
        }
        if let data = UserDefaults.standard.data(forKey: Self.cityKey),
           let saved = try? JSONDecoder().decode(City.self, from: data), saved.isValid {
            city = saved
            if !cities.contains(where: { $0.id == saved.id }) { cities.append(saved) }
        }
        if city == nil { city = cities.first }
        saveCities()
    }

    func select(_ city: City) {
        guard city.isValid else { return }
        if !cities.contains(where: { $0.id == city.id }) { cities.append(city) }
        saveCities()
        forecastID = UUID()
        self.city = city
        current = nil
        forecastError = nil
        results = []
        if let data = try? JSONEncoder().encode(city) {
            UserDefaults.standard.set(data, forKey: Self.cityKey)
        }
    }

    func removeSelectedCity() {
        guard let selected = city else { return }
        cities.removeAll { $0.id == selected.id }
        forecastID = UUID()
        current = nil
        forecastError = nil
        isLoading = false
        city = nil
        UserDefaults.standard.removeObject(forKey: Self.cityKey)
        saveCities()
        if let next = cities.first { select(next) }
    }

    private func saveCities() {
        if let data = try? JSONEncoder().encode(cities) {
            UserDefaults.standard.set(data, forKey: Self.citiesKey)
        }
    }

    func search(_ text: String) async {
        let id = UUID()
        searchID = id
        results = []
        searchError = nil
        didSearch = false
        isSearching = false
        let name = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard name.count >= 2 else { return }
        isSearching = true
        defer { if searchID == id { isSearching = false } }
        do {
            try await Task.sleep(for: .milliseconds(350))
            let response: SearchResponse = try await Self.fetch(
                host: "geocoding-api.open-meteo.com", path: "/v1/search",
                items: [URLQueryItem(name: "name", value: name), URLQueryItem(name: "count", value: "8")])
            try Task.checkCancellation()
            guard searchID == id else { return }
            results = (response.results ?? []).filter(\.isValid)
            didSearch = true
        } catch {
            guard !Task.isCancelled, searchID == id else { return }
            searchError = "City search failed: \(error.localizedDescription)"
        }
    }

    func loadForecast() async {
        let id = UUID()
        forecastID = id
        current = nil
        forecastError = nil
        isLoading = false
        guard let city else { return }
        isLoading = true
        defer { if forecastID == id { isLoading = false } }
        do {
            let response: ForecastResponse = try await Self.fetch(
                host: "api.open-meteo.com", path: "/v1/forecast", items: [
                    URLQueryItem(name: "latitude", value: String(city.latitude)),
                    URLQueryItem(name: "longitude", value: String(city.longitude)),
                    URLQueryItem(name: "current", value: "temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,wind_speed_10m,is_day"),
                    URLQueryItem(name: "temperature_unit", value: "celsius"),
                    URLQueryItem(name: "wind_speed_unit", value: "kmh"),
                    URLQueryItem(name: "timeformat", value: "unixtime")
                ])
            try Task.checkCancellation()
            guard forecastID == id else { return }
            current = response.current
        } catch {
            guard !Task.isCancelled, forecastID == id else { return }
            forecastError = "Weather unavailable: \(error.localizedDescription)"
        }
    }

    func observationTime(_ timestamp: Double) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.timeZone = city?.timezone.flatMap(TimeZone.init(identifier:)) ?? .current
        return formatter.string(from: Date(timeIntervalSince1970: timestamp))
            + " " + (formatter.timeZone.abbreviation() ?? "")
    }

    private nonisolated static func fetch<T: Decodable & Sendable>(
        host: String, path: String, items: [URLQueryItem]
    ) async throws -> T {
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = path
        components.queryItems = items
        guard let url = components.url else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse,
              http.url?.scheme?.lowercased() == "https" else { throw URLError(.badServerResponse) }
        guard (200..<300).contains(http.statusCode) else {
            throw NSError(domain: "Open-Meteo", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "Server returned HTTP \(http.statusCode)."])
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}
