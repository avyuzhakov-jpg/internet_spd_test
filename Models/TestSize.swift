import Foundation

enum TestSize: Int, CaseIterable, Identifiable, Codable {
    case mb5 = 5
    case mb50 = 50

    var id: Int { rawValue }

    var displayTitle: String {
        "\(rawValue) MB"
    }
}
