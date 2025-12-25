import Foundation
// import CloudKit (removed - using Firebase)

struct TripNote: Identifiable, Codable, Hashable {
    var id: String
    var tripID: String
    var content: String
    var lastModifiedBy: String
    var lastModifiedDate: Date
    var recordName: String?
    
    init(id: String = UUID().uuidString,
         tripID: String,
         content: String = "",
         lastModifiedBy: String,
         lastModifiedDate: Date = Date(),
         recordName: String? = nil) {
        self.id = id
        self.tripID = tripID
        self.content = content
        self.lastModifiedBy = lastModifiedBy
        self.lastModifiedDate = lastModifiedDate
        self.recordName = recordName
    }
    
    init?(record: CKRecord) {
        guard let lastModifiedBy = record["lastModifiedBy"] as? String,
              let lastModifiedDate = record["lastModifiedDate"] as? Date else {
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
        self.content = record["content"] as? String ?? ""
        self.lastModifiedBy = lastModifiedBy
        self.lastModifiedDate = lastModifiedDate
        self.recordName = record.recordID.recordName
    }
    
    func toCKRecord() -> CKRecord {
        let recordID = recordName.map { CKRecord.ID(recordName: $0) } ?? CKRecord.ID(recordName: id)
        let record = CKRecord(recordType: "TripNote", recordID: recordID)
        
        // Create a reference to the Trip record
        let tripRecordID = CKRecord.ID(recordName: tripID)
        let tripReference = CKRecord.Reference(recordID: tripRecordID, action: .deleteSelf)
        record["tripID"] = tripReference
        
        record["content"] = content
        record["lastModifiedBy"] = lastModifiedBy
        record["lastModifiedDate"] = lastModifiedDate
        
        return record
    }
}
