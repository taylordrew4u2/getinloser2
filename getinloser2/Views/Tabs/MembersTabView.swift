import SwiftUI

struct MembersTabView: View {
    @EnvironmentObject var firebaseManager: FirebaseStorageManager
    @EnvironmentObject var notificationManager: NotificationManager
    
    let trip: Trip
    
    @State private var members: [TripMember] = []
    @State private var isLoading = true
    @State private var showingShareSheet = false
    
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
                        // Invite Code Card
                        InviteCodeCard(trip: trip, showingShareSheet: $showingShareSheet)
                        
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
                                
                                Text("\(trip.memberIDs.count)")
                                    .font(.headline)
                                    .foregroundColor(.blue)
                            }
                            
                            ForEach(trip.memberIDs, id: \.self) { memberID in
                                MemberRowView(memberID: memberID, trip: trip, members: members)
                            }
                        }
                        
                        // Invite Button
                        Button(action: { showingShareSheet = true }) {
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
            ShareTripSheet(trip: trip)
        }
    }
    
    private func loadMembers() async {
        do {
            let fetchedMembers = try await firebaseManager.fetchMembers(memberIDs: trip.memberIDs)
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
}

struct InviteCodeCard: View {
    let trip: Trip
    @Binding var showingShareSheet: Bool
    @State private var codeCopied = false
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Invite Code")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text("Share this code with friends to join")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Button(action: { showingShareSheet = true }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }
            
            HStack(spacing: 8) {
                Text(trip.inviteCode)
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                    .foregroundColor(.blue)
                    .tracking(4)
                
                Button(action: copyCode) {
                    Image(systemName: codeCopied ? "checkmark.circle.fill" : "doc.on.doc")
                        .font(.title2)
                        .foregroundColor(codeCopied ? .green : .gray)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
    
    private func copyCode() {
        UIPasteboard.general.string = trip.inviteCode
        codeCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            codeCopied = false
        }
    }
}

struct MemberRowView: View {
    @EnvironmentObject var firebaseManager: FirebaseStorageManager
    
    let memberID: String
    let trip: Trip
    let members: [TripMember]
    
    @State private var showingRemoveAlert = false
    
    private var member: TripMember? {
        members.first { $0.userRecordID == memberID }
    }
    
    private var isCurrentUser: Bool {
        memberID == firebaseManager.currentUserID
    }
    
    private var isOwner: Bool {
        memberID == trip.ownerID
    }
    
    private var displayName: String {
        if let member = member {
            return member.name
        } else if isCurrentUser {
            return "You"
        } else if isOwner {
            return "Trip Owner"
        } else {
            return "Member"
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Text(displayName.prefix(1).uppercased())
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(displayName)
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
                    
                    if isCurrentUser && !isOwner {
                        Text("You")
                            .font(.caption2)
                            .foregroundColor(.gray)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
            }
            
            Spacer()
            
            if !isOwner && firebaseManager.currentUserID == trip.ownerID && !isCurrentUser {
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
            Text("Are you sure you want to remove this member from the trip?")
        }
    }
    
    private func removeMember() {
        Task {
            do {
                try await firebaseManager.removeMember(memberID, from: trip)
            } catch {
                print("Error removing member: \(error)")
            }
        }
    }
}

struct ShareTripSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var firebaseManager: FirebaseStorageManager
    
    let trip: Trip
    
    @State private var codeCopied = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                VStack(spacing: 32) {
                    VStack(spacing: 8) {
                        Image(systemName: "person.2.badge.plus")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        Text("Invite Friends")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("Share this code with friends who have the app")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    
                    VStack(spacing: 16) {
                        Text("INVITE CODE")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.gray)
                        
                        Text(trip.inviteCode)
                            .font(.system(size: 48, weight: .bold, design: .monospaced))
                            .foregroundColor(.blue)
                            .tracking(8)
                        
                        Button(action: copyCode) {
                            Label(codeCopied ? "Copied!" : "Copy Code", systemImage: codeCopied ? "checkmark.circle.fill" : "doc.on.doc")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(codeCopied ? Color.green : Color.blue.opacity(0.3))
                                .cornerRadius(12)
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(16)
                    
                    Button(action: shareMessage) {
                        Label("Share via Message", systemImage: "square.and.arrow.up")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 8) {
                        Text("How it works")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text("1. Share the invite code with your friends\n2. They open the app and tap 'Join Trip'\n3. They enter the code and they're in!")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
            }
            .preferredColorScheme(.dark)
        }
    }
    
    private func copyCode() {
        UIPasteboard.general.string = trip.inviteCode
        codeCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            codeCopied = false
        }
    }
    
    private func shareMessage() {
        let message = firebaseManager.getShareMessage(for: trip)
        let activityVC = UIActivityViewController(activityItems: [message], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
}

#Preview {
    MembersTabView(trip: Trip(
        name: "Tokyo Adventure",
        location: "Tokyo, Japan",
        startDate: Date(),
        endDate: Date().addingTimeInterval(86400 * 7),
        ownerID: "user123"
    ))
    .environmentObject(FirebaseStorageManager.shared)
    .environmentObject(NotificationManager.shared)
}
