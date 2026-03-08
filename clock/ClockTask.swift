//
//  ClockTask.swift
//  clock
//
//  Defines the task/meeting model for the clock agenda.
//

import SwiftUI

/// A simple model representing a task/meeting on a clock.
/// Times are in minutes from midnight (0...1440). For a 12-hour clock, values wrap every 720 minutes.
struct ClockTask: Identifiable, Hashable {
    let id = UUID()
    var title: String
    var startMinutes: Int   // minutes from midnight
    var endMinutes: Int     // minutes from midnight
    var color: Color
    var isCompleted: Bool = false
    var url: URL? = nil

    /// A computed emoji based on the task title
    var emoji: String {
        let t = title.lowercased()
        if t.contains("work") || t.contains("code") || t.contains("study") { return "💻" }
        if t.contains("meet") || t.contains("call") || t.contains("sync") { return "👥" }
        if t.contains("eat") || t.contains("lunch") || t.contains("dinner") || t.contains("matcha") { return "🍵" }
        if t.contains("walk") || t.contains("run") || t.contains("gym") || t.contains("workout") { return "🏃" }
        if t.contains("read") || t.contains("book") { return "📚" }
        if t.contains("admin") || t.contains("email") { return "📥" }
        return "✨"
    }

    /// Normalize to 12h range in minutes [0, 720)
    var start12h: Double { Double(startMinutes % 720) }
    var end12h: Double { Double(endMinutes % 720) }
}
