-- M30 (deferred): stop clients writing their own entitlements.
-- !! DO NOT APPLY YET. The shipped client still upserts player_entitlements
-- !! (EntitlementManager._sync_to_cloud_if_signed_in). Apply only after a
-- !! server-side grant path (purchase verification Edge Function writing
-- !! entitlement_grants / player_entitlements with the service role) ships
-- !! and the client stops writing (planned for MP-0).
-- Idempotent: safe to re-run.

drop policy if exists "Users can insert their own entitlements" on public.player_entitlements;
drop policy if exists "Users can update their own entitlements" on public.player_entitlements;
revoke insert, update, delete on public.player_entitlements from anon, authenticated;
