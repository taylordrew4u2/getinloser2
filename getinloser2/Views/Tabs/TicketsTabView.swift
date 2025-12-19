import SwiftUI
import PhotosUI
import PDFKit

struct TicketsTabView: View {
    @EnvironmentObject var cloudKitManager: CloudKitManager
    
    let trip: Trip
    
    @State private var tickets: [TicketDocument] = []
    @State private var isLoading = true
    @State private var showingImagePicker = false
    @State private var showingDocumentPicker = false
    @State private var selectedImage: PhotosPickerItem?
    @State private var selectedTicket: TicketDocument?
    
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
                PhotosPicker(selection: $selectedImage, matching: .images) {
                    Label("Upload Photo", systemImage: "photo")
                }
                
                Button(action: { showingDocumentPicker = true }) {
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
        .task {
            await loadTickets()
        }
        .onChange(of: selectedImage) { _, newValue in
            if newValue != nil {
                uploadImage()
            }
        }
        .sheet(isPresented: $showingDocumentPicker) {
            DocumentPickerView { url in
                uploadDocument(url: url)
            }
        }
        .sheet(item: $selectedTicket) { ticket in
            TicketDetailView(ticket: ticket)
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
            let fetchedTickets = try await cloudKitManager.fetchTickets(for: trip.id)
            await MainActor.run {
                tickets = fetchedTickets
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
            
            do {
                if let data = try await selectedImage.loadTransferable(type: Data.self) {
                    let ticket = TicketDocument(
                        tripID: trip.id,
                        fileName: "ticket_\(Date().timeIntervalSince1970).jpg",
                        fileType: "image",
                        uploadedBy: cloudKitManager.currentUserID
                    )
                    
                    let savedTicket = try await cloudKitManager.uploadTicket(ticket, fileData: data)
                    
                    await MainActor.run {
                        tickets.append(savedTicket)
                        self.selectedImage = nil
                    }
                }
            } catch {
                print("Error uploading image: \(error)")
            }
        }
    }
    
    private func uploadDocument(url: URL) {
        Task {
            do {
                let data = try Data(contentsOf: url)
                
                let ticket = TicketDocument(
                    tripID: trip.id,
                    fileName: url.lastPathComponent,
                    fileType: "pdf",
                    uploadedBy: cloudKitManager.currentUserID
                )
                
                let savedTicket = try await cloudKitManager.uploadTicket(ticket, fileData: data)
                
                await MainActor.run {
                    tickets.append(savedTicket)
                }
            } catch {
                print("Error uploading document: \(error)")
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
    @EnvironmentObject var cloudKitManager: CloudKitManager
    
    let ticket: TicketDocument
    
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
                try await cloudKitManager.deleteTicket(ticket)
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
    .environmentObject(CloudKitManager.shared)
}
