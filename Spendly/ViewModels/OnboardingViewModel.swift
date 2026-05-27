import Foundation
import UIKit

// MARK: - Country Selection

enum Country: String, CaseIterable, Identifiable {
    case colombia, mexico, argentina, chile, peru, brasil, espana, estadosUnidos, alemania, francia
    var id: String { rawValue }
    var flag: String {
        switch self {
        case .colombia: return "🇨🇴"; case .mexico: return "🇲🇽"; case .argentina: return "🇦🇷"
        case .chile: return "🇨🇱"; case .peru: return "🇵🇪"; case .brasil: return "🇧🇷"
        case .espana: return "🇪🇸"; case .estadosUnidos: return "🇺🇸"
        case .alemania: return "🇩🇪"; case .francia: return "🇫🇷"
        }
    }
    var displayName: String {
        switch self {
        case .colombia: return "Colombia"; case .mexico: return "México"; case .argentina: return "Argentina"
        case .chile: return "Chile"; case .peru: return "Perú"; case .brasil: return "Brasil"
        case .espana: return "España"; case .estadosUnidos: return "Estados Unidos"
        case .alemania: return "Alemania"; case .francia: return "Francia"
        }
    }
    var currency: AppPreferences.AppCurrency {
        switch self {
        case .colombia: return .cop; case .mexico: return .mxn; case .argentina: return .ars
        case .chile: return .clp; case .peru: return .pen; case .brasil: return .brl
        case .espana, .alemania, .francia: return .eur; case .estadosUnidos: return .usd
        }
    }
}

// MARK: - Fixed Expense Entry

struct FixedExpenseEntry: Identifiable {
    let id = UUID()
    var emoji: String
    var name: String
    var amount: String
    var category: TransactionCategory
    var parsedAmount: Decimal { parseAmountFromFormatted(amount) }
}

// MARK: - Suggested Item

struct SuggestedItem: Identifiable {
    let id = UUID()
    let emoji: String
    let name: String
    let category: TransactionCategory
}

// MARK: - Split Type Option

enum SplitTypeOption: String, CaseIterable, Identifiable {
    case equal, proportional, custom, onePays
    var id: String { rawValue }
    var displayName: String {
        switch self { case .equal: return "50/50"; case .proportional: return "Proporcional"
        case .custom: return "% Personalizado"; case .onePays: return "Uno paga" }
    }
    var emoji: String {
        switch self { case .equal: return "⚖️"; case .proportional: return "📊"
        case .custom: return "🔧"; case .onePays: return "💳" }
    }
    var subtitle: String {
        switch self { case .equal: return "Cada quien paga la mitad"; case .proportional: return "Según cuánto gana cada uno"
        case .custom: return "Tú decides el porcentaje"; case .onePays: return "Una persona cubre todo" }
    }
}

// MARK: - ViewModel

/// Couple (11 steps): welcome(0) name(1) country(2) coupleQ(3) income(4) partner(5) split(6) sharedFixed(7) personalFixed(8) budget(9) summary(10)
/// Solo   (8 steps):  welcome(0) name(1) country(2) coupleQ(3) income(4) personalFixed(5) budget(6) summary(7)
@MainActor
@Observable
final class OnboardingViewModel {

    var currentStep: Int = 0
    var isCompleting = false
    var errorMessage: String?

    // Step 1
    var displayName = ""

    // Step 2
    var selectedCountry: Country = .colombia
    var currency: AppPreferences.AppCurrency = .cop
    func selectCountry(_ c: Country) { selectedCountry = c; currency = c.currency }

    // Step 3
    var wantsCoupleMode = false
    var coupleChoiceMade = false

    // Step 4
    var monthlyIncome = ""

    // Step 5 (couple)
    var partnerName = ""
    var partnerIncome = ""
    var inviteCode = ""
    var isPartnerLinked = false

    // Step 6 (couple)
    var selectedSplit: SplitTypeOption = .equal
    var customPercent: Int = 60
    var onePayerIsUser1 = true

    // Steps 7-8 / 5: Fixed Expenses
    var fixedExpenses: [FixedExpenseEntry] = []
    var expandedChipId: UUID? = nil
    var showFreeForm = false
    var freeFormName = ""
    var freeFormAmount = ""
    var freeFormCategory: TransactionCategory = .other
    var freeFormEmoji = "📌"
    var sharedFlags: [UUID: Bool] = [:]

    // Shared fixed chips (couple step 7) — 15 chips + "Nuevo" handled in View
    let sharedSuggestions: [SuggestedItem] = [
        SuggestedItem(emoji: "🏠", name: "Arriendo", category: .housing),
        SuggestedItem(emoji: "💡", name: "Servicios", category: .utilities),
        SuggestedItem(emoji: "🌐", name: "Internet", category: .utilities),
        SuggestedItem(emoji: "📱", name: "Teléfono", category: .utilities),
        SuggestedItem(emoji: "🚗", name: "Transporte", category: .transport),
        SuggestedItem(emoji: "🛡️", name: "Seguro", category: .other),
        SuggestedItem(emoji: "📺", name: "Streaming", category: .entertainment),
        SuggestedItem(emoji: "💪", name: "Gym", category: .health),
        SuggestedItem(emoji: "🏦", name: "Deuda", category: .debt),
        SuggestedItem(emoji: "🍔", name: "Comida", category: .food),
        SuggestedItem(emoji: "🍻", name: "Salidas", category: .entertainment),
        SuggestedItem(emoji: "🎓", name: "Educación", category: .education),
        SuggestedItem(emoji: "💳", name: "Tarjeta", category: .debt),
        SuggestedItem(emoji: "🚘", name: "Carro", category: .debt),
        SuggestedItem(emoji: "📦", name: "Otros", category: .other),
    ]

    // Personal fixed chips (couple step 8 / solo step 5) — 15 chips + "Nuevo" handled in View
    let personalSuggestionsBase: [SuggestedItem] = [
        SuggestedItem(emoji: "📱", name: "Teléfono", category: .utilities),
        SuggestedItem(emoji: "🛡️", name: "Seguro", category: .other),
        SuggestedItem(emoji: "📺", name: "Streaming", category: .entertainment),
        SuggestedItem(emoji: "💪", name: "Gym", category: .health),
        SuggestedItem(emoji: "🎓", name: "Educación", category: .education),
        SuggestedItem(emoji: "💊", name: "Salud", category: .health),
        SuggestedItem(emoji: "🐕", name: "Mascota", category: .other),
        SuggestedItem(emoji: "🚗", name: "Transporte", category: .transport),
        SuggestedItem(emoji: "🏦", name: "Deuda", category: .debt),
        SuggestedItem(emoji: "🍔", name: "Comida", category: .food),
        SuggestedItem(emoji: "🍻", name: "Salidas", category: .entertainment),
        SuggestedItem(emoji: "💳", name: "Tarjeta", category: .debt),
        SuggestedItem(emoji: "🚘", name: "Carro", category: .debt),
        SuggestedItem(emoji: "👶", name: "Hijos", category: .other),
        SuggestedItem(emoji: "📦", name: "Otros", category: .other),
    ]

    /// Personal suggestions filtered: remove names already used as shared expenses
    var personalSuggestions: [SuggestedItem] {
        if !isCoupleFlow { return personalSuggestionsBase }
        let usedNames = Set(fixedExpenses.filter { sharedFlags[$0.id] == true }.map(\.name))
        return personalSuggestionsBase.filter { !usedNames.contains($0.name) }
    }

    // Step 9 (couple) / 6 (solo): Budget
    var budgetLimitEnabled = false
    var budgetLimitAmount = ""
    // Couple budget contribution
    var contributionByPercent = true
    var myContributionPercent: Int = 50
    var myContributionAmount = ""

    // MARK: - Dynamic Steps

    var totalSteps: Int { wantsCoupleMode ? 11 : 8 }
    var isCoupleFlow: Bool { wantsCoupleMode }
    var progress: Double { totalSteps > 1 ? Double(currentStep) / Double(totalSteps - 1) : 1 }
    var isFirstStep: Bool { currentStep == 0 }
    var isLastStep: Bool { currentStep == totalSteps - 1 }

    // MARK: - Computed Values

    var resolvedPartnerName: String {
        if let n = MockDataService.shared.mockPartnerProfile?.displayName, !n.isEmpty { return n }
        return partnerName
    }

    var parsedUserIncome: Decimal { parseAmountFromFormatted(monthlyIncome) }
    var parsedPartnerIncome: Decimal { parseAmountFromFormatted(partnerIncome) }
    var combinedIncome: Decimal { parsedUserIncome + parsedPartnerIncome }
    var totalFixedExpenses: Decimal { fixedExpenses.reduce(Decimal.zero) { $0 + $1.parsedAmount } }

    var sharedExpenses: [FixedExpenseEntry] { fixedExpenses.filter { sharedFlags[$0.id] == true } }
    var personalExpenses: [FixedExpenseEntry] { fixedExpenses.filter { sharedFlags[$0.id] != true } }
    var totalSharedExpenses: Decimal { sharedExpenses.reduce(Decimal.zero) { $0 + $1.parsedAmount } }
    var totalPersonalExpenses: Decimal { personalExpenses.reduce(Decimal.zero) { $0 + $1.parsedAmount } }

    var availableBudget: Decimal {
        let inc = isCoupleFlow ? combinedIncome : parsedUserIncome
        return max(0, inc - totalFixedExpenses)
    }

    var parsedBudgetLimit: Decimal { parseAmountFromFormatted(budgetLimitAmount) }

    // Couple budget contribution
    var myContribution: Decimal {
        if contributionByPercent {
            return parsedUserIncome * Decimal(myContributionPercent) / 100
        }
        return parseAmountFromFormatted(myContributionAmount)
    }

    var partnerContribution: Decimal {
        max(0, totalSharedExpenses - myContribution)
    }

    var contributionSurplus: Decimal {
        myContribution - totalSharedExpenses + partnerContribution
        // Simplified: myContribution + partnerContribution - totalSharedExpenses
        // Since partnerContribution = max(0, total - my), surplus = max(0, my - total)
    }

    var contributionCoversShared: Bool {
        myContribution + partnerContribution >= totalSharedExpenses
    }

    var myContributionPctOfIncome: Int {
        guard parsedUserIncome > 0 else { return 0 }
        return Int(NSDecimalNumber(decimal: myContribution / parsedUserIncome * 100).doubleValue.rounded())
    }

    var partnerContributionPctOfIncome: Int {
        guard parsedPartnerIncome > 0 else { return 0 }
        return Int(NSDecimalNumber(decimal: partnerContribution / parsedPartnerIncome * 100).doubleValue.rounded())
    }

    // MARK: - Split Preview

    func splitPreview(for total: Decimal) -> (Decimal, Decimal) {
        switch selectedSplit {
        case .equal: let h = total / 2; return (h, h)
        case .proportional:
            guard combinedIncome > 0 else { return (total / 2, total / 2) }
            let u1 = total * parsedUserIncome / combinedIncome; return (u1, total - u1)
        case .custom:
            let u1 = total * Decimal(customPercent) / 100; return (u1, total - u1)
        case .onePays: return onePayerIsUser1 ? (total, 0) : (0, total)
        }
    }

    var user1Pct: Int {
        switch selectedSplit {
        case .equal: return 50
        case .proportional:
            guard combinedIncome > 0 else { return 50 }
            return Int(NSDecimalNumber(decimal: parsedUserIncome / combinedIncome * 100).doubleValue.rounded())
        case .custom: return customPercent
        case .onePays: return onePayerIsUser1 ? 100 : 0
        }
    }
    var user2Pct: Int { 100 - user1Pct }

    // MARK: - Can Advance

    var canAdvance: Bool {
        switch currentStep {
        case 1: return !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case 4: return parsedUserIncome > 0
        case 5 where isCoupleFlow: return canSetupPartner
        default: return true
        }
    }

    // MARK: - Partner

    var canSetupPartner: Bool {
        !partnerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && parseAmountFromFormatted(partnerIncome) > 0
    }

    func setupPartnerAndContinue() {
        let n = partnerName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !n.isEmpty else { errorMessage = "Ingresa el nombre de tu pareja."; return }
        let inc = parseAmountFromFormatted(partnerIncome)
        guard inc > 0 else { errorMessage = "Ingresa el ingreso mensual de tu pareja."; return }
        MockDataService.shared.createPhantomPartner(name: n, monthlyIncome: inc, gender: "other")
        inviteCode = MockDataService.shared.regenerateInviteCode()
        isPartnerLinked = true; errorMessage = nil
        currentStep = 6 // split
    }

    // MARK: - Navigation

    func nextStep() {
        guard validateCurrentStep() else { return }
        errorMessage = nil
        if currentStep < totalSteps - 1 { currentStep += 1 }
    }

    func previousStep() {
        errorMessage = nil
        if currentStep == 4 {
            if isCoupleFlow { wantsCoupleMode = false }
            coupleChoiceMade = false; currentStep = 3; return
        }
        if currentStep > 0 { currentStep -= 1 }
    }

    func chooseCoupleMode() { wantsCoupleMode = true; coupleChoiceMade = true; errorMessage = nil; currentStep = 4 }
    func chooseSoloMode() { wantsCoupleMode = false; coupleChoiceMade = true; errorMessage = nil; currentStep = 4 }

    // MARK: - Invite Code

    var formattedInviteCode: String {
        guard inviteCode.count == 6 else { return inviteCode }
        return "\(inviteCode.prefix(3)) \(inviteCode.suffix(3))"
    }
    func copyInviteCode() { UIPasteboard.general.string = inviteCode; UIImpactFeedbackGenerator(style: .medium).impactOccurred() }

    // MARK: - Fixed Expense Management

    func selectExpenseSuggestion(_ s: SuggestedItem) {
        if expandedChipId == s.id { expandedChipId = nil }
        else { expandedChipId = s.id; freeFormEmoji = s.emoji; freeFormName = s.name; freeFormCategory = s.category; freeFormAmount = ""; showFreeForm = false }
    }

    func addExpenseFromChip(forceShared: Bool? = nil) {
        let name = freeFormName.trimmingCharacters(in: .whitespacesAndNewlines)
        let amt = parseAmountFromFormatted(freeFormAmount)
        guard !name.isEmpty else { errorMessage = "Ingresa el nombre del gasto."; return }
        guard amt > 0 else { errorMessage = "Ingresa un monto válido."; return }
        let entry = FixedExpenseEntry(emoji: freeFormEmoji, name: name, amount: freeFormAmount, category: freeFormCategory)
        fixedExpenses.append(entry)
        if let s = forceShared { sharedFlags[entry.id] = s }
        freeFormEmoji = "📌"; freeFormName = ""; freeFormAmount = ""; freeFormCategory = .other
        expandedChipId = nil; showFreeForm = false; errorMessage = nil
    }

    func removeFixedExpense(_ e: FixedExpenseEntry) { fixedExpenses.removeAll { $0.id == e.id }; sharedFlags.removeValue(forKey: e.id) }
    func openFreeForm() { showFreeForm = true; expandedChipId = nil; freeFormName = ""; freeFormAmount = ""; freeFormCategory = .other; freeFormEmoji = "📌" }
    func closeFreeForm() { showFreeForm = false }

    // MARK: - Complete Onboarding

    func completeOnboarding(userId: UUID) async {
        guard validateAllSteps() else { return }
        isCompleting = true; errorMessage = nil; defer { isCompleting = false }
        let parsedIncome = parseAmountFromFormatted(monthlyIncome)
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let mock = MockDataService.shared

        if mock.isEnabled {
            let devUserId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
            let coupleUUID = UUID(uuidString: "00000000-0000-0000-0000-000000000010")!
            mock.completeOnboarding(displayName: trimmedName, monthlyIncome: parsedIncome, currency: currency.rawValue)
            AppPreferences.shared.currency = currency

            if !isCoupleFlow && budgetLimitEnabled && parsedBudgetLimit > 0 {
                mock.budgetLimitEnabled = true; mock.userBudgetLimit = parsedBudgetLimit
            }

            let now = Date()
            _ = mock.addMockTransaction(Transaction(id: UUID(), userId: devUserId, coupleId: coupleUUID,
                type: .income, category: .salary, amount: parsedIncome, description: "Salario", notes: nil, date: now,
                isRecurring: true, recurringFrequency: .monthly, isShared: false, createdAt: now, updatedAt: now))

            for expense in fixedExpenses {
                let isShared = sharedFlags[expense.id] == true && isCoupleFlow
                var st: SplitType? = nil; var s1: Decimal? = nil; var s2: Decimal? = nil
                if isShared { st = resolvedSplitType(); let (a, b) = splitPreview(for: expense.parsedAmount); s1 = a; s2 = b }
                _ = mock.addMockTransaction(Transaction(id: UUID(), userId: devUserId, coupleId: coupleUUID,
                    type: .expense, category: expense.category, amount: expense.parsedAmount,
                    description: "\(expense.emoji) \(expense.name)", notes: nil, date: now,
                    isRecurring: true, recurringFrequency: .monthly, isShared: isShared, splitType: st,
                    splitUser1Amount: s1, splitUser2Amount: s2, createdAt: now, updatedAt: now))
            }

            if isCoupleFlow {
                AppPreferences.shared.isCoupleMode = true
                let pp = parseAmountFromFormatted(partnerIncome)
                if pp > 0 { mock.mockPartnerProfile?.monthlyIncome = pp; mock.mockCouple?.user2Income = pp; mock.mockCouple?.combinedMonthlyIncome = parsedIncome + pp }
                mock.updateMockCoupleSettings(CoupleSettings(defaultSplitType: resolvedSplitType(), categorySplits: [:]))
                if pp > 0, let pid = mock.mockPartnerProfile?.id {
                    _ = mock.addMockTransaction(Transaction(id: UUID(), userId: pid, coupleId: coupleUUID,
                        type: .income, category: .salary, amount: pp, description: "Ingreso de \(resolvedPartnerName)", notes: nil, date: now,
                        isRecurring: true, recurringFrequency: .monthly, isShared: false, splitType: nil, createdAt: now, updatedAt: now))
                }
            } else { AppPreferences.shared.isCoupleMode = false }
            mock.saveAll()
        } else {
            do {
                try await AuthService.updateProfile(displayName: trimmedName, monthlyIncome: parsedIncome, currency: currency.rawValue, onboardingCompleted: true)
                AppPreferences.shared.currency = currency; _ = userId
            } catch { errorMessage = "No se pudo completar la configuración. Intenta de nuevo." }
        }
    }

    // MARK: - Helpers

    private func resolvedSplitType() -> SplitType {
        let uid = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        switch selectedSplit {
        case .equal: return .equal; case .proportional: return .proportional; case .custom: return .custom(customPercent)
        case .onePays: return .onePays(onePayerIsUser1 ? uid : UUID(uuidString: "00000000-0000-0000-0000-000000000002")!)
        }
    }

    func currencySymbol() -> String { currency.symbol }
    func formattedAmount(_ t: String) -> String { let f = formatWithThousands(t); return f.isEmpty ? "\(currencySymbol())0" : "\(currencySymbol())\(f)" }
    func formattedDecimal(_ v: Decimal) -> String { "\(currencySymbol())\(formatWithThousands("\(Int(NSDecimalNumber(decimal: v).doubleValue.rounded()))"))" }

    // MARK: - Validation

    func validateCurrentStep() -> Bool {
        errorMessage = nil
        switch currentStep {
        case 1:
            if displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { errorMessage = "Por favor ingresa tu nombre."; return false }
            return true
        case 4:
            if parseAmountFromFormatted(monthlyIncome) <= 0 { errorMessage = "El ingreso mensual debe ser mayor a cero."; return false }
            return true
        default: return true
        }
    }

    private func validateAllSteps() -> Bool {
        if displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { errorMessage = "El nombre es obligatorio."; return false }
        if parseAmountFromFormatted(monthlyIncome) <= 0 { errorMessage = "El ingreso mensual debe ser mayor a cero."; return false }
        if isCoupleFlow && parseAmountFromFormatted(partnerIncome) <= 0 { errorMessage = "El ingreso de tu pareja debe ser mayor a cero."; return false }
        return true
    }
}
