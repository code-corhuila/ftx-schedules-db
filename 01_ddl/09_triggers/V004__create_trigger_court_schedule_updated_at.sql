-- V004 · Fires set_updated_at on every update of court_schedule.
-- Rollback: 05_rollbacks/01_ddl/09_triggers/U004__create_trigger_court_schedule_updated_at.sql
CREATE TRIGGER trg_court_schedule_updated_at
    BEFORE UPDATE ON schedules.court_schedule
    FOR EACH ROW
    EXECUTE FUNCTION schedules.set_updated_at();
