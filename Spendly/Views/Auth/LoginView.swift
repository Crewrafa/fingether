import SwiftUI

// MARK: - Double Wave (depth effect — two layers, slightly offset)

private struct WaveBack: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: rect.height * 0.45))
        p.addCurve(
            to: CGPoint(x: rect.width, y: rect.height * 0.55),
            control1: CGPoint(x: rect.width * 0.25, y: rect.height * 0.0),
            control2: CGPoint(x: rect.width * 0.75, y: rect.height * 1.0)
        )
        p.addLine(to: CGPoint(x: rect.width, y: 0))
        p.addLine(to: .zero)
        p.closeSubpath()
        return p
    }
}

private struct WaveFront: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: rect.height * 0.50))
        p.addCurve(
            to: CGPoint(x: rect.width, y: rect.height * 0.65),
            control1: CGPoint(x: rect.width * 0.35, y: rect.height * 0.10),
            control2: CGPoint(x: rect.width * 0.65, y: rect.height * 0.95)
        )
        p.addLine(to: CGPoint(x: rect.width, y: 0))
        p.addLine(to: .zero)
        p.closeSubpath()
        return p
    }
}

// MARK: - Login View

struct LoginView: View {

    @Bindable var authViewModel: AuthViewModel
    @State private var showRegister = false
    @State private var showResetPassword = false
    @State private var showPassword = false
    @State private var btnScale: CGFloat = 1.0
    @State private var emailFocused = false
    @State private var passwordFocused = false
    @Environment(\.colorScheme) private var cs
    @FocusState private var focusedField: LoginField?

    enum LoginField { case email, password }

    // Stagger animation states
    @State private var showLogo = false
    @State private var showTitle = false
    @State private var showTagline = false
    @State private var showFields = false
    @State private var showButton = false
    @State private var showSocial = false
    @State private var showFooter = false

    // Multi-color palette
    private let primary = Color.fingetherPrimary
    private let primaryDark = Color.fingetherPrimaryDark
    private let sky = Color(hex: "0EA5E9")
    private let rose = Color(hex: "F4A5AE")
    private let slate = Color(hex: "475569")
    private let slateLight = Color(hex: "94A3B8")
    private var fieldBg: Color { cs == .dark ? Color(hex: "1E2E2A") : Color(hex: "FAFBFF") }
    private let fieldBorderDefault = Color(hex: "E2E8F0")

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let totalH = geo.size.height
                let safeTop = geo.safeAreaInsets.top
                let safeBottom = geo.safeAreaInsets.bottom
                let headerH = totalH * 0.40

                ZStack {
                    // ── Rich gradient: primary pink → sky hint → warm white ──
                    LinearGradient(
                        stops: [
                            .init(color: cs == .dark ? Color(hex: "6B1450") : primary, location: 0),
                            .init(color: cs == .dark ? Color(hex: "1A2840") : sky.opacity(0.30), location: 0.45),
                            .init(color: cs == .dark ? Color(hex: "1A1A2E") : Color(hex: "FAFBFF"), location: 1.0),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()

                    // ── Decorative bokeh circles (glassmorphism depth) ──
                    Circle()
                        .fill(rose.opacity(cs == .dark ? 0.04 : 0.07))
                        .frame(width: 260, height: 260)
                        .blur(radius: 70)
                        .offset(x: 100, y: -totalH * 0.15)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .ignoresSafeArea()

                    Circle()
                        .fill(sky.opacity(cs == .dark ? 0.04 : 0.06))
                        .frame(width: 200, height: 200)
                        .blur(radius: 60)
                        .offset(x: -80, y: totalH * 0.35)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                        .ignoresSafeArea()

                    // ── Double wave: back (wider, lighter) + front (narrower, offset) ──
                    WaveBack()
                        .fill(primary.opacity(cs == .dark ? 0.10 : 0.20))
                        .frame(height: headerH * 1.2)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .ignoresSafeArea(edges: .top)

                    WaveFront()
                        .fill(primary.opacity(cs == .dark ? 0.06 : 0.10))
                        .frame(height: headerH * 1.2)
                        .offset(y: 10)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .ignoresSafeArea(edges: .top)

                    // ── Content ──
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            headerContent(safeTop: safeTop, height: headerH)
                            formContent
                                .padding(.top, 8)
                            Spacer(minLength: 24)
                            bottomContent
                                .padding(.bottom, max(safeBottom + 8, 24))
                        }
                        .frame(minHeight: totalH)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                    .scrollDismissesKeyboard(.interactively)
                }
            }
            .ignoresSafeArea(edges: .top)
            .navigationDestination(isPresented: $showRegister) {
                RegisterView(authViewModel: authViewModel, showRegister: $showRegister)
            }
            .alert("Recuperar contrasena", isPresented: $showResetPassword) {
                TextField("Correo electronico", text: $authViewModel.email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                Button("Enviar") { Task { await authViewModel.resetPassword() } }
                Button("Cancelar", role: .cancel) {}
            } message: {
                Text("Ingresa tu correo y te enviaremos un enlace para restablecer tu contrasena.")
            }
            .onAppear { stagger() }
        }
    }

    // MARK: - Header Content

    private func headerContent(safeTop: CGFloat, height: CGFloat) -> some View {
        VStack(spacing: 12) {
            Spacer().frame(height: max(safeTop + 16, 56))

            // Logo — $ in white, heart in rose, white glow
            ZStack {
                // Glow
                Circle()
                    .fill(.white.opacity(0.30))
                    .frame(width: 92, height: 92)
                    .blur(radius: 20)

                Text("$")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Image(systemName: "heart.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(rose)
                    .offset(x: 22, y: -22)
            }
            .scaleEffect(showLogo ? 1.0 : 0.8)
            .opacity(showLogo ? 1 : 0)
            .onTapGesture(count: 3) {
                authViewModel.enterDevMode()
            }

            Text("Fingether")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .opacity(showTitle ? 1 : 0)
                .offset(y: showTitle ? 0 : 6)

            Text("Las cuentas claras, el amor intacto ✨")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
                .opacity(showTagline ? 1 : 0)

            Spacer(minLength: 0)
        }
        .frame(height: height)
    }

    // MARK: - Form Content

    private var formContent: some View {
        VStack(spacing: 16) {
            Text("Iniciar sesión")
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundStyle(slate)
                .frame(maxWidth: .infinity, alignment: .leading)
                .opacity(showFields ? 1 : 0)

            // Error
            if let error = authViewModel.errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(.white).font(.subheadline)
                    Text(error).font(.caption).foregroundStyle(.white).lineLimit(2)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.fingetherDanger, in: RoundedRectangle(cornerRadius: 10))
                .onTapGesture { authViewModel.errorMessage = nil }
            }

            // Email — envelope icon in teal
            HStack(spacing: 10) {
                Image(systemName: "envelope")
                    .font(.system(size: 16))
                    .foregroundStyle(primary)
                    .frame(width: 22)
                TextField("Correo electrónico", text: $authViewModel.email)
                    .font(.system(size: 15))
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .email)
            }
            .frame(height: 52)
            .padding(.horizontal, 16)
            .background(fieldBg)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(focusedField == .email ? primary : fieldBorderDefault, lineWidth: focusedField == .email ? 1.5 : 0.5)
                    .animation(.easeInOut(duration: 0.2), value: focusedField)
            )
            .opacity(showFields ? 1 : 0)
            .offset(y: showFields ? 0 : 10)

            // Password — lock icon in sky (different from email)
            HStack(spacing: 10) {
                Image(systemName: "lock")
                    .font(.system(size: 16))
                    .foregroundStyle(sky)
                    .frame(width: 22)
                Group {
                    if showPassword {
                        TextField("Contraseña", text: $authViewModel.password)
                    } else {
                        SecureField("Contraseña", text: $authViewModel.password)
                    }
                }
                .font(.system(size: 15))
                .focused($focusedField, equals: .password)
                Button { showPassword.toggle() } label: {
                    Image(systemName: showPassword ? "eye.slash" : "eye")
                        .font(.system(size: 14))
                        .foregroundStyle(slateLight)
                }
            }
            .frame(height: 52)
            .padding(.horizontal, 16)
            .background(fieldBg)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(focusedField == .password ? sky : fieldBorderDefault, lineWidth: focusedField == .password ? 1.5 : 0.5)
                    .animation(.easeInOut(duration: 0.2), value: focusedField)
            )
            .opacity(showFields ? 1 : 0)
            .offset(y: showFields ? 0 : 10)

            // Forgot password — in sky (different from button primary)
            HStack {
                Spacer()
                Button { showResetPassword = true } label: {
                    Text("Olvidé mi contraseña")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(sky)
                }
            }
            .opacity(showFields ? 1 : 0)

            // Sign in button — enters new user mode (clean onboarding)
            Button {
                authViewModel.enterNewUserMode()
            } label: {
                HStack(spacing: 8) {
                    if authViewModel.isLoading {
                        ProgressView().tint(.white)
                    }
                    Text("Iniciar sesión")
                        .font(.system(size: 17, weight: .bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    LinearGradient(
                        colors: [primary, primaryDark],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .scaleEffect(btnScale)
            }
            .disabled(authViewModel.isLoading)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in withAnimation(.spring(response: 0.15)) { btnScale = 0.97 } }
                    .onEnded { _ in withAnimation(.spring(response: 0.15)) { btnScale = 1.0 } }
            )
            .opacity(showButton ? 1 : 0)
            .offset(y: showButton ? 0 : 12)
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Bottom Content

    private var bottomContent: some View {
        VStack(spacing: 20) {
            Text("o continúa con")
                .font(.caption)
                .foregroundStyle(slateLight)
                .opacity(showSocial ? 1 : 0)

            // Social circles with subtle shadow
            HStack(spacing: 20) {
                socialCircle(bg: .black, border: cs == .dark ? Color.white.opacity(0.15) : .clear) {
                    Image(systemName: "apple.logo")
                        .font(.system(size: 20))
                        .foregroundStyle(.white)
                }
                socialCircle(bg: cs == .dark ? Color(hex: "1E2E2A") : .white, border: fieldBorderDefault) {
                    Text("G")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(hex: "4285F4"))
                }
                socialCircle(bg: Color(hex: "1877F2"), border: .clear) {
                    Text("f")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
            .opacity(showSocial ? 1 : 0)

            VStack(spacing: 10) {
                HStack(spacing: 4) {
                    Text("No tienes cuenta?")
                        .font(.footnote)
                        .foregroundStyle(slateLight)
                    Button { showRegister = true } label: {
                        Text("Crear cuenta")
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(primary)
                    }
                }

                // TODO: REMOVE BEFORE PRODUCTION
                Button {
                    authViewModel.enterDevMode()
                } label: {
                    Text("⚡ Saltar al app (Dev)")
                        .font(.caption2)
                        .foregroundStyle(slateLight.opacity(0.5))
                }
            }
            .opacity(showFooter ? 1 : 0)
        }
    }

    // MARK: - Social Circle

    private func socialCircle<V: View>(bg: Color, border: Color, @ViewBuilder icon: () -> V) -> some View {
        Button { authViewModel.enterDevMode() } label: {
            icon()
                .frame(width: 56, height: 56)
                .background(bg)
                .clipShape(Circle())
                .overlay(Circle().stroke(border, lineWidth: 0.5))
                .shadow(color: .black.opacity(cs == .dark ? 0.2 : 0.08), radius: 2, y: 2)
        }
    }

    // MARK: - Stagger

    private func stagger() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1)) { showLogo = true }
        withAnimation(.easeOut(duration: 0.5).delay(0.3)) { showTitle = true }
        withAnimation(.easeOut(duration: 0.4).delay(0.5)) { showTagline = true }
        withAnimation(.easeOut(duration: 0.5).delay(0.6)) { showFields = true }
        withAnimation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.8)) { showButton = true }
        withAnimation(.easeOut(duration: 0.4).delay(1.0)) { showSocial = true }
        withAnimation(.easeOut(duration: 0.3).delay(1.2)) { showFooter = true }
    }

}
