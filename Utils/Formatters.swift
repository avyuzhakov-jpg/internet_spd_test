import Foundation
import CoreLocation

enum Formatters {

    /// ISO8601 formatter with fractional seconds for stable CSV timestamps.
    static let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    /// Converts Date to ISO8601 string.
    static func iso8601String(from date: Date) -> String {
        iso8601.string(from: date)
    }

    /// Rounds a double to N decimal places and returns string.
    static func roundedString(_ value: Double, decimals: Int) -> String {
        let factor = pow(10.0, Double(decimals))
        let rounded = (value * factor).rounded() / factor
        return String(format: "%.\(decimals)f", rounded)
    }

    /// Coordinate -> rounded lat/lon strings (3 decimals by requirement).
    static func roundedCoordinateStrings(_ coordinate: CLLocationCoordinate2D?, decimals: Int = 3) -> (lat: String, lon: String) {
        guard let c = coordinate else {
            return ("", "")
        }
        return (
            lat: roundedString(c.latitude, decimals: decimals),
            lon: roundedString(c.longitude, decimals: decimals)
        )
    }
}
