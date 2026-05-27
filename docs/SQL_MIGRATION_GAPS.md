# Fingether — SQL Migration Gaps

> Estado: **Auditoría v1.1 (Abril 2026)** — el código Swift y los modelos asumen tablas y columnas que el esquema actual de Supabase **no contiene**. Este documento es una lista canónica de lo que falta para poder activar la app contra Supabase real (sin `MockDataService.shared.isEnabled = true`).
>
> **No crear estas migraciones aquí.** Son trabajo planificado, no inmediato. Cada feature mock-only romperá si Supabase real se conecta sin estas tablas/columnas.

## Resumen

| Categoría | Item | Tipo |
|---|---|---|
| Tabla | `debts` | NUEVA |
| Tabla | `trips` | NUEVA |
| Tabla | `trip_expenses` | NUEVA |
| Tabla | `trip_budget_categories` | NUEVA |
| Tabla | `financial_challenges` | NUEVA |
| Tabla | `simulations` | NUEVA |
| Tabla | `financial_score_history` | NUEVA |
| Tabla | `day_financial_summaries` | NUEVA (o vista materializada) |
| Tabla | `tutorial_progress` | NUEVA |
| Tabla | `couple_settings` | NUEVA (hoy `CoupleSettings` es un struct local mock) |
| Tabla | `fixed_expense_payments` | NUEVA (para persistir el checklist mensual de pagados) |
| Columnas | `profiles.*` | 14 columnas nuevas |
| Columnas | `couples.*` | 6 columnas nuevas |
| Columnas | `transactions.*` | 5 columnas nuevas |
| Columnas | `savings_goals.*` | 1 columna nueva (`is_shared`) |
| Funciones | varias | RPC nuevas para los flujos couple |

---

## Tablas faltantes

### `debts`
Modela "quien le debe a quien" entre la pareja. Hoy vive en `MockDataService.mockDebts`.

```sql
CREATE TABLE debts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    couple_id UUID NOT NULL REFERENCES couples(id) ON DELETE CASCADE,
    from_user_id UUID NOT NULL REFERENCES profiles(id),  -- quien debe
    to_user_id UUID NOT NULL REFERENCES profiles(id),    -- quien es acreedor
    concept TEXT NOT NULL,
    amount DECIMAL(12,2) NOT NULL CHECK (amount > 0),
    is_paid BOOLEAN NOT NULL DEFAULT FALSE,
    paid_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

RLS: cualquiera de los dos partners puede leer/escribir.

Modelo Swift: `Spendly/Models/Debt.swift`. Service mock: `MockDataService.addMockDebt/markDebtAsPaid/getNetBalance`. Usado por `DashboardView.whoOwesWhoCard` y `DebtDetailView`.

### `trips`, `trip_expenses`, `trip_budget_categories`
Sistema de viajes con presupuesto por categoría y aporte mensual recurrente. Modelos: `Spendly/Models/Trip.swift`, `TripExpense.swift`. Service mock: `MockDataService.mockTrips`, `mockTripExpenses`, `addMockTripExpense` (que actualiza el `spentAmount` de la categoría).

```sql
CREATE TABLE trips (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    couple_id UUID NOT NULL REFERENCES couples(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    emoji TEXT NOT NULL DEFAULT '✈️',
    destination TEXT NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    total_budget DECIMAL(12,2) NOT NULL,
    currency TEXT NOT NULL DEFAULT 'MXN',
    status TEXT NOT NULL CHECK (status IN ('planning','active','completed')),
    is_shared BOOLEAN NOT NULL DEFAULT TRUE,
    savings_mode TEXT NOT NULL CHECK (savings_mode IN ('monthly','freeForm','alreadyHave')),
    monthly_savings_amount DECIMAL(12,2) NOT NULL DEFAULT 0,
    current_saved DECIMAL(12,2) NOT NULL DEFAULT 0,
    linked_transaction_id UUID REFERENCES transactions(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE trip_budget_categories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    trip_id UUID NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    emoji TEXT NOT NULL,
    budget_amount DECIMAL(12,2) NOT NULL,
    spent_amount DECIMAL(12,2) NOT NULL DEFAULT 0
);

CREATE TABLE trip_expenses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    trip_id UUID NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id),
    amount DECIMAL(12,2) NOT NULL,
    currency TEXT NOT NULL,
    category_id UUID NOT NULL REFERENCES trip_budget_categories(id) ON DELETE CASCADE,
    merchant TEXT NOT NULL,
    notes TEXT,
    date TIMESTAMPTZ NOT NULL,
    split_type TEXT,
    split_user1_amount DECIMAL(12,2),
    split_user2_amount DECIMAL(12,2),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

Trigger sugerido: `AFTER INSERT/UPDATE/DELETE ON trip_expenses` recalcula `trip_budget_categories.spent_amount`.

### `financial_challenges`
Retos gamificados (semana sin delivery, sprint de ahorro, etc.). Modelo: `Spendly/Models/FinancialChallenge.swift`. Service mock: `MockDataService.mockChallenges`.

```sql
CREATE TABLE financial_challenges (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    couple_id UUID NOT NULL REFERENCES couples(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT NOT NULL,
    type TEXT NOT NULL,         -- no_spend, savings_sprint, budget_streak, category_limit, income_boost
    metric TEXT NOT NULL,       -- amount, count, days, percentage
    target_value DECIMAL(12,2) NOT NULL,
    current_value DECIMAL(12,2) NOT NULL DEFAULT 0,
    difficulty TEXT NOT NULL,   -- easy, medium, hard, extreme
    status TEXT NOT NULL,       -- active, completed, failed, cancelled
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    category transaction_category,
    xp_reward INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

### `simulations`
Escenarios "what-if" del Simulador financiero. Modelo: `Spendly/Models/Simulation.swift`. Service mock: `MockDataService.mockSimulations`.

```sql
CREATE TABLE simulations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    couple_id UUID NOT NULL REFERENCES couples(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    type TEXT NOT NULL,         -- debt_payoff, savings_projection, expense_reduction, income_increase, emergency_fund
    params JSONB NOT NULL,      -- monthly_amount, target_amount, interest_rate, months, category
    result JSONB,               -- projected_total, monthly_breakdown[], savings_gain, time_to_goal_months, summary
    risk_level TEXT NOT NULL,   -- low, medium, high
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

### `financial_score_history`
Historico del Fingether Score. Modelo: `Spendly/Models/FinancialScore.swift`. Service mock: `MockDataService.mockScoreHistory` (30-day random walk).

```sql
CREATE TABLE financial_score_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    couple_id UUID NOT NULL REFERENCES couples(id) ON DELETE CASCADE,
    score INTEGER NOT NULL CHECK (score BETWEEN 0 AND 100),
    breakdown JSONB NOT NULL,   -- ScoreBreakdown
    trend TEXT NOT NULL,        -- up, stable, down
    tips TEXT[] NOT NULL DEFAULT '{}',
    calculated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

Sugerencia: agregar una RPC `recompute_financial_score(couple_id)` que reproduzca la lógica de `MockDataService.calculateFinancialScore`.

### `day_financial_summaries`
Vista (no tabla) para el calendario heatmap. Modelo: `Spendly/Models/DayFinancialSummary.swift`.

Recomendación: implementarla como **vista** o como función SQL `get_day_summaries(couple_id, month, user_id?)` que matchea la firma actual de `MockDataService.getDayFinancialSummaries`.

### `tutorial_progress`
Estado del tutorial interactivo. Hoy `tutorialInfoStepsViewed` vive en `AppPreferences` (UserDefaults local). Para sincronizar entre dispositivos hace falta persistencia server-side.

```sql
CREATE TABLE tutorial_progress (
    user_id UUID PRIMARY KEY REFERENCES profiles(id) ON DELETE CASCADE,
    info_steps_viewed INTEGER[] NOT NULL DEFAULT '{}',
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

### `couple_settings`
`CoupleSettings` (defaultSplitType + per-category overrides) hoy es un struct local de mock. Para producción:

```sql
CREATE TABLE couple_settings (
    couple_id UUID PRIMARY KEY REFERENCES couples(id) ON DELETE CASCADE,
    default_split_type TEXT NOT NULL,         -- equal, proportional, custom_<pct>, one_pays_<uuid>
    category_splits JSONB NOT NULL DEFAULT '{}',
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

### `fixed_expense_payments`
Persistencia del checklist "pagado este mes" de gastos fijos. Bug fix #5 movió esto a `MockDataService.paidFixedKeys` (Set local). Para producción:

```sql
CREATE TABLE fixed_expense_payments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    couple_id UUID NOT NULL REFERENCES couples(id) ON DELETE CASCADE,
    transaction_id UUID NOT NULL REFERENCES transactions(id) ON DELETE CASCADE,
    year INTEGER NOT NULL,
    month INTEGER NOT NULL CHECK (month BETWEEN 1 AND 12),
    paid_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    paid_by_user_id UUID REFERENCES profiles(id),
    UNIQUE(transaction_id, year, month)
);
```

---

## Columnas faltantes

### `profiles`
Los modelos Swift (`Models/Profile.swift`) y el `ProfileEditSheet` esperan estos campos. Ninguno existe en `001_initial_schema.sql`.

```sql
ALTER TABLE profiles
    ADD COLUMN date_of_birth DATE,
    ADD COLUMN gender TEXT,
    ADD COLUMN city TEXT,
    ADD COLUMN country TEXT,
    ADD COLUMN relationship_status TEXT,        -- soltero, en_relacion, casado, otro
    ADD COLUMN relationship_start_date DATE,
    ADD COLUMN occupation TEXT,
    ADD COLUMN employment_type TEXT,
    ADD COLUMN industry TEXT,
    ADD COLUMN housing_type TEXT,
    ADD COLUMN has_children INTEGER,
    ADD COLUMN has_credit_cards BOOLEAN,
    ADD COLUMN credit_card_count INTEGER,
    ADD COLUMN has_savings BOOLEAN,
    ADD COLUMN financial_goal TEXT,
    ADD COLUMN live_together BOOLEAN,
    ADD COLUMN relationship_length TEXT;
```

### `couples`
```sql
ALTER TABLE couples
    ADD COLUMN invite_expiration TIMESTAMPTZ,
    ADD COLUMN user_1_name TEXT NOT NULL DEFAULT '',
    ADD COLUMN user_2_name TEXT,
    ADD COLUMN user_1_income DECIMAL(12,2) NOT NULL DEFAULT 0,
    ADD COLUMN user_2_income DECIMAL(12,2),
    ADD COLUMN couple_monthly_budget DECIMAL(12,2);
```

Nota: `user_1_name` y `user_1_income` son redundantes con `profiles.display_name` y `profiles.monthly_income`. Mantener ambos para evitar joins en el path crítico, pero mantener consistencia con triggers.

### `transactions`
```sql
ALTER TABLE transactions
    ADD COLUMN is_shared BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN split_type TEXT,                       -- equal, proportional, custom_<pct>, one_pays_<uuid>
    ADD COLUMN split_user1_amount DECIMAL(12,2),
    ADD COLUMN split_user2_amount DECIMAL(12,2),
    ADD COLUMN debt_total_amount DECIMAL(12,2);       -- usado por las deudas registradas en onboarding
```

### `savings_goals`
```sql
ALTER TABLE savings_goals
    ADD COLUMN is_shared BOOLEAN NOT NULL DEFAULT TRUE;
```

---

## RPC nuevas necesarias

| RPC | Para que |
|---|---|
| `calculate_who_owes_whom(couple_id)` | Reemplaza el cálculo en mock. |
| `recompute_financial_score(couple_id)` | Persiste a `financial_score_history`. |
| `get_day_summaries(couple_id, month, user_id)` | Backend del calendario heatmap. |
| `seed_couple_settings(couple_id)` | Default 50/50 al crear couple. |
| `mark_fixed_expense_paid(transaction_id, year, month)` | Toggle del checklist. |

---

## Plan de implementación sugerido

1. **Fase A — Couples + Splits.** Columnas en `couples` y `transactions`. Sin esto el modo pareja no funciona contra Supabase real.
2. **Fase B — Profile fields.** Columnas en `profiles` para que `ProfileEditSheet` persista.
3. **Fase C — Debts + CoupleSettings.** Tablas `debts` y `couple_settings`. Habilita el balance "quien debe a quien" real.
4. **Fase D — Fixed expense payments.** Tabla y RPC del checklist mensual.
5. **Fase E — Trips, Challenges, Simulations.** Tablas + RPC. Features avanzadas.
6. **Fase F — Score history + day summaries.** Tablas finales para el dashboard de Score y el calendario.
7. **Fase G — Tutorial progress.** Sync entre dispositivos.

Cada fase debería incluir:
- Migración SQL numerada (`003_couples_splits.sql`, `004_profile_fields.sql`, etc.).
- Policies RLS específicas.
- Service Swift correspondiente (eliminando el branch `if MockDataService.shared.isEnabled { ... return mock }`).
- Tests de integración que verifiquen el flujo end-to-end con un proyecto Supabase de staging.

---

## Estado actual del Mock vs Real

| Feature | Mock | Real |
|---|---|---|
| Auth (signUp/signIn/signOut) | ✅ | ✅ |
| Profile CRUD básico (display_name, income, currency, onboarding_completed) | ✅ | ✅ |
| Couple linking (create/join via RPC) | ✅ | ✅ |
| Transaction CRUD | ✅ | ✅ (sin `is_shared`/`split_*`) |
| Budget CRUD + alerts | ✅ | ✅ |
| Savings Goals + contribute | ✅ | ✅ (sin `is_shared`) |
| Pet state + XP + evolution | ✅ | ✅ |
| Achievements (incl. couple) | ✅ | ✅ |
| Insights AI (Edge Function + Claude) | ✅ | ✅ |
| Dashboard "quien debe a quien" | ✅ | ❌ (requiere `debts` + columnas split) |
| Fixed expenses checklist (paid) | ✅ | ❌ (requiere `fixed_expense_payments`) |
| Profile fields extendidos | ✅ | ❌ |
| Trips + savings recurrentes | ✅ | ❌ |
| Challenges | ✅ | ❌ |
| Simulator (financiero + crédito) | ✅ | ❌ |
| Fingether Score + history | ✅ | ❌ |
| Calendar heatmap | ✅ | ❌ |
| Tutorial progress sync | ✅ (UserDefaults) | ❌ |
| Subscriptions persistence | ✅ (post v1.1) | ❌ |
| Couple settings (split default) | ✅ | ❌ |

---

**Owner:** TBD
**Última actualización:** v1.1 — Auditoría Final
