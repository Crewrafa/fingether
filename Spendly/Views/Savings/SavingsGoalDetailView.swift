import SwiftUI

struct SavingsGoalDetailView: View {
    let goalId: UUID
    let coupleId: UUID
    let viewModel: SavingsGoalViewModel

    @State private var contributeAmount = ""
    @State private var showContribute = false

    private var goal: SavingsGoal {
        viewModel.goals.first(where: { $0.id == goalId }) ?? SavingsGoal(
            id: goalId, coupleId: coupleId, name: "...",
            description: nil, targetAmount: 1, currentAmount: 0,
            targetDate: nil, emoji: "🎯", status: .active,
            createdAt: Date(), updatedAt: Date()
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                progressRing
                amountInfo
                contributeSection
                detailsSection
            }
            .padding()
        }
        .trackCurrency()
        .navigationTitle(goal.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var progressRing: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 14)
                Circle()
                    .trim(from: 0, to: CGFloat(goal.progressPercentage.doubleValue))
                    .stroke(Color.fingetherPrimary, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.spring, value: goal.progressPercentage)

                VStack(spacing: 4) {
                    Text(goal.emoji)
                        .font(.system(size: 40))
                    Text("\(Int(goal.progressPercentage.doubleValue * 100))%")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                }
            }
            .frame(width: 180, height: 180)
        }
    }

    private var amountInfo: some View {
        HStack(spacing: 16) {
            VStack(spacing: 4) {
                Text("Ahorrado")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(goal.currentAmount.currencyFormatted)
                    .font(.title3.bold())
                    .foregroundStyle(Color.fingetherPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .frame(maxWidth: .infinity)

            Divider().frame(height: 40)

            VStack(spacing: 4) {
                Text("Meta")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(goal.targetAmount.currencyFormatted)
                    .font(.title3.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .frame(maxWidth: .infinity)

            Divider().frame(height: 40)

            VStack(spacing: 4) {
                Text("Falta")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text((goal.targetAmount - goal.currentAmount).currencyFormatted)
                    .font(.title3.bold())
                    .foregroundStyle(.orange)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
    }

    private var contributeSection: some View {
        VStack(spacing: 12) {
            if showContribute {
                HStack {
                    Text("$")
                        .font(.title3.bold())
                        .foregroundStyle(.secondary)
                    TextField("0", text: $contributeAmount)
                        .font(.title3.bold())
                        .keyboardType(.numberPad)
                        .onChange(of: contributeAmount) { _, val in
                            contributeAmount = formatWithThousands(val)
                        }
                    Button("Abonar") {
                        Task {
                            let amount = parseAmountFromFormatted(contributeAmount)
                            if amount > 0 {
                                await viewModel.contribute(goalId: goal.id, amount: amount)
                                contributeAmount = ""
                                showContribute = false
                            }
                        }
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.fingetherPrimary)
                    .disabled(contributeAmount.isEmpty)
                }
                .padding()
                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
            }

            Button {
                showContribute.toggle()
            } label: {
                Label(
                    showContribute ? "Cancelar" : "Abonar a Meta",
                    systemImage: showContribute ? "xmark" : "plus.circle.fill"
                )
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(showContribute ? Color(.systemGray5) : Color.fingetherPrimary, in: RoundedRectangle(cornerRadius: 16))
                .foregroundStyle(showContribute ? Color.primary : Color.white)
            }
        }
    }

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let description = goal.description {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if let targetDate = goal.targetDate {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundStyle(.secondary)
                    Text("Fecha limite: \(targetDate.formattedSpanishLong)")
                        .font(.subheadline)
                }
            }
            HStack {
                Image(systemName: "clock")
                    .foregroundStyle(.secondary)
                Text("Creada \(goal.createdAt.relativeTimeSpanish)")
                    .font(.subheadline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
    }
}
