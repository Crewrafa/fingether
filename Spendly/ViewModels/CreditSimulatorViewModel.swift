import Foundation

@MainActor
@Observable
final class CreditSimulatorViewModel {

    // MARK: - Inputs

    var amountText = ""
    var rateText = "28.5"
    var months: Int = 36
    var startDate = Date()

    var amountSlider: Double = 50_000_000
    var rateSlider: Double = 28.5

    // MARK: - Parsed Inputs

    var parsedAmount: Decimal {
        let d = parseAmountFromFormatted(amountText)
        return d > 0 ? d : Decimal(amountSlider)
    }

    var parsedRate: Decimal {
        Decimal(string: rateText.replacingOccurrences(of: ",", with: ".")) ?? Decimal(rateSlider)
    }

    var monthlyRate: Decimal {
        parsedRate / 100 / 12
    }

    // MARK: - Core Calculations (French amortization — fixed payment)

    var monthlyPayment: Decimal {
        let p = parsedAmount
        let r = monthlyRate
        let n = months
        guard n > 0, p > 0 else { return 0 }
        guard r > 0 else { return p / Decimal(n) }

        // cuota = P * (r * (1+r)^n) / ((1+r)^n - 1)
        let onePlusR = 1 + NSDecimalNumber(decimal: r).doubleValue
        let power = pow(onePlusR, Double(n))
        let rDouble = NSDecimalNumber(decimal: r).doubleValue
        let pDouble = NSDecimalNumber(decimal: p).doubleValue

        let payment = pDouble * (rDouble * power) / (power - 1)
        return Decimal(Int(payment.rounded()))
    }

    var totalPayment: Decimal {
        monthlyPayment * Decimal(months)
    }

    var totalInterest: Decimal {
        totalPayment - parsedAmount
    }

    var interestPercentage: Int {
        guard parsedAmount > 0 else { return 0 }
        let pct = NSDecimalNumber(decimal: totalInterest / parsedAmount * 100).doubleValue
        return Int(pct.rounded())
    }

    var capitalRatio: Double {
        guard totalPayment > 0 else { return 1 }
        return NSDecimalNumber(decimal: parsedAmount / totalPayment).doubleValue
    }

    var monthlyRateFormatted: String {
        let r = NSDecimalNumber(decimal: monthlyRate * 100).doubleValue
        return String(format: "%.2f%%", r)
    }

    var lastPaymentDate: Date {
        Calendar.current.date(byAdding: .month, value: months, to: startDate) ?? startDate
    }

    // MARK: - Amortization Table

    struct AmortizationRow: Identifiable {
        let id: Int // month number
        let payment: Decimal
        let capital: Decimal
        let interest: Decimal
        let balance: Decimal
    }

    var amortizationTable: [AmortizationRow] {
        let p = parsedAmount
        let r = monthlyRate
        let cuota = monthlyPayment
        guard months > 0, p > 0, cuota > 0 else { return [] }

        var rows: [AmortizationRow] = []
        var balance = NSDecimalNumber(decimal: p).doubleValue
        let rDouble = NSDecimalNumber(decimal: r).doubleValue
        let cuotaDouble = NSDecimalNumber(decimal: cuota).doubleValue

        for m in 1...months {
            let interestMonth = balance * rDouble
            var capitalMonth = cuotaDouble - interestMonth
            if m == months { capitalMonth = balance } // last month: pay remaining
            balance -= capitalMonth
            if balance < 0 { balance = 0 }

            rows.append(AmortizationRow(
                id: m,
                payment: Decimal(Int(cuotaDouble.rounded())),
                capital: Decimal(Int(capitalMonth.rounded())),
                interest: Decimal(Int(interestMonth.rounded())),
                balance: Decimal(Int(max(balance, 0).rounded()))
            ))
        }
        return rows
    }

    // MARK: - Comparator

    struct PlanComparison: Identifiable {
        let id: Int // months
        let months: Int
        let monthlyPayment: Decimal
        let totalInterest: Decimal
        let totalPayment: Decimal
    }

    var comparisons: [PlanComparison] {
        let shorter = max(months - 12, 6)
        let longer = min(months + 12, 120)
        let plans = Set([shorter, months, longer]).sorted()

        return plans.map { m in
            let mp = calculatePayment(amount: parsedAmount, rate: monthlyRate, months: m)
            let total = mp * Decimal(m)
            return PlanComparison(
                id: m,
                months: m,
                monthlyPayment: mp,
                totalInterest: total - parsedAmount,
                totalPayment: total
            )
        }
    }

    // MARK: - Slider Sync

    func syncAmountFromSlider() {
        let val = Int(amountSlider)
        amountText = formatWithThousands("\(val)")
    }

    func syncAmountFromText() {
        let parsed = parseAmountFromFormatted(amountText)
        if parsed > 0 {
            amountSlider = min(max(NSDecimalNumber(decimal: parsed).doubleValue, 100_000), 500_000_000)
        }
    }

    func syncRateFromSlider() {
        rateText = String(format: "%.1f", rateSlider)
    }

    func syncRateFromText() {
        if let val = Double(rateText.replacingOccurrences(of: ",", with: ".")) {
            rateSlider = min(max(val, 0), 60)
        }
    }

    // MARK: - Helpers

    private func calculatePayment(amount: Decimal, rate: Decimal, months: Int) -> Decimal {
        guard months > 0, amount > 0 else { return 0 }
        guard rate > 0 else { return amount / Decimal(months) }

        let onePlusR = 1 + NSDecimalNumber(decimal: rate).doubleValue
        let power = pow(onePlusR, Double(months))
        let rDouble = NSDecimalNumber(decimal: rate).doubleValue
        let pDouble = NSDecimalNumber(decimal: amount).doubleValue

        let payment = pDouble * (rDouble * power) / (power - 1)
        return Decimal(Int(payment.rounded()))
    }

    func formattedDecimal(_ value: Decimal) -> String {
        let intVal = Int(NSDecimalNumber(decimal: value).doubleValue.rounded())
        let symbol = AppPreferences.shared.currency.symbol
        return "\(symbol)\(formatWithThousands("\(intVal)"))"
    }

    // MARK: - Couple Split (only used when isCoupleMode == true)

    /// Tipo de split actual de la pareja, leido desde MockDataService.coupleSettings.
    var coupleSplitType: SplitType {
        MockDataService.shared.coupleSettings.defaultSplitType
    }

    /// Porcentajes que paga cada miembro de la pareja bajo el split actual.
    /// Para .proportional usa los ingresos reales de la pareja.
    var coupleSplitPercents: (user1: Int, user2: Int) {
        MockDataService.shared.splitPercents(for: coupleSplitType)
    }

    /// Cuota mensual que asume cada miembro de la pareja segun el split actual.
    var coupleMonthlyPayment: (user1: Decimal, user2: Decimal) {
        MockDataService.shared.splitFor(amount: monthlyPayment, splitType: coupleSplitType)
    }

    /// Total a pagar (capital + intereses) que asume cada miembro.
    var coupleTotalPayment: (user1: Decimal, user2: Decimal) {
        MockDataService.shared.splitFor(amount: totalPayment, splitType: coupleSplitType)
    }

    /// Total de intereses que asume cada miembro.
    var coupleTotalInterest: (user1: Decimal, user2: Decimal) {
        MockDataService.shared.splitFor(amount: totalInterest, splitType: coupleSplitType)
    }

    /// Para una fila de la tabla de amortizacion, retorna la parte que paga cada usuario en esa cuota.
    func coupleSplitForRow(_ row: AmortizationRow) -> (user1: Decimal, user2: Decimal) {
        MockDataService.shared.splitFor(amount: row.payment, splitType: coupleSplitType)
    }

    /// Para un plan del comparador, retorna la cuota mensual de cada usuario.
    func coupleMonthlyForPlan(_ plan: PlanComparison) -> (user1: Decimal, user2: Decimal) {
        MockDataService.shared.splitFor(amount: plan.monthlyPayment, splitType: coupleSplitType)
    }
}
