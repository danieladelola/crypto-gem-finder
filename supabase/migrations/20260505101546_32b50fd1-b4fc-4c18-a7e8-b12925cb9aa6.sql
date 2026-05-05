-- ============ ENUMS ============
CREATE TYPE public.app_role AS ENUM ('admin', 'user');
CREATE TYPE public.tx_status AS ENUM ('pending', 'approved', 'rejected', 'completed', 'cancelled');
CREATE TYPE public.kyc_status AS ENUM ('none', 'pending', 'approved', 'rejected');
CREATE TYPE public.stake_status AS ENUM ('active', 'completed', 'cancelled');
CREATE TYPE public.trade_status AS ENUM ('open', 'closed', 'cancelled');
CREATE TYPE public.trade_side AS ENUM ('buy', 'sell', 'long', 'short');

-- ============ PROFILES ============
CREATE TABLE public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT,
  full_name TEXT,
  phone TEXT,
  avatar_url TEXT,
  email_verified BOOLEAN NOT NULL DEFAULT false,
  mobile_verified BOOLEAN NOT NULL DEFAULT false,
  banned BOOLEAN NOT NULL DEFAULT false,
  kyc_status public.kyc_status NOT NULL DEFAULT 'none',
  notes TEXT,
  address_line1 TEXT,
  address_line2 TEXT,
  city TEXT,
  state TEXT,
  postal_code TEXT,
  country TEXT,
  dob DATE,
  id_number TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.user_roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role public.app_role NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, role)
);
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.has_role(_user_id UUID, _role public.app_role)
RETURNS BOOLEAN LANGUAGE SQL STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = _user_id AND role = _role)
$$;

CREATE TABLE public.market_assets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  symbol TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  coingecko_id TEXT,
  deposit_address TEXT,
  icon_url TEXT,
  active BOOLEAN NOT NULL DEFAULT true,
  sort_order INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.market_assets ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.wallet_balances (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  coin TEXT NOT NULL,
  available NUMERIC(28,8) NOT NULL DEFAULT 0 CHECK (available >= 0),
  staked NUMERIC(28,8) NOT NULL DEFAULT 0 CHECK (staked >= 0),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, coin)
);
ALTER TABLE public.wallet_balances ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.fiat_balances (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL,
  currency TEXT NOT NULL DEFAULT 'USD',
  available NUMERIC(28,8) NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(user_id, currency)
);
ALTER TABLE public.fiat_balances ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.deposits (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  coin TEXT NOT NULL,
  amount NUMERIC(28,8) NOT NULL CHECK (amount > 0),
  tx_hash TEXT,
  proof_url TEXT,
  status public.tx_status NOT NULL DEFAULT 'pending',
  admin_note TEXT,
  usd_amount NUMERIC(28,8),
  pay_coin TEXT,
  pay_amount NUMERIC(28,8),
  rate_used NUMERIC(28,8),
  fee_pct NUMERIC(8,4) DEFAULT 0,
  usd_credited NUMERIC(28,8),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  processed_at TIMESTAMPTZ
);
ALTER TABLE public.deposits ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.withdrawals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  coin TEXT NOT NULL,
  amount NUMERIC(28,8) NOT NULL CHECK (amount > 0),
  fee NUMERIC(28,8) NOT NULL DEFAULT 0,
  address TEXT NOT NULL,
  status public.tx_status NOT NULL DEFAULT 'pending',
  admin_note TEXT,
  usd_amount NUMERIC(28,8),
  payout_coin TEXT,
  payout_amount NUMERIC(28,8),
  rate_used NUMERIC(28,8),
  fee_pct NUMERIC(8,4) DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  processed_at TIMESTAMPTZ
);
ALTER TABLE public.withdrawals ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.staking_plans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  coin TEXT NOT NULL,
  apy NUMERIC(6,2) NOT NULL,
  lock_days INT NOT NULL,
  min_amount NUMERIC(28,8) NOT NULL DEFAULT 0,
  max_amount NUMERIC(28,8),
  fixed_amount NUMERIC(28,8),
  description TEXT,
  is_usd BOOLEAN NOT NULL DEFAULT false,
  active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.staking_plans ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.user_stakes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  plan_id UUID NOT NULL REFERENCES public.staking_plans(id) ON DELETE RESTRICT,
  coin TEXT NOT NULL,
  amount NUMERIC(28,8) NOT NULL CHECK (amount > 0),
  apy NUMERIC(6,2) NOT NULL,
  reward_earned NUMERIC(28,8) NOT NULL DEFAULT 0,
  is_usd BOOLEAN NOT NULL DEFAULT false,
  started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  ends_at TIMESTAMPTZ NOT NULL,
  status public.stake_status NOT NULL DEFAULT 'active',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.user_stakes ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.trade_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  pair TEXT NOT NULL,
  side public.trade_side NOT NULL,
  amount NUMERIC(28,8) NOT NULL,
  entry_price NUMERIC(28,8) NOT NULL,
  exit_price NUMERIC(28,8),
  pnl NUMERIC(28,8),
  status public.trade_status NOT NULL DEFAULT 'open',
  notes TEXT,
  opened_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  closed_at TIMESTAMPTZ
);
ALTER TABLE public.trade_records ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.signals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  pair TEXT NOT NULL,
  side public.trade_side NOT NULL,
  entry NUMERIC(28,8) NOT NULL,
  target NUMERIC(28,8),
  stop NUMERIC(28,8),
  notes TEXT,
  created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.signals ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.user_signals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  signal_id UUID NOT NULL REFERENCES public.signals(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  read BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (signal_id, user_id)
);
ALTER TABLE public.user_signals ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  body TEXT,
  read BOOLEAN NOT NULL DEFAULT false,
  broadcast BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.login_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  ip TEXT,
  user_agent TEXT,
  at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.login_history ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.transaction_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  type TEXT NOT NULL,
  coin TEXT,
  amount NUMERIC(28,8),
  ref_id UUID,
  status public.tx_status,
  description TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.transaction_history ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.copy_experts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  bio TEXT,
  avatar_url TEXT,
  win_rate NUMERIC(5,2),
  followers INT NOT NULL DEFAULT 0,
  active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.copy_experts ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.kyc_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  doc_type TEXT NOT NULL,
  doc_url TEXT,
  status public.kyc_status NOT NULL DEFAULT 'pending',
  admin_note TEXT,
  id_front_url TEXT,
  id_back_url TEXT,
  selfie_url TEXT,
  full_address TEXT,
  reviewed_at TIMESTAMPTZ,
  reviewed_by UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.kyc_records ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.system_settings (
  key TEXT PRIMARY KEY,
  value JSONB NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.system_settings ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.exchange_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL,
  kind TEXT NOT NULL,
  from_asset TEXT NOT NULL,
  to_asset TEXT NOT NULL,
  from_amount NUMERIC(28,8) NOT NULL,
  to_amount NUMERIC(28,8) NOT NULL,
  rate NUMERIC(28,8) NOT NULL,
  fee_amount NUMERIC(28,8) NOT NULL DEFAULT 0,
  fee_pct NUMERIC(8,4) NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'completed',
  note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.exchange_transactions ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.balance_adjustments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_id UUID NOT NULL,
  user_id UUID NOT NULL,
  asset TEXT NOT NULL,
  delta NUMERIC(28,8) NOT NULL,
  reason TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.balance_adjustments ENABLE ROW LEVEL SECURITY;

-- RLS POLICIES
CREATE POLICY profiles_self_select ON public.profiles FOR SELECT TO authenticated USING (auth.uid() = id);
CREATE POLICY profiles_admin_select ON public.profiles FOR SELECT TO authenticated USING (public.has_role(auth.uid(), 'admin'));
CREATE POLICY profiles_self_update ON public.profiles FOR UPDATE TO authenticated USING (auth.uid() = id);
CREATE POLICY profiles_admin_update ON public.profiles FOR UPDATE TO authenticated USING (public.has_role(auth.uid(), 'admin'));
CREATE POLICY profiles_self_insert ON public.profiles FOR INSERT TO authenticated WITH CHECK (auth.uid() = id);

CREATE POLICY user_roles_self_select ON public.user_roles FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY user_roles_admin_all ON public.user_roles FOR ALL TO authenticated USING (public.has_role(auth.uid(), 'admin')) WITH CHECK (public.has_role(auth.uid(), 'admin'));

CREATE POLICY market_assets_read_all ON public.market_assets FOR SELECT USING (true);
CREATE POLICY market_assets_admin_write ON public.market_assets FOR ALL TO authenticated USING (public.has_role(auth.uid(), 'admin')) WITH CHECK (public.has_role(auth.uid(), 'admin'));

CREATE POLICY wb_self_select ON public.wallet_balances FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY wb_admin_all ON public.wallet_balances FOR ALL TO authenticated USING (public.has_role(auth.uid(), 'admin')) WITH CHECK (public.has_role(auth.uid(), 'admin'));

CREATE POLICY fb_self_select ON public.fiat_balances FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY fb_admin_all ON public.fiat_balances FOR ALL TO authenticated USING (public.has_role(auth.uid(), 'admin')) WITH CHECK (public.has_role(auth.uid(), 'admin'));

CREATE POLICY dep_self_select ON public.deposits FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY dep_self_insert ON public.deposits FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
CREATE POLICY dep_admin_all ON public.deposits FOR ALL TO authenticated USING (public.has_role(auth.uid(), 'admin')) WITH CHECK (public.has_role(auth.uid(), 'admin'));

CREATE POLICY wd_self_select ON public.withdrawals FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY wd_self_insert ON public.withdrawals FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
CREATE POLICY wd_admin_all ON public.withdrawals FOR ALL TO authenticated USING (public.has_role(auth.uid(), 'admin')) WITH CHECK (public.has_role(auth.uid(), 'admin'));

CREATE POLICY sp_read_all ON public.staking_plans FOR SELECT USING (true);
CREATE POLICY sp_admin_all ON public.staking_plans FOR ALL TO authenticated USING (public.has_role(auth.uid(), 'admin')) WITH CHECK (public.has_role(auth.uid(), 'admin'));

CREATE POLICY us_self_select ON public.user_stakes FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY us_self_insert ON public.user_stakes FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
CREATE POLICY us_admin_all ON public.user_stakes FOR ALL TO authenticated USING (public.has_role(auth.uid(), 'admin')) WITH CHECK (public.has_role(auth.uid(), 'admin'));

CREATE POLICY tr_self_select ON public.trade_records FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY tr_admin_all ON public.trade_records FOR ALL TO authenticated USING (public.has_role(auth.uid(), 'admin')) WITH CHECK (public.has_role(auth.uid(), 'admin'));

CREATE POLICY sig_read_all ON public.signals FOR SELECT TO authenticated USING (true);
CREATE POLICY sig_admin_all ON public.signals FOR ALL TO authenticated USING (public.has_role(auth.uid(), 'admin')) WITH CHECK (public.has_role(auth.uid(), 'admin'));

CREATE POLICY usig_self_select ON public.user_signals FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY usig_self_update ON public.user_signals FOR UPDATE TO authenticated USING (auth.uid() = user_id);
CREATE POLICY usig_admin_all ON public.user_signals FOR ALL TO authenticated USING (public.has_role(auth.uid(), 'admin')) WITH CHECK (public.has_role(auth.uid(), 'admin'));

CREATE POLICY notif_self_select ON public.notifications FOR SELECT TO authenticated USING (auth.uid() = user_id OR broadcast = true);
CREATE POLICY notif_self_update ON public.notifications FOR UPDATE TO authenticated USING (auth.uid() = user_id);
CREATE POLICY notif_admin_all ON public.notifications FOR ALL TO authenticated USING (public.has_role(auth.uid(), 'admin')) WITH CHECK (public.has_role(auth.uid(), 'admin'));

CREATE POLICY lh_self_select ON public.login_history FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY lh_self_insert ON public.login_history FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
CREATE POLICY lh_admin_select ON public.login_history FOR SELECT TO authenticated USING (public.has_role(auth.uid(), 'admin'));

CREATE POLICY th_self_select ON public.transaction_history FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY th_admin_all ON public.transaction_history FOR ALL TO authenticated USING (public.has_role(auth.uid(), 'admin')) WITH CHECK (public.has_role(auth.uid(), 'admin'));

CREATE POLICY ce_read_all ON public.copy_experts FOR SELECT USING (true);
CREATE POLICY ce_admin_all ON public.copy_experts FOR ALL TO authenticated USING (public.has_role(auth.uid(), 'admin')) WITH CHECK (public.has_role(auth.uid(), 'admin'));

CREATE POLICY kyc_self_select ON public.kyc_records FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY kyc_self_insert ON public.kyc_records FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
CREATE POLICY kyc_admin_all ON public.kyc_records FOR ALL TO authenticated USING (public.has_role(auth.uid(), 'admin')) WITH CHECK (public.has_role(auth.uid(), 'admin'));

CREATE POLICY ss_read_all ON public.system_settings FOR SELECT USING (true);
CREATE POLICY ss_admin_write ON public.system_settings FOR ALL TO authenticated USING (public.has_role(auth.uid(), 'admin')) WITH CHECK (public.has_role(auth.uid(), 'admin'));

CREATE POLICY ex_self_select ON public.exchange_transactions FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY ex_admin_all ON public.exchange_transactions FOR ALL TO authenticated USING (public.has_role(auth.uid(), 'admin')) WITH CHECK (public.has_role(auth.uid(), 'admin'));

CREATE POLICY ba_admin_all ON public.balance_adjustments FOR ALL TO authenticated USING (public.has_role(auth.uid(), 'admin')) WITH CHECK (public.has_role(auth.uid(), 'admin'));
CREATE POLICY ba_user_select_own ON public.balance_adjustments FOR SELECT TO authenticated USING (auth.uid() = user_id);
