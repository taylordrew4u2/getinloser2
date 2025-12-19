import SwiftUI
import MapKit

struct AddTripView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var cloudKitManager: CloudKitManager
    @StateObject private var locationManager = LocationManager.shared
    
    @State private var tripName = ""
    @State private var location = ""
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(86400 * 7) // 7 days later
    @State private var showingMapConfirmation = false
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Trip Name
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Trip Name")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            TextField("Enter trip name", text: $tripName)
                                .textFieldStyle(CustomTextFieldStyle())
                        }
                        
                        // Location
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Location")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            HStack {
                                TextField("Enter destination", text: $location)
                                    .textFieldStyle(CustomTextFieldStyle())
                                
                                Button(action: confirmLocation) {
                                    Image(systemName: "map.fill")
                                        .foregroundColor(.blue)
                                        .padding(12)
                                        .background(Color.white.opacity(0.1))
                                        .cornerRadius(8)
                                }
                                .disabled(location.isEmpty)
                            }
                        }
                        
                        // Dates
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Trip Dates")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .colorScheme(.dark)
                                .accentColor(.blue)
                            
                            DatePicker("End Date", selection: $endDate, in: startDate..., displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .colorScheme(.dark)
                                .accentColor(.blue)
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
            .navigationTitle("Add Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: createTrip) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                        } else {
                            Text("Create")
                                .fontWeight(.semibold)
                        }
                    }
                    .foregroundColor(.blue)
                    .disabled(tripName.isEmpty || location.isEmpty || isLoading)
                }
            }
            .sheet(isPresented: $showingMapConfirmation) {
                MapConfirmationView(location: location, selectedCoordinate: $selectedCoordinate)
            }
            .preferredColorScheme(.dark)
        }
    }
    
    private func confirmLocation() {
        showingMapConfirmation = true
    }
    
    private func createTrip() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // Geocode if no coordinate selected
                if selectedCoordinate == nil {
                    selectedCoordinate = try await locationManager.geocodeAddress(location)
                }
                
                let trip = Trip(
                    name: tripName,
                    location: location,
                    coordinate: selectedCoordinate,
                    startDate: startDate,
                    endDate: endDate,
                    ownerID: cloudKitManager.currentUserID,
                    memberIDs: [cloudKitManager.currentUserID]
                )
                
                _ = try await cloudKitManager.createTrip(trip)
                
                await MainActor.run {
                    isLoading = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Failed to create trip: \(error.localizedDescription)"
                }
            }
        }
    }
}

struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(8)
            .foregroundColor(.white)
    }
}

#Preview {
    AddTripView()
        .environmentObject(CloudKitManager.shared)
}
