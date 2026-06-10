import WatchKit

/// Thin wrapper over the Taptic Engine so call sites read nicely.
enum Haptics {
    static func tap()     { WKInterfaceDevice.current().play(.click) }
    static func success() { WKInterfaceDevice.current().play(.success) }
    static func warn()    { WKInterfaceDevice.current().play(.retry) }
}
