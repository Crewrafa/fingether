# Fingether Redesign v2 — Couple-First

> ⚠️ **OUTDATED — el codigo actual NO implementa este layout.**
>
> Este doc proponia un tab bar diferente (`Nosotros, Gastos, Fijos, Metas, Más`) con un Split Model hibrido y un Dashboard con un mockup ASCII especifico. La app de produccion adopto el modelo de split (`SplitType` en `Models/Transaction.swift`) y la idea couple-first general, pero **no implementa este tab bar ni este Dashboard**.
>
> Estado real:
> - Tabs reales: ver `Spendly/Spendly/App/MainTabView.swift`.
> - Couple settings UI viven en `MasView.swift` (sección "Más"), no en una sección "Pareja" dedicada.
> - El bloque ASCII del Dashboard es **inspiracional**, no fiel.
>
> Tratar como **referencia historica**.

---


## Nuevo Tab Bar
1. 💕 **Nosotros** — Dashboard de pareja (quién gastó qué, balance, quién debe)
2. 💸 **Gastos** — Todas las transacciones con splits visibles
3. 📌 **Fijos** — Gastos recurrentes con splits asignados
4. 🎯 **Metas** — Metas de ahorro compartidas
5. ⚙️ **Más** — Settings completos, logros, insights, perfil

## Split Model (Híbrido)
- **Default global**: la pareja elige un split (50/50, proporcional, custom %)
- **Override por categoría**: "la renta siempre la pago yo"
- **Override por transacción**: flexibilidad máxima

### SplitType enum:
- `.equal` — 50/50
- `.proportional` — proporcional al ingreso (calculado automático)
- `.custom(percentage: Int)` — % personalizado (ej: 70/30)
- `.onePays(userId: UUID)` — uno paga todo

## Dashboard "Nosotros"
```
┌─────────────────────────────┐
│ 💕 Rafael & Mariana         │
│ Abril 2026                  │
├─────────────────────────────┤
│    Balance de Pareja        │
│      $28,500 💚             │
│  Ingresos    Gastos         │
│  $51,500    -$23,000        │
├──────────────┬──────────────┤
│ 🧑 Rafael    │ 👩 Mariana   │
│ $8,200       │ $3,500       │
│ individual   │ individual   │
├──────────────┴──────────────┤
│ 💜 Compartido: $11,300      │
│ ┌ Renta      $8,500  50/50 ┐│
│ │ Super      $870    50/50 ││
│ └ Netflix    $299    yo    ┘│
├─────────────────────────────┤
│ 💰 Quién debe a quién      │
│ Rafael debe $1,200 a Mariana│
│        [Saldar cuentas]     │
├─────────────────────────────┤
│ 🎯 Meta: Cancún 60% ████░░ │
├─────────────────────────────┤
│ Últimos 2 gastos            │
│ 🍔 Tacos $85 — Rafael      │
│ 🍣 Sushi $245 — Mariana 💕 │
└─────────────────────────────┘
```

## Pantalla Fijos
- Lista de gastos recurrentes
- Cada uno con: emoji, nombre, monto, frecuencia, quién paga/split
- Total mensual
- Botón agregar nuevo gasto fijo

## Settings Completos
- Perfil (nombre, avatar, ingreso)
- Pareja (código, partner, ingreso combinado)
- Split default (50/50, proporcional, custom)
- Presupuestos por categoría
- Notificaciones
- Moneda y formato
- Exportar datos
- Tema (claro/oscuro)
- Sobre la app
- Cerrar sesión

## Paleta de Colores
- Primary: #00C9A7 (teal/menta)
- Couple/shared: #9B59B6 (morado)
- Expense: #FF6B6B (coral)
- Income: #00C9A7 (teal)
- Fixed: #E17055 (naranja terracota)
- Goals: #FDCB6E (amarillo cálido)
- Background: #F5F7FA
- Cards: white with subtle shadows
- Emojis everywhere — no boring icons
