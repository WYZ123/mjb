import Foundation

enum WishFormat {
    static func money(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.locale = Locale(identifier: "en_US")
        formatter.currencySymbol = "$"
        let whole = abs(value - value.rounded()) < 0.005
        formatter.minimumFractionDigits = whole ? 0 : 2
        formatter.maximumFractionDigits = whole ? 0 : 2
        return formatter.string(from: NSNumber(value: value)) ?? "$0"
    }

    static func percent(_ ratio: Double) -> String {
        let value = ratio * 100
        if !value.isFinite {
            return "0%"
        }
        if abs(value - value.rounded()) < 0.05 {
            return "\(Int(value.rounded()))%"
        }
        return String(format: "%.1f%%", value)
    }

    static func monthDay(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    static func monthYear(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        return formatter.string(from: date)
    }

    static func fullDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.setLocalizedDateFormatFromTemplate("MMMMd yyyy")
        return formatter.string(from: date)
    }

    static func weekday(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }

    static func axisAmount(_ value: Double) -> String {
        let sign = value < 0 ? "-" : ""
        let amount = abs(value)
        if amount >= 1_000_000 {
            return sign + compact(amount / 1_000_000, suffix: "m")
        }
        if amount >= 1_000 {
            return sign + compact(amount / 1_000, suffix: "k")
        }
        if abs(amount - amount.rounded()) < 0.05 {
            return sign + "\(Int(amount.rounded()))"
        }
        return sign + String(format: "%.0f", amount.rounded())
    }

    static func editable(_ value: Double) -> String {
        if abs(value - value.rounded()) < 0.001 {
            return String(Int(value.rounded()))
        }
        var text = String(format: "%.2f", value)
        while text.last == "0" {
            text.removeLast()
        }
        if text.last == "." {
            text.removeLast()
        }
        return text
    }

    static func parseAmount(_ raw: String) -> Double? {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        text = text.replacingOccurrences(of: "，", with: ".")
        text = text.replacingOccurrences(of: ",", with: "")
        text = text.replacingOccurrences(of: "$", with: "")
        text = text.replacingOccurrences(of: "¥", with: "")
        text = text.replacingOccurrences(of: "￥", with: "")
        text = text.replacingOccurrences(of: " ", with: "")
        guard let value = Double(text), value.isFinite, value >= 0 else { return nil }
        return value
    }

    static func parseDays(_ raw: String) -> Int? {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Int(text), value > 0, value < 100_000 else { return nil }
        return value
    }

    private static func compact(_ value: Double, suffix: String) -> String {
        if abs(value - value.rounded()) < 0.05 {
            return "\(Int(value.rounded()))\(suffix)"
        }
        return String(format: "%.1f\(suffix)", value)
    }
}
