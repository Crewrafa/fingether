import SwiftUI

struct TransactionRow: View {
    let transaction: Transaction
    var currentUserId: UUID?
    var showOwnerBadge: Bool = true

    /// C3: whether to show reaction bar on this row (couple mode only).
    @State private var showReactionBar = false

    /// True if the transaction is from the PARTNER (not the current user).
    private var isPartnerTransaction: Bool {
        guard let uid = currentUserId else { return false }
        return transaction.userId != uid
    }

    /// True if we're in couple mode with a linked partner.
    private var isCoupleContext: Bool {
        AppPreferences.shared.isCoupleMode &&
        MockDataService.shared.mockCouple?.user2Name?.isEmpty == false
    }

    /// My reaction to this transaction (if any).
    private var myReaction: String? {
        guard let uid = currentUserId else { return nil }
        return transaction.reactions?[uid.uuidString]
    }

    /// Partner's reaction to this transaction (if any).
    private var partnerReaction: String? {
        guard let uid = currentUserId else { return nil }
        let partnerId = uid == MockDataService.shared.currentUser1Id
            ? MockDataService.shared.currentUser2Id
            : MockDataService.shared.currentUser1Id
        return transaction.reactions?[partnerId.uuidString]
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 12) {
                // Category icon with scope indicator
                ZStack(alignment: .bottomTrailing) {
                    Text(transaction.category.emoji)
                        .font(.title2)
                        .frame(width: 44, height: 44)
                        .background(categoryColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))

                    if showOwnerBadge {
                        scopeBadge
                            .offset(x: 4, y: 4)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(transaction.description.isEmpty ? transaction.category.displayName : transaction.description)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text(transaction.date.formattedSpanishShort)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if transaction.isShared {
                            Text(payerLabel)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(Color.fingetherRose)
                        }

                        if transaction.isRecurring {
                            Image(systemName: "repeat")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }

                        // C3: show existing reactions inline
                        if let reaction = partnerReaction {
                            Text(reaction)
                                .font(.caption)
                                .padding(2)
                                .background(Color.fingetherRose.opacity(0.15))
                                .clipShape(Circle())
                        }
                        if let reaction = myReaction {
                            Text(reaction)
                                .font(.caption)
                                .padding(2)
                                .background(Color.fingetherPrimary.opacity(0.15))
                                .clipShape(Circle())
                        }
                    }
                }

                Spacer()

                // C3: small emoji button to trigger reaction bar (only for partner transactions)
                if isCoupleContext && isPartnerTransaction {
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                            showReactionBar.toggle()
                        }
                    } label: {
                        Image(systemName: myReaction != nil ? "face.smiling.inverse" : "face.smiling")
                            .font(.caption)
                            .foregroundStyle(myReaction != nil ? Color.fingetherPrimary : .secondary)
                    }
                    .buttonStyle(.plain)
                }

                Text(amountText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(amountColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }

            // C3: Reaction bar (shown with spring animation)
            if showReactionBar {
                reactionBar
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.vertical, 4)
        .trackCurrency()
    }

    // MARK: - Reaction Bar (C3)

    private var reactionBar: some View {
        HStack(spacing: 12) {
            ForEach(Transaction.reactionEmojis, id: \.self) { emoji in
                Button {
                    guard let uid = currentUserId else { return }
                    MockDataService.shared.reactToTransaction(
                        transactionId: transaction.id,
                        userId: uid,
                        emoji: emoji
                    )
                    withAnimation(.spring(response: 0.25)) {
                        showReactionBar = false
                    }
                } label: {
                    Text(emoji)
                        .font(.title2)
                        .scaleEffect(myReaction == emoji ? 1.2 : 1.0)
                        .background(
                            myReaction == emoji
                                ? Color.fingetherPrimary.opacity(0.15)
                                : Color.clear,
                            in: Circle()
                        )
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.selection, trigger: myReaction)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private var scopeBadge: some View {
        Group {
            if transaction.isShared {
                Image(systemName: "heart.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.white)
                    .frame(width: 16, height: 16)
                    .background(Color.fingetherRose, in: Circle())
            } else if let uid = currentUserId, transaction.userId == uid {
                Image(systemName: "person.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(.white)
                    .frame(width: 16, height: 16)
                    .background(Color.fingetherPrimary, in: Circle())
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(.white)
                    .frame(width: 16, height: 16)
                    .background(Color.fingetherDanger, in: Circle())
            }
        }
    }

    private var amountText: String {
        let sign = transaction.type == .income ? "+" : "-"
        return "\(sign)\(transaction.amount.currencyFormatted)"
    }

    private var amountColor: Color {
        if transaction.type == .income {
            return Color.fingetherIncome
        } else if transaction.isShared {
            return Color.fingetherRose
        } else {
            return Color(.label)
        }
    }

    private var payerLabel: String {
        let mock = MockDataService.shared
        if let uid = currentUserId, transaction.userId == uid {
            return mock.mockProfile?.displayName ?? "Yo"
        } else {
            return mock.mockPartnerProfile?.displayName ?? "Pareja"
        }
    }

    private var categoryColor: Color {
        Constants.categoryColors[transaction.category] ?? .gray
    }
}
