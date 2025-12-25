import Foundation
// import CloudKit (removed - using Firebase)

struct IOUEntry: Identifiable, Codable, Hashable {
    var id: String
    var tripID: String
    var ownerID: String // Person who is OWED money
    var debtorID: String // Person who OWES money
    var amount: Double
    var note: String?
    var createdDate: Date
    var lastModifiedDate: Date
    var recordName: String?
    
    init(id: String = UUID().uuidString,
         tripID: String,
         ownerID: String,
         debtorID: String,
         amount: Double,
         note: String? = nil,
         createdDate: Date = Date(),
         lastModifiedDate: Date = Date(),
         recordName: String? = nil) {
        self.id = id
        self.tripID = tripID
        self.ownerID = ownerID
        self.debtorID = debtorID
        self.amount = amount
        self.note = note
        self.createdDate = createdDate
        self.lastModifiedDate = lastModifiedDate
        self.recordName = recordName
    }
    
    init?(record: CKRecord) {
        guard let amount = record["amount"] as? Double,
              let ownerID = record["ownerID"] as? String,
              let debtorID = record["debtorID"] as? String,
              let createdDate = record["createdDate"] as? Date,
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
        self.ownerID = ownerID
        self.debtorID = debtorID
        self.amount = amount
        self.note = record["note"] as? String
        self.createdDate = createdDate
        self.lastModifiedDate = lastModifiedDate
        self.recordName = record.recordID.recordName
    }
    
    func toCKRecord() -> CKRecord {
        let recordID = recordName.map { CKRecord.ID(recordName: $0) } ?? CKRecord.ID(recordName: id)
        let record = CKRecord(recordType: "IOUEntry", recordID: recordID)
        
        // Create a reference to the Trip record
        let tripRecordID = CKRecord.ID(recordName: tripID)
        let tripReference = CKRecord.Reference(recordID: tripRecordID, action: .deleteSelf)
        record["tripID"] = tripReference
        
        record["ownerID"] = ownerID
        record["debtorID"] = debtorID
        record["amount"] = amount
        record["note"] = note
        record["createdDate"] = createdDate
        record["lastModifiedDate"] = lastModifiedDate
        
        return record
    }
}
