import Foundation

@main
struct FestivalTests {
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return calendar
    }

    static func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    static func names(_ date: Date) -> [String] {
        DayMarker.markers(for: date, lunar: LunarFormatter.text(for: date, calendar: calendar), calendar: calendar).map(\.name)
    }

    static func main() {
        for year in 2026...2032 {
            for (month, day, name) in [(10, 24, "程序员节"), (10, 31, "万圣节"), (11, 11, "光棍节"), (12, 25, "圣诞节")] {
                let target = date(year, month, day)
                precondition(names(target).contains(name))
                for offset in [-1, 1] {
                    precondition(!names(calendar.date(byAdding: .day, value: offset, to: target)!).contains(name))
                }
            }
        }

        // Check the full range of possible Thanksgiving dates, including leap years.
        for (year, day) in [(2026, 26), (2027, 25), (2028, 23), (2029, 22), (2030, 28), (2031, 27), (2032, 25)] {
            let matches = (1...30).filter { names(date(year, 11, $0)).contains("感恩节") }
            precondition(matches == [day], "Incorrect Thanksgiving date in \(year)")
        }

        // Laba follows the Chinese calendar and crosses Gregorian year boundaries.
        for target in [date(2026, 1, 26), date(2027, 1, 15)] {
            let lunar = LunarFormatter.text(for: target, calendar: calendar)
            precondition(lunar.month == 12 && lunar.day == 8 && !lunar.isLeapMonth)
            precondition(names(target).contains("腊八节"))
            let leap = LunarInfo(month: 12, day: 8, isLeapMonth: true, displayText: "初八")
            precondition(!DayMarker.markers(for: target, lunar: leap, calendar: calendar).contains { $0.name == "腊八节" })
        }
        precondition(!names(date(2026, 12, 8)).contains("腊八节"))
        precondition(names(date(2026, 5, 10)).contains("母亲节"))
        precondition(names(date(2026, 6, 21)).contains("父亲节"))
        print("PASS: fixed festivals, Thanksgiving 2026–2032, lunar Laba, Mother's/Father's Day")
    }
}
