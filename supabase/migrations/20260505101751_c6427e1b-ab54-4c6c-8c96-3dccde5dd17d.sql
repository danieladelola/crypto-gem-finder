CREATE OR REPLACE FUNCTION public.touch_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END; $$;

CREATE TRIGGER profiles_touch BEFORE UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();
CREATE TRIGGER wb_touch BEFORE UPDATE ON public.wallet_balances FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();
CREATE TRIGGER fb_touch BEFORE UPDATE ON public.fiat_balances FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();
CREATE TRIGGER staking_plans_touch BEFORE UPDATE ON public.staking_plans FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE m RECORD;
BEGIN
  INSERT INTO public.profiles (id, email, full_name, email_verified)
  VALUES (NEW.id, NEW.email, COALESCE(NEW.raw_user_meta_data->>'full_name', ''), NEW.email_confirmed_at IS NOT NULL)
  ON CONFLICT (id) DO NOTHING;
  IF NEW.email = 'admin@vura.pro' THEN
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
END; $$;
CREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

CREATE OR REPLACE FUNCTION public.handle_deposit_status_change()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE credit NUMERIC(28,8);
BEGIN
  IF NEW.status = 'approved' AND OLD.status <> 'approved' THEN
    credit := COALESCE(NEW.usd_credited, NEW.usd_amount, 0);
    IF credit > 0 THEN
      INSERT INTO public.fiat_balances (user_id, currency, available) VALUES (NEW.user_id, 'USD', credit)
      ON CONFLICT (user_id, currency) DO UPDATE SET available = public.fiat_balances.available + credit;
      NEW.usd_credited := credit;
      INSERT INTO public.transaction_history (user_id, type, coin, amount, ref_id, status, description)
      VALUES (NEW.user_id, 'deposit', 'USD', credit, NEW.id, 'approved', format('Deposit approved: %s USD funded via %s', credit, COALESCE(NEW.pay_coin, NEW.coin)));
    ELSE
      INSERT INTO public.wallet_balances (user_id, coin, available) VALUES (NEW.user_id, NEW.coin, NEW.amount)
      ON CONFLICT (user_id, coin) DO UPDATE SET available = public.wallet_balances.available + NEW.amount;
      INSERT INTO public.transaction_history (user_id, type, coin, amount, ref_id, status, description)
      VALUES (NEW.user_id, 'deposit', NEW.coin, NEW.amount, NEW.id, 'approved', 'Deposit approved');
    END IF;
    NEW.processed_at := now();
  ELSIF NEW.status = 'rejected' AND OLD.status <> 'rejected' THEN
    INSERT INTO public.transaction_history (user_id, type, coin, amount, ref_id, status, description)
    VALUES (NEW.user_id, 'deposit', COALESCE(NEW.pay_coin, NEW.coin), COALESCE(NEW.pay_amount, NEW.amount), NEW.id, 'rejected', 'Deposit rejected');
    NEW.processed_at := now();
  END IF;
  RETURN NEW;
END; $$;
CREATE TRIGGER deposits_status_change BEFORE UPDATE ON public.deposits FOR EACH ROW EXECUTE FUNCTION public.handle_deposit_status_change();

CREATE OR REPLACE FUNCTION public.handle_withdrawal_insert()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE bal NUMERIC(28,8); total_debit NUMERIC(28,8);
BEGIN
  IF NEW.usd_amount IS NOT NULL AND NEW.usd_amount > 0 THEN
    total_debit := NEW.usd_amount;
    SELECT available INTO bal FROM public.fiat_balances WHERE user_id = NEW.user_id AND currency = 'USD' FOR UPDATE;
    IF bal IS NULL OR bal < total_debit THEN RAISE EXCEPTION 'Insufficient USD balance'; END IF;
    UPDATE public.fiat_balances SET available = available - total_debit WHERE user_id = NEW.user_id AND currency = 'USD';
    INSERT INTO public.transaction_history (user_id, type, coin, amount, ref_id, status, description)
    VALUES (NEW.user_id, 'withdrawal', 'USD', total_debit, NEW.id, 'pending', format('Withdrawal requested: $%s -> %s %s', total_debit, NEW.payout_amount, NEW.payout_coin));
  ELSE
    total_debit := NEW.amount + COALESCE(NEW.fee, 0);
    SELECT available INTO bal FROM public.wallet_balances WHERE user_id = NEW.user_id AND coin = NEW.coin FOR UPDATE;
    IF bal IS NULL OR bal < total_debit THEN RAISE EXCEPTION 'Insufficient balance'; END IF;
    UPDATE public.wallet_balances SET available = available - total_debit WHERE user_id = NEW.user_id AND coin = NEW.coin;
    INSERT INTO public.transaction_history (user_id, type, coin, amount, ref_id, status, description)
    VALUES (NEW.user_id, 'withdrawal', NEW.coin, NEW.amount, NEW.id, 'pending', 'Withdrawal requested');
  END IF;
  RETURN NEW;
END; $$;
CREATE TRIGGER withdrawals_insert BEFORE INSERT ON public.withdrawals FOR EACH ROW EXECUTE FUNCTION public.handle_withdrawal_insert();

CREATE OR REPLACE FUNCTION public.handle_withdrawal_status_change()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NEW.status = 'rejected' AND OLD.status <> 'rejected' THEN
    IF OLD.usd_amount IS NOT NULL AND OLD.usd_amount > 0 THEN
      INSERT INTO public.fiat_balances (user_id, currency, available) VALUES (NEW.user_id, 'USD', OLD.usd_amount)
      ON CONFLICT (user_id, currency) DO UPDATE SET available = public.fiat_balances.available + OLD.usd_amount;
      INSERT INTO public.transaction_history (user_id, type, coin, amount, ref_id, status, description)
      VALUES (NEW.user_id, 'withdrawal', 'USD', OLD.usd_amount, NEW.id, 'rejected', 'Withdrawal rejected - USD refunded');
    ELSE
      UPDATE public.wallet_balances SET available = available + (OLD.amount + COALESCE(OLD.fee,0)) WHERE user_id = NEW.user_id AND coin = OLD.coin;
      INSERT INTO public.transaction_history (user_id, type, coin, amount, ref_id, status, description)
      VALUES (NEW.user_id, 'withdrawal', OLD.coin, OLD.amount, NEW.id, 'rejected', 'Withdrawal rejected, balance refunded');
    END IF;
    NEW.processed_at = now();
  ELSIF NEW.status = 'approved' AND OLD.status <> 'approved' THEN
    INSERT INTO public.transaction_history (user_id, type, coin, amount, ref_id, status, description)
    VALUES (NEW.user_id, 'withdrawal', COALESCE(NEW.payout_coin, NEW.coin), COALESCE(NEW.payout_amount, NEW.amount), NEW.id, 'approved', 'Withdrawal approved');
    NEW.processed_at = now();
  END IF;
  RETURN NEW;
END; $$;
CREATE TRIGGER withdrawals_status_change BEFORE UPDATE ON public.withdrawals FOR EACH ROW EXECUTE FUNCTION public.handle_withdrawal_status_change();

CREATE OR REPLACE FUNCTION public.handle_stake_insert()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE bal NUMERIC(28,8);
BEGIN
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
END; $$;
CREATE TRIGGER user_stakes_insert BEFORE INSERT ON public.user_stakes FOR EACH ROW EXECUTE FUNCTION public.handle_stake_insert();

CREATE OR REPLACE FUNCTION public.handle_stake_status_change()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE payout NUMERIC(28,8);
BEGIN
  IF NEW.status = 'completed' AND OLD.status = 'active' THEN
    payout := OLD.amount + COALESCE(NEW.reward_earned, 0);
    IF OLD.is_usd THEN
      INSERT INTO public.fiat_balances (user_id, currency, available) VALUES (NEW.user_id, 'USD', payout)
      ON CONFLICT (user_id, currency) DO UPDATE SET available = public.fiat_balances.available + payout;
      INSERT INTO public.transaction_history (user_id, type, coin, amount, ref_id, status, description)
      VALUES (NEW.user_id, 'stake_complete', 'USD', payout, NEW.id, 'completed', 'USD stake completed with reward');
    ELSE
      UPDATE public.wallet_balances SET staked = staked - OLD.amount, available = available + payout WHERE user_id = NEW.user_id AND coin = OLD.coin;
      INSERT INTO public.transaction_history (user_id, type, coin, amount, ref_id, status, description)
      VALUES (NEW.user_id, 'stake_complete', OLD.coin, payout, NEW.id, 'completed', 'Stake completed with reward');
    END IF;
  ELSIF NEW.status = 'cancelled' AND OLD.status = 'active' THEN
    IF OLD.is_usd THEN
      INSERT INTO public.fiat_balances (user_id, currency, available) VALUES (NEW.user_id, 'USD', OLD.amount)
      ON CONFLICT (user_id, currency) DO UPDATE SET available = public.fiat_balances.available + OLD.amount;
    ELSE
      UPDATE public.wallet_balances SET staked = staked - OLD.amount, available = available + OLD.amount WHERE user_id = NEW.user_id AND coin = OLD.coin;
    END IF;
    INSERT INTO public.transaction_history (user_id, type, coin, amount, ref_id, status, description)
    VALUES (NEW.user_id, 'stake_cancel', CASE WHEN OLD.is_usd THEN 'USD' ELSE OLD.coin END, OLD.amount, NEW.id, 'cancelled', 'Stake cancelled');
  END IF;
  RETURN NEW;
END; $$;
CREATE TRIGGER user_stakes_status_change BEFORE UPDATE ON public.user_stakes FOR EACH ROW EXECUTE FUNCTION public.handle_stake_status_change();

CREATE OR REPLACE FUNCTION public.handle_kyc_insert()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  UPDATE public.profiles SET kyc_status = 'pending' WHERE id = NEW.user_id;
  RETURN NEW;
END; $$;
CREATE TRIGGER kyc_insert AFTER INSERT ON public.kyc_records FOR EACH ROW EXECUTE FUNCTION public.handle_kyc_insert();

CREATE OR REPLACE FUNCTION public.handle_kyc_status_change()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NEW.status <> OLD.status THEN
    UPDATE public.profiles SET kyc_status = NEW.status WHERE id = NEW.user_id;
    NEW.reviewed_at := now();
    NEW.reviewed_by := auth.uid();
    INSERT INTO public.notifications (user_id, title, body)
    VALUES (NEW.user_id, 'KYC ' || NEW.status,
      CASE WHEN NEW.status = 'approved' THEN 'Your identity verification has been approved.'
           WHEN NEW.status = 'rejected' THEN COALESCE('KYC rejected: ' || NEW.admin_note, 'Your KYC submission was rejected.')
           ELSE 'Your KYC status has been updated.' END);
  END IF;
  RETURN NEW;
END; $$;
CREATE TRIGGER kyc_status_change BEFORE UPDATE ON public.kyc_records FOR EACH ROW EXECUTE FUNCTION public.handle_kyc_status_change();

CREATE OR REPLACE FUNCTION public.admin_adjust_balance(_target UUID, _asset TEXT, _delta NUMERIC, _reason TEXT DEFAULT NULL)
RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE adj_id UUID; cur NUMERIC(28,8);
BEGIN
  IF NOT public.has_role(auth.uid(), 'admin') THEN RAISE EXCEPTION 'Only admins can adjust balances'; END IF;
  IF _delta = 0 THEN RAISE EXCEPTION 'Delta cannot be zero'; END IF;
  IF upper(_asset) = 'USD' THEN
    INSERT INTO public.fiat_balances (user_id, currency, available) VALUES (_target, 'USD', GREATEST(_delta, 0))
    ON CONFLICT (user_id, currency) DO UPDATE SET available = public.fiat_balances.available + _delta;
    SELECT available INTO cur FROM public.fiat_balances WHERE user_id = _target AND currency = 'USD';
    IF cur < 0 THEN RAISE EXCEPTION 'Adjustment would result in negative USD balance'; END IF;
  ELSE
    INSERT INTO public.wallet_balances (user_id, coin, available, staked) VALUES (_target, upper(_asset), GREATEST(_delta, 0), 0)
    ON CONFLICT (user_id, coin) DO UPDATE SET available = public.wallet_balances.available + _delta;
    SELECT available INTO cur FROM public.wallet_balances WHERE user_id = _target AND coin = upper(_asset);
    IF cur < 0 THEN RAISE EXCEPTION 'Adjustment would result in negative balance'; END IF;
  END IF;
  INSERT INTO public.balance_adjustments (admin_id, user_id, asset, delta, reason)
  VALUES (auth.uid(), _target, upper(_asset), _delta, _reason) RETURNING id INTO adj_id;
  INSERT INTO public.transaction_history (user_id, type, coin, amount, ref_id, status, description)
  VALUES (_target, CASE WHEN _delta > 0 THEN 'admin_credit' ELSE 'admin_debit' END,
          upper(_asset), abs(_delta), adj_id, 'completed',
          COALESCE(_reason, format('Admin %s of %s %s', CASE WHEN _delta > 0 THEN 'credit' ELSE 'debit' END, abs(_delta), upper(_asset))));
  RETURN adj_id;
END; $$;

CREATE OR REPLACE FUNCTION public.record_login(_ip TEXT DEFAULT NULL, _ua TEXT DEFAULT NULL)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL THEN RETURN; END IF;
  INSERT INTO public.login_history (user_id, ip, user_agent) VALUES (auth.uid(), _ip, _ua);
END; $$;

CREATE OR REPLACE FUNCTION public.execute_exchange(_from_asset text, _to_asset text, _from_amount numeric, _rate numeric, _fee_pct numeric)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  uid UUID := auth.uid(); gross_to NUMERIC(28,8); fee_amt NUMERIC(28,8); net_to NUMERIC(28,8);
  kind TEXT; bal NUMERIC(28,8); tx_id UUID; ex_enabled BOOLEAN; prices JSONB;
  ref_from NUMERIC(28,8); ref_to NUMERIC(28,8); ref_rate NUMERIC(28,8); deviation NUMERIC(28,8); enforced_fee NUMERIC(28,8);
BEGIN
  IF uid IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  IF _from_asset = _to_asset THEN RAISE EXCEPTION 'Assets must differ'; END IF;
  IF _from_amount <= 0 THEN RAISE EXCEPTION 'Amount must be positive'; END IF;
  IF _rate <= 0 THEN RAISE EXCEPTION 'Invalid rate'; END IF;
  SELECT COALESCE((value->>'enabled')::boolean, true) INTO ex_enabled FROM public.system_settings WHERE key = 'exchange';
  IF ex_enabled IS FALSE THEN RAISE EXCEPTION 'Exchange is disabled'; END IF;
  SELECT COALESCE((value->>'fee_pct')::numeric, 0) INTO enforced_fee FROM public.system_settings WHERE key = 'exchange';
  enforced_fee := COALESCE(enforced_fee, _fee_pct);
  IF _from_asset <> 'USD' AND NOT EXISTS (SELECT 1 FROM public.market_assets WHERE symbol = _from_asset AND active = true)
    THEN RAISE EXCEPTION 'Asset % not available', _from_asset; END IF;
  IF _to_asset <> 'USD' AND NOT EXISTS (SELECT 1 FROM public.market_assets WHERE symbol = _to_asset AND active = true)
    THEN RAISE EXCEPTION 'Asset % not available', _to_asset; END IF;
  SELECT value INTO prices FROM public.system_settings WHERE key = 'last_prices';
  IF prices IS NOT NULL THEN
    ref_from := CASE WHEN _from_asset = 'USD' THEN 1 ELSE NULLIF((prices->>_from_asset)::numeric, 0) END;
    ref_to := CASE WHEN _to_asset = 'USD' THEN 1 ELSE NULLIF((prices->>_to_asset)::numeric, 0) END;
    IF ref_from IS NOT NULL AND ref_to IS NOT NULL AND ref_to > 0 THEN
      ref_rate := ref_from / ref_to;
      deviation := abs(_rate - ref_rate) / ref_rate;
      IF deviation > 0.05 THEN RAISE EXCEPTION 'Rate deviates from market reference (% vs %)', _rate, ref_rate; END IF;
    END IF;
  END IF;
  gross_to := _from_amount * _rate;
  fee_amt := gross_to * (enforced_fee / 100.0);
  net_to := gross_to - fee_amt;
  IF _from_asset = 'USD' AND _to_asset <> 'USD' THEN kind := 'buy';
  ELSIF _from_asset <> 'USD' AND _to_asset = 'USD' THEN kind := 'sell';
  ELSE kind := 'swap'; END IF;
  IF _from_asset = 'USD' THEN
    SELECT available INTO bal FROM public.fiat_balances WHERE user_id = uid AND currency = 'USD' FOR UPDATE;
    IF bal IS NULL OR bal < _from_amount THEN RAISE EXCEPTION 'Insufficient USD balance'; END IF;
    UPDATE public.fiat_balances SET available = available - _from_amount WHERE user_id = uid AND currency = 'USD';
  ELSE
    SELECT available INTO bal FROM public.wallet_balances WHERE user_id = uid AND coin = _from_asset FOR UPDATE;
    IF bal IS NULL OR bal < _from_amount THEN RAISE EXCEPTION 'Insufficient % balance', _from_asset; END IF;
    UPDATE public.wallet_balances SET available = available - _from_amount WHERE user_id = uid AND coin = _from_asset;
  END IF;
  IF _to_asset = 'USD' THEN
    INSERT INTO public.fiat_balances (user_id, currency, available) VALUES (uid, 'USD', net_to)
    ON CONFLICT (user_id, currency) DO UPDATE SET available = public.fiat_balances.available + net_to;
  ELSE
    INSERT INTO public.wallet_balances (user_id, coin, available, staked) VALUES (uid, _to_asset, net_to, 0)
    ON CONFLICT (user_id, coin) DO UPDATE SET available = public.wallet_balances.available + net_to;
  END IF;
  INSERT INTO public.exchange_transactions (user_id, kind, from_asset, to_asset, from_amount, to_amount, rate, fee_amount, fee_pct, status)
  VALUES (uid, kind, _from_asset, _to_asset, _from_amount, net_to, _rate, fee_amt, enforced_fee, 'completed') RETURNING id INTO tx_id;
  INSERT INTO public.transaction_history (user_id, type, coin, amount, ref_id, status, description)
  VALUES (uid, kind, _to_asset, net_to, tx_id, 'completed', format('%s %s -> %s %s', _from_amount, _from_asset, net_to, _to_asset));
  RETURN tx_id;
END; $$;

CREATE OR REPLACE FUNCTION public.update_price_cache(_prices JSONB)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL THEN RETURN; END IF;
  INSERT INTO public.system_settings (key, value) VALUES ('last_prices', _prices)
  ON CONFLICT (key) DO UPDATE SET value = _prices, updated_at = now();
END; $$;

INSERT INTO storage.buckets (id, name, public) VALUES ('avatars', 'avatars', true) ON CONFLICT (id) DO NOTHING;
INSERT INTO storage.buckets (id, name, public) VALUES ('kyc-docs', 'kyc-docs', false) ON CONFLICT (id) DO NOTHING;

CREATE POLICY "Avatar files publicly readable" ON storage.objects FOR SELECT USING (bucket_id = 'avatars' AND (storage.foldername(name))[1] IS NOT NULL);
CREATE POLICY "Users upload own avatar" ON storage.objects FOR INSERT TO authenticated WITH CHECK (bucket_id = 'avatars' AND auth.uid()::text = (storage.foldername(name))[1]);
CREATE POLICY "Users update own avatar" ON storage.objects FOR UPDATE TO authenticated USING (bucket_id = 'avatars' AND auth.uid()::text = (storage.foldername(name))[1]);
CREATE POLICY "Users delete own avatar" ON storage.objects FOR DELETE TO authenticated USING (bucket_id = 'avatars' AND auth.uid()::text = (storage.foldername(name))[1]);
CREATE POLICY kyc_user_upload ON storage.objects FOR INSERT TO authenticated WITH CHECK (bucket_id = 'kyc-docs' AND auth.uid()::text = (storage.foldername(name))[1]);
CREATE POLICY kyc_user_read_own ON storage.objects FOR SELECT TO authenticated USING (bucket_id = 'kyc-docs' AND auth.uid()::text = (storage.foldername(name))[1]);
CREATE POLICY kyc_user_update_own ON storage.objects FOR UPDATE TO authenticated USING (bucket_id = 'kyc-docs' AND auth.uid()::text = (storage.foldername(name))[1]);
CREATE POLICY kyc_admin_read_all ON storage.objects FOR SELECT TO authenticated USING (bucket_id = 'kyc-docs' AND public.has_role(auth.uid(), 'admin'));

INSERT INTO public.market_assets (symbol, name, coingecko_id, deposit_address, sort_order) VALUES
  ('BTC',  'Bitcoin',  'bitcoin',     'bc1qVuraDemoBitcoinAddress00000000000001', 1),
  ('ETH',  'Ethereum', 'ethereum',    '0xVuraDemoEthereumAddress0000000000000001', 2),
  ('USDT', 'Tether',   'tether',      '0xVuraDemoUSDTAddressERC2000000000000000', 3),
  ('SOL',  'Solana',   'solana',      'VuraDemoSolanaAddress00000000000000000001', 4),
  ('BNB',  'BNB',      'binancecoin', 'bnb1vurademoaddressbnbxxxxxxxxxxxxxxxx', 5),
  ('XRP',  'XRP',      'ripple',      'rVuraDemoXRPAddress00000000000000000001',  6);

INSERT INTO public.staking_plans (name, coin, apy, lock_days, min_amount, max_amount) VALUES
  ('Flexible BTC', 'BTC', 4.5, 30, 0.001, 1),
  ('30-Day ETH',   'ETH', 6.0, 30, 0.05, 50),
  ('90-Day USDT',  'USDT', 9.0, 90, 50, 100000);

INSERT INTO public.system_settings (key, value) VALUES
  ('platform_name',    '"Vura"'::jsonb),
  ('support_email',    '"support@vura.pro"'::jsonb),
  ('withdrawal_fee_pct', '0.5'::jsonb),
  ('min_withdrawal',   '10'::jsonb),
  ('kyc_required',     'false'::jsonb),
  ('exchange',         '{"enabled": true, "fee_pct": 0.5, "min_usd": 1, "max_usd": 100000}'::jsonb),
  ('deposit',          '{"enabled": true, "fee_pct": 0, "min_usd": 10, "max_usd": 100000}'::jsonb),
  ('last_prices',      '{}'::jsonb),
  ('deposit_addresses', jsonb_build_object(
    'BTC', jsonb_build_object('address', '', 'enabled', true,  'network', 'Bitcoin'),
    'ETH', jsonb_build_object('address', '', 'enabled', true,  'network', 'ERC-20'),
    'USDT',jsonb_build_object('address', '', 'enabled', true,  'network', 'TRC-20'),
    'USDC',jsonb_build_object('address', '', 'enabled', true,  'network', 'ERC-20'),
    'SOL', jsonb_build_object('address', '', 'enabled', true,  'network', 'Solana'),
    'TRX', jsonb_build_object('address', '', 'enabled', true,  'network', 'Tron'),
    'XRP', jsonb_build_object('address', '', 'enabled', true,  'network', 'XRP Ledger')
  ));
