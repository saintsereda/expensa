//
//  CurrencyManager.swift
//  Expensa
//
//  Created by Andrew Sereda on 26.10.2024.
//

import Foundation
import CoreData

public class CurrencyManager: ObservableObject {
    static let shared = CurrencyManager()
    private let context: NSManagedObjectContext
    @Published public private(set) var defaultCurrency: Currency?
    @Published public private(set) var availableCurrencies: [Currency] = []
    
    private var isInitialized = false
    
    var currencyConverter: CurrencyConverter {
        CurrencyConverter.shared
    }
    
    private init() {
        self.context = CoreDataStack.shared.context
        // Initialize synchronously to ensure data is ready when views load
        initializeCurrencies()
    }
    
    private func initializeCurrencies() {
        guard !isInitialized else { return }
        
        // Load currencies synchronously
        loadAvailableCurrencies()
        
        // If no currencies exist, create them first
        if availableCurrencies.isEmpty {
            resetAndInitializeCurrencies()
            loadAvailableCurrencies()
        }
        
        // Check if this is first launch
        let isFirstLaunch = !UserDefaults.standard.bool(forKey: "hasLaunchedBefore")
        
        // Try locale currency on first launch
        if isFirstLaunch {
            if let localeCode = Locale.current.currency?.identifier {
                print("🌍 System locale currency: \(localeCode)")
                if let localeCurrency = fetchCurrency(withCode: localeCode) {
                    print("✅ Using system locale currency: \(localeCurrency.code ?? "unknown")")
                    self.defaultCurrency = localeCurrency
                    UserDefaults.standard.set(localeCode, forKey: "defaultCurrencyCode")
                    UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
                    isInitialized = true
                    return
                }
            }
        }
        
        // Try to load existing default currency
        if let savedCurrencyCode = UserDefaults.standard.string(forKey: "defaultCurrencyCode"),
           let savedCurrency = fetchCurrency(withCode: savedCurrencyCode) {
            self.defaultCurrency = savedCurrency
            isInitialized = true
            return
        }
        
        // Fallback to USD
        if let usdCurrency = fetchCurrency(withCode: "USD") {
            self.defaultCurrency = usdCurrency
            UserDefaults.standard.set("USD", forKey: "defaultCurrencyCode")
            isInitialized = true
            return
        }
    }
    
    private func loadAvailableCurrencies() {
        let request: NSFetchRequest<Currency> = Currency.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Currency.code, ascending: true)]
        
        do {
            self.availableCurrencies = try context.fetch(request)
        } catch {
            print("Error loading currencies: \(error)")
            self.availableCurrencies = []
        }
    }
    
    // Method to add to CurrencyManager.swift
    private func resetAndInitializeCurrencies() {
        // Get device-specific initialization key
        let deviceId = UserDefaults.standard.string(forKey: "deviceIdentifier") ?? UUID().uuidString
        let currencyInitKey = "hasLoadedDefaultCurrencies-\(deviceId)"
        
        // Skip if already initialized on this device
        guard !UserDefaults.standard.bool(forKey: currencyInitKey) else {
            print("📱 Currencies already initialized on this device")
            return
        }
        
        let savedPreference = UserDefaults.standard.string(forKey: "defaultCurrencyCode")
        
        // Check existing currencies before adding
        let existingCurrencyCodes = getExistingCurrencyCodes()
        var currenciesToAdd: [(String, String, String, String)] = []
        
        for currencyData in commonCurrencies {
            if !existingCurrencyCodes.contains(currencyData.0) {
                currenciesToAdd.append(currencyData)
            }
        }
        
        if !currenciesToAdd.isEmpty {
            context.performAndWait {
                for (code, name, symbol, flag) in currenciesToAdd {
                    let currency = Currency(context: context)
                    currency.id = UUID()
                    currency.code = code
                    currency.name = name
                    currency.symbol = symbol
                    currency.flag = flag
                    currency.lastUpdated = Date()
                }
                try? context.save()
            }
        }
        
        // Mark as initialized on this device
        UserDefaults.standard.set(true, forKey: currencyInitKey)
        
        // Reload currencies
        loadAvailableCurrencies()
        
        // Set default currency
        if let previousCode = savedPreference,
           let previousCurrency = fetchCurrency(withCode: previousCode) {
            self.defaultCurrency = previousCurrency
        } else if let usdCurrency = fetchCurrency(withCode: "USD") {
            self.defaultCurrency = usdCurrency
            UserDefaults.standard.set("USD", forKey: "defaultCurrencyCode")
        }
        
        isInitialized = true
    }

    // Helper function to get existing currency codes
    private func getExistingCurrencyCodes() -> Set<String> {
        let request: NSFetchRequest<Currency> = Currency.fetchRequest()
        request.propertiesToFetch = ["code"]
        
        do {
            let results = try context.fetch(request)
            return Set(results.compactMap { $0.code })
        } catch {
            print("Error fetching currency codes: \(error)")
            return []
        }
    }
    
    func handleDefaultCurrencyChange(to newCurrency: Currency) async {
        guard let oldCurrency = defaultCurrency,
              oldCurrency != newCurrency else {
            return
        }
        
        // Convert all expenses to new currency
        await ExpenseDataManager.shared.convertAllExpenses(
            from: oldCurrency,
            to: newCurrency
        )
        
        // Update default currency after conversion is done
        await MainActor.run {
            self.setDefaultCurrency(newCurrency)
        }
    }
    
    func setDefaultCurrency(_ currency: Currency) {
        DispatchQueue.main.async {
            let oldDefault = self.defaultCurrency?.code
            self.defaultCurrency = currency
            
            if let code = currency.code {
                UserDefaults.standard.set(code, forKey: "defaultCurrencyCode")
            }
            
            NotificationCenter.default.post(
                name: Notification.Name("DefaultCurrencyChanged"),
                object: nil,
                userInfo: [
                    "currencyCode": currency.code ?? "USD",
                    "oldDefaultCurrency": oldDefault ?? "USD"
                ]
            )
        }
    }
    
    // Add this method to CurrencyManager
    func debugCurrencies() {
        print("\n📱 Currency Debug Info:")
        print("Initialized: \(isInitialized)")
        print("Available currencies count: \(availableCurrencies.count)")
        print("Default currency: \(defaultCurrency?.code ?? "none")")
        print("Saved default currency code:", UserDefaults.standard.string(forKey: "defaultCurrencyCode") ?? "none")
        
        if let localeCode = Locale.current.currency?.identifier {
            print("System locale currency: \(localeCode)")
            if let localeCurrency = fetchCurrency(withCode: localeCode) {
                print("Locale currency found in database: \(localeCurrency.code ?? "unknown")")
            } else {
                print("Locale currency not found in database")
            }
        }
    }
    
    public func fetchCurrency(withCode code: String) -> Currency? {
        let request: NSFetchRequest<Currency> = Currency.fetchRequest()
        request.predicate = NSPredicate(format: "code == %@", code)
        request.fetchLimit = 1
        
        do {
            let result = try context.fetch(request).first
            if result == nil {
                print("🔍 No currency found for code: \(code)")
            }
            return result
        } catch {
            print("❌ Error fetching currency with code \(code): \(error)")
            return nil
        }
    }
    
    private let commonCurrencies = [
        ("AED", "United Arab Emirates Dirham", "د.إ", "🇦🇪"),
        ("AFN", "Afghan Afghani", "؋", "🇦🇫"),
        ("ALL", "Albanian Lek", "L", "🇦🇱"),
        ("AMD", "Armenian Dram", "֏", "🇦🇲"),
        ("ANG", "Netherlands Antillean Guilder", "ƒ", "🇦🇼"),
        ("AOA", "Angolan Kwanza", "Kz", "🇦🇴"),
        ("ARS", "Argentine Peso", "$", "🇦🇷"),
        ("AUD", "Australian Dollar", "A$", "🇦🇺"),
        ("AWG", "Aruban Florin", "ƒ", "🇦🇼"),
        ("AZN", "Azerbaijani Manat", "₼", "🇦🇿"),
        ("BAM", "Bosnia-Herzegovina Convertible Mark", "KM", "🇧🇦"),
        ("BBD", "Barbadian Dollar", "$", "🇧🇧"),
        ("BDT", "Bangladeshi Taka", "৳", "🇧🇩"),
        ("BGN", "Bulgarian Lev", "лв", "🇧🇬"),
        ("BHD", "Bahraini Dinar", ".د.ب", "🇧🇭"),
        ("BIF", "Burundian Franc", "FBu", "🇧🇮"),
        ("BMD", "Bermudan Dollar", "$", "🇧🇲"),
        ("BND", "Brunei Dollar", "$", "🇧🇳"),
        ("BOB", "Bolivian Boliviano", "Bs.", "🇧🇴"),
        ("BRL", "Brazilian Real", "R$", "🇧🇷"),
        ("BSD", "Bahamian Dollar", "$", "🇧🇸"),
        ("BTC", "Bitcoin", "₿", "🌍"),
        ("BTN", "Bhutanese Ngultrum", "Nu.", "🇧🇹"),
        ("BWP", "Botswanan Pula", "P", "🇧🇼"),
        ("BZD", "Belize Dollar", "BZ$", "🇧🇿"),
        ("CAD", "Canadian Dollar", "C$", "🇨🇦"),
        ("CDF", "Congolese Franc", "FC", "🇨🇩"),
        ("CHF", "Swiss Franc", "Fr.", "🇨🇭"),
        ("CLF", "Chilean Unit of Account (UF)", "UF", "🇨🇱"),
        ("CLP", "Chilean Peso", "$", "🇨🇱"),
        ("CNH", "Chinese Yuan (Offshore)", "¥", "🇨🇳"),
        ("CNY", "Chinese Yuan", "¥", "🇨🇳"),
        ("COP", "Colombian Peso", "$", "🇨🇴"),
        ("CRC", "Costa Rican Colón", "₡", "🇨🇷"),
        ("CUC", "Cuban Convertible Peso", "$", "🇨🇺"),
        ("CUP", "Cuban Peso", "₱", "🇨🇺"),
        ("CVE", "Cape Verdean Escudo", "$", "🇨🇻"),
        ("CZK", "Czech Republic Koruna", "Kč", "🇨🇿"),
        ("DJF", "Djiboutian Franc", "Fdj", "🇩🇯"),
        ("DKK", "Danish Krone", "kr", "🇩🇰"),
        ("DOP", "Dominican Peso", "RD$", "🇩🇴"),
        ("DZD", "Algerian Dinar", "د.ج", "🇩🇿"),
        ("EGP", "Egyptian Pound", "£", "🇪🇬"),
        ("ERN", "Eritrean Nakfa", "Nfk", "🇪🇷"),
        ("ETB", "Ethiopian Birr", "Br", "🇪🇹"),
        ("EUR", "Euro", "€", "🇪🇺"),
        ("FJD", "Fijian Dollar", "FJ$", "🇫🇯"),
        ("FKP", "Falkland Islands Pound", "£", "🇫🇰"),
        ("GBP", "British Pound Sterling", "£", "🇬🇧"),
        ("GEL", "Georgian Lari", "₾", "🇬🇪"),
        ("GGP", "Guernsey Pound", "£", "🇬🇬"),
        ("GHS", "Ghanaian Cedi", "₵", "🇬🇭"),
        ("GIP", "Gibraltar Pound", "£", "🇬🇮"),
        ("GMD", "Gambian Dalasi", "D", "🇬🇲"),
        ("GNF", "Guinean Franc", "FG", "🇬🇳"),
        ("GTQ", "Guatemalan Quetzal", "Q", "🇬🇹"),
        ("GYD", "Guyanaese Dollar", "$", "🇬🇾"),
        ("HKD", "Hong Kong Dollar", "HK$", "🇭🇰"),
        ("HNL", "Honduran Lempira", "L", "🇭🇳"),
        ("HRK", "Croatian Kuna", "kn", "🇭🇷"),
        ("HTG", "Haitian Gourde", "G", "🇭🇹"),
        ("HUF", "Hungarian Forint", "Ft", "🇭🇺"),
        ("IDR", "Indonesian Rupiah", "Rp", "🇮🇩"),
        ("ILS", "Israeli New Sheqel", "₪", "🇮🇱"),
        ("IMP", "Manx pound", "£", "🇮🇲"),
        ("INR", "Indian Rupee", "₹", "🇮🇳"),
        ("IQD", "Iraqi Dinar", "ع.د", "🇮🇶"),
        ("ISK", "Icelandic Króna", "kr", "🇮🇸"),
        ("JEP", "Jersey Pound", "£", "🇯🇪"),
        ("JMD", "Jamaican Dollar", "J$", "🇯🇲"),
        ("JOD", "Jordanian Dinar", "د.ا", "🇯🇴"),
        ("JPY", "Japanese Yen", "¥", "🇯🇵"),
        ("KES", "Kenyan Shilling", "KSh", "🇰🇪"),
        ("KGS", "Kyrgystani Som", "с", "🇰🇬"),
        ("KHR", "Cambodian Riel", "៛", "🇰🇭"),
        ("KMF", "Comorian Franc", "CF", "🇰🇲"),
        ("KRW", "South Korean Won", "₩", "🇰🇷"),
        ("KWD", "Kuwaiti Dinar", "د.ك", "🇰🇼"),
        ("KYD", "Cayman Islands Dollar", "$", "🇰🇾"),
        ("KZT", "Kazakhstani Tenge", "₸", "🇰🇿"),
        ("LAK", "Laotian Kip", "₭", "🇱🇦"),
        ("LBP", "Lebanese Pound", "ل.ل", "🇱🇧"),
        ("LKR", "Sri Lankan Rupee", "Rs", "🇱🇰"),
        ("LRD", "Liberian Dollar", "$", "🇱🇷"),
        ("LSL", "Lesotho Loti", "L", "🇱🇸"),
        ("LYD", "Libyan Dinar", "ل.د", "🇱🇾"),
        ("MAD", "Moroccan Dirham", "د.م.", "🇲🇦"),
        ("MDL", "Moldovan Leu", "L", "🇲🇩"),
        ("MGA", "Malagasy Ariary", "Ar", "🇲🇬"),
        ("MKD", "Macedonian Denar", "ден", "🇲🇰"),
        ("MMK", "Myanma Kyat", "K", "🇲🇲"),
        ("MNT", "Mongolian Tugrik", "₮", "🇲🇳"),
        ("MOP", "Macanese Pataca", "MOP$", "🇲🇴"),
        ("MRU", "Mauritanian Ouguiya", "UM", "🇲🇷"),
        ("MUR", "Mauritian Rupee", "₨", "🇲🇺"),
        ("MVR", "Maldivian Rufiyaa", "Rf", "🇲🇻"),
        ("MWK", "Malawian Kwacha", "MK", "🇲🇼"),
        ("MXN", "Mexican Peso", "$", "🇲🇽"),
        ("MYR", "Malaysian Ringgit", "RM", "🇲🇾"),
        ("MZN", "Mozambican Metical", "MT", "🇲🇿"),
        ("NAD", "Namibian Dollar", "N$", "🇳🇦"),
        ("NGN", "Nigerian Naira", "₦", "🇳🇬"),
        ("NIO", "Nicaraguan Córdoba", "C$", "🇳🇮"),
        ("NOK", "Norwegian Krone", "kr", "🇳🇴"),
        ("NPR", "Nepalese Rupee", "₨", "🇳🇵"),
        ("NZD", "New Zealand Dollar", "NZ$", "🇳🇿"),
        ("OMR", "Omani Rial", "ر.ع.", "🇴🇲"),
        ("PAB", "Panamanian Balboa", "B/.", "🇵🇦"),
        ("PEN", "Peruvian Nuevo Sol", "S/", "🇵🇪"),
        ("PGK", "Papua New Guinean Kina", "K", "🇵🇬"),
        ("PHP", "Philippine Peso", "₱", "🇵🇭"),
        ("PKR", "Pakistani Rupee", "₨", "🇵🇰"),
        ("PLN", "Polish Zloty", "zł", "🇵🇱"),
        ("PYG", "Paraguayan Guarani", "₲", "🇵🇾"),
        ("QAR", "Qatari Rial", "ر.ق", "🇶🇦"),
        ("RON", "Romanian Leu", "lei", "🇷🇴"),
        ("RSD", "Serbian Dinar", "дин.", "🇷🇸"),
        ("RWF", "Rwandan Franc", "FRw", "🇷🇼"),
        ("SAR", "Saudi Riyal", "ر.س", "🇸🇦"),
        ("SBD", "Solomon Islands Dollar", "$", "🇸🇧"),
        ("SCR", "Seychellois Rupee", "₨", "🇸🇨"),
        ("SDG", "Sudanese Pound", "ج.س.", "🇸🇩"),
        ("SEK", "Swedish Krona", "kr", "🇸🇪"),
        ("SGD", "Singapore Dollar", "S$", "🇸🇬"),
        ("SHP", "Saint Helena Pound", "£", "🇸🇭"),
        ("SLL", "Sierra Leonean Leone", "Le", "🇸🇱"),
        ("SOS", "Somali Shilling", "S", "🇸🇴"),
        ("SRD", "Surinamese Dollar", "$", "🇸🇷"),
        ("SSP", "South Sudanese Pound", "£", "🇸🇸"),
        ("STN", "São Tomé and Príncipe Dobra", "Db", "🇸🇹"),
        ("SVC", "Salvadoran Colón", "₡", "🇸🇻"),
        ("SYP", "Syrian Pound", "£", "🇸🇾"),
        ("SZL", "Swazi Lilangeni", "L", "🇸🇿"),
        ("THB", "Thai Baht", "฿", "🇹🇭"),
        ("TJS", "Tajikistani Somoni", "ЅМ", "🇹🇯"),
        ("TMT", "Turkmenistani Manat", "T", "🇹🇲"),
        ("TND", "Tunisian Dinar", "د.ت", "🇹🇳"),
        ("TOP", "Tongan Pa'anga", "T$", "🇹🇴"),
        ("TRY", "Turkish Lira", "₺", "🇹🇷"),
        ("TTD", "Trinidad and Tobago Dollar", "TT$", "🇹🇹"),
        ("TWD", "New Taiwan Dollar", "NT$", "🇹🇼"),
        ("TZS", "Tanzanian Shilling", "TSh", "🇹🇿"),
        ("UAH", "Ukrainian Hryvnia", "₴", "🇺🇦"),
        ("UGX", "Ugandan Shilling", "USh", "🇺🇬"),
        ("USD", "United States Dollar", "$", "🇺🇸"),
        ("UYU", "Uruguayan Peso", "$U", "🇺🇾"),
        ("UZS", "Uzbekistan Som", "so'm", "🇺🇿"),
        ("VES", "Venezuelan Bolívar Soberano", "Bs.S", "🇻🇪"),
        ("VND", "Vietnamese Dong", "₫", "🇻🇳"),
        ("VUV", "Vanuatu Vatu", "VT", "🇻🇺"),
        ("WST", "Samoan Tala", "WS$", "🇼🇸"),
        ("XAF", "CFA Franc BEAC", "FCFA", "🇨🇫"),
        ("XAG", "Silver (troy ounce)", "XAG", "🪙"),
        ("XAU", "Gold (troy ounce)", "XAU", "🪙"),
        ("XCD", "East Caribbean Dollar", "EC$", "🇦🇬"),
        ("XDR", "Special Drawing Rights", "XDR", "🌍"),
        ("XOF", "CFA Franc BCEAO", "CFA", "🇧🇫"),
        ("XPD", "Palladium Ounce", "XPD", "🪙"),
        ("XPF", "CFP Franc", "₣", "🇵🇫"),
        ("XPT", "Platinum Ounce", "XPT", "🪙"),
        ("YER", "Yemeni Rial", "﷼", "🇾🇪"),
        ("ZAR", "South African Rand", "R", "🇿🇦"),
        ("ZMW", "Zambian Kwacha", "ZK", "🇿🇲")
    ]

    func saveCurrencyUpdates() {
        do {
            try context.save()
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        } catch {
            print("Error saving currency updates: \(error)")
        }
    }
}
