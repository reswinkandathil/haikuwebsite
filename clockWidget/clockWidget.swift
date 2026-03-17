import WidgetKit
import SwiftUI
import EventKit

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        var entries: [SimpleEntry] = []

        // To make it a real clock, we generate a timeline entry for every second
        // Note: iOS heavily batches widget updates. A standard widget won't update every second.
        // But since iOS 14, to make a live-updating clock face in a widget, we must rely on specific 
        // SwiftUI views (like Text(Date(), style: .timer)), OR for custom drawn hands, we provide an entry 
        // per minute, and iOS animates/interpolates it if possible. 
        // However, we will generate the next 60 minutes, updated every minute exactly on the minute mark.
        
        let currentDate = Date()
        let startOfNextMinute = Calendar.current.date(bySetting: .second, value: 0, of: Calendar.current.date(byAdding: .minute, value: 1, to: currentDate)!) ?? currentDate
        
        for minuteOffset in 0 ..< 60 {
            let entryDate = Calendar.current.date(byAdding: .minute, value: minuteOffset, to: startOfNextMinute)!
            let entry = SimpleEntry(date: entryDate)
            entries.append(entry)
        }

        // Tell the system to ask for a new timeline when this one runs out (in an hour)
        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
}

struct clockWidgetEntryView : View {
    var entry: Provider.Entry
    
    // Default to .sage for the widget
    var theme: AppTheme {
        return .sage
    }

    var body: some View {
        // Reusing your highly aesthetic clock!
        StaticClockView(
            now: entry.date,
            tasks: fetchWidgetTasks(),
            is24HourClock: false,
            theme: theme,
            showHands: true,
            showText: true, // Show the numbers around the clock
            showCenterText: false // Hide the digital time and focus time in the middle for the widget
        )
        .padding(12)
    }
    
    // Fetch today's tasks directly from EventKit so they show on the widget automatically
    private func fetchWidgetTasks() -> [ClockTask] {
        let manager = CalendarManager()
        // Check if we actually have permission. In widgets, we can't prompt, we just have to check.
        let status = EKEventStore.authorizationStatus(for: .event)
        
        if status == .authorized || status == .fullAccess {
            return manager.fetchEvents(for: Date(), theme: theme)
        } else {
            // If the main app hasn't gotten permission yet, return nothing.
            return []
        }
    }
}

struct clockWidget: Widget {
    let kind: String = "clockWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(iOS 17.0, *) {
                clockWidgetEntryView(entry: entry)
                    .containerBackground(for: .widget) {
                        AppTheme.sage.bg
                    }
            } else {
                clockWidgetEntryView(entry: entry)
                    .background(AppTheme.sage.bg)
            }
        }
        .configurationDisplayName("Aesthetic Clock")
        .description("Your beautifully minimal clock, right on your home screen.")
        .supportedFamilies([.systemSmall, .systemLarge])
    }
}
