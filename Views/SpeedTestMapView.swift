import SwiftUI
import MapKit
import CoreLocation

/// Reusable map view showing Start/End markers.
/// If coordinates are unavailable - shows placeholder text.
struct SpeedTestMapView: View {
    let start: CLLocationCoordinate2D?
    let end: CLLocationCoordinate2D?

    @State private var position: MapCameraPosition = .automatic

    // ✅ Fix: use Equatable keys for onChange (CLLocationCoordinate2D is not Equatable)
    private var startKey: String {
        guard let s = start else { return "nil" }
        return "\(s.latitude),\(s.longitude)"
    }

    private var endKey: String {
        guard let e = end else { return "nil" }
        return "\(e.latitude),\(e.longitude)"
    }

    var body: some View {
        Group {
            if start == nil && end == nil {
                ContentUnavailableView("Location unavailable", systemImage: "location.slash")
                    .frame(maxWidth: .infinity, minHeight: 180)
            } else {
                Map(position: $position) {
                    if let start {
                        Marker("Start", coordinate: start)
                    }
                    if let end {
                        Marker("End", coordinate: end)
                    }
                }
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .onAppear {
                    updateCamera()
                }
                .onChange(of: startKey) { _ in updateCamera() }
                .onChange(of: endKey) { _ in updateCamera() }
            }
        }
    }

    private func updateCamera() {
        if let start, let end {
            let region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(
                    latitude: (start.latitude + end.latitude) / 2.0,
                    longitude: (start.longitude + end.longitude) / 2.0
                ),
                span: MKCoordinateSpan(
                    latitudeDelta: abs(start.latitude - end.latitude) * 2.5 + 0.01,
                    longitudeDelta: abs(start.longitude - end.longitude) * 2.5 + 0.01
                )
            )
            position = .region(region)
        } else if let only = start ?? end {
            let region = MKCoordinateRegion(
                center: only,
                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
            )
            position = .region(region)
        }
    }
}
