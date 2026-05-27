import SwiftUI

struct TripListView: View {
    let coupleId: UUID

    @State private var viewModel = TripViewModel()
    @State private var showCreateTrip = false
    @State private var preferences = AppPreferences.shared
    @State private var paywallFeature: PremiumFeature?  // P6
    private var lang: AppLanguage { preferences.language }

    private var canCreateTrip: Bool {
        MockDataService.shared.mockProfile?.subscriptionTier == .premium
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(spacing: 20) {
                    if viewModel.isLoading && viewModel.trips.isEmpty {
                        LoadingView()
                            .frame(maxWidth: .infinity, minHeight: 300)
                    } else if viewModel.trips.isEmpty {
                        EmptyStateView(
                            icon: "airplane",
                            title: L10n.t("trip_no_trips", lang),
                            subtitle: L10n.t("trip_no_trips_subtitle", lang),
                            actionTitle: L10n.t("trip_create", lang),
                            action: {
                                if canCreateTrip { showCreateTrip = true }
                                else { paywallFeature = .trips }
                            }
                        )
                        .padding(.top, 40)
                    } else {
                        // Active trip (hero card)
                        if let active = viewModel.activeTrip {
                            activeTripCard(active)
                        }

                        // Upcoming trips
                        if !viewModel.upcomingTrips.isEmpty {
                            sectionHeader(L10n.t("trip_upcoming", lang))
                            ForEach(viewModel.upcomingTrips) { trip in
                                NavigationLink {
                                    TripDetailView(trip: trip, coupleId: coupleId, viewModel: viewModel)
                                } label: {
                                    tripRow(trip)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        // Past trips
                        if !viewModel.pastTrips.isEmpty {
                            sectionHeader(L10n.t("trip_past", lang))
                            ForEach(viewModel.pastTrips) { trip in
                                NavigationLink {
                                    TripSummaryView(trip: trip, coupleId: coupleId, viewModel: viewModel)
                                } label: {
                                    tripRow(trip)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 80)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())

            // FAB
            Button {
                if canCreateTrip { showCreateTrip = true }
                else { paywallFeature = .trips }
            } label: {
                Image(systemName: "plus")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(Color.fingetherPrimary, in: Circle())
                    .shadow(color: Color.fingetherPrimary.opacity(0.4), radius: 10, y: 5)
            }
            .padding(.trailing, 20)
            .padding(.bottom, 20)
        }
        .trackCurrency()
        .sheet(isPresented: $showCreateTrip) {
            CreateTripView(coupleId: coupleId, viewModel: viewModel)
        }
        .paywallGate($paywallFeature)
        .task {
            await viewModel.loadTrips(coupleId: coupleId)
        }
        .refreshable {
            await viewModel.loadTrips(coupleId: coupleId)
        }
    }

    // MARK: - Active Trip Hero Card

    private func activeTripCard(_ trip: Trip) -> some View {
        NavigationLink {
            TripDetailView(trip: trip, coupleId: coupleId, viewModel: viewModel)
        } label: {
            VStack(spacing: 14) {
                HStack {
                    Text(trip.emoji)
                        .font(.system(size: 40))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(trip.name)
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                        Text(trip.destination)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.8))
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(dayLabel(trip))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.9))
                        Text("\(trip.daysRemaining) \(L10n.t("trip_days_remaining", lang))")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }

                // Budget bar
                let usage = budgetUsage(trip)
                VStack(spacing: 6) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(.white.opacity(0.25))
                                .frame(height: 14)
                            RoundedRectangle(cornerRadius: 6)
                                .fill(budgetBarColor(usage))
                                .frame(width: max(CGFloat(usage) * geo.size.width, 4), height: 14)
                        }
                    }
                    .frame(height: 14)

                    HStack {
                        Text("\(L10n.t("trip_spent", lang)): \(trip.totalSpent.currencyFormatted)")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.white.opacity(0.9))
                        Spacer()
                        Text("de \(trip.totalBudget.currencyFormatted)")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            }
            .padding(20)
            .background(
                LinearGradient(
                    colors: [Color.fingetherPrimary, Color.fingetherPrimaryDark],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: Color.fingetherPrimary.opacity(0.3), radius: 12, y: 6)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Trip Row

    private func tripRow(_ trip: Trip) -> some View {
        HStack(spacing: 12) {
            Text(trip.emoji)
                .font(.largeTitle)

            VStack(alignment: .leading, spacing: 4) {
                Text(trip.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(.label))
                Text(trip.destination)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(trip.startDate.formattedSpanishShort) - \(trip.endDate.formattedSpanishShort)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(trip.totalBudget.currencyFormatted)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color(.label))

                Text(trip.status.displayName)
                    .font(.caption2.weight(.medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(statusColor(trip.status).opacity(0.15))
                    .foregroundStyle(statusColor(trip.status))
                    .clipShape(Capsule())
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.04), radius: 6, y: 3)
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 4)
    }

    private func dayLabel(_ trip: Trip) -> String {
        let totalDays = Calendar.current.dateComponents([.day], from: trip.startDate, to: trip.endDate).day ?? 1
        let elapsed = Calendar.current.dateComponents([.day], from: trip.startDate, to: Date()).day ?? 0
        let currentDay = min(max(elapsed + 1, 1), totalDays)
        return String(format: L10n.t("trip_day_of", lang), currentDay, totalDays)
    }

    private func budgetUsage(_ trip: Trip) -> Double {
        guard trip.totalBudget > 0 else { return 0 }
        return min(trip.totalSpent.doubleValue / trip.totalBudget.doubleValue, 1.0)
    }

    private func budgetBarColor(_ usage: Double) -> Color {
        if usage >= 0.9 { return Color.fingetherExpense }
        if usage >= 0.7 { return Color.fingetherWarning }
        return .white
    }

    private func statusColor(_ status: TripStatus) -> Color {
        switch status {
        case .planning: return Color.fingetherSky
        case .active: return Color.fingetherPrimary
        case .completed: return .secondary
        }
    }
}
