//
//  GraphCalculator.swift
//  Expensa
//
//  Created by Andrew Sereda on 08.11.2024.
//

import Foundation
import SwiftUI

// Common helper functions to prevent NaN
//private struct GraphCalculator {
//    static func calculateYPosition(
//        for amount: Decimal,
//        maxAmount: Decimal,
//        height: CGFloat
//    ) -> CGFloat {
//        // Prevent division by zero
//        guard maxAmount != 0 else { return height }
//        
//        let amountDouble = NSDecimalNumber(decimal: amount).doubleValue
//        let maxDouble = NSDecimalNumber(decimal: maxAmount).doubleValue
//        
//        // Prevent NaN
//        guard maxDouble > 0, amountDouble.isFinite, maxDouble.isFinite else {
//            return height
//        }
//        
//        return height - (height * CGFloat(amountDouble / maxDouble))
//    }
//    
//    static func safeMaxAmount(_ amounts: [Decimal]) -> Decimal {
//        amounts.max() ?? 1
//    }
//    
//    static func calculateCurrentDayX(currentDate: Date, selectedDate: Date, daysInMonth: Int) -> CGFloat {
//        let calendar = Calendar.current
//        let currentDay = calendar.component(.day, from: currentDate) - 1
//        return CGFloat(currentDay) / CGFloat(max(daysInMonth - 1, 1))
//    }
//}
