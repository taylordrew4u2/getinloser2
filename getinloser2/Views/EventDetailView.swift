import SwiftUI
import MapKit

struct EventDetailView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var firebaseManager: FirebaseStorageManager
    @StateObject private var locationManager = LocationManager.shared
    
    let trip: Trip
    @State var event: ItineraryEvent
    let onEventUpdated: (ItineraryEvent) -> Void
    
    @State private var isEditing = false
    @State private var showingDeleteAlert = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Event Name
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Event")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text(event.name)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                        
                        // Time
                        HStack {
                            Label(event.time.formatted(date: .omitted, time: .shortened), systemImage: "clock.fill")
                                .foregroundColor(.blue)
                            
                            Spacer()
                            
                            Text(event.date.formatted(date: .abbreviated, time: .omitted))
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(12)
                        
                        // Location
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Location", systemImage: "location.fill")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Text(event.location)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            
                            if let coordinate = event.coordinate {
                                Button(action: { openInMaps(coordinate: coordinate) }) {
                                    HStack {
                                        Image(systemName: "map.fill")
                                        Text("Open in Maps")
                                    }
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(12)
                                }
                            }
                        }
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(12)
                        
                        // Notes
                        if !event.notes.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Notes", systemImage: "note.text")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                Text(event.notes)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            .padding()
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(12)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Event Details")
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
                        Button(role: .destructive, action: { showingDeleteAlert = true }) {
                            Label("Delete Event", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(.blue)
                    }
                }
            }
            .alert("Delete Event", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteEvent()
                }
            } message: {
                Text("Are you sure you want to delete this event?")
            }
            .preferredColorScheme(.dark)
        }
    }
    
    private func openInMaps(coordinate: CLLocationCoordinate2D) {
        locationManager.openInMaps(coordinate: coordinate, name: event.name)
    }
    
    private func deleteEvent() {
        Task {
            do {
                try await firebaseManager.deleteEvent(event)
                await MainActor.run {
                    dismiss()
                }
            } catch {
                print("Error deleting event: \(error)")
            }
        }
    }
}
