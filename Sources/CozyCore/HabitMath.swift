import Foundation

public enum HabitMath {
    public static func normalizedCompletionKeys(_ keys: String) -> Set<String> {
        Set(
            keys
                .split(whereSeparator: { $0 == "\n" || $0 == "," || $0 == " " })
                .map(String.init)
                .filter { !$0.isEmpty }
        )
    }

    public static func completionKeysString(_ keys: Set<String>) -> String {
        keys.sorted().joined(separator: "\n")
    }

    public static func toggleCompletion(
        keys: String,
        on date: Date,
        calendar: Calendar = CozyCalendar.shared
    ) -> String {
        var set = normalizedCompletionKeys(keys)
        let key = CozyCalendar.dayKey(date, calendar: calendar)
        if set.contains(key) {
            set.remove(key)
        } else {
            set.insert(key)
        }
        return completionKeysString(set)
    }

    public static func isComplete(
        keys: String,
        on date: Date,
        calendar: Calendar = CozyCalendar.shared
    ) -> Bool {
        normalizedCompletionKeys(keys).contains(CozyCalendar.dayKey(date, calendar: calendar))
    }

    public static func currentStreak(
        keys: String,
        through date: Date,
        graceDays: Int = 1,
        calendar: Calendar = CozyCalendar.shared
    ) -> Int {
        let set = normalizedCompletionKeys(keys)
        var streak = 0
        var graceRemaining = max(0, graceDays)
        var cursor = calendar.startOfDay(for: date)

        while true {
            let key = CozyCalendar.dayKey(cursor, calendar: calendar)
            if set.contains(key) {
                streak += 1
            } else if streak == 0 {
                // Today can be incomplete without losing an existing streak.
                graceRemaining -= 1
                if graceRemaining < 0 { break }
            } else if graceRemaining > 0 {
                graceRemaining -= 1
            } else {
                break
            }

            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else {
                break
            }
            cursor = previous
        }

        return streak
    }

    public static func completionsInCurrentWeek(
        keys: String,
        now: Date,
        calendar: Calendar = CozyCalendar.shared
    ) -> Int {
        let set = normalizedCompletionKeys(keys)
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now) else {
            return 0
        }

        return set.compactMap { CozyCalendar.date(fromDayKey: $0, calendar: calendar) }
            .filter { weekInterval.contains($0) }
            .count
    }
}
