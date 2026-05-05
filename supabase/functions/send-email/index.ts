// Send email via configured SMTP. Admin-only, plus internal callers.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.57.4";
import { SMTPClient } from "https://deno.land/x/denomailer@1.6.0/mod.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...corsHeaders },
  });
}

function render(tpl: string, vars: Record<string, string>) {
  return tpl.replace(/\{\{\s*(\w+)\s*\}\}/g, (_, k) => (vars[k] ?? ""));
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: corsHeaders });

  try {
    const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
    const SERVICE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const ANON = Deno.env.get("SUPABASE_ANON_KEY") ?? Deno.env.get("SUPABASE_PUBLISHABLE_KEY")!;
    const admin = createClient(SUPABASE_URL, SERVICE);

    // Admin auth check (skip when invoked with service role from another function)
    const authHeader = req.headers.get("Authorization") ?? "";
    const isService = authHeader.includes(SERVICE);
    if (!isService) {
      if (!authHeader.startsWith("Bearer ")) return json({ error: "Unauthorized" }, 401);
      const userClient = createClient(SUPABASE_URL, ANON, {
        global: { headers: { Authorization: authHeader } },
      });
      const token = authHeader.replace("Bearer ", "");
      const { data: claims, error: cErr } = await userClient.auth.getClaims(token);
      if (cErr || !claims?.claims?.sub) return json({ error: "Unauthorized" }, 401);
      const uid = claims.claims.sub as string;
      const { data: roleRow } = await admin
        .from("user_roles").select("role").eq("user_id", uid).eq("role", "admin").maybeSingle();
      if (!roleRow) return json({ error: "Forbidden" }, 403);
    }

    const body = await req.json().catch(() => ({}));
    const action = (body.action as string) ?? "send";

    // Load SMTP settings
    const { data: settings } = await admin.from("email_settings").select("*").eq("id", 1).maybeSingle();
    if (!settings) return json({ error: "SMTP not configured" }, 400);

    if (action === "test") {
      const to = body.to as string;
      if (!to) return json({ error: "Recipient required" }, 400);
      const result = await sendMail(settings, {
        to,
        subject: "Test Email from " + (settings.from_name ?? "Admin"),
        body: "This is a test email confirming your SMTP settings work.",
      });
      await admin.from("email_logs").insert({
        recipient: to, subject: "Test Email", template_key: "test",
        status: result.ok ? "sent" : "failed", error: result.error ?? null,
      });
      return json(result, result.ok ? 200 : 500);
    }

    // Standard send: { to, template_key, vars: {...}, subject?, body? }
    const to = body.to as string;
    const templateKey = body.template_key as string | undefined;
    const vars = (body.vars as Record<string, string>) ?? {};
    if (!to) return json({ error: "Recipient required" }, 400);

    // Load site_name & support_email defaults from system_settings
    const { data: ss } = await admin.from("system_settings")
      .select("key,value").in("key", ["general", "platform_name", "support_email"]);
    const general = ss?.find((r) => r.key === "general")?.value as any ?? {};
    const siteName = general.site_name ?? (ss?.find((r) => r.key === "platform_name")?.value as string) ?? "Haratrading";
    const supportEmail = general.support_email ?? (ss?.find((r) => r.key === "support_email")?.value as string) ?? "";
    vars.site_name ??= siteName;
    vars.support_email ??= supportEmail;
    vars.date ??= new Date().toISOString();

    let subject = body.subject as string | undefined;
    let content = body.body as string | undefined;

    if (templateKey) {
      const { data: tpl } = await admin.from("email_templates")
        .select("*").eq("key", templateKey).maybeSingle();
      if (tpl && tpl.active) {
        subject = render(tpl.subject, vars);
        content = render(tpl.body, vars);
      }
    }
    if (!subject) subject = "Notification from " + siteName;
    if (!content) content = vars.message ?? "You have a new notification.";

    const result = await sendMail(settings, { to, subject, body: content });
    await admin.from("email_logs").insert({
      recipient: to, subject, template_key: templateKey ?? null,
      status: result.ok ? "sent" : "failed", error: result.error ?? null,
    });
    return json(result, result.ok ? 200 : 500);
  } catch (e) {
    return json({ error: (e as Error).message }, 500);
  }
});

async function sendMail(s: any, m: { to: string; subject: string; body: string }) {
  if (!s.enabled) return { ok: false, error: "SMTP is disabled" };
  if (!s.smtp_host || !s.from_email) return { ok: false, error: "SMTP host/from email missing" };
  try {
    const client = new SMTPClient({
      connection: {
        hostname: s.smtp_host,
        port: Number(s.smtp_port ?? 587),
        tls: s.smtp_encryption === "ssl" || s.smtp_encryption === "tls",
        auth: s.smtp_user ? { username: s.smtp_user, password: s.smtp_pass ?? "" } : undefined,
      },
    });
    await client.send({
      from: s.from_name ? `${s.from_name} <${s.from_email}>` : s.from_email,
      to: m.to,
      replyTo: s.reply_to ?? undefined,
      subject: m.subject,
      content: m.body,
      html: m.body.replace(/\n/g, "<br>"),
    });
    await client.close();
    return { ok: true };
  } catch (e) {
    return { ok: false, error: (e as Error).message };
  }
}
