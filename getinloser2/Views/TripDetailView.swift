import SwiftUI

struct TripDetailView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var cloudKitManager: CloudKitManager
    
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
        let message = cloudKitManager.getShareMessage(for: trip)
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
                try await cloudKitManager.deleteTrip(trip)
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

#Preview {
    TripDetailView(trip: Trip(
        name: "Tokyo Adventure",
        location: "Tokyo, Japan",
        startDate: Date(),
        endDate: Date().addingTimeInterval(86400 * 7),
        ownerID: "user123"
    ))
    .environmentObject(CloudKitManager.shared)
    .environmentObject(NotificationManager.shared)
}
