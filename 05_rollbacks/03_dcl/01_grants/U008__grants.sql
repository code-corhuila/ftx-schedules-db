-- U008 · Reverts V008__grants.sql
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'schedules_app') THEN
        REVOKE schedules_writer FROM schedules_app;
    END IF;
END
$$;
REVOKE SELECT, INSERT, UPDATE, DELETE ON schedules.court_schedule FROM schedules_writer;
REVOKE SELECT ON schedules.court_schedule FROM schedules_reader;
REVOKE USAGE ON SCHEMA schedules FROM schedules_reader, schedules_writer;
