// Views/LogDetailView.swift

import SwiftUI
import MapKit
import CoreLocation

struct LogDetailView: View {
    let record: LogRecord

    var body: some View {
        Form {
            Section("Timestamp") {
                Text(record.timestampISO8601)
                    .font(.footnote)
                    .textSelection(.enabled)
            }

            // ✅ Updated строго как обсуждали: заменили specifier на format
            Section("Results") {
                LabeledContent("Download") {
                    Text(record.downloadMbps, format: .number.precision(.fractionLength(2)))
                    + Text(" Mbps")
                }

                LabeledContent("Upload") {
                    Text(record.uploadMbps, format: .number.precision(.fractionLength(2)))
                    + Text(" Mbps")
                }

                LabeledContent("Ping") {
                    Text(record.pingMs, format: .number.precision(.fractionLength(2)))
                    + Text(" ms")
                }

                LabeledContent("Jitter") {
                    Text(record.jitterMs, format: .number.precision(.fractionLength(2)))
                    + Text(" ms")
                }
            }

            Section("Network") {
                LabeledContent("Type", value: record.networkTypeRaw)
                LabeledContent("Test Size", value: "\(record.testSizeMb) MB")
                LabeledContent("Server", value: record.serverBaseURL)
            }

            Section("Location") {
                LabeledContent("Status", value: record.locationStatusRaw)
                LabeledContent("Start", value: "\(record.locationStartLat), \(record.locationStartLon)")
                LabeledContent("End", value: "\(record.locationEndLat), \(record.locationEndLon)")
            }

            // ✅ Added strictly as discussed: map section
            Section("Map") {
                SpeedTestMapView(
                    start: parseCoordinate(lat: record.locationStartLat, lon: record.locationStartLon),
                    end: parseCoordinate(lat: record.locationEndLat, lon: record.locationEndLon)
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            if !record.errorMessage.isEmpty {
                Section("Error") {
                    Text(record.errorMessage)
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                }
            }
        }
        .navigationTitle("Log Detail")
    }

    private func parseCoordinate(lat: String, lon: String) -> CLLocationCoordinate2D? {
        guard
            let la = Double(lat),
            let lo = Double(lon)
        else { return nil }
        return CLLocationCoordinate2D(latitude: la, longitude: lo)
    }
}
