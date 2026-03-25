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
    @State private var taskJustCompletedIds = Set<UUID>()
    
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
            return brainDumpManager.tasks.filter { $0.isCompleted && !taskJustCompletedIds.contains($0.id) }
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

                // Filter Picker
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
                .padding(.bottom, 20)
                
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
                        Text(selectedFilter == .active ? "Clear your mind" : "No completed tasks")
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
                                            }
                                            
                                            let nowCompleted = brainDumpManager.tasks[index].isCompleted
                                            
                                            if !wasCompleted && nowCompleted {
                                                // Task was just marked as completed
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
}

struct BrainDumpRow: View {
    @AppStorage("appTheme") private var currentTheme: AppTheme = .sage
    var title: String
    var isCompleted: Bool
    var scheduledDate: Date? = nil
    var isSelected: Bool = false
    var isSelectionMode: Bool = false
    var onToggle: () -> Void

    private func formatScheduledDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        // Friday on March 19
        formatter.dateFormat = "EEEE 'on' MMMM d"
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
                    
                    if let scheduledDate = scheduledDate {
                        Text("\(formatScheduledDate(scheduledDate))")
                            .font(.system(size: 12, weight: .light))
                            .foregroundStyle(currentTheme.textForeground.opacity(0.5) as Color)
                    }
                }

                Spacer()
            }
        }
        .buttonStyle(.plain)
    }
}
