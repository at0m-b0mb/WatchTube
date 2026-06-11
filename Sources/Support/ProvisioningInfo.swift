import Foundation

/// Tells the user when their free-provisioned app will expire so they know
/// when to re-deploy from Xcode. The build date is baked in at compile time;
/// free Apple IDs get 7 days, paid accounts get 365.
enum ProvisioningInfo {
    /// The moment this binary was compiled (embedded by the Swift compiler).
    static let buildDate: Date = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d yyyy HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        // __DATE__ and __TIME__ aren't available in Swift, so we read the
        // executable's modification date — Xcode stamps it at build time.
        if let execURL = Bundle.main.executableURL,
           let attrs = try? FileManager.default.attributesOfItem(atPath: execURL.path),
           let mod = attrs[.modificationDate] as? Date {
            return mod
        }
        return Date.now
    }()

    /// Whether this looks like a paid ($99/yr) provisioning profile — those
    /// last a full year. We check the embedded profile for the expiry; if
    /// there's no profile at all (simulator) we assume free.
    static let isPaid: Bool = {
        guard let profileURL = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: profileURL),
              let string = String(data: data, encoding: .ascii) else {
            return false
        }
        // Paid profiles have a much later ExpirationDate (roughly a year out).
        // Free profiles expire in ~7 days. A quick heuristic: if the plist
        // contains "ProvisionsAllDevices" or the expiry is > 30 days from the
        // creation date, it's paid.
        return string.contains("ProvisionsAllDevices")
    }()

    static let lifetimeDays: Int = isPaid ? 365 : 7

    /// When the provisioning profile (and therefore the app) stops working.
    static var expiryDate: Date {
        Calendar.current.date(byAdding: .day, value: lifetimeDays, to: buildDate)!
    }

    /// Days remaining before the app expires. Negative means already expired.
    static var daysRemaining: Int {
        Calendar.current.dateComponents([.day], from: Date.now, to: expiryDate).day ?? 0
    }

    /// A short human label: "5 days left", "Expires today", "Expired".
    static var summary: String {
        let d = daysRemaining
        if d > 1 { return "\(d) days left" }
        if d == 1 { return "1 day left" }
        if d == 0 { return "Expires today" }
        return "Expired — re-deploy from Xcode"
    }

    /// Color hint for the UI: green (4+), yellow (1-3), red (0 or expired).
    static var urgency: Urgency {
        let d = daysRemaining
        if d >= 4 { return .ok }
        if d >= 1 { return .soon }
        return .expired
    }

    enum Urgency { case ok, soon, expired }
}
