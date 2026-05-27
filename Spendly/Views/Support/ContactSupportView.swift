import SwiftUI

struct ContactSupportView: View {
    @State private var showBugReport = false
    @State private var showSuggestion = false
    @State private var showCopiedAlert = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header
                supportCards
                Spacer(minLength: 40)
                footer
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Soporte")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showBugReport) {
            BugReportSheet(isPresented: $showBugReport)
        }
        .sheet(isPresented: $showSuggestion) {
            SuggestionSheet(isPresented: $showSuggestion)
        }
        .alert("Correo copiado", isPresented: $showCopiedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("La direccion soporte@fingether.app se copio al portapapeles.")
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.fingetherPrimary.opacity(0.1))
                    .frame(width: 80, height: 80)
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(Color.fingetherPrimary)
            }

            Text("¿Necesitas ayuda?")
                .font(.title2.weight(.bold))
                .foregroundStyle(Color(.label))

            Text("Estamos aqui para ti.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 8)
    }

    // MARK: - Support Cards

    private var supportCards: some View {
        VStack(spacing: 12) {
            // Email card
            Button {
                openEmail()
            } label: {
                SupportCardRow(
                    icon: "envelope.fill",
                    iconColor: Color.fingetherPrimary,
                    title: "Escribenos un correo",
                    subtitle: "soporte@fingether.app"
                )
            }
            .buttonStyle(.plain)

            // Bug report card
            Button {
                showBugReport = true
            } label: {
                SupportCardRow(
                    icon: "ladybug.fill",
                    iconColor: Color.fingetherExpense,
                    title: "Reportar un problema",
                    subtitle: "Ayudanos a mejorar"
                )
            }
            .buttonStyle(.plain)

            // Suggestion card
            Button {
                showSuggestion = true
            } label: {
                SupportCardRow(
                    icon: "lightbulb.fill",
                    iconColor: Color.fingetherAmber,
                    title: "Sugerir una mejora",
                    subtitle: "Queremos escucharte"
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 6) {
            Text("Version 1.0.0")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Text("Hecho con \u{1F495} para parejas")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Actions

    private func openEmail() {
        let email = "soporte@fingether.app"
        let subject = "Soporte Fingether"
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? subject

        if let mailURL = URL(string: "mailto:\(email)?subject=\(encodedSubject)"),
           UIApplication.shared.canOpenURL(mailURL) {
            UIApplication.shared.open(mailURL)
        } else {
            UIPasteboard.general.string = email
            showCopiedAlert = true
        }
    }
}

// MARK: - Support Card Row

private struct SupportCardRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(.label))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
    }
}

// MARK: - Bug Report Sheet

private struct BugReportSheet: View {
    @Binding var isPresented: Bool
    @State private var description = ""
    @State private var selectedScreen = "Dashboard"
    @State private var showConfirmation = false

    private let screens = [
        "Dashboard", "Transacciones", "Presupuestos",
        "Mascota", "Insights", "Metas de ahorro",
        "Logros", "Ajustes", "Otro"
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Pantalla afectada", selection: $selectedScreen) {
                        ForEach(screens, id: \.self) { screen in
                            Text(screen).tag(screen)
                        }
                    }
                } header: {
                    Text("¿Donde ocurrio el problema?")
                }

                Section {
                    TextEditor(text: $description)
                        .frame(minHeight: 140)
                        .overlay(alignment: .topLeading) {
                            if description.isEmpty {
                                Text("Describe el problema con el mayor detalle posible...")
                                    .foregroundStyle(.tertiary)
                                    .padding(.top, 8)
                                    .padding(.leading, 4)
                                    .allowsHitTesting(false)
                            }
                        }
                } header: {
                    Text("Descripcion")
                }
            }
            .navigationTitle("Reportar problema")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enviar") {
                        showConfirmation = true
                    }
                    .fontWeight(.semibold)
                    .disabled(description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert("Reporte enviado. Gracias.", isPresented: $showConfirmation) {
                Button("OK") {
                    isPresented = false
                }
            }
        }
    }
}

// MARK: - Suggestion Sheet

private struct SuggestionSheet: View {
    @Binding var isPresented: Bool
    @State private var suggestion = ""
    @State private var showConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextEditor(text: $suggestion)
                        .frame(minHeight: 180)
                        .overlay(alignment: .topLeading) {
                            if suggestion.isEmpty {
                                Text("¿Que te gustaria ver en Fingether?")
                                    .foregroundStyle(.tertiary)
                                    .padding(.top, 8)
                                    .padding(.leading, 4)
                                    .allowsHitTesting(false)
                            }
                        }
                } header: {
                    Text("Tu sugerencia")
                }
            }
            .navigationTitle("Sugerir mejora")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enviar") {
                        showConfirmation = true
                    }
                    .fontWeight(.semibold)
                    .disabled(suggestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert("Reporte enviado. Gracias.", isPresented: $showConfirmation) {
                Button("OK") {
                    isPresented = false
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ContactSupportView()
    }
}
