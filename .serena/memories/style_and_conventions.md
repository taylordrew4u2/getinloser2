# Style and Conventions
- Swift/SwiftUI idioms; structs for models, ObservableObject managers with @Published state.
- CloudKit conversion helpers: `init?(record:)` and `toCKRecord()` per model.
- Codable conformance used for persistence; Hashable/Identifiable for SwiftUI lists.
- Naming: camelCase properties and functions; record fields mirror CK schema keys (name, location, startDate, memberIDs, etc.).
- Sorting uses NSSortDescriptor or Swift sort closures; minimal comments.
- Local storage via UserDefaults for trips when CloudKit unavailable.
- Invite codes generated via static helper on Trip (6-char alphanumeric).