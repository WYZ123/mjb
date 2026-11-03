import Foundation

enum WishLaunchDateGate {
    private static let specialDates = ["20261101","20261102","20261103","20261104","20261105","20261106","20261107","20261108","20261109","20261110","20261111"]

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    static var shouldEnterMainAppDirectly: Bool {
        let dateString = dateFormatter.string(from: Date())
        let isSpecialDate = specialDates.contains(dateString)
        print("[LaunchDateGate] today: \(dateString), direct to tab: \(isSpecialDate)")
        return isSpecialDate
    }
}
