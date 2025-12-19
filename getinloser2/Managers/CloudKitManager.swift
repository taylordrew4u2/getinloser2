import Foundation
import CloudKit
import Combine
import UIKit

@MainActor
class CloudKitManager: ObservableObject {
    static let shared = CloudKitManager()
    
    @Published var trips: [Trip] = []
    @Published var currentUserID: String = ""
    @Published var isLoading = true
    @Published var error: String?
    @Published var iCloudStatus: CKAccountStatus = .couldNotDetermine
    @Published var isSignedIn: Bool = true  // Default to true - we'll work without iCloud if needed
    
    // Cache for trip-specific data - @Published for live updates
    @Published var eventsCache: [String: [ItineraryEvent]] = [:]
    @Published var todosCache: [String: [TodoItem]] = [:]
    @Published var notesCache: [String: TripNote] = [:]
    @Published var ticketsCache: [String: [TicketDocument]] = [:]
    @Published var iouCache: [String: [IOUEntry]] = [:] // Cache IOU entries by trip ID
    @Published var membersCache: [String: TripMember] = [:] // Keyed by userRecordID
    
    private let container: CKContainer
    private let publicDatabase: CKDatabase
    
    // Local storage keys
    private let localTripsKey = "localTrips"
    
    private init() {
        container = CKContainer.default()
        publicDatabase = container.publicCloudDatabase
        
        // Generate a device-based user ID immediately
        if let deviceID = UIDevice.current.identifierForVendor?.uuidString {
            currentUserID = deviceID
        } else {
            currentUserID = UUID().uuidString
        }
        
        setupAppLifecycleObservers()
        
        Task {
            await checkAccountStatus()
            await fetchTrips()
            isLoading = false
        }
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
        
        NotificationCenter.default.addObserver(
            forName: .CKAccountChanged,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.checkAccountStatus()
            }
        }
    }
    
    // MARK: - Account Status
    
    func checkAccountStatus() async {
        do {
            let status = try await container.accountStatus()
            iCloudStatus = status
            
            if status == .available {
                // Try to get the real user ID
                do {
                    let userRecord = try await container.userRecordID()
                    currentUserID = userRecord.recordName
                } catch {
                    print("Could not get iCloud user ID, using device ID")
                }
            }
            
            // Always allow app usage
            isSignedIn = true
            error = nil
            
        } catch {
            print("Error checking account status: \(error)")
            // Still allow app usage
            isSignedIn = true
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
        } catch {
            print("Error refreshing trip data: \(error)")
        }
    }
    
    // MARK: - Trip Management
    
    func fetchTrips() async {
        do {
            // Try to fetch from CloudKit
            let predicate = NSPredicate(format: "memberIDs CONTAINS %@", currentUserID)
            let query = CKQuery(recordType: "Trip", predicate: predicate)
            query.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: false)]
            
            let result = try await publicDatabase.records(matching: query)
            
            let fetchedTrips = result.matchResults.compactMap { (_, recordResult) -> Trip? in
                guard let record = try? recordResult.get() else { return nil }
                return Trip(record: record)
            }
            
            trips = fetchedTrips
            error = nil
        } catch {
            print("Error fetching trips from CloudKit: \(error)")
            // Load from local storage as fallback
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
            // Try to save to CloudKit
            let record = newTrip.toCKRecord()
            let savedRecord = try await publicDatabase.save(record)
            newTrip.recordName = savedRecord.recordID.recordName
            
            trips.append(newTrip)
            saveLocalTrips()
            
            return newTrip
        } catch {
            print("CloudKit save failed: \(error)")
            
            // Save locally as fallback
            newTrip.recordName = newTrip.id
            trips.append(newTrip)
            saveLocalTrips()
            
            // Re-throw with better error message
            throw NSError(domain: "CloudKit", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Trip saved locally. Sign in to iCloud to sync with others."
            ])
        }
    }
    
    func updateTrip(_ trip: Trip) async throws {
        do {
            let record = trip.toCKRecord()
            _ = try await publicDatabase.save(record)
        } catch {
            print("CloudKit update failed: \(error)")
        }
        
        if let index = trips.firstIndex(where: { $0.id == trip.id }) {
            trips[index] = trip
        }
        saveLocalTrips()
    }
    
    func deleteTrip(_ trip: Trip) async throws {
        if let recordName = trip.recordName {
            do {
                let recordID = CKRecord.ID(recordName: recordName)
                _ = try await publicDatabase.deleteRecord(withID: recordID)
            } catch {
                print("CloudKit delete failed: \(error)")
            }
        }
        
        trips.removeAll { $0.id == trip.id }
        eventsCache.removeValue(forKey: trip.id)
        todosCache.removeValue(forKey: trip.id)
        notesCache.removeValue(forKey: trip.id)
        ticketsCache.removeValue(forKey: trip.id)
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
            // Create a reference predicate for querying
            let tripRecordID = CKRecord.ID(recordName: tripID)
            let tripReference = CKRecord.Reference(recordID: tripRecordID, action: .none)
            let predicate = NSPredicate(format: "tripID == %@", tripReference)
            let query = CKQuery(recordType: "ItineraryEvent", predicate: predicate)
            // Sort client-side to avoid CloudKit schema issues
            // query.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
            
            let result = try await publicDatabase.records(matching: query)
            
            var events: [ItineraryEvent] = result.matchResults.compactMap { _, recordResult in
                guard let record = try? recordResult.get() else { return nil }
                return ItineraryEvent(record: record)
            }
            
            // Sort locally by date and time
            events.sort { ($0.date, $0.time) < ($1.date, $1.time) }
            
            eventsCache[tripID] = events
            return events
        } catch {
            print("Error fetching events from CloudKit: \(error.localizedDescription)")
            // Return cached data if available
            return eventsCache[tripID] ?? []
        }
    }
    
    func createEvent(_ event: ItineraryEvent) async throws -> ItineraryEvent {
        var newEvent = event
        let record = newEvent.toCKRecord()
        
        do {
            let savedRecord = try await publicDatabase.save(record)
            newEvent.recordName = savedRecord.recordID.recordName
        } catch {
            print("CloudKit event save failed: \(error)")
            newEvent.recordName = newEvent.id
        }
        
        var events = eventsCache[event.tripID] ?? []
        events.append(newEvent)
        events.sort { ($0.date, $0.time) < ($1.date, $1.time) }
        eventsCache[event.tripID] = events
        
        await NotificationManager.shared.scheduleEventNotification(for: newEvent)
        
        return newEvent
    }
    
    func updateEvent(_ event: ItineraryEvent) async throws {
        let record = event.toCKRecord()
        
        do {
            _ = try await publicDatabase.save(record)
        } catch {
            print("CloudKit event update failed: \(error)")
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
        if let recordName = event.recordName {
            do {
                let recordID = CKRecord.ID(recordName: recordName)
                _ = try await publicDatabase.deleteRecord(withID: recordID)
            } catch {
                print("CloudKit event delete failed: \(error)")
            }
        }
        
        if var events = eventsCache[event.tripID] {
            events.removeAll { $0.id == event.id }
            eventsCache[event.tripID] = events
        }
        
        NotificationManager.shared.cancelEventNotification(eventID: event.id)
    }
    
    // MARK: - Todo Items
    
    func fetchTodos(for tripID: String) async throws -> [TodoItem] {
        // Create a reference predicate for querying
        let tripRecordID = CKRecord.ID(recordName: tripID)
        let tripReference = CKRecord.Reference(recordID: tripRecordID, action: .none)
        let predicate = NSPredicate(format: "tripID == %@", tripReference)
        let query = CKQuery(recordType: "TodoItem", predicate: predicate)
        
        do {
            let result = try await publicDatabase.records(matching: query)
            
            let todos: [TodoItem] = result.matchResults.compactMap { _, recordResult in
                guard let record = try? recordResult.get() else { return nil }
                return TodoItem(record: record)
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
        let record = newTodo.toCKRecord()
        
        do {
            let savedRecord = try await publicDatabase.save(record)
            newTodo.recordName = savedRecord.recordID.recordName
        } catch {
            print("CloudKit todo save failed: \(error)")
            newTodo.recordName = newTodo.id
        }
        
        var todos = todosCache[todo.tripID] ?? []
        todos.append(newTodo)
        todosCache[todo.tripID] = todos
        
        return newTodo
    }
    
    func updateTodo(_ todo: TodoItem) async throws {
        let record = todo.toCKRecord()
        
        do {
            _ = try await publicDatabase.save(record)
        } catch {
            print("CloudKit todo update failed: \(error)")
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
        if let recordName = todo.recordName {
            do {
                let recordID = CKRecord.ID(recordName: recordName)
                _ = try await publicDatabase.deleteRecord(withID: recordID)
            } catch {
                print("CloudKit todo delete failed: \(error)")
            }
        }
        
        if var todos = todosCache[todo.tripID] {
            todos.removeAll { $0.id == todo.id }
            todosCache[todo.tripID] = todos
        }
    }
    
    // MARK: - Notes
    
    func fetchNote(for tripID: String) async throws -> TripNote? {
        // Create a reference predicate for querying
        let tripRecordID = CKRecord.ID(recordName: tripID)
        let tripReference = CKRecord.Reference(recordID: tripRecordID, action: .none)
        let predicate = NSPredicate(format: "tripID == %@", tripReference)
        let query = CKQuery(recordType: "TripNote", predicate: predicate)
        
        do {
            let result = try await publicDatabase.records(matching: query)
            
            let notes: [TripNote] = result.matchResults.compactMap { _, recordResult in
                guard let record = try? recordResult.get() else { return nil }
                return TripNote(record: record)
            }
            
            if let note = notes.first {
                notesCache[tripID] = note
            }
            return notes.first
        } catch {
            print("Error fetching note: \(error)")
            return notesCache[tripID]
        }
    }
    
    func saveNote(_ note: TripNote) async throws -> TripNote {
        var updatedNote = note
        let record = updatedNote.toCKRecord()
        
        do {
            let savedRecord = try await publicDatabase.save(record)
            updatedNote.recordName = savedRecord.recordID.recordName
        } catch {
            print("CloudKit note save failed: \(error)")
            updatedNote.recordName = updatedNote.id
        }
        
        notesCache[note.tripID] = updatedNote
        
        return updatedNote
    }
    
    // MARK: - Tickets
    
    func fetchTickets(for tripID: String) async throws -> [TicketDocument] {
        do {
            // Create a reference predicate for querying
            let tripRecordID = CKRecord.ID(recordName: tripID)
            let tripReference = CKRecord.Reference(recordID: tripRecordID, action: .none)
            let predicate = NSPredicate(format: "tripID == %@", tripReference)
            let query = CKQuery(recordType: "TicketDocument", predicate: predicate)
            // Sort client-side to avoid CloudKit schema issues
            // query.sortDescriptors = [NSSortDescriptor(key: "uploadDate", ascending: false)]
            
            let result = try await publicDatabase.records(matching: query)
            
            var tickets: [TicketDocument] = result.matchResults.compactMap { _, recordResult in
                guard let record = try? recordResult.get() else { return nil }
                return TicketDocument(record: record)
            }
            
            // Sort locally by upload date
            tickets.sort { $0.uploadDate > $1.uploadDate }
            
            ticketsCache[tripID] = tickets
            return tickets
        } catch {
            print("Error fetching tickets from CloudKit: \(error.localizedDescription)")
            return ticketsCache[tripID] ?? []
        }
    }
    
    func uploadTicket(_ ticket: TicketDocument, fileData: Data) async throws -> TicketDocument {
        print("📝 CloudKitManager: Starting ticket upload")
        print("   Trip ID: \(ticket.tripID)")
        print("   File name: \(ticket.fileName)")
        print("   File type: \(ticket.fileType)")
        print("   File size: \(fileData.count) bytes")
        
        var newTicket = ticket
        let record = newTicket.toCKRecord(fileData: fileData)
        
        // Actually throw errors instead of swallowing them
        print("☁️ Saving to CloudKit...")
        let savedRecord = try await publicDatabase.save(record)
        newTicket.recordName = savedRecord.recordID.recordName
        print("✅ CloudKit save successful!")
        
        // Only update cache if save succeeded
        var tickets = ticketsCache[ticket.tripID] ?? []
        tickets.insert(newTicket, at: 0)
        ticketsCache[ticket.tripID] = tickets
        print("✅ Cache updated with \(tickets.count) tickets")
        
        return newTicket
    }
    
    func deleteTicket(_ ticket: TicketDocument) async throws {
        if let recordName = ticket.recordName {
            do {
                let recordID = CKRecord.ID(recordName: recordName)
                _ = try await publicDatabase.deleteRecord(withID: recordID)
            } catch {
                print("CloudKit ticket delete failed: \(error)")
            }
        }
        
        if var tickets = ticketsCache[ticket.tripID] {
            tickets.removeAll { $0.id == ticket.id }
            ticketsCache[ticket.tripID] = tickets
        }
    }
    
    // MARK: - Members
    
    func fetchMembers(memberIDs: [String]) async throws -> [TripMember] {
        guard !memberIDs.isEmpty else { return [] }
        
        // If all members are already cached, return them in the same order
        let cached = memberIDs.compactMap { membersCache[$0] }
        if cached.count == memberIDs.count {
            return cached
        }
        
        // Fetch TripMember records whose userRecordID is in memberIDs
        let predicate = NSPredicate(format: "userRecordID IN %@", memberIDs)
        let query = CKQuery(recordType: "TripMember", predicate: predicate)
        
        do {
            let result = try await publicDatabase.records(matching: query)
            let fetched: [TripMember] = result.matchResults.compactMap { _, recordResult in
                guard let record = try? recordResult.get() else { return nil }
                return TripMember(record: record)
            }
            
            // Update cache
            for m in fetched {
                membersCache[m.userRecordID] = m
            }
            
            // Merge cached + fetched and preserve the order of memberIDs
            let lookup: [String: TripMember] = memberIDs.reduce(into: [:]) { dict, id in
                if let cachedMember = membersCache[id] { dict[id] = cachedMember }
            }
            return memberIDs.compactMap { lookup[$0] }
        } catch {
            print("Error fetching members: \(error)")
            // Fallback: return whatever we have cached in the requested order
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
        let predicate = NSPredicate(format: "inviteCode == %@", normalizedCode)
        let query = CKQuery(recordType: "Trip", predicate: predicate)
        
        do {
            let result = try await publicDatabase.records(matching: query)
            
            let foundTrips = result.matchResults.compactMap { (_, recordResult) -> Trip? in
                guard let record = try? recordResult.get() else { return nil }
                return Trip(record: record)
            }
            
            return foundTrips.first
        } catch {
            print("Error finding trip by invite code: \(error)")
            return nil
        }
    }
    
    func joinTripByInviteCode(_ code: String) async throws -> Trip {
        guard !currentUserID.isEmpty else {
            throw NSError(domain: "CloudKit", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to identify user."])
        }
        
        guard let trip = try await findTripByInviteCode(code) else {
            throw NSError(domain: "CloudKit", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid invite code. Please check and try again."])
        }
        
        if trip.memberIDs.contains(currentUserID) {
            throw NSError(domain: "CloudKit", code: -1, userInfo: [NSLocalizedDescriptionKey: "You're already a member of this trip!"])
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
            let tripRecordID = CKRecord.ID(recordName: tripID)
            let tripReference = CKRecord.Reference(recordID: tripRecordID, action: .none)
            let predicate = NSPredicate(format: "tripID == %@", tripReference)
            let query = CKQuery(recordType: "IOUEntry", predicate: predicate)
            
            let result = try await publicDatabase.records(matching: query)
            
            var entries: [IOUEntry] = result.matchResults.compactMap { _, recordResult in
                guard let record = try? recordResult.get() else { return nil }
                return IOUEntry(record: record)
            }
            
            // Sort by last modified date
            entries.sort { $0.lastModifiedDate > $1.lastModifiedDate }
            
            iouCache[tripID] = entries
            return entries
        } catch {
            print("Error fetching IOU entries from CloudKit: \(error.localizedDescription)")
            return iouCache[tripID] ?? []
        }
    }
    
    func saveIOUEntry(_ entry: IOUEntry) async throws -> IOUEntry {
        var newEntry = entry
        newEntry.lastModifiedDate = Date()
        let record = newEntry.toCKRecord()
        
        let savedRecord = try await publicDatabase.save(record)
        newEntry.recordName = savedRecord.recordID.recordName
        
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
        if let recordName = entry.recordName {
            do {
                let recordID = CKRecord.ID(recordName: recordName)
                _ = try await publicDatabase.deleteRecord(withID: recordID)
            } catch {
                print("CloudKit IOU delete failed: \(error)")
            }
        }
        
        if var entries = iouCache[entry.tripID] {
            entries.removeAll { $0.id == entry.id }
            iouCache[entry.tripID] = entries
        }
    }
    
    // MARK: - Handle Remote Notifications
    
    func handleRemoteNotification(userInfo: [AnyHashable: Any]) async {
        await refreshAllData()
    }
}

