-- =============================================================================
-- ftx-schedules-db · V002 · Opening hours for the four fixed courts
--
-- Four courts x seven days = 28 rows, 06:00 to 22:00.
--
-- Court ids: these four UUIDs are a CONTRACT with ftx-courts-db. Its seed
-- migration must insert the four courts with exactly these ids, otherwise
-- every row below points to a court that does not exist.
--
-- Hours: 06:00-22:00 every day, taken from the approved mockup
-- (ftx-docs 12-ux-ui/figma, "HORARIO 06-22h"). Pending confirmation by the
-- Product Owner. If they change, add a new migration with an UPDATE; never
-- edit this file once it has run in any environment.
-- =============================================================================

INSERT INTO schedules (court_id, day_of_week, opening_time, closing_time)
SELECT c.court_id, d.day_of_week, TIME '06:00', TIME '22:00'
FROM (VALUES
        ('c0000000-0000-4000-8000-000000000001'::uuid),   -- Court 1
        ('c0000000-0000-4000-8000-000000000002'::uuid),   -- Court 2
        ('c0000000-0000-4000-8000-000000000003'::uuid),   -- Court 3
        ('c0000000-0000-4000-8000-000000000004'::uuid)    -- Court 4
     ) AS c(court_id)
CROSS JOIN (VALUES
        ('MON'), ('TUE'), ('WED'), ('THU'), ('FRI'), ('SAT'), ('SUN')
     ) AS d(day_of_week);
