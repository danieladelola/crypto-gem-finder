-- Extend profiles
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS username TEXT UNIQUE,
  ADD COLUMN IF NOT EXISTS two_factor_enabled BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS country_code TEXT,
  ADD COLUMN IF NOT EXISTS banned_reason TEXT,
  ADD COLUMN IF NOT EXISTS first_name TEXT,
  ADD COLUMN IF NOT EXISTS last_name TEXT;

CREATE INDEX IF NOT EXISTS profiles_username_lower_idx ON public.profiles (lower(username));

-- Add 'unverified' kyc_status value (Postgres requires committing before using)
ALTER TYPE public.kyc_status ADD VALUE IF NOT EXISTS 'unverified';

-- Notifications: segment + audience size
ALTER TABLE public.notifications
  ADD COLUMN IF NOT EXISTS segment TEXT,
  ADD COLUMN IF NOT EXISTS audience_count INT;

-- Impersonation log
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

CREATE POLICY imp_admin_all ON public.impersonation_log
  FOR ALL TO authenticated
  USING (public.has_role(auth.uid(), 'admin'))
  WITH CHECK (public.has_role(auth.uid(), 'admin'));

CREATE POLICY imp_target_select_own ON public.impersonation_log
  FOR SELECT TO authenticated
  USING (auth.uid() = target_user_id);

-- Username claim: returns true if claimed, false if already taken
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

-- Email-or-username -> email lookup (callable by anon for login)
CREATE OR REPLACE FUNCTION public.lookup_email_for_login(_identifier TEXT)
RETURNS TEXT LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE found TEXT;
BEGIN
  IF _identifier IS NULL OR length(_identifier) = 0 THEN RETURN NULL; END IF;
  IF _identifier LIKE '%@%' THEN
    RETURN _identifier;
  END IF;
  SELECT email INTO found FROM public.profiles WHERE lower(username) = lower(_identifier) LIMIT 1;
  RETURN found;
END; $$;

GRANT EXECUTE ON FUNCTION public.lookup_email_for_login(TEXT) TO anon, authenticated;

-- Bulk send notification to a segment (admin only)
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
    WHERE
      CASE _segment
        WHEN 'all' THEN true
        WHEN 'active' THEN p.banned = false
        WHEN 'banned' THEN p.banned = true
        WHEN 'email_unverified' THEN p.email_verified = false
        WHEN 'mobile_unverified' THEN p.mobile_verified = false
        WHEN 'kyc_unverified' THEN p.kyc_status IN ('none','unverified')
        WHEN 'kyc_pending' THEN p.kyc_status = 'pending'
        WHEN 'with_balance' THEN EXISTS (
          SELECT 1 FROM public.wallet_balances w WHERE w.user_id = p.id AND (w.available > 0 OR w.staked > 0)
        ) OR EXISTS (
          SELECT 1 FROM public.fiat_balances f WHERE f.user_id = p.id AND f.available > 0
        )
        ELSE false
      END
  ), ins AS (
    INSERT INTO public.notifications (user_id, title, body, segment)
    SELECT id, _title, _body, _segment FROM audience
    RETURNING 1
  )
  SELECT count(*) INTO inserted_count FROM ins;

  RETURN inserted_count;
END; $$;