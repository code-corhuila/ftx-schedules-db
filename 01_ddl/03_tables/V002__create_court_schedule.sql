-- V002 · court_schedule: opening hours of each court per day of the week.
--
-- Source model: ftx-docs 06-data/models.md (table "schedules"), adapted to the norm:
--   * Singular snake_case name (Annex A, rule 1).
--   * court_id references a court owned by the courts domain (ftx-courts-db).
--     It is NOT a foreign key: integrity between domains is checked by contract
--     (Annex A rule 8, Annex J.3.4).
--   * Closed sets of values are CHECK constraints, never ENUM (Annex A, rule 5).
--   * Constraints have explicit names (Annex A, rule 4).
--   * The unique index lives in 10_indexes (V005).
-- Rollback: 05_rollbacks/01_ddl/03_tables/U002__create_court_schedule.sql
CREATE TABLE schedules.court_schedule (
    id            uuid        NOT NULL DEFAULT gen_random_uuid(),
    court_id      uuid        NOT NULL,
    day_of_week   text        NOT NULL,
    opening_time  time        NOT NULL,
    closing_time  time        NOT NULL,
    created_at    timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT pk_court_schedule PRIMARY KEY (id),

    CONSTRAINT chk_court_schedule_day_of_week
        CHECK (day_of_week IN ('MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN')),

    -- Domain invariant: a court closes after it opens.
    CONSTRAINT chk_court_schedule_hours
        CHECK (closing_time > opening_time),

    -- Reservations use whole-hour slots (HU-RES-001), so the schedule must too.
    CONSTRAINT chk_court_schedule_whole_hours
        CHECK (date_trunc('hour', opening_time) = opening_time
           AND date_trunc('hour', closing_time) = closing_time)
);

COMMENT ON TABLE  schedules.court_schedule          IS 'Opening hours per court and day of week. Owned by the schedules domain.';
COMMENT ON COLUMN schedules.court_schedule.court_id IS 'Reference to a court of the courts domain (ftx-courts-db). No foreign key by design.';
