import Foundation
import Network
import Combine

// MARK: - Network Monitor
/// Monitors network connectivity and notifies observers of changes
@MainActor
final class NetworkMonitor: ObservableObject {
    // MARK: - Singleton
    static let shared = NetworkMonitor()

    // MARK: - Published Properties
    @Published private(set) var isConnected: Bool = true
    @Published private(set) var connectionType: ConnectionType = .unknown

    // MARK: - Private Properties
    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "com.unforgotten.networkmonitor")

    // MARK: - Connection Type
    enum ConnectionType: String {
        case wifi
        case cellular
        case wiredEthernet
        case unknown

        var displayName: String {
            switch self {
            case .wifi: return "Wi-Fi"
            case .cellular: return "Cellular"
            case .wiredEthernet: return "Ethernet"
            case .unknown: return "Unknown"
            }
        }
    }

    // MARK: - Initialization
    private init() {
        monitor = NWPathMonitor()
        startMonitoring()
    }

    // MARK: - Monitoring
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.handlePathUpdate(path)
            }
        }
        monitor.start(queue: queue)
    }

    private func handlePathUpdate(_ path: NWPath) {
        let wasConnected = isConnected
        isConnected = path.status == .satisfied

        // Determine connection type
        if path.usesInterfaceType(.wifi) {
            connectionType = .wifi
        } else if path.usesInterfaceType(.cellular) {
            connectionType = .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            connectionType = .wiredEthernet
        } else {
            connectionType = .unknown
        }

        // Log connectivity changes
        #if DEBUG
        if wasConnected != isConnected {
            print("🌐 Network status changed: \(isConnected ? "Connected" : "Disconnected") via \(connectionType.displayName)")
        }
        #endif

        // Post notification for components not using Combine
        if wasConnected != isConnected {
            NotificationCenter.default.post(
                name: .networkConnectivityChanged,
                object: nil,
                userInfo: ["isConnected": isConnected]
            )
        }
    }

    // MARK: - Public Methods

    /// Check current connectivity (synchronous, uses cached value)
    func checkConnectivity() -> Bool {
        return isConnected
    }

    /// Stop monitoring (call when app terminates)
    func stopMonitoring() {
        monitor.cancel()
    }
}

// MARK: - Notification Extension
extension Notification.Name {
    static let networkConnectivityChanged = Notification.Name("networkConnectivityChanged")
}
