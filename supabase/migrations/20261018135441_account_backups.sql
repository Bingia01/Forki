BEGIN;
CREATE TABLE IF NOT EXISTS public.forki_backups (
    user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    profile jsonb NOT NULL CHECK (jsonb_typeof(profile) = 'object'),
    meals jsonb NOT NULL CHECK (jsonb_typeof(meals) = 'array'),
    calorie_goal integer NOT NULL CHECK (calorie_goal BETWEEN 1000 AND 4000),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT backup_size CHECK (octet_length(profile::text) + octet_length(meals::text) <= 10000000)
);
ALTER TABLE public.forki_backups ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.forki_backups FROM PUBLIC, anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.forki_backups TO authenticated;
CREATE POLICY own_backup_select ON public.forki_backups FOR SELECT TO authenticated USING ((SELECT auth.uid()) = user_id);
CREATE POLICY own_backup_insert ON public.forki_backups FOR INSERT TO authenticated WITH CHECK ((SELECT auth.uid()) = user_id);
CREATE POLICY own_backup_update ON public.forki_backups FOR UPDATE TO authenticated USING ((SELECT auth.uid()) = user_id) WITH CHECK ((SELECT auth.uid()) = user_id);
CREATE POLICY own_backup_delete ON public.forki_backups FOR DELETE TO authenticated USING ((SELECT auth.uid()) = user_id);
COMMIT;
