BEGIN;

CREATE OR REPLACE FUNCTION public.calculate_user_progress(target_user_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
    daily_calories numeric := 0;
    weekly_calories numeric := 0;
    daily_goal integer;
    weekly_goal integer;
BEGIN
    -- Check the verified request identity, never current_user (the definer).
    IF COALESCE(auth.role(), '') <> 'service_role' AND
       (auth.uid() IS NULL OR target_user_id IS DISTINCT FROM auth.uid()) THEN
        RAISE EXCEPTION 'Not authorized' USING ERRCODE = '42501';
    END IF;
    IF target_user_id IS NULL THEN
        RAISE EXCEPTION 'A user is required' USING ERRCODE = '22023';
    END IF;
    SELECT daily_calorie_goal, weekly_calorie_goal INTO daily_goal, weekly_goal
      FROM public.user_preferences WHERE user_id = target_user_id;
    -- Do not manufacture progress if onboarding has not set usable goals.
    IF daily_goal IS NULL OR weekly_goal IS NULL OR daily_goal <= 0 OR weekly_goal <= 0 THEN RETURN; END IF;
    SELECT COALESCE(sum(calories), 0) INTO daily_calories
      FROM public.food_logs WHERE user_id = target_user_id
        AND logged_at >= CURRENT_DATE AND logged_at < CURRENT_DATE + INTERVAL '1 day';
    SELECT COALESCE(sum(calories), 0) INTO weekly_calories
      FROM public.food_logs WHERE user_id = target_user_id
        AND logged_at >= CURRENT_DATE - INTERVAL '6 days'
        AND logged_at < CURRENT_DATE + INTERVAL '1 day';
    INSERT INTO public.user_progress(user_id, daily_progress, weekly_progress, last_updated)
      VALUES (target_user_id, LEAST(100.0, daily_calories / daily_goal * 100),
              LEAST(100.0, weekly_calories / weekly_goal * 100), now())
      ON CONFLICT (user_id) DO UPDATE SET daily_progress = EXCLUDED.daily_progress,
        weekly_progress = EXCLUDED.weekly_progress, last_updated = EXCLUDED.last_updated;
END;
$$;

CREATE OR REPLACE FUNCTION public.trigger_update_progress()
RETURNS trigger LANGUAGE plpgsql SET search_path = '' AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        PERFORM public.calculate_user_progress(OLD.user_id);
        RETURN OLD;
    END IF;
    IF TG_OP = 'UPDATE' AND OLD.user_id IS DISTINCT FROM NEW.user_id THEN
        PERFORM public.calculate_user_progress(OLD.user_id);
    END IF;
    PERFORM public.calculate_user_progress(NEW.user_id);
    RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.calculate_user_progress(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.calculate_user_progress(uuid) TO authenticated, service_role;

-- Account existence is an administrative query, not a public login API.
-- Trigger functions are executed by their attached triggers, not via RPC.
DO $$
DECLARE fn regprocedure;
BEGIN
    FOR fn IN SELECT p.oid::regprocedure FROM pg_catalog.pg_proc p
      JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
      WHERE n.nspname = 'public' AND p.proname IN
        ('check_user_exists_in_auth', 'handle_new_user', 'set_meal_log_user_id',
         'handle_updated_at', 'update_updated_at_column', 'trigger_update_progress')
    LOOP
        EXECUTE format('ALTER FUNCTION %s SET search_path = %L', fn, '');
        EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC, anon, authenticated', fn);
    END LOOP;
END;
$$;
COMMIT;
