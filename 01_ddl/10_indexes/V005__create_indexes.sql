-- V005 · Indexes of court_schedule.
-- idx_court_schedule_court_id_day_of_week
--   * Rule: a court has at most one schedule per day (unique).
--   * Query it serves: "opening hours of court X on day Y", used by the
--     availability lookup (HU-RES-001). court_id is the leading column, so it
--     also serves "all schedules of court X".
-- The table is empty when this runs, so CONCURRENTLY is not needed (Annex A, rule 14).
-- Rollback: 05_rollbacks/01_ddl/10_indexes/U005__create_indexes.sql
CREATE UNIQUE INDEX idx_court_schedule_court_id_day_of_week
    ON schedules.court_schedule (court_id, day_of_week);
