import SwiftUI
import MapKit

struct MapConfirmationView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var locationManager = LocationManager.shared
    
    let location: String
    @Binding var selectedCoordinate: CLLocationCoordinate2D?
    
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @State private var markerCoordinate: CLLocationCoordinate2D?
    @State private var isLoading = true
    
    var body: some View {
        NavigationStack {
            ZStack {
                Map(position: .constant(.region(region))) {
                    if let markerCoordinate = markerCoordinate {
                        Marker(location, coordinate: markerCoordinate)
                            .tint(.blue)
                    }
                }
                .ignoresSafeArea()
                
                if isLoading {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                    
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                }
            }
            .navigationTitle("Confirm Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Confirm") {
                        selectedCoordinate = markerCoordinate
                        dismiss()
                    }
                    .foregroundColor(.blue)
                    .disabled(markerCoordinate == nil)
                }
            }
            .task {
                await loadLocation()
            }
        }
    }
    
    private func loadLocation() async {
        do {
            let coordinate = try await locationManager.geocodeAddress(location)
            
            await MainActor.run {
                markerCoordinate = coordinate
                region = MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                )
                isLoading = false
            }
        } catch {
            print("Error geocoding: \(error)")
            await MainActor.run {
                isLoading = false
            }
        }
    }
}
