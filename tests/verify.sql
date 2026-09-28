-- =============================================================================
-- ftx-schedules-db · Post-migration verification
--
-- Run after "flyway migrate". Every failed check raises an exception, so psql
-- (run with ON_ERROR_STOP=1) exits non-zero and CI turns red. Test inserts
-- that succeed are rolled back, so the database is left as the migrations
-- created it.
-- =============================================================================

SET search_path TO schedules;

-- 1. Seed: exactly 28 rows, 4 distinct courts, 7 days each, 06:00-22:00.
DO $$
DECLARE
    total     INT;
    courts    INT;
    bad_days  INT;
    bad_hours INT;
BEGIN
    SELECT COUNT(*), COUNT(DISTINCT court_id) INTO total, courts FROM schedules;

    SELECT COUNT(*) INTO bad_days
      FROM (SELECT court_id FROM schedules GROUP BY court_id HAVING COUNT(*) <> 7) t;

    SELECT COUNT(*) INTO bad_hours
      FROM schedules
     WHERE opening_time <> TIME '06:00' OR closing_time <> TIME '22:00';

    IF total <> 28 OR courts <> 4 OR bad_days <> 0 OR bad_hours <> 0 THEN
        RAISE EXCEPTION 'Seed check failed: total=%, courts=%, courts without 7 days=%, rows off 06-22=%',
            total, courts, bad_days, bad_hours;
    END IF;
    RAISE NOTICE 'OK  seed: 4 courts x 7 days, 06:00-22:00';
END $$;

-- 2. One schedule per court and day.
DO $$
BEGIN
    INSERT INTO schedules (court_id, day_of_week, opening_time, closing_time)
    VALUES ('c0000000-0000-4000-8000-000000000001', 'MON', '08:00', '10:00');
    RAISE EXCEPTION 'FAIL duplicate court/day was accepted';
EXCEPTION WHEN unique_violation THEN
    RAISE NOTICE 'OK  duplicate court/day rejected';
END $$;

-- 3. closing_time must be after opening_time.
DO $$
BEGIN
    INSERT INTO schedules (court_id, day_of_week, opening_time, closing_time)
    VALUES (gen_random_uuid(), 'MON', '22:00', '06:00');
    RAISE EXCEPTION 'FAIL inverted hours were accepted';
EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'OK  inverted hours rejected';
END $$;

-- 4. Opening and closing times must be whole hours.
DO $$
BEGIN
    INSERT INTO schedules (court_id, day_of_week, opening_time, closing_time)
    VALUES (gen_random_uuid(), 'MON', '06:30', '22:00');
    RAISE EXCEPTION 'FAIL non whole-hour time was accepted';
EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'OK  non whole-hour time rejected';
END $$;

-- 5. Only MON..SUN are valid days.
DO $$
BEGIN
    INSERT INTO schedules (court_id, day_of_week, opening_time, closing_time)
    VALUES (gen_random_uuid(), 'MONDAY', '06:00', '22:00');
    RAISE EXCEPTION 'FAIL invalid day_of_week was accepted';
EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'OK  invalid day rejected';
END $$;

-- 6. A valid new row is accepted (then rolled back).
DO $$
BEGIN
    INSERT INTO schedules (court_id, day_of_week, opening_time, closing_time)
    VALUES (gen_random_uuid(), 'MON', '07:00', '21:00');
    RAISE EXCEPTION USING ERRCODE = 'P0099', MESSAGE = 'rollback';
EXCEPTION WHEN SQLSTATE 'P0099' THEN
    RAISE NOTICE 'OK  valid row accepted (rolled back)';
END $$;

-- 7. updated_at moves forward on UPDATE (then rolled back).
DO $$
DECLARE
    before_ts TIMESTAMPTZ;
    after_ts  TIMESTAMPTZ;
BEGIN
    SELECT updated_at INTO before_ts FROM schedules
     WHERE court_id = 'c0000000-0000-4000-8000-000000000001' AND day_of_week = 'SUN';

    UPDATE schedules SET updated_at = before_ts - INTERVAL '1 day', closing_time = '21:00'
     WHERE court_id = 'c0000000-0000-4000-8000-000000000001' AND day_of_week = 'SUN'
    RETURNING updated_at INTO after_ts;

    IF after_ts < before_ts THEN
        RAISE EXCEPTION 'FAIL updated_at trigger did not fire';
    END IF;
    RAISE EXCEPTION USING ERRCODE = 'P0099', MESSAGE = 'rollback';
EXCEPTION WHEN SQLSTATE 'P0099' THEN
    RAISE NOTICE 'OK  updated_at trigger fires (rolled back)';
END $$;

-- 8. No foreign key on court_id: courts live in ftx-courts-db.
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints
         WHERE table_schema = 'schedules' AND table_name = 'schedules'
           AND constraint_type = 'FOREIGN KEY'
    ) THEN
        RAISE EXCEPTION 'FAIL schedules has a foreign key; court_id must be a cross-service reference';
    END IF;
    RAISE NOTICE 'OK  no cross-service foreign key';
END $$;
