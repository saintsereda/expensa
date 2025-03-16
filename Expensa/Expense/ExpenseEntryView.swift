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
    @Environment(\.colorScheme) private var colorScheme
    
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
    @State private var isSaving = false
    @State private var frequentCategories: [Category] = []
    
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
    
    private func loadFrequentCategories() {
        frequentCategories = categoryManager.getMostUsedCategories(limit: 3)
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
    
    // MARK: - Sections
    private var navigationBar: some View {
        HStack {
            CloseButton(
                icon: "xmark"
            ) {
                HapticFeedback.play()
                dismiss()
            }
            Spacer()
            RoundButton(
                leftIcon: isRecurring ? "calendar-recurring" : "calendar",
                label: {
                    let baseLabel = Calendar.current.isDateInToday(date) ? "Today" : date.formatted(.relative)
                    return isRecurring ? baseLabel + " • " + recurringFrequency : baseLabel
                }()
            ){
                HapticFeedback.play()
                withAnimation {
                    showingCalendar = true
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }
    
    private var amountSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 0) {
                if amount.isEmpty {
                    if let currency = selectedCurrency ?? defaultCurrency {
                        let symbol = currency.symbol ?? currency.code ?? ""
                        let isUSD = currency.code == "USD"
                        Text(isUSD ? "\(symbol)0" : "0 \(symbol)")
                            .font(.system(size: 72, weight: .regular, design: .rounded))
                            .foregroundColor(Color(UIColor.systemGray2))
                            .minimumScaleFactor(0.3)
                            .lineLimit(1)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 16)
                            .animation(.spring(response: 0.4, dampingFraction: 0.95), value: shouldShowConvertedAmount)
                    }
                } else {
                    if let currency = selectedCurrency ?? defaultCurrency {
                        let symbol = currency.symbol ?? currency.code ?? ""
                        let isUSD = currency.code == "USD"
                        
                        Text(isUSD ? "\(symbol)\(formattedAmount)" : "\(formattedAmount) \(symbol)")
                            .font(.system(size: 72, weight: .regular, design: .rounded))
                            .foregroundColor(.primary)
                            .contentTransition(.numericText())
                            .lineLimit(1)
                            .minimumScaleFactor(0.3)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 16)
                            .animation(.spring(response: 0.4, dampingFraction: 0.95), value: shouldShowConvertedAmount)
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
                        HStack(spacing: 4) {
                            Image("converted")
                                .renderingMode(.template)
                                .foregroundColor(.gray)
                            Text("\(convertedAmount ?? "") with rate \(formattedRate)")
                                .foregroundColor(.gray)
                                .font(.subheadline)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .contentTransition(.numericText())
                                .animation(.spring(response: 0.4, dampingFraction: 0.95), value: rateString)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .animation(.spring(response: 0.4, dampingFraction: 0.95), value: convertedAmount)
            }
        }
//        .padding(.vertical, shouldShowConvertedAmount ? 16 : 8)
        .padding(.horizontal, 16)
        .animation(.spring(response: 0.4, dampingFraction: 0.95), value: shouldShowConvertedAmount)
    }
    
    // MARK: - category section
//    private var categoryButtonSection: some View {
//        HStack {
//            CategoryButton(category: selectedCategory) {
//                showingCategorySelector = true
//                HapticFeedback.play()
//            }
//        }
//        .padding()
//    }
    
    private var categoryButtonSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // 1. Main CategoryButton (always shown)
                CategoryButton() {
                    showingCategorySelector = true
                    HapticFeedback.play()
                }
                
                // 2. Last selected category (if not already selected)
                if let lastUsedCategoryId = UserDefaults.standard.string(forKey: lastSelectedCategoryKey),
                   let uuid = UUID(uuidString: lastUsedCategoryId),
                   let lastCategory = categoryManager.categories.first(where: { $0.id == uuid }),
                   !frequentCategories.contains(lastCategory) {
                    
                    FrequentCategoryButton(
                        category: lastCategory,
                        isSelected: selectedCategory == lastCategory,
                        isLastSelected: true
                    ) {
                        selectedCategory = lastCategory
                        HapticFeedback.play()
                    }
                }
                
                // 3. Frequent categories
                ForEach(frequentCategories, id: \.self) { category in
                    FrequentCategoryButton(
                        category: category,
                        isSelected: selectedCategory == category,
                        isLastSelected: false
                    ) {
                        selectedCategory = category
                        HapticFeedback.play()
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 8)
    }

    // Updated FrequentCategoryButton with lastSelected flag
    struct FrequentCategoryButton: View {
        let category: Category
        let isSelected: Bool
        let isLastSelected: Bool
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                HStack(alignment: .center, spacing: 6) {
                    Text(category.icon ?? "🔹")
                        .font(.system(size: 16))
                    
                    Text(category.name ?? "Category")
                        .font(.body)
                        .foregroundColor(Color(uiColor: .label))
                    
                    // Optional indicator for last selected

                }
                .padding(.horizontal, 16)
                .frame(height: 48, alignment: .center)
                .background(isSelected ? Color(uiColor: .systemGray5) : Color.clear)
                .cornerRadius(99)
                .overlay(
                    RoundedRectangle(cornerRadius: 99)
                        .stroke(Color(uiColor: .systemGray5), lineWidth: 2)
                )
            }
        }
    }
    
    // MARK: - save section
    private var bottomActionSection: some View {
        HStack(alignment: .center, spacing: 16) {
            if !notes.isEmpty {
                // Show the actual notes when they've been written
                GhostButton(
                    leftIcon: "note-added",
                    label: notes
                ) {
                    HapticFeedback.play()
                    showingNotesSheet = true

                }
                .disabled(isSaving)
                .lineLimit(1)
            } else {
                // Show the default "Add notes" for empty notes
                GhostButton(
                    leftIcon: "note",
                    label: "Add notes or tags"
                ) {
                    HapticFeedback.play()
                    showingNotesSheet = true

                }
                .opacity(0.64)
                .disabled(isSaving)
            }
            Spacer()
            SaveButton(isEnabled: isValidInput(), action: saveExpense)
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Body
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Main rounded rectangle content section
                ZStack {
                    // Background with dynamic color logic
                    RoundedRectangle(cornerRadius: 40, style: .continuous)
                        .fill(colorScheme == .dark ? Color(UIColor.systemGray6) : Color(UIColor.systemBackground))
                        .edgesIgnoringSafeArea([.top])
                    
                    // Content with responsive spacing
                    VStack(spacing: 0) {
                        // Navigation bar - fixed top padding
                        navigationBar
                        
                        // Responsive spacing
                        Spacer()
                        
                        // Amount section
                        amountSection
                        
                        // Responsive spacing
                        Spacer()
                        
                        // Category button section
                        categoryButtonSection
                        
                        // Numeric keypad - fixed bottom padding
                        NumericKeypad(
                            onNumberTap: handleNumberInput,
                            onDelete: handleDelete
                        )
                        .padding(.bottom, 20)
                    }
                }
                .frame(maxHeight: .infinity)
                
                // Fixed spacing between rounded rectangle and bottom section
                Spacer(minLength: 12)

                
                // Bottom section with fixed height
                bottomActionSection
                    .frame(height: 48)
                
                // Bottom safe area spacing
                Spacer(minLength: 0)
                    .frame(height: max(geometry.safeAreaInsets.bottom, 16))
            }
            .background(
                colorScheme == .dark
                ? Color(UIColor.systemBackground).edgesIgnoringSafeArea(.all)
                : Color(UIColor.systemGray6).edgesIgnoringSafeArea(.all)
            )
            .navigationBarHidden(true)
            .sheet(isPresented: $showingCurrencyPicker) {
                CurrencyListView(selectedCurrency: $selectedCurrency)
                    .presentationCornerRadius(32)
            }
            .sheet(isPresented: $showingCategorySelector) {
                CategorySelectorView(selectedCategory: $selectedCategory)
                    .presentationCornerRadius(32)
                    .environmentObject(categoryManager)
            }
            .sheet(isPresented: $showingNotesSheet) {
                NotesModalView(notes: $notes, tempTags: $tempTags)
                    .presentationCornerRadius(32)
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
            .edgesIgnoringSafeArea(.bottom)
        }
    }
    
    // MARK: - helpers
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
        loadFrequentCategories()
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
        loadFrequentCategories()
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
        // Prevent multiple simultaneous save operations
        guard !isSaving else { return }
        
        // Start a save operation
        isSaving = true
        
        // Pre-validate input outside of the async context
        let decimalAmount = amount
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ",", with: ".")
        
        guard isValidInput(),
              let amountValue = Decimal(string: decimalAmount),
              let selectedCurrency = selectedCurrency,
              let category = selectedCategory else {
            errorMessage = "Please fill in all required fields"
            showingErrorAlert = true
            isSaving = false
            return
        }
        
        // Move the save operation to a background task to avoid UI blocking
        Task {
            var success = false
            
            // We're not using any throwing functions here, so no need for try/catch
            // Give the UI a chance to update with loading state
            await Task.yield()
            
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
            
            // Small delay to ensure database operations have time to complete
            // Only use try-await with functions that are actually marked as throwing
            do {
                try await Task.sleep(nanoseconds: 100_000_000) // 100ms
            } catch {
                // Handle cancellation
                print("Task was cancelled")
            }
            
            // Update UI on the main thread
            await MainActor.run {
                isSaving = false
                
                if success {
                    // Show success feedback before dismissing
                    HapticFeedback.play()
                    
                    // Call completion handler to notify parent views
                    onComplete?()
                    
                    // Dismiss the view
                    dismiss()
                } else {
                    errorMessage = "Failed to save expense. Please try again."
                    showingErrorAlert = true
                    HapticFeedback.play()
                }
            }
        }
    }
}
