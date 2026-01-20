// ViewModels/SpeedTestViewModel.swift

import Foundation
import Combine
import CoreLocation

@MainActor
final class SpeedTestViewModel: ObservableObject {

    enum Phase: String {
        case idle = "Idle"
        case pinging = "Pinging…"
        case downloading = "Downloading…"
        case uploading = "Uploading…"
        case saving = "Saving…"
        case done = "Done"
        case failed = "Failed"
    }

    // UI state
    @Published var selectedSize: TestSize = .mb5
    @Published private(set) var phase: Phase = .idle
    @Published private(set) var isRunning: Bool = false
    @Published private(set) var progress: Double = 0.0

    @Published private(set) var downloadMbps: Double?
    @Published private(set) var uploadMbps: Double?
    @Published private(set) var pingMs: Double?
    @Published private(set) var jitterMs: Double?

    @Published private(set) var networkType: NetworkType = .unknown

    @Published private(set) var startCoordinate: CLLocationCoordinate2D?
    @Published private(set) var endCoordinate: CLLocationCoordinate2D?
    @Published private(set) var locationStatus: LocationStatus = .unavailable

    @Published private(set) var errorMessage: String = ""

    // Dependencies
    private let speedTestService: SpeedTestService
    private let locationService: LocationService
    private let networkInfoService: NetworkInfoService
    private let csvService: CSVService

    private var runningTask: Task<Void, Never>?

    // ✅ Единственное изменение: убран default LocationService() из параметров init
    init(
        speedTestService: SpeedTestService = SpeedTestService(),
        locationService: LocationService? = nil,
        networkInfoService: NetworkInfoService = NetworkInfoService(),
        csvService: CSVService = CSVService()
    ) {
        self.speedTestService = speedTestService
        self.locationService = locationService ?? LocationService()
        self.networkInfoService = networkInfoService
        self.csvService = csvService
    }

    func startTest() {
        guard !isRunning else { return }

        // Reset UI
        isRunning = true
        errorMessage = ""
        phase = .pinging

        downloadMbps = nil
        uploadMbps = nil
        pingMs = nil
        jitterMs = nil

        startCoordinate = nil
        endCoordinate = nil
        locationStatus = .unavailable

        progress = 0.0

        // Capture network type at start
        networkType = networkInfoService.getNetworkType()

        let testSize = selectedSize
        let serverURL = AppConfig.baseURLString

        runningTask = Task { [weak self] in
            guard let self = self else { return }

            let timestamp = Date()

            // Location start (best effort)
            let startCoord = await self.locationService.getCurrentCoordinate()
            await MainActor.run {
                self.startCoordinate = startCoord
                self.locationStatus = (startCoord != nil) ? .ok : .unavailable
            }

            do {
                // 1) Ping/Jitter
                await MainActor.run {
                    self.phase = .pinging
                    self.progress = 0.10
                }
                let (ping, jitter) = try await self.speedTestService.measurePingAndJitter(samples: AppConfig.pingSamplesCount)

                await MainActor.run {
                    self.pingMs = ping
                    self.jitterMs = jitter
                    self.progress = 0.35
                }

                // 2) Download
                await MainActor.run {
                    self.phase = .downloading
                    self.progress = 0.40
                }
                let down = try await self.speedTestService.measureDownloadMbps(size: testSize)

                await MainActor.run {
                    self.downloadMbps = down
                    self.progress = 0.70
                }

                // 3) Upload
                await MainActor.run {
                    self.phase = .uploading
                    self.progress = 0.75
                }
                let up = try await self.speedTestService.measureUploadMbps(size: testSize)

                await MainActor.run {
                    self.uploadMbps = up
                    self.progress = 0.90
                }

                // Location end (best effort)
                let endCoord = await self.locationService.getCurrentCoordinate()
                await MainActor.run {
                    self.endCoordinate = endCoord
                    if self.locationStatus == .ok && endCoord == nil {
                        // If start was ok but end failed, still consider location unavailable
                        self.locationStatus = .unavailable
                    }
                }

                // Save CSV
                await MainActor.run {
                    self.phase = .saving
                    self.progress = 0.95
                }

                let (startLat, startLon) = Formatters.roundedCoordinateStrings(startCoord, decimals: 3)
                let (endLat, endLon) = Formatters.roundedCoordinateStrings(endCoord, decimals: 3)

                let record = LogRecord(
                    id: UUID(),
                    timestampISO8601: Formatters.iso8601String(from: timestamp),
                    downloadMbps: down,
                    uploadMbps: up,
                    pingMs: ping,
                    jitterMs: jitter,
                    networkTypeRaw: self.networkType.rawValue,
                    locationStartLat: startLat,
                    locationStartLon: startLon,
                    locationEndLat: endLat,
                    locationEndLon: endLon,
                    locationStatusRaw: self.locationStatus.rawValue,
                    testSizeMb: testSize.rawValue,
                    serverBaseURL: serverURL,
                    errorMessage: ""
                )

                do {
                    try self.csvService.append(record)
                    await MainActor.run {
                        self.phase = .done
                        self.progress = 1.0
                        self.isRunning = false
                    }
                } catch {
                    await MainActor.run {
                        self.phase = .failed
                        self.isRunning = false
                        self.errorMessage = error.localizedDescription
                    }
                }

            } catch is CancellationError {
                await self.saveFailureLog(
                    timestamp: timestamp,
                    testSize: testSize,
                    serverURL: serverURL,
                    startCoord: startCoord,
                    endCoord: nil,
                    message: "Cancelled"
                )
            } catch {
                // Capture location end even on failure (best effort)
                let endCoord = await self.locationService.getCurrentCoordinate()
                await MainActor.run {
                    self.endCoordinate = endCoord
                }

                let msg = error.localizedDescription
                await self.saveFailureLog(
                    timestamp: timestamp,
                    testSize: testSize,
                    serverURL: serverURL,
                    startCoord: startCoord,
                    endCoord: endCoord,
                    message: msg
                )
            }
        }
    }

    func cancelTest() {
        runningTask?.cancel()
        runningTask = nil
        isRunning = false
        phase = .idle
        progress = 0.0
    }

    // MARK: - Helpers

    private func saveFailureLog(
        timestamp: Date,
        testSize: TestSize,
        serverURL: String,
        startCoord: CLLocationCoordinate2D?,
        endCoord: CLLocationCoordinate2D?,
        message: String
    ) async {
        await MainActor.run {
            self.phase = .failed
            self.isRunning = false
            self.errorMessage = message
            self.progress = 0.0
        }

        let (startLat, startLon) = Formatters.roundedCoordinateStrings(startCoord, decimals: 3)
        let (endLat, endLon) = Formatters.roundedCoordinateStrings(endCoord, decimals: 3)

        let record = LogRecord(
            id: UUID(),
            timestampISO8601: Formatters.iso8601String(from: timestamp),
            downloadMbps: downloadMbps ?? 0,
            uploadMbps: uploadMbps ?? 0,
            pingMs: pingMs ?? 0,
            jitterMs: jitterMs ?? 0,
            networkTypeRaw: networkType.rawValue,
            locationStartLat: startLat,
            locationStartLon: startLon,
            locationEndLat: endLat,
            locationEndLon: endLon,
            locationStatusRaw: (startCoord != nil ? "ok" : "unavailable"),
            testSizeMb: testSize.rawValue,
            serverBaseURL: serverURL,
            errorMessage: message
        )

        // Even if location unavailable -> we still log
        do {
            try csvService.append(record)
        } catch {
            // If CSV write fails, at least we keep errorMessage in UI
            await MainActor.run {
                self.errorMessage = "\(message)\nCSV save failed: \(error.localizedDescription)"
            }
        }
    }
}
