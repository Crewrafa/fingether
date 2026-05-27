import Foundation

// MARK: - Mock Data Service

/// Servicio singleton que provee datos mock para desarrollo sin backend.
/// Se activa con `MockDataService.shared.isEnabled = true` desde enterDevMode().
@Observable
final class MockDataService: @unchecked Sendable {

    static let shared = MockDataService()

    var isEnabled = false

    // MARK: - Consistent UUIDs

    private let devUserId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    private let partnerUserId = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    private let coupleUUID = UUID(uuidString: "00000000-0000-0000-0000-000000000010")!

    // MARK: - Mutable Mock State

    var mockProfile: Profile!
    var mockPartnerProfile: Profile!
    var mockCouple: Couple!
    var mockTransactions: [Transaction] = []
    var mockBudgets: [Budget] = []
    var mockSavingsGoals: [SavingsGoal] = []
    var mockPetState: PetState!
    var mockAchievements: [Achievement] = []
    var mockNotifications: [AppNotification] = []
    var mockInsights: [InsightCache] = []
    var mockDebts: [Debt] = []
    var coupleSettings: CoupleSettings = .defaultSettings
    var mockTrips: [Trip] = []
    var mockTripExpenses: [TripExpense] = []
    var mockChallenges: [FinancialChallenge] = []
    var mockSimulations: [Simulation] = []
    var mockScoreHistory: [FinancialScore] = []

    /// Suscripciones persistidas localmente. Bug fix #3 — antes el resultado de
    /// SubscriptionViewModel.purchase() solo cambiaba estado en memoria del VM
    /// y se perdia entre lanzamientos.
    var mockSubscriptions: [Subscription] = []

    /// Bug fix #5: las marcas "pagado" del checklist de gastos fijos viven aqui
    /// en vez de un @State local de FixedExpensesView, asi sobreviven al cierre de la vista.
    /// Cada key tiene la forma "txId-yyyy-MM" para distinguir mes a mes.
    var paidFixedKeys: Set<String> = []

    // MARK: - Smart Budget (v1.4)

    /// Optional user-chosen spending limit. nil = no limit (use calculated available).
    var userBudgetLimit: Decimal? = nil
    /// Whether the user has enabled a custom spending limit.
    var budgetLimitEnabled: Bool = false

    // MARK: - Analytics (C9)

    /// Internal event log for analytics. Future: send to Mixpanel/Amplitude.
    var mockAnalyticsEvents: [AnalyticsEntry] = []

    /// Record an analytics event. Keeps last 500 entries to avoid unbounded growth.
    func trackEvent(_ entry: AnalyticsEntry) {
        mockAnalyticsEvents.append(entry)
        if mockAnalyticsEvents.count > 500 {
            mockAnalyticsEvents = Array(mockAnalyticsEvents.suffix(500))
        }
        // Don't call saveAll() here — analytics are fire-and-forget and saving on
        // every event would be wasteful. They persist on the next mutator call.
    }

    // MARK: - Free-tier usage counters (P6 v1.2.1)

    /// Insights generados este mes en plan free. Se resetea automáticamente al cambiar de mes.
    /// Free tier limit = 3/mes. Premium = ilimitado.
    var insightsUsedThisMonth: Int = 0
    /// Mes (yyyy-MM) cuando se incrementó por última vez insightsUsedThisMonth.
    var insightsCounterMonth: String = ""

    /// Consume un slot de insights. Retorna true si el usuario puede generar
    /// (premium siempre, free hasta 3/mes). Si retorna false, mostrar paywall.
    func tryConsumeInsightSlot() -> Bool {
        let isPremium = mockProfile?.subscriptionTier == .premium
        if isPremium { return true }
        let now = Date()
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM"
        let currentMonth = fmt.string(from: now)
        if insightsCounterMonth != currentMonth {
            insightsCounterMonth = currentMonth
            insightsUsedThisMonth = 0
        }
        guard insightsUsedThisMonth < Constants.FreeTierLimits.monthlyInsights else { return false }
        insightsUsedThisMonth += 1
        saveAll()
        return true
    }

    /// Cuántos insights free quedan este mes (3 - usados, mín 0).
    var insightsRemainingThisMonth: Int {
        let now = Date()
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM"
        let currentMonth = fmt.string(from: now)
        let limit = Constants.FreeTierLimits.monthlyInsights
        if insightsCounterMonth != currentMonth { return limit }
        return max(0, limit - insightsUsedThisMonth)
    }

    // MARK: - Init

    private init() {
        // P3: persistencia local. Intentamos cargar el estado desde UserDefaults.
        // Si no hay nada guardado, dejamos los arrays vacios — el seeding solo ocurre
        // cuando enterDevMode() lo activa explicitamente con seedAllData().
        loadFromDefaults()
    }

    // MARK: - Persistence (P3)
    //
    // ⚠️ PRODUCTION: Esta capa de persistencia usa UserDefaults para datos
    // financieros (transactions, debts, savings, etc.). UserDefaults NO está
    // cifrado y NO debería usarse para datos sensibles en producción real.
    //
    // Migración recomendada para producción:
    //   - Core Data con NSFileProtectionComplete (cifrado en reposo, requiere
    //     que el dispositivo esté desbloqueado), o
    //   - Keychain para tokens/credenciales pequeñas, o
    //   - SQLCipher para una base relacional cifrada.
    //
    // Mientras se trabaje contra MockDataService (sin Supabase real), UserDefaults
    // es aceptable porque toda la data es ficticia/dev.

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private static let keyPrefix = "fingether_"

    /// Guarda un valor Codable bajo "fingether_<key>". Errores se silencian
    /// (no es critico — la operacion sigue funcionando en memoria).
    private func save<T: Codable>(_ value: T, key: String) {
        if let data = try? encoder.encode(value) {
            UserDefaults.standard.set(data, forKey: Self.keyPrefix + key)
        }
    }

    /// Carga un valor Codable desde "fingether_<key>". Retorna nil si no existe o falla decode.
    private func load<T: Codable>(key: String, type: T.Type) -> T? {
        guard let data = UserDefaults.standard.data(forKey: Self.keyPrefix + key) else { return nil }
        return try? decoder.decode(type, from: data)
    }

    /// Carga todo el estado desde UserDefaults. Llamado en init().
    private func loadFromDefaults() {
        if let p = load(key: "profile", type: Profile.self) { mockProfile = p }
        if let p = load(key: "partnerProfile", type: Profile.self) { mockPartnerProfile = p }
        if let c = load(key: "couple", type: Couple.self) { mockCouple = c }
        if let pet = load(key: "petState", type: PetState.self) { mockPetState = pet }
        if let txs = load(key: "transactions", type: [Transaction].self) { mockTransactions = txs }
        if let bs = load(key: "budgets", type: [Budget].self) { mockBudgets = bs }
        if let gs = load(key: "savingsGoals", type: [SavingsGoal].self) { mockSavingsGoals = gs }
        if let ds = load(key: "debts", type: [Debt].self) { mockDebts = ds }
        if let cs = load(key: "coupleSettings", type: CoupleSettings.self) { coupleSettings = cs }
        if let ts = load(key: "trips", type: [Trip].self) { mockTrips = ts }
        if let tes = load(key: "tripExpenses", type: [TripExpense].self) { mockTripExpenses = tes }
        if let ch = load(key: "challenges", type: [FinancialChallenge].self) { mockChallenges = ch }
        if let sh = load(key: "scoreHistory", type: [FinancialScore].self) { mockScoreHistory = sh }
        if let ac = load(key: "achievements", type: [Achievement].self) { mockAchievements = ac }
        if let nf = load(key: "notifications", type: [AppNotification].self) { mockNotifications = nf }
        if let ins = load(key: "insights", type: [InsightCache].self) { mockInsights = ins }
        if let sub = load(key: "subscriptions", type: [Subscription].self) { mockSubscriptions = sub }
        if let pf = load(key: "paidFixedKeys", type: [String].self) { paidFixedKeys = Set(pf) }
        if let sims = load(key: "simulations", type: [Simulation].self) { mockSimulations = sims }
        if let used = load(key: "insightsUsedThisMonth", type: Int.self) { insightsUsedThisMonth = used }
        if let m = load(key: "insightsCounterMonth", type: String.self) { insightsCounterMonth = m }
        if let ae = load(key: "analyticsEvents", type: [AnalyticsEntry].self) { mockAnalyticsEvents = ae }
        if let lim = load(key: "userBudgetLimit", type: Decimal.self) { userBudgetLimit = lim }
        budgetLimitEnabled = load(key: "budgetLimitEnabled", type: Bool.self) ?? false
    }

    /// Guarda TODO el estado actual a UserDefaults. Llamado tras cualquier mutacion grande.
    func saveAll() {
        save(mockProfile, key: "profile")
        save(mockPartnerProfile, key: "partnerProfile")
        save(mockCouple, key: "couple")
        save(mockPetState, key: "petState")
        save(mockTransactions, key: "transactions")
        save(mockBudgets, key: "budgets")
        save(mockSavingsGoals, key: "savingsGoals")
        save(mockDebts, key: "debts")
        save(coupleSettings, key: "coupleSettings")
        save(mockTrips, key: "trips")
        save(mockTripExpenses, key: "tripExpenses")
        save(mockChallenges, key: "challenges")
        save(mockScoreHistory, key: "scoreHistory")
        save(mockAchievements, key: "achievements")
        save(mockNotifications, key: "notifications")
        save(mockInsights, key: "insights")
        save(mockSubscriptions, key: "subscriptions")
        save(Array(paidFixedKeys), key: "paidFixedKeys")
        save(mockSimulations, key: "simulations")
        save(insightsUsedThisMonth, key: "insightsUsedThisMonth")
        save(insightsCounterMonth, key: "insightsCounterMonth")
        save(mockAnalyticsEvents, key: "analyticsEvents")
        save(userBudgetLimit, key: "userBudgetLimit")
        save(budgetLimitEnabled, key: "budgetLimitEnabled")
    }

    /// Limpia TODAS las claves fingether_* de UserDefaults. Llamado en signOut.
    static func clearAllPersisted() {
        let defaults = UserDefaults.standard
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(keyPrefix) {
            defaults.removeObject(forKey: key)
        }
    }

    /// Destruye TODA la persistencia local: claves fingether_*, app_*, tutorial_*.
    /// Más agresivo que clearAllPersisted — garantiza cero datos residuales.
    func nukeAllPersistedData() {
        let defaults = UserDefaults.standard
        let prefixes = ["fingether_", "app_", "tutorial_"]
        for key in defaults.dictionaryRepresentation().keys {
            if prefixes.contains(where: { key.hasPrefix($0) }) {
                defaults.removeObject(forKey: key)
            }
        }
        defaults.synchronize()
    }

    /// Reinicia todos los datos mock al estado inicial (con datos de prueba)
    func seedAllData() {
        defer { saveAll() }
        seedProfiles()
        seedCouple()
        seedTransactions()
        seedBudgets()
        seedSavingsGoals()
        seedPetState()
        seedAchievements()
        seedNotifications()
        seedInsights()
        seedDebts()
        seedCoupleSettings()
        seedTripsAndExpenses()
        seedChallenges()
        mockSimulations = []
        seedScoreHistory()
    }

    /// Inicia con datos completamente vacíos — solo crea un perfil sin onboarding.
    /// Bug fix #8: en vez de dejar mockCouple/mockPetState como nil (lo cual hace
    /// que cualquier acceso IUO crashee antes de completeOnboarding), inicializa
    /// instancias vacias seguras. Las features siguen detectando "sin pareja"
    /// porque user2Name es nil y partner2Id es nil.
    func seedClean() {
        defer { saveAll() }
        let now = Date()
        mockProfile = Profile(
            id: devUserId,
            email: "dev@fingether.app",
            displayName: "",
            avatarUrl: nil,
            coupleId: nil,
            subscriptionTier: .free,
            monthlyIncome: 0,
            currency: "COP",
            streakDays: 0,
            lastTransactionDate: nil,
            onboardingCompleted: false,
            notificationToken: nil,
            createdAt: now,
            updatedAt: now
        )
        mockPartnerProfile = nil
        // Empty placeholder couple — partner2Id == nil signals "no pareja vinculada"
        mockCouple = Couple(
            id: coupleUUID,
            inviteCode: "",
            inviteExpiration: nil,
            partner1Id: devUserId,
            partner2Id: nil,
            user1Name: "",
            user2Name: nil,
            user1Income: 0,
            user2Income: nil,
            combinedMonthlyIncome: 0,
            coupleMonthlyBudget: nil,
            createdAt: now,
            updatedAt: now
        )
        mockTransactions = []
        mockBudgets = []
        mockSavingsGoals = []
        // Empty placeholder pet — health 0 signals "no inicializada"
        mockPetState = PetState(
            id: UUID(),
            coupleId: coupleUUID,
            name: "Buddy",
            health: 0,
            mood: .neutral,
            evolution: .egg,
            experiencePoints: 0,
            daysAlive: 0,
            accessories: [],
            equippedAccessory: nil,
            lastFed: now,
            lastHealthUpdate: now,
            createdAt: now,
            updatedAt: now
        )
        mockAchievements = []
        mockNotifications = []
        mockInsights = []
        mockDebts = []
        coupleSettings = .defaultSettings
        mockTrips = []
        mockTripExpenses = []
        mockChallenges = []
        mockSimulations = []
        mockScoreHistory = []
        mockSubscriptions = []
        paidFixedKeys = []
        mockAnalyticsEvents = []
        insightsUsedThisMonth = 0
        insightsCounterMonth = ""
        userBudgetLimit = nil
        budgetLimitEnabled = false
    }

    // MARK: - Subscription Persistence (Bug fix #3)

    /// Inserta o reemplaza la suscripcion local. En produccion real esto deberia
    /// tambien upsertear a la tabla `subscriptions` de Supabase.
    func persistMockSubscription(_ sub: Subscription) {
        defer { saveAll() }
        if let idx = mockSubscriptions.firstIndex(where: { $0.id == sub.id }) {
            mockSubscriptions[idx] = sub
        } else {
            mockSubscriptions.append(sub)
        }
        markMockProfilePremium(sub.isPremiumActive)
    }

    /// Marca el tier del perfil mock como premium o free.
    func markMockProfilePremium(_ premium: Bool) {
        defer { saveAll() }
        guard mockProfile != nil else { return }
        mockProfile.subscriptionTier = premium ? .premium : .free
        mockProfile.updatedAt = Date()
    }

    // MARK: - Paid Fixed Keys (Bug fix #5)

    func isFixedPaid(_ key: String) -> Bool {
        paidFixedKeys.contains(key)
    }

    func togglePaidFixed(_ key: String) {
        defer { saveAll() }
        if paidFixedKeys.contains(key) {
            paidFixedKeys.remove(key)
        } else {
            paidFixedKeys.insert(key)
        }
    }

    /// Completa onboarding en memoria: actualiza el perfil mock con datos del usuario
    func completeOnboarding(displayName: String, monthlyIncome: Decimal, currency: String) {
        defer { saveAll() }
        let now = Date()
        mockProfile.displayName = displayName.sanitizedName
        mockProfile.monthlyIncome = monthlyIncome
        mockProfile.currency = currency
        mockProfile.onboardingCompleted = true
        mockProfile.updatedAt = now

        // Crear couple con invite code (sin pareja aún)
        let code = generateInviteCode()
        mockCouple = Couple(
            id: coupleUUID,
            inviteCode: code,
            inviteExpiration: Calendar.current.date(byAdding: .hour, value: 24, to: now),
            partner1Id: devUserId,
            partner2Id: nil,
            user1Name: displayName,
            user2Name: nil,
            user1Income: monthlyIncome,
            user2Income: nil,
            combinedMonthlyIncome: monthlyIncome,
            coupleMonthlyBudget: nil,
            createdAt: now,
            updatedAt: now
        )
        mockProfile.coupleId = coupleUUID

        // Crear mascota inicial
        mockPetState = PetState(
            id: UUID(),
            coupleId: coupleUUID,
            name: "Buddy",
            health: 50,
            mood: .neutral,
            evolution: .egg,
            experiencePoints: 0,
            daysAlive: 1,
            accessories: [],
            equippedAccessory: nil,
            lastFed: now,
            lastHealthUpdate: now,
            createdAt: now,
            updatedAt: now
        )
    }

    /// Crea un "usuario fantasma" como pareja para pruebas desde un solo dispositivo
    func createPhantomPartner(name: String, monthlyIncome: Decimal, gender: String) {
        defer { saveAll() }
        let now = Date()
        mockPartnerProfile = Profile(
            id: partnerUserId,
            email: "partner@fingether.app",
            displayName: name.sanitizedName,
            avatarUrl: nil,
            coupleId: coupleUUID,
            subscriptionTier: .free,
            monthlyIncome: monthlyIncome,
            currency: mockProfile.currency,
            streakDays: 0,
            lastTransactionDate: nil,
            onboardingCompleted: true,
            notificationToken: nil,
            createdAt: now,
            updatedAt: now
        )
        // Vincular en couple
        mockCouple?.partner2Id = partnerUserId
        mockCouple?.user2Name = name.sanitizedName
        mockCouple?.user2Income = monthlyIncome
        mockCouple?.combinedMonthlyIncome = mockProfile.monthlyIncome + monthlyIncome
        mockCouple?.updatedAt = now
    }

    /// Elimina la pareja fantasma
    func removePhantomPartner() {
        defer { saveAll() }
        mockPartnerProfile = nil
        mockCouple?.partner2Id = nil
        mockCouple?.user2Name = nil
        mockCouple?.user2Income = nil
        mockCouple?.combinedMonthlyIncome = mockProfile.monthlyIncome
        mockCouple?.updatedAt = Date()
    }

    // MARK: - Invite Code System

    /// Genera código de 6 caracteres sin I, O, 0, 1 para evitar confusión
    func generateInviteCode() -> String {
        let chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        return String((0..<6).map { _ in chars.randomElement()! })
    }

    /// Regenera el código de invitación con nueva expiración de 24h
    func regenerateInviteCode() -> String {
        defer { saveAll() }
        let code = generateInviteCode()
        mockCouple?.inviteCode = code
        mockCouple?.inviteExpiration = Calendar.current.date(byAdding: .hour, value: 24, to: Date())
        mockCouple?.updatedAt = Date()
        return code
    }

    enum InviteValidationResult {
        case success(coupleName: String)
        case notFound
        case expired
    }

    /// Valida un código de invitación
    func validateInviteCode(_ code: String) -> InviteValidationResult {
        guard let couple = mockCouple,
              couple.inviteCode.uppercased() == code.uppercased().trimmingCharacters(in: .whitespacesAndNewlines) else {
            return .notFound
        }
        guard couple.isInviteValid else {
            return .expired
        }
        return .success(coupleName: couple.user1Name)
    }

    /// Une al usuario 2 a la pareja existente via código
    func joinCoupleWithCode(_ code: String, partnerName: String, partnerIncome: Decimal, gender: String) -> Bool {
        defer { saveAll() }
        guard case .success = validateInviteCode(code) else { return false }

        createPhantomPartner(name: partnerName, monthlyIncome: partnerIncome, gender: gender)
        return true
    }

    // MARK: - Seed Profiles

    private func seedProfiles() {
        let now = Date()
        let cal = Calendar.current

        let rafaDOB = cal.date(from: DateComponents(year: 1995, month: 3, day: 15))!
        let sofiDOB = cal.date(from: DateComponents(year: 1996, month: 8, day: 22))!
        let relationshipStart = cal.date(from: DateComponents(year: 2023, month: 6, day: 1))!

        mockProfile = Profile(
            id: devUserId,
            email: "dev@fingether.app",
            displayName: "Rafa",
            avatarUrl: nil,
            coupleId: coupleUUID,
            subscriptionTier: .premium,
            monthlyIncome: 4_600_000,
            currency: "COP",
            streakDays: 7,
            lastTransactionDate: now,
            onboardingCompleted: true,
            notificationToken: nil,
            dateOfBirth: rafaDOB,
            gender: "Masculino",
            city: "Ciudad de Mexico",
            relationshipStatus: "en_relacion",
            relationshipStartDate: relationshipStart,
            createdAt: cal.date(byAdding: .month, value: -3, to: now)!,
            updatedAt: now
        )

        mockPartnerProfile = Profile(
            id: partnerUserId,
            email: "partner@fingether.app",
            displayName: "Sofi",
            avatarUrl: nil,
            coupleId: coupleUUID,
            subscriptionTier: .premium,
            monthlyIncome: 3_000_000,
            currency: "COP",
            streakDays: 5,
            lastTransactionDate: cal.date(byAdding: .day, value: -1, to: now),
            onboardingCompleted: true,
            notificationToken: nil,
            dateOfBirth: sofiDOB,
            gender: "Femenino",
            city: "Ciudad de Mexico",
            relationshipStatus: "en_relacion",
            relationshipStartDate: relationshipStart,
            createdAt: cal.date(byAdding: .month, value: -3, to: now)!,
            updatedAt: now
        )
    }

    // MARK: - Seed Couple

    private func seedCouple() {
        let now = Date()
        mockCouple = Couple(
            id: coupleUUID,
            inviteCode: "FNGTH01",
            inviteExpiration: Calendar.current.date(byAdding: .day, value: 30, to: now),
            partner1Id: devUserId,
            partner2Id: partnerUserId,
            user1Name: mockProfile?.displayName ?? "Rafa",
            user2Name: mockPartnerProfile?.displayName ?? "Sofi",
            user1Income: mockProfile?.monthlyIncome ?? 4_600_000,
            user2Income: mockPartnerProfile?.monthlyIncome ?? 3_000_000,
            combinedMonthlyIncome: 7_600_000,
            coupleMonthlyBudget: nil,
            createdAt: Calendar.current.date(byAdding: .month, value: -3, to: now)!,
            updatedAt: now
        )
    }

    // MARK: - Seed Transactions

    private func seedTransactions() {
        let now = Date()
        let cal = Calendar.current

        func daysAgo(_ days: Int) -> Date {
            cal.date(byAdding: .day, value: -days, to: now)!
        }

        mockTransactions = [
            // --- Salarios (ingresos individuales) ---
            makeTx(userId: devUserId, type: .income, category: .salary, amount: 2_300_000, desc: "Nomina quincenal", date: daysAgo(1)),
            makeTx(userId: partnerUserId, type: .income, category: .salary, amount: 1_500_000, desc: "Nomina quincenal Sofi", date: daysAgo(1)),
            makeTx(userId: devUserId, type: .income, category: .salary, amount: 2_300_000, desc: "Nomina quincenal", date: daysAgo(16)),
            makeTx(userId: devUserId, type: .income, category: .freelance, amount: 800_000, desc: "Proyecto freelance logo", date: daysAgo(10)),

            // --- Comida individual ---
            makeTx(userId: devUserId, type: .expense, category: .food, amount: 15_000, desc: "Tacos El Pastor", date: daysAgo(0)),
            makeTx(userId: devUserId, type: .expense, category: .food, amount: 12_000, desc: "Cafe y pan dulce", date: daysAgo(2)),
            makeTx(userId: devUserId, type: .expense, category: .food, amount: 18_000, desc: "Tortas Don Juan", date: daysAgo(9)),
            makeTx(userId: partnerUserId, type: .expense, category: .food, amount: 32_000, desc: "Ensalada y jugo", date: daysAgo(3)),

            // --- Comida compartida ---
            makeTx(userId: partnerUserId, type: .expense, category: .food, amount: 45_000, desc: "Sushi en Ichiban", date: daysAgo(1), shared: true, splitType: .equal),
            makeTx(userId: devUserId, type: .expense, category: .food, amount: 65_000, desc: "Super en Soriana", date: daysAgo(4), shared: true, splitType: .equal),
            makeTx(userId: partnerUserId, type: .expense, category: .food, amount: 95_000, desc: "Despensa semanal Walmart", date: daysAgo(7), shared: true, splitType: .equal),
            makeTx(userId: devUserId, type: .expense, category: .food, amount: 35_000, desc: "Pollo rostizado y tortillas", date: daysAgo(14), shared: true, splitType: .equal),
            makeTx(userId: partnerUserId, type: .expense, category: .food, amount: 220_000, desc: "Cena romantica restaurante", date: daysAgo(20), shared: true, splitType: .equal),

            // --- Transporte individual ---
            makeTx(userId: devUserId, type: .expense, category: .transport, amount: 22_000, desc: "Uber al trabajo", date: daysAgo(0)),
            makeTx(userId: devUserId, type: .expense, category: .transport, amount: 22_000, desc: "Uber regreso", date: daysAgo(8)),
            makeTx(userId: partnerUserId, type: .expense, category: .transport, amount: 10_000, desc: "DiDi al centro", date: daysAgo(3)),

            // --- Transporte compartido ---
            makeTx(userId: devUserId, type: .expense, category: .transport, amount: 150_000, desc: "Gasolina carro", date: daysAgo(5), shared: true, splitType: .equal),

            // --- Entretenimiento compartido ---
            makeTx(userId: devUserId, type: .expense, category: .entertainment, amount: 55_000, desc: "Netflix mensual", date: daysAgo(6), recurring: true, freq: .monthly, shared: true, splitType: .onePays(devUserId)),
            makeTx(userId: devUserId, type: .expense, category: .entertainment, amount: 33_000, desc: "Spotify Premium", date: daysAgo(6), recurring: true, freq: .monthly, shared: true, splitType: .onePays(devUserId)),
            makeTx(userId: partnerUserId, type: .expense, category: .entertainment, amount: 65_000, desc: "Cine + palomitas", date: daysAgo(12), shared: true, splitType: .equal),

            // --- Servicios compartidos (gastos fijos) ---
            makeTx(userId: devUserId, type: .expense, category: .utilities, amount: 85_000, desc: "Recibo de luz CFE", date: daysAgo(15), shared: true, splitType: .onePays(devUserId)),
            makeTx(userId: devUserId, type: .expense, category: .utilities, amount: 75_000, desc: "Internet Totalplay", date: daysAgo(15), recurring: true, freq: .monthly, shared: true, splitType: .onePays(devUserId)),
            makeTx(userId: devUserId, type: .expense, category: .utilities, amount: 45_000, desc: "Recibo de agua", date: daysAgo(30), shared: true, splitType: .onePays(devUserId)),

            // --- Compras individuales ---
            makeTx(userId: partnerUserId, type: .expense, category: .shopping, amount: 280_000, desc: "Ropa en Liverpool", date: daysAgo(18)),
            makeTx(userId: devUserId, type: .expense, category: .shopping, amount: 165_000, desc: "Audifonos Bluetooth", date: daysAgo(25)),

            // --- Salud individual ---
            makeTx(userId: partnerUserId, type: .expense, category: .health, amount: 110_000, desc: "Consulta medica", date: daysAgo(22)),
            makeTx(userId: devUserId, type: .expense, category: .health, amount: 65_000, desc: "Farmacia medicamentos", date: daysAgo(35)),

            // --- Vivienda compartida (gasto fijo) ---
            makeTx(userId: devUserId, type: .expense, category: .housing, amount: 1_600_000, desc: "Renta mensual", date: daysAgo(28), recurring: true, freq: .monthly, shared: true, splitType: .equal),

            // --- Ahorro compartido ---
            makeTx(userId: devUserId, type: .expense, category: .savings, amount: 370_000, desc: "Ahorro quincenal", date: daysAgo(1), shared: true, splitType: .equal),

            // --- Educacion individual ---
            makeTx(userId: partnerUserId, type: .expense, category: .education, amount: 220_000, desc: "Curso de ingles online", date: daysAgo(40)),

            // --- Regalos individual ---
            makeTx(userId: devUserId, type: .expense, category: .gifts, amount: 140_000, desc: "Regalo cumple mama", date: daysAgo(45)),
        ]
    }

    private func makeTx(
        userId: UUID,
        type: TransactionType,
        category: TransactionCategory,
        amount: Decimal,
        desc: String,
        date: Date,
        recurring: Bool = false,
        freq: RecurringFrequency? = nil,
        shared: Bool = false,
        splitType: SplitType? = nil
    ) -> Transaction {
        Transaction(
            id: UUID(),
            userId: userId,
            coupleId: coupleUUID,
            type: type,
            category: category,
            amount: amount,
            description: desc,
            notes: nil,
            date: date,
            isRecurring: recurring,
            recurringFrequency: freq,
            isShared: shared,
            splitType: splitType,
            createdAt: date,
            updatedAt: date
        )
    }

    // MARK: - Seed Budgets
    // v1.5 fix: NO hardcoded category budgets. The smart BudgetCalculator
    // (income - fixed - savings = available) is the ONLY budget source.
    // Users can optionally create per-category budgets from the Budgets screen.
    private func seedBudgets() {
        mockBudgets = []
    }

    // MARK: - Seed Savings Goals

    private func seedSavingsGoals() {
        let now = Date()
        let cal = Calendar.current

        mockSavingsGoals = [
            SavingsGoal(
                id: UUID(), coupleId: coupleUUID, name: "Viaje a Cancun",
                description: "Vacaciones de verano en pareja, todo incluido 5 noches",
                targetAmount: 35000, currentAmount: 21000,
                targetDate: cal.date(byAdding: .month, value: 3, to: now),
                emoji: "🏖️", status: .active, isShared: true,
                createdAt: cal.date(byAdding: .month, value: -2, to: now)!, updatedAt: now
            ),
            SavingsGoal(
                id: UUID(), coupleId: coupleUUID, name: "Fondo de emergencia",
                description: "3 meses de gastos basicos cubiertos",
                targetAmount: 90000, currentAmount: 13500,
                targetDate: nil,
                emoji: "🛡️", status: .active, isShared: true,
                createdAt: cal.date(byAdding: .month, value: -3, to: now)!, updatedAt: now
            ),
            SavingsGoal(
                id: UUID(), coupleId: coupleUUID, name: "iPhone nuevo",
                description: "iPhone 16 Pro para reemplazar el actual",
                targetAmount: 28000, currentAmount: 8400,
                targetDate: cal.date(byAdding: .month, value: 5, to: now),
                emoji: "📱", status: .active, isShared: false,
                createdAt: cal.date(byAdding: .month, value: -1, to: now)!, updatedAt: now
            ),
            SavingsGoal(
                id: UUID(), coupleId: coupleUUID, name: "Curso de cocina",
                description: "Clases de cocina italiana los sabados",
                targetAmount: 900_000, currentAmount: 2000,
                targetDate: cal.date(byAdding: .month, value: 2, to: now),
                emoji: "👩‍🍳", status: .active, isShared: false,
                createdAt: cal.date(byAdding: .day, value: -15, to: now)!, updatedAt: now
            ),
        ]
    }

    // MARK: - Seed Pet State

    private func seedPetState() {
        let now = Date()
        mockPetState = PetState(
            id: UUID(),
            coupleId: coupleUUID,
            name: "Buddy",
            health: 72,
            mood: .happy,
            evolution: .teen,
            experiencePoints: 2500,
            daysAlive: 45,
            accessories: ["sombrero", "bufanda", "lentes_sol"],
            equippedAccessory: "sombrero",
            lastFed: Calendar.current.date(byAdding: .hour, value: -4, to: now)!,
            lastHealthUpdate: now,
            createdAt: Calendar.current.date(byAdding: .day, value: -45, to: now)!,
            updatedAt: now
        )
    }

    // MARK: - Seed Achievements

    private func seedAchievements() {
        let now = Date()
        let cal = Calendar.current

        let defs: [(key: String, title: String, desc: String, cat: AchievementCategory, icon: String, target: Int, progress: Int, unlocked: Bool, reward: String?)] = [
            // Hitos
            ("first_transaction", "Primer paso", "Registra tu primera transaccion", .milestone, "star.fill", 1, 1, true, nil),
            ("ten_transactions", "Constancia", "Registra 10 transacciones", .milestone, "list.bullet", 10, 10, true, nil),
            ("fifty_transactions", "Medio centenar", "Registra 50 transacciones", .milestone, "list.bullet.rectangle", 50, 30, false, nil),
            ("hundred_transactions", "Centenario", "Registra 100 transacciones", .milestone, "star.circle.fill", 100, 30, false, nil),
            ("first_fixed", "Organizado", "Registra tu primer gasto fijo", .milestone, "pin.fill", 1, 1, true, nil),

            // Rachas
            ("week_streak", "Semana perfecta", "Registra gastos 7 dias seguidos", .streak, "flame.fill", 7, 7, true, nil),
            ("two_week_streak", "Imparable", "Racha de 14 dias seguidos", .streak, "flame.fill", 14, 7, false, nil),
            ("month_streak", "Mes de fuego", "Racha de 30 dias seguidos", .streak, "flame.circle.fill", 30, 7, false, nil),
            ("quarter_streak", "Trimestre dorado", "Racha de 90 dias seguidos", .streak, "flame.circle.fill", 90, 7, false, nil),

            // Ahorro
            ("first_saving", "Primer ahorro", "Crea tu primera meta de ahorro", .savings, "banknote.fill", 1, 1, true, nil),
            ("saving_25", "25% ahorrado", "Alcanza el 25% en una meta", .savings, "chart.bar.fill", 1, 1, true, nil),
            ("saving_50", "Mitad del camino", "Alcanza el 50% en una meta", .savings, "chart.bar.fill", 1, 0, false, nil),
            ("saving_75", "Casi ahi", "Alcanza el 75% en una meta", .savings, "chart.bar.fill", 1, 0, false, nil),
            ("saving_100", "Meta cumplida", "Completa una meta de ahorro", .savings, "trophy.fill", 1, 0, false, nil),
            ("three_goals", "Ambicioso", "Ten 3 metas de ahorro activas", .savings, "target", 3, 2, false, nil),
            ("save_10k", "Primer 10 mil", "Ahorra un total de $10,000", .savings, "dollarsign.circle.fill", 1, 0, false, nil),

            // Presupuesto
            ("budget_master", "Maestro del presupuesto", "No excedas ningun presupuesto en 1 mes", .budget, "chart.pie.fill", 1, 0, false, nil),
            ("three_budgets", "Planificador", "Crea 3 presupuestos activos", .budget, "chart.pie.fill", 3, 3, true, nil),
            ("budget_streak_3", "Disciplina financiera", "3 meses sin exceder presupuestos", .budget, "medal.fill", 3, 0, false, nil),
            ("under_budget", "Por debajo del limite", "Gasta menos del 50% de un presupuesto", .budget, "hand.thumbsup.fill", 1, 0, false, nil),

            // Social / Pareja
            ("couple_joined", "Mejor juntos", "Vincula tu cuenta con tu pareja", .social, "heart.fill", 1, 1, true, nil),
            ("first_shared", "Primer gasto juntos", "Registra tu primer gasto compartido", .social, "heart.circle.fill", 1, 1, true, nil),
            ("settle_debt", "Cuentas claras", "Salda tu primera deuda con tu pareja", .social, "checkmark.seal.fill", 1, 0, false, nil),
            ("no_debts", "Sin deudas", "No tengas deudas pendientes con tu pareja", .social, "hands.clap.fill", 1, 0, false, nil),
            ("shared_goal_complete", "Meta en pareja", "Completen una meta de ahorro juntos", .social, "star.circle.fill", 1, 0, false, nil),
            ("anniversary", "Aniversario Fingether", "Lleva 1 ano usando Fingether", .social, "gift.fill", 1, 0, false, nil),
            ("first_shared_expense", "Primer gasto compartido 💕", "Registren su primer gasto en pareja", .social, "person.2.fill", 1, 1, true, nil),
            ("couple_budget_master", "Maestros del presupuesto en pareja", "Mantengan todos los presupuestos compartidos en verde por 1 mes", .social, "chart.pie.fill", 1, 0, false, nil),
            ("couple_trip_planned", "Viaje juntos planeado", "Crean su primer viaje compartido en Fingether", .social, "airplane", 1, 0, false, nil),
            ("five_couple_challenges", "Equipo invencible", "Completen 5 retos financieros juntos", .social, "trophy.fill", 5, 0, false, nil),

            // Exploracion
            ("insight_reader", "Curioso", "Lee 5 consejos de IA", .milestone, "lightbulb.fill", 5, 2, false, nil),
            ("voice_first", "Manos libres", "Registra un gasto por voz", .milestone, "mic.fill", 1, 0, false, nil),
            ("change_currency", "Internacional", "Cambia la moneda de la app", .milestone, "globe.americas.fill", 1, 1, true, nil),
            ("dark_mode", "Lado oscuro", "Activa el modo oscuro", .milestone, "moon.fill", 1, 0, false, nil),
            ("all_categories", "Explorador", "Usa todas las categorias de gasto", .milestone, "square.grid.3x3.fill", 15, 8, false, nil),
        ]

        mockAchievements = defs.map { d in
            Achievement(
                id: UUID(),
                coupleId: coupleUUID,
                key: d.key,
                title: d.title,
                description: d.desc,
                category: d.cat,
                icon: d.icon,
                unlockedAt: d.unlocked ? cal.date(byAdding: .day, value: -Int.random(in: 1...30), to: now) : nil,
                rewardAccessory: d.reward,
                progress: d.progress,
                target: d.target,
                createdAt: cal.date(byAdding: .month, value: -3, to: now)!
            )
        }
    }

    // MARK: - Seed Notifications

    private func seedNotifications() {
        let now = Date()
        let cal = Calendar.current

        mockNotifications = [
            AppNotification(
                id: UUID(), userId: devUserId, coupleId: coupleUUID,
                type: .budgetAlert,
                title: "Presupuesto de comida al 80%",
                body: "Llevas $2,740 de $5,000 en comida este mes. Cuidado con los gastos restantes.",
                data: nil, isRead: false,
                createdAt: cal.date(byAdding: .hour, value: -2, to: now)!
            ),
            AppNotification(
                id: UUID(), userId: devUserId, coupleId: coupleUUID,
                type: .achievement,
                title: "Logro desbloqueado: Racha semanal",
                body: "Felicidades! Registraste transacciones 7 dias seguidos. Tu mascota recibio una bufanda.",
                data: nil, isRead: false,
                createdAt: cal.date(byAdding: .hour, value: -5, to: now)!
            ),
            AppNotification(
                id: UUID(), userId: devUserId, coupleId: coupleUUID,
                type: .partnerActivity,
                title: "Sofi registro un gasto",
                body: "Sofi registro $245 en Sushi en Ichiban (Comida).",
                data: nil, isRead: true,
                createdAt: cal.date(byAdding: .day, value: -1, to: now)!
            ),
            AppNotification(
                id: UUID(), userId: devUserId, coupleId: coupleUUID,
                type: .petStatus,
                title: "Buddy esta feliz!",
                body: "Tu mascota tiene salud al 72%. Sigue registrando gastos para mantenerla contenta.",
                data: nil, isRead: true,
                createdAt: cal.date(byAdding: .day, value: -2, to: now)!
            ),
            AppNotification(
                id: UUID(), userId: devUserId, coupleId: coupleUUID,
                type: .savingsMilestone,
                title: "Meta de ahorro: 60% completado",
                body: "Tu meta 'Viaje a Cancun' ya lleva $21,000 de $35,000. Van muy bien!",
                data: nil, isRead: false,
                createdAt: cal.date(byAdding: .day, value: -3, to: now)!
            ),
        ]
    }

    // MARK: - Seed Insights

    private func seedInsights() {
        let now = Date()
        let cal = Calendar.current

        mockInsights = [
            InsightCache(
                id: UUID(), coupleId: coupleUUID,
                insightType: "monthly_summary",
                content: """
                Este mes llevan un buen ritmo financiero. Sus ingresos combinados suman $47,000 MXN \
                y los gastos van en $18,500 MXN, lo cual representa un 39% de sus ingresos. \
                La categoria con mayor gasto es Comida ($2,740), seguida de Vivienda ($8,500). \
                Les recomiendo revisar si pueden reducir los gastos de transporte usando transporte \
                publico al menos 2 dias a la semana, lo que podria ahorrarles hasta $500 mensuales. \
                Su meta de ahorro para Cancun va muy bien con 60% completado. Sigan asi!
                """,
                metadata: ["period": "abril_2026"],
                generatedAt: cal.date(byAdding: .hour, value: -6, to: now)!,
                expiresAt: cal.date(byAdding: .day, value: 7, to: now)!
            ),
            InsightCache(
                id: UUID(), coupleId: coupleUUID,
                insightType: "saving_tip",
                content: """
                Consejo para ahorrar: He notado que gastan aproximadamente $478 al mes en suscripciones \
                digitales (Netflix, Spotify, Internet). Una opcion es considerar planes familiares \
                compartidos que podrian reducir este gasto un 30%. Tambien, el gasto en comida fuera \
                de casa ($1,530 este mes) podria reducirse cocinando en casa 2 dias mas por semana, \
                ahorrando estimadamente $600 mensuales que pueden ir directos a su fondo de emergencia.
                """,
                metadata: ["category": "savings"],
                generatedAt: cal.date(byAdding: .day, value: -2, to: now)!,
                expiresAt: cal.date(byAdding: .day, value: 5, to: now)!
            ),
        ]
    }

    // MARK: - Auth Mock Methods

    func getMockProfile() -> Profile {
        mockProfile
    }

    func updateMockProfile(displayName: String?, monthlyIncome: Decimal?, currency: String?, onboardingCompleted: Bool?) {
        defer { saveAll() }
        if let displayName { mockProfile.displayName = displayName }
        if let monthlyIncome { mockProfile.monthlyIncome = monthlyIncome }
        if let currency { mockProfile.currency = currency }
        if let onboardingCompleted { mockProfile.onboardingCompleted = onboardingCompleted }
        mockProfile.updatedAt = Date()
    }

    // MARK: - Couple Mock Methods

    func getMockCouple() -> Couple? {
        mockCouple
    }

    func getMockPartnerProfile() -> Profile? {
        mockPartnerProfile
    }

    func mockCreateCouple() -> (coupleId: UUID, inviteCode: String) {
        (coupleId: coupleUUID, inviteCode: mockCouple.inviteCode)
    }

    func mockJoinCouple(inviteCode: String) -> UUID? {
        if inviteCode.uppercased() == mockCouple.inviteCode {
            return coupleUUID
        }
        return nil
    }

    // MARK: - Transaction Mock Methods

    func getMockTransactions(coupleId: UUID, month: Date?, category: TransactionCategory?, type: TransactionType?) -> [Transaction] {
        var result = mockTransactions.filter { $0.coupleId == coupleId }

        if let month {
            let start = month.startOfMonth
            let end = month.endOfMonth
            result = result.filter { $0.date >= start && $0.date <= end }
        }
        if let category {
            result = result.filter { $0.category == category }
        }
        if let type {
            result = result.filter { $0.type == type }
        }

        return result.sorted { $0.date > $1.date }
    }

    func getMockRecentTransactions(coupleId: UUID, limit: Int) -> [Transaction] {
        Array(
            mockTransactions
                .filter { $0.coupleId == coupleId }
                .sorted { $0.date > $1.date }
                .prefix(limit)
        )
    }

    func addMockTransaction(_ transaction: Transaction) -> Transaction {
        defer { saveAll() }
        var tx = transaction
        // Sanitize text fields
        tx.description = tx.description.sanitizedText
        if let notes = tx.notes { tx.notes = notes.sanitizedText }
        // Ensure couple_id is set
        if tx.coupleId == nil {
            tx.coupleId = coupleUUID
        }
        // Auto-calculate split amounts for shared recurring transactions
        if tx.isRecurring && tx.isShared {
            let splitType = tx.splitType ?? coupleSettings.defaultSplitType
            tx.splitType = splitType
            let amounts = calculateSplitAmounts(for: tx.amount, splitType: splitType)
            tx.splitUser1Amount = amounts.user1
            tx.splitUser2Amount = amounts.user2
        }
        mockTransactions.append(tx)
        return tx
    }

    /// Calculates split amounts for a given total and split type
    private func calculateSplitAmounts(for total: Decimal, splitType: SplitType) -> (user1: Decimal, user2: Decimal) {
        switch splitType {
        case .equal:
            let half = total / 2
            return (half, half)
        case .custom(let pct):
            let user1 = total * Decimal(pct) / 100
            return (user1, total - user1)
        case .onePays(let payerId):
            if payerId == devUserId {
                return (total, 0)
            } else {
                return (0, total)
            }
        case .proportional:
            // Default to 50/50 if no income data
            let half = total / 2
            return (half, half)
        }
    }

    /// Recalculates split amounts for ALL shared recurring transactions using current couple settings
    func recalculateAllSharedFixedSplits() {
        defer { saveAll() }
        for i in mockTransactions.indices {
            let tx = mockTransactions[i]
            guard tx.isRecurring && tx.isShared else { continue }
            let splitType = tx.splitType ?? coupleSettings.defaultSplitType
            mockTransactions[i].splitType = splitType
            let amounts = calculateSplitAmounts(for: tx.amount, splitType: splitType)
            mockTransactions[i].splitUser1Amount = amounts.user1
            mockTransactions[i].splitUser2Amount = amounts.user2
            mockTransactions[i].updatedAt = Date()
        }
    }

    /// C3: Add/update an emoji reaction to a transaction.
    func reactToTransaction(transactionId: UUID, userId: UUID, emoji: String) {
        defer { saveAll() }
        guard let idx = mockTransactions.firstIndex(where: { $0.id == transactionId }) else { return }
        var reactions = mockTransactions[idx].reactions ?? [:]
        // Toggle: if same emoji, remove; otherwise set.
        if reactions[userId.uuidString] == emoji {
            reactions.removeValue(forKey: userId.uuidString)
        } else {
            reactions[userId.uuidString] = emoji
        }
        mockTransactions[idx].reactions = reactions.isEmpty ? nil : reactions
        mockTransactions[idx].updatedAt = Date()
        AnalyticsService.track(.transactionReacted, properties: ["emoji": emoji])
    }

    func updateMockTransaction(_ transaction: Transaction) {
        defer { saveAll() }
        if let idx = mockTransactions.firstIndex(where: { $0.id == transaction.id }) {
            mockTransactions[idx] = transaction
        }
    }

    func deleteMockTransaction(id: UUID) {
        defer { saveAll() }
        mockTransactions.removeAll { $0.id == id }
    }

    // MARK: - Budget Mock Methods

    func getMockBudgets(coupleId: UUID) -> [Budget] {
        mockBudgets
            .filter { $0.coupleId == coupleId && $0.isActive }
            .sorted { $0.category.rawValue < $1.category.rawValue }
    }

    func addMockBudget(_ budget: Budget) -> Budget {
        defer { saveAll() }
        mockBudgets.append(budget)
        return budget
    }

    func updateMockBudget(_ budget: Budget) {
        defer { saveAll() }
        if let idx = mockBudgets.firstIndex(where: { $0.id == budget.id }) {
            mockBudgets[idx] = budget
        }
    }

    func deleteMockBudget(id: UUID) {
        defer { saveAll() }
        mockBudgets.removeAll { $0.id == id }
    }

    func getMockBudgetAlerts(coupleId: UUID) -> [BudgetAlertResponse] {
        mockBudgets
            .filter { $0.coupleId == coupleId && $0.isActive && $0.isOverThreshold }
            .map { budget in
                BudgetAlertResponse(
                    budgetId: budget.id,
                    category: budget.category,
                    percentageUsed: budget.usagePercentage,
                    amountLimit: budget.amountLimit,
                    currentSpent: budget.currentSpent
                )
            }
    }

    // MARK: - Dashboard Mock Methods

    func getMockMonthlySummary(coupleId: UUID, month: Date) -> MonthlySummary {
        let txs = getMockTransactions(coupleId: coupleId, month: month, category: nil, type: nil)

        let totalIncome = txs.filter { $0.type == .income }.reduce(Decimal.zero) { $0 + $1.amount }
        let totalExpenses = txs.filter { $0.type == .expense }.reduce(Decimal.zero) { $0 + $1.amount }

        var breakdown: [TransactionCategory: Decimal] = [:]
        for tx in txs where tx.type == .expense {
            breakdown[tx.category, default: 0] += tx.amount
        }

        let topCategory = breakdown.max(by: { $0.value < $1.value })?.key

        return MonthlySummary(
            totalIncome: totalIncome,
            totalExpenses: totalExpenses,
            netBalance: totalIncome - totalExpenses,
            categoryBreakdown: breakdown,
            transactionCount: txs.count,
            topCategory: topCategory
        )
    }

    // MARK: - Pet Mock Methods

    func getMockPetState(coupleId: UUID) -> PetState? {
        if mockPetState.coupleId == coupleId {
            return mockPetState
        }
        return nil
    }

    func updateMockPetName(name: String) {
        defer { saveAll() }
        mockPetState.name = name
        mockPetState.updatedAt = Date()
    }

    func equipMockAccessory(accessory: String?) {
        defer { saveAll() }
        mockPetState.equippedAccessory = accessory
        mockPetState.updatedAt = Date()
    }

    func awardMockXP(xp: Int) {
        defer { saveAll() }
        guard mockPetState != nil else { return }
        mockPetState.experiencePoints += xp
        // Check evolution thresholds
        if mockPetState.experiencePoints >= 10000 {
            mockPetState.evolution = .legendary
        } else if mockPetState.experiencePoints >= 5000 {
            mockPetState.evolution = .adult
        } else if mockPetState.experiencePoints >= 1500 {
            mockPetState.evolution = .teen
        } else if mockPetState.experiencePoints >= 500 {
            mockPetState.evolution = .baby
        }
        mockPetState.updatedAt = Date()
        // Bug fix #7: tras subir XP/evolution, recalcular health y mood.
        recalculatePetHealthAndMood()
    }

    /// Bug fix #7: ahora calcula la salud real (antes solo bumpeaba timestamps).
    /// Replica la formula del SQL: 0.4 * budgetAdherence + 0.3 * savingsProgress + 0.3 * streakBonus
    func refreshMockPetHealth() {
        defer { saveAll() }
        guard mockPetState != nil else { return }
        recalculatePetHealthAndMood()
    }

    /// Recalcula health/mood basado en presupuestos, metas y rachas. Bug fix #7.
    private func recalculatePetHealthAndMood() {
        guard mockPetState != nil else { return }

        // Budget adherence: promedio de (1 - spent/limit) en presupuestos activos.
        let activeBudgets = mockBudgets.filter { $0.isActive }
        let avgBudget: Double
        if activeBudgets.isEmpty {
            avgBudget = 0.5
        } else {
            let ratios: [Double] = activeBudgets.map { b in
                guard b.amountLimit > 0 else { return 1 }
                let used = NSDecimalNumber(decimal: b.currentSpent / b.amountLimit).doubleValue
                return max(0, min(1, 1 - used))
            }
            avgBudget = ratios.reduce(0, +) / Double(ratios.count)
        }

        // Savings progress: promedio de current/target en metas activas.
        let activeGoals = mockSavingsGoals.filter { $0.status == .active }
        let avgSavings: Double
        if activeGoals.isEmpty {
            avgSavings = 0
        } else {
            let progresses: [Double] = activeGoals.map { g in
                guard g.targetAmount > 0 else { return 0 }
                return min(1, NSDecimalNumber(decimal: g.currentAmount / g.targetAmount).doubleValue)
            }
            avgSavings = progresses.reduce(0, +) / Double(progresses.count)
        }

        // Streak bonus: max racha entre los profiles, 5 puntos por dia, max 100.
        let maxStreak = max(mockProfile?.streakDays ?? 0, mockPartnerProfile?.streakDays ?? 0)
        let streakBonus = min(100.0, Double(maxStreak) * 5.0)

        let raw = (avgBudget * 100 * 0.4) + (avgSavings * 100 * 0.3) + (streakBonus * 0.3)
        let health = max(0, min(100, Int(raw.rounded())))

        let mood: PetMood
        switch health {
        case 80...:        mood = .ecstatic
        case 60..<80:      mood = .happy
        case 40..<60:      mood = .neutral
        case 20..<40:      mood = .sad
        default:           mood = .critical
        }

        mockPetState.health = health
        mockPetState.mood = mood
        mockPetState.lastHealthUpdate = Date()
        mockPetState.updatedAt = Date()
    }

    // MARK: - Savings Goal Mock Methods

    func getMockGoals(coupleId: UUID) -> [SavingsGoal] {
        mockSavingsGoals
            .filter { $0.coupleId == coupleId }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func addMockGoal(_ goal: SavingsGoal) -> SavingsGoal {
        defer { saveAll() }
        mockSavingsGoals.append(goal)
        return goal
    }

    func updateMockGoal(_ goal: SavingsGoal) {
        defer { saveAll() }
        if let idx = mockSavingsGoals.firstIndex(where: { $0.id == goal.id }) {
            mockSavingsGoals[idx] = goal
        }
    }

    func deleteMockGoal(id: UUID) {
        defer { saveAll() }
        mockSavingsGoals.removeAll { $0.id == id }
    }

    func contributeMockToGoal(goalId: UUID, amount: Decimal) {
        defer { saveAll() }
        if let idx = mockSavingsGoals.firstIndex(where: { $0.id == goalId }) {
            mockSavingsGoals[idx].currentAmount += amount
            if mockSavingsGoals[idx].currentAmount >= mockSavingsGoals[idx].targetAmount {
                mockSavingsGoals[idx].status = .completed
            }
            mockSavingsGoals[idx].updatedAt = Date()
        }
    }

    // MARK: - Achievement Mock Methods

    func getMockAchievements(coupleId: UUID) -> [Achievement] {
        mockAchievements.filter { $0.coupleId == coupleId }
    }

    func checkMockAchievements(coupleId: UUID) -> [String] {
        // Return empty — no new unlocks in mock mode
        []
    }

    // MARK: - Notification Mock Methods

    func getMockNotifications(userId: UUID) -> [AppNotification] {
        mockNotifications
            .filter { $0.userId == userId }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func markMockNotificationAsRead(notificationId: UUID) {
        defer { saveAll() }
        if let idx = mockNotifications.firstIndex(where: { $0.id == notificationId }) {
            mockNotifications[idx].isRead = true
        }
    }

    func getMockUnreadCount(userId: UUID) -> Int {
        mockNotifications.filter { $0.userId == userId && !$0.isRead }.count
    }

    // MARK: - Insights Mock Methods

    func getMockCachedInsights(coupleId: UUID) -> [InsightCache] {
        mockInsights
            .filter { $0.coupleId == coupleId && !$0.isExpired }
            .sorted { $0.generatedAt > $1.generatedAt }
    }

    func generateMockInsight(type: String, mode: String? = nil) -> String {
        let isCouple = (mode == "couple") || (mode == nil && AppPreferences.shared.isCoupleMode)
        let n1 = currentUser1Name
        let n2 = currentUser2Name

        switch type {
        case "monthly_summary":
            if let cached = mockInsights.first(where: { $0.insightType == "monthly_summary" })?.content {
                return cached
            }
            return isCouple
                ? "Entre \(n1) y \(n2) gastaron menos que el mes pasado. Sigan asi."
                : "Gastaste menos que el mes pasado. Sigue asi."

        case "saving_tip":
            if let cached = mockInsights.first(where: { $0.insightType == "saving_tip" })?.content {
                return cached
            }
            return isCouple
                ? "Establezcan juntos un presupuesto mensual por categoria. Funciona mejor cuando ambos lo conocen."
                : "Establece un presupuesto mensual por categoria de gasto."

        default:
            return isCouple
                ? "Consejo para \(n1) y \(n2): revisen sus gastos compartidos juntos cada semana."
                : "Consejo: revisar tus gastos semanalmente te ayuda a mantener el control."
        }
    }

    // MARK: - Seed Couple Settings

    private func seedCoupleSettings() {
        coupleSettings = CoupleSettings(
            defaultSplitType: .equal,
            categorySplits: [
                .housing: .equal,
                .utilities: .onePays(devUserId),
                .entertainment: .equal
            ]
        )
    }

    // MARK: - Couple Settings Mock Methods

    func getMockCoupleSettings() -> CoupleSettings {
        coupleSettings
    }

    func updateMockCoupleSettings(_ settings: CoupleSettings) {
        defer { saveAll() }
        coupleSettings = settings
    }

    // MARK: - Couple Split Helpers (used by all couple-mode features)

    /// Identificador del usuario principal en mock (Rafa).
    var currentUser1Id: UUID { devUserId }

    /// Identificador de la pareja en mock (Sofi).
    var currentUser2Id: UUID { partnerUserId }

    /// Nombre real del usuario 1 desde mockCouple. Fallback a "Tu".
    var currentUser1Name: String {
        let name = mockCouple?.user1Name ?? mockProfile?.displayName ?? ""
        return name.isEmpty ? "Tu" : name
    }

    /// Nombre real del usuario 2 desde mockCouple. Fallback a "Pareja".
    var currentUser2Name: String {
        let name = mockCouple?.user2Name ?? mockPartnerProfile?.displayName ?? ""
        return name.isEmpty ? "Pareja" : name
    }

    /// Ingreso mensual del usuario 1 (real, no hardcodeado).
    var currentUser1Income: Decimal {
        mockCouple?.user1Income ?? mockProfile?.monthlyIncome ?? 0
    }

    /// Ingreso mensual del usuario 2 (real, no hardcodeado).
    var currentUser2Income: Decimal {
        mockCouple?.user2Income ?? mockPartnerProfile?.monthlyIncome ?? 0
    }

    /// Ingreso combinado de la pareja.
    var currentCombinedIncome: Decimal {
        currentUser1Income + currentUser2Income
    }

    /// Total de gastos compartidos del mes actual (transactions con isShared y type expense).
    func currentMonthCoupleExpensesTotal(coupleId: UUID? = nil) -> Decimal {
        let cid = coupleId ?? coupleUUID
        let now = Date()
        return mockTransactions
            .filter {
                $0.coupleId == cid &&
                $0.type == .expense &&
                Calendar.current.isDate($0.date, equalTo: now, toGranularity: .month)
            }
            .reduce(Decimal.zero) { $0 + $1.amount }
    }

    /// Divide un monto entre la pareja segun el SplitType dado.
    /// IMPORTANTE: Para .proportional usa los ingresos reales de mockCouple.user1Income / user2Income,
    /// nunca valores hardcodeados.
    func splitFor(amount: Decimal, splitType: SplitType) -> (user1: Decimal, user2: Decimal) {
        switch splitType {
        case .equal:
            let half = amount / 2
            return (half, half)

        case .custom(let pct):
            let user1 = amount * Decimal(pct) / 100
            return (user1, amount - user1)

        case .onePays(let payerId):
            if payerId == devUserId {
                return (amount, 0)
            } else {
                return (0, amount)
            }

        case .proportional:
            let i1 = currentUser1Income
            let i2 = currentUser2Income
            let total = i1 + i2
            guard total > 0 else {
                let half = amount / 2
                return (half, half)
            }
            let user1 = amount * i1 / total
            return (user1, amount - user1)
        }
    }

    /// Porcentajes (0-100) que paga cada usuario bajo el split type actual del coupleSettings.
    func currentSplitPercents() -> (user1: Int, user2: Int) {
        splitPercents(for: coupleSettings.defaultSplitType)
    }

    /// Porcentajes (0-100) que paga cada usuario para un splitType arbitrario.
    func splitPercents(for splitType: SplitType) -> (user1: Int, user2: Int) {
        let result = splitFor(amount: 100, splitType: splitType)
        let p1 = Int(NSDecimalNumber(decimal: result.user1).doubleValue.rounded())
        let clamped = min(100, max(0, p1))
        return (clamped, 100 - clamped)
    }

    // MARK: - Who Owes Whom Calculation

    /// Calcula quien le debe a quien basado en las transacciones compartidas del mes actual.
    /// Retorna (deudorId, acreedorId, monto).
    func calculateWhoOwesWhom() -> (owerId: UUID, owedId: UUID, amount: Decimal) {
        let now = Date()
        let startOfMonth = now.startOfMonth
        let endOfMonth = now.endOfMonth

        let sharedTxs = mockTransactions.filter {
            $0.isShared &&
            $0.type == .expense &&
            $0.coupleId == coupleUUID &&
            $0.date >= startOfMonth &&
            $0.date <= endOfMonth
        }

        // Track net balance: positive means devUser is owed, negative means devUser owes
        var devUserNetBalance: Decimal = 0

        for tx in sharedTxs {
            let split = tx.splitType ?? .equal
            let payer = tx.userId
            let total = tx.amount

            // Bug fix #4: usa el helper splitFor que lee mockCouple.user1Income/user2Income
            // reales (antes hardcodeaba 25000/47000 para .proportional).
            let parts = splitFor(amount: total, splitType: split)
            let devUserShare = parts.user1
            let partnerShare = parts.user2

            // If devUser paid, partner owes their share to devUser
            if payer == devUserId {
                devUserNetBalance += partnerShare
            } else {
                // Partner paid, devUser owes their share to partner
                devUserNetBalance -= devUserShare
            }
        }

        if devUserNetBalance >= 0 {
            // Partner owes devUser
            return (owerId: partnerUserId, owedId: devUserId, amount: devUserNetBalance)
        } else {
            // DevUser owes partner
            return (owerId: devUserId, owedId: partnerUserId, amount: -devUserNetBalance)
        }
    }

    // MARK: - Expense Analysis Methods

    /// Retorna todas las transacciones recurrentes de la pareja
    func getFixedExpenses(coupleId: UUID) -> [Transaction] {
        mockTransactions.filter {
            $0.coupleId == coupleId && $0.isRecurring && $0.type == .expense
        }
    }

    /// Suma total de gastos recurrentes de la pareja
    func getFixedExpensesTotal(coupleId: UUID) -> Decimal {
        getFixedExpenses(coupleId: coupleId).reduce(Decimal.zero) { $0 + $1.amount }
    }

    /// Gastos individuales (no compartidos) de un usuario este mes
    func getIndividualExpenses(userId: UUID, coupleId: UUID) -> Decimal {
        let now = Date()
        let startOfMonth = now.startOfMonth
        let endOfMonth = now.endOfMonth

        return mockTransactions.filter {
            $0.userId == userId &&
            $0.coupleId == coupleId &&
            $0.type == .expense &&
            !$0.isShared &&
            $0.date >= startOfMonth &&
            $0.date <= endOfMonth
        }.reduce(Decimal.zero) { $0 + $1.amount }
    }

    /// Total de gastos compartidos de la pareja este mes
    func getSharedExpensesTotal(coupleId: UUID) -> Decimal {
        let now = Date()
        let startOfMonth = now.startOfMonth
        let endOfMonth = now.endOfMonth

        return mockTransactions.filter {
            $0.coupleId == coupleId &&
            $0.type == .expense &&
            $0.isShared &&
            $0.date >= startOfMonth &&
            $0.date <= endOfMonth
        }.reduce(Decimal.zero) { $0 + $1.amount }
    }

    // MARK: - Seed Trips & Expenses

    private func seedTripsAndExpenses() {
        let now = Date()
        let cal = Calendar.current

        let tripId = UUID()
        let catHospedajeId = UUID()
        let catComidaId = UUID()
        let catTransporteId = UUID()
        let catActividadesId = UUID()
        let catComprasId = UUID()

        mockTrips = [
            Trip(
                id: tripId,
                coupleId: coupleUUID,
                name: "Fin de semana en Cartagena",
                emoji: "🏖️",
                destination: "Cartagena",
                startDate: cal.date(byAdding: .day, value: -3, to: now) ?? now,
                endDate: cal.date(byAdding: .day, value: 2, to: now) ?? now,
                totalBudget: 2500000,
                currency: "COP",
                status: .active,
                categories: [
                    TripBudgetCategory(id: catHospedajeId, name: "Hospedaje", emoji: "🏨", budgetAmount: 800000, spentAmount: 650000),
                    TripBudgetCategory(id: catComidaId, name: "Comida", emoji: "🍽️", budgetAmount: 600000, spentAmount: 205000),
                    TripBudgetCategory(id: catTransporteId, name: "Transporte", emoji: "🚕", budgetAmount: 400000, spentAmount: 45000),
                    TripBudgetCategory(id: catActividadesId, name: "Actividades", emoji: "🎯", budgetAmount: 500000, spentAmount: 0),
                    TripBudgetCategory(id: catComprasId, name: "Compras", emoji: "🛍️", budgetAmount: 200000, spentAmount: 0),
                ],
                isShared: true,
                savingsMode: .alreadyHave,
                monthlySavingsAmount: 0,
                currentSaved: 2500000,
                linkedTransactionId: nil,
                createdAt: cal.date(byAdding: .day, value: -5, to: now) ?? now
            ),
        ]

        mockTripExpenses = [
            TripExpense(id: UUID(), tripId: tripId, userId: devUserId, amount: 650000, currency: "COP", categoryId: catHospedajeId, merchant: "Hotel Caribe", date: cal.date(byAdding: .day, value: -3, to: now) ?? now, createdAt: now),
            TripExpense(id: UUID(), tripId: tripId, userId: partnerUserId, amount: 85000, currency: "COP", categoryId: catComidaId, merchant: "Restaurante La Cevicheria", date: cal.date(byAdding: .day, value: -2, to: now) ?? now, createdAt: now),
            TripExpense(id: UUID(), tripId: tripId, userId: devUserId, amount: 45000, currency: "COP", categoryId: catTransporteId, merchant: "Uber al centro", date: cal.date(byAdding: .day, value: -2, to: now) ?? now, createdAt: now),
            TripExpense(id: UUID(), tripId: tripId, userId: devUserId, amount: 120000, currency: "COP", categoryId: catComidaId, merchant: "Cena en la playa", date: cal.date(byAdding: .day, value: -1, to: now) ?? now, createdAt: now),
        ]
    }

    // MARK: - Seed Challenges

    private func seedChallenges() {
        let now = Date()
        let cal = Calendar.current

        mockChallenges = [
            FinancialChallenge(
                id: UUID(), coupleId: coupleUUID,
                name: "Semana sin domicilios",
                description: "No pidan comida a domicilio por 7 dias. Cocinen en casa.",
                type: .noSpend, metric: .days, targetValue: 7, currentValue: 4,
                difficulty: .easy, status: .active,
                startDate: cal.date(byAdding: .day, value: -4, to: now) ?? now,
                endDate: cal.date(byAdding: .day, value: 3, to: now) ?? now,
                category: .food, xpReward: 50,
                createdAt: cal.date(byAdding: .day, value: -4, to: now) ?? now
            ),
        ]
    }

    // MARK: - Seed Score History

    private func seedScoreHistory() {
        let cal = Calendar.current
        let now = Date()
        var history: [FinancialScore] = []

        // Generate 30 days of score data with realistic fluctuation
        var baseScore = 58
        for daysAgo in stride(from: 29, through: 0, by: -1) {
            let date = cal.date(byAdding: .day, value: -daysAgo, to: now)!
            // Random walk with slight upward trend
            let delta = Int.random(in: -4...5)
            baseScore = min(100, max(10, baseScore + delta))

            let trend: ScoreTrend = delta > 0 ? .up : delta < 0 ? .down : .stable

            let breakdown = ScoreBreakdown(
                budgetAdherence: min(100, max(0, baseScore + Int.random(in: -15...15))),
                savingsRate: min(100, max(0, baseScore + Int.random(in: -20...10))),
                debtManagement: min(100, max(0, baseScore + Int.random(in: -10...20))),
                transactionConsistency: min(100, max(0, baseScore + Int.random(in: -5...15))),
                goalProgress: min(100, max(0, baseScore + Int.random(in: -15...15))),
                spendingDiversity: min(100, max(0, baseScore + Int.random(in: -10...10)))
            )

            history.append(FinancialScore(
                id: UUID(),
                coupleId: coupleUUID,
                score: baseScore,
                breakdown: breakdown,
                trend: trend,
                tips: [],
                calculatedAt: date
            ))
        }
        mockScoreHistory = history
    }

    // MARK: - Seed Debts

    private func seedDebts() {
        let now = Date()
        let cal = Calendar.current

        mockDebts = [
            Debt(
                id: UUID(),
                coupleId: coupleUUID,
                fromUserId: partnerUserId,  // Sofi le debe a Rafa
                toUserId: devUserId,
                concept: "Cena del viernes",
                amount: 65_000,
                isPaid: false,
                paidAt: nil,
                createdAt: cal.date(byAdding: .day, value: -3, to: now)!,
                updatedAt: now
            ),
            Debt(
                id: UUID(),
                coupleId: coupleUUID,
                fromUserId: devUserId,  // Rafa le debe a Sofi
                toUserId: partnerUserId,
                concept: "Mitad del super",
                amount: 220_000,
                isPaid: false,
                paidAt: nil,
                createdAt: cal.date(byAdding: .day, value: -5, to: now)!,
                updatedAt: now
            ),
            Debt(
                id: UUID(),
                coupleId: coupleUUID,
                fromUserId: partnerUserId,  // Sofi le debe a Rafa
                toUserId: devUserId,
                concept: "Uber compartido",
                amount: 28_000,
                isPaid: true,
                paidAt: cal.date(byAdding: .day, value: -1, to: now),
                createdAt: cal.date(byAdding: .day, value: -7, to: now)!,
                updatedAt: cal.date(byAdding: .day, value: -1, to: now)!
            ),
            Debt(
                id: UUID(),
                coupleId: coupleUUID,
                fromUserId: devUserId,  // Rafa le debe a Sofi
                toUserId: partnerUserId,
                concept: "Regalo para mama",
                amount: 92_000,
                isPaid: false,
                paidAt: nil,
                createdAt: cal.date(byAdding: .day, value: -2, to: now)!,
                updatedAt: now
            ),
        ]
    }

    // MARK: - Debt Mock Methods

    func getMockDebts(coupleId: UUID) -> [Debt] {
        mockDebts
            .filter { $0.coupleId == coupleId }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func addMockDebt(_ debt: Debt) -> Debt {
        defer { saveAll() }
        mockDebts.append(debt)
        return debt
    }

    func updateMockDebt(_ debt: Debt) {
        defer { saveAll() }
        if let idx = mockDebts.firstIndex(where: { $0.id == debt.id }) {
            mockDebts[idx] = debt
        }
    }

    func deleteMockDebt(id: UUID) {
        defer { saveAll() }
        mockDebts.removeAll { $0.id == id }
    }

    func markDebtAsPaid(id: UUID) {
        defer { saveAll() }
        if let idx = mockDebts.firstIndex(where: { $0.id == id }) {
            mockDebts[idx].isPaid = true
            mockDebts[idx].paidAt = Date()
            mockDebts[idx].updatedAt = Date()
        }
    }

    /// Calcula el balance neto de todas las deudas pendientes.
    /// Retorna (deudorId, acreedorId, montoNeto).
    func getNetBalance() -> (owerId: UUID, owedId: UUID, netAmount: Decimal) {
        // Positive means devUser owes partner, negative means partner owes devUser
        var devUserOwes: Decimal = 0

        for debt in mockDebts where !debt.isPaid {
            if debt.fromUserId == devUserId {
                // devUser owes partner
                devUserOwes += debt.amount
            } else {
                // partner owes devUser
                devUserOwes -= debt.amount
            }
        }

        if devUserOwes >= 0 {
            return (owerId: devUserId, owedId: partnerUserId, netAmount: devUserOwes)
        } else {
            return (owerId: partnerUserId, owedId: devUserId, netAmount: -devUserOwes)
        }
    }

    // MARK: - Trip Mock Methods

    func getMockTrips(coupleId: UUID) -> [Trip] {
        mockTrips.filter { $0.coupleId == coupleId }.sorted { $0.startDate > $1.startDate }
    }

    func addMockTrip(_ trip: Trip) -> Trip {
        defer { saveAll() }
        mockTrips.append(trip)
        return trip
    }

    func updateMockTrip(_ trip: Trip) {
        defer { saveAll() }
        if let idx = mockTrips.firstIndex(where: { $0.id == trip.id }) {
            mockTrips[idx] = trip
        }
    }

    func deleteMockTrip(id: UUID) {
        defer { saveAll() }
        mockTrips.removeAll { $0.id == id }
        mockTripExpenses.removeAll { $0.tripId == id }
    }

    // MARK: - Trip Expense Mock Methods

    func getMockTripExpenses(tripId: UUID) -> [TripExpense] {
        mockTripExpenses.filter { $0.tripId == tripId }.sorted { $0.date > $1.date }
    }

    func addMockTripExpense(_ expense: TripExpense) -> TripExpense {
        defer { saveAll() }
        mockTripExpenses.append(expense)
        // Update trip category spent
        if let tripIdx = mockTrips.firstIndex(where: { $0.id == expense.tripId }),
           let catIdx = mockTrips[tripIdx].categories.firstIndex(where: { $0.id == expense.categoryId }) {
            mockTrips[tripIdx].categories[catIdx].spentAmount += expense.amount
        }
        return expense
    }

    func updateMockTripExpense(_ expense: TripExpense) {
        defer { saveAll() }
        if let idx = mockTripExpenses.firstIndex(where: { $0.id == expense.id }) {
            mockTripExpenses[idx] = expense
        }
    }

    func deleteMockTripExpense(id: UUID) {
        defer { saveAll() }
        mockTripExpenses.removeAll { $0.id == id }
    }

    // MARK: - Challenge Mock Methods

    func getMockChallenges(coupleId: UUID) -> [FinancialChallenge] {
        mockChallenges.filter { $0.coupleId == coupleId }.sorted { $0.startDate > $1.startDate }
    }

    func addMockChallenge(_ challenge: FinancialChallenge) -> FinancialChallenge {
        defer { saveAll() }
        mockChallenges.append(challenge)
        return challenge
    }

    func updateMockChallenge(_ challenge: FinancialChallenge) {
        defer { saveAll() }
        if let idx = mockChallenges.firstIndex(where: { $0.id == challenge.id }) {
            mockChallenges[idx] = challenge
        }
    }

    func deleteMockChallenge(id: UUID) {
        defer { saveAll() }
        mockChallenges.removeAll { $0.id == id }
    }

    // MARK: - Simulation Mock Methods

    func getMockSimulations(coupleId: UUID) -> [Simulation] {
        mockSimulations.filter { $0.coupleId == coupleId }.sorted { $0.createdAt > $1.createdAt }
    }

    func addMockSimulation(_ simulation: Simulation) -> Simulation {
        defer { saveAll() }
        mockSimulations.append(simulation)
        return simulation
    }

    func updateMockSimulation(_ simulation: Simulation) {
        defer { saveAll() }
        if let idx = mockSimulations.firstIndex(where: { $0.id == simulation.id }) {
            mockSimulations[idx] = simulation
        }
    }

    func deleteMockSimulation(id: UUID) {
        defer { saveAll() }
        mockSimulations.removeAll { $0.id == id }
    }

    // MARK: - Financial Score Calculation

    func calculateFinancialScore(coupleId: UUID) -> FinancialScore {
        let now = Date()
        let cal = Calendar.current

        // --- Budget Adherence (0-100) ---
        let activeBudgets = mockBudgets.filter { $0.coupleId == coupleId && $0.isActive }
        let budgetAdherence: Int
        if activeBudgets.isEmpty {
            budgetAdherence = 50 // Neutral if no budgets
        } else {
            let withinBudget = activeBudgets.filter { !$0.isOverBudget }.count
            budgetAdherence = min(100, (withinBudget * 100) / activeBudgets.count)
        }

        // --- Savings Rate (0-100) ---
        let monthTxs = mockTransactions.filter {
            $0.coupleId == coupleId &&
            cal.isDate($0.date, equalTo: now, toGranularity: .month)
        }
        let monthIncome = monthTxs.filter { $0.type == .income }.reduce(Decimal.zero) { $0 + $1.amount }
        let monthExpenses = monthTxs.filter { $0.type == .expense }.reduce(Decimal.zero) { $0 + $1.amount }
        let savingsRate: Int
        if monthIncome > 0 {
            let savings = max(monthIncome - monthExpenses, 0)
            let rate = Int(NSDecimalNumber(decimal: savings / monthIncome * 100).doubleValue.rounded())
            savingsRate = min(100, max(0, rate))
        } else {
            savingsRate = 30 // Low score when no income tracked
        }

        // --- Debt Management (0-100) ---
        let coupleDebts = mockDebts.filter { $0.coupleId == coupleId }
        let unpaidDebts = coupleDebts.filter { !$0.isPaid }
        let paidDebts = coupleDebts.filter { $0.isPaid }
        let debtManagement: Int
        if coupleDebts.isEmpty {
            debtManagement = 80 // Good if no debts at all
        } else if unpaidDebts.isEmpty {
            debtManagement = 100
        } else {
            let paidRatio = Double(paidDebts.count) / Double(coupleDebts.count)
            debtManagement = min(100, max(0, Int(paidRatio * 100)))
        }

        // --- Transaction Consistency (0-100) ---
        let streakDays = mockProfile?.streakDays ?? 0
        let transactionConsistency = min(100, max(0, streakDays * 14)) // 7 days = 98%

        // --- Goal Progress (0-100) ---
        let activeGoals = mockSavingsGoals.filter { $0.coupleId == coupleId && $0.status == .active }
        let goalProgress: Int
        if activeGoals.isEmpty {
            goalProgress = 40 // Neutral-low if no goals
        } else {
            let avgProgress = activeGoals.reduce(0.0) { $0 + $1.progress } / Double(activeGoals.count)
            goalProgress = min(100, max(0, Int(avgProgress * 100)))
        }

        // --- Spending Diversity (0-100) ---
        let expenseTxs = monthTxs.filter { $0.type == .expense }
        let categoriesUsed = Set(expenseTxs.map(\.category)).count
        let spendingDiversity = min(100, max(0, categoriesUsed * 15)) // 7+ categories = ~100

        let breakdown = ScoreBreakdown(
            budgetAdherence: budgetAdherence,
            savingsRate: savingsRate,
            debtManagement: debtManagement,
            transactionConsistency: transactionConsistency,
            goalProgress: goalProgress,
            spendingDiversity: spendingDiversity
        )

        // Determine trend
        let trend: ScoreTrend
        if let lastScore = mockScoreHistory.last {
            if breakdown.overall > lastScore.score + 3 {
                trend = .up
            } else if breakdown.overall < lastScore.score - 3 {
                trend = .down
            } else {
                trend = .stable
            }
        } else {
            trend = .stable
        }

        // Generate tips
        var tips: [String] = []
        if budgetAdherence < 60 {
            tips.append("Varios de tus presupuestos estan excedidos. Revisa tus categorias de mayor gasto.")
        }
        if savingsRate < 40 {
            tips.append("Tu tasa de ahorro es baja. Intenta ahorrar al menos el 20% de tus ingresos.")
        }
        if debtManagement < 60 {
            tips.append("Tienes deudas pendientes con tu pareja. Liquidarlas mejorara tu score.")
        }
        if transactionConsistency < 50 {
            tips.append("Registra tus gastos diariamente para mejorar tu consistencia financiera.")
        }
        if goalProgress < 50 {
            tips.append("Contribuye regularmente a tus metas de ahorro para avanzar mas rapido.")
        }
        if spendingDiversity < 50 {
            tips.append("Tus gastos estan muy concentrados. Diversifica para tener un presupuesto mas saludable.")
        }
        if tips.isEmpty {
            tips.append("Vas muy bien! Mantén tus buenos habitos financieros.")
        }

        return FinancialScore(
            id: UUID(),
            coupleId: coupleId,
            score: breakdown.overall,
            breakdown: breakdown,
            trend: trend,
            tips: tips,
            calculatedAt: now
        )
    }

    // MARK: - Day Financial Summaries (Calendar)

    /// Retorna los resumenes diarios del mes para la pareja.
    /// Si se pasa `userId`, filtra solo transacciones de ese usuario (modo individual).
    func getDayFinancialSummaries(month: Date, coupleId: UUID, userId: UUID? = nil) -> [DayFinancialSummary] {
        let cal = Calendar.current
        let startOfMonth = month.startOfMonth
        let range = cal.range(of: .day, in: .month, for: month) ?? 1..<31

        // Get transactions for the month
        let monthTxs = mockTransactions.filter { tx in
            (tx.coupleId == coupleId || tx.coupleId == nil) &&
            cal.isDate(tx.date, equalTo: month, toGranularity: .month) &&
            !tx.isRecurring &&
            (userId == nil || tx.userId == userId)
        }

        // Group by day
        var dayMap: [Int: [Transaction]] = [:]
        for tx in monthTxs {
            let day = cal.component(.day, from: tx.date)
            dayMap[day, default: []].append(tx)
        }

        // Calculate average daily expenses for heat level reference
        let totalExpenses = monthTxs.filter { $0.type == .expense }.reduce(Decimal.zero) { $0 + $1.amount }
        let avgDailyExpense = range.count > 0 ? totalExpenses / Decimal(range.count) : 1

        var summaries: [DayFinancialSummary] = []

        for day in range {
            guard let date = cal.date(bySetting: .day, value: day, of: startOfMonth) else { continue }

            let transactions = dayMap[day] ?? []
            let income = transactions.filter { $0.type == .income }.reduce(Decimal.zero) { $0 + $1.amount }
            let expenses = transactions.filter { $0.type == .expense }.reduce(Decimal.zero) { $0 + $1.amount }
            let topCategory = transactions
                .filter { $0.type == .expense }
                .reduce(into: [TransactionCategory: Decimal]()) { $0[$1.category, default: 0] += $1.amount }
                .max { $0.value < $1.value }?.key

            let heatLevel: HeatLevel
            if transactions.isEmpty {
                heatLevel = .none
            } else if avgDailyExpense > 0 {
                let ratio = NSDecimalNumber(decimal: expenses / avgDailyExpense).doubleValue
                switch ratio {
                case ..<0.5: heatLevel = .low
                case 0.5..<1.5: heatLevel = .medium
                case 1.5..<2.5: heatLevel = .high
                default: heatLevel = .extreme
                }
            } else {
                heatLevel = expenses > 0 ? .medium : .low
            }

            summaries.append(DayFinancialSummary(
                id: UUID(),
                date: date,
                totalIncome: income,
                totalExpenses: expenses,
                transactionCount: transactions.count,
                heatLevel: heatLevel,
                topCategory: topCategory,
                transactions: transactions.sorted { $0.date > $1.date }
            ))
        }

        return summaries
    }

    // MARK: - Relationship Duration

    /// Calcula la duracion de la relacion basado en relationshipStartDate del perfil.
    /// Retorna un string como "2 anos, 10 meses".
    func getRelationshipDuration() -> String {
        guard let startDate = mockProfile.relationshipStartDate else {
            return "Sin fecha de inicio"
        }

        let cal = Calendar.current
        let components = cal.dateComponents([.year, .month], from: startDate, to: Date())

        let years = components.year ?? 0
        let months = components.month ?? 0

        if years == 0 && months == 0 {
            return "Menos de un mes"
        } else if years == 0 {
            return months == 1 ? "1 mes" : "\(months) meses"
        } else if months == 0 {
            return years == 1 ? "1 ano" : "\(years) anos"
        } else {
            let yearStr = years == 1 ? "1 ano" : "\(years) anos"
            let monthStr = months == 1 ? "1 mes" : "\(months) meses"
            return "\(yearStr), \(monthStr)"
        }
    }
}
