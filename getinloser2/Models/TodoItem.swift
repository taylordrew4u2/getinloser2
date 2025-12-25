import Foundation
// import CloudKit (removed - using Firebase)

struct TodoItem: Identifiable, Codable, Hashable {
    var id: String
    var tripID: String
    var title: String
    var completedBy: [String: Bool] // UserID: isCompleted
    var createdBy: String
    var recordName: String?
    
    init(id: String = UUID().uuidString,
         tripID: String,
         title: String,
         completedBy: [String: Bool] = [:],
         createdBy: String,
         recordName: String? = nil) {
        self.id = id
        self.tripID = tripID
        self.title = title
        self.completedBy = completedBy
        self.createdBy = createdBy
        self.recordName = recordName
    }
    
    init?(record: CKRecord) {
        guard let title = record["title"] as? String,
              let createdBy = record["createdBy"] as? String else {
            return nil
        }
        
        // Handle tripID as either a Reference or String
        let tripID: String
        if let reference = record["tripID"] as? CKRecord.Reference {
            tripID = reference.recordID.recordName
        } else if let stringID = record["tripID"] as? String {
            tripID = stringID
        } else {
            return nil
        }
        
        self.id = record.recordID.recordName
        self.tripID = tripID
        self.title = title
        self.createdBy = createdBy
        self.recordName = record.recordID.recordName
        
        // Parse completedBy dictionary
        if let completedByData = record["completedBy"] as? Data {
            self.completedBy = (try? JSONDecoder().decode([String: Bool].self, from: completedByData)) ?? [:]
        } else {
            self.completedBy = [:]
        }
    }
    
    func toCKRecord() -> CKRecord {
        let recordID = recordName.map { CKRecord.ID(recordName: $0) } ?? CKRecord.ID(recordName: id)
        let record = CKRecord(recordType: "TodoItem", recordID: recordID)
        
        // Create a reference to the Trip record
        let tripRecordID = CKRecord.ID(recordName: tripID)
        let tripReference = CKRecord.Reference(recordID: tripRecordID, action: .deleteSelf)
        record["tripID"] = tripReference
        
        record["title"] = title
        record["createdBy"] = createdBy
        
        if let completedByData = try? JSONEncoder().encode(completedBy) {
            record["completedBy"] = completedByData
        }
        
        return record
    }
    
    func isFullyCompleted(memberIDs: [String]) -> Bool {
        return memberIDs.allSatisfy { completedBy[$0] == true }
    }
    
    func pendingMembers(memberIDs: [String]) -> [String] {
        return memberIDs.filter { completedBy[$0] != true }
    }
}
