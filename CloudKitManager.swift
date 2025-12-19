import Foundation
import CloudKit
import Combine

@MainActor
class CloudKitManager: ObservableObject {
    static let shared = CloudKitManager()
    
    @Published var trips: [Trip] = []
    @Published var currentUserID: String = ""
    @Published var isLoading = true
    @Published var error: String?
    
    private let container: CKContainer
    private let privateDatabase: CKDatabase
    private let sharedDatabase: CKDatabase
    private var subscriptionID = "trip-changes"
    
    private init() {
        container = CKContainer.default()
        privateDatabase = container.privateCloudDatabase
        sharedDatabase = container.sharedCloudDatabase
        
        Task {
            await fetchUserID()
            await setupSubscriptions()
            await fetchTrips()
            isLoading = false
        }
    }
    
    // MARK: - User Management
    
    func fetchUserID() async {
        do {
            let userRecord = try await container.userRecordID()
            currentUserID = userRecord.recordName
        } catch {
            print("Error fetching user ID: \(error)")
            self.error = "Failed to fetch user ID"
        }
    }
    
    // MARK: - Trip Management
    
    func fetchTrips() async {
        do {
            let query = CKQuery(recordType: "Trip", predicate: NSPredicate(value: true))
            query.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: false)]
            
            let result = try await sharedDatabase.records(matching: query)
            
            let fetchedTrips = result.matchResults.compactMap { (recordID, recordResult) -> Trip? in
                guard let record = try? recordResult.get() else { return nil }
                return Trip(record: record)
            }
            
            trips = fetchedTrips
        } catch {
            print("Error fetching trips: \(error)")
            self.error = "Failed to fetch trips"
        }
    }
    
    func createTrip(_ trip: Trip) async throws -> Trip {
        var newTrip = trip
        let record = newTrip.toCKRecord()
        
        let savedRecord = try await sharedDatabase.save(record)
        newTrip.recordName = savedRecord.recordID.recordName
        
        await MainActor.run {
            trips.append(newTrip)
        }
        
        // Notify all members
        await notifyTripMembers(tripID: newTrip.id, message: "New trip '\(newTrip.name)' has been created")
        
        return newTrip
    }
    
    func updateTrip(_ trip: Trip) async throws {
        let record = trip.toCKRecord()
        _ = try await sharedDatabase.save(record)
        
        await MainActor.run {
            if let index = trips.firstIndex(where: { $0.id == trip.id }) {
                trips[index] = trip
            }
        }
        
        await notifyTripMembers(tripID: trip.id, message: "Trip '\(trip.name)' has been updated")
    }
    
    func deleteTrip(_ trip: Trip) async throws {
        guard let recordName = trip.recordName else { return }
        let recordID = CKRecord.ID(recordName: recordName)
        
        _ = try await sharedDatabase.deleteRecord(withID: recordID)
        
        await MainActor.run {
            trips.removeAll { $0.id == trip.id }
        }
    }
    
    // MARK: - Itinerary Events
    
    func fetchEvents(for tripID: String) async throws -> [ItineraryEvent] {
        let predicate = NSPredicate(format: "tripID == %@", tripID)
        let query = CKQuery(recordType: "ItineraryEvent", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true), NSSortDescriptor(key: "time", ascending: true)]
        
        let result = try await sharedDatabase.records(matching: query)
        
        return result.matchResults.compactMap { (recordID, recordResult) -> ItineraryEvent? in
            guard let record = try? recordResult.get() else { return nil }
            return ItineraryEvent(record: record)
        }
    }
    
    func createEvent(_ event: ItineraryEvent) async throws -> ItineraryEvent {
        var newEvent = event
        let record = newEvent.toCKRecord()
        
        let savedRecord = try await sharedDatabase.save(record)
        newEvent.recordName = savedRecord.recordID.recordName
        
        await notifyTripMembers(tripID: event.tripID, message: "New event '\(event.name)' added to itinerary")
        
        // Schedule notification for event
        await NotificationManager.shared.scheduleEventNotification(for: newEvent)
        
        return newEvent
    }
    
    func updateEvent(_ event: ItineraryEvent) async throws {
        let record = event.toCKRecord()
        _ = try await sharedDatabase.save(record)
        
        await notifyTripMembers(tripID: event.tripID, message: "Event '\(event.name)' has been updated")
        
        // Reschedule notification
        await NotificationManager.shared.scheduleEventNotification(for: event)
    }
    
    func deleteEvent(_ event: ItineraryEvent) async throws {
        guard let recordName = event.recordName else { return }
        let recordID = CKRecord.ID(recordName: recordName)
        
        _ = try await sharedDatabase.deleteRecord(withID: recordID)
        
        await notifyTripMembers(tripID: event.tripID, message: "Event '\(event.name)' has been deleted")
        
        // Cancel notification
        NotificationManager.shared.cancelEventNotification(eventID: event.id)
    }
    
    // MARK: - Todo Items
    
    func fetchTodos(for tripID: String) async throws -> [TodoItem] {
        let predicate = NSPredicate(format: "tripID == %@", tripID)
        let query = CKQuery(recordType: "TodoItem", predicate: predicate)
        
        let result = try await sharedDatabase.records(matching: query)
        
        return result.matchResults.compactMap { (recordID, recordResult) -> TodoItem? in
            guard let record = try? recordResult.get() else { return nil }
            return TodoItem(record: record)
        }
    }
    
    func createTodo(_ todo: TodoItem) async throws -> TodoItem {
        var newTodo = todo
        let record = newTodo.toCKRecord()
        
        let savedRecord = try await sharedDatabase.save(record)
        newTodo.recordName = savedRecord.recordID.recordName
        
        await notifyTripMembers(tripID: todo.tripID, message: "New todo item added: '\(todo.title)'")
        
        return newTodo
    }
    
    func updateTodo(_ todo: TodoItem) async throws {
        let record = todo.toCKRecord()
        _ = try await sharedDatabase.save(record)
        
        await notifyTripMembers(tripID: todo.tripID, message: "Todo item updated: '\(todo.title)'")
    }
    
    func toggleTodoCompletion(_ todo: TodoItem, userID: String) async throws {
        var updatedTodo = todo
        updatedTodo.completedBy[userID] = !(updatedTodo.completedBy[userID] ?? false)
        
        try await updateTodo(updatedTodo)
    }
    
    func deleteTodo(_ todo: TodoItem) async throws {
        guard let recordName = todo.recordName else { return }
        let recordID = CKRecord.ID(recordName: recordName)
        
        _ = try await sharedDatabase.deleteRecord(withID: recordID)
        
        await notifyTripMembers(tripID: todo.tripID, message: "Todo item deleted: '\(todo.title)'")
    }
    
    // MARK: - Notes
    
    func fetchNote(for tripID: String) async throws -> TripNote? {
        let predicate = NSPredicate(format: "tripID == %@", tripID)
        let query = CKQuery(recordType: "TripNote", predicate: predicate)
        
        let result = try await sharedDatabase.records(matching: query)
        
        let notes = result.matchResults.compactMap { (recordID, recordResult) -> TripNote? in
            guard let record = try? recordResult.get() else { return nil }
            return TripNote(record: record)
        }
        
        return notes.first
    }
    
    func saveNote(_ note: TripNote) async throws -> TripNote {
        var updatedNote = note
        let record = updatedNote.toCKRecord()
        
        let savedRecord = try await sharedDatabase.save(record)
        updatedNote.recordName = savedRecord.recordID.recordName
        
        await notifyTripMembers(tripID: note.tripID, message: "Notes have been updated")
        
        return updatedNote
    }
    
    // MARK: - Tickets
    
    func fetchTickets(for tripID: String) async throws -> [TicketDocument] {
        let predicate = NSPredicate(format: "tripID == %@", tripID)
        let query = CKQuery(recordType: "TicketDocument", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "uploadDate", ascending: false)]
        
        let result = try await sharedDatabase.records(matching: query)
        
        return result.matchResults.compactMap { (recordID, recordResult) -> TicketDocument? in
            guard let record = try? recordResult.get() else { return nil }
            return TicketDocument(record: record)
        }
    }
    
    func uploadTicket(_ ticket: TicketDocument, fileData: Data) async throws -> TicketDocument {
        var newTicket = ticket
        let record = newTicket.toCKRecord(fileData: fileData)
        
        let savedRecord = try await sharedDatabase.save(record)
        newTicket.recordName = savedRecord.recordID.recordName
        
        await notifyTripMembers(tripID: ticket.tripID, message: "New ticket uploaded: '\(ticket.fileName)'")
        
        return newTicket
    }
    
    func deleteTicket(_ ticket: TicketDocument) async throws {
        guard let recordName = ticket.recordName else { return }
        let recordID = CKRecord.ID(recordName: recordName)
        
        _ = try await sharedDatabase.deleteRecord(withID: recordID)
        
        await notifyTripMembers(tripID: ticket.tripID, message: "Ticket deleted: '\(ticket.fileName)'")
    }
    
    // MARK: - Members
    
    func fetchMembers(memberIDs: [String]) async throws -> [TripMember] {
        guard !memberIDs.isEmpty else { return [] }
        
        let recordIDs = memberIDs.map { CKRecord.ID(recordName: $0) }
        let results = try await sharedDatabase.records(for: recordIDs)
        
        return results.compactMap { (recordID, recordResult) -> TripMember? in
            guard let record = try? recordResult.get() else { return nil }
            return TripMember(record: record)
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
    
    // MARK: - Sharing
    
    func generateShareLink(for trip: Trip) async throws -> URL {
        guard let recordName = trip.recordName else {
            throw NSError(domain: "CloudKit", code: -1, userInfo: [NSLocalizedDescriptionKey: "Trip not saved to CloudKit"])
        }
        
        let recordID = CKRecord.ID(recordName: recordName)
        let share = CKShare(rootRecord: try await sharedDatabase.record(for: recordID))
        share[CKShare.SystemFieldKey.title] = "Join \(trip.name)" as CKRecordValue
        share.publicPermission = .readWrite
        
        _ = try await sharedDatabase.save(share)
        
        guard let url = share.url else {
            throw NSError(domain: "CloudKit", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to generate share URL"])
        }
        
        return url
    }
    
    func acceptShare(metadata: CKShare.Metadata) async throws {
        _ = try await container.accept(metadata)
        await fetchTrips()
    }
    
    // MARK: - Subscriptions
    
    private func setupSubscriptions() async {
        // Subscribe to trip changes
        let subscription = CKQuerySubscription(
            recordType: "Trip",
            predicate: NSPredicate(value: true),
            subscriptionID: subscriptionID,
            options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
        )
        
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo
        
        do {
            _ = try await sharedDatabase.save(subscription)
        } catch {
            print("Error setting up subscription: \(error)")
        }
    }
    
    // MARK: - Notifications
    
    private func notifyTripMembers(tripID: String, message: String) async {
        guard let trip = trips.first(where: { $0.id == tripID }) else { return }
        
        // Send push notification to all members
        for memberID in trip.memberIDs where memberID != currentUserID {
            await sendPushNotification(to: memberID, message: message, tripID: tripID)
        }
    }
    
    private func sendPushNotification(to userID: String, message: String, tripID: String) async {
        // This would use CloudKit push notifications
        // For now, we'll use local notifications through NotificationManager
        await NotificationManager.shared.sendLocalNotification(title: "Trip Update", body: message)
    }
}
