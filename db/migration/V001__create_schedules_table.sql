-- =============================================================================
-- ftx-schedules-db · V001 · Schedules table
--
-- Opening hours per court and day of week.
-- Source model: ftx-docs 06-data/models.md (table "schedules").
--
-- Deviation from 06-data/models.md, required by the repository split:
--   court_id is a CROSS-SERVICE reference to ftx-courts-db. It has NO foreign
--   key, following the cross-service rule in 06-data/models.md
--   ("Cross-service references: UUID without FK constraint").
-- =============================================================================

CREATE TABLE schedules (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Cross-service reference to courts.id in ftx-courts-db. No FK by design.
    court_id        UUID        NOT NULL,

    day_of_week     VARCHAR(10) NOT NULL
                    CONSTRAINT chk_schedule_day_of_week
                    CHECK (day_of_week IN ('MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN')),

    opening_time    TIME        NOT NULL,
    closing_time    TIME        NOT NULL,

    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- 02-domain, Schedule INV-001: openingTime must be before closingTime.
    CONSTRAINT chk_schedule_hours
        CHECK (closing_time > opening_time),

    -- Reservations cover whole hours (binding decision), so opening and
    -- closing times must fall on the hour for the slot grid to line up (FR-003).
    CONSTRAINT chk_schedule_whole_hours
        CHECK (
            date_trunc('hour', opening_time) = opening_time
            AND date_trunc('hour', closing_time) = closing_time
        )
);

-- A court cannot have more than one schedule for the same day.
CREATE UNIQUE INDEX idx_schedules_court_day
    ON schedules (court_id, day_of_week);

-- Keeps updated_at truthful without relying on application code.
CREATE FUNCTION set_updated_at() RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at := NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_schedules_updated_at
    BEFORE UPDATE ON schedules
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();

COMMENT ON TABLE  schedules          IS 'Opening hours per court and day of week. Owned by the schedules context.';
COMMENT ON COLUMN schedules.court_id IS 'Cross-service reference to ftx-courts-db courts.id. No FK by design.';
