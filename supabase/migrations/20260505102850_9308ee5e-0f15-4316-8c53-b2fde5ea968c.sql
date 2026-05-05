CREATE OR REPLACE FUNCTION public.handle_new_user()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE m RECORD;
BEGIN
  INSERT INTO public.profiles (id, email, full_name, email_verified)
  VALUES (NEW.id, NEW.email, COALESCE(NEW.raw_user_meta_data->>'full_name', ''), NEW.email_confirmed_at IS NOT NULL)
  ON CONFLICT (id) DO NOTHING;
  IF NEW.email = 'support@haratrading.com' THEN
    INSERT INTO public.user_roles (user_id, role) VALUES (NEW.id, 'admin') ON CONFLICT DO NOTHING;
  ELSE
    INSERT INTO public.user_roles (user_id, role) VALUES (NEW.id, 'user') ON CONFLICT DO NOTHING;
  END IF;
  FOR m IN SELECT symbol FROM public.market_assets WHERE active = true LOOP
    INSERT INTO public.wallet_balances (user_id, coin, available, staked)
    VALUES (NEW.id, m.symbol, 0, 0) ON CONFLICT (user_id, coin) DO NOTHING;
  END LOOP;
  INSERT INTO public.fiat_balances (user_id, currency, available)
  VALUES (NEW.id, 'USD', 0) ON CONFLICT DO NOTHING;
  RETURN NEW;
END; $function$;