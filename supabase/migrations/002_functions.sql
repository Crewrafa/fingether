-- ============================================================
-- Fingether — Functions + Triggers
-- Migration 002: All SQL functions and triggers
-- ============================================================

-- ============================================================
-- FUNCTION: Handle new user signup
-- Creates a profile automatically when a user signs up
-- ============================================================

CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO profiles (id, email, display_name)
    VALUES (
        NEW.id,
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'display_name', SPLIT_PART(NEW.email, '@', 1))
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- ============================================================
-- FUNCTION: Update updated_at timestamp
-- ============================================================

CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply updated_at trigger to all relevant tables
CREATE TRIGGER set_updated_at BEFORE UPDATE ON profiles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER set_updated_at BEFORE UPDATE ON couples
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER set_updated_at BEFORE UPDATE ON transactions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER set_updated_at BEFORE UPDATE ON budgets
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER set_updated_at BEFORE UPDATE ON savings_goals
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER set_updated_at BEFORE UPDATE ON pet_state
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER set_updated_at BEFORE UPDATE ON subscriptions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================================
-- FUNCTION: Join couple with invite code
-- ============================================================

CREATE OR REPLACE FUNCTION join_couple(p_invite_code TEXT)
RETURNS UUID AS $$
DECLARE
    v_couple_id UUID;
    v_user_id UUID := auth.uid();
BEGIN
    -- Find couple by invite code
    SELECT id INTO v_couple_id
    FROM couples
    WHERE invite_code = UPPER(p_invite_code)
    AND partner_2_id IS NULL
    AND partner_1_id != v_user_id;

    IF v_couple_id IS NULL THEN
        RAISE EXCEPTION 'Invalid or expired invite code';
    END IF;

    -- Update couple with partner 2
    UPDATE couples
    SET partner_2_id = v_user_id,
        updated_at = NOW()
    WHERE id = v_couple_id;

    -- Update both profiles with couple_id
    UPDATE profiles
    SET couple_id = v_couple_id
    WHERE id = v_user_id;

    -- Create pet for the couple
    INSERT INTO pet_state (couple_id, name)
    VALUES (v_couple_id, 'Buddy')
    ON CONFLICT (couple_id) DO NOTHING;

    -- Seed default achievements for the couple
    PERFORM seed_achievements(v_couple_id);

    RETURN v_couple_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- FUNCTION: Create couple (partner 1 initiates)
-- ============================================================

CREATE OR REPLACE FUNCTION create_couple()
RETURNS TABLE(couple_id UUID, invite_code TEXT) AS $$
DECLARE
    v_couple_id UUID;
    v_invite_code TEXT;
    v_user_id UUID := auth.uid();
BEGIN
    -- Check if user already has a couple
    IF EXISTS (SELECT 1 FROM profiles WHERE id = v_user_id AND couple_id IS NOT NULL) THEN
        RAISE EXCEPTION 'User already belongs to a couple';
    END IF;

    -- Create couple
    INSERT INTO couples (partner_1_id)
    VALUES (v_user_id)
    RETURNING couples.id, couples.invite_code INTO v_couple_id, v_invite_code;

    -- Update profile
    UPDATE profiles
    SET couple_id = v_couple_id
    WHERE id = v_user_id;

    RETURN QUERY SELECT v_couple_id, v_invite_code;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- FUNCTION: Update budget spent amount on transaction change
-- ============================================================

CREATE OR REPLACE FUNCTION update_budget_on_transaction()
RETURNS TRIGGER AS $$
DECLARE
    v_couple_id UUID;
    v_month_start DATE;
    v_month_end DATE;
BEGIN
    -- Get the relevant record (NEW for INSERT/UPDATE, OLD for DELETE)
    IF TG_OP = 'DELETE' THEN
        v_couple_id := OLD.couple_id;
    ELSE
        v_couple_id := NEW.couple_id;
    END IF;

    -- Only process expenses with a couple
    IF v_couple_id IS NULL THEN
        RETURN COALESCE(NEW, OLD);
    END IF;

    -- Calculate current month boundaries
    v_month_start := DATE_TRUNC('month', CURRENT_DATE)::DATE;
    v_month_end := (DATE_TRUNC('month', CURRENT_DATE) + INTERVAL '1 month' - INTERVAL '1 day')::DATE;

    -- Recalculate spent for all active budgets of this couple
    UPDATE budgets b
    SET current_spent = COALESCE((
        SELECT SUM(t.amount)
        FROM transactions t
        WHERE t.couple_id = v_couple_id
        AND t.category = b.category
        AND t.type = 'expense'
        AND t.date BETWEEN v_month_start AND v_month_end
    ), 0)
    WHERE b.couple_id = v_couple_id
    AND b.is_active = TRUE;

    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_transaction_change
    AFTER INSERT OR UPDATE OR DELETE ON transactions
    FOR EACH ROW EXECUTE FUNCTION update_budget_on_transaction();

-- ============================================================
-- FUNCTION: Update pet health based on financial behavior
-- health = (budget_adherence * 0.4) + (savings_progress * 0.3) + (streak_bonus * 0.3)
-- ============================================================

CREATE OR REPLACE FUNCTION calculate_pet_health(p_couple_id UUID)
RETURNS INTEGER AS $$
DECLARE
    v_budget_adherence DECIMAL;
    v_savings_progress DECIMAL;
    v_streak_bonus DECIMAL;
    v_health INTEGER;
    v_avg_budget_ratio DECIMAL;
    v_avg_savings_ratio DECIMAL;
    v_max_streak INTEGER;
BEGIN
    -- Budget adherence: average of (1 - spent/limit) across active budgets, capped 0-1
    SELECT COALESCE(AVG(
        GREATEST(0, LEAST(1, 1.0 - (current_spent / NULLIF(amount_limit, 0))))
    ), 0.5)
    INTO v_avg_budget_ratio
    FROM budgets
    WHERE couple_id = p_couple_id AND is_active = TRUE;

    v_budget_adherence := v_avg_budget_ratio * 100;

    -- Savings progress: average of (current/target) across active goals
    SELECT COALESCE(AVG(
        LEAST(1, current_amount / NULLIF(target_amount, 0))
    ), 0)
    INTO v_avg_savings_ratio
    FROM savings_goals
    WHERE couple_id = p_couple_id AND status = 'active';

    v_savings_progress := v_avg_savings_ratio * 100;

    -- Streak bonus: based on max streak of couple members
    SELECT COALESCE(MAX(streak_days), 0)
    INTO v_max_streak
    FROM profiles
    WHERE couple_id = p_couple_id;

    v_streak_bonus := LEAST(100, v_max_streak * 5); -- 5 points per streak day, max 100

    -- Final health calculation
    v_health := ROUND(
        (v_budget_adherence * 0.4) +
        (v_savings_progress * 0.3) +
        (v_streak_bonus * 0.3)
    )::INTEGER;

    -- Clamp between 0 and 100
    v_health := GREATEST(0, LEAST(100, v_health));

    RETURN v_health;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- FUNCTION: Update pet mood based on health
-- ============================================================

CREATE OR REPLACE FUNCTION get_pet_mood(p_health INTEGER)
RETURNS pet_mood AS $$
BEGIN
    IF p_health >= 80 THEN RETURN 'ecstatic';
    ELSIF p_health >= 60 THEN RETURN 'happy';
    ELSIF p_health >= 40 THEN RETURN 'neutral';
    ELSIF p_health >= 20 THEN RETURN 'sad';
    ELSE RETURN 'critical';
    END IF;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ============================================================
-- FUNCTION: Get pet evolution based on XP
-- ============================================================

CREATE OR REPLACE FUNCTION get_pet_evolution(p_xp INTEGER)
RETURNS pet_evolution AS $$
BEGIN
    IF p_xp >= 10000 THEN RETURN 'legendary';
    ELSIF p_xp >= 5000 THEN RETURN 'adult';
    ELSIF p_xp >= 2000 THEN RETURN 'teen';
    ELSIF p_xp >= 500 THEN RETURN 'baby';
    ELSE RETURN 'egg';
    END IF;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ============================================================
-- FUNCTION: Refresh pet state (called periodically or on events)
-- ============================================================

CREATE OR REPLACE FUNCTION refresh_pet_state(p_couple_id UUID)
RETURNS VOID AS $$
DECLARE
    v_health INTEGER;
    v_mood pet_mood;
    v_xp INTEGER;
    v_evolution pet_evolution;
BEGIN
    -- Calculate new health
    v_health := calculate_pet_health(p_couple_id);

    -- Get current XP
    SELECT experience_points INTO v_xp
    FROM pet_state
    WHERE couple_id = p_couple_id;

    IF v_xp IS NULL THEN
        RETURN;
    END IF;

    -- Determine mood and evolution
    v_mood := get_pet_mood(v_health);
    v_evolution := get_pet_evolution(v_xp);

    -- Update pet state
    UPDATE pet_state
    SET health = v_health,
        mood = v_mood,
        evolution = v_evolution,
        last_health_update = NOW()
    WHERE couple_id = p_couple_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- FUNCTION: Award XP to pet
-- ============================================================

CREATE OR REPLACE FUNCTION award_pet_xp(p_couple_id UUID, p_xp INTEGER)
RETURNS VOID AS $$
BEGIN
    UPDATE pet_state
    SET experience_points = experience_points + p_xp,
        evolution = get_pet_evolution(experience_points + p_xp)
    WHERE couple_id = p_couple_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- FUNCTION: Update streak on transaction
-- ============================================================

CREATE OR REPLACE FUNCTION update_user_streak()
RETURNS TRIGGER AS $$
DECLARE
    v_last_date DATE;
    v_current_streak INTEGER;
BEGIN
    SELECT last_transaction_date, streak_days
    INTO v_last_date, v_current_streak
    FROM profiles
    WHERE id = NEW.user_id;

    IF v_last_date IS NULL OR v_last_date < CURRENT_DATE - INTERVAL '1 day' THEN
        -- Reset streak if more than 1 day gap
        v_current_streak := 1;
    ELSIF v_last_date = CURRENT_DATE - INTERVAL '1 day' THEN
        -- Consecutive day
        v_current_streak := v_current_streak + 1;
    END IF;
    -- Same day = no change

    UPDATE profiles
    SET streak_days = v_current_streak,
        last_transaction_date = CURRENT_DATE
    WHERE id = NEW.user_id;

    -- Award XP for streak milestones
    IF NEW.couple_id IS NOT NULL AND v_current_streak > 0 AND v_current_streak % 7 = 0 THEN
        PERFORM award_pet_xp(NEW.couple_id, 50);
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_transaction_streak
    AFTER INSERT ON transactions
    FOR EACH ROW EXECUTE FUNCTION update_user_streak();

-- ============================================================
-- FUNCTION: Seed default achievements for a couple
-- ============================================================

CREATE OR REPLACE FUNCTION seed_achievements(p_couple_id UUID)
RETURNS VOID AS $$
BEGIN
    INSERT INTO achievements (couple_id, key, title, description, category, icon, target, reward_accessory) VALUES
        (p_couple_id, 'first_transaction', 'Primer Paso', 'Registra tu primera transaccion', 'milestone', '🎉', 1, NULL),
        (p_couple_id, 'week_streak', 'Semana Perfecta', '7 dias consecutivos registrando gastos', 'streak', '🔥', 7, 'hat_fire'),
        (p_couple_id, 'month_streak', 'Mes Imparable', '30 dias consecutivos registrando gastos', 'streak', '⭐', 30, 'cape_gold'),
        (p_couple_id, 'budget_master', 'Maestro del Presupuesto', 'No exceder ningun presupuesto por un mes', 'budget', '🎯', 1, 'glasses_smart'),
        (p_couple_id, 'first_saving', 'Primer Ahorro', 'Crea tu primera meta de ahorro', 'savings', '🐷', 1, NULL),
        (p_couple_id, 'saving_25', 'Cuarto del Camino', 'Alcanza el 25% de una meta de ahorro', 'savings', '📈', 1, 'scarf_green'),
        (p_couple_id, 'saving_50', 'Mitad del Camino', 'Alcanza el 50% de una meta de ahorro', 'savings', '🚀', 1, 'bow_tie'),
        (p_couple_id, 'saving_complete', 'Meta Cumplida', 'Completa una meta de ahorro', 'savings', '🏆', 1, 'crown_gold'),
        (p_couple_id, 'couple_joined', 'Mejor Juntos', 'Tu pareja se unio a Fingether', 'social', '💕', 1, 'heart_necklace'),
        (p_couple_id, 'transactions_50', 'Medio Centenar', 'Registra 50 transacciones', 'milestone', '📊', 50, 'backpack_adventure'),
        (p_couple_id, 'transactions_100', 'Centenario', 'Registra 100 transacciones', 'milestone', '💎', 100, 'wings_angel'),
        (p_couple_id, 'pet_teen', 'Creciendo Juntos', 'Tu mascota evoluciono a adolescente', 'pet', '🌱', 1, NULL),
        (p_couple_id, 'pet_adult', 'Madurez Financiera', 'Tu mascota evoluciono a adulto', 'pet', '🌳', 1, 'monocle_fancy'),
        (p_couple_id, 'pet_legendary', 'Leyenda Financiera', 'Tu mascota alcanzo el nivel legendario', 'pet', '👑', 1, 'aura_legendary'),
        (p_couple_id, 'budget_3_months', 'Disciplina Total', 'Mantente dentro del presupuesto 3 meses seguidos', 'budget', '🏅', 3, 'shield_platinum'),
        -- Couple achievements
        (p_couple_id, 'first_shared_expense', 'Primer gasto compartido', 'Registren su primer gasto en pareja', 'social', '💑', 1, 'matching_caps'),
        (p_couple_id, 'couple_budget_master', 'Maestros del presupuesto en pareja', 'Mantengan todos los presupuestos compartidos en verde por 1 mes', 'social', '🥇', 1, 'medal_couple'),
        (p_couple_id, 'couple_trip_planned', 'Viaje juntos planeado', 'Crean su primer viaje compartido en Fingether', 'social', '✈️', 1, 'travel_pack'),
        (p_couple_id, 'five_couple_challenges', 'Equipo invencible', 'Completen 5 retos financieros juntos', 'social', '🏆', 5, 'trophy_couple')
    ON CONFLICT (couple_id, key) DO NOTHING;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- FUNCTION: Check and unlock achievements
-- ============================================================

CREATE OR REPLACE FUNCTION check_achievements(p_couple_id UUID)
RETURNS TABLE(newly_unlocked TEXT[]) AS $$
DECLARE
    v_unlocked TEXT[] := '{}';
    v_transaction_count INTEGER;
    v_streak INTEGER;
    v_pet pet_state%ROWTYPE;
BEGIN
    -- Count couple transactions
    SELECT COUNT(*) INTO v_transaction_count
    FROM transactions WHERE couple_id = p_couple_id;

    -- Get max streak
    SELECT COALESCE(MAX(streak_days), 0) INTO v_streak
    FROM profiles WHERE couple_id = p_couple_id;

    -- Get pet state
    SELECT * INTO v_pet FROM pet_state WHERE couple_id = p_couple_id;

    -- First transaction
    IF v_transaction_count >= 1 THEN
        UPDATE achievements SET progress = 1, unlocked_at = COALESCE(unlocked_at, NOW())
        WHERE couple_id = p_couple_id AND key = 'first_transaction' AND unlocked_at IS NULL;
        IF FOUND THEN v_unlocked := array_append(v_unlocked, 'first_transaction'); END IF;
    END IF;

    -- Week streak
    IF v_streak >= 7 THEN
        UPDATE achievements SET progress = v_streak, unlocked_at = COALESCE(unlocked_at, NOW())
        WHERE couple_id = p_couple_id AND key = 'week_streak' AND unlocked_at IS NULL;
        IF FOUND THEN v_unlocked := array_append(v_unlocked, 'week_streak'); END IF;
    END IF;

    -- Month streak
    IF v_streak >= 30 THEN
        UPDATE achievements SET progress = v_streak, unlocked_at = COALESCE(unlocked_at, NOW())
        WHERE couple_id = p_couple_id AND key = 'month_streak' AND unlocked_at IS NULL;
        IF FOUND THEN v_unlocked := array_append(v_unlocked, 'month_streak'); END IF;
    END IF;

    -- Transaction milestones
    IF v_transaction_count >= 50 THEN
        UPDATE achievements SET progress = v_transaction_count, unlocked_at = COALESCE(unlocked_at, NOW())
        WHERE couple_id = p_couple_id AND key = 'transactions_50' AND unlocked_at IS NULL;
        IF FOUND THEN v_unlocked := array_append(v_unlocked, 'transactions_50'); END IF;
    END IF;

    IF v_transaction_count >= 100 THEN
        UPDATE achievements SET progress = v_transaction_count, unlocked_at = COALESCE(unlocked_at, NOW())
        WHERE couple_id = p_couple_id AND key = 'transactions_100' AND unlocked_at IS NULL;
        IF FOUND THEN v_unlocked := array_append(v_unlocked, 'transactions_100'); END IF;
    END IF;

    -- Pet evolution achievements
    IF v_pet.evolution IN ('teen', 'adult', 'legendary') THEN
        UPDATE achievements SET progress = 1, unlocked_at = COALESCE(unlocked_at, NOW())
        WHERE couple_id = p_couple_id AND key = 'pet_teen' AND unlocked_at IS NULL;
        IF FOUND THEN v_unlocked := array_append(v_unlocked, 'pet_teen'); END IF;
    END IF;

    IF v_pet.evolution IN ('adult', 'legendary') THEN
        UPDATE achievements SET progress = 1, unlocked_at = COALESCE(unlocked_at, NOW())
        WHERE couple_id = p_couple_id AND key = 'pet_adult' AND unlocked_at IS NULL;
        IF FOUND THEN v_unlocked := array_append(v_unlocked, 'pet_adult'); END IF;
    END IF;

    IF v_pet.evolution = 'legendary' THEN
        UPDATE achievements SET progress = 1, unlocked_at = COALESCE(unlocked_at, NOW())
        WHERE couple_id = p_couple_id AND key = 'pet_legendary' AND unlocked_at IS NULL;
        IF FOUND THEN v_unlocked := array_append(v_unlocked, 'pet_legendary'); END IF;
    END IF;

    -- Add unlocked accessories to pet
    IF array_length(v_unlocked, 1) > 0 THEN
        UPDATE pet_state
        SET accessories = accessories || (
            SELECT ARRAY_AGG(reward_accessory)
            FROM achievements
            WHERE couple_id = p_couple_id
            AND key = ANY(v_unlocked)
            AND reward_accessory IS NOT NULL
        )
        WHERE couple_id = p_couple_id;

        -- Award XP for achievements
        PERFORM award_pet_xp(p_couple_id, array_length(v_unlocked, 1) * 100);
    END IF;

    RETURN QUERY SELECT v_unlocked;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- FUNCTION: Get monthly summary for a couple
-- ============================================================

CREATE OR REPLACE FUNCTION get_monthly_summary(p_couple_id UUID, p_month DATE DEFAULT CURRENT_DATE)
RETURNS TABLE(
    total_income DECIMAL,
    total_expenses DECIMAL,
    net_balance DECIMAL,
    category_breakdown JSONB,
    transaction_count INTEGER,
    top_category transaction_category
) AS $$
DECLARE
    v_month_start DATE := DATE_TRUNC('month', p_month)::DATE;
    v_month_end DATE := (DATE_TRUNC('month', p_month) + INTERVAL '1 month' - INTERVAL '1 day')::DATE;
BEGIN
    RETURN QUERY
    WITH month_transactions AS (
        SELECT t.* FROM transactions t
        WHERE t.couple_id = p_couple_id
        AND t.date BETWEEN v_month_start AND v_month_end
    ),
    category_totals AS (
        SELECT
            t.category,
            SUM(t.amount) as cat_total
        FROM month_transactions t
        WHERE t.type = 'expense'
        GROUP BY t.category
        ORDER BY cat_total DESC
    )
    SELECT
        COALESCE(SUM(CASE WHEN mt.type = 'income' THEN mt.amount END), 0),
        COALESCE(SUM(CASE WHEN mt.type = 'expense' THEN mt.amount END), 0),
        COALESCE(SUM(CASE WHEN mt.type = 'income' THEN mt.amount ELSE -mt.amount END), 0),
        COALESCE((SELECT jsonb_object_agg(ct.category, ct.cat_total) FROM category_totals ct), '{}'::JSONB),
        COUNT(mt.id)::INTEGER,
        (SELECT ct.category FROM category_totals ct LIMIT 1)
    FROM month_transactions mt;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- FUNCTION: Check budget alerts
-- ============================================================

CREATE OR REPLACE FUNCTION check_budget_alerts(p_couple_id UUID)
RETURNS TABLE(
    budget_id UUID,
    category transaction_category,
    percentage_used DECIMAL,
    amount_limit DECIMAL,
    current_spent DECIMAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        b.id,
        b.category,
        ROUND((b.current_spent / NULLIF(b.amount_limit, 0)) * 100, 1),
        b.amount_limit,
        b.current_spent
    FROM budgets b
    WHERE b.couple_id = p_couple_id
    AND b.is_active = TRUE
    AND b.current_spent >= b.amount_limit * b.alert_threshold;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
