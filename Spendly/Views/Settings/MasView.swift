import SwiftUI

struct MasView: View {

    let userId: UUID
    let coupleId: UUID?
    @Bindable var authViewModel: AuthViewModel

    @State private var preferences = AppPreferences.shared
    @State private var notificationsEnabled = true
    @State private var showProfileEdit = false
    @State private var showSupportAlert = false
    @State private var supportAlertTitle = ""
    @State private var supportAlertMessage = ""
    @State private var showDeleteConfirmation = false
    @State private var showDeleteFinalConfirmation = false
    @State private var showPhantomPartner = false
    @State private var phantomTapCount = 0
    @State private var phantomName = ""
    @State private var phantomIncome = ""
    @State private var phantomGender = "Femenino"

    private let mockData = MockDataService.shared

    private var lang: AppLanguage { preferences.language }

    var body: some View {
        NavigationStack {
            List {
                profileHeaderSection
                tutorialSection
                financesSection
                configSection
                supportSection
                aboutSection
                dangerSection
            }
            .navigationTitle(L10n.t("mas_title", lang))
            .trackCurrency()
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(L10n.t("mas_title", lang))
                        .font(.headline)
                        .onTapGesture(count: 3) {
                            showPhantomPartner = true
                        }
                }
            }
            .sheet(isPresented: $showPhantomPartner) {
                phantomPartnerSheet
            }
            .sheet(isPresented: $showProfileEdit) {
                ProfileEditSheet(
                    profile: mockData.mockProfile,
                    hasPartner: mockData.mockPartnerProfile != nil,
                    onSave: { updatedProfile in
                        mockData.mockProfile = updatedProfile
                    }
                )
            }
            .alert(supportAlertTitle, isPresented: $showSupportAlert) {
                Button(L10n.t("mas_understood", lang), role: .cancel) { }
            } message: {
                Text(supportAlertMessage)
            }
            .alert(L10n.t("mas_delete_account", lang), isPresented: $showDeleteConfirmation) {
                Button(L10n.t("cancel", lang), role: .cancel) { }
                Button(L10n.t("mas_continue", lang), role: .destructive) {
                    showDeleteFinalConfirmation = true
                }
            } message: {
                Text(L10n.t("mas_delete_confirm", lang))
            }
            .alert(L10n.t("mas_continue", lang), isPresented: $showDeleteFinalConfirmation) {
                Button(L10n.t("cancel", lang), role: .cancel) { }
                Button(L10n.t("mas_delete_final_button", lang), role: .destructive) {
                    clearAllDataAndSignOut()
                }
            } message: {
                Text(L10n.t("mas_delete_final", lang))
            }
        }
    }

    // MARK: - Sign Out (clears ALL MockDataService state)

    private func clearAllDataAndSignOut() {
        Task { await authViewModel.signOut() }
    }

    // MARK: - Profile Header Section

    private var profileHeaderSection: some View {
        Section {
            Button {
                showProfileEdit = true
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        profileAvatar(name: mockData.mockProfile.displayName, size: 48)
                        if let partner = mockData.mockPartnerProfile {
                            profileAvatar(name: partner.displayName, size: 36)
                                .offset(x: 22, y: 16)
                                .overlay(
                                    Circle()
                                        .stroke(Color(.systemBackground), lineWidth: 2)
                                        .frame(width: 38, height: 38)
                                        .offset(x: 22, y: 16)
                                )
                        }
                    }
                    .frame(width: 70)

                    VStack(alignment: .leading, spacing: 4) {
                        if let partner = mockData.mockPartnerProfile {
                            Text("💕 \(mockData.mockProfile.displayName) & \(partner.displayName)")
                                .font(.headline)
                                .foregroundStyle(Color(.label))
                        } else {
                            Text(mockData.mockProfile.displayName)
                                .font(.headline)
                                .foregroundStyle(Color(.label))
                        }

                        Text(mockData.mockProfile.email)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if mockData.mockPartnerProfile != nil {
                            Text("🕐 \(mockData.getRelationshipDuration()) \(L10n.t("mas_relationship_duration", lang))")
                                .font(.caption2)
                                .foregroundStyle(Color.fingetherRose)
                        }
                    }

                    Spacer()

                    Image(systemName: "pencil.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color.fingetherPrimary)
                }
                .padding(.vertical, 8)
            }
        }
    }

    // MARK: - Tutorial Section (destacado)

    private var tutorialSection: some View {
        Section {
            NavigationLink {
                TutorialListView()
            } label: {
                tutorialCardLabel
            }
            .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
            .listRowBackground(Color.clear)
        }
    }

    private var tutorialCardLabel: some View {
        // Read live progress from a fresh view model so the card reflects current state.
        let vm = TutorialViewModel()
        let total = vm.totalCount
        let done = vm.completedCount
        let pct = vm.progress

        return HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.18))
                    .frame(width: 52, height: 52)
                Text("📖")
                    .font(.system(size: 28))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.t("tutorial_card_title", lang))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(L10n.t("tutorial_card_subtitle", lang))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(2)

                // Mini progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.25))
                            .frame(height: 5)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white)
                            .frame(width: max(geo.size.width * CGFloat(pct), 4), height: 5)
                    }
                }
                .frame(height: 5)
                .padding(.top, 2)

                Text("\(done)/\(total)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.95))
            }

            Spacer(minLength: 4)

            Image(systemName: "chevron.right")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white.opacity(0.9))
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [Color.fingetherPrimary, Color.fingetherPrimaryDark],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: Color.fingetherPrimary.opacity(0.3), radius: 12, y: 6)
    }

    // MARK: - Finances Section

    private var financesSection: some View {
        Section {
            if let cid = coupleId {
                NavigationLink {
                    AchievementListView(coupleId: cid)
                } label: {
                    Label {
                        Text(L10n.t("mas_achievements", lang))
                    } icon: {
                        Text("🏆")
                    }
                }

                NavigationLink {
                    InsightsView(coupleId: cid)
                } label: {
                    Label {
                        Text(L10n.t("mas_insights", lang))
                    } icon: {
                        Text("🤖")
                    }
                }

                NavigationLink {
                    SimulatorView(coupleId: cid)
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("¿Qué pasaría si...?")
                            Text("Simula escenarios y toma mejores decisiones")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Text("🔮")
                    }
                }

                NavigationLink {
                    CreditSimulatorView()
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Calculadora de crédito")
                            Text("Calcula cuotas, intereses y amortización")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Text("🏦")
                    }
                }

                NavigationLink {
                    FinancialCalendarView(coupleId: cid)
                } label: {
                    Label {
                        Text("Calendario financiero")
                    } icon: {
                        Text("📅")
                    }
                }

                NavigationLink {
                    ScoreView(coupleId: cid, userId: userId)
                } label: {
                    Label {
                        Text("Score Fingether")
                    } icon: {
                        Text("🏆")
                    }
                }

                // C7: Money Date (couple-only)
                if preferences.isCoupleMode {
                    NavigationLink {
                        MoneyDateView(coupleId: cid)
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("💕 Money Date")
                                Text("Revisen sus finanzas juntos este mes")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Text("❤️")
                        }
                    }
                }

                // C6: Referral Program
                NavigationLink {
                    ReferralView()
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Invitar amigos")
                            Text("Ambas parejas reciben 1 mes gratis")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Text("🎁")
                    }
                }
            } else {
                Text(L10n.t("mas_link_partner", lang))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text(L10n.t("mas_finances", lang))
        }
    }

    // MARK: - Config Section

    private var configSection: some View {
        Section {
            // P4: el toggle individual/pareja vive SOLO en el Dashboard ahora.
            // Esta seccion antes lo mostraba aqui tambien y confundia. Eliminado.

            Picker(selection: $preferences.currency) {
                ForEach(AppPreferences.AppCurrency.allCases, id: \.self) { currency in
                    Text(currency.displayName).tag(currency)
                }
            } label: {
                Label {
                    Text(L10n.t("mas_currency", lang))
                } icon: {
                    Text("💱")
                }
            }

            Picker(selection: $preferences.theme) {
                ForEach(AppPreferences.AppTheme.allCases, id: \.self) { theme in
                    Text(theme.displayName).tag(theme)
                }
            } label: {
                Label {
                    Text(L10n.t("mas_theme", lang))
                } icon: {
                    Text("🎨")
                }
            }

            // C4: 3 granular notification toggles
            Toggle(isOn: $preferences.notificationsMorning) {
                Label { Text("Resumen matutino (7 AM)") } icon: { Text("☀️") }
            }.tint(Color.fingetherPrimary)

            Toggle(isOn: $preferences.notificationsPartnerSpend) {
                Label { Text("Gastos de tu pareja") } icon: { Text("💕") }
            }.tint(Color.fingetherPrimary)

            Toggle(isOn: $preferences.notificationsEvening) {
                Label { Text("Resumen nocturno (8 PM)") } icon: { Text("🌙") }
            }.tint(Color.fingetherPrimary)

            Toggle(isOn: $notificationsEnabled) {
                Label {
                    Text(L10n.t("mas_notifications", lang))
                } icon: {
                    Text("🔔")
                }
            }
            .tint(Color.fingetherPrimary)

            Picker(selection: $preferences.language) {
                ForEach(AppLanguage.allCases, id: \.self) { language in
                    HStack {
                        Text(language.flag)
                        Text(language.displayName)
                    }.tag(language)
                }
            } label: {
                Label {
                    Text(L10n.t("mas_language", lang))
                } icon: {
                    Text("🌐")
                }
            }
        } header: {
            Text(L10n.t("mas_config", lang))
        }
    }

    // MARK: - Support Section

    private var supportSection: some View {
        Section {
            NavigationLink {
                FAQView()
            } label: {
                Label {
                    Text(L10n.t("mas_faq", lang))
                } icon: {
                    Text("❓")
                }
            }

            NavigationLink {
                ContactSupportView()
            } label: {
                Label {
                    Text(L10n.t("mas_contact", lang))
                } icon: {
                    Text("📧")
                }
            }

            NavigationLink {
                TermsView()
            } label: {
                Label {
                    Text(L10n.t("mas_terms", lang))
                } icon: {
                    Text("📄")
                }
            }

            NavigationLink {
                PrivacyPolicyView()
            } label: {
                Label {
                    Text(L10n.t("mas_privacy", lang))
                } icon: {
                    Text("🔒")
                }
            }
        } header: {
            Text(L10n.t("mas_support", lang))
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        Section {
            HStack {
                Text(L10n.t("mas_version", lang))
                Spacer()
                Text("1.0.0")
                    .foregroundStyle(.secondary)
            }

            HStack {
                Spacer()
                Text(L10n.t("mas_made_with_love", lang))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        } header: {
            Text(L10n.t("mas_about", lang))
        }
    }

    // MARK: - Danger Section

    private var dangerSection: some View {
        Section {
            Button {
                clearAllDataAndSignOut()
            } label: {
                HStack {
                    Text("🚪")
                    Text(L10n.t("mas_sign_out", lang))
                        .foregroundStyle(Color.fingetherDanger)
                }
            }

            Button {
                showDeleteConfirmation = true
            } label: {
                HStack {
                    Text("🗑️")
                    Text(L10n.t("mas_delete_account", lang))
                        .foregroundStyle(Color.fingetherDanger)
                }
            }
        }
    }

    // MARK: - Phantom Partner Sheet

    private var phantomPartnerSheet: some View {
        NavigationStack {
            Form {
                if mockData.mockPartnerProfile != nil {
                    Section {
                        HStack {
                            Text("👻 Pareja actual")
                            Spacer()
                            Text(mockData.mockPartnerProfile?.displayName ?? "")
                                .foregroundStyle(.secondary)
                        }
                        Button(role: .destructive) {
                            mockData.removePhantomPartner()
                            preferences.isCoupleMode = false
                            showPhantomPartner = false
                        } label: {
                            Label("Eliminar pareja fantasma", systemImage: "trash")
                        }
                    }
                } else {
                    Section("Crear pareja fantasma") {
                        TextField("Nombre de la pareja", text: $phantomName)
                        HStack {
                            Text("$")
                                .foregroundStyle(Color.fingetherPrimary)
                            TextField("Ingreso mensual", text: $phantomIncome)
                                .keyboardType(.numberPad)
                                .onChange(of: phantomIncome) { _, val in
                                    phantomIncome = formatWithThousands(val)
                                }
                        }
                        Picker("Genero", selection: $phantomGender) {
                            Text("Femenino").tag("Femenino")
                            Text("Masculino").tag("Masculino")
                            Text("No binario").tag("No binario")
                        }
                    }

                    Section {
                        Button {
                            let income = Decimal(string: phantomIncome.filter(\.isNumber)) ?? 0
                            guard !phantomName.isEmpty, income > 0 else { return }
                            mockData.createPhantomPartner(
                                name: phantomName.trimmingCharacters(in: .whitespacesAndNewlines),
                                monthlyIncome: income,
                                gender: phantomGender
                            )
                            preferences.isCoupleMode = true
                            showPhantomPartner = false
                        } label: {
                            HStack {
                                Image(systemName: "person.badge.plus")
                                Text("Crear pareja")
                            }
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.fingetherPrimary, in: RoundedRectangle(cornerRadius: 12))
                        }
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    }
                }
            }
            .navigationTitle("👻 Pareja Fantasma")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cerrar") { showPhantomPartner = false }
                }
            }
        }
    }

    // MARK: - Helpers

    private func profileAvatar(name: String, size: CGFloat) -> some View {
        let initial = String(name.prefix(1)).uppercased()
        return ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.fingetherPrimary, Color.fingetherRose],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)

            Text(initial)
                .font(.system(size: size * 0.4, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
    }
}

// MARK: - Profile Edit Sheet

private struct ProfileEditSheet: View {

    @Environment(\.dismiss) private var dismiss

    // Personal info
    @State var name: String
    @State var dateOfBirth: Date
    @State var hasBirthDate: Bool
    @State var gender: String
    @State var city: String
    @State var country: String

    // Employment
    @State var occupation: String
    @State var employmentType: String
    @State var industry: String

    // Relationship
    @State var relationshipStatus: String
    @State var relationshipLength: String
    @State var liveTogether: Bool

    // Housing
    @State var housingType: String
    @State var hasChildren: Int

    // Financial
    @State var monthlyIncomeText: String
    @State var hasCreditCards: Bool
    @State var creditCardCount: Int
    @State var hasSavings: Bool
    @State var financialGoal: String

    let hasPartner: Bool
    let onSave: (Profile) -> Void

    private let profile: Profile

    // MARK: - Option Lists

    private let genderOptions = ["Masculino", "Femenino", "No binario", "Prefiero no decir"]

    private let employmentTypeOptions: [(label: String, value: String)] = [
        ("Sin especificar", ""),
        ("Empleado tiempo completo", "full_time"),
        ("Medio tiempo", "part_time"),
        ("Freelancer", "freelancer"),
        ("Empresario", "business_owner"),
        ("Desempleado", "unemployed"),
        ("Estudiante", "student"),
        ("Jubilado", "retired")
    ]

    private let industryOptions: [(label: String, value: String)] = [
        ("Sin especificar", ""),
        ("Tecnologia", "technology"),
        ("Salud", "health"),
        ("Educacion", "education"),
        ("Finanzas", "finance"),
        ("Comercio", "commerce"),
        ("Gobierno", "government"),
        ("Otro", "other")
    ]

    private let relationshipOptions: [(label: String, value: String)] = [
        ("Novios", "en_relacion"),
        ("Union libre", "union_libre"),
        ("Casados", "casado"),
        ("Otro", "otro")
    ]

    private let relationshipLengthOptions: [(label: String, value: String)] = [
        ("Sin especificar", ""),
        ("Menos de 1 ano", "less_1"),
        ("1-3 anos", "1_3"),
        ("3-5 anos", "3_5"),
        ("5-10 anos", "5_10"),
        ("Mas de 10 anos", "more_10")
    ]

    private let housingOptions: [(label: String, value: String)] = [
        ("Sin especificar", ""),
        ("Arriendo", "renting"),
        ("Propia (pagando)", "own_paying"),
        ("Propia (pagada)", "own_paid"),
        ("Familiar", "family"),
        ("Otro", "other")
    ]

    private let financialGoalOptions: [(label: String, value: String)] = [
        ("Sin especificar", ""),
        ("Ahorrar para emergencias", "emergency_fund"),
        ("Pagar deudas", "pay_debts"),
        ("Comprar vivienda", "buy_home"),
        ("Invertir", "invest"),
        ("Viajar", "travel"),
        ("Jubilacion", "retirement"),
        ("Otro", "other")
    ]

    private let childrenOptions: [(label: String, value: Int)] = [
        ("No", 0),
        ("1", 1),
        ("2", 2),
        ("3", 3),
        ("4+", 4)
    ]

    private let statusToRaw: [String: String] = [
        "Novios": "en_relacion",
        "Union libre": "union_libre",
        "Casados": "casado",
        "Otro": "otro"
    ]

    // MARK: - Init

    init(profile: Profile, hasPartner: Bool = false, onSave: @escaping (Profile) -> Void) {
        self.profile = profile
        self.hasPartner = hasPartner
        self.onSave = onSave

        _name = State(initialValue: profile.displayName)
        _hasBirthDate = State(initialValue: profile.dateOfBirth != nil)
        _dateOfBirth = State(initialValue: profile.dateOfBirth ?? Date())
        _gender = State(initialValue: profile.gender ?? "Prefiero no decir")
        _city = State(initialValue: profile.city ?? "")
        _country = State(initialValue: profile.country ?? "")

        // Employment
        _occupation = State(initialValue: profile.occupation ?? "")
        _employmentType = State(initialValue: profile.employmentType ?? "")
        _industry = State(initialValue: profile.industry ?? "")

        // Relationship
        let rawStatus = profile.relationshipStatus ?? "otro"
        let displayMap: [String: String] = [
            "en_relacion": "Novios",
            "union_libre": "Union libre",
            "casado": "Casados",
            "otro": "Otro",
            "soltero": "Otro"
        ]
        _relationshipStatus = State(initialValue: displayMap[rawStatus] ?? "Otro")
        _relationshipLength = State(initialValue: profile.relationshipLength ?? "")
        _liveTogether = State(initialValue: profile.liveTogether ?? false)

        // Housing
        _housingType = State(initialValue: profile.housingType ?? "")
        _hasChildren = State(initialValue: profile.hasChildren ?? 0)

        // Financial
        let incomeString = profile.monthlyIncome == 0 ? "" : "\(profile.monthlyIncome)"
        _monthlyIncomeText = State(initialValue: incomeString)
        _hasCreditCards = State(initialValue: profile.hasCreditCards ?? false)
        _creditCardCount = State(initialValue: profile.creditCardCount ?? 1)
        _hasSavings = State(initialValue: profile.hasSavings ?? false)
        _financialGoal = State(initialValue: profile.financialGoal ?? "")
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                personalInfoSection
                employmentSection
                if hasPartner {
                    relationshipSection
                }
                housingSection
                financialSection
            }
            .tint(Color.fingetherPrimary)
            .navigationTitle("Editar Perfil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        saveProfile()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.fingetherPrimary)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    // MARK: - Personal Info Section

    private var personalInfoSection: some View {
        Section {
            HStack {
                Text("Nombre")
                    .foregroundStyle(.secondary)
                Spacer()
                TextField("Tu nombre", text: $name)
                    .multilineTextAlignment(.trailing)
            }

            Toggle("Fecha de nacimiento", isOn: $hasBirthDate)
            if hasBirthDate {
                DatePicker("Seleccionar fecha", selection: $dateOfBirth, in: ...Date(), displayedComponents: .date)
                    .environment(\.locale, Locale(identifier: "es_MX"))
            }

            Picker("Genero", selection: $gender) {
                ForEach(genderOptions, id: \.self) { option in
                    Text(option).tag(option)
                }
            }

            HStack {
                Text("Pais")
                    .foregroundStyle(.secondary)
                Spacer()
                TextField("Opcional", text: $country)
                    .multilineTextAlignment(.trailing)
            }

            HStack {
                Text("Ciudad")
                    .foregroundStyle(.secondary)
                Spacer()
                TextField("Opcional", text: $city)
                    .multilineTextAlignment(.trailing)
            }
        } header: {
            Text("Informacion personal")
                .font(.subheadline.weight(.semibold))
        }
    }

    // MARK: - Employment Section

    private var employmentSection: some View {
        Section {
            HStack {
                Text("Ocupacion")
                    .foregroundStyle(.secondary)
                Spacer()
                TextField("Ej: Ingeniero, Disenadora...", text: $occupation)
                    .multilineTextAlignment(.trailing)
            }

            Picker("Tipo de empleo", selection: $employmentType) {
                ForEach(employmentTypeOptions, id: \.value) { option in
                    Text(option.label).tag(option.value)
                }
            }

            Picker("Industria", selection: $industry) {
                ForEach(industryOptions, id: \.value) { option in
                    Text(option.label).tag(option.value)
                }
            }
        } header: {
            HStack {
                Text("Situacion laboral")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("Opcional")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Relationship Section

    private var relationshipSection: some View {
        Section {
            Picker("Estado", selection: $relationshipStatus) {
                ForEach(relationshipOptions, id: \.value) { option in
                    Text(option.label).tag(option.label)
                }
            }

            Picker("Tiempo de relacion", selection: $relationshipLength) {
                ForEach(relationshipLengthOptions, id: \.value) { option in
                    Text(option.label).tag(option.value)
                }
            }

            Toggle("Viven juntos?", isOn: $liveTogether)
        } header: {
            Text("Relacion")
                .font(.subheadline.weight(.semibold))
        }
    }

    // MARK: - Housing Section

    private var housingSection: some View {
        Section {
            Picker("Tipo de vivienda", selection: $housingType) {
                ForEach(housingOptions, id: \.value) { option in
                    Text(option.label).tag(option.value)
                }
            }

            Picker("Tiene hijos?", selection: $hasChildren) {
                ForEach(childrenOptions, id: \.value) { option in
                    Text(option.label).tag(option.value)
                }
            }
        } header: {
            Text("Vivienda")
                .font(.subheadline.weight(.semibold))
        }
    }

    // MARK: - Financial Section

    private var financialSection: some View {
        Section {
            HStack {
                Text("Ingreso mensual")
                    .foregroundStyle(.secondary)
                Spacer()
                HStack(spacing: 4) {
                    Text("$")
                        .foregroundStyle(Color.fingetherPrimary)
                    TextField("0", text: $monthlyIncomeText)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 140)
                        .onChange(of: monthlyIncomeText) { _, val in
                            monthlyIncomeText = formatWithThousands(val)
                        }
                }
            }

            Toggle("Tiene tarjetas de credito?", isOn: $hasCreditCards)
            if hasCreditCards {
                Stepper("Cuantas? \(creditCardCount)", value: $creditCardCount, in: 1...10)
            }

            Toggle("Tiene ahorros?", isOn: $hasSavings)

            Picker("Objetivo financiero", selection: $financialGoal) {
                ForEach(financialGoalOptions, id: \.value) { option in
                    Text(option.label).tag(option.value)
                }
            }
        } header: {
            Text("Situacion financiera")
                .font(.subheadline.weight(.semibold))
        }
    }

    // MARK: - Save

    private func saveProfile() {
        var updated = profile
        updated.displayName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.dateOfBirth = hasBirthDate ? dateOfBirth : nil
        updated.gender = gender
        updated.city = city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : city.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.country = country.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : country.trimmingCharacters(in: .whitespacesAndNewlines)

        // Employment
        updated.occupation = occupation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : occupation.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.employmentType = employmentType.isEmpty ? nil : employmentType
        updated.industry = industry.isEmpty ? nil : industry

        // Relationship
        updated.relationshipStatus = statusToRaw[relationshipStatus] ?? "otro"
        updated.relationshipLength = relationshipLength.isEmpty ? nil : relationshipLength
        updated.liveTogether = liveTogether

        // Housing
        updated.housingType = housingType.isEmpty ? nil : housingType
        updated.hasChildren = hasChildren

        // Financial
        let incomeDigits = monthlyIncomeText.filter(\.isNumber)
        updated.monthlyIncome = Decimal(string: incomeDigits) ?? profile.monthlyIncome
        updated.hasCreditCards = hasCreditCards
        updated.creditCardCount = hasCreditCards ? creditCardCount : nil
        updated.hasSavings = hasSavings
        updated.financialGoal = financialGoal.isEmpty ? nil : financialGoal

        updated.updatedAt = Date()
        onSave(updated)
    }
}
