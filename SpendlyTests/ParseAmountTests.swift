import XCTest
@testable import Spendly

final class ParseAmountTests: XCTestCase {

    // MARK: - parseAmountFromFormatted

    func testParseFormattedLargeNumber() {
        let result = parseAmountFromFormatted("4.600.000")
        XCTAssertEqual(result, 4_600_000)
    }

    func testParseFormattedMediumNumber() {
        let result = parseAmountFromFormatted("30.000")
        XCTAssertEqual(result, 30_000)
    }

    func testParseFormattedSmallNumber() {
        let result = parseAmountFromFormatted("800")
        XCTAssertEqual(result, 800)
    }

    func testParseFormattedEmptyString() {
        let result = parseAmountFromFormatted("")
        XCTAssertEqual(result, Decimal.zero)
    }

    func testParseFormattedNonNumericString() {
        let result = parseAmountFromFormatted("abc")
        XCTAssertEqual(result, Decimal.zero)
    }

    func testParseFormattedVeryLargeNumber() {
        let result = parseAmountFromFormatted("1.234.567.890")
        XCTAssertEqual(result, 1_234_567_890)
    }

    func testParseFormattedWithCurrencySymbol() {
        // parseAmountFromFormatted strips non-digits
        let result = parseAmountFromFormatted("$1.500.000")
        XCTAssertEqual(result, 1_500_000)
    }

    // MARK: - formatWithThousands

    func testFormatLargeNumber() {
        let result = formatWithThousands("4600000")
        XCTAssertEqual(result, "4.600.000")
    }

    func testFormatEmptyString() {
        let result = formatWithThousands("")
        XCTAssertEqual(result, "")
    }

    func testFormatSmallNumber() {
        let result = formatWithThousands("800")
        XCTAssertEqual(result, "800")
    }

    func testFormatMediumNumber() {
        let result = formatWithThousands("30000")
        XCTAssertEqual(result, "30.000")
    }

    func testFormatOneThousand() {
        let result = formatWithThousands("1000")
        XCTAssertEqual(result, "1.000")
    }

    func testFormatStripsNonDigits() {
        // formatWithThousands filters to digits first
        let result = formatWithThousands("abc123def")
        XCTAssertEqual(result, "123")
    }

    // MARK: - Roundtrip: format then parse

    func testRoundtripFormatThenParse() {
        let original = "5000000"
        let formatted = formatWithThousands(original)
        let parsed = parseAmountFromFormatted(formatted)
        XCTAssertEqual(parsed, 5_000_000)
    }

    // MARK: - VoiceExpenseParser (Spanish)

    func testVoiceParserSpanish30MilSupermercado() {
        let result = VoiceExpenseParser.parse(text: "Gaste 30 mil en el supermercado", language: .es)
        XCTAssertEqual(result.amount, 30_000, "Should parse '30 mil' as 30000")
        XCTAssertEqual(result.category, .food, "Should detect supermercado as food")
        XCTAssertNotNil(result.merchant, "Should extract a merchant name")
    }

    // MARK: - VoiceExpenseParser (English)

    func testVoiceParserEnglish50Restaurant() {
        let result = VoiceExpenseParser.parse(text: "Spent 50 at restaurant", language: .en)
        XCTAssertEqual(result.amount, 50, "Should parse '50' as 50")
        XCTAssertEqual(result.category, .food, "Should detect restaurant as food")
    }

    // MARK: - VoiceExpenseParser (Spanish compound number)

    func testVoiceParser25MilQuinientos() {
        let result = VoiceExpenseParser.parse(text: "25 mil quinientos", language: .es)
        XCTAssertEqual(result.amount, 25_500, "Should parse '25 mil quinientos' as 25500")
    }

    // MARK: - VoiceExpenseParser edge cases

    func testVoiceParserEmptyText() {
        let result = VoiceExpenseParser.parse(text: "", language: .es)
        XCTAssertNil(result.amount)
        XCTAssertNil(result.merchant)
        XCTAssertNil(result.category)
    }

    func testVoiceParserNoAmount() {
        let result = VoiceExpenseParser.parse(text: "fui al supermercado", language: .es)
        XCTAssertEqual(result.category, .food, "Should still detect category")
    }

    func testVoiceParserTransportCategory() {
        let result = VoiceExpenseParser.parse(text: "Gaste 120 en uber", language: .es)
        XCTAssertEqual(result.amount, 120)
        XCTAssertEqual(result.category, .transport)
    }

    func testVoiceParserGermanMultiplier() {
        let result = VoiceExpenseParser.parse(text: "50 tausend", language: .de)
        XCTAssertEqual(result.amount, 50_000)
    }
}
