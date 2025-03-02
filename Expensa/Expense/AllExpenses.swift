import SwiftUI
import CoreData

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct EmptyStateView: View {
    enum EmptyStateType {
        case search
        case category
        
        var icon: String {
            switch self {
            case .search: return "magnifyingglass"
            case .category: return "tag"
            }
        }
        
        var title: String {
            switch self {
            case .search: return "No matching expenses found"
            case .category: return "No expenses in selected categories"
            }
        }
        
        var message: String {
            switch self {
            case .search: return "Try adjusting your search terms"
            case .category: return "Try selecting different categories"
            }
        }
    }
    
    let type: EmptyStateType
    
    var body: some View {
        VStack(spacing: 16) {
            Circle()
                .fill(Color(.systemGray6))
                .frame(width: 80, height: 80)
                .overlay(
                    Image(systemName: type.icon)
                        .font(.system(size: 32))
                        .foregroundColor(.gray)
                )
            
            Text(type.title)
                .font(.headline)
            
            Text(type.message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

struct FilterButton: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(label)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.4, dampingFraction: 0.95), value: label)
                if isSelected {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 40, alignment: .center)
            .background(isSelected ? Color(uiColor: .systemGray5) : Color(uiColor: .secondarySystemBackground))
            .foregroundColor(isSelected ? .primary : .secondary)
            .cornerRadius(999)
        }
    }
}

struct AllExpenses: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var tagManager: TagManager
    @State private var selectedExpense: Expense?
    @State private var searchText = ""
    @State private var showingCategoryFilter = false
    @State private var selectedCategories: Set<Category> = []
    @State private var currentPage = 0
    private let itemsPerPage = 50
    
    // Add these states for tag filtering
    @State private var selectedTags: Set<Tag> = []
    @State private var showingTagFilter = false
    @State private var hasTags: Bool = false
    
    // States for pull-up behavior
    @State private var isRefreshing = false
    @State private var scrollOffset: CGFloat = 0
    @State private var pullDistance: CGFloat = 0
    @State private var scrollDifference: CGFloat = 0
    
    var predicate: NSPredicate {
        var predicates: [NSPredicate] = [
            NSPredicate(format: "date <= %@", Date() as NSDate)
        ]
        
        if !searchText.isEmpty {
            predicates.append(NSPredicate(format: "category.name CONTAINS[cd] %@ OR notes CONTAINS[cd] %@",
                                        searchText, searchText))
        }
        
        if !selectedCategories.isEmpty {
            predicates.append(NSPredicate(format: "category IN %@", selectedCategories))
        }
        
        // Add tag filtering
        if !selectedTags.isEmpty {
            predicates.append(NSPredicate(format: "ANY tags IN %@", selectedTags))
        }
        
        return NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    }
    
    @FetchRequest(
        sortDescriptors: [SortDescriptor(\.date, order: .reverse)],
        predicate: NSPredicate(format: "date <= %@", Date() as NSDate)
    ) private var allExpenses: FetchedResults<Expense>
    
    var categoryButtonLabel: String {
        if selectedCategories.isEmpty {
            return "Category"
        }
        if selectedCategories.count == 1 {
            return selectedCategories.first?.name ?? "Category"
        }
        return "\(selectedCategories.count) categories"
    }
    
    var tagButtonLabel: String {
        if selectedTags.isEmpty {
            return "Tags"
        }
        if selectedTags.count == 1 {
            return "#\(selectedTags.first?.name ?? "")"
        }
        return "\(selectedTags.count) tags"
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Search and filter section
                VStack(alignment: .leading, spacing: 8) {
                    SearchBar(text: $searchText)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            FilterButton(
                                label: categoryButtonLabel,
                                isSelected: !selectedCategories.isEmpty,
                                action: {
                                    if !selectedCategories.isEmpty {
                                        selectedCategories.removeAll()
                                    } else {
                                        showingCategoryFilter = true
                                    }
                                }
                            )
                            
                            // Only show tags filter button if there are tags
                            if hasTags {
                                FilterButton(
                                    label: tagButtonLabel,
                                    isSelected: !selectedTags.isEmpty,
                                    action: {
                                        if !selectedTags.isEmpty {
                                            selectedTags.removeAll()
                                        } else {
                                            showingTagFilter = true
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.bottom, 4)
                    }
                }
                .padding(.horizontal)
                
                // Main content
                let displayedExpenses = Array(allExpenses.prefix(itemsPerPage * (currentPage + 1)))
                
                if displayedExpenses.isEmpty {
                    if !searchText.isEmpty {
                        EmptyStateView(type: .search)
                    } else if !selectedCategories.isEmpty {
                        EmptyStateView(type: .category)
                    } else if !selectedTags.isEmpty {
                        // Add tag specific empty state
                        EmptyStateView(type: .search)
                    } else {
                        EmptyStateView(type: .search)
                    }
                } else {
                    LazyVStack(spacing: 0) {
                        GroupedExpensesView(
                            expenses: displayedExpenses,
                            onExpenseSelected: { expense in
                                selectedExpense = expense
                            }
                        )
                        .padding(.horizontal)
                        
                        // Pull-up message section
                        GeometryReader { geometry in
                            let maxY = geometry.frame(in: .named("scroll")).maxY
                            
                            VStack {
                                if pullDistance > 0 {  // Simple condition
                                    Text("No more expenses to show 😎")
                                        .foregroundColor(.gray)
                                        .font(.subheadline)
                                }
                            }
                            .frame(height: 32)
                            .frame(maxWidth: .infinity)
                            .offset(y: 32)
                            .preference(
                                key: ScrollOffsetPreferenceKey.self,
                                value: maxY
                            )
                        }
                    }
                    .padding(.bottom, -8)
                }
            }
            .padding(.top, 16)
        }
        .coordinateSpace(name: "scroll")
        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
            let previousOffset = scrollOffset
            scrollOffset = offset
            
            if !isRefreshing {
                let scrollDifference = previousOffset - offset
                pullDistance = min(max(0, pullDistance + scrollDifference), 60)
                if pullDistance >= 10 {
                    isRefreshing = true
                    currentPage += 1
                    DispatchQueue.main.asyncAfter(deadline: .now()) {
                        withAnimation {
                            isRefreshing = false
                            pullDistance = 0
                        }
                    }
                }
            }
        }
        .navigationTitle("All expenses")
        .onAppear {
            // Reset filters when view appears
            selectedCategories.removeAll()
            selectedTags.removeAll()
            searchText = ""
            currentPage = 0
            updatePredicate()
            checkForTags()
        }
        .sheet(item: $selectedExpense) { _ in
            ExpenseDetailView(
                expense: $selectedExpense,
                onDelete: {
                    if let expense = selectedExpense {
                        ExpenseDataManager.shared.deleteExpense(expense)
                        selectedExpense = nil
                        currentPage = 0  // Reset pagination when deleting
                    }
                }
            )
        }
        .sheet(isPresented: $showingCategoryFilter) {
            CategorySheet(selectedCategories: $selectedCategories)
        }
        .sheet(isPresented: $showingTagFilter) {
            TagSheet(selectedTags: $selectedTags)
        }
        .onChange(of: selectedCategories) {
            updatePredicate()
        }
        .onChange(of: selectedTags) {
            updatePredicate()
        }
        .onChange(of: searchText) {
            updatePredicate()
        }
    }
    
    private func updatePredicate() {
        currentPage = 0
        allExpenses.nsPredicate = predicate
    }
    
    private func checkForTags() {
        // Check if there are any tags in the system
        let fetchRequest: NSFetchRequest<Tag> = Tag.fetchRequest()
        fetchRequest.fetchLimit = 1
        
        do {
            let count = try viewContext.count(for: fetchRequest)
            hasTags = count > 0
        } catch {
            print("Error checking for tags: \(error)")
            hasTags = false
        }
    }
}


//import SwiftUI
//import CoreData
//
//struct ScrollOffsetPreferenceKey: PreferenceKey {
//    static var defaultValue: CGFloat = 0
//    
//    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
//        value = nextValue()
//    }
//}
//
//struct EmptyStateView: View {
//    enum EmptyStateType {
//        case search
//        case category
//        
//        var icon: String {
//            switch self {
//            case .search: return "magnifyingglass"
//            case .category: return "tag"
//            }
//        }
//        
//        var title: String {
//            switch self {
//            case .search: return "No matching expenses found"
//            case .category: return "No expenses in selected categories"
//            }
//        }
//        
//        var message: String {
//            switch self {
//            case .search: return "Try adjusting your search terms"
//            case .category: return "Try selecting different categories"
//            }
//        }
//    }
//    
//    let type: EmptyStateType
//    
//    var body: some View {
//        VStack(spacing: 16) {
//            Circle()
//                .fill(Color(.systemGray6))
//                .frame(width: 80, height: 80)
//                .overlay(
//                    Image(systemName: type.icon)
//                        .font(.system(size: 32))
//                        .foregroundColor(.gray)
//                )
//            
//            Text(type.title)
//                .font(.headline)
//            
//            Text(type.message)
//                .font(.subheadline)
//                .foregroundColor(.secondary)
//                .multilineTextAlignment(.center)
//        }
//        .frame(maxWidth: .infinity)
//        .padding(.vertical, 40)
//    }
//}
//
//struct FilterButton: View {
//    let label: String
//    let isSelected: Bool
//    let action: () -> Void
//    
//    var body: some View {
//        Button(action: action) {
//            HStack {
//                Text(label)
//                if isSelected {
//                    Image(systemName: "xmark.circle.fill")
//                        .foregroundColor(.secondary)
//                }
//            }
//            .padding(.horizontal, 16)
//            .padding(.vertical, 8)
//            .background(isSelected ? Color.accentColor : Color.accentColor.opacity(0.1))
//            .foregroundColor(isSelected ? .white : .accentColor)
//            .cornerRadius(10)
//        }
//    }
//}
//
//struct AllExpenses: View {
//    @Environment(\.managedObjectContext) private var viewContext
//    @State private var selectedExpense: Expense?
//    @State private var searchText = ""
//    @State private var showingCategoryFilter = false
//    @State private var selectedCategories: Set<Category> = []
//    @State private var currentPage = 0
//    private let itemsPerPage = 50
//    
//    // States for pull-up behavior
//    @State private var isRefreshing = false
//    @State private var scrollOffset: CGFloat = 0
//    @State private var pullDistance: CGFloat = 0
//    
//    var predicate: NSPredicate {
//        var predicates: [NSPredicate] = [
//            NSPredicate(format: "date <= %@", Date() as NSDate)
//        ]
//        
//        if !searchText.isEmpty {
//            predicates.append(NSPredicate(format: "category.name CONTAINS[cd] %@ OR notes CONTAINS[cd] %@",
//                                        searchText, searchText))
//        }
//        
//        if !selectedCategories.isEmpty {
//            predicates.append(NSPredicate(format: "category IN %@", selectedCategories))
//        }
//        
//        return NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
//    }
//    
//    @FetchRequest(
//        sortDescriptors: [SortDescriptor(\.date, order: .reverse)],
//        predicate: NSPredicate(format: "date <= %@", Date() as NSDate)
//    ) private var allExpenses: FetchedResults<Expense>
//    
//    var categoryButtonLabel: String {
//        if selectedCategories.isEmpty {
//            return "Category"
//        }
//        if selectedCategories.count == 1 {
//            return selectedCategories.first?.name ?? "Category"
//        }
//        return "\(selectedCategories.count) categories"
//    }
//    
//    var body: some View {
//        ScrollView {
//            VStack(spacing: 16) {
//                // Search and filter section
//                VStack(alignment: .leading, spacing: 8) {
//                    SearchBar(text: $searchText)
//                    
//                    HStack(spacing: 8) {
//                        FilterButton(
//                            label: categoryButtonLabel,
//                            isSelected: !selectedCategories.isEmpty,
//                            action: {
//                                if !selectedCategories.isEmpty {
//                                    selectedCategories.removeAll()
//                                } else {
//                                    showingCategoryFilter = true
//                                }
//                            }
//                        )
//                    }
//                }
//                .padding(.horizontal)
//                
//                // Main content
//                let displayedExpenses = Array(allExpenses.prefix(itemsPerPage * (currentPage + 1)))
//                
//                if displayedExpenses.isEmpty {
//                    if !searchText.isEmpty {
//                        EmptyStateView(type: .search)
//                    } else if !selectedCategories.isEmpty {
//                        EmptyStateView(type: .category)
//                    } else {
//                        EmptyStateView(type: .search)
//                    }
//                } else {
//                    LazyVStack(spacing: 0) {
//                        GroupedExpensesView(
//                            expenses: displayedExpenses,
//                            onExpenseSelected: { expense in
//                                selectedExpense = expense
//                            }
//                        )
//                        .padding(.horizontal)
//                        
//                        // Pull-up message section
//                        GeometryReader { geometry in
//                            let maxY = geometry.frame(in: .named("scroll")).maxY
//                            
//                            VStack {
//                                if pullDistance > 0 {
//                                    Text("No more expenses to show 😎")
//                                        .foregroundColor(.gray)
//                                        .font(.subheadline)
//                                }
//                            }
//                            .frame(height: 32)
//                            .frame(maxWidth: .infinity)
//                            .offset(y: 32)
//                            .preference(
//                                key: ScrollOffsetPreferenceKey.self,
//                                value: maxY
//                            )
//                        }
//                    }
//                    .padding(.bottom, -8)
//                }
//            }
//            .padding(.top, 16)
//        }
//        .coordinateSpace(name: "scroll")
//        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
//            let previousOffset = scrollOffset
//            scrollOffset = offset
//            
//            if !isRefreshing {
//                let scrollDifference = previousOffset - offset
//                pullDistance = min(max(0, pullDistance + scrollDifference), 60)
//                
//                if pullDistance >= 10 {
//                    isRefreshing = true
//                    currentPage += 1
//                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
//                        withAnimation {
//                            isRefreshing = false
//                            pullDistance = 0
//                        }
//                    }
//                }
//            }
//        }
//        .navigationTitle("All expenses")
//        .onAppear {
//            // Reset filters when view appears
//            selectedCategories.removeAll()
//            searchText = ""
//            currentPage = 0
//            updatePredicate()
//        }
//        .sheet(item: $selectedExpense) { _ in
//            ExpenseDetailView(
//                expense: $selectedExpense,
//                onDelete: {
//                    if let expense = selectedExpense {
//                        ExpenseDataManager.shared.deleteExpense(expense)
//                        selectedExpense = nil
//                        currentPage = 0  // Reset pagination when deleting
//                    }
//                }
//            )
//        }
//        .sheet(isPresented: $showingCategoryFilter) {
//            CategorySheet(selectedCategories: $selectedCategories)
//        }
//        .onChange(of: selectedCategories) {
//            updatePredicate()
//        }
//        .onChange(of: searchText) {
//            updatePredicate()
//        }
//    }
//    
//    private func updatePredicate() {
//        currentPage = 0
//        allExpenses.nsPredicate = predicate
//    }
//}


//import SwiftUI
//import CoreData
//
//struct ScrollOffsetPreferenceKey: PreferenceKey {
//    static var defaultValue: CGFloat = 0
//    
//    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
//        value = nextValue()
//    }
//}
//
//struct AllExpenses: View {
//    @Environment(\.managedObjectContext) private var viewContext
//    @State private var selectedExpense: Expense?
//    @State private var searchText = ""
//    @State private var showingCategoryFilter = false
//    @State private var selectedCategories: Set<Category> = []
//    @State private var expenses: [Expense] = []
//    
//    // New states for pull-up behavior
//    @State private var isRefreshing = false
//    @State private var scrollOffset: CGFloat = 0
//    @State private var pullDistance: CGFloat = 0
//    
//    struct EmptyStateView: View {
//        enum EmptyStateType {
//            case search
//            case category
//            
//            var icon: String {
//                switch self {
//                case .search: return "magnifyingglass"
//                case .category: return "tag"
//                }
//            }
//            
//            var title: String {
//                switch self {
//                case .search: return "No matching expenses found"
//                case .category: return "No expenses in selected categories"
//                }
//            }
//            
//            var message: String {
//                switch self {
//                case .search: return "Try adjusting your search terms"
//                case .category: return "Try selecting different categories"
//                }
//            }
//        }
//        
//        let type: EmptyStateType
//        
//        var body: some View {
//            VStack(spacing: 16) {
//                Circle()
//                    .fill(Color(.systemGray6))
//                    .frame(width: 80, height: 80)
//                    .overlay(
//                        Image(systemName: type.icon)
//                            .font(.system(size: 32))
//                            .foregroundColor(.gray)
//                    )
//                
//                Text(type.title)
//                    .font(.headline)
//                
//                Text(type.message)
//                    .font(.subheadline)
//                    .foregroundColor(.secondary)
//                    .multilineTextAlignment(.center)
//            }
//            .frame(maxWidth: .infinity)
//            .padding(.vertical, 40)
//        }
//    }
//    
//    struct FilterButton: View {
//        let label: String
//        let isSelected: Bool
//        let action: () -> Void
//        
//        var body: some View {
//            Button(action: action) {
//                HStack {
//                    Text(label)
//                    if isSelected {
//                        Image(systemName: "xmark.circle.fill")
//                            .foregroundColor(.secondary)
//                    }
//                }
//                .padding(.horizontal, 16)
//                .padding(.vertical, 8)
//                .background(isSelected ? Color.accentColor : Color.accentColor.opacity(0.1))
//                .foregroundColor(isSelected ? .white : .accentColor)
//                .cornerRadius(10)
//            }
//        }
//    }
//    
//    var categoryButtonLabel: String {
//        if selectedCategories.isEmpty {
//            return "Category"
//        }
//        if selectedCategories.count == 1 {
//            return selectedCategories.first?.name ?? "Category"
//        }
//        return "\(selectedCategories.count) categories"
//    }
//    
//    private func fetchExpenses() {
//        let fetchRequest: NSFetchRequest<Expense> = Expense.fetchRequest()
//        
//        var predicates: [NSPredicate] = [
//            NSPredicate(format: "date <= %@", Date() as NSDate)
//        ]
//        
//        if !searchText.isEmpty {
//            predicates.append(NSPredicate(format: "category.name CONTAINS[cd] %@ OR notes CONTAINS[cd] %@",
//                                        searchText, searchText))
//        }
//        
//        if !selectedCategories.isEmpty {
//            predicates.append(NSPredicate(format: "category IN %@", selectedCategories))
//        }
//        
//        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
//        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Expense.date, ascending: false)]
//        
//        do {
//            expenses = try viewContext.fetch(fetchRequest)
//        } catch {
//            print("Error fetching expenses: \(error)")
//        }
//    }
//    
//    var body: some View {
//        ScrollView {
//            VStack(spacing: 16) {
//                // Search and filter section
//                VStack(alignment: .leading, spacing: 8) {
//                    SearchBar(text: $searchText)
//                    
//                    HStack(spacing: 8) {
//                        FilterButton(
//                            label: categoryButtonLabel,
//                            isSelected: !selectedCategories.isEmpty,
//                            action: {
//                                if !selectedCategories.isEmpty {
//                                    selectedCategories.removeAll()
//                                } else {
//                                    showingCategoryFilter = true
//                                }
//                            }
//                        )
//                    }
//                }
//                .padding(.horizontal)
//                
//                // Main content
//                if expenses.isEmpty {
//                    if !searchText.isEmpty {
//                        EmptyStateView(type: .search)
//                    } else if !selectedCategories.isEmpty {
//                        EmptyStateView(type: .category)
//                    } else {
//                        EmptyStateView(type: .search)
//                    }
//                } else {
//                    LazyVStack(spacing: 0) {
//                        GroupedExpensesView(
//                            expenses: expenses,
//                            onExpenseSelected: { expense in
//                                selectedExpense = expense
//                            }
//                        )
//                        .padding(.horizontal)
//                        
//                        // Pull-up message section
//                        GeometryReader { geometry in
//                            let maxY = geometry.frame(in: .named("scroll")).maxY
//                            
//                            VStack {
//                                if pullDistance > 0 {
//                                    Text("No more expenses to show 😎")
//                                        .foregroundColor(.gray)
//                                        .font(.subheadline)
//                                }
//                            }
//                            .frame(height: 32)
//                            .frame(maxWidth: .infinity)
//                            .offset(y: 32)
//                            .preference(
//                                key: ScrollOffsetPreferenceKey.self,
//                                value: maxY
//                            )
//                        }
//                    }
//                    .padding(.bottom, -8)
//                }
//            }
//            .padding(.top, 16)
//        }
//        .coordinateSpace(name: "scroll")
//        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
//            let previousOffset = scrollOffset
//            scrollOffset = offset
//            
//            if !isRefreshing {
//                let scrollDifference = previousOffset - offset
//                pullDistance = min(max(0, pullDistance + scrollDifference), 60)
//                
//                if pullDistance >= 10 {
//                    isRefreshing = true
//                    DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
//                        withAnimation {
//                            isRefreshing = false
//                            pullDistance = 0
//                        }
//                    }
//                }
//            }
//        }
//        .navigationTitle("All expenses")
//        .onAppear {
//            fetchExpenses()
//        }
//        .sheet(item: $selectedExpense) { _ in
//            ExpenseDetailView(
//                expense: $selectedExpense,
//                onDelete: {
//                    if let expense = selectedExpense {
//                        ExpenseDataManager.shared.deleteExpense(expense)
//                        selectedExpense = nil
//                        fetchExpenses()
//                    }
//                }
//            )
//        }
//        .sheet(isPresented: $showingCategoryFilter) {
//            CategorySheet(selectedCategories: $selectedCategories)
//        }
//        .onChange(of: selectedCategories) { _ in
//            fetchExpenses()
//        }
//        .onChange(of: searchText) { _ in
//            fetchExpenses()
//        }
//    }
//}
