// Config/AppConfig.swift

import Foundation

enum AppConfig {
    static let baseURLString: String = "http://95.142.45.145/speedtest"

    static var baseURL: URL {
        guard let url = URL(string: baseURLString) else {
            // Fallback should never happen in production; still prevents crash
            return URL(string: "http://95.142.45.145/speedtest")!
        }
        return url
    }

    /// Ping samples used to compute ping (median) + jitter (stddev)
    static let pingSamplesCount: Int = 15
}
