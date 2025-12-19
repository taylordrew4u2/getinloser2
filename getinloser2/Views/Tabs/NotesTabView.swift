import SwiftUI

struct NotesTabView: View {
    @EnvironmentObject var cloudKitManager: CloudKitManager
    
    let trip: Trip
    
    @State private var note: TripNote?
    @State private var noteText = ""
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var saveTask: Task<Void, Never>?
    @FocusState private var isTextEditorFocused: Bool
    
    // Use cached note for live updates
    private var cachedNote: TripNote? {
        cloudKitManager.notesCache[trip.id]
    }
    
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
                            scheduleNoteSave()
                        }
                    
                    if let displayNote = note ?? cachedNote {
                        HStack {
                            Text("Last edited: \(displayNote.lastModifiedDate.formatted(date: .abbreviated, time: .shortened))")
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
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(.green)
                                Text("Saved")
                                    .font(.caption)
                                    .foregroundColor(.green)
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
        .refreshable {
            await loadNote()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            Task {
                await refreshNoteFromCloud()
            }
        }
        .onChange(of: cachedNote?.content) { _, newContent in
            // Update local text if changed by another user (and we're not currently editing)
            if let newContent = newContent, !isTextEditorFocused, newContent != noteText {
                noteText = newContent
            }
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
    
    private func refreshNoteFromCloud() async {
        do {
            if let existingNote = try await cloudKitManager.fetchNote(for: trip.id) {
                await MainActor.run {
                    // Only update if we're not currently focused (editing)
                    if !isTextEditorFocused {
                        note = existingNote
                        noteText = existingNote.content
                    }
                }
            }
        } catch {
            print("Error refreshing note: \(error)")
        }
    }
    
    private func scheduleNoteSave() {
        // Cancel any existing save task
        saveTask?.cancel()
        
        // Schedule a new save after a delay (debounce)
        saveTask = Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 second delay
            
            guard !Task.isCancelled else { return }
            
            await saveNote()
        }
    }
    
    private func saveNote() async {
        guard var currentNote = note ?? cachedNote else { return }
        
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
