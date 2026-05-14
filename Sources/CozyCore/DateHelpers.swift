import Foundation

public enum CozyCalendar {
    public static let shared = Calendar.autoupdatingCurrent

    public static func startOfDay(_ date: Date, calendar: Calendar = shared) -> Date {
        calendar.startOfDay(for: date)
    }

    public static func isToday(_ date: Date?, now: Date = Date(), calendar: Calendar = shared) -> Bool {
        guard let date else { return false }
        return calendar.isDate(date, inSameDayAs: now)
    }

    public static func isUpcoming(_ date: Date?, now: Date = Date(), calendar: Calendar = shared) -> Bool {
        guard let date else { return false }
        return date >= calendar.startOfDay(for: now)
    }

    public static func dayKey(_ date: Date, calendar: Calendar = shared) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }

    public static func date(fromDayKey key: String, calendar: Calendar = shared) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }
}
