import SwiftUI
import PhotosUI
import PDFKit

struct TicketsTabView: View {
    @EnvironmentObject var firebaseManager: FirebaseStorageManager
    
    let trip: Trip
    
    @State private var isLoading = true
    @State private var showingImagePicker = false
    @State private var showingDocumentPicker = false
    @State private var selectedImage: PhotosPickerItem?
    @State private var selectedTicket: TicketDocument?
    @State private var isUploading = false
    @State private var uploadError: String?
    @State private var showingErrorAlert = false
    @State private var showingPhotoPicker = false
    
    // Use cached data for live updates
    private var tickets: [TicketDocument] {
        firebaseManager.ticketsCache[trip.id] ?? []
    }
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
            } else if tickets.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        ForEach(tickets) { ticket in
                            TicketCardView(ticket: ticket)
                                .onTapGesture {
                                    selectedTicket = ticket
                                }
                        }
                    }
                    .padding()
                }
            }
        }
        .overlay(alignment: .bottomTrailing) {
            Menu {
                Button(action: { 
                    showingPhotoPicker = true
                }) {
                    Label("Upload Photo", systemImage: "photo")
                }
                
                Button(action: { 
                    showingDocumentPicker = true 
                }) {
                    Label("Upload PDF", systemImage: "doc.fill")
                }
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 56))
                    .foregroundColor(.blue)
                    .background(Color.black)
                    .clipShape(Circle())
            }
            .padding()
        }
        .photosPicker(isPresented: $showingPhotoPicker, selection: $selectedImage, matching: .images)
        .task {
            await loadTickets()
        }
        .refreshable {
            await loadTickets()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            Task {
                await loadTickets()
            }
        }
        .onChange(of: selectedImage) { oldValue, newValue in
            // Only upload when a new image is selected (not when clearing)
            if oldValue == nil && newValue != nil {
                uploadImage()
            }
        }
        .sheet(isPresented: $showingDocumentPicker) {
            DocumentPickerView { url in
                uploadDocument(url: url)
            }
        }
        .sheet(item: $selectedTicket) { ticket in
            TicketDetailView(ticket: ticket, tripID: trip.id)
        }
        .alert("Upload Error", isPresented: $showingErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            if let uploadError = uploadError {
                Text(uploadError)
            }
        }
        .overlay {
            if isUploading {
                ZStack {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 16) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                            .scaleEffect(1.5)
                        
                        Text("Uploading ticket...")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .padding(32)
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "ticket")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Tickets Yet")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            Text("Upload flight tickets and travel documents")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
    
    private func loadTickets() async {
        do {
            _ = try await firebaseManager.fetchTickets(for: trip.id)
            await MainActor.run {
                isLoading = false
            }
        } catch {
            print("Error loading tickets: \(error)")
            await MainActor.run {
                isLoading = false
            }
        }
    }
    
    private func uploadImage() {
        Task {
            guard let selectedImage = selectedImage else { return }
            
            await MainActor.run {
                isUploading = true
            }
            
            do {
                print("📸 Starting photo upload...")
                
                if let data = try await selectedImage.loadTransferable(type: Data.self) {
                    print("✅ Loaded image data: \(data.count) bytes")
                    
                    let ticket = TicketDocument(
                        tripID: trip.id,
                        fileName: "ticket_\(Date().timeIntervalSince1970).jpg",
                        fileType: "image",
                        uploadedBy: firebaseManager.currentUserID
                    )
                    
                    print("📤 Uploading to CloudKit...")
                    let savedTicket = try await firebaseManager.uploadTicket(ticket, fileData: data)
                    print("✅ Upload successful! Record: \(savedTicket.recordName ?? "unknown")")
                    
                    await MainActor.run {
                        self.selectedImage = nil
                        isUploading = false
                    }
                } else {
                    throw NSError(domain: "TicketUpload", code: 1, 
                                userInfo: [NSLocalizedDescriptionKey: "Failed to load image data"])
                }
            } catch {
                print("❌ Error uploading image: \(error)")
                await MainActor.run {
                    uploadError = "Failed to upload photo: \(error.localizedDescription)"
                    showingErrorAlert = true
                    isUploading = false
                    self.selectedImage = nil
                }
            }
        }
    }
    
    private func uploadDocument(url: URL) {
        Task {
            await MainActor.run {
                isUploading = true
            }
            
            do {
                // Start accessing the security-scoped resource
                guard url.startAccessingSecurityScopedResource() else {
                    throw NSError(domain: "TicketUpload", code: 2,
                                userInfo: [NSLocalizedDescriptionKey: "Couldn't access the selected file"])
                }
                
                // Ensure we stop accessing when done
                defer {
                    url.stopAccessingSecurityScopedResource()
                }
                
                let data = try Data(contentsOf: url)
                
                let ticket = TicketDocument(
                    tripID: trip.id,
                    fileName: url.lastPathComponent,
                    fileType: "pdf",
                    uploadedBy: firebaseManager.currentUserID
                )
                
                _ = try await firebaseManager.uploadTicket(ticket, fileData: data)
                
                await MainActor.run {
                    isUploading = false
                }
            } catch {
                print("Error uploading document: \(error)")
                await MainActor.run {
                    uploadError = "Failed to upload PDF: \(error.localizedDescription)"
                    showingErrorAlert = true
                    isUploading = false
                }
            }
        }
    }
}

struct TicketCardView: View {
    let ticket: TicketDocument
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.05))
                    .frame(height: 150)
                
                Image(systemName: ticket.fileType == "image" ? "photo" : "doc.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.blue)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(ticket.fileName)
                    .font(.caption)
                    .foregroundColor(.white)
                    .lineLimit(2)
                
                Text(ticket.uploadDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct DocumentPickerView: UIViewControllerRepresentable {
    let onDocumentPicked: (URL) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf])
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onDocumentPicked: onDocumentPicked)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onDocumentPicked: (URL) -> Void
        
        init(onDocumentPicked: @escaping (URL) -> Void) {
            self.onDocumentPicked = onDocumentPicked
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            onDocumentPicked(url)
        }
    }
}

struct TicketDetailView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var firebaseManager: FirebaseStorageManager
    
    let ticket: TicketDocument
    let tripID: String
    
    @State private var showingDeleteAlert = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                VStack {
                    if ticket.fileType == "image" {
                        AsyncImage(url: ticket.assetURL) { image in
                            image
                                .resizable()
                                .scaledToFit()
                        } placeholder: {
                            ProgressView()
                        }
                    } else {
                        VStack(spacing: 20) {
                            Image(systemName: "doc.fill")
                                .font(.system(size: 80))
                                .foregroundColor(.blue)
                            
                            Text(ticket.fileName)
                                .font(.headline)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                        }
                    }
                }
            }
            .navigationTitle("Ticket")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(role: .destructive, action: { showingDeleteAlert = true }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                }
            }
            .alert("Delete Ticket", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteTicket()
                }
            } message: {
                Text("Are you sure you want to delete this ticket?")
            }
            .preferredColorScheme(.dark)
        }
    }
    
    private func deleteTicket() {
        Task {
            do {
                try await firebaseManager.deleteTicket(ticket)
                await MainActor.run {
                    dismiss()
                }
            } catch {
                print("Error deleting ticket: \(error)")
            }
        }
    }
}

#Preview {
    TicketsTabView(trip: Trip(
        name: "Tokyo Adventure",
        location: "Tokyo, Japan",
        startDate: Date(),
        endDate: Date().addingTimeInterval(86400 * 7),
        ownerID: "user123"
    ))
    .environmentObject(FirebaseStorageManager.shared)
}
