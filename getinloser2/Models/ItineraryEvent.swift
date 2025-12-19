import Foundation
import CloudKit
import CoreLocation

struct ItineraryEvent: Identifiable, Codable, Hashable {
    var id: String
    var tripID: String
    var name: String
    var date: Date
    var time: Date
    var location: String
    var coordinate: CLLocationCoordinate2D?
    var notes: String
    var createdBy: String
    var recordName: String?
    
    // MARK: - Hashable & Equatable
    
    static func == (lhs: ItineraryEvent, rhs: ItineraryEvent) -> Bool {
        lhs.id == rhs.id &&
        lhs.tripID == rhs.tripID &&
        lhs.name == rhs.name &&
        lhs.date == rhs.date &&
        lhs.time == rhs.time &&
        lhs.location == rhs.location &&
        lhs.notes == rhs.notes &&
        lhs.createdBy == rhs.createdBy &&
        lhs.recordName == rhs.recordName &&
        lhs.coordinate?.latitude == rhs.coordinate?.latitude &&
        lhs.coordinate?.longitude == rhs.coordinate?.longitude
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(tripID)
        hasher.combine(name)
        hasher.combine(date)
        hasher.combine(time)
        hasher.combine(location)
        hasher.combine(notes)
        hasher.combine(createdBy)
        hasher.combine(recordName)
        hasher.combine(coordinate?.latitude)
        hasher.combine(coordinate?.longitude)
    }
    
    init(id: String = UUID().uuidString,
         tripID: String,
         name: String,
         date: Date,
         time: Date,
         location: String,
         coordinate: CLLocationCoordinate2D? = nil,
         notes: String = "",
         createdBy: String,
         recordName: String? = nil) {
        self.id = id
        self.tripID = tripID
        self.name = name
        self.date = date
        self.time = time
        self.location = location
        self.coordinate = coordinate
        self.notes = notes
        self.createdBy = createdBy
        self.recordName = recordName
    }
    
    init?(record: CKRecord) {
        guard let name = record["name"] as? String,
              let date = record["date"] as? Date,
              let time = record["time"] as? Date,
              let location = record["location"] as? String,
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
        self.name = name
        self.date = date
        self.time = time
        self.location = location
        self.notes = record["notes"] as? String ?? ""
        self.createdBy = createdBy
        self.recordName = record.recordID.recordName
        
        if let locationAsset = record["coordinate"] as? CLLocation {
            self.coordinate = locationAsset.coordinate
        }
    }
    
    func toCKRecord() -> CKRecord {
        let recordID = recordName.map { CKRecord.ID(recordName: $0) } ?? CKRecord.ID(recordName: id)
        let record = CKRecord(recordType: "ItineraryEvent", recordID: recordID)
        
        // Create a reference to the Trip record
        let tripRecordID = CKRecord.ID(recordName: tripID)
        let tripReference = CKRecord.Reference(recordID: tripRecordID, action: .deleteSelf)
        record["tripID"] = tripReference
        
        record["name"] = name
        record["date"] = date
        record["time"] = time
        record["location"] = location
        record["notes"] = notes
        record["createdBy"] = createdBy
        
        if let coordinate = coordinate {
            record["coordinate"] = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        }
        
        return record
    }
    
    // Codable for coordinate
    enum CodingKeys: String, CodingKey {
        case id, tripID, name, date, time, location, notes, createdBy, recordName
        case latitude, longitude
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(tripID, forKey: .tripID)
        try container.encode(name, forKey: .name)
        try container.encode(date, forKey: .date)
        try container.encode(time, forKey: .time)
        try container.encode(location, forKey: .location)
        try container.encode(notes, forKey: .notes)
        try container.encode(createdBy, forKey: .createdBy)
        try container.encodeIfPresent(recordName, forKey: .recordName)
        try container.encodeIfPresent(coordinate?.latitude, forKey: .latitude)
        try container.encodeIfPresent(coordinate?.longitude, forKey: .longitude)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        tripID = try container.decode(String.self, forKey: .tripID)
        name = try container.decode(String.self, forKey: .name)
        date = try container.decode(Date.self, forKey: .date)
        time = try container.decode(Date.self, forKey: .time)
        location = try container.decode(String.self, forKey: .location)
        notes = try container.decode(String.self, forKey: .notes)
        createdBy = try container.decode(String.self, forKey: .createdBy)
        recordName = try container.decodeIfPresent(String.self, forKey: .recordName)
        
        if let lat = try container.decodeIfPresent(Double.self, forKey: .latitude),
           let lon = try container.decodeIfPresent(Double.self, forKey: .longitude) {
            coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
    }
}
