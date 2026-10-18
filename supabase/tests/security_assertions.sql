CREATE TRIGGER food_progress AFTER INSERT OR UPDATE OR DELETE ON public.food_logs FOR EACH ROW EXECUTE FUNCTION public.trigger_update_progress();
INSERT INTO auth.users VALUES ('11111111-1111-1111-1111-111111111111','a@example.invalid','{"name":"A"}'),('22222222-2222-2222-2222-222222222222','b@example.invalid','{"name":"B"}');
INSERT INTO public.user_preferences VALUES ('11111111-1111-1111-1111-111111111111',2000,14000),('22222222-2222-2222-2222-222222222222',2000,14000);
DO $$ BEGIN
 IF has_function_privilege('anon','public.calculate_user_progress(uuid)','execute') THEN RAISE EXCEPTION 'Anonymous progress execution'; END IF;
 IF has_function_privilege('authenticated','public.check_user_exists_in_auth(text)','execute') THEN RAISE EXCEPTION 'Account enumeration'; END IF;
 IF (SELECT count(*) FROM public.users)<>2 THEN RAISE EXCEPTION 'Signup trigger broke'; END IF;
 IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname IN ('calculate_user_progress','trigger_update_progress','check_user_exists_in_auth','handle_new_user','set_meal_log_user_id','handle_updated_at','update_updated_at_column') AND p.proconfig IS NULL) THEN RAISE EXCEPTION 'Missing search_path'; END IF;
END $$;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.role','authenticated',false);
SELECT set_config('request.jwt.claim.sub','11111111-1111-1111-1111-111111111111',false);
DO $$ BEGIN
 BEGIN PERFORM public.calculate_user_progress('22222222-2222-2222-2222-222222222222'); RAISE EXCEPTION 'Cross-user access accepted'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.calculate_user_progress(NULL); RAISE EXCEPTION 'Null identity accepted'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
INSERT INTO public.food_logs(user_id,calories) VALUES ('11111111-1111-1111-1111-111111111111',500);
DO $$ BEGIN IF (SELECT daily_progress FROM public.user_progress WHERE user_id=auth.uid())<>25 THEN RAISE EXCEPTION 'Own-row insert trigger broke'; END IF; END $$;
UPDATE public.food_logs SET calories=1000 WHERE user_id=auth.uid();
DO $$ BEGIN IF (SELECT daily_progress FROM public.user_progress WHERE user_id=auth.uid())<>50 THEN RAISE EXCEPTION 'Own-row update trigger broke'; END IF; END $$;
DELETE FROM public.food_logs WHERE user_id=auth.uid();
DO $$ BEGIN IF (SELECT daily_progress FROM public.user_progress WHERE user_id=auth.uid())<>0 THEN RAISE EXCEPTION 'Own-row delete trigger broke'; END IF; END $$;
INSERT INTO public.forki_backups(user_id,profile,meals,calorie_goal) VALUES (auth.uid(),'{}','[]',2000);
SELECT set_config('request.jwt.claim.sub','22222222-2222-2222-2222-222222222222',false);
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.forki_backups) THEN RAISE EXCEPTION 'Cross-account backup read'; END IF;
 BEGIN INSERT INTO public.forki_backups(user_id,profile,meals,calorie_goal) VALUES ('11111111-1111-1111-1111-111111111111','{}','[]',2000); RAISE EXCEPTION 'Cross-account backup write'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
INSERT INTO public.forki_backups(user_id,profile,meals,calorie_goal) VALUES (auth.uid(),'{}','[]',2200);
UPDATE public.forki_backups SET calorie_goal=2400 WHERE user_id=auth.uid();
DO $$ BEGIN IF (SELECT calorie_goal FROM public.forki_backups)<>2400 THEN RAISE EXCEPTION 'Own backup update failed'; END IF; END $$;
DO $$ BEGIN
 BEGIN UPDATE public.forki_backups SET user_id='11111111-1111-1111-1111-111111111111' WHERE user_id=auth.uid(); RAISE EXCEPTION 'Backup owner transfer accepted'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
DELETE FROM public.forki_backups WHERE user_id=auth.uid();
DO $$ BEGIN IF EXISTS(SELECT 1 FROM public.forki_backups) THEN RAISE EXCEPTION 'Own backup delete failed'; END IF; END $$;
RESET ROLE;
SET ROLE anon;
DO $$ BEGIN
 BEGIN PERFORM public.calculate_user_progress('11111111-1111-1111-1111-111111111111'); RAISE EXCEPTION 'Anonymous execution accepted'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.check_user_exists_in_auth('a@example.invalid'); RAISE EXCEPTION 'Anonymous account enumeration'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;
SET ROLE service_role;
SELECT set_config('request.jwt.claim.role','service_role',false);
SELECT set_config('request.jwt.claim.sub','',false);
SELECT public.calculate_user_progress('11111111-1111-1111-1111-111111111111');
RESET ROLE;
SELECT 'Database security and compatibility checks passed' AS result;
