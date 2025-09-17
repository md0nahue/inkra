import Foundation
import Network
import Combine

@MainActor
class NetworkConnectivityService: ObservableObject {
    nonisolated static let shared = NetworkConnectivityService()
    
    @Published var isConnected: Bool = true
    @Published var connectionType: NWInterface.InterfaceType?
    
    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "NetworkConnectivityMonitor")
    
    nonisolated private init() {
        monitor = NWPathMonitor()
        startMonitoring()
    }
    
    nonisolated private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                self?.isConnected = path.status == .satisfied
                self?.connectionType = path.availableInterfaces.first?.type
                
                // Log connectivity changes
                if path.status == .satisfied {
                    print("📶 Network connected via \(self?.connectionType?.description ?? "unknown")")
                } else {
                    print("📵 Network disconnected")
                }
                
                // Post notification for other services
                NotificationCenter.default.post(
                    name: .networkConnectivityChanged,
                    object: nil,
                    userInfo: ["isConnected": path.status == .satisfied]
                )
            }
        }
        
        monitor.start(queue: queue)
    }
    
    deinit {
        monitor.cancel()
    }
}

extension NWInterface.InterfaceType {
    var description: String {
        switch self {
        case .wifi:
            return "WiFi"
        case .cellular:
            return "Cellular"
        case .wiredEthernet:
            return "Ethernet"
        case .loopback:
            return "Loopback"
        case .other:
            return "Other"
        @unknown default:
            return "Unknown"
        }
    }
}

extension Notification.Name {
    static let networkConnectivityChanged = Notification.Name("networkConnectivityChanged")
}