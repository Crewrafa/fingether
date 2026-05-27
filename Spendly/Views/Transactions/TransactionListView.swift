import SwiftUI

struct TransactionListView: View {

    let userId: UUID
    let coupleId: UUID?

    @State private var viewModel = TransactionViewModel()
    @State private var showAddTransaction = false
    @State private var selectedTransaction: Transaction?
    @State private var selectedScope: TransactionScope = .all

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                VStack(spacing: 0) {
                    // P5: subtitulo clarificador "Tus gastos del día a día"
                    subtitleBanner
                    searchBar
                    scopeFilter
                    filterChips
                    transactionsList
                }

                addTransactionFAB
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .trackCurrency()
            .navigationTitle("Gastos")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showAddTransaction, onDismiss: { reloadIfNeeded() }) {
                if let cid = coupleId {
                    AddTransactionView(coupleId: cid, userId: userId)
                }
            }
            .sheet(item: $selectedTransaction, onDismiss: { reloadIfNeeded() }) { transaction in
                if let cid = coupleId {
                    AddTransactionView(coupleId: cid, userId: userId, editingTransaction: transaction)
                }
            }
            .task {
                if let cid = coupleId {
                    await viewModel.loadTransactions(coupleId: cid)
                }
            }
        }
    }

    private func reloadIfNeeded() {
        guard let cid = coupleId else { return }
        Task { await viewModel.loadTransactions(coupleId: cid) }
    }

    // MARK: - Subtitle Banner (P5: clarifies Gastos vs Fijos)

    private var subtitleBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "info.circle")
                .font(.caption2)
            Text("Tus gastos del día a día")
                .font(.caption2)
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 6)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Buscar transacciones...", text: $viewModel.searchText)
                    .autocorrectionDisabled()
                    .onChange(of: viewModel.searchText) {
                        viewModel.applyFilters()
                    }
                if !viewModel.searchText.isEmpty {
                    Button {
                        viewModel.searchText = ""
                        viewModel.applyFilters()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - Scope Filter

    private var scopeFilter: some View {
        HStack(spacing: 8) {
            ForEach(TransactionScope.allCases) { scope in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedScope = scope
                    }
                } label: {
                    Text(scope.label)
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            selectedScope == scope
                            ? Color.fingetherRose
                            : Color(.secondarySystemGroupedBackground)
                        )
                        .foregroundStyle(
                            selectedScope == scope
                            ? .white
                            : Color(.label)
                        )
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.04), radius: 3, y: 1)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
    }

    // MARK: - Filter Chips

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(
                    title: "Todos",
                    isSelected: viewModel.selectedFilterType == nil,
                    action: {
                        viewModel.selectedFilterType = nil
                        viewModel.applyFilters()
                    }
                )

                ForEach(TransactionType.allCases) { type in
                    filterChip(
                        title: type.displayName,
                        isSelected: viewModel.selectedFilterType == type,
                        action: {
                            viewModel.selectedFilterType = type
                            viewModel.applyFilters()
                        }
                    )
                }

                Divider()
                    .frame(height: 24)

                Menu {
                    Button("Todas las categorias") {
                        viewModel.selectedFilterCategory = nil
                        viewModel.applyFilters()
                    }
                    ForEach(TransactionCategory.allCases) { category in
                        Button {
                            viewModel.selectedFilterCategory = category
                            viewModel.applyFilters()
                        } label: {
                            Label(category.displayName, systemImage: category.iconName)
                        }
                    }
                } label: {
                    filterChipLabel(
                        title: viewModel.selectedFilterCategory?.displayName ?? "Categoria",
                        isSelected: viewModel.selectedFilterCategory != nil
                    )
                }

                DatePicker(
                    "Mes",
                    selection: $viewModel.selectedMonth,
                    displayedComponents: .date
                )
                .labelsHidden()
                .tint(Color.fingetherPrimary)
                .onChange(of: viewModel.selectedMonth) {
                    viewModel.applyFilters()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    private func filterChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            filterChipLabel(title: title, isSelected: isSelected)
        }
    }

    private func filterChipLabel(title: String, isSelected: Bool) -> some View {
        Text(title)
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? Color.fingetherPrimary : Color(.secondarySystemGroupedBackground))
            .foregroundStyle(isSelected ? .white : Color(.label))
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.04), radius: 3, y: 1)
    }

    // MARK: - Summary Header

    private var summaryHeader: some View {
        HStack(spacing: 16) {
            VStack(spacing: 2) {
                Text("Ingresos")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(viewModel.totalIncome.currencyFormatted)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.fingetherIncome)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            Divider().frame(height: 30)
            VStack(spacing: 2) {
                Text("Gastos")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(viewModel.totalExpenses.currencyFormatted)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.fingetherDanger)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            Divider().frame(height: 30)
            VStack(spacing: 2) {
                Text("Balance")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(viewModel.balance.currencyFormatted)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(viewModel.balance >= 0 ? Color.fingetherIncome : Color.fingetherDanger)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
        .padding(.horizontal, 16)
    }

    // MARK: - Scoped Transactions

    private var scopedTransactions: [Transaction] {
        switch selectedScope {
        case .all:
            return viewModel.filteredTransactions
        case .mine:
            return viewModel.filteredTransactions.filter { !$0.isShared && $0.userId == userId }
        case .shared:
            return viewModel.filteredTransactions.filter { $0.isShared }
        }
    }

    // MARK: - Transactions List

    private var transactionsList: some View {
        Group {
            if viewModel.isLoading && viewModel.transactions.isEmpty {
                LoadingView(message: "Cargando transacciones...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if scopedTransactions.isEmpty {
                EmptyStateView(
                    icon: "tray",
                    title: "Sin transacciones",
                    subtitle: viewModel.searchText.isEmpty
                        ? scopeEmptyMessage
                        : "No se encontraron resultados",
                    actionTitle: viewModel.searchText.isEmpty ? "Agregar transaccion" : nil,
                    action: { showAddTransaction = true }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 0) {
                    summaryHeader
                        .padding(.vertical, 8)

                    List {
                        ForEach(groupedTransactions, id: \.date) { group in
                            Section {
                                ForEach(group.transactions) { transaction in
                                    TransactionRow(transaction: transaction, currentUserId: userId)
                                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                                        .listRowBackground(Color(.secondarySystemGroupedBackground))
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            selectedTransaction = transaction
                                        }
                                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                            Button(role: .destructive) {
                                                Task { await viewModel.deleteTransaction(id: transaction.id) }
                                            } label: {
                                                Label("Eliminar", systemImage: "trash.fill")
                                            }
                                        }
                                }
                            } header: {
                                Text(group.dateLabel)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color(.label))
                                    .textCase(nil)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .refreshable {
                        if let cid = coupleId {
                            await viewModel.loadTransactions(coupleId: cid)
                        }
                    }
                }
            }
        }
    }

    private var scopeEmptyMessage: String {
        switch selectedScope {
        case .all:
            return "Agrega tu primera transaccion para comenzar"
        case .mine:
            return "No tienes transacciones individuales este mes"
        case .shared:
            return "No hay gastos compartidos este mes"
        }
    }

    private var groupedTransactions: [TransactionGroupDisplay] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: scopedTransactions) { transaction in
            calendar.startOfDay(for: transaction.date)
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_MX")
        formatter.dateFormat = "EEEE, d 'de' MMMM"

        return grouped
            .map { date, txns in
                TransactionGroupDisplay(
                    date: date,
                    dateLabel: formatter.string(from: date).capitalizedFirst,
                    transactions: txns.sorted { $0.date > $1.date }
                )
            }
            .sorted { $0.date > $1.date }
    }

    // MARK: - FAB

    private var addTransactionFAB: some View {
        Button {
            showAddTransaction = true
        } label: {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 60, height: 60)
                .background(
                    LinearGradient(
                        colors: [Color.fingetherPrimary, Color.fingetherPrimaryDark],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Circle())
                .shadow(color: Color.fingetherPrimary.opacity(0.4), radius: 10, y: 5)
        }
        .sensoryFeedback(.impact(flexibility: .solid), trigger: showAddTransaction)
    }
}

// MARK: - Transaction Scope

private enum TransactionScope: String, CaseIterable, Identifiable {
    case all
    case mine
    case shared

    var id: Self { self }

    var label: String {
        switch self {
        case .all: return "Todos"
        case .mine: return "🧑 Mios"
        case .shared: return "💕 Compartidos"
        }
    }
}

// MARK: - Transaction Group Display

private struct TransactionGroupDisplay: Identifiable {
    let date: Date
    let dateLabel: String
    let transactions: [Transaction]

    var id: Date { date }
}
