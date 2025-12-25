import SwiftUI
import Combine

struct ItineraryTabView: View {
    @EnvironmentObject var firebaseManager: FirebaseStorageManager
    
    let trip: Trip
    
    @State private var isLoading = true
    @State private var showingFirstDayTimeline = false
    
    // Computed property that uses the cache for live updates
    private var events: [ItineraryEvent] {
        firebaseManager.eventsCache[trip.id] ?? []
    }
    
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
        .refreshable {
            await loadEvents()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            Task {
                await loadEvents()
            }
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
        VStack {
            Spacer()
            
            Button(action: {
                // Show the first day's timeline to add events
                if tripDays.first != nil {
                    showingFirstDayTimeline = true
                }
            }) {
                VStack(spacing: 20) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 70))
                        .foregroundColor(.blue)
                    
                    Text("Add to Itinerary")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Start planning your trip")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .frame(width: 280, height: 280)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.white.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(Color.blue.opacity(0.3), lineWidth: 2)
                        )
                )
                .shadow(color: Color.blue.opacity(0.2), radius: 20, x: 0, y: 10)
            }
            .buttonStyle(ScaleButtonStyle())
            
            Spacer()
        }
        .sheet(isPresented: $showingFirstDayTimeline) {
            if let firstDay = tripDays.first {
                DayTimelineView(trip: trip, date: firstDay, events: eventsForDay(firstDay))
            }
        }
    }
    
    private func loadEvents() async {
        do {
            _ = try await firebaseManager.fetchEvents(for: trip.id)
            await MainActor.run {
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
    @EnvironmentObject var firebaseManager: FirebaseStorageManager
    
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

// MARK: - Scale Button Style

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
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
    .environmentObject(FirebaseStorageManager.shared)
}
