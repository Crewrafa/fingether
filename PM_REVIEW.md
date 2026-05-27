# Spendly -- Product Review & Recommendations

> ⚠️ **OUTDATED — el codigo actual NO implementa este diseño.**
>
> Este documento describe una propuesta del PM con: tab bar de 5 elementos con FAB central "+", tab "Pet" eliminada, tab dedicada "Gastos Fijos", layout especifico del Dashboard, modelo de splitting nuevo, etc. Algunas ideas se adoptaron (split type, Settings completos, Couple-first), pero el layout y la navegacion **no coinciden con el codigo actual**:
>
> - Tabs reales (`MainTabView.swift`): `transactions, fixedExpenses, dashboard, savings, settings`. NO hay FAB central, NO hay Pet tab.
> - Pet feature sigue en modelos / SQL / `MockDataService` pero NO se renderiza en ninguna view.
> - El layout del Dashboard difiere del propuesto en la Sección 6.
>
> Tratar este archivo como **referencia historica de diseño**, no como spec vivo. Antes de implementar cualquier sección, confirmar con el codigo actual.

---

**Fecha:** Abril 2026
**Autor:** PM Review
**Estado:** Para implementacion inmediata (HISTORICO)

---

## Seccion 1: Analisis Competitivo

### Que hacen bien las mejores apps de finanzas en pareja

**Honeydue**
- Cada miembro ve las cuentas del otro con nivel de visibilidad configurable (total, parcial, nada)
- Chat integrado por transaccion: puedes comentar "que es esto?" directamente sobre un gasto
- Categorias compartidas con emojis personalizables
- Alertas cuando la pareja registra un gasto grande
- "Bills" dedicado: una seccion solo para cuentas fijas con recordatorios de pago
- Balance de quien-debe-a-quien siempre visible

**Splitwise**
- Modelo de deudas simplificado: no importa cuantas transacciones haya, siempre muestra un unico saldo neto
- Multiples grupos (no solo pareja, tambien roommates, viajes, etc.)
- Splitting flexible: partes iguales, porcentaje, montos exactos, por participacion
- Historial de pagos/settlements con confirmacion de ambas partes
- Recibos con foto integrados

**Zeta**
- Cuentas bancarias reales conectadas (Plaid) -- las transacciones se importan automaticamente
- Vista "Yours, Mine, Ours" como concepto central de la UI
- Presupuestos por categoria con progreso visual claro
- Metas de ahorro compartidas con contribucion visible de cada persona
- Onboarding que pregunta el "money style" de cada persona

**Goodbudget**
- Sistema de sobres (envelopes) que es visual e intuitivo
- Sobres compartidos entre dispositivos en tiempo real
- Reportes mensuales con comparativas vs meses anteriores
- Filosofia zero-based budgeting que obliga a asignar cada peso

### Que le falta a Spendly hoy

| Feature | Estado actual | Prioridad |
|---------|--------------|-----------|
| Split configurable por transaccion (50/50, proporcional, custom) | NO existe -- solo hay toggle "compartido si/no" | CRITICA |
| Balance quien-debe-a-quien | NO existe | CRITICA |
| Gastos fijos como seccion dedicada (no solo tag en dashboard) | Solo card en dashboard | ALTA |
| Visualizacion "Mio / Tuyo / Nuestro" clara | Parcial -- cards en dashboard | ALTA |
| Notificaciones cuando la pareja agrega gasto | En modelo pero sin UI real | ALTA |
| Comentarios/reacciones en transacciones | NO existe | MEDIA |
| Foto de recibo | NO existe | MEDIA |
| Reportes/graficas mensuales | NO existe (solo summary numerico) | ALTA |
| Exportar datos (CSV/PDF) | NO existe | MEDIA |
| Categorias personalizables | NO -- enum fijo en codigo | MEDIA |
| Ingreso individual por persona (para splits proporcionales) | Solo existe `combinedMonthlyIncome` en Couple | ALTA |

---

## Seccion 2: Estructura de App Recomendada

### Nuevo Tab Layout (5 tabs, couple-first)

```
Tab 1: Inicio (Dashboard)        -- icono: house.fill
Tab 2: Transacciones             -- icono: arrow.left.arrow.right
Tab 3: [+] Agregar (FAB central) -- icono: plus.circle.fill
Tab 4: Gastos Fijos              -- icono: pin.fill
Tab 5: Ajustes                   -- icono: gearshape.fill
```

**Cambio clave:** Eliminar Pet y consolidar Insights dentro del Dashboard. Agregar tab de Gastos Fijos que es el core de la vida financiera en pareja (renta, servicios, seguros, suscripciones). El boton central "+" es el FAB elevado para agregar transaccion rapida.

### Contenido de cada pantalla

**Tab 1 -- Dashboard (Inicio)**
- Greeting personalizado: "Hola Rafael y Maria" con ambos avatares
- Card de Balance Neto entre la pareja: "Maria te debe $450" o "Estan al corriente" con boton "Liquidar"
- Resumen del mes: Ingresos / Gastos / Balance con progress ring
- Split visual: "Mis Gastos | En Pareja | De [Nombre Pareja]" (3 columnas, no 2)
- Mini chart: barras horizontales de gastos por categoria (top 5)
- Transacciones recientes (ultimas 5) con avatar de quien registro
- Metas de ahorro activas (progreso horizontal compacto, max 2)
- Alerta de presupuesto si alguno esta >80%
- NO incluir pet mini card (removido)

**Tab 2 -- Transacciones**
- Queda como esta pero agregar:
  - Filtro "Mios / Compartidos / De pareja" como segment control al top
  - Cada transaccion muestra mini avatar de quien la registro
  - Badge de split: "50/50", "70/30", "100% tuyo" en cada row
  - Resumen del mes arriba de la lista (ya existe, mantener)
  - Swipe left para editar, swipe right para marcar como liquidada

**Tab 3 -- Boton Central (+)**
- No es una pantalla, es un action sheet/modal con opciones:
  - "Gasto rapido" (abre AddTransaction con tipo expense preseleccionado)
  - "Ingreso" (abre AddTransaction con tipo income preseleccionado)
  - "Gasto fijo nuevo" (abre formulario de gasto recurrente)
  - "Abonar a meta" (abre selector de meta + monto)

**Tab 4 -- Gastos Fijos**
- Seccion detallada en Seccion 4 abajo

**Tab 5 -- Ajustes**
- Seccion detallada en Seccion 5 abajo

### Pantallas secundarias (accesibles desde tabs pero no en tab bar)

- **Presupuestos:** NavigationLink desde Dashboard o Settings
- **Metas de Ahorro:** NavigationLink desde Dashboard o Settings
- **Logros/Achievements:** NavigationLink desde Settings
- **Insights IA:** Boton en Dashboard que abre sheet
- **Reportes:** NavigationLink desde Settings
- **Perfil de Pareja:** NavigationLink desde Settings

---

## Seccion 3: Modelo de Expense Splitting

### Como deben funcionar los splits

**Principio fundamental:** Cada transaccion compartida debe tener un `split_type` y `split_ratio` que define como se divide el costo entre ambos.

### Modelo de datos necesario

Agregar al modelo `Transaction`:
```swift
var splitType: SplitType       // .equal, .proportional, .custom, .paidByOne
var splitRatio: Double         // 0.0 a 1.0 -- porcentaje que paga el usuario que registro
var settledAmount: Decimal     // cuanto se ha liquidado de esta transaccion
var isSettled: Bool             // si ya se liquido la deuda
```

Agregar al modelo `Profile`:
```swift
var monthlyIncome: Decimal     // YA EXISTE -- usarlo para calcular splits proporcionales
```

Agregar al modelo `Couple`:
```swift
var defaultSplitType: SplitType       // config default de la pareja
var defaultSplitRatio: Double         // ratio default
var settlementBalance: Decimal        // balance neto acumulado: positivo = pareja te debe, negativo = tu debes
```

### Tipos de split

```swift
enum SplitType: String, Codable, CaseIterable {
    case equal          // 50/50
    case proportional   // Proporcional al ingreso de cada uno
    case custom         // Porcentaje personalizado (ej: 70/30)
    case paidByOne      // 100% una persona (no se divide)
}
```

### Plantillas pre-configuradas

En onboarding o en Settings > Pareja, la pareja elige su modelo default:

| Plantilla | Descripcion | Ratio |
|-----------|-------------|-------|
| Mitad y mitad | Todo 50/50 | 0.50 |
| Proporcional al ingreso | Se calcula automaticamente basado en el ingreso de cada uno | Auto |
| Uno paga renta, otro servicios | Split personalizado por categoria | Varies |
| Personalizado | La pareja define el % | Custom |

**Ejemplo proporcional:** Si Rafael gana $30,000 y Maria gana $20,000, el ingreso total es $50,000. Rafael paga 60% (30k/50k) y Maria 40% (20k/50k) de cada gasto compartido.

### Tracking quien-debe-a-quien

**Settlement Balance Card** (en Dashboard, siempre visible cuando hay deuda):
- Calculo: Sumar todos los gastos compartidos del mes, aplicar el split, calcular la diferencia neta
- Mostrar: "Maria te debe $1,250" con boton "Enviar recordatorio" y boton "Marcar como liquidado"
- Cuando se liquida, se crea un registro de tipo `settlement` en transacciones
- Historial de liquidaciones visible en detalle

### Flujo de usuario al agregar transaccion compartida

1. Usuario marca toggle "Compartido"
2. Aparece selector de split: [50/50] [Proporcional] [Custom]
3. Si elige Custom, aparece slider de 0% a 100% con labels "Tu: 70% -- Pareja: 30%"
4. El default viene de la configuracion de pareja
5. Al guardar, se calcula automaticamente cuanto debe cada quien

---

## Seccion 4: Pantalla de Gastos Fijos

### Que debe mostrar

**Header:**
- Total mensual de gastos fijos: "$15,400/mes"
- Dividido en: "Tu parte: $8,200 | Parte de [Pareja]: $7,200"
- Barra de progreso: cuantos se han pagado este mes vs pendientes

**Lista de gastos fijos, agrupados por estado:**

**Seccion "Pendientes este mes"** (fondo ligeramente amarillo/naranja)
- Cada item: Emoji + Nombre + Monto + Fecha de vencimiento + Quien paga + Badge de split
- Ejemplo: "🏠 Renta -- $12,000 -- Vence 1 abril -- 60/40 -- [Boton: Marcar pagado]"
- Ordenados por fecha de vencimiento (proximo primero)
- Indicador visual de urgencia: rojo si vence hoy o ya vencio, amarillo si vence en 3 dias

**Seccion "Pagados este mes"** (fondo ligeramente verde)
- Mismos items pero con checkmark verde y opacidad reducida
- Quien lo pago y cuando

**Seccion "Todos los gastos fijos"** (vista completa)
- Lista completa de recurrentes activos
- Cada uno muestra: frecuencia, proximo pago, split asignado, categoria

### Campos de un gasto fijo

```swift
struct FixedExpense: Codable, Identifiable {
    let id: UUID
    let coupleId: UUID
    var name: String
    var emoji: String
    var category: TransactionCategory
    var amount: Decimal
    var frequency: RecurringFrequency      // mensual, quincenal, etc.
    var dueDay: Int                         // dia del mes en que vence (1-31)
    var splitType: SplitType
    var splitRatio: Double
    var assignedTo: UUID?                   // quien es responsable de pagarlo (o nil = ambos)
    var autoCreateTransaction: Bool         // crear transaccion automatica en la fecha
    var reminderDaysBefore: Int             // recordatorio X dias antes
    var isActive: Bool
    var lastPaidDate: Date?
    var notes: String?
}
```

### Gestion de recurrentes en pareja

- **Asignacion:** Cada gasto fijo puede asignarse a una persona o ser compartido
- **Recordatorios:** Push notification X dias antes del vencimiento al responsable
- **Auto-registro:** Opcion de crear la transaccion automaticamente el dia del vencimiento
- **Historial:** Ver los ultimos 6 meses de pagos de cada gasto fijo
- **Edicion facil:** Swipe para editar monto (ej: si sube la renta), pausar, o eliminar

### Categorias sugeridas de gastos fijos

- Renta/Hipoteca
- Agua
- Luz/Electricidad
- Gas
- Internet
- Telefono
- Seguros (auto, vida, gastos medicos)
- Streaming (Netflix, Spotify, etc.)
- Gimnasio
- Transporte (gasolina, metro, etc.)
- Creditos/Prestamos
- Mantenimiento del hogar

---

## Seccion 5: Recomendaciones de Settings

### Estructura completa de Settings

```
PERFIL
  - Foto de perfil (avatar)
  - Nombre de usuario
  - Email (solo lectura)
  - Ingreso mensual personal (importante para splits proporcionales)
  - Racha de dias registrando

PAREJA
  - Nombre de la pareja / alias (ej: "Los Garcia")
  - Ver perfil de pareja
  - Codigo de invitacion (para vincular)
  - Modelo de split default (50/50, proporcional, custom)
  - Ratio custom si aplica
  - Ingreso combinado (auto-calculado)
  - Desvincular pareja (con confirmacion seria)

FINANZAS
  - Presupuestos (NavigationLink a lista)
  - Metas de Ahorro (NavigationLink a lista)
  - Gastos Fijos (NavigationLink al tab, o duplicado aqui)
  - Logros (NavigationLink a lista)
  - Categorias personalizadas (agregar/editar/reordenar)

MONEDA Y FORMATO
  - Moneda principal (MXN, USD, EUR, COP, ARS, etc.)
  - Formato de fecha
  - Primer dia de la semana (lunes o domingo)
  - Dia de corte mensual (1-28, para que el "mes" empiece el dia de quincena si quieren)

NOTIFICACIONES
  - Toggle: Gasto de pareja registrado
  - Toggle: Presupuesto cerca del limite
  - Toggle: Recordatorio de gastos fijos
  - Toggle: Meta de ahorro alcanzada
  - Toggle: Resumen semanal
  - Toggle: Recordatorio diario de registrar gastos
  - Hora del recordatorio diario (time picker)

EXPORTAR DATOS
  - Exportar transacciones del mes (CSV)
  - Exportar reporte mensual (PDF)
  - Rango de fechas personalizado

APARIENCIA
  - Tema: Claro / Oscuro / Sistema
  - Icono de app alternativo (si premium)

SUSCRIPCION
  - Plan actual (Gratis / Premium)
  - Boton "Mejorar a Premium"
  - Restaurar compras
  - Beneficios de premium listados

SOPORTE
  - Centro de ayuda / FAQ
  - Contactar soporte (email)
  - Calificar en App Store
  - Compartir app con amigos

LEGAL
  - Terminos y condiciones
  - Politica de privacidad
  - Version de la app

CUENTA
  - Cerrar sesion
  - Eliminar cuenta (con flow de confirmacion serio: escribir "ELIMINAR" para confirmar)
```

---

## Seccion 6: Recomendaciones UI/UX

### Paleta de colores

```
PRIMARY (acciones, CTAs, exito):
  - #00C9A7 (verde turquesa) -- YA EN USO, mantener como primario
  - #00B4D8 (azul claro) -- acento secundario, gradientes

SEMANTIC:
  - #FF6B6B (rojo coral) -- gastos, errores, alertas criticas -- YA EN USO
  - #FFB84D (amarillo/naranja) -- warnings, presupuesto cerca del limite
  - #00C9A7 (verde) -- ingresos, exito, metas completadas

COUPLE IDENTITY:
  - #9B59B6 (morado) -- compartido/pareja -- YA EN USO, mantener
  - #E91E63 (rosa) -- acentos romanticos sutiles (corazones, vinculacion)

NEUTRALS:
  - #2D3436 -- texto principal
  - #636E72 -- texto secundario
  - #B2BEC3 -- texto deshabilitado
  - #F5F7FA -- fondo principal -- YA EN USO
  - #FFFFFF -- cards

DARK MODE:
  - Fondo: #1A1A2E
  - Cards: #16213E
  - Texto: #EAEAEA
```

### Tipografia

- **Numeros grandes (montos):** SF Pro Rounded, Bold -- da personalidad sin perder legibilidad
- **Headers:** SF Pro Display, Semibold
- **Body:** SF Pro Text, Regular
- **Montos en cards:** Design: .rounded para que se sientan amigables, no corporativos
- **Tamano minimo de texto:** 11pt para accesibilidad

### Uso de emojis

Los emojis ya se usan bien en categorias. Expandir:
- Cada gasto fijo tiene su emoji configurable
- Metas de ahorro tienen emoji (YA EXISTE)
- Reacciones rapidas a transacciones de la pareja: thumbsUp, heart, eyes, warning
- NO usar emojis en botones de accion ni en navigation titles -- mantener limpio

### Como hacer que se sienta premium y couple-oriented

1. **Greeting personalizado:** "Hola Rafael y Maria" con ambos avatares en mini circulo en el header del dashboard
2. **Duo color coding:** Tu color (verde turquesa) y color de pareja (morado) consistente en toda la app. Las transacciones tuyas tienen borde/acento verde, las de tu pareja morado, las compartidas degradado de ambos
3. **Micro-animaciones:**
   - Confetti sutil cuando liquidan deuda
   - Progress bar animado cuando abonan a meta
   - Haptic feedback en acciones principales (YA EXISTE en FAB)
   - Numero animado tipo "counter" cuando se actualiza el balance
4. **Cards con depth:** Sombras sutiles, bordes redondeados de 16pt, padding generoso -- YA SE HACE BIEN
5. **Gradientes sutiles:** Solo en CTAs principales (FAB, boton guardar), no en cards regulares
6. **Empty states con personalidad:** Ilustraciones simples, no solo iconos -- "Aun no hay gastos fijos. Agrega la renta para empezar a organizarse en pareja"

### Layout del Dashboard recomendado (top to bottom)

```
1. [Header] Saludo + Avatares de pareja + Mes actual
2. [Card HERO] Balance de pareja: "Maria te debe $1,250" [Liquidar]
3. [Card] Resumen del mes: Ingresos | Gastos | Balance + progress ring
4. [2 Cards lado a lado] Mis Gastos | Gastos en Pareja
5. [Card] Top 5 categorias (barras horizontales con emoji + monto)
6. [Card] Gastos fijos: X pagados de Y totales [Ver todos ->]
7. [Card] Metas de ahorro activas (max 2, barra de progreso) [Ver todas ->]
8. [Card] Alertas de presupuesto (si hay alguna >80%)
9. [Card] Transacciones recientes (ultimas 5)
10. [Spacer para FAB]
```

### Interacciones que deleitan

- **Pull to refresh** con animacion personalizada (ya hay .refreshable, customizar la animacion)
- **Long press en transaccion** para ver detalle rapido (peek)
- **Doble tap en balance de pareja** para enviar recordatorio a la pareja
- **Shake to undo** la ultima transaccion registrada
- **Swipe horizontal entre meses** en el dashboard para comparar
- **Celebracion visual** cuando:
  - La pareja liquida todas las deudas del mes
  - Se completa una meta de ahorro
  - Se mantiene el presupuesto bajo control todo el mes
  - Se alcanza racha de 7, 30, 100 dias

---

## Seccion 7: Metas de Ahorro

### Como hacer las metas compartidas engaging

**Problema actual:** Las metas son una lista con barra de progreso generica. No hay emocion, no hay sentido de progreso conjunto.

### Visual Progress mejorado

Reemplazar la ProgressView generica con:

**Barra de progreso dual:**
```
[===Rafael 60%===][==Maria 40%==][............restante............]
$6,000 de $10,000 ahorrados -- Faltan $4,000
```
- Color de Rafael (verde turquesa) para su contribucion
- Color de Maria (morado) para su contribucion
- Gris para lo restante
- Animacion de llenado cuando se abona

**Card de meta individual:**
```
+--------------------------------------------------+
|  Emoji grande     Nombre de la meta               |
|  ej: "Vacaciones en la playa"                     |
|                                                    |
|  [====verde====][==morado==][..........]           |
|  $6,000 / $10,000                    60%           |
|                                                    |
|  Tu: $3,600  |  Pareja: $2,400                    |
|                                                    |
|  Ritmo: $800/mes -- Llegas en: 5 meses            |
|  Meta: 15 dic 2026      [Abonar]                  |
+--------------------------------------------------+
```

### Milestones

Cada meta tiene milestones automaticos:
- **25%** -- "Buen comienzo" -- icono de semilla
- **50%** -- "A la mitad" -- icono de planta creciendo
- **75%** -- "Ya casi" -- icono de planta floreciendo
- **100%** -- "Meta cumplida" -- icono de arbol + confetti

Cada milestone se celebra con:
- Push notification a ambos: "Alcanzaron el 50% de 'Vacaciones'. Siguen asi."
- Badge/achievement que se desbloquea
- Animacion de confetti en la app cuando abren la meta

### Metas sugeridas (templates)

Al crear meta, ofrecer templates populares:
- Vacaciones -- emoji: playa/avion
- Fondo de emergencia -- emoji: escudo
- Boda -- emoji: anillos
- Auto nuevo -- emoji: auto
- Casa/Enganche -- emoji: casa
- Navidad/Regalos -- emoji: regalo
- Tecnologia -- emoji: laptop
- Personalizada -- emoji: a elegir

### Campos mejorados del modelo

Agregar al modelo `SavingsGoal`:
```swift
var contributionByUser: [UUID: Decimal]    // cuanto ha aportado cada quien
var monthlyTarget: Decimal?                 // meta mensual de ahorro
var autoDeductFromIncome: Bool              // deducir automaticamente del ingreso
var milestoneReached: Int                   // 0, 25, 50, 75, 100
var celebrationSeen: Bool                   // si ya vieron la celebracion
```

### Gamificacion de metas

- **Racha de ahorro:** Si la pareja abona a metas por 4 semanas seguidas, desbloquean achievement
- **Tabla de contribucion:** Mostrar quien ha aportado mas (sin que sea competencia toxica, presentar como "equipo")
- **Proyeccion:** "A este ritmo, alcanzan la meta en X meses" calculado en base al promedio de abonos recientes
- **Recordatorio amable:** Push semanal: "Esta semana no han abonado a 'Vacaciones'. Quieren abonar $500?"

---

## Resumen de Prioridades para Implementacion

### Sprint 1 (Critico -- hacer primero)
1. Agregar `splitType` y `splitRatio` al modelo de Transaction
2. UI de split en AddTransactionView
3. Balance quien-debe-a-quien en Dashboard
4. Pantalla de Gastos Fijos (nuevo tab)
5. Reestructurar tabs (eliminar Pet, agregar Gastos Fijos + boton central)

### Sprint 2 (Alto)
1. Settings completo con todas las secciones
2. Split proporcional al ingreso (requiere ingreso individual en Profile)
3. Settlement/liquidacion flow
4. Notificaciones de gasto de pareja
5. Mejoras visuales al Dashboard (nuevo layout)

### Sprint 3 (Medio)
1. Metas de ahorro mejoradas (contribucion dual, milestones)
2. Reportes mensuales con graficas
3. Exportar datos CSV
4. Categorias personalizables
5. Dark mode

### Sprint 4 (Nice to have)
1. Reacciones en transacciones
2. Foto de recibo
3. Insights IA mejorados con datos de splits
4. Achievements actualizados para el nuevo modelo
5. Animaciones y celebraciones
