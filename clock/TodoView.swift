import SwiftUI

struct TodoView: View {
    @AppStorage("appTheme") private var currentTheme: AppTheme = .sage
    @StateObject private var brainDumpManager = BrainDumpManager()
    @State private var newTaskTitle: String = ""
    @FocusState private var isFocused: Bool
    @State private var showingBulkImport = false
    
    enum Filter: String, CaseIterable {
        case active = "Inbox"
        case completed = "Done"
    }
    @State private var selectedFilter: Filter = .active
    
    enum DoneFilter: String, CaseIterable {
        case all = "All"
        case daily = "Daily"
        case weekly = "Weekly"
    }
    @State private var selectedDoneFilter: DoneFilter = .all
    
    @State private var taskJustCompletedIds = Set<UUID>()
    
    @State private var showingClearAlert = false
    
    // Selection for scheduling
    @State private var isSelectionMode = false
    @State private var selectedTaskIds = Set<UUID>()
    
    var onSchedule: (String, UUID) -> Void
    
    private var bgColor: Color { currentTheme.bg }
    private var goldColor: Color { currentTheme.accent }

    var filteredTasks: [BrainDumpTask] {
        switch selectedFilter {
        case .active:
            return brainDumpManager.tasks.filter { !$0.isCompleted || taskJustCompletedIds.contains($0.id) }
        case .completed:
            let completed = brainDumpManager.tasks.filter { $0.isCompleted && !taskJustCompletedIds.contains($0.id) }
            let cal = Calendar.current
            let now = Date()
            
            switch selectedDoneFilter {
            case .all:
                // Show everything older than this week
                return completed.filter { task in
                    guard let date = task.completedDate else { return false }
                    return !cal.isDate(date, equalTo: now, toGranularity: .weekOfYear) ||
                           !cal.isDate(date, equalTo: now, toGranularity: .yearForWeekOfYear)
                }
            case .daily:
                // Show only today
                return completed.filter { task in
                    guard let date = task.completedDate else { return false }
                    return cal.isDateInToday(date)
                }
            case .weekly:
                // Show this week, but exclude today (so they "moved" here)
                return completed.filter { task in
                    guard let date = task.completedDate else { return false }
                    let isThisWeek = cal.isDate(date, equalTo: now, toGranularity: .weekOfYear) &&
                                     cal.isDate(date, equalTo: now, toGranularity: .yearForWeekOfYear)
                    return isThisWeek && !cal.isDateInToday(date)
                }
            }
        }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                Text("BRAIN DUMP")
                    .font(.system(size: 14, weight: .regular, design: .serif))
                    .foregroundStyle(goldColor)
                    .tracking(2)
                    .padding(.top, 40)
                    .padding(.bottom, 24)

                // Main Filter Picker (Inbox / Done)
                HStack(spacing: 0) {
                    ForEach(Filter.allCases, id: \.self) { filter in
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedFilter = filter
                            }
                        }) {
                            VStack(spacing: 8) {
                                Text(filter.rawValue.uppercased())
                                    .font(.system(size: 12, weight: .medium, design: .serif))
                                    .foregroundStyle(selectedFilter == filter ? goldColor : (currentTheme.textForeground.opacity(0.4) as Color))
                                    .tracking(1)
                                
                                Rectangle()
                                    .fill(selectedFilter == filter ? goldColor : (SwiftUI.Color.clear.opacity(0.001) as Color))
                                    .frame(height: 2)
                                    .frame(width: 40)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 12)

                // Sub-Filter for Done tab
                if selectedFilter == .completed {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(DoneFilter.allCases, id: \.self) { df in
                                Button(action: {
                                    AnalyticsManager.shared.capture("brain_dump_done_filter_changed", properties: ["filter": df.rawValue])
                                    withAnimation(.snappy) {
                                        selectedDoneFilter = df
                                    }
                                }) {                                    Text(df.rawValue.uppercased())
                                        .font(.system(size: 10, weight: selectedDoneFilter == df ? .bold : .medium, design: .serif))
                                        .foregroundStyle(selectedDoneFilter == df ? goldColor : currentTheme.textForeground.opacity(0.4))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(
                                            ZStack {
                                                Capsule()
                                                    .fill(selectedDoneFilter == df ? goldColor.opacity(0.1) : Color.clear)
                                                Capsule()
                                                    .stroke(selectedDoneFilter == df ? goldColor.opacity(0.3) : currentTheme.textForeground.opacity(0.1), lineWidth: 1)
                                            }
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                            
                            if !filteredTasks.isEmpty {
                                Rectangle()
                                    .fill(currentTheme.textForeground.opacity(0.1))
                                    .frame(width: 1, height: 20)
                                    .padding(.horizontal, 4)
                                
                                Button(action: { showingClearAlert = true }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "trash")
                                            .font(.system(size: 10))
                                        Text("CLEAR")
                                            .font(.system(size: 10, weight: .bold, design: .serif))
                                    }
                                    .foregroundStyle(Color.red.opacity(0.7))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule()
                                            .stroke(Color.red.opacity(0.2), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 40)
                    }
                    .padding(.bottom, 20)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                if !isSelectionMode && selectedFilter == .active {
                    // Quick Add Input
                    HStack(spacing: 12) {
                        TextField("Quick task...", text: $newTaskTitle)
                            .font(.system(size: 16, weight: .regular))
                            .foregroundStyle(currentTheme.textForeground)
                            .tint(goldColor)
                            .focused($isFocused)
                            .submitLabel(.done)
                            .onSubmit {
                                addTask()
                            }
                        
                        Button(action: { showingBulkImport = true }) {
                            Image(systemName: "text.badge.plus")
                                .font(.system(size: 22))
                                .foregroundStyle(goldColor)
                        }

                        Button(action: addTask) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(newTaskTitle.isEmpty ? (currentTheme.textForeground.opacity(0.3) as Color) : goldColor)
                        }
                        .disabled(newTaskTitle.isEmpty)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(currentTheme.fieldBg)
                    )
                    .padding(.horizontal, 40)
                    .padding(.bottom, 20)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                if filteredTasks.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: selectedFilter == .active ? "brain.head.profile" : "checkmark.seal")
                            .font(.system(size: 32))
                            .foregroundStyle(goldColor.opacity(0.5) as Color)
                        Text(selectedFilter == .active ? "Clear your mind" : "No tasks in \(selectedDoneFilter.rawValue)")
                            .font(.system(size: 14, weight: .light))
                            .foregroundStyle(currentTheme.textForeground.opacity(0.5) as Color)
                    }
                    Spacer()
                } else {
                    List {
                        ForEach(filteredTasks) { task in
                            BrainDumpRow(
                                title: task.title,
                                isCompleted: task.isCompleted,
                                scheduledDate: task.scheduledDate,
                                completedDate: task.completedDate,
                                isSelected: selectedTaskIds.contains(task.id),
                                isSelectionMode: isSelectionMode,
                                onToggle: {
                                    if isSelectionMode {
                                        if selectedTaskIds.contains(task.id) {
                                            selectedTaskIds.remove(task.id)
                                        } else {
                                            selectedTaskIds.insert(task.id)
                                        }
                                    } else {
                                        if let index = brainDumpManager.tasks.firstIndex(where: { $0.id == task.id }) {
                                            let wasCompleted = brainDumpManager.tasks[index].isCompleted
                                            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                                brainDumpManager.tasks[index].isCompleted.toggle()
                                                if brainDumpManager.tasks[index].isCompleted {
                                                    brainDumpManager.tasks[index].completedDate = Date()
                                                } else {
                                                    brainDumpManager.tasks[index].completedDate = nil
                                                }
                                            }
                                            
                                            let nowCompleted = brainDumpManager.tasks[index].isCompleted
                                            
                                            if !wasCompleted && nowCompleted {
                                                // Task was just marked as completed
                                                AnalyticsManager.shared.capture("brain_dump_task_completed")
                                                taskJustCompletedIds.insert(task.id) 
                                                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                                                
                                                // After 1.2s, move it to the completed list (remove from the active view)
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                                        _ = taskJustCompletedIds.remove(task.id)
                                                    }
                                                }
                                            } else if wasCompleted && !nowCompleted {
                                                // Task was marked as active again
                                                AnalyticsManager.shared.capture("brain_dump_task_reactivated")
                                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                            }
                                        }
                                    }
                                }
                            )
                            .listRowBackground(SwiftUI.Color.clear.opacity(0.001) as Color)
                            .listRowInsets(EdgeInsets(top: 14, leading: 40, bottom: 14, trailing: 40))
                            .listRowSeparator(.hidden)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    if let index = brainDumpManager.tasks.firstIndex(where: { $0.id == task.id }) {
                                        AnalyticsManager.shared.capture("brain_dump_task_deleted")
                                        withAnimation(.easeInOut) {
                                            _ = brainDumpManager.tasks.remove(at: index)
                                        }
                                    }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                        .onMove(perform: moveTask)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }

            // Bottom Action Bar
            ZStack(alignment: .bottomTrailing) {
                if isSelectionMode && !selectedTaskIds.isEmpty {
                    Button(action: {
                        if let firstId = selectedTaskIds.first,
                           let task = brainDumpManager.tasks.first(where: { $0.id == firstId }) {
                            AnalyticsManager.shared.capture("brain_dump_task_scheduled")
                            onSchedule(task.title, task.id)
                            withAnimation {
                                isSelectionMode = false
                                selectedTaskIds.removeAll()
                            }
                        }
                    }) {
                        Text("Schedule Selected")
                            .font(.system(size: 16, weight: .medium, design: .serif))
                            .foregroundStyle(currentTheme.bg)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                RoundedRectangle(cornerRadius: 35)
                                    .fill(goldColor)
                                    .shadow(color: Color.black.opacity(0.3) as Color, radius: 10, x: 0, y: 5)
                            )
                    }
                    .padding(.trailing, 86) // Avoid overlapping the FAB
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // Floating Action Button (Toggle)
                Button(action: { 
                    if !isSelectionMode && brainDumpManager.tasks.isEmpty { return }
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        isSelectionMode.toggle()
                        if !isSelectionMode {
                            selectedTaskIds.removeAll()
                        }
                    }
                    AnalyticsManager.shared.capture("brain_dump_selection_mode_toggled", properties: ["is_active": isSelectionMode])
                }) {
                    ZStack {
                        Circle()
                            .fill(goldColor)
                            .frame(width: 70, height: 70)
                            .shadow(color: Color.black.opacity(0.3) as Color, radius: 10, x: 0, y: 5)
                        
                        Image(systemName: isSelectionMode ? "xmark" : "calendar.badge.plus")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(currentTheme.bg)
                    }
                }
                .buttonStyle(.plain)
                .disabled(!isSelectionMode && brainDumpManager.tasks.isEmpty)
                .opacity((!isSelectionMode && brainDumpManager.tasks.isEmpty) ? (0.4 as Double) : (1.0 as Double))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .sheet(isPresented: $showingBulkImport) {
            BulkImportView(isPresented: $showingBulkImport, manager: brainDumpManager)
        }
        .alert("Clear \(selectedDoneFilter.rawValue) Tasks?", isPresented: $showingClearAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                AnalyticsManager.shared.capture("brain_dump_list_cleared", properties: ["filter": selectedDoneFilter.rawValue])
                clearCurrentFilter()
            }
        } message: {
            Text("Are you sure you want to clear your \(selectedDoneFilter.rawValue.lowercased()) list? This action cannot be undone.")
        }
    }
    
    private func addTask() {
        guard !newTaskTitle.isEmpty else { return }
        withAnimation {
            brainDumpManager.tasks.insert(BrainDumpTask(title: newTaskTitle), at: 0)
        }
        AnalyticsManager.shared.capture("brain_dump_task_added")
        newTaskTitle = ""
        isFocused = true
    }
    
    private func moveTask(from source: IndexSet, to destination: Int) {
        brainDumpManager.tasks.move(fromOffsets: source, toOffset: destination)
    }

    private func clearCurrentFilter() {
        let idsToRemove = Set(filteredTasks.map { $0.id })
        withAnimation {
            brainDumpManager.tasks.removeAll { idsToRemove.contains($0.id) }
        }
    }
}

struct BrainDumpRow: View {
    @AppStorage("appTheme") private var currentTheme: AppTheme = .sage
    var title: String
    var isCompleted: Bool
    var scheduledDate: Date? = nil
    var completedDate: Date? = nil
    var isSelected: Bool = false
    var isSelectionMode: Bool = false
    var onToggle: () -> Void

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 16) {
                if isSelectionMode {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22, weight: .light))
                        .foregroundStyle(isSelected ? currentTheme.accent : (currentTheme.textForeground.opacity(0.3) as Color))
                } else {
                    Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22, weight: .light))
                        .foregroundStyle(isCompleted ? (currentTheme.textForeground.opacity(0.3) as Color) : currentTheme.accent)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(currentTheme.textForeground.opacity(isCompleted ? 0.4 : 0.9) as Color)
                        .strikethrough(isCompleted && !isSelectionMode, color: (currentTheme.textForeground.opacity(0.4) as Color))
                    
                    if isCompleted, let completedDate = completedDate {
                        Text("Completed on \(formatDate(completedDate))")
                            .font(.system(size: 11, weight: .light))
                            .foregroundStyle(currentTheme.textForeground.opacity(0.4) as Color)
                    } else if let scheduledDate = scheduledDate {
                        Text("Scheduled on \(formatDate(scheduledDate))")
                            .font(.system(size: 11, weight: .light))
                            .foregroundStyle(currentTheme.textForeground.opacity(0.4) as Color)
                    }
                }

                Spacer()
            }
        }
        .buttonStyle(.plain)
    }
}
