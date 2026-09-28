-- Horario base: 4 canchas x 7 días, 06:00-22:00.
-- Los court_id deben coincidir con los ids sembrados en ftx-courts-db.

INSERT INTO schedules (court_id, day_of_week, opening_time, closing_time)
SELECT c.court_id, d.day_of_week, TIME '06:00', TIME '22:00'
FROM (VALUES (1), (2), (3), (4)) AS c(court_id)
CROSS JOIN (VALUES ('MON'), ('TUE'), ('WED'), ('THU'), ('FRI'), ('SAT'), ('SUN')) AS d(day_of_week);
