import SwiftUI

struct AddSavingsGoalView: View {
    @Environment(\.dismiss) private var dismiss
    let coupleId: UUID
    var onSave: (() -> Void)?

    @State private var name = ""
    @State private var description = ""
    @State private var targetAmount = ""
    @State private var targetDate = Date().addingTimeInterval(90 * 24 * 3600)
    @State private var hasTargetDate = true
    @State private var selectedEmoji = "🎯"
    @State private var isShared = true
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let emojis = ["🎯", "🏠", "✈️", "🚗", "💍", "📱", "🎓", "🐶", "🎮", "💰", "🎁", "🏖️", "🩺", "👶", "🎸"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Meta") {
                    TextField("Nombre de la meta", text: $name)
                    TextField("Descripcion (opcional)", text: $description, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section("Tipo de meta") {
                    Picker("", selection: $isShared) {
                        Label("💕 En conjunto", systemImage: "heart.fill").tag(true)
                        Label("🧑 Individual", systemImage: "person.fill").tag(false)
                    }
                    .pickerStyle(.segmented)

                    Text(isShared
                        ? "Ambos pueden ver y abonar a esta meta"
                        : "Solo tu puedes abonar, tu pareja puede ver el progreso")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Section("Monto objetivo") {
                    HStack {
                        Text("$")
                            .font(.title2.bold())
                            .foregroundStyle(.secondary)
                        TextField("0", text: $targetAmount)
                            .font(.title2.bold())
                            .keyboardType(.numberPad)
                            .onChange(of: targetAmount) { _, val in
                                targetAmount = formatWithThousands(val)
                            }
                    }
                }

                Section("Fecha limite") {
                    Toggle("Establecer fecha limite", isOn: $hasTargetDate)
                    if hasTargetDate {
                        DatePicker("Fecha", selection: $targetDate, in: Date()..., displayedComponents: .date)
                            .environment(\.locale, Locale(identifier: "es_MX"))
                    }
                }

                Section("Icono") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                        ForEach(emojis, id: \.self) { emoji in
                            Button {
                                selectedEmoji = emoji
                            } label: {
                                Text(emoji)
                                    .font(.title)
                                    .frame(width: 50, height: 50)
                                    .background(
                                        selectedEmoji == emoji ? Color.fingetherPrimary.opacity(0.2) : Color(.systemGray6),
                                        in: RoundedRectangle(cornerRadius: 10)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(selectedEmoji == emoji ? Color.fingetherPrimary : .clear, lineWidth: 2)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(Color.fingetherDanger).font(.caption)
                    }
                }
            }
            .navigationTitle("Nueva Meta de Ahorro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Crear") {
                        Task { await createGoal() }
                    }
                    .fontWeight(.semibold)
                    .disabled(name.isEmpty || targetAmount.isEmpty || isLoading)
                }
            }
        }
    }

    private func createGoal() async {
        guard let amount = Decimal(string: targetAmount), amount > 0 else {
            errorMessage = "Ingresa un monto valido"
            return
        }
        isLoading = true
        defer { isLoading = false }

        do {
            let goal = SavingsGoal(
                id: UUID(),
                coupleId: coupleId,
                name: name,
                description: description.isEmpty ? nil : description,
                targetAmount: amount,
                currentAmount: 0,
                targetDate: hasTargetDate ? targetDate : nil,
                emoji: selectedEmoji,
                status: .active,
                isShared: isShared,
                createdAt: Date(),
                updatedAt: Date()
            )
            let created = try await SavingsGoalService.createGoal(goal)

            // If the goal has a target date, create a recurring transaction for the monthly contribution
            if hasTargetDate {
                let months = max(1, Calendar.current.dateComponents([.month], from: Date(), to: targetDate).month ?? 1)
                let monthlyContribution = amount / Decimal(months)
                if monthlyContribution > 0 {
                    let mock = MockDataService.shared
                    let userId = mock.mockProfile?.id ?? UUID()
                    let now = Date()
                    _ = mock.addMockTransaction(Transaction(
                        id: UUID(), userId: userId, coupleId: coupleId,
                        type: .expense, category: .savings, amount: monthlyContribution,
                        description: "\(selectedEmoji) \(name)",
                        notes: "savings_goal_\(created.id)",
                        date: now, isRecurring: true, recurringFrequency: .monthly,
                        isShared: isShared, createdAt: now, updatedAt: now
                    ))
                }
            }

            onSave?()
            dismiss()
        } catch {
            errorMessage = "No se pudo crear la meta."
        }
    }
}
