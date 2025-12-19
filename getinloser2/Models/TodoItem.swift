import Foundation
import CloudKit

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
        guard let tripID = record["tripID"] as? String,
              let title = record["title"] as? String,
              let createdBy = record["createdBy"] as? String else {
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
        
        record["tripID"] = tripID
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
