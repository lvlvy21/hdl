//
//  DailyTasksApp.swift
//  Created by faying.luo
//

import SwiftUI

// MARK: - Task Model
struct Task: Identifiable, Codable {
    var id = UUID()
    var title: String
    var deadline: Date
    var isCompleted: Bool = false
}

// MARK: - Task Data Manager
class TaskManager: ObservableObject {
    @Published var tasks: [Task] = [] {
        didSet { saveTasks() }
    }
    
    let tasksKey = "dailyTasks"
    
    init() { loadTasks() }
    
    func addTask(_ task: Task) {
        tasks.append(task)
    }
    
    func updateTask(_ task: Task) {
        if let index = tasks.firstIndex(where: {$0.id == task.id}) {
            tasks[index] = task
        }
    }
    
    func deleteTask(at offsets: IndexSet) {
        tasks.remove(atOffsets: offsets)
    }
    
    func toggleComplete(_ task: Task) {
        if let index = tasks.firstIndex(where: {$0.id == task.id}) {
            tasks[index].isCompleted.toggle()
        }
    }
    
    func saveTasks() {
        if let encoded = try? JSONEncoder().encode(tasks) {
            UserDefaults.standard.set(encoded, forKey: tasksKey)
        }
    }
    
    func loadTasks() {
        if let data = UserDefaults.standard.data(forKey: tasksKey),
           let decoded = try? JSONDecoder().decode([Task].self, from: data) {
            tasks = decoded
        }
    }
}

// MARK: - Main App
@main
struct DailyTasksApp: App {
    @StateObject private var taskManager = TaskManager()
    @AppStorage("isDarkMode") private var isDarkMode = false
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(taskManager)
                .preferredColorScheme(isDarkMode ? .dark : .light)
        }
    }
}

// MARK: - Main Tab View
struct MainTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Tasks", systemImage: "checkmark.square")
                }
            StatsView()
                .tabItem {
                    Label("Stats", systemImage: "chart.pie")
                }
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
    }
}

// MARK: - Home View
struct HomeView: View {
    @EnvironmentObject var taskManager: TaskManager
    @State private var showAddTask = false
    
    var body: some View {
        NavigationView {
            List {
                if taskManager.tasks.isEmpty {
                    Text("No tasks today")
                        .foregroundColor(.gray)
                } else {
                    ForEach(taskManager.tasks) { task in
                        HStack {
                            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                                .onTapGesture { taskManager.toggleComplete(task) }
                            VStack(alignment: .leading) {
                                Text(task.title)
                                Text(task.deadline, style: .date)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                if let index = taskManager.tasks.firstIndex(where: {$0.id == task.id}) {
                                    taskManager.deleteTask(at: IndexSet(integer: index))
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Tasks")
            .toolbar {
                Button(action: { showAddTask = true }) {
                    Image(systemName: "plus")
                }
            }
            .sheet(isPresented: $showAddTask) {
                AddTaskView()
            }
        }
    }
}

// MARK: - Add Task View
struct AddTaskView: View {
    @EnvironmentObject var taskManager: TaskManager
    @Environment(\.presentationMode) var presentationMode
    @State private var title = ""
    @State private var deadline = Date()
    @State private var showAlert = false
    
    var body: some View {
        NavigationView {
            Form {
                TextField("Task Title", text: $title)
                DatePicker("Deadline", selection: $deadline, displayedComponents: .date)
            }
            .navigationTitle("Add Task")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { presentationMode.wrappedValue.dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if title.trimmingCharacters(in: .whitespaces).isEmpty {
                            showAlert = true
                        } else {
                            let newTask = Task(title: title, deadline: deadline)
                            taskManager.addTask(newTask)
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                }
            }
            .alert("Task title cannot be empty", isPresented: $showAlert) {
                Button("OK", role: .cancel) { }
            }
        }
    }
}

// MARK: - Stats View
struct StatsView: View {
    @EnvironmentObject var taskManager: TaskManager
    
    var completedCount: Int {
        taskManager.tasks.filter { $0.isCompleted }.count
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Total Tasks: \(taskManager.tasks.count)")
            Text("Completed: \(completedCount)")
            Text("Completion: \(taskManager.tasks.isEmpty ? 0 : Int(Double(completedCount)/Double(taskManager.tasks.count)*100))%")
            ProgressView(value: taskManager.tasks.isEmpty ? 0 : Double(completedCount)/Double(taskManager.tasks.count))
                .padding()
        }
        .navigationTitle("Statistics")
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @AppStorage("isDarkMode") private var isDarkMode = false
    @AppStorage("pushNotificationEnabled") private var pushNotificationEnabled = false
    @State private var showAlert = false
    
    var body: some View {
        Form {
            Toggle("Push Notifications", isOn: $pushNotificationEnabled)
            Toggle("Dark Mode", isOn: $isDarkMode)
            Button("Save Settings") {
                showAlert = true
            }
            .alert("Settings Saved", isPresented: $showAlert) {
                Button("OK", role: .cancel) {}
            }
        }
        .navigationTitle("Settings")
    }
}
