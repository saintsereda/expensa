# Expensa — Feature Knowledge Base

> Internal reference for blog writing. Describes what the Expensa iOS app actually does today, based on a read of the source at `/Users/andrewsereda/Personal/Pet-projects/ExpenseTracker`.
> Generated: 2026-04-17

## Quick Facts

- **Platform:** iOS 17.0+ (some features require iOS 18+)
- **Tech Stack:** SwiftUI, Core Data, CloudKit (NSPersistentCloudKitContainer), Swift 6+
- **Data Model:** Multi-space, multi-account architecture; space is the primary data boundary
- **Sync:** iCloud CloudKit with persistent change tracking and remote notifications
- **AI Providers:** OpenAI GPT-4o-mini (receipt scanning, merchant categorization, smart budget allocation), Apple Vision Framework (fallback)
- **Exchange Rates:** OpenExchangeRates API (live rates) + Supabase cache layer
- **Monetization:** RevenueCat subscription management; free tier with limits, premium plan
- **Source:** 279 Swift files across Views, ViewModels, Services, Repositories, Models

---

## Feature Areas

### Transactions — Core CRUD & Entry

#### Manual Transaction Entry
- **What it does:** Add expense, income, or transfer transactions with amount, currency, category, notes, merchant name, date, account, and tags.
- **User flow:** Main dashboard → "+" button → select type (expense/income/transfer) → fill amount/currency → select account → pick category → add optional notes/merchant/tags → save.
- **Details:** Custom numeric keypad input with locale-aware decimal separator handling (both "." and "," accepted). Amount entry supports calculator-style expressions if enabled in settings. Currency picker in transaction form. Automatic suggestion of last-used category. Real-time exchange rate lookup if multi-currency. Haptic feedback on amount entry.
- **Plan:** Free (basic entry) | Premium (multi-currency add flow, AI categorization on import)
- **Code:** `/ExpenseTracker/Views/Transactions/AddTransactionView.swift`, `/ExpenseTracker/ViewModels/Transactions/AddTransactionViewModel.swift`, `/ExpenseTracker/Services/Transactionservice.swift`

#### Transaction List & Details
- **What it does:** View all transactions in a filterable, searchable, sortable list; drill into a transaction to see full details and edit.
- **User flow:** Dashboard → "Transactions" tab → filter/search → tap to open detail sheet → edit or delete.
- **Details:** Supports filtering by date range, account, category, tags, transaction type (expense/income/transfer). Search across merchant name and notes. Sort by date, amount, category. Group by date or category. Pull-to-refresh syncs with iCloud. Transaction detail sheet shows all fields and allows inline edits. Swipe actions for quick delete/edit.
- **Plan:** Free
- **Code:** `/ExpenseTracker/Views/Transactions/TransactionListView.swift`, `/ExpenseTracker/ViewModels/Transactions/TransactionListViewModel.swift`

#### Receipt & Check Scanning
- **What it does:** Scan a physical receipt/bill/bank statement via camera or photo library to auto-extract transaction details (amount, date, currency, merchant).
- **User flow:** Dashboard or Add Transaction → "Scan Receipt" button → camera or photo library picker → review extracted data → (optional) confirm category → save as transaction.
- **Details:** 
  - **Primary method (if OpenAI API key configured):** GPT-4o-mini Vision API with structured JSON output. Resizes images to max 1024px for performance. Extracts amount, currency, date, merchant name, and receipt datetime (when both date and time are present).
  - **Fallback (Apple Vision):** Text recognition via Vision framework + regex-based parsing. Supports amounts in multiple formats (e.g., 123.45, 1 234,56). Detects currency codes (USD, EUR, PLN, etc.) and symbols.
  - **Free tier limit:** 5 lifetime scans.
  - **Premium tier:** 30 scans/month.
  - **AI categorization:** If OpenAI API is available and premium, merchant name is auto-categorized using AI; else user selects manually or AI shows "not sure" state.
  - **Supported receipt types:** Receipts, bank statements, invoices, bills.
  - **Language support:** Multi-language text recognition (Cyrillic, Latin, etc.).
- **Plan:** Free (5 scans lifetime) | Premium (30/month)
- **Code:** `/ExpenseTracker/Services/CheckScanService.swift` (Apple Vision fallback), `/ExpenseTracker/Services/OpenAICheckScanService.swift` (OpenAI primary), `/ExpenseTracker/Views/CheckProcessing/CheckProcessingView.swift`, `/ExpenseTracker/ViewModels/CheckProcessing/CheckProcessingViewModel.swift`

#### Share Sheet Receipt Scanning Extension
- **What it does:** Scan a receipt from Photos or any app that supports share sheet without opening the main app.
- **User flow:** Open image in Photos or share from another app → "Share" button → "Scan with Expensa" → system processes scan and deeplinks into main app if available.
- **Details:** Standalone Share Extension target. Performs scan processing (OpenAI or Vision fallback). Returns extracted transaction to main app via deep link when available.
- **Plan:** Free (subject to lifetime/monthly quota)
- **Code:** `/ScanReceiptExtension/` (empty in current state — likely removed or refactored)

#### Recurring Transactions
- **What it does:** Create a template for recurring expenses/income/transfers that auto-generates transactions on a schedule (daily, weekly, bi-weekly, monthly, quarterly, yearly, custom).
- **User flow:** Dashboard → "Recurring" → "+" → fill template details (amount, account, category, frequency, start date, optional end date) → "Create".
- **Details:**
  - **Frequency support:** Daily, weekly, bi-weekly, monthly, quarterly, yearly, custom interval in days.
  - **Catch-up generation:** When app launches or refreshes, any overdue recurring templates automatically create transactions up to today, with idempotency checks (no duplicate if same-day transaction exists).
  - **Pause/Resume:** Temporarily pause recurrence without deleting; resume later.
  - **Cancel:** Soft-delete with cancellation timestamp; active transactions remain.
  - **Notifications:** Optional reminders on day of or day before due date (configurable via notification settings).
  - **Free tier limit:** 3 active recurrences.
  - **Premium:** Unlimited.
  - **Next run date tracking:** System tracks when the next transaction should generate.
- **Plan:** Free (3 active) | Premium (unlimited)
- **Code:** `/ExpenseTracker/Services/RecurrenceService.swift`, `/ExpenseTracker/Views/Recurrence/EditRecurrenceView.swift`, `/ExpenseTracker/ViewModels/Recurrence/EditRecurrenceViewModel.swift`

#### Transaction Tags
- **What it does:** Create custom tags (e.g., "business", "gift", "travel") and attach them to transactions for secondary categorization and filtering.
- **User flow:** Settings → Tags → "+" to create → transaction detail → add tags from list.
- **Details:** User-created tags with custom colors. Tags are space-scoped. Can filter transactions by tag. Can bulk-apply tags via multi-operation mode. Displayed as colored pills on transaction list.
- **Plan:** Free
- **Code:** `/ExpenseTracker/Views/Tags/TagsListView.swift`, `/ExpenseTracker/ViewModels/Tags/TagListViewModel.swift`

#### Transfers (Inter-Account)
- **What it does:** Move money between two of your own accounts (not a payment to another person).
- **User flow:** Add Transaction → select "Transfer" type (only appears if 2+ accounts) → pick "from" and "to" accounts → amount → save.
- **Details:** Automatically creates matching transactions in both accounts. Exchange rate applied if accounts are in different currencies. Marked with transfer icon in transaction list. Can edit or delete, which updates both sides.
- **Plan:** Free
- **Code:** `/ExpenseTracker/ViewModels/Transactions/AddTransactionViewModel.swift`

### Accounts — Wallet & Balance Tracking

#### Account Management
- **What it does:** Create and manage financial accounts (cash wallets, credit cards, bank accounts, savings, investment accounts).
- **User flow:** Settings → Accounts → view all accounts → "+" to add new or tap to edit existing.
- **Details:** Each account has name, type, currency, initial balance, icon, and color. Types: cash, bank, creditCard, savings, investment. Can mark as primary, hidden, or archived. System tracks account balance dynamically (sum of all transactions). Multi-currency support — each account can be in a different currency.
- **Plan:** Free (2 accounts) | Premium (unlimited)
- **Code:** `/ExpenseTracker/Views/Accounts/AccountsManagementView.swift`, `/ExpenseTracker/ViewModels/Accounts/AccountsManagementViewModel.swift`

#### Account Balance Tracking
- **What it does:** Display current balance and historical balance changes for each account.
- **User flow:** Dashboard or Accounts screen → tap an account to see balance and transaction history.
- **Details:** Calculated dynamically from transactions. Displays in account's native currency. Shows net worth progress line across accounts (all converted to base currency for display). Can see running balance trends over time.
- **Plan:** Free
- **Code:** `/ExpenseTracker/Views/Accounts/NetWorthProgressLine.swift`, `/ExpenseTracker/Views/Accounts/NetWorthTrendChart.swift`

#### Apple Wallet Integration (Import)
- **What it does:** Import credit card or payment card transactions from Apple Wallet via App Intent automation.
- **User flow:** Set up Shortcuts automation on Apple Wallet transaction → Expensa receives amount, merchant, date → auto-categorizes (if premium + API) → adds transaction without opening app.
- **Details:** Triggered via AppIntent (ImportWalletTransactionIntent). Parses amount (supports "$25.50", "25,50 EUR", etc.), merchant name, and date. Automatically categorizes using merchant categorization service if available. Stores target space preference in settings. Returns local notification with transaction summary. Optionally notifies if purchase exceeded category budget.
- **Plan:** Free (basic import) | Premium (AI categorization, AI category-name matching)
- **Code:** `/ExpenseTracker/Intents/ImportWalletTransactionIntent.swift`, `/ExpenseTracker/Intents/TransactionDataParser.swift`

### Categories — Organization & Spending Buckets

#### Category Management
- **What it does:** Create, edit, and delete expense and income categories for organizing transactions.
- **User flow:** Settings → Categories → view all categories → "+" to add or tap to edit.
- **Details:** Each category has name, icon (from SF Symbols), and color. Type: expense, income, or both. System provides default categories (Food & Drinks, Transport, Shopping, Entertainment, Bills, Health, Other). Can organize into folders (category groups). Categories are space-scoped. Display in transaction entry, filters, and reports.
- **Plan:** Free
- **Code:** `/ExpenseTracker/Views/Categories/CategoryManagementView.swift`, `/ExpenseTracker/ViewModels/Categories/CategoryListViewModel.swift`

#### Category Folders (Groups)
- **What it does:** Organize categories into collapsible folders for cleaner navigation.
- **User flow:** Settings → Categories → folder icon → "+" to create folder or edit.
- **Details:** Folders have name, icon, and sort order. Expand/collapse to show/hide child categories. Improves UI navigation when many categories exist. Space-scoped.
- **Plan:** Free
- **Code:** `/ExpenseTracker/Views/Categories/FolderListView.swift`, `/ExpenseTracker/ViewModels/Categories/AddFolderViewModel.swift`

#### Custom Merchant Rules
- **What it does:** Train the app to auto-categorize merchants based on your rules. When a merchant appears again, the app applies your stored rule.
- **User flow:** When adding transaction or importing, if merchant is not auto-categorized, user selects a category → system offers to "remember this for [merchant]" → stored for future.
- **Details:** Rule stored with merchant name, matched category, and match type (exact, prefix, regex — implementation may vary). When a new transaction with same merchant arrives, rule is applied before asking user. Improves categorization UX over time. Space-scoped. Can manually manage rules in Settings → Merchant Rules.
- **Plan:** Free
- **Code:** `/ExpenseTracker/Services/MerchantCategorizationService.swift`, `/ExpenseTracker/Repositories/Implementations/CustomMerchantRuleRepository.swift`

#### AI Merchant Categorization
- **What it does:** Use OpenAI to intelligently suggest a category for a transaction based on merchant name and your available categories.
- **User flow:** On receipt scan, import, or Wallet automation, if merchant name is present and user is premium, AI suggests a category (with confidence level: high/medium/low).
- **Details:** 
  - **Service:** OpenAI GPT-4o-mini with instruction-tuned prompts.
  - **Input:** Merchant name, currency hint, list of user's actual categories.
  - **Output:** Category name (must match one in user's list), confidence level, optionally normalized merchant name.
  - **Confidence levels:** high → auto-apply, medium/low → show "not sure" UI and collect user feedback.
  - **Cost tracking:** Logs token usage and estimated USD cost per call.
  - **When available:** Premium plan with API key configured.
  - **Fallback:** Built-in merchant mapping (hardcoded rules for common merchants like McDonald's, Amazon, Shell, etc.).
- **Plan:** Premium (with monthly quota)
- **Code:** `/ExpenseTracker/Services/MerchantCategorizationService.swift`

### Budgets — Spending Limits & Allocations

#### Monthly/Cycle Budget
- **What it does:** Set a total spending budget for the month (or custom cycle) and track progress against it.
- **User flow:** Dashboard → Budget card → "Edit Budget" → enter total amount, pick cycle type (monthly, bi-weekly, custom), confirm.
- **Details:**
  - **Cycle types:** Monthly (starts on configurable day 1-31), bi-weekly, custom (e.g., start on day 15).
  - **Rollover:** If previous month had unused budget, option to carry it forward.
  - **Tracking:** Dashboard shows progress bar and % of budget spent.
  - **Currency:** Budget is in the space's default currency; legacy multi-currency budgets are converted for display.
  - **Notifications:** Optional alert when budget is exceeded.
- **Plan:** Free (1 budget per space)
- **Code:** `/ExpenseTracker/Views/Budgets/BudgetFormView.swift`, `/ExpenseTracker/ViewModels/Budgets/BudgetFormViewModel.swift`

#### Category Budgets (Spending Limits per Category)
- **What it does:** Set individual spending limits for specific categories (e.g., max $300/month for groceries).
- **User flow:** Budget view → "Category Limits" → "+" for each category → enter limit amount.
- **Details:**
  - **Per-category allocation:** Allocate portions of total budget to each category or set independent per-category limits.
  - **Progress tracking:** Shows spent vs. limit for each category.
  - **Notifications:** Alert when any category exceeds its limit.
  - **Premium feature:** Available only on premium plan.
  - **Free tier:** Shared overall budget only, no per-category breakdown.
- **Plan:** Premium only
- **Code:** `/ExpenseTracker/Views/Budgets/CategoryBudgetLimitFormView.swift`, `/ExpenseTracker/ViewModels/Budgets/CategoryBudgetViewModel.swift`

#### Smart Budget Allocation (AI)
- **What it does:** Use OpenAI to suggest how to split your total budget across categories based on spending habits and regional norms.
- **User flow:** Budget form → "Smart Allocation" button → enter budget amount, cycle type, optional core categories → AI returns allocation percentages → confirm to apply.
- **Details:**
  - **AI provider:** OpenAI GPT-4o (not mini, full model).
  - **Input:** Total budget, cycle type, currency, locale/country context, list of user's categories, optional "core categories" (frequently-used ones to prioritize).
  - **Output:** Allocation percentages for each category, summing to 100% of budget.
  - **Regional context:** Infers spending patterns for the user's country/region (e.g., different allocation for Poland vs. USA).
  - **Core categories:** If specified, smart allocation ensures core categories receive 60-75% of budget by default.
  - **Cost tracking:** Logs usage and USD cost.
  - **When available:** Premium plan with API key.
  - **Limitations:** Uses gpt-4o (higher cost); monthly quota of 10 AI allocation requests.
- **Plan:** Premium (monthly quota: 10 allocations)
- **Code:** `/ExpenseTracker/Services/SmartAllocationService.swift`

#### Budget Rollover Service
- **What it does:** Automatically copy budget settings (total and category limits) from the previous budget cycle to the new one.
- **User flow:** Automatic (runs in background when app opens or refreshes); no user action needed.
- **Details:** When a new budget cycle begins and no budget exists yet, the system copies amounts and allocations from the previous cycle. Prevents manual re-entry. Rollover check runs max once per hour per space to avoid redundant operations.
- **Plan:** Free
- **Code:** `/ExpenseTracker/Services/BudgetRolloverService.swift`

### Spaces — Multi-Account & Collaboration

#### Spaces (Segregated Wallets)
- **What it does:** Create separate financial "spaces" to organize different money pools (e.g., personal, household, business, trip fund).
- **User flow:** Dashboard → Spaces picker (top-left) → "+" to create → name, icon, color → save. Switch spaces anytime.
- **Details:**
  - **Boundary:** Each space has its own accounts, transactions, categories, budgets, recurrences, tags, and settings.
  - **Data isolation:** Data in one space doesn't mix with others.
  - **Default space:** System creates a default personal space on first launch.
  - **Free tier:** 1 space.
  - **Premium:** Unlimited spaces.
  - **Icon & color:** Customizable emoji icon and color for quick recognition.
  - **All data scoped:** Transactions, categories, accounts, budgets, etc. all belong to exactly one space (enforced at data layer).
- **Plan:** Free (1) | Premium (unlimited)
- **Code:** `/ExpenseTracker/Services/SpaceManager.swift`, `/ExpenseTracker/Views/Spaces/SpacesPickerSheet.swift`, `/ExpenseTracker/ViewModels/Spaces/SpaceFormViewModel.swift`

#### Shared Spaces (Collaboration)
- **What it does:** Invite family, friends, or housemates to share a space and co-track expenses in real-time via iCloud CloudKit.
- **User flow:** Space settings → "Share" button → system generates CloudKit share link → copy & send to other users → they tap link → system adds them as participant → both users see live updates.
- **Details:**
  - **CloudKit-backed:** Uses NSPersistentCloudKitContainer for real-time sync.
  - **Permissions:** Share owner can manage participants (add, remove, change role).
  - **Roles:** Owner (full control), member (can add/edit transactions, budgets).
  - **Sync:** Changes from one participant auto-sync to others within seconds.
  - **Premium feature:** Available only on premium plan.
  - **Limitations:** One shared space limit on free tier (not tested, but premium allows unlimited).
  - **Share invites:** Deep link-based. If user not on device, fallback to manual user ID input.
  - **Participant tracking:** Displays member list with join dates and roles.
- **Plan:** Premium only
- **Code:** `/ExpenseTracker/Services/CloudKitSharingService.swift`, `/ExpenseTracker/Views/Sharing/CloudSharingSheet.swift`

#### Space Settings
- **What it does:** Configure space-specific preferences (default currency, budget start day, calculator toggle).
- **User flow:** Space settings → edit name, icon, color, default currency, budget cycle start day.
- **Details:**
  - **Default currency:** All new transactions in this space default to this currency (can override per-transaction).
  - **Budget start day:** When does the budget cycle start (1-31 for monthly, or day number for custom cycles).
  - **Calculator enabled:** Toggle whether amount entry shows calculator-style expressions.
  - **Settings are space-owned:** Each space has independent settings.
- **Plan:** Free
- **Code:** `/ExpenseTracker/Views/Spaces/EditSpaceSheet.swift`

### Multi-Currency & Exchange Rates

#### Multi-Currency Support
- **What it does:** Add transactions in any of 150+ supported currencies; app automatically converts to your base currency for reporting.
- **User flow:** Add transaction → pick amount currency (defaults to base, can override) → app fetches live rate → shows converted amount in base currency.
- **Details:**
  - **Supported currencies:** 150+ fiat currencies (USD, EUR, GBP, JPY, CNY, INR, KRW, AUD, CAD, CHF, etc.; legacy HRK removed).
  - **Storage:** Stores original amount + currency, converted amount + base currency, and exchange rate used.
  - **Edit behavior:** If you change the amount, rate stays the same. If you change the currency, rate is re-fetched.
  - **Historical rates:** Stores the rate used at transaction time (not adjusted retroactively if rates change).
  - **Multi-currency flows:** Transaction entry, import, recurrence, Wallet import all support currency selection.
- **Plan:** Free (base currency entry) | Premium (multi-currency add-transaction flow UI)
- **Code:** `/ExpenseTracker/Models/Extensions/Currency+Extensions.swift`, `/ExpenseTracker/Services/Currencyservice.swift`

#### Exchange Rate Fetching
- **What it does:** Fetch live currency conversion rates from OpenExchangeRates API with caching layer.
- **User flow:** Automatic (transparent); user doesn't trigger this directly.
- **Details:**
  - **Primary source:** OpenExchangeRates API (free tier, ~1500 requests/month).
  - **Caching:** Rates cached in Core Data (CurrencyRate entity) with lastUpdated timestamp.
  - **Cache validity:** Rates refreshed if stale (older than ~24 hours, exact threshold may vary).
  - **Supabase supplement:** Supabase stores FX rate snapshots as backup/historical reference (RLS-protected to SELECT-only).
  - **Fallback:** If API unavailable, uses cached rates.
  - **Conversion logic:** User enters amount in currency A → system fetches rate → calculates base currency value → stores all three values.
  - **Base currency change:** New transactions use new base; old transactions keep their stored base + converted values (app converts for display if needed).
- **Plan:** Free
- **Code:** `/ExpenseTracker/Services/Currencyservice.swift`

#### Currency Converter
- **What it does:** Quick calculator tool to convert between any two supported currencies using current rates.
- **User flow:** Dashboard → "Converter" card or Settings → Currency Rates → enter amount and currencies.
- **Details:** Input amount in source currency → output shows equivalent in target currency. Rates fetched on-demand or from cache. Used for quick reference (not for transaction entry — that's handled separately).
- **Plan:** Free
- **Code:** `/ExpenseTracker/Views/Currency/CurrencyConverterView.swift`, `/ExpenseTracker/ViewModels/Currency/CurrencyConverterViewModel.swift`

#### Currency Rate Display
- **What it does:** View current exchange rates for popular currency pairs and historical rate snapshots.
- **User flow:** Settings → Currency Rates → view list of rates with timestamps.
- **Details:** Shows rates fetched from API, with last-updated time. Optional charts/trends (if available in analytics).
- **Plan:** Free
- **Code:** `/ExpenseTracker/Views/Settings/CurrencyRatesView.swift`, `/ExpenseTracker/ViewModels/Settings/CurrencyRatesViewModel.swift`

### Import & Export

#### CSV Import
- **What it does:** Import transactions from a CSV file (bank export, spreadsheet) with smart column mapping and AI-assisted categorization.
- **User flow:** Settings → Import → pick CSV file → preview → (optional) confirm/adjust column mapping → preview candidates → save → transactions added to current space.
- **Details:**
  - **Step 1: Parse CSV** — Detects delimiter (comma, semicolon, tab), skip empty rows, handle quoted fields.
  - **Step 2: Column mapping** — System uses AI (if available) or heuristics to infer which columns are date, amount, merchant, currency, type, category, etc. User can manually adjust.
  - **Step 3: Build candidates** — Converts rows to ImportTransactionCandidate objects with parsed values.
  - **Step 4: Enrich** — Attempts merchant categorization (AI if premium, else built-in rules).
  - **Step 5: Account resolution** — Matches CSV "account" or "from_account" column to user's existing accounts.
  - **Step 6: Preview & edit** — User sees candidate list, can delete unwanted rows, edit individual fields, change categories.
  - **Step 7: Commit** — Transactions saved to Core Data + CloudKit.
  - **Supported formats:** CSV, TSV, pipe-delimited. Can import CSV exported from other finance apps (Mint, YNAB, etc.).
  - **Currency inference:** Looks for currency code/symbol in file or defaults to space's base currency.
  - **AI features:** 
    - Column name semantic matching (user's "expense amount" matches app's "amount" field).
    - Merchant categorization (if premium).
    - Category name semantic matching (CSV "Dining Out" → app's "Restaurants" category).
  - **Cost tracking:** Logs AI token usage and USD cost.
  - **Error handling:** Shows user-friendly errors if mapping fails; allows retry.
- **Plan:** Free (basic import) | Premium (AI categorization, AI column/category matching)
- **Code:** `/ExpenseTracker/Services/CSVImportService.swift`, `/ExpenseTracker/Views/Settings/ImportView.swift`, `/ExpenseTracker/ViewModels/Settings/ImportViewModel.swift`

#### Document Import (PDF, RTF, ODT, TXT)
- **What it does:** Extract transaction data from uploaded documents (invoices, receipts in PDF, text exports from banking apps).
- **User flow:** Settings → Import → choose document → system parses and extracts structured data.
- **Details:** Uses DocumentParsingService to handle PDF, RTF, ODT, TXT formats. Extracts text, then applies regex/heuristics to find amounts, dates, merchant names. Less structured than CSV but useful for scanned invoices. Can optionally use AI to improve extraction.
- **Plan:** Free (basic) | Premium (with AI enhancement if available)
- **Code:** `/ExpenseTracker/Services/DocumentParsingService.swift`

#### CSV Export
- **What it does:** Export transactions to a CSV file for backup, analysis, or import into other tools.
- **User flow:** Settings → Export → pick export options (columns to include, date range, etc.) → generate → download & share via share sheet.
- **Details:**
  - **Configurable columns:** Date, type, original amount, original currency, converted amount, exchange rate, merchant, note, category, account, to account, tags, created at.
  - **Date range filtering:** Export specific date ranges.
  - **Progress tracking:** Shows export progress during generation.
  - **File format:** Standard CSV with proper escaping for quotes/commas in fields.
  - **Sharing:** Generated file exported via iOS share sheet (email, cloud storage, etc.).
  - **All-space export:** Option to export entire space or filtered transactions.
- **Plan:** Free
- **Code:** `/ExpenseTracker/Services/CSVExportService.swift`, `/ExpenseTracker/Views/Settings/ExportSheet.swift`, `/ExpenseTracker/ViewModels/Settings/ExportViewModel.swift`

### Dashboard & Analytics

#### Dashboard Overview
- **What it does:** Home screen showing spending summary, budget progress, upcoming recurrences, and quick-access cards.
- **User flow:** Open app → Dashboard displayed (if app is in .ready state).
- **Details:**
  - **Summary cards:**
    - Total spent (this period or selected range)
    - Income (optional breakdown)
    - Net (income - expenses)
    - Budget progress bar (% of budget used, color-coded)
  - **Upcoming recurrences card:** Lists next 3-5 due recurring transactions with dates.
  - **Spending by category:** Pie or bar chart showing top categories.
  - **Recent transactions:** List of last 10-20 transactions.
  - **Quick actions:** Links to Add Transaction, Scan Receipt, Budget, etc.
  - **Customization:** User can toggle visibility of cards (via DashboardVisibilitySettings).
  - **Time period filter:** Toggle between week, month, quarter, year, custom range.
- **Plan:** Free
- **Code:** `/ExpenseTracker/Views/Dashboard/DashboardView.swift`, `/ExpenseTracker/ViewModels/Dashboard/DashboardViewModel.swift`

#### Advanced Analytics Tab
- **What it does:** Detailed insights, trend charts, and spending breakdowns across multiple dimensions.
- **User flow:** Dashboard → "Analytics" tab → view charts, filters, and detailed breakdowns.
- **Details:**
  - **Charts:**
    - Line chart: Spending over time (daily, weekly, monthly trends).
    - Pie chart: Spending by category, income by category.
    - Bar chart: Comparison across months or accounts.
  - **Filters:** Date range, account, category, tags, transaction type.
  - **Breakdowns:**
    - Spending by category (all expenses, top categories).
    - Income by category.
    - Tag-based analytics (spending across tagged transactions).
    - Calendar heatmap: Spending intensity by day.
  - **Summaries:** Total spent, average per day, largest expense, etc.
  - **Data export:** Can export analytics data or screenshots.
  - **Premium feature:** Advanced analytics tab requires premium plan.
- **Plan:** Premium only
- **Code:** `/ExpenseTracker/Views/Dashboard/Analytics/AnalyticsView.swift`, `/ExpenseTracker/ViewModels/Dashboard/AnalyticsViewModel.swift`

#### Spending by Category View
- **What it does:** Pie/donut chart showing expense distribution across categories.
- **User flow:** Dashboard → Spending by Category card → drill down to see category details.
- **Details:** Shows top categories by amount. Tap a category to see transactions in that category. Color-coded by category color. Shows % of total. Supports date range filtering.
- **Plan:** Free
- **Code:** `/ExpenseTracker/Views/Dashboard/SpendingByCategoryView.swift`, `/ExpenseTracker/ViewModels/Dashboard/SpendingByCategoryViewModel.swift`

#### Income by Category View
- **What it does:** Breakdown of income transactions by income category.
- **User flow:** Similar to Spending — appears in Dashboard or Analytics.
- **Details:** Mirror of expense view but for income. Shows which income categories contributed most. Filter by date range.
- **Plan:** Free
- **Code:** `/ExpenseTracker/Views/Dashboard/IncomeByCategoryView.swift`

#### Net Worth Tracking
- **What it does:** Display total value of all accounts combined (sum of balances across all accounts, in base currency).
- **User flow:** Dashboard or Accounts screen → Net Worth card shows current net worth and trend.
- **Details:**
  - **Calculation:** Sum of account balances, converted to base currency.
  - **Trend chart:** Line chart showing net worth over time.
  - **Multi-currency:** Accounts in different currencies are converted using historical exchange rates.
  - **Account breakdown:** Can see which accounts contribute to net worth.
- **Plan:** Free
- **Code:** `/ExpenseTracker/Views/Accounts/NetWorthProgressLine.swift`, `/ExpenseTracker/Services/NetWorthService.swift`

#### Calendar Heatmap
- **What it does:** Visual calendar showing spending intensity (darker = more spending) for each day.
- **User flow:** Dashboard → Calendar view → see spending patterns across a month or quarter.
- **Details:** Color intensity represents amount spent (or % of budget). Tap a day to see transactions for that day. Useful for identifying spending patterns and anomalies.
- **Plan:** Likely premium (if in analytics section)
- **Code:** `/ExpenseTracker/Views/Dashboard/CalendarSpendingView.swift`

#### Tag Analytics
- **What it does:** View spending breakdown by tags (e.g., how much spent on "business" vs "personal" tags across all transactions).
- **User flow:** Analytics → Tag Analytics card → see spending per tag.
- **Details:** Filter by date range. Shows total and average per tag. Helps identify how much budget goes to tagged categories.
- **Plan:** Likely free or premium (if in analytics)
- **Code:** `/ExpenseTracker/Views/Dashboard/TagAnalyticsView.swift`, `/ExpenseTracker/ViewModels/Dashboard/TagAnalyticsViewModel.swift`

### Notifications & Reminders

#### Daily Reminders
- **What it does:** Send a daily notification reminder to log expenses at a set time.
- **User flow:** Settings → Notifications → toggle "Daily Reminders" → pick preset (morning 9am, lunch 1pm, evening 9pm) or custom time → confirm.
- **Details:**
  - **Presets:** Morning, Lunch, Evening (with default times; user can customize).
  - **Custom times:** Pick any specific hour + minute.
  - **Frequency:** Daily at same time (or user can choose specific days of week).
  - **Notification body:** Customizable message (e.g., "Have you logged your expenses today?").
  - **Sound:** Custom app sound (notification.wav).
  - **Persistence:** Reminders are scheduled via UserNotifications framework; persist across app restarts.
  - **Opt-out:** User can disable daily reminders entirely.
- **Plan:** Free
- **Code:** `/ExpenseTracker/Services/NotificationService.swift`, `/ExpenseTracker/Views/Settings/NotificationSettingsView.swift`

#### Recurrence Notifications
- **What it does:** Send a reminder when a recurring transaction is due (day of or day before).
- **User flow:** Edit recurring template → toggle "Notify me" → pick timing ("day of due date" or "day before") → confirm.
- **Details:**
  - **Timing modes:** 
    - Day of: Notify on the day the transaction is due.
    - Day before: Notify the day before due date.
  - **Time:** Scheduled at a configurable time (defaults to recurrence reminder time in settings).
  - **Catch-up:** If notification time has passed for "today," system schedules an immediate catch-up notification instead of skipping.
  - **Idempotency:** System tracks which notifications have been sent to avoid duplicates.
  - **Persistency:** Scheduled notification IDs stored to survive app restarts.
- **Plan:** Free
- **Code:** `/ExpenseTracker/Services/NotificationService.swift`

#### Budget Alerts
- **What it does:** Notify user when total budget or category budget is exceeded.
- **User flow:** Settings → Notifications → toggle "Budget Alerts" → confirm.
- **Details:** When a transaction is added/imported that pushes spending over a budget limit, a notification fires (if budget alerts are enabled). Shows which budget was exceeded and by how much. Sent immediately (not scheduled).
- **Plan:** Free
- **Code:** `/ExpenseTracker/Services/NotificationService.swift`

#### Budget Overspent Notifications (Apple Pay Automation)
- **What it does:** When a transaction is imported via Apple Wallet automation, if it causes a category budget to be exceeded, notify the user.
- **User flow:** Wallet automation triggers → transaction imported → if budget exceeded, notification sent with amount over and category.
- **Details:** Fires locally even if app is not open. Shows budget name and overspent amount.
- **Plan:** Free
- **Code:** `/ExpenseTracker/Intents/ImportWalletTransactionIntent.swift`

### Onboarding & App Setup

#### First-Launch Onboarding
- **What it does:** Guide new users through initial setup (choose currency, create default space, confirm iCloud readiness).
- **User flow:** Launch app for first time → see welcome screen → pick base currency → verify iCloud available → see success screen.
- **Details:**
  - **Step 1: Welcome** — Intro message explaining what app does.
  - **Step 2: Currency selection** — Pick default currency for base calculations (from device locale or manual picker).
  - **Step 3: Cloud check** — System verifies iCloud is available; if not, explains why (not signed in, etc.).
  - **Step 4: Success** — Congratulations screen; tap to enter app.
  - **Default data:** System creates default space, default cash account, default expense categories, default settings.
  - **Onboarding completion:** One-time flow (UserDefaults flag prevents re-showing).
  - **Cloud timing:** System waits up to 6 seconds for iCloud data to load (checking for existing spaces). If user data exists, shows recovery option. If not, "Start Fresh" creates new default space.
- **Plan:** Free
- **Code:** `/ExpenseTracker/Views/Onboarding/OnboardingFlowView.swift`, `/ExpenseTracker/App/AppStartupCoordinator.swift`

### Settings & Customization

#### Appearance Settings
- **What it does:** Customize app theme and visual appearance.
- **User flow:** Settings → Appearance → pick theme (Light, Dark, Auto) and accent color (optional).
- **Details:**
  - **Theme modes:** Light, Dark, System (auto).
  - **Accent color:** (Optional) custom primary color for UI elements (if implemented).
  - **Dark mode support:** Full dark mode support across all views.
  - **Accessibility:** Respects system Reduce Motion and Increase Contrast settings.
- **Plan:** Free
- **Code:** `/ExpenseTracker/Views/Settings/AppearanceView.swift`, `/ExpenseTracker/Services/AppearanceService.swift`

#### Default Currency Setting
- **What it does:** Set the base currency for the current space (used for conversions and reporting).
- **User flow:** Settings → Default Currency → pick currency from 150+ list.
- **Details:** Applies to space, not globally. Changing it affects new transactions (old transactions retain their stored base currency). Filter by region or search by code/name. Shows flag emoji for each currency.
- **Plan:** Free
- **Code:** `/ExpenseTracker/Views/Settings/DefaultCurrencyView.swift`, `/ExpenseTracker/ViewModels/Settings/DefaultCurrencyViewModel.swift`

#### Budget Start Day
- **What it does:** Configure which day of the month the budget cycle starts (1-31 or custom day).
- **User flow:** Settings → Budget → pick start day.
- **Details:** Defaults to 1st of month. Allows custom days (e.g., 15th) or bi-weekly cycles. Applied per space. Affects budget rollover and progress calculation.
- **Plan:** Free
- **Code:** (Embedded in Settings/SettingsView or Budget forms)

#### Calculator Toggle
- **What it does:** Enable or disable calculator-style expression entry when adding transaction amounts.
- **User flow:** Settings → Calculator → toggle on/off.
- **Details:** If enabled, user can type "100+50" and it evaluates to "150" before saving. Useful for quick math. Disabled by default.
- **Plan:** Free
- **Code:** (Likely in SettingsViewModel or AppSettings)

#### Notification Preferences
- **What it does:** Configure all notification types (daily reminders, recurrence notifications, budget alerts).
- **User flow:** Settings → Notifications → toggle each notification type on/off and customize times.
- **Details:** Centralized control for permission, presets, custom times, and specific triggers. See Notifications section for details.
- **Plan:** Free
- **Code:** `/ExpenseTracker/Views/Settings/NotificationSettingsView.swift`, `/ExpenseTracker/ViewModels/Settings/NotificationSettingsViewModel.swift`

#### Data Management
- **What it does:** Backup, restore, export, and manage local data.
- **User flow:** Settings → Data Management → backup, restore, export, or reset options.
- **Details:**
  - **Local backup:** Export Core Data database to Files/iCloud Drive.
  - **Restore:** Restore from previous backup.
  - **Export:** See CSV Export (above).
  - **Reset:** Wipe all local data (with confirmation).
  - **Sample data (debug only):** Generate mock transactions for testing (only in debug builds).
- **Plan:** Free
- **Code:** `/ExpenseTracker/Views/Settings/DataManagementView.swift`, `/ExpenseTracker/ViewModels/Settings/DataManagementViewModel.swift`

#### iCloud Sync Status
- **What it does:** Show sync status and allow manual refresh.
- **User flow:** Settings or top of dashboard → sync indicator → pull-to-refresh to manually trigger sync.
- **Details:** Shows "Syncing", "Up to date", or error state. Pull-to-refresh forces immediate CloudKit fetch. System auto-syncs in background via NSPersistentCloudKitContainer.
- **Plan:** Free
- **Code:** (Embedded in multiple views, uses Persistence.swift refresh methods)

#### Shortcuts Settings (Wallet Target Space)
- **What it does:** Configure which space receives transactions from Apple Wallet automation.
- **User flow:** Settings → Shortcuts → pick target space for Wallet imports.
- **Details:** When Wallet automation runs, ImportWalletTransactionIntent reads this setting to know which space to add the transaction to. Defaults to first/primary space.
- **Plan:** Free
- **Code:** (Likely in SettingsViewModel or UserDefaults keys)

### Accessibility & Localization

#### Accessibility Support
- **What it does:** VoiceOver, dynamic type, motion reduction, and high contrast support.
- **User flow:** System Settings → Accessibility → enable features → use app with assistive features.
- **Details:**
  - **VoiceOver:** All UI elements have accessibility labels and hints.
  - **Dynamic Type:** Text sizes scale with system font size (5 levels).
  - **Reduce Motion:** Animations disabled if user prefers.
  - **Increase Contrast:** High-contrast colors available.
  - **Note:** Production audit (PRODUCTION_READINESS.md) flagged some gesture-based interactions (MED-24) as accessibility-weak; these may be improved in future.
- **Plan:** Free
- **Code:** Throughout views; uses `.accessibilityLabel()`, `.accessibilityHint()`, etc.

#### Localization
- **What it does:** Support multiple languages (at minimum, English and Ukrainian; extensible to others).
- **User flow:** System Settings → Language → app automatically displays in selected language.
- **Details:**
  - **English (en):** Primary language.
  - **Ukrainian (uk):** Localized strings for transaction types, notification bodies, UI text.
  - **Strings:** Uses NSLocalizedString for all user-facing text.
  - **Future:** Extensible to other languages without code changes.
- **Plan:** Free
- **Code:** Uses `.lproj` folders (en.lproj, uk.lproj) with Localizable.strings; embedded in source via String(localized: "key") pattern.

### Premium & Paywall

#### Subscription Management
- **What it does:** Purchase and manage premium subscription via RevenueCat.
- **User flow:** Settings → Premium → view paywall → purchase annual/monthly plan → RevenueCat handles payment & entitlements.
- **Details:**
  - **Provider:** RevenueCat (abstracts Apple App Store, Google Play, etc.).
  - **Plans:** Annual and monthly options (exact pricing in RevenueCat dashboard, not hardcoded).
  - **Entitlements:** On successful purchase, app receives "premium" entitlement from RevenueCat.
  - **Restore:** Users can restore purchases via Settings → Premium → "Restore Purchases".
  - **Trial:** Configurable via RevenueCat dashboard (not app-side logic).
  - **Attribution:** RevenueCat tracks attribution sources (ad campaigns, organic, etc.).
- **Plan:** Requires premium subscription
- **Code:** `/ExpenseTracker/Services/PurchaseService.swift`, `/ExpenseTracker/Services/RevenueCatClient.swift`, `/ExpenseTracker/Views/Premium/PaywallView.swift`

#### Paywall & Premium Features
- **What it does:** Display paywall explaining premium features; gate premium features behind entitlement checks.
- **User flow:** User attempts premium feature (e.g., add 3rd space) → system shows paywall explaining feature + benefits + upgrade button → tap to purchase.
- **Details:**
  - **EntitlementService:** Central service checking if feature is available based on user's plan.
  - **PremiumFeature enum:** Lists all gated features with display names, descriptions, icons, paywall copy.
  - **PremiumRequirement struct:** Returned when feature is blocked; includes feature, current count, and limit.
  - **Paywall UI:** Shows hero image/title, feature description, pricing, and CTA button.
  - **Free trial:** Can be configured in RevenueCat dashboard.
  - **Fallback:** If RevenueCat unavailable, defaults to free plan.
- **Plan:** Premium features only
- **Code:** `/ExpenseTracker/Services/EntitlementService.swift`, `/ExpenseTracker/Views/Premium/PaywallView.swift`, `/ExpenseTracker/ViewModels/Premium/PaywallViewModel.swift`

#### Plan Downgrade Service
- **What it does:** Handle data cleanup if user loses premium status (e.g., due to subscription lapse or refund).
- **User flow:** User's subscription expires → system detects premium loss → PlanDowngradeService runs.
- **Details:**
  - **Actions on downgrade:** Archive/hide excess spaces beyond free limit, disable shared spaces, reset category budgets if on free tier.
  - **Data preservation:** No data is deleted; features are just disabled.
  - **User notification:** Might notify user that certain features are now unavailable.
  - **Re-upgrade:** If user re-purchases premium, data is restored and features re-enabled.
- **Plan:** Internal (triggered on entitlement change)
- **Code:** `/ExpenseTracker/Services/PlanDowngradeService.swift`

#### Free Plan Limits
- **What it does:** Enforce free-tier quotas and usage limits.
- **User flow:** User creates more spaces than free tier allows → system blocks and shows paywall.
- **Details:**
  - **Spaces:** Max 1 free, unlimited premium.
  - **Accounts:** Max 2 free, unlimited premium.
  - **Recurrences:** Max 3 active free, unlimited premium.
  - **Receipt scans:** 5 lifetime free, 30/month premium.
  - **Other features:** Category budgets, analytics, shared spaces, AI categorization, multi-currency flows all premium.
  - **Entitlement count provider:** Queries repos to determine current counts and compare against limits.
- **Plan:** Free (with limits)
- **Code:** `/ExpenseTracker/Services/EntitlementService.swift` (FreePlanLimits enum)

#### Premium Plan Limits (Monthly Quotas)
- **What it does:** Prevent runaway costs by capping premium-plan monthly AI usage.
- **User flow:** User hits monthly limit (e.g., 30 receipt scans) → system blocks further scans until next month.
- **Details:**
  - **Receipt scans:** 30/month.
  - **AI categorizations:** 300/month.
  - **Smart allocations:** 10/month.
  - **Reset:** Resets on the 1st of each month (or per-space budget cycle start day for budget-related features).
  - **Usage tracking:** Logged via OpenAI token usage structures; reset via date-based checks.
- **Plan:** Premium (to prevent abuse)
- **Code:** `/ExpenseTracker/Services/EntitlementService.swift` (PremiumPlanLimits enum)

### Tip Jar (Optional In-App Purchase)

#### Tip Jar
- **What it does:** Allow users to optionally send a small one-time tip to support development (separate from premium subscription).
- **User flow:** Settings → Support → "Leave a Tip" → pick amount ($1, $5, $10, or custom) → purchase.
- **Details:** RevenueCat-managed IAP. No features gated behind tips; purely optional. Proceeds go to developer. Thank you message displayed on completion.
- **Plan:** Optional (free app)
- **Code:** `/ExpenseTracker/Views/Settings/TipJarView.swift`, `/ExpenseTracker/Services/TipJarService.swift`

### Search, Filters & Sorting

#### Transaction Search
- **What it does:** Search transactions by merchant name or notes.
- **User flow:** Transaction list → tap search icon → type merchant name or keywords → results update in real-time.
- **Details:** Case-insensitive substring match on merchant name and note fields. Shows matching transactions only. Combines with filters (can filter by date + search merchant).
- **Plan:** Free
- **Code:** `/ExpenseTracker/ViewModels/Transactions/TransactionListViewModel.swift` (search logic)

#### Transaction Filters
- **What it does:** Filter transactions by date range, account, category, tags, type.
- **User flow:** Transaction list → filter icon → pick criteria → apply.
- **Details:**
  - **Date range:** From-to date picker (preset ranges: Today, This Week, This Month, This Year, Custom).
  - **Account:** Multi-select list of accounts.
  - **Category:** Multi-select list of categories (with folder hierarchy).
  - **Tags:** Multi-select list of tags.
  - **Type:** Expense, Income, Transfer (checkboxes).
  - **Combination:** All filters applied together (AND logic).
  - **Persistence:** Last filter state saved to UserDefaults (optional).
- **Plan:** Free
- **Code:** `/ExpenseTracker/Views/Transactions/TransactionListView.swift`, `/ExpenseTracker/ViewModels/Transactions/FiltersViewModel.swift`

#### Transaction Sort
- **What it does:** Sort transaction list by date (ascending/descending), amount, or category.
- **User flow:** Transaction list → sort icon → pick column and order.
- **Details:** Default is date descending (newest first). Persisted to space settings.
- **Plan:** Free
- **Code:** (Embedded in TransactionListViewModel)

#### Multi-Operation Mode (Bulk Edit)
- **What it does:** Select multiple transactions and perform batch actions (change category, add tags, delete all at once).
- **User flow:** Transaction list → toggle multi-select mode → tap transactions to select → pick action (assign category, add tags, delete) → confirm.
- **Details:**
  - **Actions:** Bulk assign category, bulk add tags, bulk delete.
  - **Preview:** Shows how many transactions selected.
  - **Undo:** Deletion is final (no undo, but warning is shown).
  - **Premium feature:** Available only on premium plan.
- **Plan:** Premium only
- **Code:** (Embedded in TransactionListViewModel / TransactionListView)

### Location Services (Potential Future Feature)

#### Location-Based Features
- **What it does:** (Not fully implemented; flagged in architecture as future) Potentially auto-detect merchant location for context when scanning receipts.
- **User flow:** (Not yet in use)
- **Details:** LocationService stub exists in codebase. May be used in future for location-aware categorization or smart suggestions. Requires NSLocationWhenInUseUsageDescription permission (already in Info.plist).
- **Plan:** Free (if implemented)
- **Code:** `/ExpenseTracker/Services/LocationService.swift` (stub)

### Deep Linking & Intent Handling

#### Deep Links
- **What it does:** Allow external apps or URLs to trigger actions in Expensa (e.g., open a space, view a transaction).
- **User flow:** External URL (e.g., from email, browser) → system routes to Expensa → app opens to relevant screen.
- **Details:**
  - **DeepLinkManager** handles URL parsing.
  - **Supported links:** Open space, view transaction, open import flow, etc.
  - **CloudKit shares:** Deep link for accepting space share from other user.
  - **Pending intents:** Memory-only queue (not persisted); if app is killed, intent can be lost (flagged as MED-20 in audit).
- **Plan:** Free
- **Code:** `/ExpenseTracker/Services/DeepLinkManager.swift`

### Background Tasks & Sync

#### Background Refresh
- **What it does:** Periodically sync data with iCloud in the background (even when app is closed).
- **User flow:** Automatic; no user action needed.
- **Details:**
  - **iOS feature:** Uses BGAppRefreshTask.
  - **Frequency:** Configurable (typically 15 min to 1 hour).
  - **Tasks:** Recurrence generation, budget rollover, currency rate refresh.
  - **CloudKit sync:** NSPersistentCloudKitContainer auto-syncs in background.
  - **No network:** If offline, tasks deferred until network available.
- **Plan:** Free
- **Code:** `/ExpenseTracker/App/AppDelegate.swift` (background task registration)

#### Recurrence Generation (Background)
- **What it does:** Generate due recurring transactions in the background without user interaction.
- **User flow:** Automatic (triggered on app launch, background refresh, or manual sync).
- **Details:** System checks for due recurrences and creates transactions idempotently (no duplicates if already created). Runs async off main thread.
- **Plan:** Free
- **Code:** `/ExpenseTracker/Services/RecurrenceService.swift` (runDueRecurrences method)

#### Budget Rollover (Background)
- **What it does:** Automatically copy budget from previous cycle to new one if needed.
- **User flow:** Automatic; checked periodically (max once per hour).
- **Details:** Avoids redundant checks via lastRolloverCheck timestamp cache.
- **Plan:** Free
- **Code:** `/ExpenseTracker/Services/BudgetRolloverService.swift`

---

## Premium Feature Summary

| Feature | Free Limit | Premium |
|---------|-----------|---------|
| Spaces | 1 | Unlimited |
| Accounts | 2 | Unlimited |
| Active Recurrences | 3 | Unlimited |
| Receipt Scans | 5 (lifetime) | 30/month |
| Category Budgets | Not available | Unlimited |
| Analytics Tab | Not available | Full access |
| Multi-Currency Add Flow | Not available | Enabled |
| AI Merchant Categorization | Not available | 300/month |
| Shared Spaces | Not available | Enabled |
| Smart Budget Allocation | Not available | 10/month |
| Multi-Operation Mode | Not available | Enabled |

---

## Technical Highlights

### Data Persistence
- **Core Data:** Dual stores (private + shared) for CloudKit sync.
- **NSPersistentCloudKitContainer:** Automatic CloudKit schema generation and syncing.
- **Deterministic IDs:** Budget, CategoryBudget, custom merchant rules use deterministic UUID construction for dedup across devices.
- **Store assignment:** All space-owned objects assigned to same store/zone as their owning Space (no cross-zone relationships).

### Offline Support
- App works offline for local reads/writes. Syncs when network/iCloud returns.
- Caching: Currency rates, iOS shortcuts configuration, Apple Pay sync content cached locally.

### Performance
- Fetched results controllers for live list updates.
- Async/await for background operations (receipt scanning, import, API calls).
- Lazy loading for large data sets.
- Caching of formatters and date calculations to avoid per-render recalculation.

### Security
- API keys not hardcoded; loaded from environment vars or Info.plist.
- CloudKit RLS (row-level security) on Supabase cache.
- Keychain used for sensitive data (e.g., premium plan status moved from UserDefaults).
- PrivacyInfo.xcprivacy manifest declares all privacy-relevant APIs.

### API Integrations
- **OpenAI:** Vision API for receipt scanning, GPT-4o-mini for merchant categorization and CSV column inference, GPT-4o for smart budget allocation.
- **OpenExchangeRates:** Currency conversion rates (free tier).
- **Supabase:** FX rate snapshots cache (SELECT-only RLS).
- **RevenueCat:** Subscription and in-app purchase management.
- **CloudKit:** iCloud sync and sharing.
- **Apple Vision Framework:** Fallback OCR (local, on-device).
- **UserNotifications:** Local push notifications for reminders and alerts.
- **App Intents:** Wallet automation and Shortcuts integration.

---

## Known Limitations & TODOs (from Audit)

### Unresolved Issues (Post-Ship Hardening)
1. **Test suite:** PurchaseServiceTests compilation errors; test deployment targets misaligned (MED-26, MED-27).
2. **Force unwraps:** Remain in file system access, regex compilation, CSV parsing (MED-10, MED-13, MED-14).
3. **Refresh strategy:** CloudKit refresh uses broad `refreshAllObjects()` (MED-21).
4. **Pending intents:** Deep links not persisted across app termination (MED-20).
5. **Error handling:** 12+ catch blocks swallowing errors silently (MED-15).
6. **Print statements:** Replaced with `dprint()` (compiles away in release) but audit flagged exposure risk (MED-2).
7. **Cloud check:** 6-second polling window may be too short on slow connections (MED-28).

### Implemented Future Considerations (from README)
- Apple Watch experience.
- Expanded Shortcuts/Intents.
- Location-based automations.
- Bill reminders and savings goals.

---

## File Structure Overview

```
ExpenseTracker/
├── Views/                       # SwiftUI views (18 subdirs, ~65 files)
│   ├── Dashboard/               # Home screen, analytics, charts
│   ├── Transactions/            # Add, list, details, filters
│   ├── Budgets/                 # Budget form, category limits
│   ├── Accounts/                # Account mgmt, net worth
│   ├── Categories/              # Category & folder mgmt
│   ├── Recurrence/              # Recurring transaction UI
│   ├── Spaces/                  # Space picker, creation, management
│   ├── Settings/                # All settings screens
│   ├── Premium/                 # Paywall
│   ├── Onboarding/              # First-launch flows
│   ├── CheckProcessing/         # Receipt scanning UI
│   ├── Currency/                # Converter, rate display
│   ├── Sharing/                 # CloudKit share UI
│   ├── Tags/                    # Tag management
│   └── Components/              # Reusable UI components
├── ViewModels/                  # MVVM view models (~45 files)
├── Services/                    # Business logic & API integration (~37 files)
│   ├── CheckScanService.swift           # Apple Vision OCR
│   ├── OpenAICheckScanService.swift     # OpenAI Vision API
│   ├── MerchantCategorizationService    # AI merchant→category
│   ├── SmartAllocationService           # AI budget allocation
│   ├── CSVImportService                 # CSV import orchestration
│   ├── CSVExportService                 # CSV export
│   ├── CSVParsingService                # CSV parsing helpers
│   ├── NotificationService              # Local notifications
│   ├── RecurrenceService                # Recurrence generation
│   ├── BudgetRolloverService            # Budget copying
│   ├── CloudKitSharingService           # iCloud share management
│   ├── CurrencyService                  # FX rate fetching & caching
│   ├── PurchaseService                  # RevenueCat integration
│   ├── EntitlementService               # Premium feature gating
│   ├── LocationService                  # (Stub for future)
│   └── [others]
├── Repositories/                # Data access layer (~10 implementations + protocols)
│   ├── TransactionRepository.swift
│   ├── AccountRepository.swift
│   ├── CategoryRepository.swift
│   ├── BudgetRepository.swift
│   ├── CategoryBudgetRepository.swift
│   ├── RecurrenceRepository.swift
│   ├── TagRepository.swift
│   ├── CustomMerchantRuleRepository.swift
│   └── [others]
├── Models/                      # Core Data entities & DTOs
│   ├── Extensions/              # Category extensions for entities
│   └── [model files]
├── App/                         # App entry & lifecycle
│   ├── ExpenseTrackerApp.swift  # @main App struct
│   ├── AppDelegate.swift        # Background tasks
│   ├── AppStartupCoordinator.swift  # Onboarding & startup
│   ├── ContentView.swift        # Root view hierarchy
│   └── [others]
├── Configuration/               # API keys & build config
│   └── APIConfiguration.swift
├── Persistence.swift            # Core Data + CloudKit setup
├── Utilities/                   # Helpers, formatters, extensions (~25 files)
├── Intents/                     # App Intents for Shortcuts & Automation
│   ├── ImportWalletTransactionIntent.swift
│   ├── TransactionDataParser.swift
│   └── [others]
├── Resources/                   # Localization, merchant rules, etc.
└── ExpenseTracker.entitlements  # CloudKit, push notification capabilities
```

---

## Summary

**Expensa is a production-ready, full-featured personal finance app** with multi-space organization, real-time iCloud sync, AI-powered receipt scanning & categorization, smart budgeting, multi-currency support, and collaborative spaces. It offers a free tier with reasonable limits and a premium subscription unlocking advanced features (unlimited spaces, category budgets, analytics, faster scan quota). The codebase is architecturally sound (Clean Architecture + MVVM, protocol-driven, testable), though with post-launch hardening needed (force unwrap removal, error handling visibility, test alignment). All critical ship blockers are resolved; remaining items are medium/low-priority polish.