-- V008 · Permissions of the schedules domain.
--   schedules_reader: read only.
--   schedules_writer: read and write rows. Never DDL: structure only comes from this repo.
-- The domain grants its writer role to its own user (Annex J.7). schedules_app is
-- created by ftx-infra-postgres; if it does not exist yet (for example in CI with an
-- empty database), the grant is skipped and applied when infra creates the user
-- and this repo adds a new migration, or by running U008/V008 by hand.
-- Rollback: 05_rollbacks/03_dcl/01_grants/U008__grants.sql
GRANT USAGE ON SCHEMA schedules TO schedules_reader, schedules_writer;
-- Table by table, never ON ALL TABLES: the schema also holds flyway_schema_history,
-- and no application user may read or alter the migration history.
GRANT SELECT ON schedules.court_schedule TO schedules_reader;
GRANT SELECT, INSERT, UPDATE, DELETE ON schedules.court_schedule TO schedules_writer;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'schedules_app') THEN
        GRANT schedules_writer TO schedules_app;
    ELSE
        RAISE NOTICE 'schedules_app does not exist yet: grant skipped (created by ftx-infra-postgres)';
    END IF;
END
$$;
