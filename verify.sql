\set ON_ERROR_STOP on

DO $$
DECLARE
    n INT;
BEGIN
    -- Seed completo
    SELECT count(*) INTO n FROM schedules;
    IF n <> 28 THEN
        RAISE EXCEPTION 'Se esperaban 28 filas de seed, hay %', n;
    END IF;

    SELECT count(DISTINCT court_id) INTO n FROM schedules;
    IF n <> 4 THEN
        RAISE EXCEPTION 'Se esperaban 4 canchas, hay %', n;
    END IF;

    -- Cada regla debe rechazar datos inválidos
    BEGIN
        INSERT INTO schedules (court_id, day_of_week, opening_time, closing_time)
        VALUES (99, 'XYZ', '06:00', '22:00');
        RAISE EXCEPTION 'ck_schedules_day_of_week no se aplicó';
    EXCEPTION WHEN check_violation THEN NULL;
    END;

    BEGIN
        INSERT INTO schedules (court_id, day_of_week, opening_time, closing_time)
        VALUES (99, 'MON', '22:00', '06:00');
        RAISE EXCEPTION 'ck_schedules_time_range no se aplicó';
    EXCEPTION WHEN check_violation THEN NULL;
    END;

    BEGIN
        INSERT INTO schedules (court_id, day_of_week, opening_time, closing_time)
        VALUES (99, 'MON', '06:30', '22:00');
        RAISE EXCEPTION 'ck_schedules_opening_whole_hour no se aplicó';
    EXCEPTION WHEN check_violation THEN NULL;
    END;

    BEGIN
        INSERT INTO schedules (court_id, day_of_week, opening_time, closing_time)
        VALUES (99, 'MON', '06:00', '21:30');
        RAISE EXCEPTION 'ck_schedules_closing_whole_hour no se aplicó';
    EXCEPTION WHEN check_violation THEN NULL;
    END;

    BEGIN
        INSERT INTO schedules (court_id, day_of_week, opening_time, closing_time)
        VALUES (1, 'MON', '06:00', '22:00');
        RAISE EXCEPTION 'uq_schedules_court_day no se aplicó';
    EXCEPTION WHEN unique_violation THEN NULL;
    END;

    RAISE NOTICE 'verify.sql: seed y constraints OK';
END
$$;
