ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS username TEXT UNIQUE,
  ADD COLUMN IF NOT EXISTS two_factor_enabled BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS country_code TEXT,
  ADD COLUMN IF NOT EXISTS banned_reason TEXT,
  ADD COLUMN IF NOT EXISTS first_name TEXT,
  ADD COLUMN IF NOT EXISTS last_name TEXT;

CREATE INDEX IF NOT EXISTS profiles_username_lower_idx ON public.profiles (lower(username));

ALTER TABLE public.notifications
  ADD COLUMN IF NOT EXISTS segment TEXT,
  ADD COLUMN IF NOT EXISTS audience_count INT;

CREATE TABLE IF NOT EXISTS public.impersonation_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_id UUID NOT NULL,
  target_user_id UUID NOT NULL,
  admin_email TEXT,
  target_email TEXT,
  ip TEXT,
  user_agent TEXT,
  started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  ended_at TIMESTAMPTZ
);
ALTER TABLE public.impersonation_log ENABLE ROW LEVEL SECURITY;
CREATE POLICY imp_admin_all ON public.impersonation_log FOR ALL TO authenticated
  USING (public.has_role(auth.uid(), 'admin')) WITH CHECK (public.has_role(auth.uid(), 'admin'));
CREATE POLICY imp_target_select_own ON public.impersonation_log FOR SELECT TO authenticated USING (auth.uid() = target_user_id);

CREATE OR REPLACE FUNCTION public.set_username(_username TEXT)
RETURNS BOOLEAN LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE existing UUID;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  IF _username IS NULL OR length(trim(_username)) < 3 THEN RAISE EXCEPTION 'Username too short'; END IF;
  IF length(_username) > 30 THEN RAISE EXCEPTION 'Username too long'; END IF;
  IF _username !~ '^[A-Za-z0-9_.]+$' THEN RAISE EXCEPTION 'Username can only contain letters, numbers, underscore and dot'; END IF;
  SELECT id INTO existing FROM public.profiles WHERE lower(username) = lower(_username) AND id <> auth.uid();
  IF existing IS NOT NULL THEN RETURN false; END IF;
  UPDATE public.profiles SET username = _username WHERE id = auth.uid();
  RETURN true;
END; $$;

CREATE OR REPLACE FUNCTION public.lookup_email_for_login(_identifier TEXT)
RETURNS TEXT LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE found TEXT;
BEGIN
  IF _identifier IS NULL OR length(_identifier) = 0 THEN RETURN NULL; END IF;
  IF _identifier LIKE '%@%' THEN RETURN _identifier; END IF;
  SELECT email INTO found FROM public.profiles WHERE lower(username) = lower(_identifier) LIMIT 1;
  RETURN found;
END; $$;
GRANT EXECUTE ON FUNCTION public.lookup_email_for_login(TEXT) TO anon, authenticated;

CREATE OR REPLACE FUNCTION public.send_notification_segment(
  _segment TEXT, _title TEXT, _body TEXT, _target_user UUID DEFAULT NULL
) RETURNS INT LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE inserted_count INT := 0;
BEGIN
  IF NOT public.has_role(auth.uid(), 'admin') THEN RAISE EXCEPTION 'Only admins'; END IF;
  IF _title IS NULL OR length(trim(_title)) = 0 THEN RAISE EXCEPTION 'Title required'; END IF;
  IF _segment = 'single' THEN
    IF _target_user IS NULL THEN RAISE EXCEPTION 'target_user required for single'; END IF;
    INSERT INTO public.notifications (user_id, title, body, segment) VALUES (_target_user, _title, _body, _segment);
    RETURN 1;
  END IF;
  WITH audience AS (
    SELECT id FROM public.profiles p
    WHERE CASE _segment
      WHEN 'all' THEN true
      WHEN 'active' THEN p.banned = false
      WHEN 'banned' THEN p.banned = true
      WHEN 'email_unverified' THEN p.email_verified = false
      WHEN 'mobile_unverified' THEN p.mobile_verified = false
      WHEN 'kyc_unverified' THEN p.kyc_status IN ('none','unverified')
      WHEN 'kyc_pending' THEN p.kyc_status = 'pending'
      WHEN 'with_balance' THEN EXISTS (SELECT 1 FROM public.wallet_balances w WHERE w.user_id = p.id AND (w.available > 0 OR w.staked > 0))
        OR EXISTS (SELECT 1 FROM public.fiat_balances f WHERE f.user_id = p.id AND f.available > 0)
      ELSE false
    END
  ), ins AS (
    INSERT INTO public.notifications (user_id, title, body, segment)
    SELECT id, _title, _body, _segment FROM audience RETURNING 1
  )
  SELECT count(*) INTO inserted_count FROM ins;
  RETURN inserted_count;
END; $$;

CREATE TABLE IF NOT EXISTS public.email_settings (
  id INT PRIMARY KEY DEFAULT 1,
  enabled BOOLEAN NOT NULL DEFAULT false,
  mail_driver TEXT NOT NULL DEFAULT 'smtp',
  smtp_host TEXT, smtp_port INT DEFAULT 587, smtp_user TEXT, smtp_pass TEXT,
  smtp_encryption TEXT NOT NULL DEFAULT 'tls',
  from_email TEXT, from_name TEXT, reply_to TEXT,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT email_settings_singleton CHECK (id = 1)
);
INSERT INTO public.email_settings (id) VALUES (1) ON CONFLICT DO NOTHING;
ALTER TABLE public.email_settings ENABLE ROW LEVEL SECURITY;
CREATE POLICY es_admin_all ON public.email_settings FOR ALL TO authenticated
  USING (public.has_role(auth.uid(), 'admin')) WITH CHECK (public.has_role(auth.uid(), 'admin'));

CREATE TABLE IF NOT EXISTS public.email_templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  key TEXT NOT NULL UNIQUE, name TEXT NOT NULL, subject TEXT NOT NULL, body TEXT NOT NULL,
  active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.email_templates ENABLE ROW LEVEL SECURITY;
CREATE POLICY et_admin_all ON public.email_templates FOR ALL TO authenticated
  USING (public.has_role(auth.uid(), 'admin')) WITH CHECK (public.has_role(auth.uid(), 'admin'));
CREATE POLICY et_read_all ON public.email_templates FOR SELECT TO authenticated USING (true);
CREATE TRIGGER trg_email_templates_updated BEFORE UPDATE ON public.email_templates
  FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

CREATE TABLE IF NOT EXISTS public.email_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  recipient TEXT NOT NULL, subject TEXT, template_key TEXT,
  status TEXT NOT NULL, error TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.email_logs ENABLE ROW LEVEL SECURITY;
CREATE POLICY el_admin_all ON public.email_logs FOR ALL TO authenticated
  USING (public.has_role(auth.uid(), 'admin')) WITH CHECK (public.has_role(auth.uid(), 'admin'));
CREATE INDEX IF NOT EXISTS idx_email_logs_created ON public.email_logs (created_at DESC);

INSERT INTO public.email_templates (key, name, subject, body, active) VALUES
('welcome', 'Welcome Email', 'Welcome to {{site_name}}', 'Hi {{user_name}},\n\nWelcome to {{site_name}}! Your account is ready.\n\nLogin: {{login_url}}\n\n— The {{site_name}} Team', true),
('email_verification', 'Email Verification', 'Verify your email - {{site_name}}', 'Hi {{user_name}},\n\nPlease verify your email by clicking the link below:\n\n{{verification_link}}\n\nThanks,\n{{site_name}}', true),
('password_reset', 'Password Reset', 'Reset your password - {{site_name}}', 'Hi {{user_name}},\n\nClick the link below to reset your password:\n\n{{reset_link}}\n\nIf you did not request this, ignore this email.', true),
('kyc_pending', 'KYC Pending', 'KYC submission received', 'Hi {{user_name}},\n\nWe received your KYC submission and it is pending review.\n\n— {{site_name}}', true),
('kyc_approved', 'KYC Approved', 'KYC Approved', 'Hi {{user_name}},\n\nYour KYC has been approved. You now have full access.\n\n— {{site_name}}', true),
('kyc_rejected', 'KYC Rejected', 'KYC Rejected', 'Hi {{user_name}},\n\nUnfortunately your KYC was rejected. Please contact support: {{support_email}}', true),
('deposit_received', 'Deposit Received', 'Deposit received', 'Hi {{user_name}},\n\nWe have received your deposit of {{amount}} {{currency}}. Transaction ID: {{transaction_id}}.', true),
('deposit_approved', 'Deposit Approved', 'Deposit approved', 'Hi {{user_name}},\n\nYour deposit of {{amount}} {{currency}} has been approved.', true),
('withdrawal_request', 'Withdrawal Request', 'Withdrawal request received', 'Hi {{user_name}},\n\nYour withdrawal request of {{amount}} {{currency}} is being processed.', true),
('withdrawal_approved', 'Withdrawal Approved', 'Withdrawal approved', 'Hi {{user_name}},\n\nYour withdrawal of {{amount}} {{currency}} has been approved.', true),
('withdrawal_rejected', 'Withdrawal Rejected', 'Withdrawal rejected', 'Hi {{user_name}},\n\nYour withdrawal of {{amount}} {{currency}} was rejected. Contact: {{support_email}}', true),
('account_banned', 'Account Banned', 'Account suspended', 'Hi {{user_name}},\n\nYour account has been suspended. Contact: {{support_email}}', true),
('account_unbanned', 'Account Unbanned', 'Account reinstated', 'Hi {{user_name}},\n\nYour account has been reinstated. Welcome back!', true),
('login_alert', 'Login Alert', 'New login to your account', 'Hi {{user_name}},\n\nA new login was detected on your account at {{date}}.', true),
('general_notification', 'General Notification', '{{status}}', 'Hi {{user_name}},\n\n{{status}}\n\n— {{site_name}}', true)
ON CONFLICT (key) DO NOTHING;