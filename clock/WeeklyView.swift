import SwiftUI

struct WeeklyView: View {
    @AppStorage("appTheme") private var currentTheme: AppTheme = .sage
    @AppStorage("is24HourClock") private var is24HourClock = false
    
    var tasksByDate: [Date: [ClockTask]]
    @Binding var selectedDate: Date
    @Binding var selectedTab: ContentView.Tab
    
    @State private var displayWeek: Date = {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let weekday = cal.component(.weekday, from: today)
        return cal.date(byAdding: .day, value: 1 - weekday, to: today) ?? today
    }()
    
    private let daysOfWeek = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header for week range
            HStack {
                Button(action: { changeWeek(by: -7) }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(currentTheme.accent)
                        .padding(12)
                        .background(Circle().fill(currentTheme.fieldBg))
                }
                
                Spacer()
                
                Text(weekRangeString(from: displayWeek))
                    .font(.system(size: 22, weight: .semibold, design: .serif))
                    .foregroundStyle(currentTheme.accent)
                    .id(displayWeek)
                    .transition(.opacity)
                
                Spacer()
                
                Button(action: { changeWeek(by: 7) }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(currentTheme.accent)
                        .padding(12)
                        .background(Circle().fill(currentTheme.fieldBg))
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 40)
            .padding(.bottom, 30)
            
            // Grid of Large Clocks
            ScrollView {
                VStack(spacing: 32) {
                    let days = getDaysInWeek()
                    // 2 columns of 3, then 1 centered? Or just 1 large list? 
                    // Let's go with 1 large column to make them "big enough to see writing"
                    ForEach(0..<days.count, id: \.self) { index in
                        if let date = days[index] {
                            let tasks = tasksByDate[date, default: []]
                            let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
                            let dayName = daysOfWeek[index]
                            let dayNum = Calendar.current.component(.day, from: date)
                            
                            HStack(spacing: 24) {
                                // Left side: Day info
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(dayName)
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(isSelected ? currentTheme.accent : currentTheme.textForeground.opacity(0.4))
                                    Text("\(dayNum)")
                                        .font(.system(size: 32, weight: .light, design: .serif))
                                        .foregroundStyle(isSelected ? currentTheme.textForeground : currentTheme.textForeground.opacity(0.8))
                                }
                                .frame(width: 60, alignment: .leading)
                                
                                // Right side: Big Clock with tasks
                                ZStack {
                                    StaticClockView(now: Date(), tasks: tasks, is24HourClock: is24HourClock, theme: currentTheme, showHands: true, showText: true)
                                        .frame(width: 140, height: 140)
                                        .background(
                                            Circle()
                                                .fill(currentTheme.fieldBg)
                                                .shadow(color: currentTheme.shadowDark, radius: 10, x: 6, y: 6)
                                                .shadow(color: currentTheme.shadowLight, radius: 10, x: -6, y: -6)
                                        )
                                        .overlay(
                                            Circle()
                                                .stroke(isSelected ? currentTheme.accent : Color.clear, lineWidth: 3)
                                                .padding(-8)
                                        )
                                    
                                    // Task list summary next to it or overlay? 
                                    // Let's put a small vertical list of tasks next to the clock
                                }
                                .onTapGesture {
                                    withAnimation {
                                        selectedDate = date
                                        selectedTab = .clock
                                    }
                                }
                                
                                // Task summary
                                VStack(alignment: .leading, spacing: 6) {
                                    if tasks.isEmpty {
                                        Text("No tasks")
                                            .font(.system(size: 12, weight: .light))
                                            .foregroundStyle(currentTheme.textForeground.opacity(0.3))
                                    } else {
                                        ForEach(tasks.prefix(3)) { task in
                                            HStack(spacing: 6) {
                                                Circle()
                                                    .fill(task.color)
                                                    .frame(width: 6, height: 6)
                                                Text(task.title)
                                                    .font(.system(size: 12, weight: .medium))
                                                    .foregroundStyle(currentTheme.textForeground.opacity(0.8))
                                                    .lineLimit(1)
                                            }
                                        }
                                        if tasks.count > 3 {
                                            Text("+ \(tasks.count - 3) more")
                                                .font(.system(size: 10, weight: .light))
                                                .foregroundStyle(currentTheme.textForeground.opacity(0.4))
                                        }
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.vertical, 16)
                            .padding(.horizontal, 24)
                            .background(
                                RoundedRectangle(cornerRadius: 24)
                                    .fill(isSelected ? currentTheme.fieldBg.opacity(0.5) : Color.clear)
                            )
                        }
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .id(displayWeek)
        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
    }
    
    private func changeWeek(by days: Int) {
        withAnimation(.easeInOut(duration: 0.3)) {
            if let newWeek = Calendar.current.date(byAdding: .day, value: days, to: displayWeek) {
                displayWeek = newWeek
            }
        }
    }
    
    private func weekRangeString(from date: Date) -> String {
        let cal = Calendar.current
        let endDate = cal.date(byAdding: .day, value: 6, to: date) ?? date
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        
        let startStr = formatter.string(from: date)
        let endStr = formatter.string(from: endDate)
        
        formatter.dateFormat = "yyyy"
        let yearStr = formatter.string(from: endDate)
        
        return "\(startStr) - \(endStr)"
    }
    
    private func getDaysInWeek() -> [Date?] {
        var days: [Date?] = []
        let cal = Calendar.current
        for i in 0..<7 {
            if let date = cal.date(byAdding: .day, value: i, to: displayWeek) {
                days.append(cal.startOfDay(for: date))
            }
        }
        return days
    }
}
