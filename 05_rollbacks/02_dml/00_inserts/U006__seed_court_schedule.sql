-- U006 · Reverts V006__seed_court_schedule.sql: removes only the seeded rows.
DELETE FROM schedules.court_schedule
WHERE court_id IN ('c0000000-0000-4000-8000-000000000001',
                   'c0000000-0000-4000-8000-000000000002',
                   'c0000000-0000-4000-8000-000000000003',
                   'c0000000-0000-4000-8000-000000000004');
