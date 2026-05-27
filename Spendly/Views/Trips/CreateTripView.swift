import SwiftUI

// MARK: - Date Selection State

private enum DateSelectionStep {
    case selectingStart
    case selectingEnd
}

struct CreateTripView: View {
    let coupleId: UUID
    @Bindable var viewModel: TripViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var preferences = AppPreferences.shared
    private var lang: AppLanguage { preferences.language }
    @State private var selectedEmojiIndex = 0
    @State private var dateSelectionStep: DateSelectionStep = .selectingEnd
    @State private var displayedMonth: Date = Date()
    @State private var showAddCategory = false
    @State private var newCategoryName = ""
    @State private var newCategoryEmoji = "📌"
    @State private var categoryAmountStrings: [UUID: String] = [:]

    private let emojiOptions = ["✈️", "🏖️", "🏔️", "🗼", "🚗", "🛳️", "🏕️", "🎡", "🌴", "🏙️", "🎿", "🏝️"]
    private let categoryEmojiOptions = ["📌", "🎉", "💊", "📸", "🎁", "🧳", "🎶", "⛽", "🏋️", "🍺"]

    private let teal = Color.fingetherPrimary
    private let coral = Color.fingetherExpense
    private let calendar = Calendar.current
    private let weekdaySymbols = ["L", "M", "M", "J", "V", "S", "D"]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    private var isCoupleAvailable: Bool {
        AppPreferences.shared.isCoupleMode && MockDataService.shared.mockPartnerProfile != nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 1. Emoji + Name
                    nameSection

                    // 2. Destination
                    destinationSection

                    // 3. Dates
                    datesSection

                    // 4. Individual / Pareja toggle
                    if isCoupleAvailable {
                        sharedToggleSection
                    }

                    // 5. Categories with editable budget
                    categoriesSection

                    // 6. Total budget (read-only)
                    totalBudgetSection

                    // 7. Savings mode
                    savingsModeSection

                    // 8. Split preview (if shared)
                    if viewModel.formIsShared {
                        splitPreviewSection
                    }

                    // Error
                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(coral)
                            .padding(.horizontal)
                    }

                    // 9. Create button
                    Button {
                        Task {
                            viewModel.formEmoji = emojiOptions[selectedEmojiIndex]
                            await viewModel.createTrip(coupleId: coupleId)
                            if viewModel.errorMessage == nil {
                                dismiss()
                            }
                        }
                    } label: {
                        if viewModel.isLoading {
                            ProgressView()
                                .tint(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(teal.opacity(0.6), in: RoundedRectangle(cornerRadius: 14))
                        } else {
                            Text(L10n.t("trip_create", lang))
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(teal, in: RoundedRectangle(cornerRadius: 14))
                        }
                    }
                    .disabled(viewModel.isLoading)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle(L10n.t("trip_new", lang))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L10n.t("cancel", lang)) { dismiss() }
                        .foregroundStyle(teal)
                }
            }
            .onAppear {
                initCategoryAmountStrings()
            }
        }
    }

    // MARK: - 1. Name Section

    private var nameSection: some View {
        VStack(spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(emojiOptions.indices, id: \.self) { idx in
                        Text(emojiOptions[idx])
                            .font(.system(size: 32))
                            .padding(8)
                            .background(
                                selectedEmojiIndex == idx
                                    ? teal.opacity(0.2)
                                    : Color.clear
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .onTapGesture { selectedEmojiIndex = idx }
                    }
                }
                .padding(.horizontal, 16)
            }

            TextField(L10n.t("trip_name_placeholder", lang), text: $viewModel.formName)
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .multilineTextAlignment(.center)
                .padding(14)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 16)
        }
        .padding(.top, 8)
    }

    // MARK: - 2. Destination

    private var destinationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.t("trip_destination", lang))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)

            HStack(spacing: 10) {
                Image(systemName: "mappin.and.ellipse")
                    .foregroundStyle(coral)
                TextField(L10n.t("trip_destination_placeholder", lang), text: $viewModel.formDestination)
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 16)
        }
    }

    // MARK: - 3. Dates (Inline Calendar)

    private var datesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.t("trip_dates", lang))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)

            VStack(spacing: 12) {
                monthNavigationHeader
                weekdayHeaderRow
                dayGrid
                dateSummaryRow
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 16)
        }
    }

    private var monthNavigationHeader: some View {
        HStack {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    displayedMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(teal)
                    .frame(width: 36, height: 36)
            }

            Spacer()

            Text(monthYearString(from: displayedMonth))
                .font(.system(.headline, design: .rounded))

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    displayedMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(teal)
                    .frame(width: 36, height: 36)
            }
        }
    }

    private var weekdayHeaderRow: some View {
        LazyVGrid(columns: columns, spacing: 0) {
            ForEach(weekdaySymbols.indices, id: \.self) { idx in
                Text(weekdaySymbols[idx])
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(height: 30)
            }
        }
    }

    private var dayGrid: some View {
        let days = daysForMonth(displayedMonth)
        return LazyVGrid(columns: columns, spacing: 4) {
            ForEach(days, id: \.self) { date in
                if let date = date {
                    dayCell(for: date)
                } else {
                    Color.clear.frame(width: 40, height: 40)
                }
            }
        }
    }

    private func dayCell(for date: Date) -> some View {
        let isStart = calendar.isDate(date, inSameDayAs: viewModel.formStartDate)
        let isEnd = calendar.isDate(date, inSameDayAs: viewModel.formEndDate)
        let isInRange = date > viewModel.formStartDate && date < viewModel.formEndDate
        let isToday = calendar.isDateInToday(date)
        let isPast = date < calendar.startOfDay(for: Date())

        return Button {
            handleDateTap(date)
        } label: {
            Text("\(calendar.component(.day, from: date))")
                .font(.system(.body, design: .rounded).weight(isStart || isEnd ? .bold : .regular))
                .foregroundStyle(
                    isStart || isEnd ? .white :
                    isPast ? Color.primary.opacity(0.35) :
                    Color.primary
                )
                .frame(width: 40, height: 40)
                .background {
                    if isStart || isEnd {
                        Circle().fill(teal)
                    } else if isInRange {
                        Circle().fill(teal.opacity(0.15))
                    } else if isToday {
                        Circle().strokeBorder(teal.opacity(0.5), lineWidth: 1.5)
                    }
                }
        }
    }

    private var dateSummaryRow: some View {
        let days = calendar.dateComponents([.day], from: viewModel.formStartDate, to: viewModel.formEndDate).day ?? 0
        let startStr = shortDateString(viewModel.formStartDate)
        let endStr = shortDateString(viewModel.formEndDate)

        return HStack(spacing: 6) {
            Text("\u{1F4C5}")
            Text("\(startStr) \u{2192} \(endStr) (\(days) \(days == 1 ? L10n.t("trip_day", lang) : L10n.t("trip_days", lang)))")
                .font(.system(.subheadline, design: .rounded).weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    // MARK: - 4. Shared Toggle

    private var sharedToggleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.t("trip_type", lang))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)

            HStack(spacing: 0) {
                sharedToggleButton(title: L10n.t("trip_individual", lang), icon: "person.fill", isSelected: !viewModel.formIsShared) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.formIsShared = false
                    }
                }

                sharedToggleButton(title: L10n.t("trip_couple", lang), icon: "heart.fill", isSelected: viewModel.formIsShared) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.formIsShared = true
                    }
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 16)
        }
    }

    private func sharedToggleButton(title: String, icon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.subheadline)
                Text(title)
                    .font(.subheadline.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(isSelected ? teal.opacity(0.15) : Color.clear)
            .foregroundStyle(isSelected ? teal : .secondary)
        }
    }

    // MARK: - 5. Categories

    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L10n.t("trip_categories", lang))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    showAddCategory = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                        Text(L10n.t("trip_add", lang))
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(teal)
                }
            }
            .padding(.horizontal, 20)

            VStack(spacing: 0) {
                ForEach(viewModel.formCategories.indices, id: \.self) { idx in
                    if idx > 0 {
                        Divider().padding(.horizontal, 14)
                    }
                    categoryRow(index: idx)
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 16)
        }
        .alert(L10n.t("trip_new_category", lang), isPresented: $showAddCategory) {
            TextField("Nombre", text: $newCategoryName)

            Button(L10n.t("cancel", lang), role: .cancel) {
                newCategoryName = ""
                newCategoryEmoji = "📌"
            }
            Button(L10n.t("trip_add", lang)) {
                let name = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !name.isEmpty {
                    viewModel.addCustomCategory(name: name, emoji: newCategoryEmoji)
                    initCategoryAmountStrings()
                }
                newCategoryName = ""
                newCategoryEmoji = "📌"
            }
        } message: {
            Text(L10n.t("trip_category_prompt", lang))
        }
    }

    private func categoryRow(index: Int) -> some View {
        let category = viewModel.formCategories[index]
        let catId = category.id
        return HStack(spacing: 10) {
            Text(category.emoji)
                .font(.title3)

            Text(category.name)
                .font(.subheadline)
                .lineLimit(1)

            Spacer()

            HStack(spacing: 2) {
                Text("$")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(.secondary)

                TextField("0", text: Binding<String>(
                    get: { categoryAmountStrings[catId] ?? "" },
                    set: { newValue in
                        let formatted = formatWithThousands(newValue)
                        categoryAmountStrings[catId] = formatted
                        let parsed = parseAmountFromFormatted(formatted)
                        viewModel.updateCategoryBudget(at: index, amount: parsed)
                    }
                ))
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 90)
            }

            if viewModel.formCategories.count > 1 {
                Button {
                    viewModel.removeCategory(at: index)
                    categoryAmountStrings.removeValue(forKey: catId)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.body)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: - 6. Total Budget (Read-Only)

    private var totalBudgetSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.t("trip_total_budget", lang))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)

            HStack {
                Text("Total")
                    .font(.system(.body, design: .rounded).weight(.medium))
                    .foregroundStyle(.secondary)

                Spacer()

                Text(viewModel.formTotalBudget.currencyFormatted)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(viewModel.formTotalBudget > 0 ? teal : .secondary)
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 16)
        }
    }

    // MARK: - 7. Savings Mode

    private var savingsModeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.t("trip_savings_mode", lang))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)

            HStack(spacing: 10) {
                savingsModeCard(
                    mode: .monthly,
                    icon: "calendar.badge.clock",
                    title: L10n.t("trip_monthly", lang),
                    subtitle: L10n.t("trip_monthly_fixed", lang)
                )
                savingsModeCard(
                    mode: .freeForm,
                    icon: "hand.point.up.left.fill",
                    title: L10n.t("trip_free", lang),
                    subtitle: L10n.t("trip_free_manual", lang)
                )
                savingsModeCard(
                    mode: .alreadyHave,
                    icon: "checkmark.seal.fill",
                    title: L10n.t("trip_already_have", lang),
                    subtitle: L10n.t("trip_money_ready", lang)
                )
            }
            .padding(.horizontal, 16)

            if viewModel.formSavingsMode == .monthly {
                monthlySavingsInput
            }
        }
    }

    private func savingsModeCard(mode: TripSavingsMode, icon: String, title: String, subtitle: String) -> some View {
        let isSelected = viewModel.formSavingsMode == mode
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.formSavingsMode = mode
            }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title3)
                Text(title)
                    .font(.caption.weight(.bold))
                Text(subtitle)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(isSelected ? teal.opacity(0.12) : Color(.secondarySystemGroupedBackground))
            .foregroundStyle(isSelected ? teal : .secondary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isSelected ? teal : Color.clear, lineWidth: 2)
            )
        }
    }

    private var monthlySavingsInput: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                Text("$")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(teal)

                TextField(L10n.t("trip_monthly_contribution", lang), text: $viewModel.formMonthlySavings)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .keyboardType(.numberPad)
                    .onChange(of: viewModel.formMonthlySavings) { _, newValue in
                        viewModel.formMonthlySavings = formatWithThousands(newValue)
                    }

                Spacer()

                let suggestion = viewModel.suggestMonthlySavings()
                if suggestion > 0 && viewModel.formMonthlySavings.isEmpty {
                    Button {
                        viewModel.formMonthlySavings = formatWithThousands("\(Int(NSDecimalNumber(decimal: suggestion).doubleValue.rounded()))")
                    } label: {
                        Text(L10n.t("trip_suggested", lang))
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(teal.opacity(0.15))
                            .foregroundStyle(teal)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 16)

            if let months = viewModel.formEstimatedMonths {
                let monthlySavingsFormatted = viewModel.formParsedMonthlySavings.currencyFormatted
                HStack(spacing: 4) {
                    Image(systemName: "info.circle.fill")
                        .font(.caption)
                        .foregroundStyle(teal)
                    Text(String(format: L10n.t("trip_monthly_estimate", lang), monthlySavingsFormatted, months, months == 1 ? L10n.t("trip_month_singular", lang) : L10n.t("trip_months_plural", lang)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - 8. Split Preview

    private var splitPreviewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.t("trip_split_couple", lang))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)

            let mock = MockDataService.shared
            let settings = mock.coupleSettings
            let totalBudget = viewModel.formTotalBudget
            let userName = mock.mockProfile?.displayName ?? "Tu"
            let partnerName = mock.mockPartnerProfile?.displayName ?? "Pareja"

            let splits = computeSplits(total: totalBudget, splitType: settings.defaultSplitType)

            VStack(spacing: 10) {
                splitRow(name: userName, amount: splits.user1, color: teal)
                splitRow(name: partnerName, amount: splits.user2, color: coral)

                Divider()

                HStack {
                    Text(L10n.t("trip_type_label", lang))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(splitTypeLabel(settings.defaultSplitType))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 16)
        }
    }

    private func splitRow(name: String, amount: Decimal, color: Color) -> some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(name)
                .font(.subheadline)
            Spacer()
            Text(amount.currencyFormatted)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
        }
    }

    private func computeSplits(total: Decimal, splitType: SplitType) -> (user1: Decimal, user2: Decimal) {
        let mock = MockDataService.shared
        let userId = mock.getMockProfile().id

        switch splitType {
        case .equal:
            return (total / 2, total / 2)
        case .proportional:
            let income1 = mock.mockCouple?.user1Income ?? Decimal.zero
            let income2 = mock.mockCouple?.user2Income ?? Decimal.zero
            let incomeTotal = income1 + income2
            if incomeTotal > 0 {
                return (total * income1 / incomeTotal, total * income2 / incomeTotal)
            }
            return (total / 2, total / 2)
        case .custom(let pct):
            return (total * Decimal(pct) / 100, total * Decimal(100 - pct) / 100)
        case .onePays(let payerId):
            if payerId == userId {
                return (total, 0)
            } else {
                return (0, total)
            }
        }
    }

    private func splitTypeLabel(_ type: SplitType) -> String {
        switch type {
        case .equal: return "50/50"
        case .proportional: return L10n.t("trip_split_proportional", lang)
        case .custom(let pct): return "\(pct)% / \(100 - pct)%"
        case .onePays: return L10n.t("trip_split_one_pays", lang)
        }
    }

    // MARK: - Calendar Helpers

    private func handleDateTap(_ date: Date) {
        switch dateSelectionStep {
        case .selectingStart:
            viewModel.formStartDate = date
            if date >= viewModel.formEndDate {
                viewModel.formEndDate = calendar.date(byAdding: .day, value: 1, to: date) ?? date
            }
            dateSelectionStep = .selectingEnd
        case .selectingEnd:
            if date <= viewModel.formStartDate {
                viewModel.formStartDate = date
                dateSelectionStep = .selectingEnd
            } else {
                viewModel.formEndDate = date
                dateSelectionStep = .selectingStart
            }
        }
    }

    private func daysForMonth(_ monthDate: Date) -> [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: monthDate),
              let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: monthDate))
        else { return [] }

        let firstWeekday = calendar.component(.weekday, from: firstOfMonth)
        let offset = (firstWeekday + 5) % 7

        var days: [Date?] = Array(repeating: nil, count: offset)

        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth) {
                days.append(date)
            }
        }

        while days.count % 7 != 0 {
            days.append(nil)
        }

        return days
    }

    private func monthYearString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_MX")
        formatter.dateFormat = "MMMM yyyy"
        let result = formatter.string(from: date)
        return result.prefix(1).uppercased() + result.dropFirst()
    }

    private func shortDateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_MX")
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date)
    }

    // MARK: - Amount String Helpers

    private func initCategoryAmountStrings() {
        for cat in viewModel.formCategories {
            if categoryAmountStrings[cat.id] == nil {
                if cat.budgetAmount > 0 {
                    categoryAmountStrings[cat.id] = formatWithThousands("\(Int(NSDecimalNumber(decimal: cat.budgetAmount).doubleValue.rounded()))")
                } else {
                    categoryAmountStrings[cat.id] = ""
                }
            }
        }
    }
}
