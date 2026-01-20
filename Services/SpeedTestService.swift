import Foundation

/// Production-quality speed test service.
/// Uses URLSession + async/await and measures:
/// - Ping median (ms) + Jitter std deviation (ms)
/// - Download speed (Mbps) by downloading N MB from server
/// - Upload speed (Mbps) by uploading N MB raw binary (application/octet-stream)
final class SpeedTestService {

    enum SpeedTestError: LocalizedError {
        case invalidBaseURL
        case invalidResponse
        case httpError(statusCode: Int)
        case uploadNotOk
        case cancelled

        var errorDescription: String? {
            switch self {
            case .invalidBaseURL:
                return "Invalid base URL."
            case .invalidResponse:
                return "Invalid server response."
            case .httpError(let code):
                return "HTTP error: \(code)"
            case .uploadNotOk:
                return "Upload failed: server returned ok=false."
            case .cancelled:
                return "Cancelled."
            }
        }
    }

    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL = AppConfig.baseURL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    // MARK: - Public API

    /// Performs a full test sequence:
    /// 1) ping/jitter
    /// 2) download speed
    /// 3) upload speed
    func runFullTest(size: TestSize) async throws -> (pingMs: Double, jitterMs: Double, downloadMbps: Double, uploadMbps: Double) {
        try Task.checkCancellation()

        let (ping, jitter) = try await measurePingAndJitter(samples: AppConfig.pingSamplesCount)

        try Task.checkCancellation()

        let download = try await measureDownloadMbps(size: size)

        try Task.checkCancellation()

        let upload = try await measureUploadMbps(size: size)

        return (ping, jitter, download, upload)
    }

    // MARK: - Ping / Jitter

    func measurePingAndJitter(samples: Int) async throws -> (pingMs: Double, jitterMs: Double) {
        var times: [Double] = []
        times.reserveCapacity(samples)

        for _ in 0..<samples {
            try Task.checkCancellation()
            let ms = try await singlePingMs()
            times.append(ms)

            // Small delay between pings to reduce burst effects
            try await Task.sleep(nanoseconds: 120_000_000) // 120ms
        }

        guard let result = Statistics.pingAndJitter(from: times) else {
            return (0, 0)
        }
        return (result.pingMs, result.jitterMs)
    }

    private func singlePingMs() async throws -> Double {
        let url = baseURL.appendingPathComponent("ping")

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10

        let start = CFAbsoluteTimeGetCurrent()
        let (_, response) = try await session.data(for: request)
        let end = CFAbsoluteTimeGetCurrent()

        guard let http = response as? HTTPURLResponse else {
            throw SpeedTestError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            throw SpeedTestError.httpError(statusCode: http.statusCode)
        }

        let seconds = end - start
        return seconds * 1000.0
    }

    // MARK: - Download

    func measureDownloadMbps(size: TestSize) async throws -> Double {
        var comps = URLComponents(url: baseURL.appendingPathComponent("download"), resolvingAgainstBaseURL: false)
        comps?.queryItems = [
            URLQueryItem(name: "size", value: "\(size.rawValue)")
        ]
        guard let url = comps?.url else {
            throw SpeedTestError.invalidBaseURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 60

        // Measure "payload transfer time" by timing the entire data(for:) call.
        // This is a practical approximation for app-level measurement.
        let start = CFAbsoluteTimeGetCurrent()
        let (data, response) = try await session.data(for: request)
        let end = CFAbsoluteTimeGetCurrent()

        guard let http = response as? HTTPURLResponse else {
            throw SpeedTestError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            throw SpeedTestError.httpError(statusCode: http.statusCode)
        }

        let seconds = max(end - start, 0.0001)
        let bytes = Double(data.count)

        // Mbps = (bytes * 8) / seconds / 1_000_000
        let mbps = (bytes * 8.0) / seconds / 1_000_000.0
        return mbps
    }

    // MARK: - Upload

    func measureUploadMbps(size: TestSize) async throws -> Double {
        let url = baseURL.appendingPathComponent("upload")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 90
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")

        // Generate raw binary payload: 5MB or 50MB
        let payload = makeRandomData(megabytes: size.rawValue)

        let start = CFAbsoluteTimeGetCurrent()
        let (data, response) = try await session.upload(for: request, from: payload)
        let end = CFAbsoluteTimeGetCurrent()

        guard let http = response as? HTTPURLResponse else {
            throw SpeedTestError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            throw SpeedTestError.httpError(statusCode: http.statusCode)
        }

        // Server returns JSON: {"ok": true}
        if !isUploadOkResponse(data) {
            throw SpeedTestError.uploadNotOk
        }

        let seconds = max(end - start, 0.0001)
        let bytes = Double(payload.count)

        let mbps = (bytes * 8.0) / seconds / 1_000_000.0
        return mbps
    }

    private func isUploadOkResponse(_ data: Data) -> Bool {
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let ok = json["ok"] as? Bool
        else { return false }

        return ok
    }

    /// Creates pseudo-random data without compression.
    private func makeRandomData(megabytes: Int) -> Data {
        let byteCount = megabytes * 1_000_000 // MB in decimal for network measurement consistency
        var bytes = [UInt8](repeating: 0, count: byteCount)
        for i in 0..<bytes.count {
            bytes[i] = UInt8.random(in: 0...255)
        }
        return Data(bytes)
    }
}
