-- =============================================================================
-- ftx-schedules-db · Post-migration checks (run by db-ci.yml after migrate)
--
-- Every failed check raises an exception, so psql (ON_ERROR_STOP=1) exits
-- non-zero and the CI turns red. Test rows are rolled back, so the database is
-- left exactly as the migrations created it.
-- =============================================================================

-- 1. Seed: 28 rows, 4 courts, 7 days each, 06:00-22:00.
DO $$
DECLARE total int; courts int; bad_days int; bad_hours int;
BEGIN
    SELECT count(*), count(DISTINCT court_id) INTO total, courts FROM schedules.court_schedule;
    SELECT count(*) INTO bad_days
      FROM (SELECT court_id FROM schedules.court_schedule GROUP BY court_id HAVING count(*) <> 7) t;
    SELECT count(*) INTO bad_hours FROM schedules.court_schedule
     WHERE opening_time <> time '06:00' OR closing_time <> time '22:00';
    IF total <> 28 OR courts <> 4 OR bad_days <> 0 OR bad_hours <> 0 THEN
        RAISE EXCEPTION 'FAIL seed: total=%, courts=%, courts without 7 days=%, rows off 06-22=%',
            total, courts, bad_days, bad_hours;
    END IF;
    RAISE NOTICE 'OK  seed: 4 courts x 7 days, 06:00-22:00';
END $$;

-- 2. One schedule per court and day.
DO $$
BEGIN
    INSERT INTO schedules.court_schedule (court_id, day_of_week, opening_time, closing_time)
    VALUES ('c0000000-0000-4000-8000-000000000001', 'MON', '08:00', '10:00');
    RAISE EXCEPTION 'FAIL duplicate court/day was accepted';
EXCEPTION WHEN unique_violation THEN
    RAISE NOTICE 'OK  duplicate court/day rejected';
END $$;

-- 3. closing_time must be after opening_time.
DO $$
BEGIN
    INSERT INTO schedules.court_schedule (court_id, day_of_week, opening_time, closing_time)
    VALUES (gen_random_uuid(), 'MON', '22:00', '06:00');
    RAISE EXCEPTION 'FAIL inverted hours were accepted';
EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'OK  inverted hours rejected';
END $$;

-- 4. Whole hours only.
DO $$
BEGIN
    INSERT INTO schedules.court_schedule (court_id, day_of_week, opening_time, closing_time)
    VALUES (gen_random_uuid(), 'MON', '06:30', '22:00');
    RAISE EXCEPTION 'FAIL non whole-hour time was accepted';
EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'OK  non whole-hour time rejected';
END $$;

-- 5. Only MON..SUN.
DO $$
BEGIN
    INSERT INTO schedules.court_schedule (court_id, day_of_week, opening_time, closing_time)
    VALUES (gen_random_uuid(), 'MONDAY', '06:00', '22:00');
    RAISE EXCEPTION 'FAIL invalid day_of_week was accepted';
EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'OK  invalid day rejected';
END $$;

-- 6. A valid row is accepted (then rolled back).
DO $$
BEGIN
    INSERT INTO schedules.court_schedule (court_id, day_of_week, opening_time, closing_time)
    VALUES (gen_random_uuid(), 'MON', '07:00', '21:00');
    RAISE EXCEPTION USING ERRCODE = 'P0099', MESSAGE = 'rollback';
EXCEPTION WHEN SQLSTATE 'P0099' THEN
    RAISE NOTICE 'OK  valid row accepted (rolled back)';
END $$;

-- 7. updated_at is maintained by the trigger (then rolled back).
DO $$
DECLARE after_ts timestamptz;
BEGIN
    UPDATE schedules.court_schedule
       SET updated_at = now() - interval '1 day', closing_time = '21:00'
     WHERE court_id = 'c0000000-0000-4000-8000-000000000001' AND day_of_week = 'SUN'
    RETURNING updated_at INTO after_ts;
    IF after_ts < now() THEN
        RAISE EXCEPTION 'FAIL updated_at trigger did not fire';
    END IF;
    RAISE EXCEPTION USING ERRCODE = 'P0099', MESSAGE = 'rollback';
EXCEPTION WHEN SQLSTATE 'P0099' THEN
    RAISE NOTICE 'OK  updated_at trigger fires (rolled back)';
END $$;

-- 8. No foreign key: courts live in another domain (Annex J.3.4).
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.table_constraints
                WHERE table_schema = 'schedules' AND constraint_type = 'FOREIGN KEY') THEN
        RAISE EXCEPTION 'FAIL the schedules schema has a foreign key';
    END IF;
    RAISE NOTICE 'OK  no cross-domain foreign key';
END $$;

-- 9. Nothing of this domain lives in public (Annex A, rule 9).
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename LIKE '%schedule%') THEN
        RAISE EXCEPTION 'FAIL a schedules table lives in public';
    END IF;
    RAISE NOTICE 'OK  nothing in public';
END $$;

-- 10. Roles exist, cannot log in, and the writer cannot change structure.
DO $$
BEGIN
    IF (SELECT count(*) FROM pg_roles
         WHERE rolname IN ('schedules_reader', 'schedules_writer') AND NOT rolcanlogin) <> 2 THEN
        RAISE EXCEPTION 'FAIL schedules_reader / schedules_writer missing or LOGIN';
    END IF;
    IF NOT has_table_privilege('schedules_reader', 'schedules.court_schedule', 'SELECT')
       OR has_table_privilege('schedules_reader', 'schedules.court_schedule', 'INSERT') THEN
        RAISE EXCEPTION 'FAIL schedules_reader must read and never write';
    END IF;
    IF NOT has_table_privilege('schedules_writer', 'schedules.court_schedule', 'INSERT')
       OR has_schema_privilege('schedules_writer', 'schedules', 'CREATE') THEN
        RAISE EXCEPTION 'FAIL schedules_writer must write rows and never create objects';
    END IF;
    RAISE NOTICE 'OK  roles NOLOGIN with least privilege';
END $$;

-- 11. No application role can touch the migration history.
DO $$
BEGIN
    IF to_regclass('schedules.flyway_schema_history') IS NOT NULL
       AND (has_table_privilege('schedules_writer', 'schedules.flyway_schema_history', 'SELECT')
         OR has_table_privilege('schedules_reader', 'schedules.flyway_schema_history', 'SELECT')) THEN
        RAISE EXCEPTION 'FAIL an application role can read flyway_schema_history';
    END IF;
    RAISE NOTICE 'OK  migration history is private';
END $$;
