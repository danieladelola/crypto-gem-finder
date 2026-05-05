import { useEffect, useState } from "react";
import { useAuth } from "@/hooks/useAuth";
import { Button } from "@/components/ui/button";
import { ArrowLeft } from "lucide-react";
import { useNavigate } from "react-router-dom";
import { supabase } from "@/integrations/supabase/client";

export function ImpersonationBanner() {
  const { user } = useAuth();
  const nav = useNavigate();
  const [active, setActive] = useState(false);

  useEffect(() => {
    if (!user) return setActive(false);
    setActive(sessionStorage.getItem("impersonation_target_email") === user.email);
  }, [user]);

  if (!active) return null;

  async function exit() {
    sessionStorage.removeItem("impersonation_target_email");
    sessionStorage.removeItem("impersonation_admin_id");
    await supabase.auth.signOut();
    nav("/admin/login", { replace: true });
  }

  return (
    <div className="bg-amber-500 text-amber-950 px-4 py-2 flex flex-col sm:flex-row items-center justify-between gap-2 text-sm font-medium sticky top-0 z-50">
      <span>⚠️ You are viewing this account as admin (impersonating {user?.email}).</span>
      <Button size="sm" variant="outline" className="bg-white/20 border-amber-900/30 hover:bg-white/30" onClick={exit}>
        <ArrowLeft className="h-4 w-4 mr-1" /> Return to admin panel
      </Button>
    </div>
  );
}
