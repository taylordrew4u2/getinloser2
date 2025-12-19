import SwiftUI

struct TodoTabView: View {
    @EnvironmentObject var cloudKitManager: CloudKitManager
    
    let trip: Trip
    
    @State private var todos: [TodoItem] = []
    @State private var members: [TripMember] = []
    @State private var isLoading = true
    @State private var showingAddTodo = false
    @State private var newTodoTitle = ""
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
            } else if todos.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(todos) { todo in
                            TodoItemView(
                                todo: todo,
                                trip: trip,
                                members: members,
                                onToggle: { toggleTodo(todo) }
                            )
                        }
                    }
                    .padding()
                }
            }
        }
        .overlay(alignment: .bottomTrailing) {
            Button(action: { showingAddTodo = true }) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 56))
                    .foregroundColor(.blue)
                    .background(Color.black)
                    .clipShape(Circle())
            }
            .padding()
        }
        .task {
            await loadData()
        }
        .sheet(isPresented: $showingAddTodo) {
            AddTodoView(trip: trip) { newTodo in
                todos.append(newTodo)
                todos.sort { !$0.isFullyCompleted(memberIDs: trip.memberIDs) && $1.isFullyCompleted(memberIDs: trip.memberIDs) }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checklist")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Tasks Yet")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            Text("Add tasks for your group to complete")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
    
    private func loadData() async {
        do {
            async let todosTask = cloudKitManager.fetchTodos(for: trip.id)
            async let membersTask = cloudKitManager.fetchMembers(memberIDs: trip.memberIDs)
            
            let (fetchedTodos, fetchedMembers) = try await (todosTask, membersTask)
            
            await MainActor.run {
                todos = fetchedTodos.sorted { 
                    !$0.isFullyCompleted(memberIDs: trip.memberIDs) && $1.isFullyCompleted(memberIDs: trip.memberIDs)
                }
                members = fetchedMembers
                isLoading = false
            }
        } catch {
            print("Error loading data: \(error)")
            await MainActor.run {
                isLoading = false
            }
        }
    }
    
    private func toggleTodo(_ todo: TodoItem) {
        Task {
            do {
                try await cloudKitManager.toggleTodoCompletion(todo, userID: cloudKitManager.currentUserID)
                
                // Refresh todos
                let updatedTodos = try await cloudKitManager.fetchTodos(for: trip.id)
                await MainActor.run {
                    todos = updatedTodos.sorted {
                        !$0.isFullyCompleted(memberIDs: trip.memberIDs) && $1.isFullyCompleted(memberIDs: trip.memberIDs)
                    }
                }
            } catch {
                print("Error toggling todo: \(error)")
            }
        }
    }
}

struct TodoItemView: View {
    let todo: TodoItem
    let trip: Trip
    let members: [TripMember]
    let onToggle: () -> Void
    
    @EnvironmentObject var cloudKitManager: CloudKitManager
    @State private var showingDeleteAlert = false
    
    private var currentUserCompleted: Bool {
        todo.completedBy[cloudKitManager.currentUserID] == true
    }
    
    private var isFullyCompleted: Bool {
        todo.isFullyCompleted(memberIDs: trip.memberIDs)
    }
    
    private var pendingMemberNames: [String] {
        let pendingIDs = todo.pendingMembers(memberIDs: trip.memberIDs)
        return members.filter { pendingIDs.contains($0.userRecordID) }.map { $0.name }
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: currentUserCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(currentUserCompleted ? .blue : .gray)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(todo.title)
                    .font(.body)
                    .foregroundColor(.white)
                    .strikethrough(isFullyCompleted)
                
                if isFullyCompleted {
                    Label("Completed by all members", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                } else if !pendingMemberNames.isEmpty {
                    Label("Waiting for: \(pendingMemberNames.joined(separator: ", "))", systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                
                // Show who has completed
                let completedMembers = members.filter { todo.completedBy[$0.userRecordID] == true }
                if !completedMembers.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle")
                            .font(.caption2)
                            .foregroundColor(.blue)
                        
                        Text(completedMembers.map { $0.name }.joined(separator: ", "))
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
            }
            
            Spacer()
            
            Menu {
                Button(role: .destructive, action: { showingDeleteAlert = true }) {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color.white.opacity(isFullyCompleted ? 0.03 : 0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isFullyCompleted ? Color.green.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 1)
        )
        .alert("Delete Task", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteTodo()
            }
        } message: {
            Text("Are you sure you want to delete this task?")
        }
    }
    
    private func deleteTodo() {
        Task {
            do {
                try await cloudKitManager.deleteTodo(todo)
            } catch {
                print("Error deleting todo: \(error)")
            }
        }
    }
}

struct AddTodoView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var cloudKitManager: CloudKitManager
    
    let trip: Trip
    let onTodoAdded: (TodoItem) -> Void
    
    @State private var todoTitle = ""
    @State private var isLoading = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                VStack(alignment: .leading, spacing: 16) {
                    Text("Task Description")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    TextField("Enter task description", text: $todoTitle, axis: .vertical)
                        .textFieldStyle(CustomTextFieldStyle())
                        .lineLimit(3...6)
                    
                    Text("All members will need to check off this task for it to be marked as complete.")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Add Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: createTodo) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                        } else {
                            Text("Add")
                                .fontWeight(.semibold)
                        }
                    }
                    .foregroundColor(.blue)
                    .disabled(todoTitle.isEmpty || isLoading)
                }
            }
            .preferredColorScheme(.dark)
        }
    }
    
    private func createTodo() {
        isLoading = true
        
        Task {
            do {
                let todo = TodoItem(
                    tripID: trip.id,
                    title: todoTitle,
                    completedBy: [:],
                    createdBy: cloudKitManager.currentUserID
                )
                
                let savedTodo = try await cloudKitManager.createTodo(todo)
                
                await MainActor.run {
                    onTodoAdded(savedTodo)
                    isLoading = false
                    dismiss()
                }
            } catch {
                print("Error creating todo: \(error)")
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }
}

#Preview {
    TodoTabView(trip: Trip(
        name: "Tokyo Adventure",
        location: "Tokyo, Japan",
        startDate: Date(),
        endDate: Date().addingTimeInterval(86400 * 7),
        ownerID: "user123"
    ))
    .environmentObject(CloudKitManager.shared)
}
