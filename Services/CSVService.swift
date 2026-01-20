import Foundation

/// Handles CSV persistence in Documents directory.
/// - Appends log lines
/// - Reads all records
/// - Provides file URL for ShareSheet export
final class CSVService {

    enum CSVError: LocalizedError {
        case cannotCreateDirectory
        case cannotWriteHeader
        case cannotReadFile

        var errorDescription: String? {
            switch self {
            case .cannotCreateDirectory:
                return "Cannot create storage directory."
            case .cannotWriteHeader:
                return "Cannot write CSV header."
            case .cannotReadFile:
                return "Cannot read CSV file."
            }
        }
    }

    private let fileManager = FileManager.default
    private let fileName = "speedtest_logs.csv"

    /// CSV header (stable order as required)
    static let headerLine: String =
    [
        "timestamp",
        "download_mbps",
        "upload_mbps",
        "ping_ms",
        "jitter_ms",
        "network_type",
        "location_start_lat",
        "location_start_lon",
        "location_end_lat",
        "location_end_lon",
        "location_status",
        "test_size_mb",
        "server_base_url",
        "error_message"
    ].joined(separator: ",")

    /// Path: Documents/speedtest_logs.csv
    func csvFileURL() throws -> URL {
        guard let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw CSVError.cannotCreateDirectory
        }
        return docs.appendingPathComponent(fileName)
    }

    /// Ensures file exists + header is written.
    private func ensureCSVExists() throws {
        let url = try csvFileURL()

        if !fileManager.fileExists(atPath: url.path) {
            do {
                try (CSVService.headerLine + "\n").write(to: url, atomically: true, encoding: .utf8)
            } catch {
                throw CSVError.cannotWriteHeader
            }
        }
    }

    /// Escapes string for CSV:
    /// - Wrap in quotes if contains comma or quote or newline
    /// - Double quotes inside field
    static func escapeCSVField(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return value
    }

    /// Converts LogRecord to a CSV line (matching header order).
    static func toCSVLine(_ record: LogRecord) -> String {
        [
            escapeCSVField(record.timestampISO8601),
            String(format: "%.3f", record.downloadMbps),
            String(format: "%.3f", record.uploadMbps),
            String(format: "%.3f", record.pingMs),
            String(format: "%.3f", record.jitterMs),
            escapeCSVField(record.networkTypeRaw),

            escapeCSVField(record.locationStartLat),
            escapeCSVField(record.locationStartLon),
            escapeCSVField(record.locationEndLat),
            escapeCSVField(record.locationEndLon),
            escapeCSVField(record.locationStatusRaw),

            "\(record.testSizeMb)",
            escapeCSVField(record.serverBaseURL),
            escapeCSVField(record.errorMessage)
        ].joined(separator: ",")
    }

    /// Append record to CSV.
    func append(_ record: LogRecord) throws {
        try ensureCSVExists()
        let url = try csvFileURL()

        let line = CSVService.toCSVLine(record) + "\n"

        if let handle = try? FileHandle(forWritingTo: url) {
            try handle.seekToEnd()
            if let data = line.data(using: .utf8) {
                try handle.write(contentsOf: data)
            }
            try handle.close()
        } else {
            // fallback
            var existing = (try? String(contentsOf: url, encoding: .utf8)) ?? (CSVService.headerLine + "\n")
            existing += line
            try existing.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    /// Reads all CSV lines and parses into LogRecord array (best effort).
    /// We keep parsing simple: since we only write CSV from our own app, format is predictable.
    func readAllRecords() throws -> [LogRecord] {
        try ensureCSVExists()
        let url = try csvFileURL()

        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            throw CSVError.cannotReadFile
        }

        let lines = content
            .split(separator: "\n")
            .map(String.init)

        guard lines.count >= 2 else { return [] } // header only

        // NOTE: We do not implement full CSV parser with quotes here.
        // Since our writer quotes fields when needed, we keep values safe.
        // For "production", a full CSV parser can be added later (still no 3rd party).
        // For now we parse by commas with minimal handling (works for most typical values).
        let dataLines = lines.dropFirst()

        return dataLines.compactMap { line in
            let parts = splitCSVLine(line)
            guard parts.count >= 14 else { return nil }

            return LogRecord(
                id: UUID(),
                timestampISO8601: parts[0],
                downloadMbps: Double(parts[1]) ?? 0,
                uploadMbps: Double(parts[2]) ?? 0,
                pingMs: Double(parts[3]) ?? 0,
                jitterMs: Double(parts[4]) ?? 0,
                networkTypeRaw: parts[5],
                locationStartLat: parts[6],
                locationStartLon: parts[7],
                locationEndLat: parts[8],
                locationEndLon: parts[9],
                locationStatusRaw: parts[10],
                testSizeMb: Int(parts[11]) ?? 0,
                serverBaseURL: parts[12],
                errorMessage: parts[13]
            )
        }
    }

    /// Minimal CSV splitter that respects quotes.
    private func splitCSVLine(_ line: String) -> [String] {
        var result: [String] = []
        var current = ""
        var inQuotes = false

        var iterator = line.makeIterator()
        while let ch = iterator.next() {
            if ch == "\"" {
                if inQuotes {
                    // If next is also quote -> escaped quote
                    if let next = iterator.next() {
                        if next == "\"" {
                            current.append("\"")
                        } else {
                            // quote closed, push back next char by appending it later
                            inQuotes = false
                            current.append(next)
                        }
                    } else {
                        inQuotes = false
                    }
                } else {
                    inQuotes = true
                }
            } else if ch == "," && !inQuotes {
                result.append(current)
                current = ""
            } else {
                current.append(ch)
            }
        }
        result.append(current)
        return result
    }
}
