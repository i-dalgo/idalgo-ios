import Foundation

/// Jours et heures du Score Center, dans le fuseau du jour affiché.
package enum ScoreCenterFormat {
    /// « Aujourd'hui », « Hier », « Demain », sinon « dimanche 8 novembre ».
    package static func dayLabel(_ date: String, now: Date, timeZone: TimeZone) -> String {
        relativeDayLabel(date, now: now, timeZone: timeZone) ?? longDay(date) ?? date
    }

    /// « Aujourd'hui », « Hier » ou « Demain » ; `nil` pour un autre jour.
    package static func relativeDayLabel(_ date: String, now: Date, timeZone: TimeZone) -> String? {
        let calendar = calendar(timeZone)
        let labels = [(-1, IdalgoStrings.yesterday), (0, IdalgoStrings.today), (1, IdalgoStrings.tomorrow)]
        for (offset, label) in labels {
            guard let day = calendar.date(byAdding: .day, value: offset, to: now) else { continue }
            if calendarDate(day, calendar: calendar) == date { return label }
        }
        return nil
    }

    /// « dimanche 8 novembre » pour un jour du calendrier (`AAAA-MM-JJ`).
    package static func longDay(_ date: String) -> String? {
        let parts = date.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, (1...12).contains(parts[1]) else { return nil }
        let utc = calendar(TimeZone(identifier: "UTC")!)
        guard let noon = utc.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12))
        else { return nil }
        let weekday = IdalgoStrings.weekdays[utc.component(.weekday, from: noon) - 1]
        let day = parts[2] == 1 ? "1er" : String(parts[2])
        return "\(weekday) \(day) \(IdalgoStrings.months[parts[1] - 1])"
    }

    /// Jour du calendrier (`AAAA-MM-JJ`) d'un instant dans un fuseau.
    package static func calendarDate(_ date: Date, timeZone: TimeZone) -> String {
        calendarDate(date, calendar: calendar(timeZone))
    }

    /// Heure d'un instant dans un fuseau : « 21:45 ».
    package static func time(_ date: Date, timeZone: TimeZone) -> String {
        let parts = calendar(timeZone).dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
    }

    /// Heure lue par VoiceOver : « à 21 h 45 ».
    static func spokenTime(_ date: Date, timeZone: TimeZone) -> String {
        let parts = calendar(timeZone).dateComponents([.hour, .minute], from: date)
        return IdalgoStrings.kickoffSpoken(hour: parts.hour ?? 0, minute: parts.minute ?? 0)
    }

    private static func calendarDate(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    private static func calendar(_ timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }
}
