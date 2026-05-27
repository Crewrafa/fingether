<div align="center">

# Fingether

**App iOS nativa de finanzas en pareja con mascota Tamagotchi que refleja la salud financiera.**

Proyecto solo del autor — diseño, arquitectura, backend, frontend, IA, monetización.

![Swift](https://img.shields.io/badge/Swift-5.9+-F05138?logo=swift&logoColor=white)
![iOS](https://img.shields.io/badge/iOS-17+-000000?logo=apple&logoColor=white)
![SwiftUI](https://img.shields.io/badge/SwiftUI-Observable-007AFF)
![Supabase](https://img.shields.io/badge/Supabase-Postgres%20%2B%20Edge-3ECF8E?logo=supabase&logoColor=white)
![Claude AI](https://img.shields.io/badge/Claude_API-Insights-D97757)
![License](https://img.shields.io/badge/License-Proprietary-red)

</div>

---

> **Aviso de licencia.** Este repositorio es **público para evaluación**, no de código abierto.
> No se permite clonar, reutilizar ni derivar trabajo. Lee [`LICENSE`](./LICENSE).
> ¿Te interesa colaborar o licenciar? → **psicologorafaelbaez@gmail.com**

---

## Screenshots

<!--
Cuando tengas las capturas, agrégalas en docs/screenshots/ y reemplaza
los placeholders de abajo. Sugerencia: PNG a 1290×2796 (iPhone 15 Pro Max).
-->

<div align="center">

| Onboarding | Dashboard | Mascota |
| :---: | :---: | :---: |
| _pendiente_ | _pendiente_ | _pendiente_ |

| Insights IA | Presupuestos | Paywall |
| :---: | :---: | :---: |
| _pendiente_ | _pendiente_ | _pendiente_ |

</div>

---

## El producto

Llevar las cuentas en pareja suele ser una discusión disfrazada de hoja de cálculo. **Fingether** convierte ese seguimiento en una mecánica de juego compartida: cada decisión financiera —un gasto, un ahorro, cumplir el presupuesto— alimenta o lastima a una **mascota Tamagotchi** que ambos cuidan.

No es otra "app de gastos". Es **psicología financiera de pareja** envuelta en producto:

- **Visibilidad mutua sin fricción** — ambos miembros ven los movimientos en tiempo real (Supabase Realtime), pero con RLS estricta para que nadie fuera de la pareja vea nada.
- **Refuerzo positivo, no culpa** — la paleta evita rojos agresivos; los gastos no son "malos", solo decisiones. El feedback emocional viene de la mascota.
- **Insights con IA, no dashboards muertos** — Claude analiza el contexto real de la pareja (ingresos, hábitos, presupuestos) y genera recomendaciones accionables, no gráficos de pastel.
- **Voz como input principal** — `"Café 45"` y listo. Apple Speech Framework parsea categoría, monto y comercio.
- **Diseñado para LATAM** — COP por defecto, localización en español, presupuestos pensados para ingresos quincenales y gastos fijos típicos de la región.

---

## Lo que demuestra este proyecto

Esto no es un tutorial de SwiftUI ni un fork. Es un sistema **end-to-end** construido por una sola persona:

| Capa | Trabajo | Métricas |
| --- | --- | --- |
| **iOS / SwiftUI** | App nativa completa con MVVM estricto, `@Observable`, navegación por tabs, 21 módulos funcionales | ~28,400 líneas de Swift · 106 archivos · 18 modelos · 17 ViewModels · 15 services |
| **Backend / Supabase** | Schema relacional con RLS multi-tenant por pareja, triggers, funciones SQL, Realtime sync | 11 tablas · **35 RLS policies** · 9 triggers · funciones SQL para streaks, presupuestos y estado de mascota |
| **IA / Edge Functions** | Edge Function en Deno/TypeScript que llama a Claude API con prompt engineering específico para finanzas de pareja, cache de insights, rate-limit por tier | 674 líneas de TS · prompt versionado · respuestas estructuradas JSON |
| **Voz** | Parser semántico de gastos hablados en español — extrae monto, categoría y comercio del texto libre | Apple Speech + parser custom (`VoiceExpenseParser.swift`) |
| **Monetización** | Free tier real (50 transacciones/mes, 3 presupuestos, 2 metas, 5 insights), paywall, integración StoreKit 2 con suscripciones mensual y anual | `SubscriptionService` + paywall integrado en flujos |
| **Diseño** | Sistema de colores con psicología aplicada (sin rojos para gastos), tokens semánticos, onboarding rediseñado, gradientes y estados focales custom | `L10n`, `AppPreferences`, tokens `fingether*` en todo el código |
| **Producto** | PRD propio, documento master con 21 pasos de construcción, decisiones de scope, naming, branding y migración Spendly → Fingether | `PM_REVIEW.md`, `docs/REDESIGN_SPEC.md` |

> **Rol único.** No hay "equipo de backend" ni "el diseñador". Cada decisión —desde el nombre del archivo SQL hasta la psicología del color— es del autor.

---

## Arquitectura

```
┌───────────────────────────────────────────────────────────────────┐
│  iOS App (SwiftUI · iOS 17+ · @Observable)                        │
│  Views ─→ ViewModels ─→ Services ─→ SupabaseManager               │
│  Voice (Apple Speech) ─→ VoiceExpenseParser ─→ TransactionService │
│  Keychain (tokens) · StoreKit 2 (suscripciones) · Lottie (mascota)│
└───────────────────────────────────────────────────────────────────┘
                            │  HTTPS · Realtime · JWT
                            ▼
┌───────────────────────────────────────────────────────────────────┐
│  Supabase                                                          │
│  • Auth (email/password + magic links)                             │
│  • Postgres con RLS por couple_id (35 policies)                    │
│  • Realtime (sync entre pareja)                                    │
│  • Storage (avatares)                                              │
│  • Edge Function: generate-insights (Deno + TypeScript)            │
│      └─→ Claude API (server-side, key nunca toca el cliente)       │
└───────────────────────────────────────────────────────────────────┘
```

### MVVM estricto

```
Views/          Solo UI. Cero lógica de negocio.
ViewModels/     @Observable. Orquestan estado y llaman Services.
Services/       Stateless. Toda I/O y reglas de negocio.
Models/         Structs Codable puros.
Utils/          Keychain, L10n, AppPreferences, extensions.
```

Esta separación se respeta sin excepción en los 106 archivos. Las `Views/` no importan `SupabaseManager`; los `Services/` no conocen SwiftUI.

---

## Lo difícil del producto, y cómo lo resolví

### 1. **Multi-tenant por pareja con RLS**

Cada fila (transacción, presupuesto, meta, estado de mascota) pertenece a un `couple_id`. Las **35 RLS policies** garantizan que un usuario solo vea datos de su pareja, sin un solo `WHERE user_id = ...` en la app. La seguridad vive en Postgres, no en el cliente.

### 2. **API key de Claude jamás en el cliente**

La integración con la IA pasa por una **Edge Function** (`supabase/functions/generate-insights`). El cliente iOS solo manda un POST autenticado; la key vive como secret de Supabase. Esto es no-negociable: tirar el binario nunca expone la key.

### 3. **Mascota como espejo financiero, no decoración**

`PetService` calcula `health` y `mood` en tiempo real a partir de:
- Cumplimiento de presupuestos (peso 40%)
- Streak de registros diarios (peso 30%)
- Progreso en metas de ahorro (peso 30%)

Y evoluciona por XP acumulado (`egg → baby → teen → adult → legendary`). No es Tamagotchi de adorno: si tiras el presupuesto, la mascota se pone triste, y eso duele más que una notificación pasiva.

### 4. **Free tier que sí limita, sin ser hostil**

```swift
enum FreeTierLimits {
    static let monthlyTransactions = 50
    static let activeBudgets = 3
    static let activeSavingsGoals = 2
    static let monthlyInsights = 5
}
```

Los límites se validan **server-side** en triggers/funciones SQL, no solo en el cliente. Imposible bypassear con un build modificado.

### 5. **Voz que entiende español coloquial**

`VoiceExpenseParser` toma `"gasté 320 pesos en el super"` y produce `Transaction(amount: 320, category: .food, ...)`. Maneja decimales hablados, monedas, sinónimos de categorías ("comida", "super", "abarrotes" → `.food`).

### 6. **Migración de marca en vivo**

El producto se llamaba Spendly y se renombró a Fingether con el producto ya construido. Hice la migración sin romper bundle IDs en TestFlight, manteniendo el path de la carpeta legacy y migrando solo identificadores externos y strings de UI. La carpeta sigue llamándose `Spendly/` a propósito.

---

## Stack

| Capa | Tecnología | Por qué |
| --- | --- | --- |
| UI | **SwiftUI** (iOS 17+) | `@Observable` macro, navegación moderna, sin UIKit |
| Estado | `@Observable` class | Más limpio que `ObservableObject`, sin `@Published` ruido |
| Backend | **Supabase** | Postgres real + Auth + Realtime + Edge Functions en un paquete |
| IA | **Claude API** | Calidad superior para razonamiento financiero contextual |
| Edge | **Deno + TypeScript** | Runtime de Supabase; tipado fuerte para el contrato con Claude |
| Pagos | **StoreKit 2** | API moderna, async/await nativo, no librerías third-party |
| Voz | **Apple Speech Framework** | On-device cuando es posible, sin enviar audio a servidores |
| Animación | **Lottie** | Mascota expresiva sin spritesheets |
| Seguridad | **Keychain** (tokens), **RLS** (DB), **xcconfig** (claves no en repo) | Defensa en profundidad |
| Build | **Xcode** + `project.yml` (XcodeGen) | Project file regenerable, sin merges horrendos |

---

## Estructura

```
Spendly/
├── App/
│   ├── SpendlyApp.swift          # Entry point + DI raíz
│   ├── MainTabView.swift         # Navegación principal
│   └── Config.xcconfig           # Vars de entorno (placeholders en repo)
├── Models/                       # 18 structs Codable
├── Views/                        # 21 módulos: Dashboard, Pet, Insights, Trips...
├── ViewModels/                   # 17 @Observable classes
├── Services/                     # 15 services: Auth, Pet, Budget, Insights, Voice...
├── Utils/                        # Keychain, L10n, AppPreferences
└── Resources/                    # Assets, Lottie JSON, Localizable.strings

supabase/
├── migrations/
│   ├── 001_initial_schema.sql    # 11 tablas + 35 RLS policies
│   └── 002_functions.sql         # Triggers, funciones SQL, streaks
└── functions/
    └── generate-insights/        # Edge Function — Claude API

docs/
├── REDESIGN_SPEC.md              # Spec de rediseño v1.6
└── SQL_MIGRATION_GAPS.md         # Gaps detectados en migrations

PM_REVIEW.md                      # Notas de producto / scope / decisiones
```

---

## Build local (referencia, no para reuso)

> Recordatorio: el código no es reutilizable bajo ningún uso. Esta sección existe para que un evaluador pueda compilar y probar localmente si lo acuerda con el autor.

```bash
# 1. Generar el .xcodeproj (usamos XcodeGen)
brew install xcodegen
xcodegen generate

# 2. Configurar credenciales de Supabase
cp Spendly/App/Config.example.xcconfig Spendly/App/Config.xcconfig
# Editar Config.xcconfig con SUPABASE_URL y SUPABASE_ANON_KEY reales

# 3. Aplicar migraciones SQL en tu proyecto Supabase
# Correr en orden: supabase/migrations/001_*.sql, luego 002_*.sql

# 4. Desplegar Edge Function (requiere supabase CLI)
supabase functions deploy generate-insights
supabase secrets set ANTHROPIC_API_KEY=tu_key_de_claude

# 5. Abrir y compilar en Xcode 15+
open Spendly.xcodeproj
```

---

## Estado y roadmap

| Hito | Estado |
| --- | --- |
| Schema SQL + RLS multi-tenant | ✅ |
| Auth + couple linking | ✅ |
| CRUD transacciones + filtros | ✅ |
| Dashboard + presupuestos | ✅ |
| Mascota: modelo + lógica de salud | ✅ |
| Mascota: UI + animaciones Lottie | ✅ |
| Edge Function de insights IA | ✅ |
| Voz (Apple Speech + parser) | ✅ |
| Metas de ahorro + achievements | ✅ |
| Onboarding rediseñado (v1.6) | ✅ |
| Suscripciones StoreKit 2 | ✅ |
| Notificaciones push | 🚧 |
| Submission App Store | 🚧 |

---

## Sobre el autor

**Rafael Báez** — diseño, producto, ingeniería, IA, monetización. Este repositorio es la prueba.

- 📧 **psicologorafaelbaez@gmail.com**
- 🐙 [github.com/Crewrafa](https://github.com/Crewrafa)

¿Buscas a alguien que pueda llevar un producto **de PRD a TestFlight** él solo? Hablemos.

---

<div align="center">

**¿Te gustó lo que viste? Da una ⭐ en el repo — sirve para mí, no te cuesta nada.**

</div>
