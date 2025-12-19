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
        guard let fileName = record["fileName"] as? String,
              let fileType = record["fileType"] as? String,
              let uploadedBy = record["uploadedBy"] as? String,
              let uploadDate = record["uploadDate"] as? Date else {
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
        
        // Create a reference to the Trip record
        let tripRecordID = CKRecord.ID(recordName: tripID)
        let tripReference = CKRecord.Reference(recordID: tripRecordID, action: .deleteSelf)
        record["tripID"] = tripReference
        
        record["fileName"] = fileName
        record["fileType"] = fileType
        record["uploadedBy"] = uploadedBy
        record["uploadDate"] = uploadDate
        
        // Create temporary file for CKAsset
        // Use a unique filename to avoid conflicts
        let uniqueFileName = "\(UUID().uuidString)_\(fileName)"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(uniqueFileName)
        
        do {
            try fileData.write(to: tempURL)
            print("✅ Wrote ticket data to temporary file: \(tempURL.path)")
            print("   File size: \(fileData.count) bytes")
            record["fileAsset"] = CKAsset(fileURL: tempURL)
        } catch {
            print("❌ Failed to write temporary file: \(error)")
        }
        
        return record
    }
}
