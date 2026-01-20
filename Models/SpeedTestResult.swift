import Foundation
import CoreLocation

/// Result of a completed speed test (in-memory).
/// This is what UI shows after the test.
struct SpeedTestResult: Equatable {
    let timestamp: Date

    let downloadMbps: Double
    let uploadMbps: Double

    /// Median or average ping in milliseconds
    let pingMs: Double

    /// Jitter in milliseconds (derived from ping sample series)
    let jitterMs: Double

    let networkType: NetworkType

    /// Start & end coordinates (may be nil if location unavailable)
    let startLocation: CLLocationCoordinate2D?
    let endLocation: CLLocationCoordinate2D?

    let locationStatus: LocationStatus
    let testSize: TestSize

    let serverBaseURL: String

    /// If something failed, we still produce a record with errorMessage.
    let errorMessage: String
}
