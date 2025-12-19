import Foundation
import CloudKit

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
        guard let tripID = record["tripID"] as? String,
              let lastModifiedBy = record["lastModifiedBy"] as? String,
              let lastModifiedDate = record["lastModifiedDate"] as? Date else {
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
        
        record["tripID"] = tripID
        record["content"] = content
        record["lastModifiedBy"] = lastModifiedBy
        record["lastModifiedDate"] = lastModifiedDate
        
        return record
    }
}
