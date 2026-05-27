import SwiftUI

struct OnboardingView: View {
    @Bindable var authViewModel: AuthViewModel
    @State private var viewModel = OnboardingViewModel()
    @State private var preferences = AppPreferences.shared
    @State private var checkmarkScale: CGFloat = 0.3
    private let primary = Color.fingetherPrimary
    private let primaryDark = Color.fingetherPrimaryDark
    private let coral = Color.fingetherExpense
    private let individual = Color.fingetherSky
    private let gradientColors = [Color.fingetherPrimary, Color.fingetherPrimaryDark]
    @Environment(\.colorScheme) private var cs

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            VStack(spacing: 0) {
                if viewModel.currentStep > 0 { progressBar.padding(.top, 12).padding(.horizontal, 24) }
                Group { stepView(for: viewModel.currentStep) }
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                    .animation(.easeInOut(duration: 0.3), value: viewModel.currentStep).id(viewModel.currentStep)
                if let err = viewModel.errorMessage {
                    ErrorBanner(message: err) { viewModel.errorMessage = nil }.padding(.horizontal, 8).padding(.bottom, 4)
                }
                bottomButtons.padding(.horizontal, 24).padding(.bottom, 24)
            }
        }
    }

    private var progressBar: some View {
        HStack(spacing: 6) { ForEach(0..<viewModel.totalSteps, id: \.self) { i in Capsule().fill(i <= viewModel.currentStep ? primary : Color(.systemGray4)).frame(height: 4) } }
    }

    // MARK: - Step Router
    @ViewBuilder private func stepView(for step: Int) -> some View {
        if viewModel.wantsCoupleMode {
            switch step {
            case 0: welcomeStep; case 1: nameStep; case 2: countryCurrencyStep; case 3: coupleQuestionStep
            case 4: incomeStep; case 5: partnerDataStep; case 6: splitStep
            case 7: fixedStep(shared: true); case 8: fixedStep(shared: false)
            case 9: coupleBudgetStep; case 10: summaryStep; default: EmptyView()
            }
        } else {
            switch step {
            case 0: welcomeStep; case 1: nameStep; case 2: countryCurrencyStep
            case 3: if viewModel.coupleChoiceMade { incomeStep } else { coupleQuestionStep }
            case 4: incomeStep; case 5: fixedStep(shared: false)
            case 6: soloBudgetStep; case 7: summaryStep; default: EmptyView()
            }
        }
    }

    // MARK: - Welcome
    @State private var showWelcomeLogo = false; @State private var showBullets = false
    private let welcomeBullets: [(emoji: String, text: String)] = [
        ("💸", "Divide gastos justos, sin discutir"), ("📊", "Presupuesto inteligente que se calcula solo"),
        ("🎯", "Metas de ahorro en pareja o individual"), ("🧾", "Checklist de gastos fijos cada mes"),
        ("🤖", "Asesor financiero con inteligencia artificial"), ("✈️", "Planifica viajes con presupuesto real"),
        ("🏆", "Retos y logros para mejorar tus finanzas"), ("📅", "Calendario para ver tus patrones de gasto"),
    ]
    private var welcomeStep: some View {
        ZStack {
            LinearGradient(stops: [
                .init(color: cs == .dark ? Color(hex: "1E1B4B") : primary.opacity(0.15), location: 0),
                .init(color: cs == .dark ? Color(hex: "1A2840") : Color.fingetherSky.opacity(0.08), location: 0.5),
                .init(color: cs == .dark ? Color(hex: "1A1A2E") : Color(.systemGroupedBackground), location: 1)
            ], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    Spacer(minLength: 40)
                    ZStack {
                        Circle().fill(primary.opacity(0.12)).frame(width: 120, height: 120)
                        ZStack { Text("$").font(.system(size: 44, weight: .black, design: .rounded)).foregroundStyle(primary)
                            Image(systemName: "heart.fill").font(.system(size: 16, weight: .bold)).foregroundStyle(Color.fingetherRose).offset(x: 26, y: -26) }
                    }.scaleEffect(showWelcomeLogo ? 1.0 : 0.6).opacity(showWelcomeLogo ? 1 : 0)
                    VStack(spacing: 10) {
                        Text("Bienvenido a Fingether").font(.system(size: 28, weight: .bold, design: .rounded)).foregroundStyle(Color(.label))
                        Text("Las cuentas claras, el amor intacto ✨").font(.subheadline).foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(welcomeBullets.enumerated()), id: \.offset) { idx, b in
                            HStack(spacing: 14) { Text(b.emoji).font(.system(size: 24)); Text(b.text).font(.body).foregroundStyle(Color.fingetherSlate) }
                                .opacity(showBullets ? 1 : 0).offset(y: showBullets ? 0 : 8)
                                .animation(.easeOut(duration: 0.4).delay(0.5 + Double(idx) * 0.08), value: showBullets)
                        }
                    }.padding(.horizontal, 32)
                    Spacer(minLength: 100)
                }
            }
        }.onAppear { withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1)) { showWelcomeLogo = true }; showBullets = true }
    }

    // MARK: - Name
    private var nameStep: some View {
        VStack(spacing: 24) { Spacer(); stepIcon("person.fill"); Text("¿Cómo te llamas?").font(.title2.bold()).foregroundStyle(Color(.label))
            TextField("Tu nombre", text: $viewModel.displayName).font(.system(size: 20, weight: .medium)).textInputAutocapitalization(.words)
                .padding(16).background(Color(.secondarySystemGroupedBackground)).clipShape(RoundedRectangle(cornerRadius: 14)).padding(.horizontal, 24)
            Spacer(); Spacer() }
    }

    // MARK: - Country
    private var countryCurrencyStep: some View {
        ScrollView { VStack(spacing: 24) { Spacer(minLength: 20); stepIcon("globe.americas.fill")
            Text("¿De dónde eres?").font(.title2.bold()).foregroundStyle(Color(.label))
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(Country.allCases) { c in
                    Button { withAnimation { viewModel.selectCountry(c) } } label: {
                        HStack(spacing: 8) { Text(c.flag).font(.title2); Text(c.displayName).font(.subheadline.weight(.medium)).foregroundStyle(Color(.label)).lineLimit(1); Spacer()
                            if viewModel.selectedCountry == c { Image(systemName: "checkmark.circle.fill").foregroundStyle(primary) }
                        }.padding(12).background(viewModel.selectedCountry == c ? primary.opacity(0.08) : Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(viewModel.selectedCountry == c ? primary : .clear, lineWidth: 1.5))
                    }
                }
            }.padding(.horizontal, 24)
            HStack(spacing: 6) { Text("Moneda:").font(.subheadline).foregroundStyle(.secondary); Text(viewModel.currency.displayName).font(.subheadline.weight(.semibold)).foregroundStyle(primary) }
            Spacer(minLength: 80) } }
    }

    // MARK: - Couple Question
    private var coupleQuestionStep: some View {
        VStack(spacing: 24) { Spacer(); stepIcon("heart.fill"); Text("¿Manejan dinero juntos?").font(.title2.bold()).foregroundStyle(Color(.label))
            VStack(spacing: 16) {
                choiceCard(emoji: "👤", title: "Solo yo", sub: "Manejo mis finanzas individual", border: individual) { viewModel.chooseSoloMode() }
                choiceCard(emoji: "💕", title: "Con mi pareja", sub: "Dividimos gastos juntos", border: primary) { viewModel.chooseCoupleMode() }
            }.padding(.horizontal, 24); Spacer(); Spacer() }
    }
    private func choiceCard(emoji: String, title: String, sub: String, border: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) { HStack(spacing: 14) { Text(emoji).font(.system(size: 36)); VStack(alignment: .leading, spacing: 3) { Text(title).font(.headline).foregroundStyle(Color(.label)); Text(sub).font(.caption).foregroundStyle(.secondary) }; Spacer() }
            .padding(20).frame(minHeight: 80).background(Color(.secondarySystemGroupedBackground)).clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(border.opacity(0.4), lineWidth: 1.5)) }
    }

    // MARK: - Income
    private var incomeStep: some View {
        VStack(spacing: 24) { Spacer(); stepIcon("dollarsign.circle.fill"); Text("¿Cuánto ganas al mes?").font(.title2.bold()).foregroundStyle(Color(.label))
            HStack { Text(viewModel.currencySymbol()).font(.system(size: 28, weight: .bold)).foregroundStyle(primary)
                TextField("Tu ingreso mensual", text: $viewModel.monthlyIncome).font(.system(size: 24, weight: .semibold)).keyboardType(.numberPad)
                    .onChange(of: viewModel.monthlyIncome) { _, v in viewModel.monthlyIncome = formatWithThousands(v) }
            }.padding(16).background(Color(.secondarySystemGroupedBackground)).clipShape(RoundedRectangle(cornerRadius: 14)).padding(.horizontal, 24)
            Spacer(); Spacer() }
    }

    // MARK: - Partner Data
    private var partnerDataStep: some View {
        ScrollView { VStack(spacing: 24) { Spacer(minLength: 20); stepIcon("person.badge.plus")
            VStack(spacing: 8) { Text("Configura a tu pareja").font(.title2.bold()).foregroundStyle(Color(.label))
                Text("Llena los datos de tu pareja para empezar.").font(.subheadline).foregroundStyle(.secondary) }
            if viewModel.parsedUserIncome > 0 {
                HStack(spacing: 8) { Text("💰").font(.caption); Text("Tú ganas \(viewModel.formattedAmount(viewModel.monthlyIncome))").font(.caption).foregroundStyle(.secondary) }
                    .padding(10).background(primary.opacity(0.08)).clipShape(Capsule())
            }
            VStack(spacing: 14) {
                TextField("Nombre de tu pareja", text: $viewModel.partnerName).font(.system(size: 18, weight: .medium)).textInputAutocapitalization(.words)
                    .padding(14).background(Color(.secondarySystemGroupedBackground)).clipShape(RoundedRectangle(cornerRadius: 14))
                HStack { Text(viewModel.currencySymbol()).font(.system(size: 24, weight: .bold)).foregroundStyle(primary)
                    TextField("Ingreso mensual de tu pareja", text: $viewModel.partnerIncome).font(.system(size: 18, weight: .medium)).keyboardType(.numberPad)
                        .onChange(of: viewModel.partnerIncome) { _, v in viewModel.partnerIncome = formatWithThousands(v) }
                }.padding(14).background(Color(.secondarySystemGroupedBackground)).clipShape(RoundedRectangle(cornerRadius: 14))
            }.padding(.horizontal, 24)
            Text("Tu pareja podrá modificar estos datos cuando se una").font(.caption).foregroundStyle(.secondary).padding(.horizontal, 24)
            Spacer(minLength: 80) } }.scrollDismissesKeyboard(.interactively)
    }

    // MARK: - Split
    private var splitStep: some View {
        ScrollView { VStack(spacing: 24) { Spacer(minLength: 12); stepIcon("slider.horizontal.3")
            VStack(spacing: 8) { Text("¿Cómo dividen los gastos?").font(.title2.bold()).foregroundStyle(Color(.label))
                Text("Elige cómo repartir los gastos compartidos").font(.subheadline).foregroundStyle(.secondary) }
            VStack(spacing: 10) { ForEach(SplitTypeOption.allCases) { o in
                Button { withAnimation { viewModel.selectedSplit = o } } label: {
                    HStack(spacing: 12) { Text(o.emoji).font(.title2)
                        VStack(alignment: .leading, spacing: 2) { Text(o.displayName).font(.subheadline.weight(.semibold)).foregroundStyle(Color(.label))
                            if o == .proportional && viewModel.combinedIncome > 0 { Text("Tú \(viewModel.user1Pct)% | \(viewModel.resolvedPartnerName) \(viewModel.user2Pct)%").font(.caption).foregroundStyle(.secondary) }
                            else { Text(o.subtitle).font(.caption).foregroundStyle(.secondary) } }; Spacer()
                        if viewModel.selectedSplit == o { Image(systemName: "checkmark.circle.fill").foregroundStyle(primary) }
                    }.padding(14).background(viewModel.selectedSplit == o ? primary.opacity(0.08) : Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(viewModel.selectedSplit == o ? primary : .clear, lineWidth: 1.5))
                }
            } }
            if viewModel.selectedSplit == .custom {
                VStack(spacing: 8) { Text("\(viewModel.displayName): \(viewModel.customPercent)% / \(viewModel.resolvedPartnerName): \(100 - viewModel.customPercent)%").font(.subheadline.weight(.semibold)).foregroundStyle(primary)
                    Slider(value: Binding(get: { Double(viewModel.customPercent) }, set: { viewModel.customPercent = Int($0) }), in: 10...90, step: 5).tint(primary) }
            }
            if viewModel.selectedSplit == .onePays {
                HStack(spacing: 12) {
                    payerBtn(label: "\(viewModel.displayName) paga", sel: viewModel.onePayerIsUser1) { viewModel.onePayerIsUser1 = true }
                    payerBtn(label: "\(viewModel.resolvedPartnerName) paga", sel: !viewModel.onePayerIsUser1) { viewModel.onePayerIsUser1 = false }
                }
            }

            // Split preview
            splitPreviewCard

            Spacer(minLength: 80) }.padding(.horizontal, 24) }
    }

    private var splitPreviewCard: some View {
        let hasShared = !viewModel.sharedExpenses.isEmpty
        let firstShared = viewModel.sharedExpenses.first
        let exampleAmount: Decimal = hasShared ? firstShared!.parsedAmount : 1_000_000
        let exampleLabel = hasShared
            ? "Ejemplo con tu \(firstShared!.name.lowercased()) de \(viewModel.formattedDecimal(exampleAmount)):"
            : "Ejemplo con un gasto de \(viewModel.formattedDecimal(1_000_000)):"
        let (s1, s2) = viewModel.splitPreview(for: exampleAmount)
        let un = viewModel.displayName.isEmpty ? "Tú" : viewModel.displayName
        let pn = viewModel.resolvedPartnerName.isEmpty ? "Pareja" : viewModel.resolvedPartnerName

        return VStack(spacing: 10) {
            Text(exampleLabel)
                .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)

            if viewModel.combinedIncome > 0 {
                HStack(spacing: 12) {
                    VStack(spacing: 4) {
                        Text("🧑 \(un)").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        Text("\(viewModel.user1Pct)%").font(.subheadline.weight(.bold)).foregroundStyle(primary)
                        Text(viewModel.formattedDecimal(s1)).font(.caption).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity).padding(10)
                    .background(primary.opacity(0.06)).clipShape(RoundedRectangle(cornerRadius: 10))

                    VStack(spacing: 4) {
                        Text("👩 \(pn)").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        Text("\(viewModel.user2Pct)%").font(.subheadline.weight(.bold)).foregroundStyle(Color.fingetherRose)
                        Text(viewModel.formattedDecimal(s2)).font(.caption).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity).padding(10)
                    .background(Color.fingetherRose.opacity(0.06)).clipShape(RoundedRectangle(cornerRadius: 10))
                }
            } else {
                Text("Ingresa los ingresos para ver la vista previa").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(14).background(primary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(primary.opacity(0.2), lineWidth: 1))
        .animation(.easeInOut(duration: 0.3), value: viewModel.selectedSplit)
        .animation(.easeInOut(duration: 0.3), value: viewModel.customPercent)
        .animation(.easeInOut(duration: 0.3), value: viewModel.onePayerIsUser1)
    }
    private func payerBtn(label: String, sel: Bool, action: @escaping () -> Void) -> some View {
        Button { withAnimation { action() } } label: { Text(label).font(.subheadline.weight(.medium)).foregroundStyle(sel ? .white : Color(.label))
            .frame(maxWidth: .infinity).padding(.vertical, 12).background(sel ? primary : Color(.secondarySystemGroupedBackground)).clipShape(RoundedRectangle(cornerRadius: 12)) }
    }

    // MARK: - Fixed Expenses (shared or personal)
    private func fixedStep(shared: Bool) -> some View {
        let title = shared ? "Gastos fijos en pareja" : "Tus gastos fijos personales"
        let subtitle = shared ? "Los que pagan entre los dos" : "Los que pagas solo tú"
        let icon = shared ? "person.2.fill" : "person.fill"
        let suggestions = shared ? viewModel.sharedSuggestions : (viewModel.isCoupleFlow ? viewModel.personalSuggestions : viewModel.personalSuggestionsBase)

        return ScrollView {
            VStack(spacing: 16) {
                Spacer(minLength: 12); stepIcon(icon)
                VStack(spacing: 8) { Text(title).font(.title2.bold()).foregroundStyle(Color(.label)); Text(subtitle).font(.subheadline).foregroundStyle(.secondary) }

                // 4-column chip grid (15 suggestions + "Nuevo" button = 16 chips = 4x4)
                chipGrid(suggestions: suggestions, forceShared: shared)

                // Free form (shown when "Nuevo" is tapped)
                if viewModel.showFreeForm { freeFormCard(forceShared: shared) }

                // Added items
                let items = shared ? viewModel.sharedExpenses : viewModel.personalExpenses
                if !items.isEmpty {
                    VStack(spacing: 6) {
                        ForEach(items) { e in
                            HStack(spacing: 8) { Text(e.emoji); Text(e.name).font(.caption.weight(.medium)).foregroundStyle(Color(.label)).lineLimit(1)
                                if shared { let (s1, s2) = viewModel.splitPreview(for: e.parsedAmount)
                                    Text("\(viewModel.user1Pct)%/\(viewModel.user2Pct)%").font(.caption2).foregroundStyle(primary) }
                                Spacer()
                                Text(viewModel.formattedDecimal(e.parsedAmount)).font(.caption.weight(.bold)).foregroundStyle(coral)
                                Button { viewModel.removeFixedExpense(e) } label: { Image(systemName: "xmark.circle.fill").font(.caption).foregroundStyle(Color(.systemGray3)) }
                            }.padding(10).background(Color(.secondarySystemGroupedBackground)).clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        let total = items.reduce(Decimal.zero) { $0 + $1.parsedAmount }
                        HStack { Text("Total").font(.caption.weight(.semibold)).foregroundStyle(.secondary); Spacer()
                            Text(viewModel.formattedDecimal(total)).font(.subheadline.weight(.bold)).foregroundStyle(coral) }.padding(.horizontal, 4)
                    }
                }

                Spacer(minLength: 80)
            }.padding(.horizontal, 24)
        }.scrollDismissesKeyboard(.interactively)
    }

    // MARK: - 4-column Chip Grid
    private func chipGrid(suggestions: [SuggestedItem], forceShared: Bool) -> some View {
        let cols = Array(repeating: GridItem(.flexible(), spacing: 6), count: 4)
        return VStack(spacing: 6) {
            LazyVGrid(columns: cols, spacing: 6) {
                ForEach(suggestions) { sug in
                    let existing = viewModel.fixedExpenses.first { $0.name == sug.name }
                    let isExpanded = viewModel.expandedChipId == sug.id
                    if let exp = existing {
                        // Used chip — ✅ with amount
                        VStack(spacing: 2) { Text("✅").font(.system(size: 16)); Text(sug.name).font(.system(size: 10)).foregroundStyle(Color(.label)).lineLimit(1) }
                            .frame(maxWidth: .infinity).padding(.vertical, 8)
                            .background(primary.opacity(0.05)).clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(primary.opacity(0.3), lineWidth: 1))
                            .contextMenu { Button(role: .destructive) { viewModel.removeFixedExpense(exp) } label: { Label("Eliminar", systemImage: "trash") } }
                    } else {
                        // Available chip
                        Button { withAnimation(.easeInOut(duration: 0.2)) { viewModel.selectExpenseSuggestion(sug) } } label: {
                            VStack(spacing: 2) { Text(sug.emoji).font(.system(size: 20)); Text(sug.name).font(.system(size: 10, weight: .medium)).foregroundStyle(isExpanded ? .white : Color(.label)).lineLimit(1) }
                                .frame(maxWidth: .infinity).padding(.vertical, 8)
                                .background(isExpanded ? primary : Color(.secondarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(.systemGray4).opacity(isExpanded ? 0 : 0.5), lineWidth: 0.5))
                        }
                    }
                }
                // "➕ Nuevo" chip — opens free form
                Button { withAnimation { viewModel.openFreeForm() } } label: {
                    VStack(spacing: 2) { Text("➕").font(.system(size: 20)); Text("Nuevo").font(.system(size: 10, weight: .medium)).foregroundStyle(Color(.label)) }
                        .frame(maxWidth: .infinity).padding(.vertical, 8)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(.systemGray4).opacity(0.5), lineWidth: 0.5))
                }
            }
            // Expanded chip form
            if let chipId = viewModel.expandedChipId, let sug = suggestions.first(where: { $0.id == chipId }) {
                expandedChipForm(sug: sug, forceShared: forceShared)
            }
        }
    }

    private func expandedChipForm(sug: SuggestedItem, forceShared: Bool) -> some View {
        VStack(spacing: 8) {
            HStack { Text(sug.emoji).font(.system(size: 18)); Spacer()
                Button { viewModel.expandedChipId = nil } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(Color(.systemGray3)) } }
            // Editable name field (pre-filled with suggestion name)
            TextField("Nombre del gasto", text: $viewModel.freeFormName)
                .font(.system(size: 14, weight: .medium))
                .padding(10).background(Color(.tertiarySystemGroupedBackground)).clipShape(RoundedRectangle(cornerRadius: 8))
            HStack { Text(viewModel.currencySymbol()).font(.headline.weight(.bold)).foregroundStyle(primary)
                TextField("Monto mensual", text: $viewModel.freeFormAmount).font(.system(size: 18, weight: .medium)).keyboardType(.numberPad)
                    .onChange(of: viewModel.freeFormAmount) { _, v in viewModel.freeFormAmount = formatWithThousands(v) }
            }.padding(10).background(Color(.tertiarySystemGroupedBackground)).clipShape(RoundedRectangle(cornerRadius: 8))
            if forceShared {
                let amt = parseAmountFromFormatted(viewModel.freeFormAmount)
                if amt > 0 { let (s1, s2) = viewModel.splitPreview(for: amt)
                    Text("Tú: \(viewModel.formattedDecimal(s1)) (\(viewModel.user1Pct)%) | \(viewModel.resolvedPartnerName): \(viewModel.formattedDecimal(s2)) (\(viewModel.user2Pct)%)")
                        .font(.caption2).foregroundStyle(primary) }
            }
            Button { viewModel.freeFormEmoji = sug.emoji; viewModel.freeFormCategory = sug.category
                viewModel.addExpenseFromChip(forceShared: forceShared) } label: {
                Text("Agregar").font(.caption.weight(.bold)).foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 8)
                    .background(primary, in: RoundedRectangle(cornerRadius: 8)) }
        }.padding(12).background(Color(.secondarySystemGroupedBackground)).clipShape(RoundedRectangle(cornerRadius: 12))
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }

    private func freeFormCard(forceShared: Bool) -> some View {
        VStack(spacing: 8) {
            HStack { Text("Gasto personalizado").font(.subheadline.weight(.semibold)); Spacer()
                Button { viewModel.closeFreeForm() } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(Color(.systemGray3)) } }
            TextField("Nombre", text: $viewModel.freeFormName).font(.system(size: 14, weight: .medium)).padding(10).background(Color(.tertiarySystemGroupedBackground)).clipShape(RoundedRectangle(cornerRadius: 8))
            HStack { Text(viewModel.currencySymbol()).font(.headline.weight(.bold)).foregroundStyle(primary)
                TextField("Monto mensual", text: $viewModel.freeFormAmount).font(.system(size: 16, weight: .medium)).keyboardType(.numberPad)
                    .onChange(of: viewModel.freeFormAmount) { _, v in viewModel.freeFormAmount = formatWithThousands(v) }
            }.padding(10).background(Color(.tertiarySystemGroupedBackground)).clipShape(RoundedRectangle(cornerRadius: 8))
            Button { viewModel.addExpenseFromChip(forceShared: forceShared) } label: {
                Text("Agregar").font(.caption.weight(.bold)).foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 8)
                    .background(primary, in: RoundedRectangle(cornerRadius: 8)) }
        }.padding(12).background(Color(.secondarySystemGroupedBackground)).clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Couple Budget
    @State private var budgetHeaderVisible = false

    private var coupleBudgetStep: some View {
        ZStack {
            // Decorative background glow
            Circle()
                .fill(primary.opacity(cs == .dark ? 0.03 : 0.04))
                .frame(width: 300, height: 300)
                .blur(radius: 100)
                .offset(x: 120, y: -80)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    Spacer(minLength: 16)

                    // HEADER — dual avatar with currency icon
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [primary.opacity(0.15), Color.fingetherSky.opacity(0.10)],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 110, height: 110)
                            .shadow(color: primary.opacity(0.15), radius: 30, y: 4)

                        HStack(spacing: -8) {
                            // User avatar
                            ZStack {
                                Circle().fill(primary).frame(width: 40, height: 40)
                                Text(String(viewModel.displayName.prefix(1)).uppercased())
                                    .font(.system(size: 16, weight: .bold, design: .rounded)).foregroundStyle(.white)
                            }
                            // Currency bridge
                            ZStack {
                                Circle().fill(Color(.systemBackground)).frame(width: 28, height: 28)
                                    .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                                Text(viewModel.currencySymbol()).font(.system(size: 12, weight: .black, design: .rounded)).foregroundStyle(primary)
                            }.zIndex(1)
                            // Partner avatar
                            ZStack {
                                Circle().fill(Color.fingetherRose).frame(width: 40, height: 40)
                                Text(String(viewModel.resolvedPartnerName.prefix(1)).uppercased())
                                    .font(.system(size: 16, weight: .bold, design: .rounded)).foregroundStyle(.white)
                            }
                        }
                    }
                    .scaleEffect(budgetHeaderVisible ? 1.0 : 0.7)
                    .opacity(budgetHeaderVisible ? 1 : 0)

                    VStack(spacing: 6) {
                        Text("Presupuesto en pareja")
                            .font(.system(size: 24, weight: .bold, design: .rounded)).foregroundStyle(Color(.label))
                        Text("Decidan cuánto aporta cada uno")
                            .font(.subheadline).foregroundStyle(Color.fingetherSlateLight)
                    }

                    // SHARED EXPENSES LIST
                    if !viewModel.sharedExpenses.isEmpty {
                        VStack(spacing: 8) {
                            HStack {
                                Text("Gastos fijos compartidos").font(.caption.weight(.bold)).foregroundStyle(Color.fingetherSlate)
                                Spacer()
                            }
                            ForEach(viewModel.sharedExpenses) { e in
                                HStack(spacing: 10) {
                                    Text(e.emoji).font(.system(size: 18))
                                    Text(e.name).font(.subheadline).foregroundStyle(Color(.label))
                                    Spacer()
                                    Text(viewModel.formattedDecimal(e.parsedAmount))
                                        .font(.system(.subheadline, design: .rounded).weight(.semibold)).foregroundStyle(coral)
                                }
                            }
                            Rectangle().fill(Color.fingetherSlateLight.opacity(0.2)).frame(height: 0.5).padding(.vertical, 4)
                            HStack {
                                Text("Total compartidos").font(.subheadline.weight(.bold)).foregroundStyle(Color(.label))
                                Spacer()
                                Text(viewModel.formattedDecimal(viewModel.totalSharedExpenses))
                                    .font(.system(.title3, design: .rounded).weight(.bold)).foregroundStyle(coral)
                                    .contentTransition(.numericText())
                            }
                        }
                        .padding(20)
                        .background(
                            LinearGradient(colors: [Color(.secondarySystemGroupedBackground), primary.opacity(0.02)],
                                          startPoint: .top, endPoint: .bottom)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(primary.opacity(0.12), lineWidth: 1))
                        .shadow(color: primary.opacity(0.06), radius: 16, y: 6)
                    }

                    // MAIN CONTRIBUTION CARD
                    VStack(spacing: 20) {
                        Text("¿Cuánto vas a aportar al presupuesto en común?")
                            .font(.subheadline.weight(.semibold)).foregroundStyle(Color(.label)).multilineTextAlignment(.center)

                        // Custom segmented control
                        HStack(spacing: 0) {
                            budgetSegment(label: "Por porcentaje", selected: viewModel.contributionByPercent) {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { viewModel.contributionByPercent = true }
                            }
                            budgetSegment(label: "Monto fijo", selected: !viewModel.contributionByPercent) {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { viewModel.contributionByPercent = false }
                            }
                        }
                        .padding(4)
                        .background(primary.opacity(0.08))
                        .clipShape(Capsule())

                        if viewModel.contributionByPercent {
                            VStack(spacing: 12) {
                                // Big percentage
                                Text("\(viewModel.myContributionPercent)%")
                                    .font(.system(size: 48, weight: .bold, design: .rounded))
                                    .foregroundStyle(primary)
                                    .contentTransition(.numericText())
                                    .animation(.spring(response: 0.3), value: viewModel.myContributionPercent)

                                // Slider
                                Slider(
                                    value: Binding(
                                        get: { Double(viewModel.myContributionPercent) },
                                        set: { viewModel.myContributionPercent = Int($0) }
                                    ),
                                    in: 0...100, step: 5
                                )
                                .tint(primary)

                                // Amount text
                                HStack(spacing: 4) {
                                    Text("Aportas")
                                        .font(.subheadline).foregroundStyle(Color.fingetherSlate)
                                    Text(viewModel.formattedDecimal(viewModel.myContribution))
                                        .font(.system(.title3, design: .rounded).weight(.bold)).foregroundStyle(primary)
                                        .contentTransition(.numericText())
                                    Text("de \(viewModel.formattedDecimal(viewModel.parsedUserIncome))")
                                        .font(.subheadline).foregroundStyle(Color.fingetherSlate)
                                }

                                // Mini progress bar
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(Color.fingetherSlateLight.opacity(0.2)).frame(height: 6)
                                        Capsule()
                                            .fill(LinearGradient(colors: [primary, Color.fingetherSky], startPoint: .leading, endPoint: .trailing))
                                            .frame(width: geo.size.width * CGFloat(min(viewModel.myContributionPercent, 100)) / 100, height: 6)
                                            .animation(.spring(response: 0.4), value: viewModel.myContributionPercent)
                                    }
                                }.frame(height: 6)
                            }
                            .transition(.opacity.combined(with: .scale(scale: 0.98)))
                        } else {
                            HStack {
                                Text(viewModel.currencySymbol())
                                    .font(.system(size: 24, weight: .bold, design: .rounded)).foregroundStyle(primary)
                                TextField("Monto mensual", text: $viewModel.myContributionAmount)
                                    .font(.system(size: 22, weight: .semibold)).keyboardType(.numberPad)
                                    .onChange(of: viewModel.myContributionAmount) { _, v in
                                        viewModel.myContributionAmount = formatWithThousands(v)
                                    }
                            }
                            .padding(16)
                            .background(Color(.tertiarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .transition(.opacity.combined(with: .scale(scale: 0.98)))
                        }

                        Rectangle().fill(Color.fingetherSlateLight.opacity(0.15)).frame(height: 0.5)

                        // DUAL CONTRIBUTION CARDS
                        HStack(spacing: 12) {
                            // My contribution card
                            VStack(spacing: 8) {
                                Text("🧑 Tu aporte").font(.caption.weight(.bold)).foregroundStyle(Color.fingetherSlate)
                                Text(viewModel.formattedDecimal(viewModel.myContribution))
                                    .font(.system(.title3, design: .rounded).weight(.bold)).foregroundStyle(primary)
                                    .lineLimit(1).minimumScaleFactor(0.6)
                                    .contentTransition(.numericText())
                                Text("\(viewModel.myContributionPctOfIncome)% de tu ingreso")
                                    .font(.caption2).foregroundStyle(Color.fingetherSlateLight)
                                    .contentTransition(.numericText())
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16).padding(.horizontal, 8)
                            .background(primary.opacity(cs == .dark ? 0.08 : 0.03))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(primary.opacity(0.2), lineWidth: 1))

                            // Partner contribution card
                            VStack(spacing: 8) {
                                Text("💕 \(viewModel.resolvedPartnerName)").font(.caption.weight(.bold)).foregroundStyle(Color.fingetherSlate).lineLimit(1)
                                if viewModel.partnerContribution > 0 {
                                    Text(viewModel.formattedDecimal(viewModel.partnerContribution))
                                        .font(.system(.title3, design: .rounded).weight(.bold)).foregroundStyle(Color.fingetherRose)
                                        .lineLimit(1).minimumScaleFactor(0.6)
                                        .contentTransition(.numericText())
                                    Text("\(viewModel.partnerContributionPctOfIncome)% de su ingreso")
                                        .font(.caption2).foregroundStyle(Color.fingetherSlateLight)
                                        .contentTransition(.numericText())
                                } else {
                                    Text("Cubierto")
                                        .font(.system(.title3, design: .rounded).weight(.bold)).foregroundStyle(Color.fingetherIncome)
                                    Text("Tú cubres todo").font(.caption2).foregroundStyle(Color.fingetherSlateLight)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16).padding(.horizontal, 8)
                            .background(Color.fingetherRose.opacity(cs == .dark ? 0.08 : 0.03))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.fingetherRose.opacity(0.2), lineWidth: 1))
                        }
                        .animation(.spring(response: 0.4), value: viewModel.myContributionPercent)

                    }
                    .padding(24)
                    .background(
                        LinearGradient(colors: [Color(.secondarySystemGroupedBackground), primary.opacity(0.03)],
                                      startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(primary.opacity(0.15), lineWidth: 1))
                    .shadow(color: primary.opacity(0.08), radius: 20, y: 8)

                    // COVERAGE STATUS
                    if viewModel.totalSharedExpenses > 0 {
                        let surplus = viewModel.myContribution + viewModel.partnerContribution - viewModel.totalSharedExpenses
                        if surplus >= 0 {
                            HStack(spacing: 10) {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.title3).foregroundStyle(Color.fingetherForest)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Cubren los gastos compartidos")
                                        .font(.subheadline.weight(.semibold)).foregroundStyle(Color.fingetherForest)
                                    if surplus > 0 {
                                        Text("Les sobran \(viewModel.formattedDecimal(surplus))")
                                            .font(.caption).foregroundStyle(Color.fingetherForest.opacity(0.8))
                                    }
                                }
                                Spacer()
                            }
                            .padding(16)
                            .background(Color.fingetherForest.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.fingetherForest.opacity(0.2), lineWidth: 1))
                            .transition(.scale.combined(with: .opacity))
                        } else {
                            HStack(spacing: 10) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.title3).foregroundStyle(Color.fingetherWarning)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Faltan \(viewModel.formattedDecimal(abs(surplus)))")
                                        .font(.subheadline.weight(.semibold)).foregroundStyle(Color.fingetherWarning)
                                    Text("para cubrir los gastos compartidos")
                                        .font(.caption).foregroundStyle(Color.fingetherWarning.opacity(0.8))
                                }
                                Spacer()
                            }
                            .padding(16)
                            .background(Color.fingetherWarning.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.fingetherWarning.opacity(0.2), lineWidth: 1))
                            .transition(.scale.combined(with: .opacity))
                        }
                    }

                    Spacer(minLength: 80)
                }
                .padding(.horizontal, 24)
                .animation(.spring(response: 0.4), value: viewModel.contributionByPercent)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1)) { budgetHeaderVisible = true }
        }
    }

    private func budgetSegment(label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline.weight(selected ? .bold : .medium))
                .foregroundStyle(selected ? .white : Color.fingetherSlate)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(selected ? primary : .clear)
                .clipShape(Capsule())
        }
    }

    // MARK: - Solo Budget
    private var soloBudgetStep: some View {
        ScrollView { VStack(spacing: 24) { Spacer(minLength: 20); stepIcon("chart.bar.fill")
            Text("Tu presupuesto").font(.title2.bold()).foregroundStyle(Color(.label))
            VStack(spacing: 8) {
                bRow("💰 Ingresos", viewModel.parsedUserIncome, Color.fingetherIncome)
                if viewModel.totalFixedExpenses > 0 { bRow("📌 Gastos fijos", -viewModel.totalFixedExpenses, coral) }
                Divider()
                HStack { Text("Disponible").font(.subheadline.weight(.bold)); Spacer()
                    Text(viewModel.formattedDecimal(viewModel.availableBudget)).font(.system(.title3, design: .rounded).weight(.bold)).foregroundStyle(primary) }
            }.padding(16).background(primary.opacity(0.06)).clipShape(RoundedRectangle(cornerRadius: 14))
            VStack(spacing: 12) {
                Toggle(isOn: $viewModel.budgetLimitEnabled) { Text("¿Quieres poner un límite de gasto?").font(.subheadline.weight(.medium)) }.tint(primary)
                if viewModel.budgetLimitEnabled {
                    HStack { Text(viewModel.currencySymbol()).font(.system(size: 20, weight: .bold)).foregroundStyle(primary)
                        TextField("Límite mensual", text: $viewModel.budgetLimitAmount).font(.system(size: 18, weight: .medium)).keyboardType(.numberPad)
                            .onChange(of: viewModel.budgetLimitAmount) { _, v in viewModel.budgetLimitAmount = formatWithThousands(v) }
                    }.padding(14).background(Color(.tertiarySystemGroupedBackground)).clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }.padding(16).background(Color(.secondarySystemGroupedBackground)).clipShape(RoundedRectangle(cornerRadius: 14))
            Spacer(minLength: 80) }.padding(.horizontal, 24) }.scrollDismissesKeyboard(.interactively)
    }
    private func bRow(_ label: String, _ value: Decimal, _ color: Color) -> some View {
        HStack { Text(label).font(.caption).foregroundStyle(.secondary); Spacer(); Text(viewModel.formattedDecimal(value)).font(.system(.caption, design: .rounded).weight(.semibold)).foregroundStyle(color) }
    }

    // MARK: - Summary
    private var summaryStep: some View {
        ScrollView { VStack(spacing: 20) { Spacer(minLength: 20)
            ZStack { Circle().fill(primary.opacity(0.1)).frame(width: 120, height: 120)
                Image(systemName: "checkmark.circle.fill").font(.system(size: 60)).foregroundStyle(primary).scaleEffect(checkmarkScale) }
                .onAppear { withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { checkmarkScale = 1.0 } }
            Text("Todo listo ✨").font(.system(size: 28, weight: .bold, design: .rounded)).foregroundStyle(Color(.label))

            // Individual
            summaryCard(icon: "person.fill", color: individual, title: viewModel.displayName.isEmpty ? "Tu perfil" : viewModel.displayName) {
                sRow("País", "\(viewModel.selectedCountry.flag) \(viewModel.selectedCountry.displayName)")
                sRow("Ingreso mensual", viewModel.formattedAmount(viewModel.monthlyIncome))
                if !viewModel.personalExpenses.isEmpty { sRow("Gastos fijos personales", "\(viewModel.personalExpenses.count) gastos (\(viewModel.formattedDecimal(viewModel.totalPersonalExpenses)))") }
            }

            if viewModel.isCoupleFlow {
                // Couple
                summaryCard(icon: "heart.fill", color: primary, title: "\(viewModel.displayName) & \(viewModel.resolvedPartnerName)") {
                    sRow("División", "\(viewModel.selectedSplit.displayName) (\(viewModel.user1Pct)%/\(viewModel.user2Pct)%)")
                    if !viewModel.sharedExpenses.isEmpty {
                        sRow("Gastos en pareja", "\(viewModel.sharedExpenses.count) gastos (\(viewModel.formattedDecimal(viewModel.totalSharedExpenses)))")
                        let myPart = viewModel.sharedExpenses.reduce(Decimal.zero) { $0 + viewModel.splitPreview(for: $1.parsedAmount).0 }
                        sRow("Tu parte", viewModel.formattedDecimal(myPart))
                    }
                    sRow("Tu aporte mensual", viewModel.formattedDecimal(viewModel.myContribution))
                }
                inviteCodeCard
            }

            // Budget
            summaryCard(icon: "chart.bar.fill", color: primary, title: "Presupuesto") {
                sRow("Disponible", viewModel.formattedDecimal(viewModel.availableBudget))
            }

            Spacer(minLength: 80)
        }.padding(.horizontal, 24) }
    }

    private func summaryCard<Content: View>(icon: String, color: Color, title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 10) {
            HStack { ZStack { Circle().fill(color.opacity(0.1)).frame(width: 32, height: 32); Image(systemName: icon).font(.caption).foregroundStyle(color) }
                Text(title).font(.headline).foregroundStyle(Color(.label)); Spacer() }
            content()
        }.padding(14).background(Color(.secondarySystemGroupedBackground)).clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(color.opacity(0.2), lineWidth: 1))
    }

    private func sRow(_ l: String, _ v: String) -> some View {
        HStack { Text(l).font(.caption).foregroundStyle(.secondary); Spacer(); Text(v).font(.caption.weight(.semibold)).foregroundStyle(Color(.label)) }
    }

    private var inviteCodeCard: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) { Image(systemName: "link.badge.plus").foregroundStyle(primary); Text("Código para tu pareja").font(.subheadline.weight(.bold)); Spacer() }
            Text(viewModel.formattedInviteCode).font(.system(size: 32, weight: .bold, design: .monospaced)).foregroundStyle(primary)
                .padding(.vertical, 12).frame(maxWidth: .infinity).background(primary.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 12))
            Text("Compártelo para que \(viewModel.resolvedPartnerName) se una").font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 12) {
                Button { viewModel.copyInviteCode() } label: { HStack(spacing: 4) { Image(systemName: "doc.on.doc"); Text("Copiar") }.font(.caption.weight(.semibold)).foregroundStyle(primary).padding(.vertical, 8).padding(.horizontal, 14).background(primary.opacity(0.1)).clipShape(Capsule()) }
                ShareLink(item: "Únete a Fingether conmigo! Usa el código: \(viewModel.inviteCode)") {
                    HStack(spacing: 4) { Image(systemName: "square.and.arrow.up"); Text("Compartir") }.font(.caption.weight(.semibold)).foregroundStyle(.white).padding(.vertical, 8).padding(.horizontal, 14).background(primary).clipShape(Capsule()) }
            }
        }.padding(14).background(Color(.secondarySystemGroupedBackground)).clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(primary.opacity(0.3), lineWidth: 1))
    }

    // MARK: - Bottom Buttons
    private var isCoupleQ: Bool { viewModel.isCoupleFlow ? viewModel.currentStep == 3 : (viewModel.currentStep == 3 && !viewModel.coupleChoiceMade) }
    private var isPartnerStep: Bool { viewModel.wantsCoupleMode && viewModel.currentStep == 5 }
    private var isSummary: Bool { viewModel.currentStep == viewModel.totalSteps - 1 }

    private var bottomButtons: some View {
        Group {
            if viewModel.currentStep == 0 {
                HStack { Spacer(); pBtn("Empezar", icon: "arrow.right") { viewModel.nextStep() }; Spacer() }
            } else if isCoupleQ { HStack { backBtn; Spacer() }
            } else if isPartnerStep {
                HStack { backBtn; Spacer(); pBtn("Continuar", icon: "arrow.right", on: viewModel.canSetupPartner) { viewModel.setupPartnerAndContinue() } }
            } else if isSummary {
                HStack(spacing: 16) { backBtn; Spacer()
                    Button { guard let uid = authViewModel.currentUser?.id else { return }
                        Task { await viewModel.completeOnboarding(userId: uid)
                            if viewModel.errorMessage == nil { if MockDataService.shared.isEnabled { authViewModel.refreshMockUser() } else { await authViewModel.checkSession() } } }
                    } label: { HStack(spacing: 6) { if viewModel.isCompleting { ProgressView().tint(.white) }; Text("Comenzar"); Image(systemName: "rocket.fill") }
                        .font(.headline).foregroundStyle(.white).padding(.vertical, 16).padding(.horizontal, 24)
                        .background(LinearGradient(colors: gradientColors, startPoint: .leading, endPoint: .trailing))
                        .clipShape(RoundedRectangle(cornerRadius: 14)).shadow(color: primary.opacity(0.3), radius: 6, y: 3) }.disabled(viewModel.isCompleting) }
            } else {
                HStack(spacing: 16) { backBtn; Spacer(); pBtn("Siguiente", icon: "chevron.right", on: viewModel.canAdvance) { viewModel.nextStep() } }
            }
        }
    }
    private func pBtn(_ label: String, icon: String, on: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) { HStack(spacing: 4) { Text(label); Image(systemName: icon) }.font(.headline).foregroundStyle(.white).padding(.vertical, 16).padding(.horizontal, 24)
            .background(on ? LinearGradient(colors: gradientColors, startPoint: .leading, endPoint: .trailing) : LinearGradient(colors: [Color.gray.opacity(0.4), Color.gray.opacity(0.4)], startPoint: .leading, endPoint: .trailing))
            .clipShape(RoundedRectangle(cornerRadius: 14)).shadow(color: on ? primary.opacity(0.3) : .clear, radius: 6, y: 3) }.disabled(!on)
    }
    private var backBtn: some View {
        Button { viewModel.previousStep() } label: { HStack(spacing: 4) { Image(systemName: "chevron.left"); Text("Anterior") }.font(.subheadline.weight(.medium)).foregroundStyle(.secondary) }
    }
    private func stepIcon(_ name: String) -> some View {
        ZStack { Circle().fill(primary.opacity(0.1)).frame(width: 100, height: 100); Image(systemName: name).font(.system(size: 48)).foregroundStyle(primary) }
    }
}
