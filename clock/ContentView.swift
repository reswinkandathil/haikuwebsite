import SwiftUI
internal import Combine

struct ContentView: View {
    @State private var now = Date()
    private let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    @State private var tasks: [ClockTask] = [
        ClockTask(title: "Matcha Tasting", startMinutes: 14*60, endMinutes: 15*60, color: Color(red: 0.85, green: 0.78, blue: 0.58)), // Gold
        ClockTask(title: "Garden Walk", startMinutes: 16*60, endMinutes: 17*60 + 30, color: Color(red: 0.75, green: 0.55, blue: 0.45)) // Muted Terracotta
    ]

    private let bgColor = Color(red: 0.18, green: 0.23, blue: 0.18) // Muted Sage Green
    private let goldColor = Color(red: 0.85, green: 0.78, blue: 0.58)

    enum Tab {
        case clock, week, today, profile
    }
    @State private var selectedTab: Tab = .clock
    @State private var showingAddTask = false

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 4) {
                    Text("HAIKU")
                        .font(.system(size: 26, weight: .regular, design: .serif))
                        .foregroundStyle(goldColor)
                        .tracking(2)

                    HStack {
                        Spacer()
                        Text(currentMonthYear())
                            .font(.system(size: 14, weight: .light, design: .serif))
                            .foregroundStyle(.white.opacity(0.7))
                        
                        Button(action: { showingAddTask = true }) {
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(goldColor)
                        }
                        .padding(.leading, 8)
                    }
                    .padding(.horizontal, 40)
                }
                .padding(.top, 20)

                Spacer()

                // Content Views
                Group {
                    if selectedTab == .clock {
                        clockContentView()
                    } else if selectedTab == .week {
                        Text("Week View").font(.title).foregroundStyle(goldColor)
                    } else if selectedTab == .today {
                        Text("Today's Agenda").font(.title).foregroundStyle(goldColor)
                    } else if selectedTab == .profile {
                        Text("User Profile").font(.title).foregroundStyle(goldColor)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                Spacer()

                // Bottom Tab Bar
                HStack {
                    TabBarButton(icon: "clock.fill", text: "Clock", isSelected: selectedTab == .clock) {
                        selectedTab = .clock
                    }
                    Spacer()
                    TabBarButton(icon: "calendar", text: "Week", isSelected: selectedTab == .week) {
                        selectedTab = .week
                    }
                    Spacer()
                    TabBarButton(icon: "calendar.day.timeline.left", text: "Today", isSelected: selectedTab == .today) {
                        selectedTab = .today
                    }
                    Spacer()
                    TabBarButton(icon: "person.fill", text: "Profile", isSelected: selectedTab == .profile) {
                        selectedTab = .profile
                    }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 20)
                .foregroundStyle(.white.opacity(0.6))
            }
        }
        .onReceive(timer) { date in
            now = date
        }
        .sheet(isPresented: $showingAddTask) {
            AddTaskView(tasks: $tasks)
        }
    }

    @ViewBuilder
    private func clockContentView() -> some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: 20)
                
            // Clock
            ClockView(now: now, tasks: $tasks)
                .frame(width: 280, height: 280)

            Spacer()
                .frame(height: 50)

            // Task List
            List {
                ForEach(tasks) { task in
                    TaskRow(time: formatTime(minutes: task.startMinutes), title: task.title, color: task.color)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 14, leading: 40, bottom: 14, trailing: 40))
                        .listRowSeparator(.hidden)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                if let index = tasks.firstIndex(where: { $0.id == task.id }) {
                                    withAnimation {
                                        tasks.remove(at: index)
                                    }
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            
            Spacer()
        }
    }

    private func currentMonthYear() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: now)
    }

    private func formatTime(minutes: Int) -> String {
        let m = minutes % (24 * 60)
        let h = m / 60
        let min = m % 60
        var comps = DateComponents()
        comps.hour = h
        comps.minute = min
        let date = Calendar.current.date(from: comps) ?? Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

struct AddTaskView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var tasks: [ClockTask]
    
    @State private var title = ""
    @State private var startTime = Date()
    @State private var endTime = Date().addingTimeInterval(3600)
    
    private let bgColor = Color(red: 0.18, green: 0.23, blue: 0.18) // Muted Sage Green
    private let fieldBgColor = Color(red: 0.15, green: 0.20, blue: 0.15)
    private let goldColor = Color(red: 0.85, green: 0.78, blue: 0.58)
    private let shadowLight = Color(red: 0.22, green: 0.28, blue: 0.22)
    private let shadowDark = Color(red: 0.12, green: 0.16, blue: 0.12)
    
    private let themeColors: [Color] = [
        Color(red: 0.85, green: 0.78, blue: 0.58), // Gold
        Color(red: 0.75, green: 0.55, blue: 0.45), // Muted Terracotta
        Color(red: 0.45, green: 0.50, blue: 0.35), // Olive
        Color(red: 0.80, green: 0.72, blue: 0.60), // Soft Sand
        Color(red: 0.35, green: 0.42, blue: 0.35)  // Pale Mint
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                bgColor.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        
                        // Title Input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("TASK NAME")
                                .font(.system(size: 12, weight: .regular, design: .serif))
                                .foregroundStyle(goldColor)
                                .tracking(1)
                            
                            TextField("Enter title...", text: $title)
                                .font(.system(size: 16, weight: .regular))
                                .foregroundStyle(.white)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(fieldBgColor)
                                        .shadow(color: shadowDark, radius: 5, x: 4, y: 4)
                                        .shadow(color: shadowLight, radius: 5, x: -4, y: -4)
                                )
                        }
                        
                        // Time Selection
                        VStack(alignment: .leading, spacing: 8) {
                            Text("SCHEDULE")
                                .font(.system(size: 12, weight: .regular, design: .serif))
                                .foregroundStyle(goldColor)
                                .tracking(1)
                            
                            VStack(spacing: 0) {
                                DatePicker("Start", selection: $startTime, displayedComponents: .hourAndMinute)
                                    .padding()
                                    .foregroundStyle(.white.opacity(0.9))
                                
                                Rectangle()
                                    .fill(Color.white.opacity(0.1))
                                    .frame(height: 1)
                                    .padding(.horizontal)
                                
                                DatePicker("End", selection: $endTime, displayedComponents: .hourAndMinute)
                                    .padding()
                                    .foregroundStyle(.white.opacity(0.9))
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(fieldBgColor)
                                    .shadow(color: shadowDark, radius: 5, x: 4, y: 4)
                                    .shadow(color: shadowLight, radius: 5, x: -4, y: -4)
                            )
                        }
                        
                        // Add Button
                        Button(action: saveTask) {
                            Text("Add to Agenda")
                                .font(.system(size: 16, weight: .medium, design: .serif))
                                .foregroundStyle(bgColor)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(goldColor)
                                        .shadow(color: .black.opacity(0.3), radius: 5, x: 2, y: 4)
                                )
                        }
                        .padding(.top, 16)
                    }
                    .padding(32)
                }
            }
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(bgColor, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .font(.system(size: 16, design: .serif))
                        .foregroundStyle(goldColor)
                }
            }
        }
        .preferredColorScheme(.dark) // Keeps picker popups dark
    }
    
    private func saveTask() {
        let cal = Calendar.current
        let sComps = cal.dateComponents([.hour, .minute], from: startTime)
        let eComps = cal.dateComponents([.hour, .minute], from: endTime)
        let sMin = (sComps.hour ?? 0) * 60 + (sComps.minute ?? 0)
        let eMin = (eComps.hour ?? 0) * 60 + (eComps.minute ?? 0)
        
        let nextColor = themeColors[tasks.count % themeColors.count]
        
        let newTask = ClockTask(
            title: title.isEmpty ? "New Task" : title,
            startMinutes: sMin,
            endMinutes: eMin,
            color: nextColor
        )
        tasks.append(newTask)
        tasks.sort { $0.startMinutes < $1.startMinutes }
        dismiss()
    }
}

struct TaskRow: View {
    var time: String
    var title: String
    var color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            Text(time)
                .font(.system(size: 14, weight: .light))
                .foregroundStyle(.white.opacity(0.6))
                .frame(width: 60, alignment: .leading)
            
            // Vertical separator
            Rectangle()
                .fill(.white.opacity(0.3))
                .frame(width: 1, height: 16)
            
            // Colored Leaf icon
            Image(systemName: "leaf.fill")
                .font(.system(size: 14))
                .foregroundStyle(color)
            
            Text(title)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(.white.opacity(0.9))
            
            Spacer()
        }
    }
}

struct TabBarButton: View {
    var icon: String
    var text: String
    var isSelected: Bool
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.5))
                Text(text)
                    .font(.system(size: 10))
                    .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.5))
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ContentView()
}
