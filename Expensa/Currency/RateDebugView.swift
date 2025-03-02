//
//  RateDebugView.swift
//  Expensa
//
//  Created by Andrew Sereda on 02.11.2024.
//

import Foundation
import SwiftUI
import CoreData

struct RateDebugView: View {
    @Environment(\.dismiss) var dismiss
    @State private var debugMessages: [String] = []
    
    var body: some View {
        List {
            Section(header: Text("Debug Controls")) {
                Button("Check Rates") {
                    // checkRates()
                }
                //                Button("Force Save Current Rates") {
                //                    saveCurrentRatesToHistory()
                //                }
                //                Button("Force Rate Update") {
                //                  //  CurrencyConverter.shared.fetchRatesIfNeeded()
                //                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                //                        // Check rates after a short delay to allow fetch to complete
                //                        self.checkRates()
                //                    }
                //                }
                //            }
                //
                //            Section(header: Text("Debug Output")) {
                //                ForEach(debugMessages, id: \.self) { message in
                //                    Text(message)
                //                        .font(.system(.body, design: .monospaced))
                //                }
                //            }
                //        }
                //        .navigationTitle("Rate Debug")
                //        .toolbar {
                //            Button("Done") {
                //                dismiss()
                //            }
                //        }
            }
        }
    }
}
    
//    private func saveCurrentRatesToHistory() {
//        debugMessages.append("\n📥 Forcing rate save to history...")
//        
//       // let currentRates = HistoricalRateManager.shared.conversionRates
//        let now = Date()
//        
//        CoreDataStack.shared.context.performAndWait {
//            for (code, rate) in currentRates {
//                let history = ExchangeRateHistory(context: CoreDataStack.shared.context)
//                history.id = UUID()
//                history.currencyCode = code
//                history.rateDate = Calendar.current.startOfDay(for: now)
//                history.rateToUSD = NSDecimalNumber(value: rate)
//                
//                debugMessages.append("   💾 Saving \(code): \(rate)")
//            }
//            
//            do {
//                try CoreDataStack.shared.context.save()
//                debugMessages.append("✅ Save completed")
//                checkRates() // Refresh the display
//            } catch {
//                debugMessages.append("❌ Save failed: \(error.localizedDescription)")
//            }
//        }
//    }
//    
//    private func checkRates() {
//        debugMessages.removeAll()
//        
//        let formatter = DateFormatter()
//        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
//        let now = Date()
//        debugMessages.append("📅 Check time: \(formatter.string(from: now))")
//        
//        // Check current rates
//        debugMessages.append("\n💱 Current Rates:")
////        HistoricalRateManager.shared.conversionRates.forEach { code, rate in
////            debugMessages.append("   \(code): \(rate)")
////        }
//        
//        // Check stored historical rates with more detail
//        let request: NSFetchRequest<ExchangeRateHistory> = ExchangeRateHistory.fetchRequest()
//        let startOfDay = Calendar.current.startOfDay(for: now)
//        request.predicate = NSPredicate(
//            format: "rateDate == %@",
//            startOfDay as NSDate
//        )
//        
//        debugMessages.append("\n🔍 Checking rates for: \(formatter.string(from: startOfDay))")
//        
//        do {
//            let storedRates = try CoreDataStack.shared.context.fetch(request)
//            debugMessages.append("\n💾 Stored Historical Rates:")
//            
//            if storedRates.isEmpty {
//                debugMessages.append("   ⚠️ No rates found for today")
//                
//                // Check if we have any historical rates at all
//                let allRatesRequest: NSFetchRequest<ExchangeRateHistory> = ExchangeRateHistory.fetchRequest()
//                let allRates = try CoreDataStack.shared.context.fetch(allRatesRequest)
//                if !allRates.isEmpty {
//                    debugMessages.append("\n📈 Found rates for other dates:")
//                    let dateFormatter = DateFormatter()
//                    dateFormatter.dateStyle = .medium
//                    
//                    allRates.forEach { history in
//                        if let date = history.rateDate {
//                            debugMessages.append("   \(dateFormatter.string(from: date)): \(String(describing: history.currencyCode)) = \(history.rateToUSD?.stringValue ?? "nil")")
//                        }
//                    }
//                }
//            } else {
//                storedRates.forEach { history in
//                    debugMessages.append("   \(String(describing: history.currencyCode)): \(history.rateToUSD?.stringValue ?? "nil")")
//                }
//            }
//            debugMessages.append("\n📊 Total stored rates for today: \(storedRates.count)")
//        } catch {
//            debugMessages.append("❌ Error: \(error.localizedDescription)")
//        }
//        
//        // Add save verification
//        debugMessages.append("\n🔄 Verifying Core Data Status:")
//        debugMessages.append("   Context has changes: \(CoreDataStack.shared.context.hasChanges)")
//        
//        if let lastUpdate = UserDefaults.standard.object(forKey: "LastCurrencyRateUpdate") as? Date {
//            debugMessages.append("   Last update: \(formatter.string(from: lastUpdate))")
//        } else {
//            debugMessages.append("   ⚠️ No last update time found")
//        }
//    }
//}
