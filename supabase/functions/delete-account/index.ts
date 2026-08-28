// Pirate Empire — M15 account deletion Edge Function
//
// The only place this milestone uses the service_role key. It is read from this function's
// Supabase-managed environment (auto-injected as SUPABASE_SERVICE_ROLE_KEY for every deployed
// Edge Function) — never passed in from the client, never committed anywhere.
//
// Deployed with default JWT verification ON (do not pass --no-verify-jwt / disable "Verify JWT
// with legacy secret" in the dashboard) so Supabase itself rejects requests with no/invalid
// Authorization header before this code ever runs — Requirement 8.3's "reachable and rejects
// requests with no/invalid Authorization header" check covers both that platform-level rejection
// and this function's own getUser() check below.
//
// Source of truth: .kiro/specs/milestone-m15-backend-cloud-services/design.md, Requirement 8.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { "Content-Type": "application/json" },
    });
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return new Response(JSON.stringify({ error: "Missing Authorization header" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

  // Scoped to the caller's own token — used only to verify who they are. The function never
  // trusts a client-supplied user id; the id always comes from this verified token.
  const callerClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });

  const { data: userData, error: userError } = await callerClient.auth.getUser();
  if (userError || !userData?.user) {
    return new Response(JSON.stringify({ error: "Invalid or expired session" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  const userId = userData.user.id;

  // Privileged client for the actual deletion — service_role bypasses RLS by design, which is
  // why player_saves has no delete policy of its own (see supabase/schema.sql).
  const adminClient = createClient(supabaseUrl, serviceRoleKey);

  const { error: deleteSaveError } = await adminClient
    .from("player_saves")
    .delete()
    .eq("user_id", userId);
  if (deleteSaveError) {
    return new Response(JSON.stringify({ error: "Failed to delete save data" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  const { error: deleteUserError } = await adminClient.auth.admin.deleteUser(userId);
  if (deleteUserError) {
    return new Response(JSON.stringify({ error: "Failed to delete account" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  return new Response(JSON.stringify({ success: true }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});
