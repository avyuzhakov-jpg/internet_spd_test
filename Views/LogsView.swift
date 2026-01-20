import SwiftUI

struct LogsView: View {
    @StateObject private var viewModel = LogsViewModel()

    @State private var isSharePresented = false
    @State private var shareURL: URL?

    var body: some View {
        NavigationStack {
            Group {
                if let error = viewModel.errorMessage {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Error")
                                .font(.headline)

                            Text(error)
                                .foregroundStyle(.red)
                                .font(.footnote)
                                .textSelection(.enabled)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else if viewModel.records.isEmpty {
                    ContentUnavailableView(
                        "No logs yet",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("Run a speed test to generate CSV history.")
                    )
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 16) {
                            ForEach(groupedKeysSorted, id: \.self) { dayKey in
                                Text(humanDayTitle(for: dayKey))
                                    .font(.headline)
                                    .padding(.horizontal, 4)
                                    .padding(.top, 6)

                                LazyVStack(spacing: 12) {
                                    ForEach(groupedRecords[dayKey] ?? []) { record in
                                        NavigationLink {
                                            LogDetailView(record: record)
                                        } label: {
                                            logCard(record)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Logs")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Export CSV") {
                        if let url = viewModel.exportCSVURL() {
                            self.shareURL = url
                            self.isSharePresented = true
                        }
                    }
                }
            }
            .onAppear {
                viewModel.refresh()
            }
            .refreshable {
                viewModel.refresh()
            }
            .sheet(isPresented: $isSharePresented) {
                if let url = shareURL {
                    ShareSheet(items: [url])
                }
            }
        }
    }

    // MARK: - Grouping

    private var groupedRecords: [String: [LogRecord]] {
        Dictionary(grouping: viewModel.records) { record in
            dayKey(for: record.timestampISO8601)
        }
    }

    private var groupedKeysSorted: [String] {
        groupedRecords.keys.sorted(by: >)
    }

    private func dayKey(for iso: String) -> String {
        guard let date = LogsDateFormatters.iso8601Date(iso) else { return "Unknown date" }
        return LogsDateFormatters.dayKeyFormatter.string(from: date)
    }

    private func humanDayTitle(for dayKey: String) -> String {
        guard dayKey != "Unknown date",
              let date = LogsDateFormatters.dayKeyToDate(dayKey) else {
            return "Unknown date"
        }
        return LogsDateFormatters.humanDayFormatter.string(from: date)
    }

    // MARK: - UI

    private func logCard(_ record: LogRecord) -> some View {
        let timeText = humanTime(from: record.timestampISO8601)

        return VStack(alignment: .leading, spacing: 10) {
            Text(timeText)
                .font(.footnote)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                metricChip(title: "↓", value: record.downloadMbps)
                metricChip(title: "↑", value: record.uploadMbps)

                Text("Ping \(record.pingMs, format: .number.precision(.fractionLength(0))) ms")
                    .font(.subheadline)
                    .foregroundStyle(.primary)
            }

            if !record.errorMessage.isEmpty {
                Text("Error: \(record.errorMessage)")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func metricChip(title: String, value: Double) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(value, format: .number.precision(.fractionLength(1)))
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }

    private func humanTime(from iso: String) -> String {
        guard let date = LogsDateFormatters.iso8601Date(iso) else {
            return iso
        }
        return LogsDateFormatters.timeFormatter.string(from: date)
    }
}

// MARK: - Local date formatters (UI-only)

private enum LogsDateFormatters {
    // ✅ FIX: support fractional seconds (".447Z")
    private static let isoWithFractionalSeconds: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [
            .withInternetDateTime,
            .withFractionalSeconds
        ]
        return f
    }()

    // fallback parser (without fractional seconds)
    private static let isoWithoutFractionalSeconds: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static func iso8601Date(_ string: String) -> Date? {
        // try fractional first, then fallback
        if let d = isoWithFractionalSeconds.date(from: string) {
            return d
        }
        return isoWithoutFractionalSeconds.date(from: string)
    }

    static let dayKeyFormatter: DateFormatter = {
        let df = DateFormatter()
        df.calendar = Calendar(identifier: .gregorian)
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(secondsFromGMT: 0)
        df.dateFormat = "yyyy-MM-dd"
        return df
    }()

    static func dayKeyToDate(_ key: String) -> Date? {
        dayKeyFormatter.date(from: key)
    }

    static let humanDayFormatter: DateFormatter = {
        let df = DateFormatter()
        df.calendar = Calendar.current
        df.locale = Locale.current
        df.timeZone = TimeZone.current
        df.dateStyle = .medium
        df.timeStyle = .none
        return df
    }()

    static let timeFormatter: DateFormatter = {
        let df = DateFormatter()
        df.calendar = Calendar.current
        df.locale = Locale.current
        df.timeZone = TimeZone.current
        df.dateStyle = .none
        df.timeStyle = .short
        return df
    }()
}
