import SwiftUI
import MapKit

struct AddEventView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var cloudKitManager: CloudKitManager
    @StateObject private var locationManager = LocationManager.shared
    
    let trip: Trip
    let date: Date
    let onEventAdded: (ItineraryEvent) -> Void
    
    @State private var eventName = ""
    @State private var eventTime = Date()
    @State private var location = ""
    @State private var notes = ""
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    @State private var showingMapConfirmation = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Event Name
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Event Name")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            TextField("Enter event name", text: $eventName)
                                .textFieldStyle(CustomTextFieldStyle())
                        }
                        
                        // Time
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Time")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            DatePicker("", selection: $eventTime, displayedComponents: .hourAndMinute)
                                .datePickerStyle(.compact)
                                .colorScheme(.dark)
                                .accentColor(.blue)
                        }
                        
                        // Location
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Location")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            HStack {
                                TextField("Enter location", text: $location)
                                    .textFieldStyle(CustomTextFieldStyle())
                                
                                Button(action: { showingMapConfirmation = true }) {
                                    Image(systemName: "map.fill")
                                        .foregroundColor(.blue)
                                        .padding(12)
                                        .background(Color.white.opacity(0.1))
                                        .cornerRadius(8)
                                }
                                .disabled(location.isEmpty)
                            }
                        }
                        
                        // Notes
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Notes")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            TextEditor(text: $notes)
                                .frame(height: 100)
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(8)
                                .foregroundColor(.white)
                                .scrollContentBackground(.hidden)
                        }
                        
                        if let errorMessage = errorMessage {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding()
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Add Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: createEvent) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                        } else {
                            Text("Add")
                                .fontWeight(.semibold)
                        }
                    }
                    .foregroundColor(.blue)
                    .disabled(eventName.isEmpty || location.isEmpty || isLoading)
                }
            }
            .sheet(isPresented: $showingMapConfirmation) {
                MapConfirmationView(location: location, selectedCoordinate: $selectedCoordinate)
            }
            .preferredColorScheme(.dark)
        }
    }
    
    private func createEvent() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // Geocode if no coordinate selected
                if selectedCoordinate == nil && !location.isEmpty {
                    selectedCoordinate = try await locationManager.geocodeAddress(location)
                }
                
                let event = ItineraryEvent(
                    tripID: trip.id,
                    name: eventName,
                    date: date,
                    time: eventTime,
                    location: location,
                    coordinate: selectedCoordinate,
                    notes: notes,
                    createdBy: cloudKitManager.currentUserID
                )
                
                let savedEvent = try await cloudKitManager.createEvent(event)
                
                await MainActor.run {
                    onEventAdded(savedEvent)
                    isLoading = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Failed to create event: \(error.localizedDescription)"
                }
            }
        }
    }
}

#Preview {
    AddEventView(
        trip: Trip(
            name: "Tokyo Adventure",
            location: "Tokyo, Japan",
            startDate: Date(),
            endDate: Date().addingTimeInterval(86400 * 7),
            ownerID: "user123"
        ),
        date: Date()
    ) { _ in }
    .environmentObject(CloudKitManager.shared)
}
