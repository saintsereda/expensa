//
//  File.swift
//  Expensa
//
//  Created by Andrew Sereda on 02.11.2024.
//

import Foundation
import CoreData
import Combine
import SwiftUI

class HistoricalRateManager: ObservableObject {
    static let shared = HistoricalRateManager()
    private let context: NSManagedObjectContext
    let lastUpdateKey = "LastCurrencyRateUpdate"
    @Published private(set) var currentRates: [String: Double] = [:]
    @Published private(set) var isFetching = false
    @Published private(set) var lastError: String?
    
    private var fetchTask: URLSessionDataTask?
    private var appId: String = ""
    
    private init() {
        self.context = CoreDataStack.shared.context
         
         // Try to get API key from keychain first
         if let savedKey = KeychainHelper.shared.getApiKey() {
             print("✅ Found API key in Keychain")
             self.appId = savedKey
         } else {
             // Fallback to Info.plist during development
             if let apiKey = Bundle.main.object(forInfoDictionaryKey: "OPENEXCHANGE_API_KEY") as? String {
                 print("📦 Found API key in Info.plist: \(apiKey)")
                 if !apiKey.isEmpty {
                     self.appId = apiKey
                     _ = KeychainHelper.shared.saveApiKey(apiKey)
                     print("✅ Saved API key to Keychain")
                 } else {
                     print("⚠️ API key from Info.plist is empty")
                 }
             } else {
                 print("⚠️ No API key found in Info.plist")
             }
         }
         
         print("Current API key status: \(isApiKeyValid ? "Valid" : "Invalid")")
        
        loadCachedRates()
        fetchRatesIfNeeded()
        scheduleMidnightUpdate()
    }
    
    // Public method to configure API key
    func configureApiKey(_ key: String) -> Bool {
        guard !key.isEmpty else {
            lastError = "API key cannot be empty"
            return false
        }
        
        if KeychainHelper.shared.saveApiKey(key) {
            self.appId = key
            fetchRatesIfNeeded(forceUpdate: true)
            return true
        }
        
        lastError = "Failed to save API key"
        return false
    }
    
    private var isApiKeyValid: Bool {
        !appId.isEmpty
    }
    
    // MARK: - Rate Management
    private func loadCachedRates() {
        let fetchRequest: NSFetchRequest<ExchangeRateHistory> = ExchangeRateHistory.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "rateDate", ascending: false)]
        
        guard let histories = try? context.fetch(fetchRequest) else {
            print("❌ Failed to fetch cached rates")
            return
        }
        
        var latestRates: [String: Double] = [:]
        for history in histories {
            guard let code = history.currencyCode,
                  !latestRates.keys.contains(code) else {
                continue
            }
            latestRates[code] = history.rateToUSD?.doubleValue
            print("💾 Loaded \(code): \(history.rateToUSD?.doubleValue ?? 0.0)")
        }
        self.currentRates = latestRates
    }
    
    func saveHistoricalRate(currencyCode: String, rate: Decimal, date: Date = Date()) {
        context.performAndWait {
            let history = ExchangeRateHistory(context: context)
            history.id = UUID()
            history.currencyCode = currencyCode
            history.rateDate = Calendar.current.startOfDay(for: date)
            history.rateToUSD = NSDecimalNumber(decimal: rate)
            
            if let currency = CurrencyManager.shared.fetchCurrency(withCode: currencyCode) {
                history.currency = currency
            }
            
            saveContext()
        }
    }

    func getRate(for code: String, on date: Date) -> Decimal? {
        let fetchRequest: NSFetchRequest<ExchangeRateHistory> = ExchangeRateHistory.fetchRequest()
        
        // First, try to find a rate on or before the specified date
        fetchRequest.predicate = NSPredicate(
            format: "currencyCode == %@ AND rateDate <= %@",
            code,
            date as NSDate
        )
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "rateDate", ascending: false)]
        fetchRequest.fetchLimit = 1

        if let history = try? context.fetch(fetchRequest).first,
           let rate = history.rateToUSD?.decimalValue {
            print("✅ Found historical rate for \(code) on or before \(date)")
            return rate
        }

        // If no historical rate found, use the latest available rate
        print("ℹ️ No historical rate found for \(code) on \(date), using latest available rate")
        
        let latestFetchRequest: NSFetchRequest<ExchangeRateHistory> = ExchangeRateHistory.fetchRequest()
        latestFetchRequest.predicate = NSPredicate(format: "currencyCode == %@", code)
        latestFetchRequest.sortDescriptors = [NSSortDescriptor(key: "rateDate", ascending: false)]
        latestFetchRequest.fetchLimit = 1

        if let latestHistory = try? context.fetch(latestFetchRequest).first,
           let latestRate = latestHistory.rateToUSD?.decimalValue {
            print("✅ Using latest rate for \(code): \(latestRate)")
            return latestRate
        }

        // If no rate is found at all, check the current rates dictionary
        if let currentRate = currentRates[code] {
            print("✅ Using current rate for \(code): \(currentRate)")
            return Decimal(currentRate)
        }

        print("❌ No rate found for \(code)")
        return nil
    }
    
    // MARK: - Rate Fetching
    private var shouldUpdateRates: Bool {
        if let lastUpdate = UserDefaults.standard.object(forKey: lastUpdateKey) as? Date {
            let calendar = Calendar.current
            let startOfToday = calendar.startOfDay(for: Date())
            return lastUpdate < startOfToday
        }
        return true
    }
    
    func fetchRatesIfNeeded(forceUpdate: Bool = false) {
        guard (shouldUpdateRates || forceUpdate), !isFetching else {
            print("⏳ Skipping rate fetch - already up to date or in progress")
            return
        }
        
        // Check API key first
        guard !appId.isEmpty else {
            print("❌ API key not configured")
            return
        }
        
        isFetching = true
        fetchTask?.cancel()
        
        // Keep the simple URL construction that was working before
        let url = URL(string: "https://openexchangerates.org/api/latest.json?app_id=\(appId)")!
        
        fetchTask = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            defer {
                DispatchQueue.main.async {
                    self?.isFetching = false
                }
            }
            
            // Simple error handling that worked before
            if let error = error {
                print("❌ Network error: \(error.localizedDescription)")
                return
            }
            
            guard let data = data else {
                print("❌ No data received")
                return
            }
            
            // Add basic response validation
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode != 200 {
                print("❌ Server returned status code: \(httpResponse.statusCode)")
                return
            }
            
            do {
                let result = try JSONDecoder().decode(RatesResponse.self, from: data)
                DispatchQueue.main.async {
                    self?.updateRates(result.rates)
                }
            } catch {
                print("❌ Decoding error: \(error)")
            }
        }
        
        fetchTask?.resume()
    }
    
    private func updateRates(_ rates: [String: Double]) {
        let currentTime = Date()
        self.currentRates = rates
        
        context.performAndWait {
            rates.forEach { code, rate in
                let history = ExchangeRateHistory(context: context)
                history.id = UUID()
                history.currencyCode = code
                history.rateDate = currentTime
                history.rateToUSD = NSDecimalNumber(value: rate)
            }
            
            saveContext()
            UserDefaults.standard.set(currentTime, forKey: lastUpdateKey)
        }
    }
    
    // MARK: - Scheduling
    private func scheduleMidnightUpdate() {
        guard let tomorrow = Calendar.current.date(
            byAdding: .day,
            value: 1,
            to: Calendar.current.startOfDay(for: Date())
        ) else { return }
        
        let timer = Timer(fire: tomorrow, interval: 0, repeats: false) { [weak self] _ in
            self?.fetchRatesIfNeeded()
            self?.scheduleMidnightUpdate()
        }
        RunLoop.main.add(timer, forMode: .common)
    }
    
    func performYearlyCleanup() {
        guard let oneYearAgo = Calendar.current.date(
            byAdding: .year,
            value: -1,
            to: Date()
        ) else { return }
        
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = ExchangeRateHistory.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "rateDate < %@",
            oneYearAgo as NSDate
        )
        
        let batchDelete = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        
        do {
            try context.execute(batchDelete)
            try context.save()
            print("✅ Cleaned up old exchange rates")
        } catch {
            print("❌ Error cleaning up old rates: \(error)")
        }
    }
    
    private func saveContext() {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            print("❌ Error saving context: \(error)")
            context.rollback()
        }
    }
    
    private struct RatesResponse: Codable {
        let timestamp: TimeInterval
        let base: String
        let rates: [String: Double]
    }
    
    func debugRateFetching() {
        print("\n📊 Rate Fetching Debug Info:")
        
        // Check last update time
        if let lastUpdate = UserDefaults.standard.object(forKey: lastUpdateKey) as? Date {
            let formatter = DateFormatter()
            formatter.dateFormat = "d MMM yyyy 'at' HH:mm:ss"
            print("   Last API Update: \(formatter.string(from: lastUpdate))")
        } else {
            print("   ⚠️ No recorded last update time")
        }
        
        // Check current rates
        print("\n   Current Rates in Memory:")
        print("   Total rates loaded: \(currentRates.count)")
        
        // Sample some major currencies
        let majorCurrencies = ["USD", "EUR", "GBP", "JPY"]
        for currency in majorCurrencies {
            if let rate = currentRates[currency] {
                print("   \(currency): \(rate)")
            } else {
                print("   \(currency): Not available")
            }
        }
        
        // Check if update is needed
        print("\n   Update Status:")
        print("   Should update rates: \(shouldUpdateRates)")
        print("   Currently fetching: \(isFetching)")
    }
}
