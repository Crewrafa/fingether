import SwiftUI

// MARK: - Data Models

struct FAQItem: Identifiable {
    let id = UUID()
    let question: String
    let answer: String
}

struct FAQSection: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let items: [FAQItem]
}

// MARK: - FAQ View

struct FAQView: View {
    @State private var searchText = ""
    @State private var expandedItems: Set<UUID> = []

    private let sections: [FAQSection] = FAQContent.allSections

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                searchBar

                if searchText.isEmpty {
                    sectionedList
                } else {
                    filteredList
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Preguntas frecuentes")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Buscar pregunta...", text: $searchText)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
            if !searchText.isEmpty {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        searchText = ""
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Sectioned List

    private var sectionedList: some View {
        ForEach(sections) { section in
            VStack(alignment: .leading, spacing: 12) {
                Label(section.title, systemImage: section.icon)
                    .font(.headline)
                    .foregroundStyle(Color(.label))
                    .padding(.leading, 4)
                    .padding(.top, 4)

                VStack(spacing: 0) {
                    ForEach(Array(section.items.enumerated()), id: \.element.id) { index, item in
                        faqRow(item: item)
                        if index < section.items.count - 1 {
                            Divider()
                                .padding(.horizontal, 16)
                        }
                    }
                }
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    // MARK: - Filtered List

    private var filteredList: some View {
        let filtered = sections
            .flatMap(\.items)
            .filter { $0.question.localizedCaseInsensitiveContains(searchText) }

        return Group {
            if filtered.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No se encontraron resultados")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(filtered.enumerated()), id: \.element.id) { index, item in
                        faqRow(item: item)
                        if index < filtered.count - 1 {
                            Divider()
                                .padding(.horizontal, 16)
                        }
                    }
                }
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    // MARK: - FAQ Row

    private func faqRow(item: FAQItem) -> some View {
        let isExpanded = expandedItems.contains(item.id)

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                if isExpanded {
                    expandedItems.remove(item.id)
                } else {
                    expandedItems.insert(item.id)
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center, spacing: 12) {
                    Text(item.question)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color(.label))
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.fingetherPrimary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 16)

                if isExpanded {
                    Text(item.answer)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineSpacing(6)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 14)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - FAQ Content

private enum FAQContent {
    static let allSections: [FAQSection] = [
        FAQSection(
            title: "Primeros pasos",
            icon: "star.fill",
            items: [
                FAQItem(
                    question: "¿Como creo mi cuenta en Fingether?",
                    answer: "Descarga Fingether desde la App Store, abre la app y selecciona \"Crear cuenta\". Puedes registrarte con tu correo electronico o usar tu cuenta de Apple. Completa tu perfil con tu nombre y moneda preferida, y listo."
                ),
                FAQItem(
                    question: "¿Como vinculo a mi pareja?",
                    answer: "Ve a Ajustes > Pareja y selecciona \"Invitar pareja\". Se generara un codigo unico de 6 digitos que tu pareja debe ingresar en su app dentro de Ajustes > Pareja > \"Tengo un codigo\". El vinculo se activa al instante y comenzaran a compartir datos financieros."
                ),
                FAQItem(
                    question: "¿Puedo usar Fingether sin pareja?",
                    answer: "Si, Fingether funciona perfecto de forma individual. Puedes registrar tus gastos, crear presupuestos y cuidar a tu mascota virtual. Cuando quieras, puedes vincular a tu pareja en cualquier momento desde Ajustes."
                ),
                FAQItem(
                    question: "¿Que es la mascota virtual?",
                    answer: "Es un companero digital estilo Tamagotchi que refleja tu salud financiera. Si mantienes buenos habitos de ahorro y respetas tus presupuestos, tu mascota estara feliz y evolucionara. Si gastas de mas, se pondra triste. Es una forma divertida de motivarte a mejorar tus finanzas."
                ),
                FAQItem(
                    question: "¿Fingether es gratis?",
                    answer: "Fingether ofrece un plan gratuito con funciones basicas: registro de gastos, presupuestos simples y la mascota virtual. El plan Premium desbloquea insights con inteligencia artificial, metas de ahorro avanzadas, categorias ilimitadas y mas personalizaciones para tu mascota."
                )
            ]
        ),
        FAQSection(
            title: "Gastos y finanzas",
            icon: "dollarsign.circle.fill",
            items: [
                FAQItem(
                    question: "¿Como registro un gasto?",
                    answer: "Toca el boton \"+\" en la pantalla principal. Ingresa el monto, selecciona una categoria, anade una descripcion opcional y elige quien realizo el gasto (tu o tu pareja). Tambien puedes usar el comando de voz para registrar gastos hablando."
                ),
                FAQItem(
                    question: "¿Puedo crear categorias personalizadas?",
                    answer: "Si, en la version Premium puedes crear categorias personalizadas con icono y color a tu gusto. En el plan gratuito cuentas con las categorias predeterminadas: Comida, Transporte, Entretenimiento, Hogar, Salud, Educacion, Ropa y Otros."
                ),
                FAQItem(
                    question: "¿Como funcionan los presupuestos?",
                    answer: "Ve a la seccion Presupuestos y crea uno nuevo seleccionando categoria, monto limite y periodo (semanal, quincenal o mensual). Fingether te avisara cuando alcances el 80% y el 100% de tu presupuesto. Puedes ver el progreso en tiempo real con graficas visuales."
                ),
                FAQItem(
                    question: "¿Los gastos se comparten automaticamente con mi pareja?",
                    answer: "Si, una vez vinculados, todos los gastos que ambos registren se sincronizan en tiempo real. Cada uno puede ver los gastos del otro en el dashboard compartido. Puedes filtrar para ver solo tus gastos, los de tu pareja o los de ambos."
                ),
                FAQItem(
                    question: "¿Puedo editar o eliminar un gasto?",
                    answer: "Si, desliza el gasto hacia la izquierda en la lista de transacciones para ver las opciones de editar o eliminar. Tambien puedes tocar cualquier gasto para ver su detalle y editarlo desde ahi. Los cambios se reflejan inmediatamente en tus presupuestos y estadisticas."
                )
            ]
        ),
        FAQSection(
            title: "Funcionalidades",
            icon: "sparkles",
            items: [
                FAQItem(
                    question: "¿Como funcionan los insights con IA?",
                    answer: "Fingether analiza tus patrones de gasto usando inteligencia artificial y te ofrece consejos personalizados. Por ejemplo, puede detectar que gastas mas en restaurantes los fines de semana y sugerirte alternativas. Los insights se actualizan semanalmente y estan disponibles en el plan Premium."
                ),
                FAQItem(
                    question: "¿Como uso el registro por voz?",
                    answer: "Toca el icono de microfono en la pantalla principal y di algo como \"Gaste 150 pesos en el super\". Fingether interpretara el monto, la categoria y la descripcion automaticamente. Revisa que todo este correcto y confirma para registrar el gasto."
                ),
                FAQItem(
                    question: "¿Que son las metas de ahorro?",
                    answer: "Son objetivos financieros que puedes crear para ahorrar hacia algo especifico, como unas vacaciones o un gadget. Define el monto objetivo y la fecha limite. Fingether te mostrara tu progreso y tu mascota te animara a seguir ahorrando."
                ),
                FAQItem(
                    question: "¿Como funcionan los logros?",
                    answer: "Fingether te premia con logros por buenos habitos financieros: registrar gastos diariamente, mantenerte dentro del presupuesto, alcanzar metas de ahorro, entre otros. Cada logro desbloquea accesorios y personalizaciones para tu mascota virtual."
                ),
                FAQItem(
                    question: "¿Puedo exportar mis datos?",
                    answer: "Si, ve a Ajustes > Exportar datos. Puedes descargar un archivo CSV con todas tus transacciones filtradas por rango de fecha. El archivo incluye fecha, monto, categoria, descripcion y quien registro cada gasto."
                )
            ]
        ),
        FAQSection(
            title: "Cuenta y seguridad",
            icon: "lock.shield.fill",
            items: [
                FAQItem(
                    question: "¿Mis datos financieros estan seguros?",
                    answer: "Absolutamente. Fingether usa cifrado de extremo a extremo para proteger tus datos. Tu informacion financiera se almacena de forma segura en servidores con certificacion SOC 2. Nunca compartimos ni vendemos tus datos a terceros."
                ),
                FAQItem(
                    question: "¿Como cambio mi contrasena?",
                    answer: "Ve a Ajustes > Cuenta > Cambiar contrasena. Ingresa tu contrasena actual y luego la nueva contrasena dos veces para confirmar. Te recomendamos usar una contrasena fuerte con al menos 8 caracteres, incluyendo mayusculas, numeros y simbolos."
                ),
                FAQItem(
                    question: "¿Puedo desvincular a mi pareja?",
                    answer: "Si, ve a Ajustes > Pareja > Desvincular. Esta accion requiere confirmacion y es irreversible: los datos compartidos permaneceran en ambas cuentas pero dejaran de sincronizarse. Podran vincularse nuevamente en el futuro si lo desean."
                ),
                FAQItem(
                    question: "¿Como elimino mi cuenta?",
                    answer: "Ve a Ajustes > Cuenta > Eliminar cuenta. Esta accion es permanente y eliminara todos tus datos, incluyendo transacciones, presupuestos, mascota y logros. Si tienes pareja vinculada, se desvinculara automaticamente antes de eliminar tu cuenta. Tienes 30 dias para reactivarla."
                )
            ]
        )
    ]
}

// MARK: - Preview

#Preview {
    NavigationStack {
        FAQView()
    }
}
