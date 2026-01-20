import Foundation

enum NetworkType: String, Codable {
    case wifi
    case cellular
    case unknown

    var displayName: String {
        switch self {
        case .wifi: return "Wi-Fi"
        case .cellular: return "Cellular"
        case .unknown: return "Unknown"
        }
    }
}
