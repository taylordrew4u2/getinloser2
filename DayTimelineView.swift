import SwiftUI

struct DayTimelineView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var cloudKitManager: CloudKitManager
    
    let trip: Trip
    let date: Date
    
    @State var events: [ItineraryEvent]
    @State private var showingAddEvent = false
    @State private var selectedEvent: ItineraryEvent?
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(0..<24) { hour in
                            HourRowView(
                                hour: hour,
                                events: eventsForHour(hour),
                                onEventTap: { event in
                                    selectedEvent = event
                                }
                            )
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle(date.formatted(.dateTime.day().month().year()))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddEvent = true }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.blue)
                    }
                }
            }
            .sheet(isPresented: $showingAddEvent) {
                AddEventView(trip: trip, date: date) { newEvent in
                    events.append(newEvent)
                    events.sort { $0.time < $1.time }
                }
            }
            .sheet(item: $selectedEvent) { event in
                EventDetailView(trip: trip, event: event) { updatedEvent in
                    if let index = events.firstIndex(where: { $0.id == updatedEvent.id }) {
                        events[index] = updatedEvent
                    }
                }
            }
            .preferredColorScheme(.dark)
        }
    }
    
    private func eventsForHour(_ hour: Int) -> [ItineraryEvent] {
        events.filter { event in
            let eventHour = Calendar.current.component(.hour, from: event.time)
            return eventHour == hour
        }
    }
}

struct HourRowView: View {
    let hour: Int
    let events: [ItineraryEvent]
    let onEventTap: (ItineraryEvent) -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Hour label
            Text(hourString)
                .font(.caption)
                .foregroundColor(.gray)
                .frame(width: 50, alignment: .leading)
            
            // Timeline
            VStack(spacing: 0) {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 1)
            }
            .frame(width: 1)
            
            // Events
            VStack(alignment: .leading, spacing: 8) {
                if events.isEmpty {
                    Spacer()
                        .frame(height: 50)
                } else {
                    ForEach(events) { event in
                        Button(action: { onEventTap(event) }) {
                            EventCardView(event: event)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: 60)
    }
    
    private var hourString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date())!
        return formatter.string(from: date)
    }
}

struct EventCardView: View {
    let event: ItineraryEvent
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(event.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                HStack(spacing: 8) {
                    Label(event.time.formatted(date: .omitted, time: .shortened), systemImage: "clock")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    
                    Label(event.location, systemImage: "location")
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color.blue.opacity(0.2))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.5), lineWidth: 1)
        )
    }
}

#Preview {
    DayTimelineView(
        trip: Trip(
            name: "Tokyo Adventure",
            location: "Tokyo, Japan",
            startDate: Date(),
            endDate: Date().addingTimeInterval(86400 * 7),
            ownerID: "user123"
        ),
        date: Date(),
        events: []
    )
    .environmentObject(CloudKitManager.shared)
}
