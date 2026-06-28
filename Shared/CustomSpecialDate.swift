import Foundation

struct CustomSpecialDate: Identifiable, Codable, Hashable {
    let id: UUID
    var month: Int
    var day: Int
    var type: DateType
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

    init(id: UUID = UUID(), month: Int, day: Int, type: DateType, customLabel: String? = nil, name: String, isYearly: Bool = true) {
        self.id = id
        self.month = month
        self.day = day
        self.type = type
        self.customLabel = customLabel ?? type.defaultLabel
        self.name = name
        self.isYearly = isYearly
    }

    func matches(month: Int, day: Int) -> Bool {
        self.month == month && self.day == day
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
        return dates
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

    static func customDate(for month: Int, day: Int) -> CustomSpecialDate? {
        load().first { $0.matches(month: month, day: day) }
    }

    private static var userDefaults: UserDefaults {
        UserDefaults(suiteName: appGroupIdentifier) ?? .standard
    }
}
