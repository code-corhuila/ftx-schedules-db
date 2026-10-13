-- U004 · Reverts V004__create_trigger_court_schedule_updated_at.sql
DROP TRIGGER IF EXISTS trg_court_schedule_updated_at ON schedules.court_schedule;
