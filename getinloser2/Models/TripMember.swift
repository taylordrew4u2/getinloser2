import Foundation
// import CloudKit (removed - using Firebase)

struct TripMember: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var phoneNumber: String
    var userRecordID: String
    var notificationsEnabled: Bool
    
    init(id: String = UUID().uuidString,
         name: String,
         phoneNumber: String = "",
         userRecordID: String,
         notificationsEnabled: Bool = true) {
        self.id = id
        self.name = name
        self.phoneNumber = phoneNumber
        self.userRecordID = userRecordID
        self.notificationsEnabled = notificationsEnabled
    }
    
    init?(record: CKRecord) {
        guard let name = record["name"] as? String,
              let userRecordID = record["userRecordID"] as? String else {
            return nil
        }
        
        self.id = record.recordID.recordName
        self.name = name
        self.phoneNumber = record["phoneNumber"] as? String ?? ""
        self.userRecordID = userRecordID
        self.notificationsEnabled = record["notificationsEnabled"] as? Bool ?? true
    }
    
    func toCKRecord() -> CKRecord {
        let record = CKRecord(recordType: "TripMember", recordID: CKRecord.ID(recordName: id))
        
        record["name"] = name
        record["phoneNumber"] = phoneNumber
        record["userRecordID"] = userRecordID
        record["notificationsEnabled"] = notificationsEnabled
        
        return record
    }
}
