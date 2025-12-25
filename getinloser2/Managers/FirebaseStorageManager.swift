import Foundation
import FirebaseCore
import FirebaseFirestore
import FirebaseStorage
import Combine
import UIKit

@MainActor
class FirebaseStorageManager: ObservableObject {
    static let shared = FirebaseStorageManager()
    
    @Published var trips: [Trip] = []
    @Published var currentUserID: String = ""
    @Published var isLoading = true
    @Published var error: String?
    @Published var isSignedIn: Bool = true
    
    // Cache for trip-specific data - @Published for live updates
    @Published var eventsCache: [String: [ItineraryEvent]] = [:]
    @Published var todosCache: [String: [TodoItem]] = [:]
    @Published var notesCache: [String: TripNote] = [:]
    @Published var ticketsCache: [String: [TicketDocument]] = [:]
    @Published var iouCache: [String: [IOUEntry]] = [:]
    @Published var membersCache: [String: TripMember] = [:]
    
    private let db: Firestore
    private let storage: Storage
    
    // Local storage keys
    private let localTripsKey = "localTrips"
    
    // Firestore listeners
    private var tripsListener: ListenerRegistration?
    private var tripListeners: [String: ListenerRegistration] = [:]
    
    private init() {
        FirebaseApp.configure()
        db = Firestore.firestore()
        storage = Storage.storage()
        
        // Generate a device-based user ID
        if let deviceID = UIDevice.current.identifierForVendor?.uuidString {
            currentUserID = deviceID
        } else {
            currentUserID = UUID().uuidString
        }
        
        setupAppLifecycleObservers()
        
        Task {
            await fetchTrips()
            isLoading = false
        }
    }
    
    deinit {
        tripsListener?.remove()
        tripListeners.values.forEach { $0.remove() }
    }
    
    // MARK: - App Lifecycle
    
    private func setupAppLifecycleObservers() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.refreshAllData()
            }
        }
    }
    
    // MARK: - Refresh All Data
    
    func refreshAllData() async {
        await fetchTrips()
        
        for trip in trips {
            await refreshTripData(tripID: trip.id)
        }
    }
    
    func refreshTripData(tripID: String) async {
        do {
            let events = try await fetchEvents(for: tripID)
            eventsCache[tripID] = events
            
            let todos = try await fetchTodos(for: tripID)
            todosCache[tripID] = todos
            
            if let note = try await fetchNote(for: tripID) {
                notesCache[tripID] = note
            }
            
            let tickets = try await fetchTickets(for: tripID)
            ticketsCache[tripID] = tickets
            
            let ious = try await fetchIOUEntries(for: tripID)
            iouCache[tripID] = ious
        } catch {
            print("Error refreshing trip data: \(error)")
        }
    }
    
    // MARK: - Trip Management
    
    func fetchTrips() async {
        do {
            let snapshot = try await db.collection("trips")
                .whereField("memberIDs", arrayContains: currentUserID)
                .order(by: "startDate", descending: true)
                .getDocuments()
            
            trips = snapshot.documents.compactMap { doc in
                try? doc.data(as: Trip.self)
            }
            error = nil
        } catch {
            print("Error fetching trips from Firestore: \(error)")
            loadLocalTrips()
        }
    }
    
    func createTrip(_ trip: Trip) async throws -> Trip {
        var newTrip = trip
        
        // Ensure current user is in memberIDs
        if !newTrip.memberIDs.contains(currentUserID) {
            newTrip.memberIDs.append(currentUserID)
        }
        
        // Ensure ownerID is set
        if newTrip.ownerID.isEmpty {
            newTrip.ownerID = currentUserID
        }
        
        do {
            try db.collection("trips").document(newTrip.id).setData(from: newTrip)
            trips.append(newTrip)
            saveLocalTrips()
            return newTrip
        } catch {
            print("Firestore save failed: \(error)")
            
            // Save locally as fallback
            trips.append(newTrip)
            saveLocalTrips()
            
            throw NSError(domain: "Firestore", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Trip saved locally. Connect to internet to sync with others."
            ])
        }
    }
    
    func updateTrip(_ trip: Trip) async throws {
        do {
            try db.collection("trips").document(trip.id).setData(from: trip)
        } catch {
            print("Firestore update failed: \(error)")
        }
        
        if let index = trips.firstIndex(where: { $0.id == trip.id }) {
            trips[index] = trip
        }
        saveLocalTrips()
    }
    
    func deleteTrip(_ trip: Trip) async throws {
        do {
            try await db.collection("trips").document(trip.id).delete()
        } catch {
            print("Firestore delete failed: \(error)")
        }
        
        trips.removeAll { $0.id == trip.id }
        eventsCache.removeValue(forKey: trip.id)
        todosCache.removeValue(forKey: trip.id)
        notesCache.removeValue(forKey: trip.id)
        ticketsCache.removeValue(forKey: trip.id)
        iouCache.removeValue(forKey: trip.id)
        saveLocalTrips()
    }
    
    // MARK: - Local Storage
    
    private func saveLocalTrips() {
        if let encoded = try? JSONEncoder().encode(trips) {
            UserDefaults.standard.set(encoded, forKey: localTripsKey)
        }
    }
    
    private func loadLocalTrips() {
        if let data = UserDefaults.standard.data(forKey: localTripsKey),
           let decoded = try? JSONDecoder().decode([Trip].self, from: data) {
            trips = decoded
        }
    }
    
    // MARK: - Itinerary Events
    
    func fetchEvents(for tripID: String) async throws -> [ItineraryEvent] {
        do {
            let snapshot = try await db.collection("trips").document(tripID)
                .collection("events")
                .getDocuments()
            
            var events = snapshot.documents.compactMap { doc in
                try? doc.data(as: ItineraryEvent.self)
            }
            
            events.sort { ($0.date, $0.time) < ($1.date, $1.time) }
            eventsCache[tripID] = events
            return events
        } catch {
            print("Error fetching events from Firestore: \(error.localizedDescription)")
            return eventsCache[tripID] ?? []
        }
    }
    
    func createEvent(_ event: ItineraryEvent) async throws -> ItineraryEvent {
        var newEvent = event
        
        do {
            try db.collection("trips").document(event.tripID)
                .collection("events").document(newEvent.id)
                .setData(from: newEvent)
        } catch {
            print("Firestore event save failed: \(error)")
        }
        
        var events = eventsCache[event.tripID] ?? []
        events.append(newEvent)
        events.sort { ($0.date, $0.time) < ($1.date, $1.time) }
        eventsCache[event.tripID] = events
        
        await NotificationManager.shared.scheduleEventNotification(for: newEvent)
        
        return newEvent
    }
    
    func updateEvent(_ event: ItineraryEvent) async throws {
        do {
            try db.collection("trips").document(event.tripID)
                .collection("events").document(event.id)
                .setData(from: event)
        } catch {
            print("Firestore event update failed: \(error)")
        }
        
        if var events = eventsCache[event.tripID],
           let index = events.firstIndex(where: { $0.id == event.id }) {
            events[index] = event
            events.sort { ($0.date, $0.time) < ($1.date, $1.time) }
            eventsCache[event.tripID] = events
        }
        
        await NotificationManager.shared.scheduleEventNotification(for: event)
    }
    
    func deleteEvent(_ event: ItineraryEvent) async throws {
        do {
            try await db.collection("trips").document(event.tripID)
                .collection("events").document(event.id).delete()
        } catch {
            print("Firestore event delete failed: \(error)")
        }
        
        if var events = eventsCache[event.tripID] {
            events.removeAll { $0.id == event.id }
            eventsCache[event.tripID] = events
        }
        
        NotificationManager.shared.cancelEventNotification(eventID: event.id)
    }
    
    // MARK: - Todo Items
    
    func fetchTodos(for tripID: String) async throws -> [TodoItem] {
        do {
            let snapshot = try await db.collection("trips").document(tripID)
                .collection("todos")
                .getDocuments()
            
            let todos = snapshot.documents.compactMap { doc in
                try? doc.data(as: TodoItem.self)
            }
            
            todosCache[tripID] = todos
            return todos
        } catch {
            print("Error fetching todos: \(error)")
            return todosCache[tripID] ?? []
        }
    }
    
    func createTodo(_ todo: TodoItem) async throws -> TodoItem {
        var newTodo = todo
        
        do {
            try db.collection("trips").document(todo.tripID)
                .collection("todos").document(newTodo.id)
                .setData(from: newTodo)
        } catch {
            print("Firestore todo save failed: \(error)")
        }
        
        var todos = todosCache[todo.tripID] ?? []
        todos.append(newTodo)
        todosCache[todo.tripID] = todos
        
        return newTodo
    }
    
    func updateTodo(_ todo: TodoItem) async throws {
        do {
            try db.collection("trips").document(todo.tripID)
                .collection("todos").document(todo.id)
                .setData(from: todo)
        } catch {
            print("Firestore todo update failed: \(error)")
        }
        
        if var todos = todosCache[todo.tripID],
           let index = todos.firstIndex(where: { $0.id == todo.id }) {
            todos[index] = todo
            todosCache[todo.tripID] = todos
        }
    }
    
    func toggleTodoCompletion(_ todo: TodoItem, userID: String) async throws {
        var updatedTodo = todo
        updatedTodo.completedBy[userID] = !(updatedTodo.completedBy[userID] ?? false)
        try await updateTodo(updatedTodo)
    }
    
    func deleteTodo(_ todo: TodoItem) async throws {
        do {
            try await db.collection("trips").document(todo.tripID)
                .collection("todos").document(todo.id).delete()
        } catch {
            print("Firestore todo delete failed: \(error)")
        }
        
        if var todos = todosCache[todo.tripID] {
            todos.removeAll { $0.id == todo.id }
            todosCache[todo.tripID] = todos
        }
    }
    
    // MARK: - Notes
    
    func fetchNote(for tripID: String) async throws -> TripNote? {
        do {
            let snapshot = try await db.collection("trips").document(tripID)
                .collection("notes")
                .getDocuments()
            
            if let doc = snapshot.documents.first,
               let note = try? doc.data(as: TripNote.self) {
                notesCache[tripID] = note
                return note
            }
            return nil
        } catch {
            print("Error fetching note: \(error)")
            return notesCache[tripID]
        }
    }
    
    func saveNote(_ note: TripNote) async throws -> TripNote {
        var updatedNote = note
        
        do {
            try db.collection("trips").document(note.tripID)
                .collection("notes").document(updatedNote.id)
                .setData(from: updatedNote)
        } catch {
            print("Firestore note save failed: \(error)")
        }
        
        notesCache[note.tripID] = updatedNote
        
        return updatedNote
    }
    
    // MARK: - Tickets
    
    func fetchTickets(for tripID: String) async throws -> [TicketDocument] {
        do {
            let snapshot = try await db.collection("trips").document(tripID)
                .collection("tickets")
                .getDocuments()
            
            var tickets = snapshot.documents.compactMap { doc in
                try? doc.data(as: TicketDocument.self)
            }
            
            tickets.sort { $0.uploadDate > $1.uploadDate }
            
            ticketsCache[tripID] = tickets
            return tickets
        } catch {
            print("Error fetching tickets from Firestore: \(error.localizedDescription)")
            return ticketsCache[tripID] ?? []
        }
    }
    
    func uploadTicket(_ ticket: TicketDocument, fileData: Data) async throws -> TicketDocument {
        print("📝 FirebaseStorageManager: Starting ticket upload")
        print("   Trip ID: \(ticket.tripID)")
        print("   File name: \(ticket.fileName)")
        print("   File type: \(ticket.fileType)")
        print("   File size: \(fileData.count) bytes")
        
        var newTicket = ticket
        
        // Upload file to Cloud Storage
        let storageRef = storage.reference()
            .child("tickets")
            .child(ticket.tripID)
            .child("\(ticket.id)_\(ticket.fileName)")
        
        print("☁️ Uploading to Cloud Storage...")
        let metadata = StorageMetadata()
        metadata.contentType = ticket.fileType
        
        let _ = try await storageRef.putDataAsync(fileData, metadata: metadata)
        
        // Get download URL
        let downloadURL = try await storageRef.downloadURL()
        newTicket.fileURL = downloadURL.absoluteString
        
        print("✅ Cloud Storage upload successful!")
        print("   Download URL: \(downloadURL.absoluteString)")
        
        // Save metadata to Firestore
        try db.collection("trips").document(ticket.tripID)
            .collection("tickets").document(newTicket.id)
            .setData(from: newTicket)
        
        print("✅ Firestore metadata saved!")
        
        // Update cache
        var tickets = ticketsCache[ticket.tripID] ?? []
        tickets.insert(newTicket, at: 0)
        ticketsCache[ticket.tripID] = tickets
        print("✅ Cache updated with \(tickets.count) tickets")
        
        return newTicket
    }
    
    func deleteTicket(_ ticket: TicketDocument) async throws {
        // Delete from Cloud Storage if URL exists
        if let urlString = ticket.fileURL, let url = URL(string: urlString) {
            do {
                let storageRef = storage.reference(forURL: url.absoluteString)
                try await storageRef.delete()
            } catch {
                print("Cloud Storage delete failed: \(error)")
            }
        }
        
        // Delete from Firestore
        do {
            try await db.collection("trips").document(ticket.tripID)
                .collection("tickets").document(ticket.id).delete()
        } catch {
            print("Firestore ticket delete failed: \(error)")
        }
        
        // Update cache
        if var tickets = ticketsCache[ticket.tripID] {
            tickets.removeAll { $0.id == ticket.id }
            ticketsCache[ticket.tripID] = tickets
        }
    }
    
    // MARK: - Members
    
    func fetchMembers(memberIDs: [String]) async throws -> [TripMember] {
        guard !memberIDs.isEmpty else { return [] }
        
        // Check cache first
        let cached = memberIDs.compactMap { membersCache[$0] }
        if cached.count == memberIDs.count {
            return cached
        }
        
        // Fetch from Firestore
        do {
            let snapshot = try await db.collection("members")
                .whereField("userRecordID", in: memberIDs)
                .getDocuments()
            
            let fetched = snapshot.documents.compactMap { doc in
                try? doc.data(as: TripMember.self)
            }
            
            // Update cache
            for m in fetched {
                membersCache[m.userRecordID] = m
            }
            
            // Return in order of memberIDs
            let lookup: [String: TripMember] = memberIDs.reduce(into: [:]) { dict, id in
                if let cachedMember = membersCache[id] { dict[id] = cachedMember }
            }
            return memberIDs.compactMap { lookup[$0] }
        } catch {
            print("Error fetching members: \(error)")
            return memberIDs.compactMap { membersCache[$0] }
        }
    }
    
    func addMember(_ member: TripMember, to trip: Trip) async throws {
        var updatedTrip = trip
        if !updatedTrip.memberIDs.contains(member.userRecordID) {
            updatedTrip.memberIDs.append(member.userRecordID)
            try await updateTrip(updatedTrip)
        }
    }
    
    func removeMember(_ memberID: String, from trip: Trip) async throws {
        var updatedTrip = trip
        updatedTrip.memberIDs.removeAll { $0 == memberID }
        try await updateTrip(updatedTrip)
    }
    
    // MARK: - Invite Code System
    
    func findTripByInviteCode(_ code: String) async throws -> Trip? {
        let normalizedCode = code.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        do {
            let snapshot = try await db.collection("trips")
                .whereField("inviteCode", isEqualTo: normalizedCode)
                .limit(to: 1)
                .getDocuments()
            
            if let doc = snapshot.documents.first {
                return try? doc.data(as: Trip.self)
            }
            return nil
        } catch {
            print("Error finding trip by invite code: \(error)")
            return nil
        }
    }
    
    func joinTripByInviteCode(_ code: String) async throws -> Trip {
        guard !currentUserID.isEmpty else {
            throw NSError(domain: "Firestore", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to identify user."])
        }
        
        guard let trip = try await findTripByInviteCode(code) else {
            throw NSError(domain: "Firestore", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid invite code. Please check and try again."])
        }
        
        if trip.memberIDs.contains(currentUserID) {
            throw NSError(domain: "Firestore", code: -1, userInfo: [NSLocalizedDescriptionKey: "You're already a member of this trip!"])
        }
        
        var updatedTrip = trip
        updatedTrip.memberIDs.append(currentUserID)
        try await updateTrip(updatedTrip)
        
        await fetchTrips()
        
        return updatedTrip
    }
    
    func getShareMessage(for trip: Trip) -> String {
        """
        Join my trip "\(trip.name)" on Get In Loser!
        
        📍 \(trip.location)
        📅 \(trip.startDate.formatted(date: .abbreviated, time: .omitted)) - \(trip.endDate.formatted(date: .abbreviated, time: .omitted))
        
        Use invite code: \(trip.inviteCode)
        
        Download the app and enter this code to join!
        """
    }
    
    // MARK: - IOU Entries
    
    func fetchIOUEntries(for tripID: String) async throws -> [IOUEntry] {
        do {
            let snapshot = try await db.collection("trips").document(tripID)
                .collection("iou")
                .getDocuments()
            
            var entries = snapshot.documents.compactMap { doc in
                try? doc.data(as: IOUEntry.self)
            }
            
            entries.sort { $0.lastModifiedDate > $1.lastModifiedDate }
            
            iouCache[tripID] = entries
            return entries
        } catch {
            print("Error fetching IOU entries from Firestore: \(error.localizedDescription)")
            return iouCache[tripID] ?? []
        }
    }
    
    func saveIOUEntry(_ entry: IOUEntry) async throws -> IOUEntry {
        var newEntry = entry
        newEntry.lastModifiedDate = Date()
        
        try db.collection("trips").document(entry.tripID)
            .collection("iou").document(newEntry.id)
            .setData(from: newEntry)
        
        // Update cache
        var entries = iouCache[entry.tripID] ?? []
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[index] = newEntry
        } else {
            entries.insert(newEntry, at: 0)
        }
        iouCache[entry.tripID] = entries
        
        return newEntry
    }
    
    func deleteIOUEntry(_ entry: IOUEntry) async throws {
        do {
            try await db.collection("trips").document(entry.tripID)
                .collection("iou").document(entry.id).delete()
        } catch {
            print("Firestore IOU delete failed: \(error)")
        }
        
        if var entries = iouCache[entry.tripID] {
            entries.removeAll { $0.id == entry.id }
            iouCache[entry.tripID] = entries
        }
    }
    
    // MARK: - Handle Remote Notifications (placeholder for Firebase Cloud Messaging)
    
    func handleRemoteNotification(userInfo: [AnyHashable: Any]) async {
        await refreshAllData()
    }
    
    // MARK: - Account Status (compatibility method)
    
    func checkAccountStatus() async {
        // Firebase doesn't require account status check like iCloud
        // Always allow app usage
        isSignedIn = true
        error = nil
    }
}
