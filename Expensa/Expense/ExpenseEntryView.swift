import SwiftUI
import CoreData
import Foundation
import Combine

class ScrollController: ObservableObject {
    @Published var isScrollEnabled = true
}

struct ExpenseEntryView: View {
    // MARK: - Environment
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var currencyManager: CurrencyManager
    @EnvironmentObject private var categoryManager: CategoryManager
    @EnvironmentObject private var tagManager: TagManager
    
    @State private var showingCalendar = false
    
    @State private var exchangeRate: String?
    
    // Add new state variables for recurrence
    @State private var isRecurring = false
    @State private var enableNotifications = true
    
    // Add frequency options
    private let frequencyOptions = ["Daily", "Weekly", "Monthly", "Yearly"]
    @State private var recurringFrequency = "Monthly"
    
    // Add computed property to check if recurrence is available
    private var canBeRecurring: Bool {
        let selectedDate = Calendar.current.startOfDay(for: date)
        let today = Calendar.current.startOfDay(for: Date())
        return selectedDate >= today
    }
    
    // MARK: - Constants
    private let lastSelectedCategoryKey = "lastSelectedCategoryID"
    
    // MARK: - Bindings
    @Binding var isPresented: Bool
    var expense: Expense? // Optional expense for edit mode
    var onComplete: (() -> Void)? // Add this line
    
    // MARK: - State
    @State private var amount: String = ""
    @State private var selectedCategory: Category?
    @State private var date: Date = Date()
    @State private var notes: String = ""
    @State private var selectedCurrency: Currency?
    @State private var convertedAmount: String?
    @State private var historicalRates: [String: Decimal]?
    
    @State private var showingCurrencyPicker = false
    @State private var showingCategorySelector = false
    @State private var showingNotesSheet = false
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    @State private var showingDatePicker = false
    
    @State private var selectedTags: Set<Tag> = []
    @State private var tempTags: Set<Tag> = []
    
    @State private var showNumberEffect = false
    @State private var shakeAmount: CGFloat = 0
    @State private var lastEnteredDigit = ""
    
    @StateObject private var scrollController = ScrollController()
    
    // Add these with other @State variables
    @State private var sourceRate: Decimal?
    @State private var targetRate: Decimal?
    
    @State private var hasLoadedStoredRate = false
    @State private var isInitialSetup = true
    @State private var storedRate: Decimal? = nil

    // Add a new function to update rates
    private func updateRates() {
        // If we're in edit mode and have loaded a stored rate, skip the rate lookup
        if isEditMode && hasLoadedStoredRate && selectedCurrency != defaultCurrency {
            return
        }
        
        // Skip if using default currency
        if selectedCurrency == defaultCurrency {
            return
        }
        
        // Otherwise, perform the lookup
        print("💱 Looking up rate for \(selectedCurrency?.code ?? "unknown") to \(defaultCurrency?.code ?? "unknown")")
        
        if let selectedCode = selectedCurrency?.code,
           let defaultCode = defaultCurrency?.code,
           let newSourceRate = HistoricalRateManager.shared.getRate(for: selectedCode, on: date),
           let newTargetRate = HistoricalRateManager.shared.getRate(for: defaultCode, on: date) {
            sourceRate = newSourceRate
            targetRate = newTargetRate
        }
    }
    
    // MARK: - Private Properties
    private func triggerShake() {
        withAnimation(.linear(duration: 0.3)) {
            shakeAmount = 1
        }
        // Reset after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            shakeAmount = 0
        }
    }
    
    private var defaultCurrency: Currency? {
        currencyManager.defaultCurrency
    }
    
    private var isUsingHistoricalRates: Bool {
        !Calendar.current.isDateInToday(date)
    }
    
    private var shouldShowConvertedAmount: Bool {
        convertedAmount != nil &&
        selectedCurrency != defaultCurrency
    }
    
    private var isEditMode: Bool {
        expense != nil
    }
    
    private var saveButtonText: String {
        isEditMode ? "Update" : "Save"
    }
    
    // MARK: - View Components
    private var dateButtonLabel: String {
        var label = Calendar.current.isDateInToday(date) ? "Today" : date.formatted(.relative)
        
        if isRecurring {
            label += " • " + recurringFrequency
        }
        
        return label
    }
    
    private var navigationBar: some View {
        HStack {
            CloseButton(
                icon: "xmark"
            ) {
                HapticFeedback.play()
                dismiss()
            }
            Spacer()
            ExpenseButton(
                icon: "calendar",
                label: dateButtonLabel
            ){
                HapticFeedback.play()
                withAnimation {
                    showingCalendar = true
                }
            }
        }
    }
    
    private var formattedAmount: String {
        formatUserInput(amount)
    }
    
    private func formatUserInput(_ amount: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        formatter.decimalSeparator = ","
        formatter.usesGroupingSeparator = true
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        
        let cleanedAmount = amount.replacingOccurrences(of: " ", with: "")
        
        // If there's a decimal part, handle it separately
        if cleanedAmount.contains(",") {
            let parts = cleanedAmount.split(separator: ",", maxSplits: 1)
            let integerPart = String(parts[0])
            let decimalPart = parts.count > 1 ? String(parts[1]) : ""
            
            // Format the integer part
            if let number = Double(integerPart) {
                let formattedInteger = formatter.string(from: NSNumber(value: number)) ?? integerPart
                // Always return with comma and decimal part
                return formattedInteger + "," + decimalPart
            }
            return cleanedAmount
        }
        
        // Handle non-decimal numbers
        if let number = Double(cleanedAmount.replacingOccurrences(of: ",", with: ".")), !amount.hasSuffix(",") {
            return formatter.string(from: NSNumber(value: number)) ?? amount
        }
        return cleanedAmount
    }
    
    private var amountSection: some View {
        VStack(spacing: 8) {
            HStack(alignment: .center, spacing: 0) {
                if amount.isEmpty {
                    if let currency = selectedCurrency ?? defaultCurrency {
                        let symbol = currency.symbol ?? currency.code ?? ""
                        let isUSD = currency.code == "USD"
                        Text(isUSD ? "\(symbol)0" : "0 \(symbol)")
                            .font(.system(size: 64, weight: .regular, design: .rounded))
                            .foregroundColor(Color(UIColor.systemGray2))
                            .minimumScaleFactor(0.3)
                            .lineLimit(1)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    if let currency = selectedCurrency ?? defaultCurrency {
                        let symbol = currency.symbol ?? currency.code ?? ""
                        let isUSD = currency.code == "USD"
                        
                        Text(isUSD ? "\(symbol)\(formattedAmount)" : "\(formattedAmount) \(symbol)")
                            .font(.system(size: 64, weight: .regular, design: .rounded))
                            .foregroundColor(.primary)
                            .contentTransition(.numericText())
                            .lineLimit(1)
                            .minimumScaleFactor(0.3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .onTapGesture {
                HapticFeedback.play()
                showingCurrencyPicker = true
            }
            .modifier(ShakeEffect(amount: 10, shakesPerUnit: 3, animatableData: shakeAmount))
            
            // Conversion information
            if shouldShowConvertedAmount {
                VStack(alignment: .center, spacing: 4) {
                    if let sourceRate = sourceRate,
                       let targetRate = targetRate,
                       let defaultCurrency = defaultCurrency {
                        let rate = targetRate/sourceRate
                        let rateString = formatUserInput(rate.description)
                        let symbol = defaultCurrency.symbol ?? defaultCurrency.code ?? ""
                        let isUSD = defaultCurrency.code == "USD"
                        let formattedRate = isUSD ? "\(symbol)\(rateString)" : "\(rateString) \(symbol)"
                        
                        Text("\(convertedAmount ?? "") with rate \(formattedRate)")
                            .foregroundColor(.gray)
                            .font(.subheadline)
                            .contentTransition(.numericText())
                            .animation(.spring(response: 0.4, dampingFraction: 0.95), value: rateString)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .animation(.spring(response: 0.4, dampingFraction: 0.95), value: convertedAmount)
            }
        }
        .padding(.vertical, 32)
        .padding(.horizontal, 16)
    }
    
    // MARK: - notes
    private var notesSection: some View {
        HStack {
            if !notes.isEmpty {
                // Show the actual notes when they've been written
                RoundButton(
                    label: notes,
                    rightIcon: "pencil.and.scribble"
                ) {
                    showingNotesSheet = true
                    HapticFeedback.play()
                }
            } else {
                // Show the default "Add notes" for empty notes
                RoundButton(
                    label: "Add notes or tags"
                ) {
                    showingNotesSheet = true
                    HapticFeedback.play()
                }
            }
        }
        .padding()
    }
    
    // MARK: - keypad
    private func handleNumberInput(_ value: String) {
        HapticFeedback.play()
        var cleanAmount = amount.replacingOccurrences(of: " ", with: "")

        if value == "," {
            if !cleanAmount.contains(",") {
                if cleanAmount.isEmpty || cleanAmount == "0" {
                    amount = "0,"
                } else {
                    // Otherwise preserve formatting when adding comma
                    amount = formatUserInput(cleanAmount) + ","
                }
                showNumberEffect = false
                lastEnteredDigit = value

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        showNumberEffect = true
                    }
                }
            } else {
                triggerShake()
            }
            return
        }

        // Check if we're entering decimal places
        if cleanAmount.contains(",") {
            let parts = cleanAmount.split(separator: ",")
            if parts.count > 1 {
                let decimalPart = parts[1]
                if decimalPart.count >= 2 {
                    triggerShake()
                    return
                }
            }
            cleanAmount += value
        } else {
            // Handle integer part
            if cleanAmount == "0" && value != "," {
                cleanAmount = value
            } else {
                let integerPart = cleanAmount.split(separator: ",").first ?? ""
                if integerPart.count >= 10 && value != "," {
                    triggerShake()
                    return
                }
                cleanAmount += value
            }
        }

        showNumberEffect = false
        lastEnteredDigit = value
        amount = formatUserInput(cleanAmount)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            withAnimation(.easeOut(duration: 0.3)) {
                showNumberEffect = true
            }
        }
    }
    
    private func handleDelete() {
        var cleanAmount = amount.replacingOccurrences(of: " ", with: "")
        
        if !cleanAmount.isEmpty {
            cleanAmount.removeLast()
            amount = formatUserInput(cleanAmount)
            HapticFeedback.play()
        }
    }
    
    // MARK: - save section
    var bottomActionSection: some View {
        BottomActionSection(
            category: selectedCategory,
            isEnabled: isValidInput(),
            onCategoryTap: {
                showingCategorySelector = true
                HapticFeedback.play()
            },
            onSaveTap: {
                HapticFeedback.play()
                saveExpense()
            }
        )
    }
    
    
    // MARK: - Body
    var body: some View {
        ZStack {
            NavigationView {
                VStack(spacing: 0) {
                    navigationBar
                        .padding(.horizontal)
                        .padding(.top, 16)
                        .background(Color(UIColor.systemBackground))
                    
                    NavigationView {
                        VStack(spacing: 0) {
                            amountSection
                        }
                    }
                    notesSection

                    
                    NumericKeypad(
                        onNumberTap: handleNumberInput,
                        onDelete: handleDelete
                    )
                    .padding(.vertical)
                    
                    bottomActionSection
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 16)
                        .frame(maxWidth: .infinity)
                        .background(Color(uiColor: .systemGray5))
                }
                .navigationBarHidden(true)
                .sheet(isPresented: $showingCurrencyPicker) {
                    CurrencyListView(selectedCurrency: $selectedCurrency)
                    .presentationCornerRadius(32)
//                    .presentationDetents([.medium, .large])
                }
                .sheet(isPresented: $showingCategorySelector) {
                    CategorySelectorView(selectedCategory: $selectedCategory)
                        .presentationCornerRadius(32)
                        .environmentObject(categoryManager)
                }
                .sheet(isPresented: $showingNotesSheet) {
                    NotesModalView(notes: $notes, tempTags: $tempTags)
                        .presentationCornerRadius(32)
                        .presentationDetents([.medium, .large])
                        .environmentObject(tagManager)
                }
                .alert("Error", isPresented: $showingErrorAlert) {
                    Button("OK", role: .cancel) { }
                } message: {
                    Text(errorMessage)
                }
                .onChange(of: selectedCurrency) {
                    if isInitialSetup { return }
                    
                    if isEditMode {
                        handleEditModeChanges()
                    } else {
                        updateRates()
                        Task { await updateConvertedAmount() }
                    }
                }

                .onChange(of: date) {
                    if isInitialSetup { return }
                    
                    if !canBeRecurring {
                        isRecurring = false
                    }
                    
                    if isEditMode {
                        handleEditModeChanges()
                    } else {
                        updateRates()
                        Task { await updateConvertedAmount() }
                    }
                }

                .onChange(of: amount) {
                    if isInitialSetup { return }
                    
                    // Simply recalculate based on whatever rate we have
                    Task { await updateConvertedAmount() }
                }
                .onAppear {
                    setupInitialData()
                }
            }
            .sheet(isPresented: $showingCalendar) {
                CalendarSheet(
                    selectedDate: $date,
                    isRecurring: $isRecurring,
                    recurringFrequency: $recurringFrequency
                ) { newDate in
                    date = newDate
                }
                .presentationCornerRadius(32)
            }
        }
    }
    
    // MARK: - Setup Methods
    private func setupInitialData() {
        isInitialSetup = true
        
        if categoryManager.categories.isEmpty {
            categoryManager.reloadCategories()
        }
        
        if let editingExpense = expense {
            setupEditMode(with: editingExpense)
            
            // For edit mode, we need to ensure the conversion display is updated
            // even during initial setup
            if selectedCurrency != defaultCurrency {
                Task {
                    // Use a special flag to bypass the isInitialSetup check
                    await updateConvertedAmount(bypassInitialSetup: true)
                }
            }
        } else {
            setupCreateMode()
        }
        
        // Reset recurrence options
        isRecurring = false
        recurringFrequency = "Monthly"
        enableNotifications = true
        
        // Clear the setup flag after a short delay to allow state to settle
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isInitialSetup = false
        }
    }

    private func setupEditMode(with expense: Expense) {
        amount = expense.amount?.stringValue ?? ""
        selectedCategory = expense.category
        date = expense.date ?? Date()
        notes = expense.notes ?? ""
        
        if let tags = expense.tags as? Set<Tag> {
            selectedTags = tags
            tempTags = tags
        }
        
        if let currencyCode = expense.currency {
            selectedCurrency = currencyManager.fetchCurrency(withCode: currencyCode)
        } else {
            selectedCurrency = defaultCurrency
        }
        
        // Check for stored rate - this handles normal expenses
        if selectedCurrency != defaultCurrency,
           let rate = expense.conversionRate?.decimalValue,
           rate > 0 {  // Make sure rate is valid
            // Store the rate
            storedRate = rate
            
            // Set sourceRate and targetRate for UI display
            sourceRate = 1.0
            targetRate = rate
            
            hasLoadedStoredRate = true
            print("📊 Using stored conversion rate: \(rate)")
        }
        // Handle imported expenses without conversion data
        else if selectedCurrency != defaultCurrency {
            // Force a fresh lookup of rates for imported expenses
            hasLoadedStoredRate = false
            storedRate = nil
            
            // Get latest rates right away for this currency
            updateRates()
            
            print("📊 No stored rate found for imported expense, fetching latest rates")
        }
    }

    // MARK: - Currency Conversion Methods
    // Single unified method for updating converted amount
    private func updateConvertedAmount(bypassInitialSetup: Bool = false) async {
        guard let selectedCurrency = selectedCurrency,
              let defaultCurrency = defaultCurrency,
              selectedCurrency != defaultCurrency else {
            await MainActor.run {
                convertedAmount = nil
            }
            return
        }

        let cleanedAmount = amount.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: ",", with: ".")

        guard let amountValue = Decimal(string: cleanedAmount) else {
            await MainActor.run {
                convertedAmount = nil
            }
            return
        }

        await MainActor.run {
            if isEditMode, hasLoadedStoredRate, let storedRate {
                convertedAmount = currencyManager.currencyConverter.formatAmount(amountValue * storedRate, currency: defaultCurrency)
            } else if let sourceRate = sourceRate, let targetRate = targetRate {
                let rate = targetRate / sourceRate
                convertedAmount = currencyManager.currencyConverter.formatAmount(amountValue * rate, currency: defaultCurrency)
            } else {
                if let result = CurrencyConverter.shared.convertAmount(amountValue, from: selectedCurrency, to: defaultCurrency, on: date) {
                    convertedAmount = result.formatted
                    sourceRate = result.rate
                    targetRate = 1.0
                }
            }
        }
    }
    
    private func handleEditModeChanges() {
        // Only run in edit mode
        guard isEditMode else { return }
        
        // Reset our flag when certain properties change
        hasLoadedStoredRate = false
        
        // Clear stored rate - we need a new one
        storedRate = nil
        
        // Force a fresh lookup
        updateRates()
        Task { await updateConvertedAmount() }
    }
    
    private func setupCreateMode() {
        if let lastUsedCategoryId = UserDefaults.standard.string(forKey: lastSelectedCategoryKey),
           let uuid = UUID(uuidString: lastUsedCategoryId) {
            // Use the in-memory categories instead of fetching again
            selectedCategory = categoryManager.categories.first { $0.id == uuid }
        }
        
        // Use the in-memory categories instead of fetching again
        selectedCategory = selectedCategory ?? categoryManager.categories.first
        selectedCurrency = defaultCurrency
    }

    
    // MARK: - Validation & Save Methods
    private func isValidInput() -> Bool {
        // Convert comma to period for Decimal parsing
        let decimalAmount = amount
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ",", with: ".")
        
        guard let amountValue = Decimal(string: decimalAmount),
              amountValue > 0,
              selectedCategory != nil,
              selectedCurrency != nil else {
            return false
        }
        
        if isRecurring && !canBeRecurring {
            return false
        }
        
        return true
    }
    
    private func saveExpense() {
        // Convert comma to period for Decimal parsing
        let decimalAmount = amount
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ",", with: ".")
        
        guard isValidInput(),
              let amountValue = Decimal(string: decimalAmount),
              let selectedCurrency = selectedCurrency,
              let category = selectedCategory else {
            errorMessage = "Please fill in all required fields"
            showingErrorAlert = true
            return
        }
        
        let success: Bool
        
        if isRecurring && canBeRecurring {
            // Create recurring expense template
            let template = RecurringExpenseManager.shared.createRecurringExpense(
                amount: amountValue,
                category: category,
                currency: selectedCurrency.code ?? "USD",
                frequency: recurringFrequency,
                startDate: date,
                notes: notes,
                notificationEnabled: enableNotifications
            )
            
            success = template != nil
        } else if let editingExpense = expense {
            // Update existing expense
            success = ExpenseDataManager.shared.updateExpense(
                editingExpense,
                amount: amountValue,
                category: category,
                date: date,
                notes: notes,
                currency: selectedCurrency,
                tags: tempTags
            )
        } else {
            // Create new regular expense
            success = ExpenseDataManager.shared.addExpense(
                amount: amountValue,
                category: category,
                date: date,
                notes: notes,
                currency: selectedCurrency,
                tags: tempTags
            )
            
            if success {
                UserDefaults.standard.set(category.id?.uuidString, forKey: lastSelectedCategoryKey)
            }
        }
        
        if success {
            dismiss()
        } else {
            errorMessage = "Failed to save expense. Please try again."
            showingErrorAlert = true
        }
    }
}
