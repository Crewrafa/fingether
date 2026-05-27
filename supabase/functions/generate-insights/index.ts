// =============================================================
// Fingether — Edge Function: generate-insights
// Generates AI-powered financial insights for couples using Claude
// =============================================================

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";

// -------------------------------------------------------------
// CORS headers for Supabase client requests
// -------------------------------------------------------------

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// -------------------------------------------------------------
// Types
// -------------------------------------------------------------

interface InsightRequest {
  couple_id: string;
  insight_type: "weekly" | "monthly" | "custom";
  user_question?: string;
  /** "couple" or "solo" — controls whether the prompt addresses both partners or one. */
  mode?: "couple" | "solo";
}

interface Transaction {
  id: string;
  type: string;
  category: string;
  amount: number;
  description: string;
  date: string;
  user_id: string;
}

interface Budget {
  category: string;
  amount_limit: number;
  current_spent: number;
  period: string;
}

interface SavingsGoal {
  name: string;
  target_amount: number;
  current_amount: number;
  target_date: string | null;
  status: string;
}

interface PetState {
  name: string;
  health: number;
  mood: string;
  evolution: string;
  experience_points: number;
}

interface FinancialData {
  transactions: Transaction[];
  budgets: Budget[];
  savings_goals: SavingsGoal[];
  pet: PetState | null;
  couple_income: number;
  currency: string;
  partner_names: string[];
}

// -------------------------------------------------------------
// Constants
// -------------------------------------------------------------

const FREE_TIER_DAILY_LIMIT = 10;
const CLAUDE_MODEL = "claude-sonnet-4-20250514";
const CLAUDE_MAX_TOKENS = 1024;
const CACHE_TTL_HOURS_WEEKLY = 24;
const CACHE_TTL_HOURS_MONTHLY = 48;
const CACHE_TTL_HOURS_CUSTOM = 12;

// -------------------------------------------------------------
// System prompt for Claude — financial advisor in Spanish
// -------------------------------------------------------------

const SYSTEM_PROMPT = `Eres el asesor financiero de Fingether, una app de finanzas para parejas. Das insights claros, directos y accionables sobre las finanzas de esta pareja. Tu tono es profesional, motivador y empático. Siempre hablas en espanol.

Reglas estrictas:
- Responde SIEMPRE en espanol.
- Se conciso: maximo 3-4 parrafos cortos.
- Usa datos concretos del resumen financiero que se te proporciona.
- Da consejos accionables y especificos, no genericos.
- Menciona a los miembros de la pareja por nombre cuando sea posible.
- Si la mascota esta triste o en estado critico, menciona como mejorar su animo a traves de buenas decisiones financieras.
- Nunca inventes datos que no esten en el contexto proporcionado.
- Usa emojis con moderacion para hacer el texto mas amigable (1-2 por parrafo maximo).
- Formatea montos con el simbolo de la moneda proporcionada.
- Si hay presupuestos excedidos, senalalos con urgencia pero sin alarmar.
- Celebra los logros y el progreso en metas de ahorro.
- Nunca des consejo de inversiones especificas ni recomendaciones de productos financieros.`;

// -------------------------------------------------------------
// Helper: Build user prompt based on insight type
// -------------------------------------------------------------

function buildUserPrompt(
  insightType: string,
  data: FinancialData,
  userQuestion?: string,
  mode?: "couple" | "solo"
): string {
  const { transactions, budgets, savings_goals, pet, couple_income, currency, partner_names } = data;
  const isCouple = mode === "couple" || (mode === undefined && partner_names.length >= 2);
  const subjectLabel = isCouple
    ? `${partner_names.join(" y ")}`
    : (partner_names[0] ?? "el usuario");
  const verbPlural = isCouple ? "gastaron" : "gastaste";

  // Calculate totals for the period
  const totalIncome = transactions
    .filter((t) => t.type === "income")
    .reduce((sum, t) => sum + t.amount, 0);
  const totalExpenses = transactions
    .filter((t) => t.type === "expense")
    .reduce((sum, t) => sum + t.amount, 0);

  // Category breakdown
  const categoryTotals: Record<string, number> = {};
  transactions
    .filter((t) => t.type === "expense")
    .forEach((t) => {
      categoryTotals[t.category] = (categoryTotals[t.category] || 0) + t.amount;
    });

  const sortedCategories = Object.entries(categoryTotals)
    .sort(([, a], [, b]) => b - a)
    .map(([cat, amount]) => `  - ${cat}: ${currency} ${amount.toFixed(2)}`)
    .join("\n");

  // Budget status
  const budgetStatus = budgets
    .map((b) => {
      const pct = b.amount_limit > 0
        ? ((b.current_spent / b.amount_limit) * 100).toFixed(1)
        : "0";
      const status = parseFloat(pct) >= 100 ? "EXCEDIDO" : parseFloat(pct) >= 80 ? "ALERTA" : "OK";
      return `  - ${b.category} (${b.period}): ${currency} ${b.current_spent.toFixed(2)} / ${currency} ${b.amount_limit.toFixed(2)} (${pct}%) [${status}]`;
    })
    .join("\n");

  // Savings goals
  const savingsStatus = savings_goals
    .map((g) => {
      const pct = g.target_amount > 0
        ? ((g.current_amount / g.target_amount) * 100).toFixed(1)
        : "0";
      const dateStr = g.target_date ? ` | Meta: ${g.target_date}` : "";
      return `  - ${g.name}: ${currency} ${g.current_amount.toFixed(2)} / ${currency} ${g.target_amount.toFixed(2)} (${pct}%)${dateStr}`;
    })
    .join("\n");

  // Pet info
  const petInfo = pet
    ? `Mascota "${pet.name}": salud ${pet.health}/100, animo ${pet.mood}, evolucion ${pet.evolution}, XP ${pet.experience_points}`
    : "Sin mascota registrada";

  const context = `
DATOS FINANCIEROS ${isCouple ? "DE LA PAREJA" : "DEL USUARIO"}:
Modo: ${isCouple ? "PAREJA — habla en plural y dirigete a ambos por nombre" : "INDIVIDUAL — habla en singular, dirigete solo al usuario"}
Sujeto: ${subjectLabel}
${isCouple ? `Miembros: ${partner_names.join(" y ")}` : `Usuario: ${partner_names[0] ?? "el usuario"}`}
Ingreso mensual ${isCouple ? "combinado" : ""}: ${currency} ${couple_income.toFixed(2)}
Moneda: ${currency}

RESUMEN DEL PERIODO:
- Ingresos: ${currency} ${totalIncome.toFixed(2)}
- Gastos: ${currency} ${totalExpenses.toFixed(2)}
- Balance: ${currency} ${(totalIncome - totalExpenses).toFixed(2)}
- Total de transacciones: ${transactions.length}

DESGLOSE POR CATEGORIA (gastos):
${sortedCategories || "  Sin gastos registrados"}

PRESUPUESTOS:
${budgetStatus || "  Sin presupuestos configurados"}

METAS DE AHORRO:
${savingsStatus || "  Sin metas de ahorro"}

MASCOTA:
${petInfo}
`.trim();

  const subjectPossessive = isCouple ? "de la pareja" : `de ${subjectLabel}`;
  const subjectPronoun = isCouple ? "les" : "le";
  const subjectVerb = isCouple ? "respetaron" : "respetaste";
  const subjectGoals = isCouple ? "sus" : "tus";

  switch (insightType) {
    case "weekly":
      return `${context}\n\nGenera un resumen semanal de las finanzas ${subjectPossessive}. Incluye: que tal ${subjectPronoun} fue esta semana, donde ${verbPlural} mas, si ${subjectVerb} ${subjectGoals} presupuestos, como van ${subjectGoals} metas de ahorro, y 2-3 consejos concretos para la proxima semana. Menciona el estado de la mascota. ${isCouple ? "Dirigete a ambos por nombre cuando sea natural." : "Habla en singular, dirigete solo al usuario."}`;
    case "monthly":
      return `${context}\n\nGenera un analisis mensual detallado de las finanzas ${subjectPossessive}. Incluye: tendencias de gasto vs ingreso, categorias donde mas ${verbPlural}, comparativa con ${subjectGoals} ingreso mensual, progreso en metas de ahorro, estado de presupuestos, y un plan de accion con 3-4 recomendaciones especificas para el proximo mes. Menciona como ${subjectGoals} comportamiento financiero afecto a la mascota. ${isCouple ? "Dirigete a ambos por nombre y usa plural." : "Habla en singular, dirigete solo al usuario."}`;
    case "custom":
      return `${context}\n\n${isCouple ? "La pareja pregunta" : "El usuario pregunta"}: "${userQuestion || "Dame un consejo financiero personalizado."}"\n\nResponde la pregunta usando los datos financieros proporcionados. Se especifico y usa numeros reales. ${isCouple ? "Dirigete a ambos." : "Habla en singular."}`;
    default:
      return `${context}\n\nDa un resumen general de las finanzas ${subjectPossessive} con consejos practicos.`;
  }
}

// -------------------------------------------------------------
// Helper: Get date range for insight type
// -------------------------------------------------------------

function getDateRange(insightType: string): { from: string; to: string } {
  const now = new Date();
  const to = now.toISOString().split("T")[0];

  if (insightType === "weekly") {
    const from = new Date(now);
    from.setDate(from.getDate() - 7);
    return { from: from.toISOString().split("T")[0], to };
  }

  // monthly or custom — last 30 days
  const from = new Date(now);
  from.setDate(from.getDate() - 30);
  return { from: from.toISOString().split("T")[0], to };
}

// -------------------------------------------------------------
// Helper: Get cache TTL for insight type
// -------------------------------------------------------------

function getCacheTTLHours(insightType: string): number {
  switch (insightType) {
    case "weekly":
      return CACHE_TTL_HOURS_WEEKLY;
    case "monthly":
      return CACHE_TTL_HOURS_MONTHLY;
    case "custom":
      return CACHE_TTL_HOURS_CUSTOM;
    default:
      return CACHE_TTL_HOURS_CUSTOM;
  }
}

// -------------------------------------------------------------
// Main handler
// -------------------------------------------------------------

Deno.serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  // Only allow POST
  if (req.method !== "POST") {
    return new Response(
      JSON.stringify({ error: "Metodo no permitido" }),
      { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }

  try {
    // -------------------------------------------------------
    // 1. Validate environment variables
    // -------------------------------------------------------

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const anthropicApiKey = Deno.env.get("ANTHROPIC_API_KEY");

    if (!supabaseUrl || !supabaseServiceRoleKey || !anthropicApiKey) {
      console.error("Missing required environment variables");
      return new Response(
        JSON.stringify({ error: "Error de configuracion del servidor" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // -------------------------------------------------------
    // 2. Authenticate user via JWT
    // -------------------------------------------------------

    const authHeader = req.headers.get("Authorization");
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      return new Response(
        JSON.stringify({ error: "Token de autenticacion requerido" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const jwt = authHeader.replace("Bearer ", "");

    // Client with user JWT for auth verification
    const supabaseAuth = createClient(supabaseUrl, supabaseServiceRoleKey, {
      global: { headers: { Authorization: `Bearer ${jwt}` } },
      auth: { persistSession: false },
    });

    const { data: { user }, error: authError } = await supabaseAuth.auth.getUser(jwt);

    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: "Token invalido o expirado" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Service role client for unrestricted DB access
    const supabase = createClient(supabaseUrl, supabaseServiceRoleKey, {
      auth: { persistSession: false },
    });

    // -------------------------------------------------------
    // 3. Parse and validate request body
    // -------------------------------------------------------

    let body: InsightRequest;
    try {
      body = await req.json();
    } catch {
      return new Response(
        JSON.stringify({ error: "Cuerpo de la solicitud invalido" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const { couple_id, insight_type, user_question, mode } = body;

    if (!couple_id || !insight_type) {
      return new Response(
        JSON.stringify({ error: "couple_id e insight_type son requeridos" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const validTypes = ["weekly", "monthly", "custom"];
    if (!validTypes.includes(insight_type)) {
      return new Response(
        JSON.stringify({
          error: `insight_type invalido. Valores permitidos: ${validTypes.join(", ")}`,
        }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (insight_type === "custom" && (!user_question || user_question.trim().length === 0)) {
      return new Response(
        JSON.stringify({ error: "user_question es requerido para insight_type 'custom'" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Sanitize user question if present
    const sanitizedQuestion = user_question
      ? user_question.trim().slice(0, 500)
      : undefined;

    // Validate mode if provided
    const sanitizedMode: "couple" | "solo" | undefined =
      mode === "couple" || mode === "solo" ? mode : undefined;

    // -------------------------------------------------------
    // 4. Verify user belongs to the couple
    // -------------------------------------------------------

    const { data: profile, error: profileError } = await supabase
      .from("profiles")
      .select("couple_id, subscription_tier, display_name, currency")
      .eq("id", user.id)
      .single();

    if (profileError || !profile) {
      return new Response(
        JSON.stringify({ error: "Perfil de usuario no encontrado" }),
        { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (profile.couple_id !== couple_id) {
      return new Response(
        JSON.stringify({ error: "No tienes acceso a esta pareja" }),
        { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // -------------------------------------------------------
    // 5. Rate limiting (free tier: 10 per day per couple)
    // -------------------------------------------------------

    const isPremium = profile.subscription_tier === "premium";

    if (!isPremium) {
      const todayStart = new Date();
      todayStart.setHours(0, 0, 0, 0);

      const { count, error: countError } = await supabase
        .from("insights_cache")
        .select("id", { count: "exact", head: true })
        .eq("couple_id", couple_id)
        .gte("generated_at", todayStart.toISOString());

      if (countError) {
        console.error("Rate limit check error:", countError.message);
        return new Response(
          JSON.stringify({ error: "Error al verificar limite de uso" }),
          { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      if ((count ?? 0) >= FREE_TIER_DAILY_LIMIT) {
        return new Response(
          JSON.stringify({
            error: "Limite diario alcanzado",
            message: `Has alcanzado el limite de ${FREE_TIER_DAILY_LIMIT} insights por dia en el plan gratuito. Actualiza a Premium para insights ilimitados.`,
            limit_reached: true,
          }),
          { status: 429, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
    }

    // -------------------------------------------------------
    // 6. Check cache for non-custom insights
    // -------------------------------------------------------

    if (insight_type !== "custom") {
      const { data: cached } = await supabase
        .from("insights_cache")
        .select("content, generated_at, metadata")
        .eq("couple_id", couple_id)
        .eq("insight_type", insight_type)
        .gt("expires_at", new Date().toISOString())
        .order("generated_at", { ascending: false })
        .limit(1)
        .maybeSingle();

      // Only reuse cache when the requested mode matches the cached one (or both unset)
      if (cached) {
        const cachedMode = (cached.metadata as Record<string, unknown> | null)?.mode as string | undefined;
        const modesMatch =
          (sanitizedMode === undefined && cachedMode === undefined) ||
          cachedMode === sanitizedMode;

        if (modesMatch) {
          return new Response(
            JSON.stringify({
              insight: cached.content,
              insight_type,
              generated_at: cached.generated_at,
              from_cache: true,
              metadata: cached.metadata,
            }),
            { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
          );
        }
      }
    }

    // -------------------------------------------------------
    // 7. Fetch financial data
    // -------------------------------------------------------

    const dateRange = getDateRange(insight_type);

    // Run all queries in parallel
    const [
      transactionsResult,
      budgetsResult,
      savingsResult,
      petResult,
      coupleResult,
      partnerNamesResult,
    ] = await Promise.all([
      // Transactions for the period
      supabase
        .from("transactions")
        .select("id, type, category, amount, description, date, user_id")
        .eq("couple_id", couple_id)
        .gte("date", dateRange.from)
        .lte("date", dateRange.to)
        .order("date", { ascending: false })
        .limit(500),

      // Active budgets
      supabase
        .from("budgets")
        .select("category, amount_limit, current_spent, period")
        .eq("couple_id", couple_id)
        .eq("is_active", true),

      // Active savings goals
      supabase
        .from("savings_goals")
        .select("name, target_amount, current_amount, target_date, status")
        .eq("couple_id", couple_id)
        .eq("status", "active"),

      // Pet state
      supabase
        .from("pet_state")
        .select("name, health, mood, evolution, experience_points")
        .eq("couple_id", couple_id)
        .maybeSingle(),

      // Couple combined income
      supabase
        .from("couples")
        .select("combined_monthly_income")
        .eq("id", couple_id)
        .single(),

      // Partner names
      supabase
        .from("profiles")
        .select("display_name")
        .eq("couple_id", couple_id),
    ]);

    if (transactionsResult.error) {
      console.error("Error fetching transactions:", transactionsResult.error.message);
      return new Response(
        JSON.stringify({ error: "Error al obtener transacciones" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const financialData: FinancialData = {
      transactions: (transactionsResult.data ?? []) as Transaction[],
      budgets: (budgetsResult.data ?? []) as Budget[],
      savings_goals: (savingsResult.data ?? []) as SavingsGoal[],
      pet: (petResult.data as PetState | null) ?? null,
      couple_income: coupleResult.data?.combined_monthly_income ?? 0,
      currency: profile.currency ?? "MXN",
      partner_names: (partnerNamesResult.data ?? []).map(
        (p: { display_name: string }) => p.display_name
      ),
    };

    // -------------------------------------------------------
    // 8. Call Claude API
    // -------------------------------------------------------

    const userPrompt = buildUserPrompt(insight_type, financialData, sanitizedQuestion, sanitizedMode);

    const claudeResponse = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-api-key": anthropicApiKey,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify({
        model: CLAUDE_MODEL,
        max_tokens: CLAUDE_MAX_TOKENS,
        system: SYSTEM_PROMPT,
        messages: [
          {
            role: "user",
            content: userPrompt,
          },
        ],
      }),
    });

    if (!claudeResponse.ok) {
      const errorBody = await claudeResponse.text();
      console.error(`Claude API error (${claudeResponse.status}):`, errorBody);
      return new Response(
        JSON.stringify({ error: "Error al generar el insight. Intenta de nuevo mas tarde." }),
        { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const claudeData = await claudeResponse.json();

    const insightContent =
      claudeData.content?.[0]?.type === "text"
        ? claudeData.content[0].text
        : null;

    if (!insightContent) {
      console.error("Unexpected Claude response structure:", JSON.stringify(claudeData));
      return new Response(
        JSON.stringify({ error: "Respuesta inesperada del servicio de IA" }),
        { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // -------------------------------------------------------
    // 9. Cache the insight
    // -------------------------------------------------------

    const ttlHours = getCacheTTLHours(insight_type);
    const expiresAt = new Date();
    expiresAt.setHours(expiresAt.getHours() + ttlHours);

    const metadata: Record<string, unknown> = {
      insight_type,
      model: CLAUDE_MODEL,
      date_range: dateRange,
      transaction_count: financialData.transactions.length,
      requested_by: user.id,
    };

    if (sanitizedQuestion) {
      metadata.user_question = sanitizedQuestion;
    }

    if (sanitizedMode) {
      metadata.mode = sanitizedMode;
    }

    const { error: cacheError } = await supabase
      .from("insights_cache")
      .insert({
        couple_id,
        insight_type,
        content: insightContent,
        metadata,
        generated_at: new Date().toISOString(),
        expires_at: expiresAt.toISOString(),
      });

    if (cacheError) {
      // Log but don't fail — the insight was already generated
      console.error("Cache insert error:", cacheError.message);
    }

    // -------------------------------------------------------
    // 10. Clean up expired cache entries (async, non-blocking)
    // -------------------------------------------------------

    supabase
      .from("insights_cache")
      .delete()
      .lt("expires_at", new Date().toISOString())
      .then(({ error }) => {
        if (error) console.error("Cache cleanup error:", error.message);
      });

    // -------------------------------------------------------
    // 11. Return the insight
    // -------------------------------------------------------

    return new Response(
      JSON.stringify({
        insight: insightContent,
        insight_type,
        generated_at: new Date().toISOString(),
        from_cache: false,
        metadata: {
          date_range: dateRange,
          transaction_count: financialData.transactions.length,
        },
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err) {
    console.error("Unhandled error in generate-insights:", err);
    return new Response(
      JSON.stringify({
        error: "Error interno del servidor. Intenta de nuevo mas tarde.",
      }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
