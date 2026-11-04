import AppIntents
import SwiftUI

struct ConvertCurrencyIntent: AppIntent {
    static let title: LocalizedStringResource = "intent.convert.title"
    static let description = IntentDescription("intent.convert.description")

    @Parameter(title: "intent.convert.amount")
    var amount: Double

    @Parameter(title: "intent.convert.from")
    var from: CurrencyEntity

    @Parameter(title: "intent.convert.to")
    var to: CurrencyEntity

    @Dependency private var convertCurrency: ConvertCurrencyUseCase

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Double> & ProvidesDialog & ShowsSnippetView {
        let conversion = try await convertCurrency(amount: Decimal(amount), from: from.code, to: to.code)
        let formatted = FormattedConversion(conversion)
        return .result(
            value: NSDecimalNumber(decimal: conversion.converted).doubleValue,
            dialog: IntentDialog(.intentConvertResult(amount: formatted.amount, converted: formatted.converted)),
            view: ConversionSnippetView(conversion: formatted)
                .environment(\.colorScheme, systemColorScheme)
        )
    }

    // iOS gives App Intent snippets a light colorScheme in Dark Mode (FB17603899).
    @MainActor
    private var systemColorScheme: ColorScheme {
        UIScreen.main.traitCollection.userInterfaceStyle == .dark ? .dark : .light
    }
}

extension ConvertCurrencyUseCase.Failure: CustomLocalizedStringResourceConvertible {
    var localizedStringResource: LocalizedStringResource {
        switch self {
        case let .ratesUnavailable(error): error?.message ?? .errorNetworkMessage
        case let .noRate(currency): .intentConvertNoRate(currency: currency.rawValue)
        }
    }
}
