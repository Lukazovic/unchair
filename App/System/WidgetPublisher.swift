import UnchairCore
import WidgetKit

/// Shares the current state with the widget extension and asks widgets to
/// refresh only when something they show changed.
final class WidgetPublisher {
    private var lastPublished: WidgetSnapshot?

    func publish(_ snapshot: WidgetSnapshot) {
        var comparable = snapshot
        comparable.updatedAt = .distantPast
        guard comparable != lastPublished else { return }
        lastPublished = comparable
        snapshot.save()
        WidgetCenter.shared.reloadAllTimelines()
    }
}
