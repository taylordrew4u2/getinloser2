import Foundation
import CloudKit
import CoreLocation

struct Trip: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var location: String
    var coordinate: CLLocationCoordinate2D?
    var startDate: Date
    var endDate: Date
    var ownerID: String
    var memberIDs: [String]
    var recordName: String?
    
    init(id: String = UUID().uuidString,
         name: String,
         location: String,
         coordinate: CLLocationCoordinate2D? = nil,
         startDate: Date,
         endDate: Date,
         ownerID: String,
         memberIDs: [String] = [],
         recordName: String? = nil) {
        self.id = id
        self.name = name
        self.location = location
        self.coordinate = coordinate
        self.startDate = startDate
        self.endDate = endDate
        self.ownerID = ownerID
        self.memberIDs = memberIDs
        self.recordName = recordName
    }
    
    // CloudKit conversion
    init?(record: CKRecord) {
        guard let name = record["name"] as? String,
              let location = record["location"] as? String,
              let startDate = record["startDate"] as? Date,
              let endDate = record["endDate"] as? Date,
              let ownerID = record["ownerID"] as? String else {
            return nil
        }
        
        self.id = record.recordID.recordName
        self.name = name
        self.location = location
        self.startDate = startDate
        self.endDate = endDate
        self.ownerID = ownerID
        self.memberIDs = record["memberIDs"] as? [String] ?? []
        self.recordName = record.recordID.recordName
        
        if let locationAsset = record["coordinate"] as? CLLocation {
            self.coordinate = locationAsset.coordinate
        }
    }
    
    func toCKRecord() -> CKRecord {
        let recordID = recordName.map { CKRecord.ID(recordName: $0) } ?? CKRecord.ID(recordName: id)
        let record = CKRecord(recordType: "Trip", recordID: recordID)
        
        record["name"] = name
        record["location"] = location
        record["startDate"] = startDate
        record["endDate"] = endDate
        record["ownerID"] = ownerID
        record["memberIDs"] = memberIDs
        
        if let coordinate = coordinate {
            record["coordinate"] = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        }
        
        return record
    }
    
    // Codable for coordinate
    enum CodingKeys: String, CodingKey {
        case id, name, location, startDate, endDate, ownerID, memberIDs, recordName
        case latitude, longitude
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(location, forKey: .location)
        try container.encode(startDate, forKey: .startDate)
        try container.encode(endDate, forKey: .endDate)
        try container.encode(ownerID, forKey: .ownerID)
        try container.encode(memberIDs, forKey: .memberIDs)
        try container.encodeIfPresent(recordName, forKey: .recordName)
        try container.encodeIfPresent(coordinate?.latitude, forKey: .latitude)
        try container.encodeIfPresent(coordinate?.longitude, forKey: .longitude)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        location = try container.decode(String.self, forKey: .location)
        startDate = try container.decode(Date.self, forKey: .startDate)
        endDate = try container.decode(Date.self, forKey: .endDate)
        ownerID = try container.decode(String.self, forKey: .ownerID)
        memberIDs = try container.decode([String].self, forKey: .memberIDs)
        recordName = try container.decodeIfPresent(String.self, forKey: .recordName)
        
        if let lat = try container.decodeIfPresent(Double.self, forKey: .latitude),
           let lon = try container.decodeIfPresent(Double.self, forKey: .longitude) {
            coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
    }
}
