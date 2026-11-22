#if DEBUG
    import Foundation
    import UnchairCore

    extension HistoryStore {
        /// The store to use at launch. Pass `-UnchairSampleData` (Debug builds
        /// only) to explore the app with a month of in-memory sample history
        /// that never touches your real data.
        static func forLaunch() -> HistoryStore {
            CommandLine.arguments.contains("-UnchairSampleData") ? sample() : HistoryStore()
        }

        /// A month of plausible, deterministic history.
        static func sample(now: Date = .now, calendar: Calendar = .current) -> HistoryStore {
            let store = HistoryStore(inMemory: true)
            let today = calendar.startOfDay(for: now)
            for offset in 1 ..< 31 {
                guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
                func at(_ hour: Double) -> Date {
                    day.addingTimeInterval(hour * 3600)
                }
                let weekday = calendar.component(.weekday, from: day)
                guard weekday != 1, weekday != 7 else { continue }

                for session in 0 ..< 2 + (offset * 7) % 5 {
                    store.recordFocusSession(FocusSession(end: at(9.5 + Double(session) * 0.6), duration: 25 * 60))
                }
                for glass in 0 ..< 4 + (offset * 3) % 6 {
                    store.recordWater(250, at: at(9 + Double(glass)))
                }
                store.recordPresence(.sitting, at: at(9))
                store.recordPresence(.standing, at: at(10))
                store.recordPresence(.sitting, at: at(10 + Double(15 + (offset * 11) % 40) / 60))
                store.recordPresence(.standing, at: at(15))
                store.recordPresence(.sitting, at: at(15.25))
                store.recordPresence(.away, at: at(18))
            }
            return store
        }
    }
#endif
