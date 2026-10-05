-- M30 W0-3.3: FK cascades for account deletion
-- Fixes S1: Ensures proper cleanup when a user is deleted via auth.deleteUser()

-- Modify existing foreign keys to cascade on delete
alter table if exists player_saves
drop constraint if exists player_saves_user_id_fkey;

alter table if exists player_saves
add constraint player_saves_user_id_fkey
foreign key (user_id) references auth.users(id) on delete cascade;

alter table if exists player_entitlements
drop constraint if exists player_entitlements_user_id_fkey;

alter table if exists player_entitlements
add constraint player_entitlements_user_id_fkey
foreign key (user_id) references auth.users(id) on delete cascade;
