import SwiftUI

struct HomeView: View {
    @EnvironmentObject var firebaseManager: FirebaseStorageManager
    @State private var showingAddTrip = false
    @State private var showingJoinTrip = false
    @State private var selectedTrip: Trip?
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                if firebaseManager.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                } else if !firebaseManager.isSignedIn {
                    iCloudSignInView
                } else if firebaseManager.trips.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(firebaseManager.trips) { trip in
                                TripCardView(trip: trip)
                                    .onTapGesture {
                                        selectedTrip = trip
                                    }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("My Trips")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingJoinTrip = true }) {
                        Image(systemName: "person.badge.plus")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                    .disabled(!firebaseManager.isSignedIn)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddTrip = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                    .disabled(!firebaseManager.isSignedIn)
                }
            }
            .sheet(isPresented: $showingAddTrip) {
                AddTripView()
            }
            .sheet(isPresented: $showingJoinTrip) {
                JoinTripView()
            }
            .sheet(item: $selectedTrip) { trip in
                TripDetailView(trip: trip)
            }
            .preferredColorScheme(.dark)
        }
    }
    
    private var iCloudSignInView: some View {
        VStack(spacing: 20) {
            Image(systemName: "icloud.slash")
                .font(.system(size: 80))
                .foregroundColor(.gray)
            
            Text("iCloud Sign In Required")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text("Please sign in to iCloud in Settings to use this app. Your trips are stored securely in iCloud.")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            if let error = firebaseManager.error {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.orange)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Button(action: openSettings) {
                Label("Open Settings", systemImage: "gear")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .padding(.top)
            
            Button(action: {
                Task {
                    await firebaseManager.checkAccountStatus()
                }
            }) {
                Text("Refresh Status")
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }
            .padding(.top, 8)
        }
    }
    
    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "airplane.departure")
                .font(.system(size: 80))
                .foregroundColor(.gray)
            
            Text("No Trips Yet")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text("Start planning your next adventure")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            HStack(spacing: 16) {
                Button(action: { showingAddTrip = true }) {
                    Label("Create Trip", systemImage: "plus")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                
                Button(action: { showingJoinTrip = true }) {
                    Label("Join Trip", systemImage: "person.badge.plus")
                        .font(.headline)
                        .foregroundColor(.blue)
                        .padding()
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(12)
                }
            }
            .padding(.top)
        }
    }
}

struct TripCardView: View {
    let trip: Trip
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(trip.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    HStack {
                        Image(systemName: "location.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                        Text(trip.location)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
            
            Divider()
                .background(Color.gray.opacity(0.3))
            
            HStack {
                Label(trip.startDate.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Image(systemName: "arrow.right")
                    .font(.caption2)
                    .foregroundColor(.gray)
                
                Text(trip.endDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Spacer()
                
                Label("\(trip.memberIDs.count)", systemImage: "person.2.fill")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}

#Preview {
    HomeView()
        .environmentObject(FirebaseStorageManager.shared)
        .environmentObject(NotificationManager.shared)
}
