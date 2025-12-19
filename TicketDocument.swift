import Foundation
import CloudKit
import UIKit

struct TicketDocument: Identifiable, Codable, Hashable {
    var id: String
    var tripID: String
    var fileName: String
    var fileType: String // "image" or "pdf"
    var uploadedBy: String
    var uploadDate: Date
    var recordName: String?
    var assetURL: URL?
    
    init(id: String = UUID().uuidString,
         tripID: String,
         fileName: String,
         fileType: String,
         uploadedBy: String,
         uploadDate: Date = Date(),
         recordName: String? = nil,
         assetURL: URL? = nil) {
        self.id = id
        self.tripID = tripID
        self.fileName = fileName
        self.fileType = fileType
        self.uploadedBy = uploadedBy
        self.uploadDate = uploadDate
        self.recordName = recordName
        self.assetURL = assetURL
    }
    
    init?(record: CKRecord) {
        guard let tripID = record["tripID"] as? String,
              let fileName = record["fileName"] as? String,
              let fileType = record["fileType"] as? String,
              let uploadedBy = record["uploadedBy"] as? String,
              let uploadDate = record["uploadDate"] as? Date else {
            return nil
        }
        
        self.id = record.recordID.recordName
        self.tripID = tripID
        self.fileName = fileName
        self.fileType = fileType
        self.uploadedBy = uploadedBy
        self.uploadDate = uploadDate
        self.recordName = record.recordID.recordName
        
        if let asset = record["fileAsset"] as? CKAsset {
            self.assetURL = asset.fileURL
        }
    }
    
    func toCKRecord(fileData: Data) -> CKRecord {
        let recordID = recordName.map { CKRecord.ID(recordName: $0) } ?? CKRecord.ID(recordName: id)
        let record = CKRecord(recordType: "TicketDocument", recordID: recordID)
        
        record["tripID"] = tripID
        record["fileName"] = fileName
        record["fileType"] = fileType
        record["uploadedBy"] = uploadedBy
        record["uploadDate"] = uploadDate
        
        // Create temporary file for CKAsset
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try? fileData.write(to: tempURL)
        record["fileAsset"] = CKAsset(fileURL: tempURL)
        
        return record
    }
}
