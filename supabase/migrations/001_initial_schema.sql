-- ============================================================
-- Fingether — Initial Schema + RLS
-- Migration 001: All tables, indexes, constraints, RLS policies
-- ============================================================

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================
-- ENUM TYPES
-- ============================================================

CREATE TYPE transaction_type AS ENUM ('income', 'expense');
CREATE TYPE transaction_category AS ENUM (
    'food', 'transport', 'housing', 'utilities', 'entertainment',
    'health', 'education', 'shopping', 'travel', 'gifts',
    'savings', 'investments', 'salary', 'freelance', 'other'
);
CREATE TYPE budget_period AS ENUM ('weekly', 'biweekly', 'monthly');
CREATE TYPE pet_mood AS ENUM ('ecstatic', 'happy', 'neutral', 'sad', 'critical');
CREATE TYPE pet_evolution AS ENUM ('egg', 'baby', 'teen', 'adult', 'legendary');
CREATE TYPE subscription_tier AS ENUM ('free', 'premium');
CREATE TYPE notification_type AS ENUM ('budget_alert', 'achievement', 'partner_activity', 'pet_status', 'insight', 'savings_milestone');
CREATE TYPE savings_goal_status AS ENUM ('active', 'completed', 'cancelled');
CREATE TYPE achievement_category AS ENUM ('savings', 'budget', 'streak', 'social', 'pet', 'milestone');

-- ============================================================
-- TABLE: profiles
-- ============================================================

CREATE TABLE profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    display_name TEXT NOT NULL,
    avatar_url TEXT,
    couple_id UUID,
    subscription_tier subscription_tier NOT NULL DEFAULT 'free',
    monthly_income DECIMAL(12,2) DEFAULT 0,
    currency TEXT NOT NULL DEFAULT 'MXN',
    streak_days INTEGER NOT NULL DEFAULT 0,
    last_transaction_date DATE,
    onboarding_completed BOOLEAN NOT NULL DEFAULT FALSE,
    notification_token TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_profiles_couple ON profiles(couple_id);
CREATE INDEX idx_profiles_email ON profiles(email);

-- ============================================================
-- TABLE: couples
-- ============================================================

CREATE TABLE couples (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    invite_code TEXT UNIQUE NOT NULL DEFAULT UPPER(SUBSTRING(md5(random()::text) FROM 1 FOR 8)),
    partner_1_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    partner_2_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    combined_monthly_income DECIMAL(12,2) DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_couples_invite_code ON couples(invite_code);
CREATE INDEX idx_couples_partner_1 ON couples(partner_1_id);
CREATE INDEX idx_couples_partner_2 ON couples(partner_2_id);

-- Add foreign key for profiles.couple_id
ALTER TABLE profiles ADD CONSTRAINT fk_profiles_couple FOREIGN KEY (couple_id) REFERENCES couples(id) ON DELETE SET NULL;

-- ============================================================
-- TABLE: transactions
-- ============================================================

CREATE TABLE transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    couple_id UUID REFERENCES couples(id) ON DELETE SET NULL,
    type transaction_type NOT NULL,
    category transaction_category NOT NULL DEFAULT 'other',
    amount DECIMAL(12,2) NOT NULL CHECK (amount > 0),
    description TEXT NOT NULL DEFAULT '',
    notes TEXT,
    date DATE NOT NULL DEFAULT CURRENT_DATE,
    is_recurring BOOLEAN NOT NULL DEFAULT FALSE,
    recurring_frequency TEXT, -- 'daily', 'weekly', 'monthly'
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_transactions_user ON transactions(user_id);
CREATE INDEX idx_transactions_couple ON transactions(couple_id);
CREATE INDEX idx_transactions_date ON transactions(date DESC);
CREATE INDEX idx_transactions_category ON transactions(category);
CREATE INDEX idx_transactions_type_date ON transactions(type, date DESC);

-- ============================================================
-- TABLE: budgets
-- ============================================================

CREATE TABLE budgets (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    couple_id UUID NOT NULL REFERENCES couples(id) ON DELETE CASCADE,
    category transaction_category NOT NULL,
    amount_limit DECIMAL(12,2) NOT NULL CHECK (amount_limit > 0),
    period budget_period NOT NULL DEFAULT 'monthly',
    current_spent DECIMAL(12,2) NOT NULL DEFAULT 0,
    alert_threshold DECIMAL(3,2) NOT NULL DEFAULT 0.80, -- 80% alert
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    start_date DATE NOT NULL DEFAULT CURRENT_DATE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(couple_id, category, period)
);

CREATE INDEX idx_budgets_couple ON budgets(couple_id);
CREATE INDEX idx_budgets_active ON budgets(is_active) WHERE is_active = TRUE;

-- ============================================================
-- TABLE: savings_goals
-- ============================================================

CREATE TABLE savings_goals (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    couple_id UUID NOT NULL REFERENCES couples(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    target_amount DECIMAL(12,2) NOT NULL CHECK (target_amount > 0),
    current_amount DECIMAL(12,2) NOT NULL DEFAULT 0 CHECK (current_amount >= 0),
    target_date DATE,
    emoji TEXT NOT NULL DEFAULT '🎯',
    status savings_goal_status NOT NULL DEFAULT 'active',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_savings_couple ON savings_goals(couple_id);
CREATE INDEX idx_savings_status ON savings_goals(status);

-- ============================================================
-- TABLE: pet_state
-- ============================================================

CREATE TABLE pet_state (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    couple_id UUID UNIQUE NOT NULL REFERENCES couples(id) ON DELETE CASCADE,
    name TEXT NOT NULL DEFAULT 'Buddy',
    health INTEGER NOT NULL DEFAULT 50 CHECK (health BETWEEN 0 AND 100),
    mood pet_mood NOT NULL DEFAULT 'neutral',
    evolution pet_evolution NOT NULL DEFAULT 'egg',
    experience_points INTEGER NOT NULL DEFAULT 0,
    days_alive INTEGER NOT NULL DEFAULT 0,
    accessories TEXT[] NOT NULL DEFAULT '{}',
    equipped_accessory TEXT,
    last_fed TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_health_update TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_pet_couple ON pet_state(couple_id);

-- ============================================================
-- TABLE: achievements
-- ============================================================

CREATE TABLE achievements (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    couple_id UUID NOT NULL REFERENCES couples(id) ON DELETE CASCADE,
    key TEXT NOT NULL, -- unique achievement identifier
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    category achievement_category NOT NULL,
    icon TEXT NOT NULL DEFAULT '🏆',
    unlocked_at TIMESTAMPTZ,
    reward_accessory TEXT, -- accessory unlocked for pet
    progress INTEGER NOT NULL DEFAULT 0,
    target INTEGER NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(couple_id, key)
);

CREATE INDEX idx_achievements_couple ON achievements(couple_id);
CREATE INDEX idx_achievements_unlocked ON achievements(unlocked_at) WHERE unlocked_at IS NOT NULL;

-- ============================================================
-- TABLE: notifications
-- ============================================================

CREATE TABLE notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    couple_id UUID REFERENCES couples(id) ON DELETE SET NULL,
    type notification_type NOT NULL,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    data JSONB DEFAULT '{}',
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_notifications_user ON notifications(user_id);
CREATE INDEX idx_notifications_unread ON notifications(user_id, is_read) WHERE is_read = FALSE;
CREATE INDEX idx_notifications_created ON notifications(created_at DESC);

-- ============================================================
-- TABLE: subscriptions
-- ============================================================

CREATE TABLE subscriptions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    product_id TEXT NOT NULL,
    tier subscription_tier NOT NULL DEFAULT 'premium',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    original_transaction_id TEXT,
    purchase_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expiration_date TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_subscriptions_user ON subscriptions(user_id);
CREATE INDEX idx_subscriptions_active ON subscriptions(is_active) WHERE is_active = TRUE;

-- ============================================================
-- TABLE: insights_cache
-- ============================================================

CREATE TABLE insights_cache (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    couple_id UUID NOT NULL REFERENCES couples(id) ON DELETE CASCADE,
    insight_type TEXT NOT NULL, -- 'weekly', 'monthly', 'custom'
    content TEXT NOT NULL,
    metadata JSONB DEFAULT '{}',
    generated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL DEFAULT NOW() + INTERVAL '24 hours'
);

CREATE INDEX idx_insights_couple ON insights_cache(couple_id);
CREATE INDEX idx_insights_expires ON insights_cache(expires_at);

-- ============================================================
-- RLS POLICIES
-- ============================================================

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE couples ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE budgets ENABLE ROW LEVEL SECURITY;
ALTER TABLE savings_goals ENABLE ROW LEVEL SECURITY;
ALTER TABLE pet_state ENABLE ROW LEVEL SECURITY;
ALTER TABLE achievements ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE insights_cache ENABLE ROW LEVEL SECURITY;

-- PROFILES policies
CREATE POLICY "Users can read own profile"
    ON profiles FOR SELECT
    USING (auth.uid() = id);

CREATE POLICY "Users can read partner profile"
    ON profiles FOR SELECT
    USING (
        couple_id IS NOT NULL
        AND couple_id IN (SELECT couple_id FROM profiles WHERE id = auth.uid())
    );

CREATE POLICY "Users can update own profile"
    ON profiles FOR UPDATE
    USING (auth.uid() = id)
    WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can insert own profile"
    ON profiles FOR INSERT
    WITH CHECK (auth.uid() = id);

-- COUPLES policies
CREATE POLICY "Users can read own couple"
    ON couples FOR SELECT
    USING (partner_1_id = auth.uid() OR partner_2_id = auth.uid());

CREATE POLICY "Users can create couple"
    ON couples FOR INSERT
    WITH CHECK (partner_1_id = auth.uid());

CREATE POLICY "Users can update own couple"
    ON couples FOR UPDATE
    USING (partner_1_id = auth.uid() OR partner_2_id = auth.uid());

CREATE POLICY "Anyone can read couple by invite code"
    ON couples FOR SELECT
    USING (TRUE); -- needed for join flow, filtered by invite_code in query

-- TRANSACTIONS policies
CREATE POLICY "Users can read own transactions"
    ON transactions FOR SELECT
    USING (user_id = auth.uid());

CREATE POLICY "Users can read partner transactions"
    ON transactions FOR SELECT
    USING (
        couple_id IS NOT NULL
        AND couple_id IN (SELECT couple_id FROM profiles WHERE id = auth.uid())
    );

CREATE POLICY "Users can insert own transactions"
    ON transactions FOR INSERT
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can update own transactions"
    ON transactions FOR UPDATE
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can delete own transactions"
    ON transactions FOR DELETE
    USING (user_id = auth.uid());

-- BUDGETS policies
CREATE POLICY "Users can read couple budgets"
    ON budgets FOR SELECT
    USING (couple_id IN (SELECT couple_id FROM profiles WHERE id = auth.uid()));

CREATE POLICY "Users can insert couple budgets"
    ON budgets FOR INSERT
    WITH CHECK (couple_id IN (SELECT couple_id FROM profiles WHERE id = auth.uid()));

CREATE POLICY "Users can update couple budgets"
    ON budgets FOR UPDATE
    USING (couple_id IN (SELECT couple_id FROM profiles WHERE id = auth.uid()));

CREATE POLICY "Users can delete couple budgets"
    ON budgets FOR DELETE
    USING (couple_id IN (SELECT couple_id FROM profiles WHERE id = auth.uid()));

-- SAVINGS_GOALS policies
CREATE POLICY "Users can read couple savings goals"
    ON savings_goals FOR SELECT
    USING (couple_id IN (SELECT couple_id FROM profiles WHERE id = auth.uid()));

CREATE POLICY "Users can insert couple savings goals"
    ON savings_goals FOR INSERT
    WITH CHECK (couple_id IN (SELECT couple_id FROM profiles WHERE id = auth.uid()));

CREATE POLICY "Users can update couple savings goals"
    ON savings_goals FOR UPDATE
    USING (couple_id IN (SELECT couple_id FROM profiles WHERE id = auth.uid()));

CREATE POLICY "Users can delete couple savings goals"
    ON savings_goals FOR DELETE
    USING (couple_id IN (SELECT couple_id FROM profiles WHERE id = auth.uid()));

-- PET_STATE policies
CREATE POLICY "Users can read couple pet"
    ON pet_state FOR SELECT
    USING (couple_id IN (SELECT couple_id FROM profiles WHERE id = auth.uid()));

CREATE POLICY "Users can update couple pet"
    ON pet_state FOR UPDATE
    USING (couple_id IN (SELECT couple_id FROM profiles WHERE id = auth.uid()));

CREATE POLICY "Users can insert couple pet"
    ON pet_state FOR INSERT
    WITH CHECK (couple_id IN (SELECT couple_id FROM profiles WHERE id = auth.uid()));

-- ACHIEVEMENTS policies
CREATE POLICY "Users can read couple achievements"
    ON achievements FOR SELECT
    USING (couple_id IN (SELECT couple_id FROM profiles WHERE id = auth.uid()));

CREATE POLICY "Users can insert couple achievements"
    ON achievements FOR INSERT
    WITH CHECK (couple_id IN (SELECT couple_id FROM profiles WHERE id = auth.uid()));

CREATE POLICY "Users can update couple achievements"
    ON achievements FOR UPDATE
    USING (couple_id IN (SELECT couple_id FROM profiles WHERE id = auth.uid()));

-- NOTIFICATIONS policies
CREATE POLICY "Users can read own notifications"
    ON notifications FOR SELECT
    USING (user_id = auth.uid());

CREATE POLICY "Users can update own notifications"
    ON notifications FOR UPDATE
    USING (user_id = auth.uid());

CREATE POLICY "System can insert notifications"
    ON notifications FOR INSERT
    WITH CHECK (TRUE); -- controlled via service role in Edge Functions

-- SUBSCRIPTIONS policies
CREATE POLICY "Users can read own subscriptions"
    ON subscriptions FOR SELECT
    USING (user_id = auth.uid());

CREATE POLICY "Users can insert own subscriptions"
    ON subscriptions FOR INSERT
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can update own subscriptions"
    ON subscriptions FOR UPDATE
    USING (user_id = auth.uid());

-- INSIGHTS_CACHE policies
CREATE POLICY "Users can read couple insights"
    ON insights_cache FOR SELECT
    USING (couple_id IN (SELECT couple_id FROM profiles WHERE id = auth.uid()));

CREATE POLICY "System can insert insights"
    ON insights_cache FOR INSERT
    WITH CHECK (TRUE); -- controlled via service role

CREATE POLICY "System can delete expired insights"
    ON insights_cache FOR DELETE
    USING (TRUE); -- cleanup via service role
