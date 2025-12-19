import SwiftUI

struct NotesTabView: View {
    @EnvironmentObject var cloudKitManager: CloudKitManager
    
    let trip: Trip
    
    @State private var note: TripNote?
    @State private var noteText = ""
    @State private var isLoading = true
    @State private var isSaving = false
    @FocusState private var isTextEditorFocused: Bool
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                } else {
                    TextEditor(text: $noteText)
                        .focused($isTextEditorFocused)
                        .padding()
                        .foregroundColor(.white)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .onChange(of: noteText) { _, _ in
                            saveNote()
                        }
                    
                    if let note = note {
                        HStack {
                            Text("Last edited: \(note.lastModifiedDate.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption)
                                .foregroundColor(.gray)
                            
                            Spacer()
                            
                            if isSaving {
                                HStack(spacing: 4) {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                        .scaleEffect(0.7)
                                    
                                    Text("Saving...")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .padding()
                        .background(Color.white.opacity(0.05))
                    }
                }
            }
        }
        .task {
            await loadNote()
        }
    }
    
    private func loadNote() async {
        do {
            if let existingNote = try await cloudKitManager.fetchNote(for: trip.id) {
                await MainActor.run {
                    note = existingNote
                    noteText = existingNote.content
                    isLoading = false
                }
            } else {
                // Create a new note
                let newNote = TripNote(
                    tripID: trip.id,
                    content: "",
                    lastModifiedBy: cloudKitManager.currentUserID
                )
                
                let savedNote = try await cloudKitManager.saveNote(newNote)
                
                await MainActor.run {
                    note = savedNote
                    isLoading = false
                }
            }
        } catch {
            print("Error loading note: \(error)")
            await MainActor.run {
                isLoading = false
            }
        }
    }
    
    private func saveNote() {
        guard var currentNote = note else { return }
        
        // Debounce save operation
        Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            await MainActor.run {
                isSaving = true
            }
            
            currentNote.content = noteText
            currentNote.lastModifiedBy = cloudKitManager.currentUserID
            currentNote.lastModifiedDate = Date()
            
            do {
                let savedNote = try await cloudKitManager.saveNote(currentNote)
                
                await MainActor.run {
                    note = savedNote
                    isSaving = false
                }
            } catch {
                print("Error saving note: \(error)")
                await MainActor.run {
                    isSaving = false
                }
            }
        }
    }
}

#Preview {
    NotesTabView(trip: Trip(
        name: "Tokyo Adventure",
        location: "Tokyo, Japan",
        startDate: Date(),
        endDate: Date().addingTimeInterval(86400 * 7),
        ownerID: "user123"
    ))
    .environmentObject(CloudKitManager.shared)
}
