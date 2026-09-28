-- Horarios de operación por cancha y día de la semana.
-- court_id no tiene FK: la tabla courts vive en ftx-courts-db (una base de datos por dominio).

CREATE TABLE schedules (
    id            BIGSERIAL   PRIMARY KEY,
    court_id      BIGINT      NOT NULL,
    day_of_week   VARCHAR(3)  NOT NULL,
    opening_time  TIME        NOT NULL,
    closing_time  TIME        NOT NULL,

    CONSTRAINT ck_schedules_day_of_week
        CHECK (day_of_week IN ('MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN')),

    CONSTRAINT ck_schedules_time_range
        CHECK (closing_time > opening_time),

    CONSTRAINT ck_schedules_opening_whole_hour
        CHECK (EXTRACT(MINUTE FROM opening_time) = 0 AND EXTRACT(SECOND FROM opening_time) = 0),

    CONSTRAINT ck_schedules_closing_whole_hour
        CHECK (EXTRACT(MINUTE FROM closing_time) = 0 AND EXTRACT(SECOND FROM closing_time) = 0),

    CONSTRAINT uq_schedules_court_day
        UNIQUE (court_id, day_of_week)
);

COMMENT ON COLUMN schedules.court_id IS
    'Identificador de la cancha en ftx-courts-db. Sin FK por la regla de una base de datos por dominio.';
