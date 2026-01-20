import Foundation

/// Record stored in CSV (persistent history).
/// Keep it simple + CSV-friendly.
struct LogRecord: Identifiable, Equatable {
    let id: UUID

    let timestampISO8601: String

    let downloadMbps: Double
    let uploadMbps: Double
    let pingMs: Double
    let jitterMs: Double

    let networkTypeRaw: String

    let locationStartLat: String
    let locationStartLon: String
    let locationEndLat: String
    let locationEndLon: String
    let locationStatusRaw: String

    let testSizeMb: Int
    let serverBaseURL: String

    let errorMessage: String
}
