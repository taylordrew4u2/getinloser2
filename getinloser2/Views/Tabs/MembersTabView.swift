import SwiftUI

struct MembersTabView: View {
    @EnvironmentObject var cloudKitManager: CloudKitManager
    @EnvironmentObject var notificationManager: NotificationManager
    
    let trip: Trip
    
    @State private var members: [TripMember] = []
    @State private var isLoading = true
    @State private var showingShareSheet = false
    @State private var shareURL: URL?
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
            } else {
                ScrollView {
                    VStack(spacing: 24) {
                        // Notification Settings
                        VStack(spacing: 16) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Notifications")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    
                                    Text("Get notified when changes are made")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                
                                Spacer()
                                
                                Toggle("", isOn: Binding(
                                    get: { notificationManager.notificationsEnabled },
                                    set: { notificationManager.toggleNotifications($0) }
                                ))
                                .tint(.blue)
                            }
                            .padding()
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(12)
                        }
                        
                        // Members List
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Members")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                Text("\(members.count)")
                                    .font(.headline)
                                    .foregroundColor(.blue)
                            }
                            
                            ForEach(members) { member in
                                MemberCardView(member: member, trip: trip)
                            }
                        }
                        
                        // Invite Button
                        Button(action: shareTrip) {
                            Label("Invite Members", systemImage: "person.badge.plus")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(12)
                        }
                    }
                    .padding()
                }
            }
        }
        .task {
            await loadMembers()
        }
        .sheet(isPresented: $showingShareSheet) {
            if let url = shareURL {
                ActivityViewController(activityItems: [url])
            }
        }
    }
    
    private func loadMembers() async {
        do {
            let fetchedMembers = try await cloudKitManager.fetchMembers(memberIDs: trip.memberIDs)
            await MainActor.run {
                members = fetchedMembers
                isLoading = false
            }
        } catch {
            print("Error loading members: \(error)")
            await MainActor.run {
                isLoading = false
            }
        }
    }
    
    private func shareTrip() {
        Task {
            do {
                let url = try await cloudKitManager.generateShareLink(for: trip)
                await MainActor.run {
                    shareURL = url
                    showingShareSheet = true
                }
            } catch {
                print("Error generating share link: \(error)")
            }
        }
    }
}

struct MemberCardView: View {
    @EnvironmentObject var cloudKitManager: CloudKitManager
    
    let member: TripMember
    let trip: Trip
    
    @State private var showingRemoveAlert = false
    
    private var isCurrentUser: Bool {
        member.userRecordID == cloudKitManager.currentUserID
    }
    
    private var isOwner: Bool {
        member.userRecordID == trip.ownerID
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Text(member.name.prefix(1).uppercased())
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(member.name)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    if isOwner {
                        Text("Owner")
                            .font(.caption2)
                            .foregroundColor(.blue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(4)
                    }
                    
                    if isCurrentUser {
                        Text("You")
                            .font(.caption2)
                            .foregroundColor(.gray)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
                
                if !member.phoneNumber.isEmpty {
                    Link(destination: URL(string: "tel:\(member.phoneNumber)")!) {
                        Label(member.phoneNumber, systemImage: "phone.fill")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            
            Spacer()
            
            if !isOwner && cloudKitManager.currentUserID == trip.ownerID {
                Button(action: { showingRemoveAlert = true }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .alert("Remove Member", isPresented: $showingRemoveAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) {
                removeMember()
            }
        } message: {
            Text("Are you sure you want to remove \(member.name) from this trip?")
        }
    }
    
    private func removeMember() {
        Task {
            do {
                try await cloudKitManager.removeMember(member.userRecordID, from: trip)
            } catch {
                print("Error removing member: \(error)")
            }
        }
    }
}

struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    MembersTabView(trip: Trip(
        name: "Tokyo Adventure",
        location: "Tokyo, Japan",
        startDate: Date(),
        endDate: Date().addingTimeInterval(86400 * 7),
        ownerID: "user123"
    ))
    .environmentObject(CloudKitManager.shared)
    .environmentObject(NotificationManager.shared)
}
