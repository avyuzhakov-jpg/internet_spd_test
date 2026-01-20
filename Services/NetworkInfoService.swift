import Foundation
import Network

/// Detects current network type using NWPathMonitor.
/// Production-safe: monitor runs on a background queue.
final class NetworkInfoService {

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkInfoService.monitor")

    private var currentType: NetworkType = .unknown

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }

            if path.usesInterfaceType(.wifi) {
                self.currentType = .wifi
            } else if path.usesInterfaceType(.cellular) {
                self.currentType = .cellular
            } else {
                self.currentType = .unknown
            }
        }

        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }

    func getNetworkType() -> NetworkType {
        currentType
    }
}
