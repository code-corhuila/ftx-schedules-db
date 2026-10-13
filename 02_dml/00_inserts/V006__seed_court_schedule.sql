-- V006 · Opening hours of the four fixed courts: 4 courts x 7 days = 28 rows.
--
-- Court ids are a CONTRACT with ftx-courts-db: its seed must insert the four
-- courts with exactly these ids.
-- Hours 06:00-22:00 come from the approved mockup (ftx-docs 12-ux-ui/figma).
-- Idempotent seed (Annex A, rule 11): running it twice leaves the same 28 rows.
-- Rollback: 05_rollbacks/02_dml/00_inserts/U006__seed_court_schedule.sql
INSERT INTO schedules.court_schedule (court_id, day_of_week, opening_time, closing_time)
SELECT c.court_id, d.day_of_week, time '06:00', time '22:00'
FROM (VALUES
        ('c0000000-0000-4000-8000-000000000001'::uuid),
        ('c0000000-0000-4000-8000-000000000002'::uuid),
        ('c0000000-0000-4000-8000-000000000003'::uuid),
        ('c0000000-0000-4000-8000-000000000004'::uuid)
     ) AS c(court_id)
CROSS JOIN (VALUES ('MON'), ('TUE'), ('WED'), ('THU'), ('FRI'), ('SAT'), ('SUN')) AS d(day_of_week)
ON CONFLICT (court_id, day_of_week)
DO UPDATE SET opening_time = EXCLUDED.opening_time,
              closing_time = EXCLUDED.closing_time;
