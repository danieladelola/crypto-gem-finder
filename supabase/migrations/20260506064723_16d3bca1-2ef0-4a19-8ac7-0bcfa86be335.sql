CREATE OR REPLACE FUNCTION public.handle_stake_insert()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE bal NUMERIC(28,8);
BEGIN
  -- Skip balance check during migrations
  IF current_setting('app.skip_stake_check', true) = 'on' THEN
    RETURN NEW;
  END IF;
  IF NEW.is_usd THEN
    SELECT available INTO bal FROM public.fiat_balances WHERE user_id = NEW.user_id AND currency = 'USD' FOR UPDATE;
    IF bal IS NULL OR bal < NEW.amount THEN RAISE EXCEPTION 'Insufficient USD balance to stake'; END IF;
    UPDATE public.fiat_balances SET available = available - NEW.amount WHERE user_id = NEW.user_id AND currency = 'USD';
    INSERT INTO public.transaction_history (user_id, type, coin, amount, ref_id, status, description)
    VALUES (NEW.user_id, 'stake', 'USD', NEW.amount, NEW.id, 'completed', 'USD stake created');
  ELSE
    SELECT available INTO bal FROM public.wallet_balances WHERE user_id = NEW.user_id AND coin = NEW.coin FOR UPDATE;
    IF bal IS NULL OR bal < NEW.amount THEN RAISE EXCEPTION 'Insufficient balance to stake'; END IF;
    UPDATE public.wallet_balances SET available = available - NEW.amount, staked = staked + NEW.amount WHERE user_id = NEW.user_id AND coin = NEW.coin;
    INSERT INTO public.transaction_history (user_id, type, coin, amount, ref_id, status, description)
    VALUES (NEW.user_id, 'stake', NEW.coin, NEW.amount, NEW.id, 'completed', 'Stake created');
  END IF;
  RETURN NEW;
END; $function$;