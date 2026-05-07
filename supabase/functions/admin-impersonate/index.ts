import { createClient } from "https://esm.sh/@supabase/supabase-js@2.57.4";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-supabase-client-platform, x-supabase-client-platform-version, x-supabase-client-runtime, x-supabase-client-runtime-version",
};

type ReturnPayload = {
  admin_id: string;
  admin_email: string;
  target_user_id: string;
  target_email: string;
  log_id: string;
  exp: number;
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: corsHeaders });

  try {
    if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

    const authHeader = req.headers.get("Authorization");
    if (!authHeader?.startsWith("Bearer ")) {
      return json({ error: "Unauthorized. Please sign in again." }, 401);
    }

    const SUPABASE_URL = requiredEnv("SUPABASE_URL");
    const ANON = Deno.env.get("SUPABASE_ANON_KEY") ?? requiredEnv("SUPABASE_PUBLISHABLE_KEY");
    const SERVICE = requiredEnv("SUPABASE_SERVICE_ROLE_KEY");

    const userClient = createClient(SUPABASE_URL, ANON, {
      global: { headers: { Authorization: authHeader } },
    });
    const token = authHeader.replace("Bearer ", "");
    const { data: claims, error: cErr } = await userClient.auth.getClaims(token);
    if (cErr || !claims?.claims?.sub) return json({ error: "Unauthorized. Please sign in again." }, 401);

    const callerId = claims.claims.sub as string;
    const callerEmail = (claims.claims as any).email as string | undefined;
    const admin = createClient(SUPABASE_URL, SERVICE);

    const body = await req.json().catch(() => ({}));
    const action = body.action as string;
    const targetUserId = body.target_user_id as string | undefined;
    const redirectTo = safeRedirectTo(body.redirect_to, req.headers.get("origin"));

    if (action === "end_impersonation") {
      return endImpersonation(admin, SERVICE, callerId, body, redirectTo);
    }

    if (!targetUserId) return json({ error: "Target user is required." }, 400);

    const isAdmin = await callerIsAdmin(admin, callerId);
    if (!isAdmin) return json({ error: "Only admins can use this action." }, 403);

    const { data: target, error: tErr } = await admin.auth.admin.getUserById(targetUserId);
    if (tErr || !target?.user?.email) return json({ error: "Target user was not found." }, 404);
    const targetEmail = target.user.email;

    if (action === "confirm_email") {
      const { error: updateErr } = await admin.auth.admin.updateUserById(targetUserId, { email_confirm: true });
      if (updateErr) return json({ error: updateErr.message }, 400);
      await admin.from("profiles").update({ email_verified: true }).eq("id", targetUserId);
      return json({ ok: true });
    }

    if (action === "impersonate") {
      if (targetUserId === callerId) return json({ error: "You are already signed in as this user." }, 400);
      if (!callerEmail) return json({ error: "Admin email is unavailable. Please sign in again." }, 401);

      const { data: log, error: logErr } = await admin
        .from("impersonation_log")
        .insert({
          admin_id: callerId,
          admin_email: callerEmail,
          target_user_id: targetUserId,
          target_email: targetEmail,
          ip: req.headers.get("x-forwarded-for") ?? null,
          user_agent: req.headers.get("user-agent") ?? null,
        })
        .select("id")
        .single();
      if (logErr || !log?.id) return json({ error: logErr?.message ?? "Could not create impersonation log." }, 400);

      const { data: link, error: linkErr } = await admin.auth.admin.generateLink({
        type: "magiclink",
        email: targetEmail,
        options: { redirectTo },
      });
      const tokenHash = link?.properties?.hashed_token;
      if (linkErr || !tokenHash) return json({ error: linkErr?.message ?? "Could not create impersonation session." }, 400);

      const returnToken = await signReturnToken(SERVICE, {
        admin_id: callerId,
        admin_email: callerEmail,
        target_user_id: targetUserId,
        target_email: targetEmail,
        log_id: log.id,
        exp: Math.floor(Date.now() / 1000) + 60 * 60,
      });

      return json({
        ok: true,
        token_hash: tokenHash,
        verification_type: "magiclink",
        email: targetEmail,
        target_user_id: targetUserId,
        admin_id: callerId,
        log_id: log.id,
        return_token: returnToken,
        redirect_to: redirectTo,
      });
    }

    return json({ error: "Unknown action." }, 400);
  } catch (e) {
    return json({ error: String((e as Error).message ?? e) }, 500);
  }
});

async function endImpersonation(admin: any, secret: string, callerId: string, body: any, redirectTo: string) {
  const returnToken = body.return_token as string | undefined;
  const logId = body.log_id as string | undefined;
  if (!returnToken || !logId) return json({ error: "Missing impersonation return state." }, 400);

  const payload = await verifyReturnToken(secret, returnToken);
  if (!payload) return json({ error: "Impersonation return state is invalid or expired." }, 401);
  if (payload.log_id !== logId) return json({ error: "Impersonation return state does not match this session." }, 401);
  if (payload.target_user_id !== callerId) return json({ error: "Current session does not match the impersonated user." }, 403);

  const { data: log, error: logErr } = await admin
    .from("impersonation_log")
    .select("id,admin_id,target_user_id,ended_at")
    .eq("id", payload.log_id)
    .maybeSingle();
  if (logErr || !log) return json({ error: "Impersonation log was not found." }, 404);
  if (log.admin_id !== payload.admin_id || log.target_user_id !== payload.target_user_id) {
    return json({ error: "Impersonation log does not match this session." }, 403);
  }

  const { data: link, error: linkErr } = await admin.auth.admin.generateLink({
    type: "magiclink",
    email: payload.admin_email,
    options: { redirectTo },
  });
  const tokenHash = link?.properties?.hashed_token;
  if (linkErr || !tokenHash) return json({ error: linkErr?.message ?? "Could not restore admin session." }, 400);

  if (!log.ended_at) {
    await admin.from("impersonation_log").update({ ended_at: new Date().toISOString() }).eq("id", payload.log_id);
  }

  return json({
    ok: true,
    token_hash: tokenHash,
    verification_type: "magiclink",
    admin_id: payload.admin_id,
    redirect_to: redirectTo,
  });
}

async function callerIsAdmin(admin: any, userId: string) {
  const { data } = await admin
    .from("user_roles")
    .select("role")
    .eq("user_id", userId)
    .eq("role", "admin")
    .maybeSingle();
  return !!data;
}

function requiredEnv(name: string) {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`${name} is not configured`);
  return value;
}

function safeRedirectTo(input: unknown, fallbackOrigin: string | null) {
  const origin = typeof input === "string" ? input : fallbackOrigin;
  if (!origin) throw new Error("Browser origin is required for impersonation.");
  const url = new URL(origin);
  if (!["http:", "https:"].includes(url.protocol)) throw new Error("Invalid redirect origin.");
  return `${url.origin}${url.pathname === "/" ? "/app" : url.pathname}`;
}

async function signReturnToken(secret: string, payload: ReturnPayload) {
  const body = base64UrlEncode(JSON.stringify(payload));
  const signature = await hmac(secret, body);
  return `${body}.${signature}`;
}

async function verifyReturnToken(secret: string, token: string): Promise<ReturnPayload | null> {
  const [body, signature] = token.split(".");
  if (!body || !signature) return null;
  const expected = await hmac(secret, body);
  if (!timingSafeEqual(signature, expected)) return null;
  const payload = JSON.parse(base64UrlDecode(body)) as ReturnPayload;
  if (!payload.exp || payload.exp < Math.floor(Date.now() / 1000)) return null;
  return payload;
}

async function hmac(secret: string, data: string) {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(data));
  return base64UrlEncode(new Uint8Array(sig));
}

function base64UrlEncode(input: string | Uint8Array) {
  const bytes = typeof input === "string" ? new TextEncoder().encode(input) : input;
  let binary = "";
  bytes.forEach((b) => (binary += String.fromCharCode(b)));
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}

function base64UrlDecode(input: string) {
  const base64 = input.replace(/-/g, "+").replace(/_/g, "/").padEnd(Math.ceil(input.length / 4) * 4, "=");
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return new TextDecoder().decode(bytes);
}

function timingSafeEqual(a: string, b: string) {
  if (a.length !== b.length) return false;
  let result = 0;
  for (let i = 0; i < a.length; i++) result |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return result === 0;
}

function json(b: unknown, status = 200) {
  return new Response(JSON.stringify(b), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
