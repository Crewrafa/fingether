import SwiftUI

struct RegisterView: View {

    @Bindable var authViewModel: AuthViewModel
    @Binding var showRegister: Bool
    @State private var confirmPassword = ""
    @State private var localError: String?
    @State private var contentOpacity: Double = 0

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.fingetherRose.opacity(0.06),
                    Color(.systemBackground),
                    Color.fingetherPrimary.opacity(0.05)
                ],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer().frame(height: 20)
                    headerSection
                    Spacer().frame(height: 32)
                    formCard
                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 28)
                .opacity(contentOpacity)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    showRegister = false
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Volver")
                    }
                    .font(.subheadline)
                    .foregroundStyle(Color.fingetherPrimary)
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) {
                contentOpacity = 1.0
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.fingetherRose.opacity(0.12))
                    .frame(width: 80, height: 80)
                    .blur(radius: 8)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.fingetherRose, Color.fingetherSky],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)
                    .shadow(color: Color.fingetherRose.opacity(0.3), radius: 12, y: 6)

                Text("👋")
                    .font(.system(size: 28))
            }

            Text("Crear Cuenta")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(Color(.label))

            Text("Unete y empieza a manejar\ntus finanzas en pareja")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Form Card

    private var formCard: some View {
        VStack(spacing: 20) {
            // Error
            if let error = localError ?? authViewModel.errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(.white).font(.subheadline)
                    Text(error)
                        .font(.caption).foregroundStyle(.white).lineLimit(2)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.fingetherDanger, in: RoundedRectangle(cornerRadius: 10))
                .onTapGesture { localError = nil; authViewModel.errorMessage = nil }
            }

            // Name
            VStack(alignment: .leading, spacing: 6) {
                Text("Nombre")
                    .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                HStack(spacing: 10) {
                    Text("😊")
                    TextField("Tu nombre", text: $authViewModel.displayName)
                        .textInputAutocapitalization(.words)
                }
                .padding(14)
                .background(Color(.systemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // Email
            VStack(alignment: .leading, spacing: 6) {
                Text("Correo")
                    .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                HStack(spacing: 10) {
                    Text("📧")
                    TextField("tu@correo.com", text: $authViewModel.email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                }
                .padding(14)
                .background(Color(.systemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // Password
            VStack(alignment: .leading, spacing: 6) {
                Text("Contrasena")
                    .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                HStack(spacing: 10) {
                    Text("🔒")
                    SecureField("Min. 6 caracteres", text: $authViewModel.password)
                }
                .padding(14)
                .background(Color(.systemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // Confirm password
            VStack(alignment: .leading, spacing: 6) {
                Text("Confirmar")
                    .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                HStack(spacing: 10) {
                    Text("🔐")
                    SecureField("Repite tu contrasena", text: $confirmPassword)
                }
                .padding(14)
                .background(Color(.systemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // Register button
            Button {
                localError = nil
                guard validateForm() else { return }
                Task { await authViewModel.signUp() }
            } label: {
                HStack(spacing: 8) {
                    if authViewModel.isLoading {
                        ProgressView().tint(.white)
                    }
                    Text("Crear Cuenta")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [Color.fingetherRose, Color.fingetherSky],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: Color.fingetherRose.opacity(0.3), radius: 10, y: 5)
            }
            .disabled(authViewModel.isLoading)
        }
        .padding(24)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.06), radius: 16, y: 8)
    }

    // MARK: - Validation

    private func validateForm() -> Bool {
        if authViewModel.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            localError = "El nombre es obligatorio."
            return false
        }
        if !authViewModel.email.isValidEmail {
            localError = "Ingresa un correo electronico valido."
            return false
        }
        if authViewModel.password.count < 6 {
            localError = "La contrasena debe tener al menos 6 caracteres."
            return false
        }
        if authViewModel.password != confirmPassword {
            localError = "Las contrasenas no coinciden."
            return false
        }
        return true
    }
}
