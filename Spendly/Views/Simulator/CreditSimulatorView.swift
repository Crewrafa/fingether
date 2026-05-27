import SwiftUI
import Charts

struct CreditSimulatorView: View {

    @State private var vm = CreditSimulatorViewModel()
    @State private var showTable = false
    @State private var preferences = AppPreferences.shared
    @State private var paywallFeature: PremiumFeature?  // P6
    @Environment(\.colorScheme) private var cs

    private let teal = Color.fingetherPrimary
    private let coral = Color.fingetherExpense
    private let slate = Color.fingetherSlate
    private let cream = Color.fingetherCream
    private let rose = Color.fingetherRose
    private var fieldBg: Color { cs == .dark ? Color(hex: "2A2A3A") : cream }
    private var isCoupleMode: Bool { preferences.isCoupleMode }
    private var isPremium: Bool {
        MockDataService.shared.mockProfile?.subscriptionTier == .premium
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                inputsSection
                if vm.parsedAmount > 0 && vm.months > 0 {
                    paymentHero
                    if isCoupleMode {
                        coupleSplitCard
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    summaryCard
                    capitalBar
                    detailsCard
                    chartSection
                    // P6: comparator + amortization table = premium feature
                    if isPremium {
                        comparatorSection
                        amortizationSection
                    } else {
                        premiumLockedAdvancedCard
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("🏦 Calculadora de crédito")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .paywallGate($paywallFeature)
    }

    // MARK: - Premium Locked Card (P6)

    private var premiumLockedAdvancedCard: some View {
        Button {
            paywallFeature = .creditSimulatorAdvanced
        } label: {
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(Color.fingetherPrimary)
                    Text("Tabla de amortización + comparador")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color(.label))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                Text("Desbloquea con Premium para ver el detalle mes a mes y comparar plazos.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
            .background(Color.fingetherPrimary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.fingetherPrimary.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Inputs

    private var inputsSection: some View {
        VStack(spacing: 18) {
            // ── Amount ──
            VStack(alignment: .leading, spacing: 10) {
                Text("¿Cuanto vas a pedir?")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(slate)

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(AppPreferences.shared.currency.symbol)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(teal)
                    TextField("0", text: $vm.amountText)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(slate)
                        .keyboardType(.numberPad)
                        .onChange(of: vm.amountText) { _, val in
                            vm.amountText = formatWithThousands(val)
                            vm.syncAmountFromText()
                        }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(fieldBg)
                .clipShape(RoundedRectangle(cornerRadius: 14))

                Slider(value: $vm.amountSlider, in: 100_000...500_000_000, step: 100_000)
                    .tint(teal)
                    .onChange(of: vm.amountSlider) { _, _ in vm.syncAmountFromSlider() }

                HStack {
                    Text("$100K").font(.caption2).foregroundStyle(.tertiary)
                    Spacer()
                    Text("$500M").font(.caption2).foregroundStyle(.tertiary)
                }
            }

            // ── Rate ──
            VStack(alignment: .leading, spacing: 10) {
                Text("Tasa anual (E.A.)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(slate)

                HStack(spacing: 8) {
                    HStack(spacing: 2) {
                        TextField("28.5", text: $vm.rateText)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(slate)
                            .keyboardType(.decimalPad)
                            .frame(width: 70)
                            .multilineTextAlignment(.center)
                            .onChange(of: vm.rateText) { _, _ in vm.syncRateFromText() }
                        Text("%")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(teal)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(fieldBg)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    Spacer()

                    // Monthly rate badge
                    Text("Mensual: \(vm.monthlyRateFormatted)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(teal)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(teal.opacity(0.1))
                        .clipShape(Capsule())
                }

                Slider(value: $vm.rateSlider, in: 0...60, step: 0.5)
                    .tint(teal)
                    .onChange(of: vm.rateSlider) { _, _ in vm.syncRateFromSlider() }
            }

            // ── Months ──
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Plazo")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(slate)
                    Spacer()
                    Text("\(vm.months) meses")
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundStyle(teal)
                        .contentTransition(.numericText())
                }

                // Chips
                HStack(spacing: 6) {
                    ForEach([12, 24, 36, 48, 60, 72], id: \.self) { m in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { vm.months = m }
                        } label: {
                            Text("\(m)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(vm.months == m ? .white : slate)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(vm.months == m ? teal : teal.opacity(0.08))
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule().stroke(vm.months == m ? teal : teal.opacity(0.2), lineWidth: 1)
                                )
                        }
                    }
                }

                Slider(
                    value: Binding(get: { Double(vm.months) }, set: { vm.months = Int($0) }),
                    in: 1...120, step: 1
                )
                .tint(teal)
            }

            // ── Date ──
            HStack {
                Text("Fecha de inicio")
                    .font(.subheadline)
                    .foregroundStyle(slate)
                Spacer()
                DatePicker("", selection: $vm.startDate, displayedComponents: .date)
                    .labelsHidden()
                    .tint(teal)
            }
            .padding(.horizontal, 4)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(cs == .dark ? 0.3 : 0.04), radius: 2, y: 2)
                .shadow(color: .black.opacity(cs == .dark ? 0.2 : 0.06), radius: 8, y: 6)
                .shadow(color: .black.opacity(cs == .dark ? 0.1 : 0.03), radius: 16, y: 12)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Payment Hero

    private var paymentHero: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 6) {
                Text("Cuota mensual fija")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))

                Text(vm.formattedDecimal(vm.monthlyPayment))
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)

            // Decorative icon
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 48))
                .foregroundStyle(.white.opacity(0.08))
                .offset(x: -12, y: -8)
        }
        .background(
            LinearGradient(colors: [teal, Color.fingetherPrimaryDark], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: teal.opacity(0.2), radius: 12, y: 6)
    }

    // MARK: - Summary

    private var summaryCard: some View {
        VStack(spacing: 12) {
            sRow("Total a pagar", vm.formattedDecimal(vm.totalPayment), Color(.label))
            Divider()
            sRow("Total intereses", vm.formattedDecimal(vm.totalInterest), coral)
            Divider()
            sRow("Monto solicitado", vm.formattedDecimal(vm.parsedAmount), teal)
            Divider()
            sRow("Intereses / Monto", "\(vm.interestPercentage)%", coral)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func sRow(_ label: String, _ value: String, _ color: Color) -> some View {
        HStack {
            Text(label).font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(color)
                .contentTransition(.numericText())
        }
    }

    // MARK: - Capital vs Interest Bar

    private var capitalBar: some View {
        VStack(spacing: 10) {
            GeometryReader { geo in
                HStack(spacing: 2) {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(teal)
                        .frame(width: max(geo.size.width * vm.capitalRatio, 4))
                    RoundedRectangle(cornerRadius: 5)
                        .fill(coral)
                }
            }
            .frame(height: 12)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            HStack {
                Label("Capital \(Int(vm.capitalRatio * 100))%", systemImage: "circle.fill")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(teal)
                Spacer()
                Label("Intereses \(100 - Int(vm.capitalRatio * 100))%", systemImage: "circle.fill")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(coral)
            }
            .labelStyle(.titleAndIcon)
            .imageScale(.small)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Details

    private var detailsCard: some View {
        VStack(spacing: 10) {
            dRow("dollarsign.circle", "Cuota mensual", vm.formattedDecimal(vm.monthlyPayment))
            dRow("calendar", "Primera cuota", firstDate)
            dRow("calendar.badge.checkmark", "Ultima cuota", lastDate)
            dRow("clock", "Plazo", "\(vm.months) meses")
            dRow("percent", "Tasa mensual", vm.monthlyRateFormatted)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func dRow(_ icon: String, _ label: String, _ value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.caption).foregroundStyle(teal).frame(width: 20)
            Text(label).font(.caption).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.system(.caption, design: .monospaced).weight(.semibold)).foregroundStyle(Color(.label))
        }
    }

    private var firstDate: String {
        (Calendar.current.date(byAdding: .month, value: 1, to: vm.startDate) ?? vm.startDate).formattedSpanishLong
    }
    private var lastDate: String { vm.lastPaymentDate.formattedSpanishLong }

    // MARK: - Chart

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Amortizacion")
                .font(.headline).foregroundStyle(Color(.label))

            let table = vm.amortizationTable
            if table.count > 1 {
                Chart {
                    ForEach(table) { row in
                        AreaMark(x: .value("Mes", row.id), y: .value("Capital", dv(row.capital)))
                            .foregroundStyle(teal.opacity(0.5))
                        AreaMark(x: .value("Mes", row.id), y: .value("Interes", dv(row.interest)))
                            .foregroundStyle(coral.opacity(0.35))
                    }
                    RuleMark(y: .value("Cuota", dv(vm.monthlyPayment)))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .foregroundStyle(slate.opacity(0.5))
                        .annotation(position: .top, alignment: .trailing) {
                            Text("Cuota fija")
                                .font(.system(size: 8))
                                .foregroundStyle(.secondary)
                        }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { val in
                        AxisValueLabel {
                            if let v = val.as(Double.self) { Text(compact(v)).font(.system(size: 9)) }
                        }
                    }
                }
                .chartXAxisLabel("Meses", alignment: .center)
                .frame(height: 200)
            }

            HStack(spacing: 16) {
                Label("Capital", systemImage: "circle.fill").font(.caption2).foregroundStyle(teal)
                Label("Intereses", systemImage: "circle.fill").font(.caption2).foregroundStyle(coral)
                Label("Cuota fija", systemImage: "line.diagonal").font(.caption2).foregroundStyle(slate)
            }
            .labelStyle(.titleAndIcon)
            .imageScale(.small)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Comparator

    private var comparatorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Compara plazos")
                .font(.headline).foregroundStyle(Color(.label))

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Plazo").frame(width: 44, alignment: .leading)
                    Text("Cuota").frame(maxWidth: .infinity, alignment: .trailing)
                    Text("Intereses").frame(maxWidth: .infinity, alignment: .trailing)
                    Text("Total").frame(maxWidth: .infinity, alignment: .trailing)
                }
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(teal.opacity(0.05))

                ForEach(vm.comparisons) { c in
                    let sel = c.months == vm.months
                    VStack(spacing: 6) {
                        HStack {
                            Text("\(c.months)m")
                                .font(.system(.caption, design: .monospaced).weight(.semibold))
                                .frame(width: 44, alignment: .leading)

                            Text(vm.formattedDecimal(c.monthlyPayment))
                                .font(.system(.caption, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .trailing)

                            VStack(alignment: .trailing, spacing: 1) {
                                Text(vm.formattedDecimal(c.totalInterest))
                                    .font(.system(.caption, design: .monospaced).weight(.medium))
                                    .foregroundStyle(coral)
                                if !sel && c.totalInterest > vm.totalInterest {
                                    Text("+\(vm.formattedDecimal(c.totalInterest - vm.totalInterest))")
                                        .font(.system(size: 9, design: .monospaced))
                                        .foregroundStyle(coral.opacity(0.6))
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .trailing)

                            Text(vm.formattedDecimal(c.totalPayment))
                                .font(.system(.caption, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }

                        if isCoupleMode {
                            comparatorCoupleSubrow(c)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(sel ? teal.opacity(0.06) : Color.clear)
                    .overlay(alignment: .leading) {
                        if sel {
                            Rectangle().fill(teal).frame(width: 3)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Amortization Table

    private var amortizationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.3)) { showTable.toggle() }
            } label: {
                HStack {
                    Image(systemName: "tablecells").foregroundStyle(teal)
                    Text("Tabla de amortizacion").font(.headline)
                    Spacer()
                    Image(systemName: showTable ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.bold)).foregroundStyle(teal)
                }
                .foregroundStyle(Color(.label))
            }

            if showTable {
                let mock = MockDataService.shared
                let n1Short = String(mock.currentUser1Name.prefix(6))
                let n2Short = String(mock.currentUser2Name.prefix(6))

                // Header
                HStack {
                    Text("#").frame(width: 28, alignment: .leading)
                    Text("Cuota").frame(maxWidth: .infinity, alignment: .trailing)
                    Text("Capital").frame(maxWidth: .infinity, alignment: .trailing)
                    Text("Interes").frame(maxWidth: .infinity, alignment: .trailing)
                    Text("Saldo").frame(maxWidth: .infinity, alignment: .trailing)
                    if isCoupleMode {
                        Text(n1Short).frame(maxWidth: .infinity, alignment: .trailing)
                        Text(n2Short).frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
                .font(.system(.caption2, design: .monospaced).weight(.bold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 8)
                .background(teal.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 8))

                LazyVStack(spacing: 0) {
                    ForEach(vm.amortizationTable) { row in
                        HStack {
                            Text("\(row.id)")
                                .frame(width: 28, alignment: .leading)
                            Text(compact(dv(row.payment)))
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            Text(compact(dv(row.capital)))
                                .foregroundStyle(teal)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            Text(compact(dv(row.interest)))
                                .foregroundStyle(coral)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            Text(compact(dv(row.balance)))
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            if isCoupleMode {
                                let split = vm.coupleSplitForRow(row)
                                Text(compact(dv(split.user1)))
                                    .foregroundStyle(rose)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                Text(compact(dv(split.user2)))
                                    .foregroundStyle(rose)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                        }
                        .font(.system(.caption2, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 6)
                        .background(row.id % 2 == 0 ? (cs == .dark ? Color.white.opacity(0.03) : cream.opacity(0.6)) : Color.clear)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Helpers

    private func dv(_ d: Decimal) -> Double {
        NSDecimalNumber(decimal: d).doubleValue
    }

    private func compact(_ v: Double) -> String {
        if v >= 1_000_000 { return String(format: "%.1fM", v / 1_000_000) }
        if v >= 1_000 { return String(format: "%.0fK", v / 1_000) }
        return "\(Int(v))"
    }

    // MARK: - Couple Split Card (only when isCoupleMode == true)

    private var coupleSplitCard: some View {
        let mock = MockDataService.shared
        let n1 = mock.currentUser1Name
        let n2 = mock.currentUser2Name
        let pcts = vm.coupleSplitPercents
        let monthly = vm.coupleMonthlyPayment
        let total = vm.coupleTotalPayment
        let interest = vm.coupleTotalInterest

        return VStack(spacing: 14) {
            // Header
            HStack(spacing: 8) {
                Text("💕")
                    .font(.title3)
                Text("\(n1) & \(n2)")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color(.label))
                Spacer()
                Text(splitTypeLabel)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(rose.opacity(0.18))
                    .foregroundStyle(Color(.label))
                    .clipShape(Capsule())
            }

            // Two-column split
            HStack(alignment: .top, spacing: 12) {
                personColumn(name: n1, pct: pcts.user1, monthly: monthly.user1, total: total.user1, interest: interest.user1)
                Rectangle()
                    .fill(rose.opacity(0.25))
                    .frame(width: 1)
                personColumn(name: n2, pct: pcts.user2, monthly: monthly.user2, total: total.user2, interest: interest.user2)
            }

            // Hint footer for proportional
            if case .proportional = vm.coupleSplitType {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle.fill")
                        .font(.caption2)
                    Text("Proporcional al ingreso de cada uno")
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(rose.opacity(0.45), lineWidth: 1.5)
        )
        .shadow(color: rose.opacity(cs == .dark ? 0.15 : 0.18), radius: 10, y: 4)
    }

    private func personColumn(name: String, pct: Int, monthly: Decimal, total: Decimal, interest: Decimal) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                Text(name)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(.label))
                    .lineLimit(1)
                Text("\(pct)%")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(teal)
            }

            Text(vm.formattedDecimal(monthly))
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(teal)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text("/ mes")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)

            VStack(spacing: 4) {
                miniRow(label: "Total", value: vm.formattedDecimal(total), color: Color(.label))
                miniRow(label: "Intereses", value: vm.formattedDecimal(interest), color: coral)
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
    }

    private func miniRow(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 1) {
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.system(.caption2, design: .monospaced).weight(.semibold))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
    }

    private var splitTypeLabel: String {
        switch vm.coupleSplitType {
        case .equal: return "50/50"
        case .proportional: return "Proporcional"
        case .custom(let pct): return "\(pct)/\(100 - pct)"
        case .onePays: return "Uno paga"
        }
    }

    // MARK: - Comparator: per-person sub-row (couple mode only)

    private func comparatorCoupleSubrow(_ plan: CreditSimulatorViewModel.PlanComparison) -> some View {
        let mock = MockDataService.shared
        let split = vm.coupleMonthlyForPlan(plan)
        return HStack(spacing: 6) {
            Image(systemName: "heart.fill")
                .font(.system(size: 8))
                .foregroundStyle(rose)

            HStack(spacing: 4) {
                Text(mock.currentUser1Name)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(vm.formattedDecimal(split.user1))
                    .foregroundStyle(teal)
            }
            .font(.system(size: 9, design: .monospaced))

            Text("·")
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)

            HStack(spacing: 4) {
                Text(mock.currentUser2Name)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(vm.formattedDecimal(split.user2))
                    .foregroundStyle(teal)
            }
            .font(.system(size: 9, design: .monospaced))

            Spacer(minLength: 0)
        }
        .padding(.leading, 44)
        .foregroundStyle(.secondary)
    }
}
