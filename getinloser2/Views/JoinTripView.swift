import SwiftUI

struct JoinTripView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var firebaseManager: FirebaseStorageManager
    
    @State private var inviteCode = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var joinedTrip: Trip?
    @State private var showingSuccess = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        Text("Join a Trip")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("Enter the invite code shared by your friend")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 40)
                    
                    // Code Input
                    VStack(spacing: 16) {
                        TextField("Enter Code", text: $inviteCode)
                            .font(.system(size: 32, weight: .bold, design: .monospaced))
                            .multilineTextAlignment(.center)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                            .foregroundColor(.white)
                            .onChange(of: inviteCode) { _, newValue in
                                // Limit to 6 characters and uppercase
                                inviteCode = String(newValue.uppercased().prefix(6))
                            }
                        
                        Text("6-character code")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal)
                    
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                            .padding(.horizontal)
                    }
                    
                    // Join Button
                    Button(action: joinTrip) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Join Trip")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(inviteCode.count == 6 ? Color.blue : Color.gray)
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .disabled(inviteCode.count != 6 || isLoading)
                    
                    Spacer()
                    
                    // Instructions
                    VStack(spacing: 8) {
                        Text("Don't have a code?")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text("Ask your friend to share their trip's invite code from the Members tab.")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
            }
            .preferredColorScheme(.dark)
            .alert("Success!", isPresented: $showingSuccess) {
                Button("View Trip") {
                    dismiss()
                }
            } message: {
                if let trip = joinedTrip {
                    Text("You've joined \"\(trip.name)\"! You can now view and edit the trip details.")
                }
            }
        }
    }
    
    private func joinTrip() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let trip = try await firebaseManager.joinTripByInviteCode(inviteCode)
                await MainActor.run {
                    isLoading = false
                    joinedTrip = trip
                    showingSuccess = true
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

#Preview {
    JoinTripView()
        .environmentObject(FirebaseStorageManager.shared)
}
