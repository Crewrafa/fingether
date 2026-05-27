import SwiftUI

// MARK: - Legal Section Model

struct LegalSection: Identifiable {
    let id: Int
    let title: String
    let content: String
}

// MARK: - Terms View

struct TermsView: View {

    private let sections: [LegalSection] = [
        LegalSection(
            id: 1,
            title: "Aceptacion de los terminos",
            content: "Al descargar, acceder o utilizar la aplicacion Fingether, aceptas estos Terminos y Condiciones en su totalidad. Si no estas de acuerdo con alguno de los terminos aqui establecidos, no utilices la App. El uso continuado de Fingether constituye la aceptacion de estos terminos y cualquier actualizacion futura que se realice."
        ),
        LegalSection(
            id: 2,
            title: "Descripcion del servicio",
            content: "Fingether es una aplicacion de gestion de finanzas personales y en pareja que permite registrar gastos, establecer presupuestos, crear metas de ahorro, planificar viajes y simular escenarios financieros. La App incluye funcionalidades como una mascota virtual que refleja tu salud financiera, insights generados por inteligencia artificial y herramientas de planificacion colaborativa. Fingether no es un servicio financiero, bancario ni de asesoria de inversion. La informacion proporcionada es orientativa y no sustituye el consejo de un profesional financiero certificado."
        ),
        LegalSection(
            id: 3,
            title: "Registro y cuenta",
            content: "Para usar Fingether necesitas crear una cuenta proporcionando informacion basica como tu nombre y correo electronico. Eres responsable de mantener la confidencialidad de tus credenciales de acceso y de todas las actividades que ocurran bajo tu cuenta. Debes tener al menos 16 anos para crear una cuenta y utilizar la App. Si detectas uso no autorizado de tu cuenta, debes notificarnos inmediatamente a traves de los canales de soporte."
        ),
        LegalSection(
            id: 4,
            title: "Uso aceptable",
            content: "Te comprometes a usar la App solo para fines personales y legitimos de gestion financiera. No debes intentar acceder a datos de otros usuarios sin autorizacion, usar la App para actividades ilegales o fraudulentas, intentar vulnerar la seguridad del sistema, realizar ingenieria inversa del software, ni utilizar la App de manera que pueda danar, deshabilitar o sobrecargar nuestros servidores o infraestructura."
        ),
        LegalSection(
            id: 5,
            title: "Funcionalidad de pareja",
            content: "La vinculacion de cuentas en pareja implica compartir ciertos datos financieros con la persona vinculada, incluyendo gastos compartidos, presupuestos conjuntos, metas de ahorro en comun y el estado de la mascota virtual. Los gastos marcados como personales nunca se comparten con tu pareja vinculada. Al desvincular las cuentas, los datos compartidos se eliminan de la vista del otro usuario, aunque se mantienen en tu historial personal. Ambos miembros de la pareja deben aceptar la vinculacion de forma explicita."
        ),
        LegalSection(
            id: 6,
            title: "Datos financieros",
            content: "La informacion financiera que ingresas en Fingether es proporcionada voluntariamente por ti. Fingether no se conecta directamente a cuentas bancarias, tarjetas de credito ni ninguna institucion financiera. Todos los datos son ingresados manualmente por el usuario. Los calculos, estadisticas y simulaciones presentados en la App son orientativos y pueden no reflejar con exactitud tu situacion financiera real."
        ),
        LegalSection(
            id: 7,
            title: "Simuladores",
            content: "Los simuladores financieros disponibles en Fingether, incluyendo simuladores de ahorro, inversion, credito hipotecario y planificacion de viajes, proporcionan calculos estimados basados en los parametros que ingresas y formulas financieras estandar. Estos resultados no constituyen asesoria financiera profesional ni garantizan resultados reales. Las proyecciones pueden variar significativamente de los resultados reales. Te recomendamos consultar con un profesional financiero certificado antes de tomar decisiones importantes basandote en estas simulaciones."
        ),
        LegalSection(
            id: 8,
            title: "Propiedad intelectual",
            content: "Fingether, incluyendo su diseno, codigo fuente, interfaz de usuario, logotipos, iconos, animaciones de la mascota virtual y marca comercial son propiedad exclusiva de Fingether. No se otorga ninguna licencia ni derecho sobre la propiedad intelectual mas alla del uso personal de la App conforme a estos terminos. Queda prohibida la reproduccion, distribucion o modificacion de cualquier elemento de la App sin autorizacion expresa por escrito."
        ),
        LegalSection(
            id: 9,
            title: "Disponibilidad",
            content: "La App se proporciona \"tal cual\" y \"segun disponibilidad\". No garantizamos que Fingether este disponible de forma ininterrumpida, que este libre de errores o que los defectos seran corregidos en un plazo determinado. Nos reservamos el derecho de modificar, suspender o discontinuar cualquier funcionalidad de la App en cualquier momento, con o sin previo aviso. Realizaremos esfuerzos razonables para notificar cambios significativos con anticipacion."
        ),
        LegalSection(
            id: 10,
            title: "Limitacion de responsabilidad",
            content: "En la maxima medida permitida por la ley aplicable, Fingether no es responsable por decisiones financieras tomadas basandose en la informacion proporcionada por la App, perdida de datos debido a fallos tecnicos o circunstancias fuera de nuestro control, danos indirectos, incidentales, especiales o consecuentes derivados del uso de la App, ni inexactitudes en los calculos de simuladores o proyecciones financieras. El uso de la App es bajo tu propio riesgo."
        ),
        LegalSection(
            id: 11,
            title: "Modificaciones",
            content: "Nos reservamos el derecho de actualizar estos Terminos y Condiciones en cualquier momento. Te notificaremos de cambios significativos a traves de la App o por correo electronico. El uso continuado de Fingether despues de la notificacion de cambios constituye la aceptacion de los terminos modificados. Te recomendamos revisar estos terminos periodicamente."
        ),
        LegalSection(
            id: 12,
            title: "Terminacion",
            content: "Puedes eliminar tu cuenta en cualquier momento desde la configuracion de la App. Al eliminar tu cuenta, tus datos personales seran eliminados conforme a nuestra Politica de Privacidad. Nos reservamos el derecho de suspender o terminar cuentas que violen estos Terminos y Condiciones, que se utilicen de forma fraudulenta o que pongan en riesgo la seguridad de otros usuarios o de la plataforma."
        ),
        LegalSection(
            id: 13,
            title: "Ley aplicable",
            content: "Estos Terminos y Condiciones se rigen e interpretan de acuerdo con las leyes aplicables en la jurisdiccion del usuario. Cualquier disputa que surja en relacion con estos terminos sera resuelta en los tribunales competentes de dicha jurisdiccion, salvo que la legislacion local del usuario establezca disposiciones mas favorables."
        ),
        LegalSection(
            id: 14,
            title: "Contacto",
            content: "Si tienes preguntas, comentarios o inquietudes sobre estos Terminos y Condiciones, puedes contactarnos en soporte@fingether.app. Haremos nuestro mejor esfuerzo por responder en un plazo razonable."
        )
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ForEach(sections) { section in
                        sectionView(section)

                        if section.id < sections.count {
                            Divider()
                        }
                    }

                    footerView
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Terminos y condiciones")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Section View

    @ViewBuilder
    private func sectionView(_ section: LegalSection) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(section.id).")
                .font(.headline)
                .bold()
                .foregroundStyle(Color.fingetherPrimary)

            Text(section.title)
                .font(.subheadline)
                .bold()
                .foregroundStyle(Color(.label))

            Text(section.content)
                .font(.subheadline)
                .foregroundStyle(Color(.label))
                .lineSpacing(6)
        }
    }

    // MARK: - Footer

    private var footerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Ultima actualizacion: Abril 2026")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let url = URL(string: "mailto:soporte@fingether.app") {
                Link("Contacto: soporte@fingether.app", destination: url)
                    .font(.caption)
                    .foregroundStyle(Color.fingetherPrimary)
            }
        }
        .padding(.top, 8)
    }
}

// MARK: - Preview

#Preview {
    TermsView()
}
