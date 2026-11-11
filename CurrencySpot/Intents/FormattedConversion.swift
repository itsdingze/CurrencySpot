import Foundation

struct FormattedConversion {
    let amount: String
    let converted: String
    let lastUpdated: String?
    let dialog: String

    init(_ conversion: ConvertCurrencyUseCase.Conversion, locale: Locale = .autoupdatingCurrent) {
        let amount = conversion.amount.amountText(in: conversion.from, locale: locale)
        let converted = conversion.converted.amountText(in: conversion.to, locale: locale)
        self.amount = amount
        self.converted = converted
        lastUpdated = conversion.ratesDate.map {
            String(localized: .calculatorRateInfoLastUpdated(date: $0.lastUpdatedDisplay(in: locale)), in: locale)
        }
        dialog = String(localized: .intentConvertResult(amount: amount, converted: converted), in: locale)
    }
}
