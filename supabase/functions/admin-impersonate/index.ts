import { createClient } from "https://esm.sh/@supabase/supabase-js@2.57.4";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: corsHeaders });

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader?.startsWith("Bearer ")) {
      return json({ error: "Unauthorized" }, 401);
    }

    const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
    const ANON = Deno.env.get("SUPABASE_ANON_KEY") ?? Deno.env.get("SUPABASE_PUBLISHABLE_KEY")!;
    const SERVICE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    const userClient = createClient(SUPABASE_URL, ANON, {
      global: { headers: { Authorization: authHeader } },
    });
    const token = authHeader.replace("Bearer ", "");
    const { data: claims, error: cErr } = await userClient.auth.getClaims(token);
    if (cErr || !claims?.claims?.sub) return json({ error: "Unauthorized" }, 401);

    const adminId = claims.claims.sub as string;
    const adminEmail = (claims.claims as any).email as string | undefined;

    const admin = createClient(SUPABASE_URL, SERVICE);

    // Verify caller is admin
    const { data: roleRow } = await admin
      .from("user_roles").select("role").eq("user_id", adminId).eq("role", "admin").maybeSingle();
    if (!roleRow) return json({ error: "Forbidden" }, 403);

    const body = await req.json().catch(() => ({}));
    const action = body.action as string;
    const targetUserId = body.target_user_id as string | undefined;

    if (!targetUserId) return json({ error: "target_user_id required" }, 400);

    // Fetch target email
    const { data: target, error: tErr } = await admin.auth.admin.getUserById(targetUserId);
    if (tErr || !target?.user?.email) return json({ error: "Target not found" }, 404);
    const targetEmail = target.user.email;

    if (action === "confirm_email") {
      await admin.auth.admin.updateUserById(targetUserId, { email_confirm: true });
      await admin.from("profiles").update({ email_verified: true }).eq("id", targetUserId);
      return json({ ok: true });
    }

    if (action === "impersonate") {
      // Generate magic link
      const { data: link, error: lErr } = await admin.auth.admin.generateLink({
        type: "magiclink",
        email: targetEmail,
      });
      if (lErr || !link?.properties?.action_link) {
        return json({ error: lErr?.message || "Failed to generate link" }, 500);
      }

      // Log
      await admin.from("impersonation_log").insert({
        admin_id: adminId,
        admin_email: adminEmail ?? null,
        target_user_id: targetUserId,
        target_email: targetEmail,
        ip: req.headers.get("x-forwarded-for") ?? null,
        user_agent: req.headers.get("user-agent") ?? null,
      });

      return json({ ok: true, action_link: link.properties.action_link });
    }

    return json({ error: "Unknown action" }, 400);
  } catch (e) {
    return json({ error: String((e as Error).message ?? e) }, 500);
  }
});

function json(b: unknown, status = 200) {
  return new Response(JSON.stringify(b), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
