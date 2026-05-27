import SwiftUI

// MARK: - Privacy Policy View

struct PrivacyPolicyView: View {

    private let sections: [LegalSection] = [
        LegalSection(
            id: 1,
            title: "Datos que recopilamos",
            content: """
            Datos que proporcionas directamente:
            - Nombre y correo electronico al crear tu cuenta
            - Informacion financiera que ingresas manualmente (gastos, ingresos, presupuestos, metas de ahorro)
            - Preferencias de la App y configuracion de tu perfil
            - Codigo de vinculacion de pareja cuando decides compartir

            Datos recopilados automaticamente:
            - Identificador unico del dispositivo para autenticacion
            - Fecha y hora de uso de la App
            - Version de la App y sistema operativo
            - Datos de rendimiento y diagnostico para mejorar la experiencia

            Datos que NO recopilamos:
            - Informacion bancaria real ni numeros de cuenta
            - Datos de tarjetas de credito o debito
            - Ubicacion GPS ni datos de geolocalizacion
            - Contactos, fotos ni acceso a otros datos del dispositivo
            - Datos biometricos
            """
        ),
        LegalSection(
            id: 2,
            title: "Como usamos tus datos",
            content: """
            Utilizamos la informacion recopilada para los siguientes fines:
            - Proporcionar y mantener el servicio de Fingether, incluyendo el registro de transacciones, presupuestos y metas
            - Generar insights financieros personalizados mediante inteligencia artificial, procesados de forma segura en el servidor
            - Calcular y actualizar el estado de tu mascota virtual basado en tus habitos financieros
            - Sincronizar datos financieros compartidos entre parejas vinculadas en tiempo real
            - Enviar notificaciones relevantes sobre presupuestos, metas y alertas configuradas
            - Mejorar y optimizar la experiencia de usuario y el rendimiento de la App
            - Generar estadisticas agregadas y anonimizadas para mejorar el servicio
            """
        ),
        LegalSection(
            id: 3,
            title: "Datos compartidos con tu pareja",
            content: """
            Cuando vinculas tu cuenta con otra persona, se comparten los siguientes datos:
            - Gastos marcados como compartidos o de pareja
            - Presupuestos creados como conjuntos
            - Metas de ahorro compartidas y su progreso
            - Estado y nivel de la mascota virtual compartida
            - Logros desbloqueados en conjunto

            Datos que NUNCA se comparten con tu pareja:
            - Gastos marcados como personales
            - Tu contrasena ni credenciales de acceso
            - Presupuestos individuales
            - Metas de ahorro personales
            - Historial de transacciones personales anteriores a la vinculacion
            """
        ),
        LegalSection(
            id: 4,
            title: "Almacenamiento y seguridad",
            content: """
            La seguridad de tus datos es nuestra prioridad. Implementamos las siguientes medidas:
            - Todos los datos se transmiten mediante cifrado HTTPS/TLS en transito
            - Los datos se almacenan en servidores seguros de Supabase con cifrado en reposo
            - Los tokens de autenticacion se almacenan de forma segura en el Keychain del dispositivo, nunca en almacenamiento no seguro
            - Implementamos Row Level Security (RLS) en cada tabla de la base de datos, garantizando que solo puedas acceder a tus propios datos
            - Las claves de API sensibles se mantienen exclusivamente en el servidor, nunca en la aplicacion del cliente
            - Se aplica validacion y sanitizacion de datos tanto en el cliente como en el servidor
            - Realizamos auditorias periodicas de seguridad y actualizamos nuestras practicas conforme a los estandares de la industria
            """
        ),
        LegalSection(
            id: 5,
            title: "Compartir con terceros",
            content: """
            NO vendemos, alquilamos ni comercializamos tus datos personales a terceros bajo ninguna circunstancia.

            Solo compartimos informacion en los siguientes casos limitados:
            - Proveedores de infraestructura: Utilizamos Supabase para el almacenamiento seguro de datos y autenticacion, y Anthropic (Claude) para el procesamiento de insights financieros mediante inteligencia artificial, siempre en el servidor y nunca exponiendo datos directamente
            - Requerimiento legal: Cuando sea necesario para cumplir con una obligacion legal, orden judicial o requerimiento de autoridad competente
            - Proteccion de derechos: Para proteger los derechos, propiedad o seguridad de Fingether, nuestros usuarios o el publico

            Todos los proveedores de infraestructura estan sujetos a acuerdos de confidencialidad y procesamiento de datos.
            """
        ),
        LegalSection(
            id: 6,
            title: "Tus derechos",
            content: """
            De acuerdo con las regulaciones de proteccion de datos aplicables, incluyendo GDPR y CCPA, tienes los siguientes derechos:
            - Acceso: Solicitar una copia completa de todos los datos personales que tenemos sobre ti
            - Rectificacion: Corregir cualquier dato personal inexacto o incompleto directamente desde la App o contactandonos
            - Eliminacion: Solicitar la eliminacion de tu cuenta y todos los datos asociados en cualquier momento
            - Exportacion: Descargar tus datos en un formato estructurado y legible por maquina
            - Retirar consentimiento: Revocar tu consentimiento para el procesamiento de datos en cualquier momento, lo cual puede limitar la funcionalidad de la App
            - Oposicion: Oponerte al procesamiento de tus datos para fines especificos
            - Portabilidad: Recibir tus datos en un formato interoperable para transferirlos a otro servicio

            Para ejercer cualquiera de estos derechos, contactanos en soporte@fingether.app. Responderemos a tu solicitud en un plazo maximo de 30 dias.
            """
        ),
        LegalSection(
            id: 7,
            title: "Retencion de datos",
            content: """
            Conservamos tus datos personales mientras tu cuenta este activa y sea necesario para proporcionarte el servicio. Tras la eliminacion de tu cuenta:
            - Tus datos personales se eliminan de nuestros sistemas activos dentro de los 30 dias siguientes
            - Los datos compartidos con tu pareja se desvinculan y anonimizan
            - Las copias de seguridad que puedan contener tus datos se eliminan en el siguiente ciclo de rotacion programado
            - Datos anonimizados y agregados pueden conservarse indefinidamente para fines estadisticos y de mejora del servicio, sin posibilidad de identificacion personal
            """
        ),
        LegalSection(
            id: 8,
            title: "Menores de edad",
            content: "Fingether esta disenado exclusivamente para usuarios de 16 anos o mas. No recopilamos intencionalmente datos personales de menores de 16 anos. Si descubrimos que hemos recopilado datos de un menor sin el consentimiento parental adecuado, eliminaremos esa informacion de forma inmediata. Si eres padre o tutor y crees que tu hijo menor de 16 anos nos ha proporcionado datos personales, contactanos en soporte@fingether.app para que podamos tomar las medidas necesarias."
        ),
        LegalSection(
            id: 9,
            title: "Cookies y seguimiento",
            content: "Fingether es una aplicacion nativa para iOS y NO utiliza cookies de navegador. NO implementamos tecnologias de seguimiento publicitario ni compartimos datos con redes de publicidad. NO utilizamos pixels de seguimiento ni tecnologias similares. Los unicos datos de analitica recopilados son para mejorar el rendimiento y la experiencia de la App, y se procesan de forma anonimizada y agregada."
        ),
        LegalSection(
            id: 10,
            title: "Transferencias internacionales",
            content: "Tus datos pueden ser procesados en servidores ubicados fuera de tu pais de residencia, en las regiones donde opera nuestra infraestructura de servidores. En estos casos, nos aseguramos de que existan salvaguardas adecuadas para proteger tus datos conforme a las leyes de proteccion de datos aplicables, incluyendo clausulas contractuales tipo y mecanismos de certificacion reconocidos internacionalmente."
        ),
        LegalSection(
            id: 11,
            title: "Cambios a esta politica",
            content: "Podemos actualizar esta Politica de Privacidad periodicamente para reflejar cambios en nuestras practicas, tecnologias o requisitos legales. Te notificaremos de cambios significativos a traves de una notificacion en la App o por correo electronico antes de que los cambios entren en vigor. Te recomendamos revisar esta politica regularmente. La fecha de la ultima actualizacion se indica al final de este documento."
        ),
        LegalSection(
            id: 12,
            title: "Contacto",
            content: "Si tienes preguntas, comentarios o solicitudes relacionadas con esta Politica de Privacidad o el tratamiento de tus datos personales, puedes contactarnos en soporte@fingether.app. Nos comprometemos a responder a todas las consultas en un plazo maximo de 30 dias habiles."
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
            .navigationTitle("Politica de privacidad")
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
    PrivacyPolicyView()
}
