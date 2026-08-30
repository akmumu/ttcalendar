import Foundation

struct CustomSpecialDate: Identifiable, Codable, Hashable {
    let id: UUID
    var year: Int? // 仅一次性日期使用；每年重复的日期不绑定年份
    var month: Int
    var day: Int
    var type: DateType
    var category: DateCategory
    var customLabel: String // 单字标记，如"生"、"会"等
    var name: String // 完整名称，如"小明生日"
    var isYearly: Bool // 是否每年重复

    enum DateType: String, Codable, CaseIterable {
        case birthday = "生日"
        case anniversary = "纪念日"
        case meeting = "会议"
        case custom = "自定义"

        var defaultLabel: String {
            switch self {
            case .birthday: return "生"
            case .anniversary: return "念"
            case .meeting: return "会"
            case .custom: return "特"
            }
        }

        /// 生日、纪念日默认每年重复；会议、自定义默认不重复。
        var defaultIsYearly: Bool {
            switch self {
            case .birthday, .anniversary: return true
            case .meeting, .custom: return false
            }
        }
    }

    enum DateCategory: String, Codable, CaseIterable {
        case work = "工作"
        case life = "生活"
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case year
        case month
        case day
        case type
        case category
        case customLabel
        case name
        case isYearly
    }

    init(id: UUID = UUID(), year: Int? = nil, month: Int, day: Int, type: DateType, category: DateCategory = .life, customLabel: String? = nil, name: String, isYearly: Bool = true) {
        self.id = id
        self.year = isYearly ? nil : year
        self.month = month
        self.day = day
        self.type = type
        self.category = category
        self.customLabel = customLabel ?? type.defaultLabel
        self.name = name
        self.isYearly = isYearly
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        year = try container.decodeIfPresent(Int.self, forKey: .year)
        month = try container.decode(Int.self, forKey: .month)
        day = try container.decode(Int.self, forKey: .day)
        type = try container.decode(DateType.self, forKey: .type)
        category = try container.decodeIfPresent(DateCategory.self, forKey: .category) ?? .life
        customLabel = try container.decode(String.self, forKey: .customLabel)
        name = try container.decode(String.self, forKey: .name)
        isYearly = try container.decode(Bool.self, forKey: .isYearly)
    }

    func matches(month: Int, day: Int) -> Bool {
        self.month == month && self.day == day
    }

    func matches(_ date: Date, calendar: Calendar = .autoupdatingCurrent) -> Bool {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        guard components.month == month, components.day == day else {
            return false
        }

        return isYearly || components.year == year
    }

    func occurrenceDate(calendar: Calendar = .autoupdatingCurrent) -> Date? {
        guard !isYearly, let year else {
            return nil
        }

        return calendar.date(from: DateComponents(year: year, month: month, day: day))
            .map(calendar.startOfDay(for:))
    }

    func nextOccurrence(onOrAfter referenceDate: Date = Date(), calendar: Calendar = .autoupdatingCurrent) -> Date? {
        let startDate = calendar.startOfDay(for: referenceDate)

        if !isYearly {
            return occurrenceDate(calendar: calendar)
        }

        let currentYear = calendar.component(.year, from: startDate)
        for candidateYear in currentYear...(currentYear + 8) {
            guard let candidate = calendar.date(from: DateComponents(year: candidateYear, month: month, day: day)) else {
                continue
            }

            let normalizedCandidate = calendar.startOfDay(for: candidate)
            if normalizedCandidate >= startDate {
                return normalizedCandidate
            }
        }

        return nil
    }

    func isArchived(relativeTo referenceDate: Date = Date(), calendar: Calendar = .autoupdatingCurrent) -> Bool {
        guard !isYearly, let occurrenceDate = occurrenceDate(calendar: calendar) else {
            return false
        }

        return occurrenceDate < calendar.startOfDay(for: referenceDate)
    }

    func resolvingLegacyYear(_ fallbackYear: Int) -> CustomSpecialDate {
        guard !isYearly, year == nil else {
            return self
        }

        var resolved = self
        resolved.year = fallbackYear
        return resolved
    }
}

enum CustomSpecialDateStore {
    static let appGroupIdentifier = "group.akmumu.ttcalendar"
    private static let storeKey = "customSpecialDates"

    static func load() -> [CustomSpecialDate] {
        guard let data = userDefaults.data(forKey: storeKey),
              let dates = try? JSONDecoder().decode([CustomSpecialDate].self, from: data) else {
            return []
        }

        let currentYear = Calendar.autoupdatingCurrent.component(.year, from: Date())
        let resolvedDates = dates.map { $0.resolvingLegacyYear(currentYear) }
        if resolvedDates != dates {
            save(resolvedDates)
        }
        return resolvedDates
    }

    static func save(_ dates: [CustomSpecialDate]) {
        guard let data = try? JSONEncoder().encode(dates) else {
            return
        }
        userDefaults.set(data, forKey: storeKey)
    }

    static func add(_ date: CustomSpecialDate) {
        var dates = load()
        dates.append(date)
        save(dates)
    }

    static func update(_ date: CustomSpecialDate) {
        var dates = load()
        if let index = dates.firstIndex(where: { $0.id == date.id }) {
            dates[index] = date
            save(dates)
        }
    }

    static func delete(_ date: CustomSpecialDate) {
        var dates = load()
        dates.removeAll { $0.id == date.id }
        save(dates)
    }

    static func customDate(
        on date: Date,
        among dates: [CustomSpecialDate]? = nil,
        calendar: Calendar = .autoupdatingCurrent
    ) -> CustomSpecialDate? {
        (dates ?? load()).first { $0.matches(date, calendar: calendar) }
    }

    private static var userDefaults: UserDefaults {
        UserDefaults(suiteName: appGroupIdentifier) ?? .standard
    }
}
