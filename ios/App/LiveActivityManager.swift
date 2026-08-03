import Foundation
import ActivityKit

final class LiveActivityManager {
    static let shared = LiveActivityManager()
    private var currentActivity: Activity<ToiletTimerAttributes>?

    // MARK: - Ruhezeit-Verschiebung (gleiche Logik wie im App-Header)

    static func quietAdjustedDueDate(start: Date, intervalMinutes: Int, settings: AppSettings?) -> Date {
        var dueDate = start.addingTimeInterval(TimeInterval(intervalMinutes * 60))
        guard let settings, settings.quietHoursEnabled else { return dueDate }

        let cal = Calendar.current
        let dueHour = cal.component(.hour, from: dueDate)

        let inQuiet: Bool
        if settings.quietFrom < settings.quietTo {
            inQuiet = dueHour >= settings.quietFrom && dueHour < settings.quietTo
        } else {
            inQuiet = dueHour >= settings.quietFrom || dueHour < settings.quietTo
        }

        if inQuiet {
            var components = cal.dateComponents([.year, .month, .day], from: dueDate)
            components.hour = settings.quietTo
            components.minute = 0
            components.second = 0
            if let quietEnd = cal.date(from: components) {
                dueDate = quietEnd <= dueDate
                    ? cal.date(byAdding: .day, value: 1, to: quietEnd)!
                    : quietEnd
            }
        }
        return dueDate
    }


    /// Übernimmt nur eine wirklich AKTIVE Activity; verwirft beendete/weggewischte.
    private func adoptActiveActivity() {
        if let current = currentActivity, current.activityState == .active || current.activityState == .stale {
            return
        }
        currentActivity = Activity<ToiletTimerAttributes>.activities.first {
            $0.activityState == .active || $0.activityState == .stale
        }
    }

    // MARK: - Start / Update (async: Aufrufer warten, damit Hintergrund-
    // prozesse wie Siri-Intents nicht enden, bevor das Update raus ist)

    func startTimer(from startTime: Date, intervalMinutes: Int, todayMl: Int, todayCount: Int, settings: AppSettings?) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print(">>> LA nicht erlaubt"); return
        }

        let physDue = startTime.addingTimeInterval(TimeInterval(intervalMinutes * 60))
        let shifted = Self.quietAdjustedDueDate(start: startTime, intervalMinutes: intervalMinutes, settings: settings)
        let state = ToiletTimerAttributes.ContentState(
            startTime: startTime,
            intervalMinutes: intervalMinutes,
            todayMl: todayMl,
            todayCount: todayCount,
            dueDate: physDue,
            quietEnd: shifted > physDue ? shifted : nil
        )

        // Nur eine AKTIVE Activity übernehmen. Beendete/weggewischte bleiben
        // in Activity.activities liegen — Updates an sie verpuffen und
        // blockieren sonst jede neue Anfrage.
        adoptActiveActivity()

        if let activity = currentActivity {
            await activity.update(.init(state: state, staleDate: nil))
            return
        }

        do {
            currentActivity = try Activity.request(
                attributes: ToiletTimerAttributes(),
                content: .init(state: state, staleDate: nil),
                pushType: nil
            )
        } catch {
            print("LA START FAILED: \(error)")
        }
    }

    func updateStats(startTime: Date, todayMl: Int, todayCount: Int, intervalMinutes: Int, settings: AppSettings?) async {
        adoptActiveActivity()
        guard let activity = currentActivity else { return }
        let physDue = startTime.addingTimeInterval(TimeInterval(intervalMinutes * 60))
        let shifted = Self.quietAdjustedDueDate(start: startTime, intervalMinutes: intervalMinutes, settings: settings)
        let state = ToiletTimerAttributes.ContentState(
            startTime: startTime,
            intervalMinutes: intervalMinutes,
            todayMl: todayMl,
            todayCount: todayCount,
            dueDate: physDue,
            quietEnd: shifted > physDue ? shifted : nil
        )
        await activity.update(.init(state: state, staleDate: nil))
    }

    func ensureRunning(from startTime: Date, intervalMinutes: Int, todayMl: Int, todayCount: Int, settings: AppSettings?) async {
        adoptActiveActivity()
        if currentActivity == nil {
            await startTimer(from: startTime, intervalMinutes: intervalMinutes,
                             todayMl: todayMl, todayCount: todayCount, settings: settings)
        }
    }

    func stopTimer() async {
        for activity in Activity<ToiletTimerAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        currentActivity = nil
    }
}
