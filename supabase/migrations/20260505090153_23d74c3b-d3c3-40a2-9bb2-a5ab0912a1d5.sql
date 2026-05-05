
-- Email settings (single row, admin-only access)
CREATE TABLE IF NOT EXISTS public.email_settings (
  id INT PRIMARY KEY DEFAULT 1,
  enabled BOOLEAN NOT NULL DEFAULT false,
  mail_driver TEXT NOT NULL DEFAULT 'smtp',
  smtp_host TEXT,
  smtp_port INT DEFAULT 587,
  smtp_user TEXT,
  smtp_pass TEXT,
  smtp_encryption TEXT NOT NULL DEFAULT 'tls',
  from_email TEXT,
  from_name TEXT,
  reply_to TEXT,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT email_settings_singleton CHECK (id = 1)
);
INSERT INTO public.email_settings (id) VALUES (1) ON CONFLICT DO NOTHING;
ALTER TABLE public.email_settings ENABLE ROW LEVEL SECURITY;
CREATE POLICY es_admin_all ON public.email_settings FOR ALL TO authenticated
  USING (public.has_role(auth.uid(), 'admin')) WITH CHECK (public.has_role(auth.uid(), 'admin'));

-- Email templates
CREATE TABLE IF NOT EXISTS public.email_templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  key TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  subject TEXT NOT NULL,
  body TEXT NOT NULL,
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

-- Email logs
CREATE TABLE IF NOT EXISTS public.email_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  recipient TEXT NOT NULL,
  subject TEXT,
  template_key TEXT,
  status TEXT NOT NULL,
  error TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.email_logs ENABLE ROW LEVEL SECURITY;
CREATE POLICY el_admin_all ON public.email_logs FOR ALL TO authenticated
  USING (public.has_role(auth.uid(), 'admin')) WITH CHECK (public.has_role(auth.uid(), 'admin'));

CREATE INDEX IF NOT EXISTS idx_email_logs_created ON public.email_logs (created_at DESC);

-- Seed default templates
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
