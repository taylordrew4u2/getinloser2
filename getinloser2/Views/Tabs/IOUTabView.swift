import SwiftUI

struct IOUTabView: View {
    @EnvironmentObject var cloudKitManager: CloudKitManager
    
    let trip: Trip
    
    @State private var isLoading = true
    @State private var showingCalculator = false
    @State private var selectedMember: TripMember?
    
    @State private var members: [TripMember] = []
    
    private var iouEntries: [IOUEntry] {
        cloudKitManager.iouCache[trip.id] ?? []
    }
    
    // Group IOUs by owner (person being owed)
    private func entriesOwedTo(_ ownerID: String) -> [IOUEntry] {
        iouEntries.filter { $0.ownerID == ownerID && $0.amount > 0 }
    }
    
    // Calculate total owed to a person
    private func totalOwedTo(_ ownerID: String) -> Double {
        entriesOwedTo(ownerID).reduce(0) { $0 + $1.amount }
    }
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
            } else {
                VStack(spacing: 0) {
                    // Member boxes
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(members) { member in
                                MemberIOUBox(
                                    member: member,
                                    trip: trip,
                                    members: members,
                                    entries: entriesOwedTo(member.userRecordID),
                                    totalOwed: totalOwedTo(member.userRecordID),
                                    onAddDebt: {
                                        selectedMember = member
                                    }
                                )
                            }
                        }
                        .padding()
                    }
                    
                    // Calculator button at bottom
                    Button(action: { showingCalculator = true }) {
                        HStack {
                            Image(systemName: "plus.forwardslash.minus")
                                .font(.title3)
                            Text("Calculator")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                    }
                }
            }
        }
        .task {
            await loadData()
        }
        .refreshable {
            await loadData()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            Task {
                await loadData()
            }
        }
        .sheet(isPresented: $showingCalculator) {
            CalculatorView()
        }
        .sheet(item: $selectedMember) { member in
            AddDebtView(trip: trip, ownerMember: member)
        }
    }
    
    private func loadData() async {
        do {
            let fetchedMembers = try await cloudKitManager.fetchMembers(memberIDs: trip.memberIDs)
            _ = try await cloudKitManager.fetchIOUEntries(for: trip.id)
            await MainActor.run {
                self.members = fetchedMembers
                self.isLoading = false
            }
        } catch {
            print("Error loading IOU data: \(error)")
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
}

// MARK: - Member IOU Box

struct MemberIOUBox: View {
    @EnvironmentObject var cloudKitManager: CloudKitManager
    
    let member: TripMember
    let trip: Trip
    let members: [TripMember]
    let entries: [IOUEntry]
    let totalOwed: Double
    let onAddDebt: () -> Void
    
    private var isCurrentUser: Bool {
        member.userRecordID == cloudKitManager.currentUserID
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with member name and total
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(member.name + (isCurrentUser ? " (You)" : ""))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    if totalOwed > 0 {
                        Text("Total owed: $\(String(format: "%.2f", totalOwed))")
                            .font(.subheadline)
                            .foregroundColor(.green)
                    } else {
                        Text("All settled up! 🎉")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                // Add button - always visible so anyone can add to this person's box
                Button(action: onAddDebt) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }
            
            if !entries.isEmpty {
                Divider()
                    .background(Color.gray.opacity(0.3))
                
                // List of people who owe this member
                VStack(spacing: 8) {
                    ForEach(entries) { entry in
                        IOUEntryRow(
                            entry: entry,
                            trip: trip,
                            members: members,
                            canModify: isCurrentUser
                        )
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(totalOwed > 0 ? Color.green.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 2)
                )
        )
    }
}

// MARK: - IOU Entry Row

struct IOUEntryRow: View {
    @EnvironmentObject var cloudKitManager: CloudKitManager
    @State private var showingEditSheet = false
    
    let entry: IOUEntry
    let trip: Trip
    let members: [TripMember]
    let canModify: Bool
    
    private var debtorName: String {
        members.first(where: { $0.userRecordID == entry.debtorID })?.name ?? (entry.debtorID == cloudKitManager.currentUserID ? "You" : "Unknown")
    }
    
    var body: some View {
        Button(action: {
            if canModify {
                showingEditSheet = true
            }
        }) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(debtorName)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                    
                    if let note = entry.note, !note.isEmpty {
                        Text(note)
                            .font(.caption)
                            .foregroundColor(.gray)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("$\(String(format: "%.2f", entry.amount))")
                        .font(.headline)
                        .foregroundColor(.green)
                    
                    if canModify {
                        Image(systemName: "pencil.circle.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!canModify)
        .sheet(isPresented: $showingEditSheet) {
            EditDebtView(trip: trip, entry: entry, members: members)
        }
    }
}

// MARK: - Add Debt View

struct AddDebtView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var cloudKitManager: CloudKitManager
    
    let trip: Trip
    let ownerMember: TripMember
    
    @State private var amount: String = ""
    @State private var note: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showingError = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 8) {
                            Text("You owe")
                                .font(.headline)
                                .foregroundColor(.gray)
                            
                            Text(ownerMember.name)
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                        .padding(.top)
                        
                        // Amount input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Amount")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            HStack {
                                Text("$")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                
                                TextField("0.00", text: $amount)
                                    .font(.title2)
                                    .keyboardType(.decimalPad)
                                    .foregroundColor(.white)
                                    .tint(.blue)
                            }
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                        }
                        
                        // Note input (optional)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Note (optional)")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            TextField("e.g., Dinner at restaurant", text: $note)
                                .font(.body)
                                .foregroundColor(.white)
                                .tint(.blue)
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(12)
                        }
                        
                        Spacer()
                    }
                    .padding()
                }
            }
            .navigationTitle("Add IOU")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveDebt()
                    }
                    .foregroundColor(.blue)
                    .disabled(isSaving || amount.isEmpty)
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                }
            }
            .preferredColorScheme(.dark)
        }
    }
    
    private func saveDebt() {
        guard let amountValue = Double(amount), amountValue > 0 else {
            errorMessage = "Please enter a valid amount"
            showingError = true
            return
        }
        
        isSaving = true
        
        Task {
            do {
                let entry = IOUEntry(
                    tripID: trip.id,
                    ownerID: ownerMember.userRecordID,
                    debtorID: cloudKitManager.currentUserID,
                    amount: amountValue,
                    note: note.isEmpty ? nil : note
                )
                
                _ = try await cloudKitManager.saveIOUEntry(entry)
                
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to save: \(error.localizedDescription)"
                    showingError = true
                    isSaving = false
                }
            }
        }
    }
}

// MARK: - Edit Debt View

struct EditDebtView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var cloudKitManager: CloudKitManager
    
    let trip: Trip
    let entry: IOUEntry
    let members: [TripMember]
    
    @State private var amount: String
    @State private var note: String
    @State private var isSaving = false
    @State private var showingDeleteAlert = false
    @State private var errorMessage: String?
    @State private var showingError = false
    
    init(trip: Trip, entry: IOUEntry, members: [TripMember]) {
        self.trip = trip
        self.entry = entry
        self.members = members
        _amount = State(initialValue: String(format: "%.2f", entry.amount))
        _note = State(initialValue: entry.note ?? "")
    }
    
    private var debtorName: String {
        members.first(where: { $0.userRecordID == entry.debtorID })?.name ?? "Unknown"
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 8) {
                            Text(debtorName)
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text("owes you")
                                .font(.headline)
                                .foregroundColor(.gray)
                        }
                        .padding(.top)
                        
                        // Amount input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Amount")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            HStack {
                                Text("$")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                
                                TextField("0.00", text: $amount)
                                    .font(.title2)
                                    .keyboardType(.decimalPad)
                                    .foregroundColor(.white)
                                    .tint(.blue)
                            }
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                            
                            Text("Reduce the amount when paid back, or set to $0 to clear")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        // Note input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Note")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            TextField("e.g., Paid via Venmo", text: $note)
                                .font(.body)
                                .foregroundColor(.white)
                                .tint(.blue)
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(12)
                            
                            Text("Add payment method or other notes")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        // Delete button
                        Button(role: .destructive, action: { showingDeleteAlert = true }) {
                            HStack {
                                Image(systemName: "trash")
                                Text("Delete Entry")
                            }
                            .font(.headline)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(12)
                        }
                        
                        Spacer()
                    }
                    .padding()
                }
            }
            .navigationTitle("Edit IOU")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveChanges()
                    }
                    .foregroundColor(.blue)
                    .disabled(isSaving || amount.isEmpty)
                }
            }
            .alert("Delete Entry", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteEntry()
                }
            } message: {
                Text("Are you sure you want to delete this IOU entry?")
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                }
            }
            .preferredColorScheme(.dark)
        }
    }
    
    private func saveChanges() {
        guard let amountValue = Double(amount), amountValue >= 0 else {
            errorMessage = "Please enter a valid amount"
            showingError = true
            return
        }
        
        isSaving = true
        
        Task {
            do {
                // If amount is 0, delete the entry instead
                if amountValue == 0 {
                    try await cloudKitManager.deleteIOUEntry(entry)
                } else {
                    var updatedEntry = entry
                    updatedEntry.amount = amountValue
                    updatedEntry.note = note.isEmpty ? nil : note
                    
                    _ = try await cloudKitManager.saveIOUEntry(updatedEntry)
                }
                
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to save: \(error.localizedDescription)"
                    showingError = true
                    isSaving = false
                }
            }
        }
    }
    
    private func deleteEntry() {
        Task {
            do {
                try await cloudKitManager.deleteIOUEntry(entry)
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to delete: \(error.localizedDescription)"
                    showingError = true
                }
            }
        }
    }
}

// MARK: - Calculator View

struct CalculatorView: View {
    @Environment(\.dismiss) var dismiss
    @State private var displayValue: String = "0"
    @State private var currentOperation: CalculatorOperation?
    @State private var previousValue: Double = 0
    @State private var shouldResetDisplay = false
    
    enum CalculatorOperation {
        case add, subtract, multiply, divide
        
        func perform(_ a: Double, _ b: Double) -> Double {
            switch self {
            case .add: return a + b
            case .subtract: return a - b
            case .multiply: return a * b
            case .divide: return b != 0 ? a / b : 0
            }
        }
        
        var symbol: String {
            switch self {
            case .add: return "+"
            case .subtract: return "−"
            case .multiply: return "×"
            case .divide: return "÷"
            }
        }
    }
    
    private let buttons: [[CalculatorButton]] = [
        [.clear, .plusMinus, .percent, .divide],
        [.seven, .eight, .nine, .multiply],
        [.four, .five, .six, .subtract],
        [.one, .two, .three, .add],
        [.zero, .decimal, .equals]
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                VStack(spacing: 12) {
                    Spacer()
                    
                    // Display
                    Text(displayValue)
                        .font(.system(size: 64, weight: .light))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.horizontal)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    
                    // Buttons
                    VStack(spacing: 12) {
                        ForEach(buttons, id: \.self) { row in
                            HStack(spacing: 12) {
                                ForEach(row, id: \.self) { button in
                                    CalculatorButtonView(button: button) {
                                        handleButtonTap(button)
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Calculator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
            }
            .preferredColorScheme(.dark)
        }
    }
    
    private func handleButtonTap(_ button: CalculatorButton) {
        switch button {
        case .zero, .one, .two, .three, .four, .five, .six, .seven, .eight, .nine:
            handleNumber(button.rawValue)
        case .decimal:
            handleDecimal()
        case .add, .subtract, .multiply, .divide:
            handleOperation(button)
        case .equals:
            handleEquals()
        case .clear:
            handleClear()
        case .plusMinus:
            handlePlusMinus()
        case .percent:
            handlePercent()
        }
    }
    
    private func handleNumber(_ number: String) {
        if shouldResetDisplay {
            displayValue = number
            shouldResetDisplay = false
        } else {
            if displayValue == "0" {
                displayValue = number
            } else {
                displayValue += number
            }
        }
    }
    
    private func handleDecimal() {
        if shouldResetDisplay {
            displayValue = "0."
            shouldResetDisplay = false
        } else if !displayValue.contains(".") {
            displayValue += "."
        }
    }
    
    private func handleOperation(_ button: CalculatorButton) {
        if let value = Double(displayValue) {
            if let operation = currentOperation {
                previousValue = operation.perform(previousValue, value)
                displayValue = formatNumber(previousValue)
            } else {
                previousValue = value
            }
        }
        
        switch button {
        case .add: currentOperation = .add
        case .subtract: currentOperation = .subtract
        case .multiply: currentOperation = .multiply
        case .divide: currentOperation = .divide
        default: break
        }
        
        shouldResetDisplay = true
    }
    
    private func handleEquals() {
        if let operation = currentOperation, let value = Double(displayValue) {
            previousValue = operation.perform(previousValue, value)
            displayValue = formatNumber(previousValue)
            currentOperation = nil
            shouldResetDisplay = true
        }
    }
    
    private func handleClear() {
        displayValue = "0"
        previousValue = 0
        currentOperation = nil
        shouldResetDisplay = false
    }
    
    private func handlePlusMinus() {
        if let value = Double(displayValue) {
            displayValue = formatNumber(-value)
        }
    }
    
    private func handlePercent() {
        if let value = Double(displayValue) {
            displayValue = formatNumber(value / 100)
        }
    }
    
    private func formatNumber(_ number: Double) -> String {
        if number.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", number)
        } else {
            return String(format: "%g", number)
        }
    }
}

enum CalculatorButton: String, Hashable {
    case zero = "0", one = "1", two = "2", three = "3", four = "4"
    case five = "5", six = "6", seven = "7", eight = "8", nine = "9"
    case decimal = "."
    case add = "+", subtract = "−", multiply = "×", divide = "÷"
    case equals = "="
    case clear = "C"
    case plusMinus = "±"
    case percent = "%"
    
    var backgroundColor: Color {
        switch self {
        case .add, .subtract, .multiply, .divide, .equals:
            return Color.orange
        case .clear, .plusMinus, .percent:
            return Color.gray.opacity(0.5)
        default:
            return Color.white.opacity(0.1)
        }
    }
}

struct CalculatorButtonView: View {
    let button: CalculatorButton
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(button.rawValue)
                .font(.title)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .frame(maxWidth: button == .zero ? .infinity : 80, minHeight: 80)
                .background(button.backgroundColor)
                .cornerRadius(button == .zero ? 40 : 40)
        }
        .frame(maxWidth: button == .zero ? .infinity : 80)
    }
}

#Preview {
    IOUTabView(trip: Trip(
        name: "Tokyo Adventure",
        location: "Tokyo, Japan",
        startDate: Date(),
        endDate: Date().addingTimeInterval(86400 * 7),
        ownerID: "user123"
    ))
    .environmentObject(CloudKitManager.shared)
}

