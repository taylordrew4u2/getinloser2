import SwiftUI

struct TripDetailView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var firebaseManager: FirebaseStorageManager
    
    let trip: Trip
    
    @State private var selectedTab = 0
    @State private var showingShareSheet = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Custom Tab Bar
                    TabBarView(selectedTab: $selectedTab)
                        .padding(.horizontal)
                        .padding(.top, 8)
                    
                    // Tab Content
                    TabView(selection: $selectedTab) {
                        ItineraryTabView(trip: trip)
                            .tag(0)
                        
                        MapsTabView(trip: trip)
                            .tag(1)
                        
                        TicketsTabView(trip: trip)
                            .tag(2)
                        
                        NotesTabView(trip: trip)
                            .tag(3)
                        
                        TodoTabView(trip: trip)
                            .tag(4)
                        
                        IOUTabView(trip: trip)
                            .tag(5)
                        
                        MembersTabView(trip: trip)
                            .tag(6)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
            }
            .navigationTitle(trip.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showingShareSheet = true }) {
                            Label("Invite Members", systemImage: "person.badge.plus")
                        }
                        
                        Button(action: shareTrip) {
                            Label("Share Trip Info", systemImage: "square.and.arrow.up")
                        }
                        
                        Button(role: .destructive, action: deleteTrip) {
                            Label("Delete Trip", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(.blue)
                    }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                ShareTripSheet(trip: trip)
            }
            .preferredColorScheme(.dark)
        }
    }
    
    private func shareTrip() {
        let message = firebaseManager.getShareMessage(for: trip)
        let activityVC = UIActivityViewController(activityItems: [message], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
    
    private func deleteTrip() {
        Task {
            do {
                try await firebaseManager.deleteTrip(trip)
                await MainActor.run {
                    dismiss()
                }
            } catch {
                print("Error deleting trip: \(error)")
            }
        }
    }
}

struct TabBarView: View {
    @Binding var selectedTab: Int
    
    let tabs = ["Itinerary", "Maps", "Tickets", "Notes", "To-Do", "IOU", "Members"]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(0..<tabs.count, id: \.self) { index in
                    TabButton(title: tabs[index], isSelected: selectedTab == index) {
                        withAnimation {
                            selectedTab = index
                        }
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }
}

struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .white : .gray)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.blue : Color.white.opacity(0.05))
                )
        }
    }
}

struct TicketsTabView: View {
    let trip: Trip
    
    var body: some View {
        VStack {
            Text("Tickets")
                .font(.title2)
                .fontWeight(.semibold)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

struct TodoItem: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var isDone: Bool
    var createdAt: Date
}

struct TodoTabView: View {
    let trip: Trip
    @State private var newTitle: String = ""
    @State private var items: [TodoItem] = []

    private var storageKey: String {
        // Build a reasonably stable key using trip name + start date
        "todos_\(trip.name)_\(trip.startDate.timeIntervalSince1970)"
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("To-Do")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
            }

            HStack(spacing: 8) {
                TextField("Add a task…", text: $newTitle)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.done)
                    .onSubmit(addItem)
                Button(action: addItem) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
                .disabled(newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if items.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checklist")
                        .font(.system(size: 28))
                        .foregroundColor(.gray)
                    Text("No tasks yet")
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(items) { item in
                        HStack(spacing: 10) {
                            Button(action: { toggle(item) }) {
                                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(item.isDone ? .green : .gray)
                            }
                            .buttonStyle(.plain)

                            Text(item.title)
                                .strikethrough(item.isDone)
                                .foregroundColor(item.isDone ? .gray : .primary)
                                .lineLimit(2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .listRowBackground(Color(.secondarySystemBackground))
                    }
                    .onDelete(perform: delete)
                }
                .listStyle(.insetGrouped)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear(perform: load)
    }

    private func addItem() {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let item = TodoItem(id: UUID(), title: trimmed, isDone: false, createdAt: Date())
        items.insert(item, at: 0)
        newTitle = ""
        save()
    }

    private func toggle(_ item: TodoItem) {
        if let idx = items.firstIndex(of: item) {
            items[idx].isDone.toggle()
            save()
        }
    }

    private func delete(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        if let decoded = try? JSONDecoder().decode([TodoItem].self, from: data) {
            items = decoded
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}

struct IOUTabView: View {
    let trip: Trip
    
    var body: some View {
        VStack {
            Text("IOU")
                .font(.title2)
                .fontWeight(.semibold)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

struct NotesTabView: View {
    let trip: Trip
    
    var body: some View {
        VStack {
            Text("Notes")
                .font(.title2)
                .fontWeight(.semibold)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

struct ItineraryTabView: View {
    let trip: Trip
    
    var body: some View {
        VStack {
            Text("Itinerary")
                .font(.title2)
                .fontWeight(.semibold)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

struct MapsTabView: View {
    let trip: Trip
    
    var body: some View {
        VStack {
            Text("Maps")
                .font(.title2)
                .fontWeight(.semibold)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

struct MembersTabView: View {
    let trip: Trip
    
    var body: some View {
        VStack {
            Text("Members")
                .font(.title2)
                .fontWeight(.semibold)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

#Preview {
    TripDetailView(trip: Trip(
        name: "Tokyo Adventure",
        location: "Tokyo, Japan",
        startDate: Date(),
        endDate: Date().addingTimeInterval(86400 * 7),
        ownerID: "user123"
    ))
    .environmentObject(FirebaseStorageManager.shared)
    .environmentObject(NotificationManager.shared)
}
