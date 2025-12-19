import SwiftUI

struct ItineraryTabView: View {
    @EnvironmentObject var cloudKitManager: CloudKitManager
    
    let trip: Trip
    
    @State private var events: [ItineraryEvent] = []
    @State private var selectedDate: Date?
    @State private var isLoading = true
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
            } else if events.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(tripDays, id: \.self) { date in
                            DayCardView(date: date, trip: trip, events: eventsForDay(date))
                        }
                    }
                    .padding()
                }
            }
        }
        .task {
            await loadEvents()
        }
    }
    
    private var tripDays: [Date] {
        var days: [Date] = []
        var currentDate = Calendar.current.startOfDay(for: trip.startDate)
        let endDate = Calendar.current.startOfDay(for: trip.endDate)
        
        while currentDate <= endDate {
            days.append(currentDate)
            currentDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate)!
        }
        
        return days
    }
    
    private func eventsForDay(_ date: Date) -> [ItineraryEvent] {
        let calendar = Calendar.current
        return events.filter { event in
            calendar.isDate(event.date, inSameDayAs: date)
        }.sorted { $0.time < $1.time }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Events Yet")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            Text("Tap on a day to add your first event")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
    }
    
    private func loadEvents() async {
        do {
            let fetchedEvents = try await cloudKitManager.fetchEvents(for: trip.id)
            await MainActor.run {
                events = fetchedEvents
                isLoading = false
            }
        } catch {
            print("Error loading events: \(error)")
            await MainActor.run {
                isLoading = false
            }
        }
    }
}

struct DayCardView: View {
    let date: Date
    let trip: Trip
    let events: [ItineraryEvent]
    
    @State private var showingTimeline = false
    
    var body: some View {
        Button(action: { showingTimeline = true }) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(date.formatted(.dateTime.weekday(.wide)))
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Text(date.formatted(.dateTime.day().month(.wide)))
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    if !events.isEmpty {
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("\(events.count)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                            
                            Text("events")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    } else {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                }
                
                if !events.isEmpty {
                    Divider()
                        .background(Color.gray.opacity(0.3))
                    
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(events.prefix(3)) { event in
                            HStack {
                                Text(event.time.formatted(date: .omitted, time: .shortened))
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                
                                Text(event.name)
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                
                                Spacer()
                            }
                        }
                        
                        if events.count > 3 {
                            Text("+ \(events.count - 3) more")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingTimeline) {
            DayTimelineView(trip: trip, date: date, events: events)
        }
    }
}

#Preview {
    ItineraryTabView(trip: Trip(
        name: "Tokyo Adventure",
        location: "Tokyo, Japan",
        startDate: Date(),
        endDate: Date().addingTimeInterval(86400 * 7),
        ownerID: "user123"
    ))
    .environmentObject(CloudKitManager.shared)
}
