//
//  RollingDigit.swift
//  Expensa
//
//  Created by Andrew Sereda on 29.10.2024.
//

import SwiftUI

struct CustomAnimateNumberText: View {
    private let font: Font
    private let weight: Font.Weight
    private let currencyManager: CurrencyManager
    private let showCurrencyInFront: Bool
    
    @Binding private var amount: Decimal
    @Binding private var textColor: Color
    
    private var numberFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.decimalSeparator = ","
        formatter.groupingSeparator = " "
        return formatter
    }
    
    private var formattedAmount: String {
        guard let defaultCurrency = currencyManager.defaultCurrency else {
            return numberFormatter.string(from: amount as NSDecimalNumber) ?? "0,00"
        }
        return currencyManager.currencyConverter.formatAmount(amount, currency: defaultCurrency)
    }
    
    init(
        font: Font = .largeTitle,
        weight: Font.Weight = .regular,
        amount: Binding<Decimal>,
        textColor: Binding<Color>,
        currencyManager: CurrencyManager,
        showCurrencyInFront: Bool = false
    ) {
        self.font = font
        self.weight = weight
        self._amount = amount
        self._textColor = textColor
        self.currencyManager = currencyManager
        self.showCurrencyInFront = showCurrencyInFront
    }
    
    var body: some View {
        Text(formattedAmount)
            .font(font)
            .fontWeight(weight)
            .foregroundColor(textColor)
            .contentTransition(.numericText())
            .animation(.spring(response: 0.4, dampingFraction: 0.95), value: amount)
    }
}
