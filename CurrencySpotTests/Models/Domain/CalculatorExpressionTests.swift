@testable import CurrencySpot
import Foundation
import Testing

@Suite("CalculatorExpression Tests")
struct CalculatorExpressionTests {
    private func entering(_ keys: String, into start: CalculatorExpression = CalculatorExpression()) -> CalculatorExpression {
        var expression = start
        for key in keys {
            switch key {
            case "0" ... "9": expression.apply(.digit(Int(String(key)) ?? 0))
            case ".": expression.apply(.decimalPoint)
            case "%": expression.apply(.percent)
            case "+": expression.apply(.operation(.add))
            case "-": expression.apply(.operation(.subtract))
            case "*": expression.apply(.operation(.multiply))
            case "/": expression.apply(.operation(.divide))
            case "<": expression.apply(.delete)
            case "C": expression.apply(.clear)
            case "=": expression.apply(.equals)
            default: Issue.record("Unknown key \(key)")
            }
        }
        return expression
    }

    @Test("multiplication binds tighter than addition")
    func multiplicationBeforeAddition() {
        #expect(entering("1250+8*3").result == 1274)
    }

    @Test("a trailing operator keeps the result of what came before it")
    func trailingOperatorKeepsRunningResult() {
        #expect(entering("1250+8*").result == 1258)
    }

    @Test("a number takes at most two fraction digits, in every number of the calculation")
    func numbersStopAtTwoFractionDigits() {
        var expression = entering("1.99")
        #expect(expression.apply(.digit(9)) == false)
        #expect(expression.result == Decimal(string: "1.99"))

        expression = entering("2+1.55")
        #expect(expression.apply(.digit(5)) == false)
        #expect(expression.result == Decimal(string: "3.55"))
        #expect(expression.steps(locale: Locale(identifier: "en_US")) == "2 + 1.55")
    }

    @Test("a decimal point starts a fraction once per number")
    func decimalPointOncePerNumber() throws {
        #expect(entering("12.5+.25").result == Decimal(string: "12.75"))
        #expect(entering("1.2.5").result == Decimal(string: "1.25"))
    }

    @Test("percent after plus or minus is a share of the running total, otherwise a hundredth")
    func percentFollowsIOSCalculator() {
        #expect(entering("12.5+8%").result == Decimal(string: "13.5"))
        #expect(entering("200-25%").result == 150)
        #expect(entering("200*10%").result == 20)
        #expect(entering("50%").result == Decimal(string: "0.5"))
    }

    @Test("percent with only a zero to apply it to is ignored, and typing continues")
    func percentOnZeroIsIgnored() {
        var start = CalculatorExpression(settledAt: 0)

        #expect(start.apply(.percent) == false)
        #expect(entering("%5", into: CalculatorExpression(settledAt: 0)).result == 5)
        #expect(entering("0.%5").result == Decimal(string: "0.5"))
    }

    @Test("percent shares compound along a chain of plus and minus", .timeLimit(.minutes(1)))
    func percentChainCompounds() {
        #expect(entering("200+10%+10%-50%").result == 121)
        #expect(entering("100" + String(repeating: "+0%", count: 40)).result == 100)
    }

    @Test("dividing by zero has no result")
    func divisionByZeroHasNoResult() {
        #expect(entering("5/0").result == nil)
        #expect(entering("5/0.5").result == 10)
    }

    @Test("a second operator in a row replaces the first")
    func operatorReplacesPendingOperator() {
        #expect(entering("5+*3").result == 15)
    }

    @Test("delete removes the last digit, then the pending operator")
    func deleteStepsBack() {
        #expect(entering("125<").result == 12)
        #expect(entering("7<").result == 0)
        let operatorRemoved = entering("12+3<<")
        #expect(operatorRemoved.result == 12)
        #expect(operatorRemoved.hasOperator == false)
    }

    @Test("equals settles the result to cents, and the next key decides whether to continue")
    func equalsSettlesResult() {
        let settled = entering("1250+8*3=")
        #expect(settled.result == 1274)
        #expect(settled.hasOperator == false)
        #expect(entering("10/3=").result == Decimal(string: "3.33"))
        #expect(entering("2+3=4").result == 4)
        #expect(entering("2+3=*2").result == 10)
    }

    @Test("a number stops accepting digits at twelve and reports the rejection")
    func numberLengthIsCapped() {
        var expression = entering("123456789012")
        let thirteenthAccepted = expression.apply(.digit(3))
        #expect(thirteenthAccepted == false)
        #expect(expression.result == 123_456_789_012)
        expression.apply(.operation(.add))
        let nextNumberAccepted = expression.apply(.digit(3))
        #expect(nextNumberAccepted)
    }

    @Test("steps show each number as typed, grouped for the locale, between operator symbols")
    func stepsFollowLocale() {
        let english = Locale(identifier: "en_US")
        #expect(entering("1250+8*3").steps(locale: english) == "1,250 + 8 × 3")
        #expect(entering("1250-").steps(locale: english) == "1,250 −")
        #expect(entering("12.50/8%").steps(locale: english) == "12.50 ÷ 8%")
        #expect(entering("1250.5+2").steps(locale: Locale(identifier: "de_DE")) == "1.250,5 + 2")
    }

    @Test("an expression settled at an amount continues on an operator and restarts on a digit")
    func settledAmountContinuesOrRestarts() throws {
        let start = CalculatorExpression(settledAt: try #require(Decimal(string: "12.5")))
        #expect(start.result == Decimal(string: "12.5"))
        #expect(entering("+1", into: start).result == Decimal(string: "13.5"))
        #expect(entering("7", into: start).result == 7)
        #expect(entering(".5", into: start).result == Decimal(string: "0.5"))
    }

    @Test("clear starts over at zero")
    func clearStartsOver() {
        let cleared = entering("12+3C")
        #expect(cleared.result == 0)
        #expect(cleared.hasOperator == false)
    }
}
