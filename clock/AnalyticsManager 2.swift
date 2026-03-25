import Foundation

final class AnalyticsManager {
    static let shared = AnalyticsManager()

    private init() {}

    /// Captures an analytics event. This is a no-op placeholder that can be wired to your analytics backend.
    /// - Parameters:
    ///   - name: Event name
    ///   - properties: Optional key-value properties to attach to the event
    func capture(_ name: String, properties: [String: String]? = nil) {
        #if DEBUG
        // Simple debug log so you can see events during development.
        if let properties, !properties.isEmpty {
            let props = properties.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
            print("[Analytics] \(name) { \(props) }")
        } else {
            print("[Analytics] \(name)")
        }
        #endif
        // In production, integrate with your analytics SDK here.
    }
}
