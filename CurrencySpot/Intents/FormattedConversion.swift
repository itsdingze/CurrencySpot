import Foundation

struct FormattedConversion {
    let amount: String
    let converted: String
    let ratesDate: String?

    init(_ conversion: ConvertCurrencyUseCase.Conversion, locale: Locale = .autoupdatingCurrent) {
        amount = conversion.amount.amountText(in: conversion.from, locale: locale)
        converted = conversion.converted.amountText(in: conversion.to, locale: locale)
        ratesDate = conversion.ratesDate?.lastUpdatedDisplay
    }
}
