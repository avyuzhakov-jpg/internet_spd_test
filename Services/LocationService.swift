import Foundation
import CoreLocation

/// Wrapper over CLLocationManager with async/await support.
/// Requirements:
/// - Location When In Use permission
/// - If unavailable -> return nil coordinates and status = .unavailable
@MainActor
final class LocationService: NSObject, CLLocationManagerDelegate {

    private let manager = CLLocationManager()

    private var authContinuation: CheckedContinuation<Bool, Never>?
    private var locationContinuation: CheckedContinuation<CLLocationCoordinate2D?, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    /// Requests When In Use authorization if needed.
    func requestAuthorizationIfNeeded() async -> Bool {
        let status = manager.authorizationStatus

        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            return true
        case .denied, .restricted:
            return false
        case .notDetermined:
            return await withCheckedContinuation { cont in
                self.authContinuation = cont
                self.manager.requestWhenInUseAuthorization()
            }
        @unknown default:
            return false
        }
    }

    /// Gets a single location fix (best effort).
    func getCurrentCoordinate() async -> CLLocationCoordinate2D? {
        let isAllowed = await requestAuthorizationIfNeeded()
        guard isAllowed else { return nil }

        // If location services disabled globally
        guard CLLocationManager.locationServicesEnabled() else {
            return nil
        }

        return await withCheckedContinuation { cont in
            self.locationContinuation = cont
            self.manager.requestLocation()
        }
    }

    // MARK: - CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard let cont = authContinuation else { return }
        authContinuation = nil

        let status = manager.authorizationStatus
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            cont.resume(returning: true)
        default:
            cont.resume(returning: false)
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let cont = locationContinuation else { return }
        locationContinuation = nil

        let coord = locations.last?.coordinate
        cont.resume(returning: coord)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard let cont = locationContinuation else { return }
        locationContinuation = nil
        cont.resume(returning: nil)
    }
}
