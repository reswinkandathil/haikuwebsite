import SwiftUI

struct YearlyView: View {
    @AppStorage("appTheme") private var currentTheme: AppTheme = .sage
    @AppStorage("is24HourClock") private var is24HourClock = false
    
    var tasksByDate: [Date: [ClockTask]]
    @Binding var selectedDate: Date
    @Binding var selectedTab: ContentView.Tab
    
    @State private var displayMonth: Date = {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: Date())
        return cal.date(from: comps) ?? Date()
    }()
    
    private let daysOfWeek = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    
    var body: some View {
        VStack(spacing: 20) {
            // Header for month/year
            HStack(spacing: 20) {
                Button(action: { changeMonth(by: -1) }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(currentTheme.accent.opacity(0.8))
                }
                
                Text(monthYearString(from: displayMonth))
                    .font(.system(size: 20, weight: .medium, design: .serif))
                    .foregroundStyle(currentTheme.accent)
                    .frame(minWidth: 160)
                    .id(displayMonth)
                    .transition(.opacity)
                
                Button(action: { changeMonth(by: 1) }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .rotationEffect(.degrees(180))
                        .foregroundStyle(currentTheme.accent.opacity(0.8))
                }
            }
            .padding(.top, 40)
            
            // Days of week header
            HStack {
                ForEach(daysOfWeek, id: \.self) { day in
                    Text(day)
                        .font(.system(size: 12, weight: .light))
                        .foregroundStyle(currentTheme.textForeground.opacity(0.5))
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 16)
            
            // Grid of mini clocks
            let days = getDaysInMonth()
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 16) {
                ForEach(0..<days.count, id: \.self) { index in
                    if let date = days[index] {
                        let tasks = tasksByDate[date, default: []]
                        let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
                        
                        VStack(spacing: 4) {
                            StaticClockView(now: Date(), tasks: tasks, is24HourClock: is24HourClock, theme: currentTheme, showHands: false, showText: false)
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Circle()
                                        .stroke(isSelected ? currentTheme.accent : Color.clear, lineWidth: 2)
                                        .padding(-4)
                                )
                                .onTapGesture {
                                    withAnimation {
                                        selectedDate = date
                                        selectedTab = .clock
                                    }
                                }
                            
                            Text("\(Calendar.current.component(.day, from: date))")
                                .font(.system(size: 10, weight: isSelected ? .bold : .medium))
                                .foregroundStyle(currentTheme.textForeground.opacity(isSelected ? 1.0 : 0.8))
                        }
                    } else {
                        Color.clear.frame(width: 36, height: 36)
                    }
                }
            }
            .padding(.horizontal, 16)
            .id(displayMonth)
            .transition(.asymmetric(insertion: .opacity, removal: .opacity))
            
            Spacer()
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 40)
                .onEnded { value in
                    if abs(value.translation.width) > abs(value.translation.height) {
                        if value.translation.width < 0 {
                            changeMonth(by: 1)
                        } else if value.translation.width > 0 {
                            changeMonth(by: -1)
                        }
                    }
                }
        )
    }
    
    private func changeMonth(by months: Int) {
        withAnimation(.easeInOut(duration: 0.3)) {
            if let newMonth = Calendar.current.date(byAdding: .month, value: months, to: displayMonth) {
                displayMonth = newMonth
            }
        }
    }
    
    private func monthYearString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
    
    private func getDaysInMonth() -> [Date?] {
        var days: [Date?] = []
        let cal = Calendar.current
        guard let monthRange = cal.range(of: .day, in: .month, for: displayMonth),
              let firstDayOfMonth = cal.date(from: cal.dateComponents([.year, .month], from: displayMonth)) else {
            return []
        }
        
        let firstWeekday = cal.component(.weekday, from: firstDayOfMonth)
        for _ in 1..<firstWeekday {
            days.append(nil)
        }
        
        for day in 1...monthRange.count {
            if let date = cal.date(byAdding: .day, value: day - 1, to: firstDayOfMonth) {
                days.append(cal.startOfDay(for: date))
            }
        }
        
        return days
    }
}
