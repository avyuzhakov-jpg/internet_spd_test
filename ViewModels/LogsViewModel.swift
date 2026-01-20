import Foundation
import Combine

@MainActor
final class LogsViewModel: ObservableObject {
    @Published private(set) var records: [LogRecord] = []
    @Published var errorMessage: String?

    private let csvService: CSVService

    init(csvService: CSVService = CSVService()) {
        self.csvService = csvService
    }

    func refresh() {
        do {
            let items = try csvService.readAllRecords()
            self.records = items.reversed()
            self.errorMessage = nil
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    func exportCSVURL() -> URL? {
        do {
            return try csvService.csvFileURL()
        } catch {
            self.errorMessage = error.localizedDescription
            return nil
        }
    }
}
