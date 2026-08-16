@testable import CurrencySpot
import Foundation
import Testing

@Suite("CalculateConversionUseCase Tests")
struct CalculateConversionUseCaseTests {
    private let useCase = CalculateConversionUseCase()
    private let table = RateTable(rates: [.usd: 1.0, .eur: 0.85, .jpy: 110.0])

    @Test("implied-cents digits become a decimal amount")
    func digitsBecomeAmount() {
        #expect(useCase(impliedCentsDigits: "12345", from: .usd, to: .usd, in: table).amount == Decimal(string: "123.45"))
        #expect(useCase(impliedCentsDigits: "0", from: .usd, to: .usd, in: table).amount == 0)
        #expect(useCase(impliedCentsDigits: "", from: .usd, to: .usd, in: table).amount == 0)
    }

    @Test("a non-numeric input falls back to zero rather than trapping")
    func nonNumericInputIsZero() {
        #expect(useCase(impliedCentsDigits: "abc", from: .usd, to: .eur, in: table).amount == 0)
    }

    @Test("conversion applies the cross rate to the amount")
    func convertsAcrossCurrencies() {
        let conversion = useCase(impliedCentsDigits: "10000", from: .usd, to: .eur, in: table)

        #expect(conversion.amount == 100)
        #expect(conversion.rate == 0.85)
        #expect(conversion.converted == Decimal(string: "85"))
    }

    @Test("an identical pair converts one to one")
    func samePairIsIdentity() {
        let conversion = useCase(impliedCentsDigits: "10000", from: .eur, to: .eur, in: table)

        #expect(conversion.rate == 1.0)
        #expect(conversion.converted == 100)
    }

    @Test("impliedCentsDigits round-trips an amount back to its digit string")
    func impliedCentsRoundTrip() {
        #expect(useCase.impliedCentsDigits(for: Decimal(string: "123.45")!) == "12345")
        #expect(useCase.impliedCentsDigits(for: 0) == "0")
        #expect(useCase.impliedCentsDigits(for: Decimal(string: "0.07")!) == "7")
    }

    @Test("impliedCentsDigits rounds a sub-cent fraction to the nearest cent")
    func impliedCentsRounds() {
        #expect(useCase.impliedCentsDigits(for: Decimal(string: "1.005")!) == "101")
        #expect(useCase.impliedCentsDigits(for: Decimal(string: "1.004")!) == "100")
    }

    @Test("impliedCentsDigits survives amounts beyond Int32 cents")
    func impliedCentsBeyondInt32() {
        #expect(useCase.impliedCentsDigits(for: Decimal(string: "30000000")!) == "3000000000")
        #expect(useCase.impliedCentsDigits(for: Decimal(string: "999999999.99")!) == "99999999999")
    }

    @Test("a digit string produced by impliedCentsDigits reproduces the amount")
    func roundTripThroughUseCase() {
        let amount = Decimal(string: "4321.09")!
        let digits = useCase.impliedCentsDigits(for: amount)

        #expect(useCase(impliedCentsDigits: digits, from: .usd, to: .usd, in: table).amount == amount)
    }
}
