import Foundation

struct DateReminder: Codable, Hashable {
    var daysBefore = 0
    var hour = 9
    var minute = 0
    var alsoOnDay = true

    static let advanceOptions = [0, 1, 3, 7]

    var offsets: [Int] {
        guard Self.advanceOptions.contains(daysBefore), (0...23).contains(hour), (0...59).contains(minute) else {
            return []
        }
        return daysBefore > 0 && alsoOnDay ? [daysBefore, 0] : [daysBefore]
    }

    var summary: String {
        let timing = daysBefore == 0 ? "当天" : "提前 \(daysBefore) 天\(alsoOnDay ? "及当天" : "")"
        return "\(timing) \(String(format: "%02d:%02d", hour, minute))"
    }
}
