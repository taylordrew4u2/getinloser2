import SwiftUI
import MapKit

struct MapsTabView: View {
    @EnvironmentObject var cloudKitManager: CloudKitManager
    @StateObject private var locationManager = LocationManager.shared
    
    let trip: Trip
    
    @State private var events: [ItineraryEvent] = []
    @State private var isLoading = true
    @State private var selectedEvent: ItineraryEvent?
    @State private var cameraPosition: MapCameraPosition = .automatic
    
    var body: some View {
        ZStack {
            if isLoading {
                Color.black
                    .ignoresSafeArea()
                
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
            } else if events.isEmpty || !events.contains(where: { $0.coordinate != nil }) {
                emptyStateView
            } else {
                Map(position: $cameraPosition) {
                    ForEach(events.filter { $0.coordinate != nil }) { event in
                        Marker(event.name, coordinate: event.coordinate!)
                            .tint(.blue)
                    }
                    
                    if let userLocation = locationManager.userLocation {
                        Annotation("You", coordinate: userLocation) {
                            ZStack {
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 20, height: 20)
                                
                                Circle()
                                    .stroke(Color.white, lineWidth: 3)
                                    .frame(width: 20, height: 20)
                            }
                        }
                    }
                }
                .ignoresSafeArea()
                .onAppear {
                    locationManager.requestPermission()
                    locationManager.startUpdatingLocation()
                    
                    // Set initial camera position to show all markers
                    if let firstCoordinate = events.first(where: { $0.coordinate != nil })?.coordinate {
                        cameraPosition = .region(MKCoordinateRegion(
                            center: firstCoordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
                        ))
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    Button(action: centerOnUserLocation) {
                        Image(systemName: "location.fill")
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue)
                            .clipShape(Circle())
                            .shadow(radius: 4)
                    }
                    .padding()
                }
            }
        }
        .task {
            await loadEvents()
        }
    }
    
    private var emptyStateView: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                Image(systemName: "map")
                    .font(.system(size: 60))
                    .foregroundColor(.gray)
                
                Text("No Locations Yet")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text("Add events with locations to see them on the map")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
    }
    
    private func loadEvents() async {
        do {
            let fetchedEvents = try await cloudKitManager.fetchEvents(for: trip.id)
            await MainActor.run {
                events = fetchedEvents
                isLoading = false
            }
        } catch {
            print("Error loading events: \(error)")
            await MainActor.run {
                isLoading = false
            }
        }
    }
    
    private func centerOnUserLocation() {
        if let userLocation = locationManager.userLocation {
            withAnimation {
                cameraPosition = .region(MKCoordinateRegion(
                    center: userLocation,
                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                ))
            }
        }
    }
}

#Preview {
    MapsTabView(trip: Trip(
        name: "Tokyo Adventure",
        location: "Tokyo, Japan",
        startDate: Date(),
        endDate: Date().addingTimeInterval(86400 * 7),
        ownerID: "user123"
    ))
    .environmentObject(CloudKitManager.shared)
}
